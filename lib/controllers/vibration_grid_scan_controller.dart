import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/accel_sample.dart';
import '../models/contact_grid_scan.dart';
import '../services/accelerometer_source.dart';
import '../services/grid_signal_processor.dart';
import '../services/scan_provenance.dart';
import '../services/vibrator_port.dart';

enum GridScanState {
  idle,
  awaitingBaseline,
  baselineCapturing,
  awaitingPlacement,
  settling,
  capturing,
  processing,
  completed,
  aborted,
  error,
}

class VibrationGridScanController extends ChangeNotifier {
  VibrationGridScanController({
    AccelerometerSource? accelerometer,
    VibratorPort? vibrator,
    int? rows,
    int? cols,
    int? settleMs,
    int? vibrateMs,
    int? warmupDiscardMs,
    int? preRollMs,
    int? minSamples,
    Future<ScanProvenance> Function()? provenanceResolver,
  })  : _accelerometer = accelerometer ?? const SensorPlusAccelerometerSource(),
        _vibrator = vibrator ?? PlatformVibrator(),
        rows = rows ?? GridSignalProcessor.defaultRows,
        cols = cols ?? GridSignalProcessor.defaultCols,
        settleMs = settleMs ?? GridSignalProcessor.settleMs,
        vibrateMs = vibrateMs ?? GridSignalProcessor.vibrateMs,
        warmupDiscardMs =
            warmupDiscardMs ?? GridSignalProcessor.warmupDiscardMs,
        preRollMs = preRollMs ?? GridSignalProcessor.preRollMs,
        minSamples = minSamples ?? GridSignalProcessor.minSamplesPerCell,
        _provenanceResolver =
            provenanceResolver ?? ScanProvenanceCollector.collect;

  final AccelerometerSource _accelerometer;
  final VibratorPort _vibrator;
  final Future<ScanProvenance> Function() _provenanceResolver;

  final int rows;
  final int cols;
  final int settleMs;
  final int vibrateMs;
  final int warmupDiscardMs;
  final int preRollMs;
  final int minSamples;

  GridScanState _state = GridScanState.idle;
  int _cellIndex = 0;
  double _baselineAirRms = 0;
  bool _abortRequested = false;
  String? _errorMessage;
  ContactGridScan? _lastScan;
  List<List<double>> _matrix = [];
  List<List<CellSignal?>> _cellStats = [];

  GridScanState get state => _state;
  int get cellIndex => _cellIndex;
  int get currentRow => _cellIndex ~/ cols;
  int get currentCol => _cellIndex % cols;
  int get totalCells => rows * cols;
  int get cellsCompleted => _cellIndex;
  double get progress => totalCells == 0 ? 0 : _cellIndex / totalCells;
  double get baselineAirRms => _baselineAirRms;
  String? get errorMessage => _errorMessage;
  ContactGridScan? get lastScan => _lastScan;

  double? cellValue(int row, int col) {
    if (row >= _matrix.length || col >= _matrix[row].length) return null;
    return _matrix[row][col];
  }

  bool get canRetakeLastCell =>
      _state == GridScanState.awaitingPlacement && _cellIndex > 0;

  void _resetSession() {
    _cellIndex = 0;
    _baselineAirRms = 0;
    _abortRequested = false;
    _errorMessage = null;
    _lastScan = null;
    _matrix = List.generate(rows, (_) => List.filled(cols, 0.0));
    _cellStats =
        List.generate(rows, (_) => List<CellSignal?>.filled(cols, null));
  }

  Future<void> startScan() async {
    if (_state == GridScanState.settling ||
        _state == GridScanState.capturing ||
        _state == GridScanState.baselineCapturing ||
        _state == GridScanState.processing) {
      return;
    }

    _resetSession();

    if (!await _vibrator.isSupported()) {
      _errorMessage =
          'No vibration motor available on this device. Scans require a phone with a haptic actuator.';
      _state = GridScanState.error;
      notifyListeners();
      return;
    }

    _state = GridScanState.awaitingBaseline;
    notifyListeners();
  }

