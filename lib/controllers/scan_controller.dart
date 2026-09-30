
import 'package:flutter/foundation.dart';
import '../services/acoustic_scan_service.dart';
import '../models/scan_data.dart';

enum ScanState {
  idle,
  scanning,
  processing,
  completed,
  error,
}

class ScanController extends ChangeNotifier {
  final AcousticScanService _acousticScanService = AcousticScanService();
  ScanState _state = ScanState.idle;
  ScanData? _lastScanData;
  String? _errorMessage;

  ScanState get state => _state;
  ScanData? get lastScanData => _lastScanData;
  String? get errorMessage => _errorMessage;

  ScanController() {
    _acousticScanService.init();
  }

  Future<void> startScan() async {
    if (_state == ScanState.scanning) return;

    _state = ScanState.scanning;
    _errorMessage = null;
    _lastScanData = null;
    notifyListeners();

    try {
      await _acousticScanService.startScan();
      print('Scan started.');
    } catch (e) {
      _errorMessage = 'Failed to start scan: ${e.toString()}';
      _state = ScanState.error;
      print(_errorMessage);
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    if (_state != ScanState.scanning) return;

    _state = ScanState.processing;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _acousticScanService.stopScan();
      if (result != null) {
        _lastScanData = result;
        _state = ScanState.completed;
        print('Scan completed and data processed: ${_lastScanData.toString()}');
        print('Mathematical Representation: ${_lastScanData!.mathematicalRepresentation.toJson()}');
        print(
          'Detection: ${result.detection.verdict.name.toUpperCase()} '
          '(score: ${result.detection.score.toStringAsFixed(2)}, '
          'confidence: ${result.detection.confidence.toStringAsFixed(2)}, '
          'segments: ${result.detection.segments.length})',
        );
      } else {
        _errorMessage = 'Scan stopped, but no data was returned.';
        _state = ScanState.error;
        print(_errorMessage);
      }
    } catch (e) {
      _errorMessage = 'Failed to stop or process scan: ${e.toString()}';
      _state = ScanState.error;
      print(_errorMessage);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _acousticScanService.dispose();
    super.dispose();
  }
}