  Future<void> captureBaseline() async {
    if (_state != GridScanState.awaitingBaseline) return;
    _abortRequested = false;
    _state = GridScanState.baselineCapturing;
    notifyListeners();

    try {
      final signal = await _captureBurst();
      if (_abortRequested) return;
      _baselineAirRms = signal.contactRms;
      if (_baselineAirRms <= 0) {
        throw StateError(
          'Baseline measured zero energy; hold the phone freely in the air and retry.',
        );
      }
      _state = GridScanState.awaitingPlacement;
      notifyListeners();
    } catch (e) {
      if (_abortRequested) return;
      _fail('Baseline capture failed: $e');
    }
  }

  Future<void> confirmPlacement() async {
    if (_state != GridScanState.awaitingPlacement) return;
    _abortRequested = false;

    _state = GridScanState.settling;
    notifyListeners();
    await Future<void>.delayed(Duration(milliseconds: settleMs));
    if (_abortRequested) return;

    _state = GridScanState.capturing;
    notifyListeners();

    CellSignal signal;
    try {
      signal = await _captureBurst();
    } catch (e) {
      if (_abortRequested) return;
      _fail('Cell capture failed: $e');
      return;
    }
    if (_abortRequested) return;

    _state = GridScanState.processing;
    notifyListeners();

    _matrix[currentRow][currentCol] = signal.contactRms;
    _cellStats[currentRow][currentCol] = signal;

    if (_cellIndex + 1 >= totalCells) {
      await _completeScan();
      return;
    }

    _cellIndex++;
    _state = GridScanState.awaitingPlacement;
    notifyListeners();
  }

  void retakeLastCell() {
    if (!canRetakeLastCell) return;
    _cellIndex--;
    _matrix[currentRow][currentCol] = 0;
    _cellStats[currentRow][currentCol] = null;
    _state = GridScanState.awaitingPlacement;
    notifyListeners();
  }

  void abortScan() {
    if (_state == GridScanState.idle ||
        _state == GridScanState.completed ||
        _state == GridScanState.aborted ||
        _state == GridScanState.error) {
      return;
    }
    _abortRequested = true;
    _vibrator.stop();
    _state = GridScanState.aborted;
    notifyListeners();
  }

  void dismissToIdle() {
    if (_state == GridScanState.completed ||
        _state == GridScanState.aborted ||
        _state == GridScanState.error) {
      _state = GridScanState.idle;
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> _completeScan() async {
    ScanProvenance provenance;
    try {
      provenance = await _provenanceResolver();
    } catch (_) {
      provenance = const ScanProvenance(
        platform: 'unknown',
        deviceModel: 'unknown',
        appVersion: 'unknown',
      );
    }
    if (_abortRequested) return;

    _lastScan = ContactGridScan(
      scanId: const Uuid().v4(),
      timestamp: DateTime.now(),
      targetType: ContactGridScan.kTargetType,
      gridDimensions: GridDimensions(rows: rows, cols: cols),
      scanDirection: ContactGridScan.kScanDirection,
      baselineAirRms: _baselineAirRms,
      capture: CaptureSettings(
        settleMs: settleMs,
        vibrateMs: vibrateMs,
        warmupDiscardMs: warmupDiscardMs,
        preRollMs: preRollMs,
        minSamplesPerCell: minSamples,
      ),
      device: provenance,
      dataMatrix: [
        for (final row in _matrix) List<double>.from(row),
      ],
      cellStats: [
        for (final row in _cellStats) [for (final c in row) c!],
      ],
    );
    _state = GridScanState.completed;
    debugPrint(_lastScan!.toJsonString());
    notifyListeners();
  }

  Future<CellSignal> _captureBurst() async {
    final samples = <AccelSample>[];
    Object? streamError;
    final subscription = _accelerometer.sampleStream().listen(
          samples.add,
          onError: (Object e) => streamError = e,
        );

    try {
      if (preRollMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: preRollMs));
      }
      await _vibrator.start(durationMs: vibrateMs);
      await Future<void>.delayed(Duration(milliseconds: vibrateMs));
      await _vibrator.stop();
    } finally {
      await subscription.cancel();
    }

    if (streamError != null) {
      throw StateError('Accelerometer error: $streamError');
    }
    if (samples.isEmpty) {
      throw StateError('Accelerometer returned no samples during capture.');
    }

    return GridSignalProcessor.computeCell(
      samples,
      warmupDiscardMs: warmupDiscardMs,
      minSamples: minSamples,
    );
  }

  void _fail(String message) {
    _errorMessage = message;
    _state = GridScanState.error;
    notifyListeners();
  }
}
