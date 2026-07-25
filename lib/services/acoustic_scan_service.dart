import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/scan_data.dart';

class AcousticScanService {
  AcousticScanService({
    this.sampleRate = 44100,
    this.numChannels = 1,
    this.fundamentalFrequency = 5000.0,
  });

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();

  String _toneFilePath = '';
  Source _audioSource = DeviceFileSource('');

  final int sampleRate;
  final int numChannels;
  final double fundamentalFrequency;

  String? _recordingPath;
  DateTime? _scanStartTime;

  Timer? _spatialLogTimer;

  final List<SpatialTimeLogEntry> _spatialTimeLog = [];

  int _currentSpatialRow = 0;
  int _currentSpatialColumn = 0;
  bool _zigzagForward = true;

  bool _initialized = false;
  bool _isScanning = false;

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    debugPrint('AcousticScanService: Initializing...');

    if (defaultTargetPlatform == TargetPlatform.android) {
      final AudioContext audioContext = AudioContext(
        android: AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
          stayAwake: true,
        ),
      );
      await _audioPlayer.setAudioContext(audioContext);
      debugPrint('AcousticScanService: AudioContext set (no focus management).');
    }

    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      // Generate a WAV file with a sine tone at the fundamental frequency.
      _toneFilePath = await _generateToneFile();
      _audioSource = DeviceFileSource(_toneFilePath);
      debugPrint('AcousticScanService: Tone file ready at $_toneFilePath');

      _initialized = true;
      debugPrint('AcousticScanService: Initialized. Player state: ${_audioPlayer.state}');
    } catch (e, stackTrace) {
      debugPrint('AcousticScanService: Init failed: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  /// Generates a WAV file containing a sine wave at [fundamentalFrequency].
  Future<String> _generateToneFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/generated_tone.wav';
    final file = File(path);

    if (await file.exists()) {
      debugPrint('AcousticScanService: Tone file already exists, reusing.');
      return path;
    }

    const double duration = 30.0;
    final int numSamples = (sampleRate * duration).toInt();
    final int dataSize = numSamples * 2; // 16-bit mono
    final int fileSize = 36 + dataSize;

    final ByteData header = ByteData(44);
    // RIFF
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    // fmt
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    // data
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final Uint8List pcm = Uint8List(dataSize);
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double sample = sin(2 * pi * fundamentalFrequency * t);
      final int pcmVal = (sample * 32767).round().clamp(-32768, 32767);
      pcm[i * 2] = pcmVal & 0xFF;
      pcm[i * 2 + 1] = (pcmVal >> 8) & 0xFF;
    }

    final Uint8List wavBytes = Uint8List(44 + dataSize);
    wavBytes.setRange(0, 44, header.buffer.asUint8List());
    wavBytes.setRange(44, 44 + dataSize, pcm);

    await file.writeAsBytes(wavBytes);
    debugPrint('AcousticScanService: Generated tone file ($fileSize bytes)');
    return path;
  }

  // ---------------------------------------------------------------------------
  // START SCAN
  // ---------------------------------------------------------------------------

  Future<void> startScan() async {
    if (_isScanning) {
      debugPrint(
        'AcousticScanService: Scan already in progress.',
      );

      return;
    }

    if (!_initialized) {
      await init();
    }

    _scanStartTime = DateTime.now();

    _spatialTimeLog.clear();

    _currentSpatialRow = 0;
    _currentSpatialColumn = 0;
    _zigzagForward = true;

    _isScanning = true;

    try {
      // -----------------------------------------------------------------------
      // START AUDIO PLAYBACK
      // -----------------------------------------------------------------------

      await _audioPlayer.stop();

      await _audioPlayer.play(
        _audioSource,
        mode: PlayerMode.mediaPlayer,
      );

      debugPrint(
        'AcousticScanService: Audio playback started.',
      );

      // -----------------------------------------------------------------------
      // CHECK RECORDING PERMISSION
      // -----------------------------------------------------------------------

      final bool hasPermission =
      await _audioRecorder.hasPermission();

      if (!hasPermission) {
        debugPrint(
          'AcousticScanService: Recording permission '
              'not granted.',
        );

        await _audioPlayer.stop();

        _isScanning = false;

        return;
      }

      // -----------------------------------------------------------------------
      // CREATE RECORDING PATH
      // -----------------------------------------------------------------------

      final directory =
      await getApplicationDocumentsDirectory();

      final timestamp =
          _scanStartTime!.millisecondsSinceEpoch;

      final requestedPath =
          '${directory.path}/scan_feedback_$timestamp.wav';

      _recordingPath = requestedPath;

      // -----------------------------------------------------------------------
      // START RECORDING
      //
      // IMPORTANT:
      // In your installed version of record, start() returns void.
      // Therefore, do NOT assign its result to a variable.
      // -----------------------------------------------------------------------

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: requestedPath,
      );
      debugPrint('AcousticScanService: Audio recorder started.');

      debugPrint(
        'AcousticScanService: Recording started at '
            '$_recordingPath',
      );

      // -----------------------------------------------------------------------
      // START SPATIAL LOGGING
      // -----------------------------------------------------------------------

      _spatialLogTimer?.cancel();

      _spatialLogTimer = Timer.periodic(
        const Duration(milliseconds: 100),
            (_) {
          _generateSpatialLogEntry();
        },
      );
    } catch (e, stackTrace) {
      _isScanning = false;

      debugPrint(
        'AcousticScanService: Failed to start scan: $e',
      );

      debugPrint(stackTrace.toString());

      try {
        await _audioPlayer.stop();
      } catch (_) {}

      try {
        await _audioRecorder.stop();
      } catch (_) {}

      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // STOP SCAN
  // ---------------------------------------------------------------------------

  Future<ScanData?> stopScan() async {
    if (!_isScanning ||
        _scanStartTime == null) {
      debugPrint(
        'AcousticScanService: No active scan.',
      );

      return null;
    }

    final DateTime startTime =
    _scanStartTime!;

    // Stop spatial logging.
    _spatialLogTimer?.cancel();
    _spatialLogTimer = null;

    _isScanning = false;

    // -------------------------------------------------------------------------
    // STOP AUDIO
    // -------------------------------------------------------------------------

    try {
      await _audioPlayer.stop();

      debugPrint(
        'AcousticScanService: Audio playback stopped.',
      );
    } catch (e) {
      debugPrint(
        'AcousticScanService: Failed to stop audio: $e',
      );
    }

    // -------------------------------------------------------------------------
    // STOP RECORDING
    // -------------------------------------------------------------------------

    try {
      final String? stoppedRecordingPath =
      await _audioRecorder.stop();
      debugPrint('AcousticScanService: Audio recorder stopped. Path: $stoppedRecordingPath');

      if (stoppedRecordingPath != null && stoppedRecordingPath.isNotEmpty) {
        _recordingPath = stoppedRecordingPath;
        final File recordedFile = File(stoppedRecordingPath);
        if (await recordedFile.exists()) {
          final int fileSize = await recordedFile.length();
          debugPrint('AcousticScanService: Recorded file size: $fileSize bytes');
        } else {
          debugPrint('AcousticScanService: Recorded file not found at: $stoppedRecordingPath');
        }
      } else {
        debugPrint('AcousticScanService: Audio recorder returned null or empty path.');
      }

      debugPrint(
        'AcousticScanService: Recording stopped.',
      );

      debugPrint(
        'AcousticScanService: Recording path: '
            '$_recordingPath',
      );
    } catch (e) {
      debugPrint(
        'AcousticScanService: Failed to stop '
            'recording: $e',
      );
    }

    // -------------------------------------------------------------------------
    // SCAN METADATA
    // -------------------------------------------------------------------------

    final DateTime scanEndTime =
    DateTime.now();

    final int totalDurationMs =
        scanEndTime
            .difference(startTime)
            .inMilliseconds;

    // -------------------------------------------------------------------------
    // CHECK RECORDING FILE
    // -------------------------------------------------------------------------

    final String? recordingPath =
        _recordingPath;

    if (recordingPath == null) {
      debugPrint(
        'AcousticScanService: Recording path is null.',
      );

      _scanStartTime = null;

      return null;
    }

    final File recordingFile =
    File(recordingPath);

    if (!await recordingFile.exists()) {
      debugPrint(
        'AcousticScanService: Recording file '
            'does not exist: $recordingPath',
      );

      _scanStartTime = null;

      return null;
    }

    debugPrint(
      'AcousticScanService: Processing recording...',
    );

    // -------------------------------------------------------------------------
    // PROCESS AUDIO
    // -------------------------------------------------------------------------

    final MathematicalRepresentation
    mathematicalRepresentation =
    await _processAudioData(
      recordingPath,
    );

    // -------------------------------------------------------------------------
    // CREATE METADATA
    // -------------------------------------------------------------------------

    final ScanMetadata metadata =
    ScanMetadata(
      startTime: startTime,
      endTime: scanEndTime,
      totalDurationMs: totalDurationMs,
      sampleRate: sampleRate,
    );

    // -------------------------------------------------------------------------
    // CREATE RESULT
    // -------------------------------------------------------------------------

    final ScanData result =
    ScanData(
      audioFilePath: recordingPath,
      metadata: metadata,
      mathematicalRepresentation:
      mathematicalRepresentation,
      spatialTimeLog:
      List<SpatialTimeLogEntry>.unmodifiable(
        _spatialTimeLog,
      ),
    );

    // Reset scan state.
    _scanStartTime = null;

    return result;
  }

  // ---------------------------------------------------------------------------
  // SPATIAL LOGGING
  // ---------------------------------------------------------------------------

  void _generateSpatialLogEntry() {
    final DateTime? startTime =
        _scanStartTime;

    if (startTime == null) {
      return;
    }

    final int timestampMs =
        DateTime.now()
            .difference(startTime)
            .inMilliseconds;

    _spatialTimeLog.add(
      SpatialTimeLogEntry(
        timestampMs: timestampMs,
        row: _currentSpatialRow,
        column: _currentSpatialColumn,
      ),
    );

    // Simulate zigzag movement.
    if (_zigzagForward) {
      _currentSpatialColumn++;

      if (_currentSpatialColumn >= 10) {
        _currentSpatialColumn = 9;

        _currentSpatialRow++;

        _zigzagForward = false;
      }
    } else {
      _currentSpatialColumn--;

      if (_currentSpatialColumn < 0) {
        _currentSpatialColumn = 0;

        _currentSpatialRow++;

        _zigzagForward = true;
      }
    }

    // Reset after 20 rows.
    if (_currentSpatialRow >= 20) {
      _currentSpatialRow = 0;

      _currentSpatialColumn = 0;

      _zigzagForward = true;
    }
  }

  // ---------------------------------------------------------------------------
  // AUDIO PROCESSING
  // ---------------------------------------------------------------------------

  Future<MathematicalRepresentation>
  _processAudioData(
      String filePath,
      ) async {
    final File audioFile =
    File(filePath);

    if (!await audioFile.exists()) {
      debugPrint(
        'Audio file not found: $filePath',
      );

      return MathematicalRepresentation(
        spectrumMatrix: [],
        energyProfile: [],
      );
    }

    final Uint8List bytes =
    await audioFile.readAsBytes();

    // Debug: hex dump first 32 bytes to see actual file format.
    final String hexDump = bytes.sublist(0, min(32, bytes.length)).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    debugPrint('Audio processing: First ${min(32, bytes.length)} bytes: $hexDump');

    // Try parsing as WAV first.
    int pcmDataOffset = 0;
    final int? wavOffset = _findWavDataChunkOffset(bytes);

    if (wavOffset != null) {
      pcmDataOffset = wavOffset;
      debugPrint('Audio processing: Using WAV data chunk at offset $pcmDataOffset');
    } else {
      debugPrint('Audio processing: WAV headers not found, treating file as raw 16-bit PCM data.');
      pcmDataOffset = 0;
    }

    if (bytes.length - pcmDataOffset < 4) {
      debugPrint('Audio processing: Not enough PCM data.');
      return MathematicalRepresentation(
        spectrumMatrix: [],
        energyProfile: [],
      );
    }

    final ByteData byteData =
    ByteData.sublistView(bytes);

    final List<double> audioSamples =
    [];

    for (
    int i = pcmDataOffset;
    i + 1 < bytes.length;
    i += 2
    ) {
      final int sample =
      byteData.getInt16(
        i,
        Endian.little,
      );

      audioSamples.add(
        sample / 32768.0,
      );
    }

    if (audioSamples.isEmpty) {
      return MathematicalRepresentation(
        spectrumMatrix: [],
        energyProfile: [],
      );
    }

    // -------------------------------------------------------------------------
    // STFT PARAMETERS
    // -------------------------------------------------------------------------

    const int windowSize = 1024;
    const int hopSize = 512;

    if (audioSamples.length <
        windowSize) {
      return MathematicalRepresentation(
        spectrumMatrix: [],
        energyProfile: [],
      );
    }

    final List<List<double>>
    spectrumMatrix = [];

    final List<double>
    energyProfile = [];

    // -------------------------------------------------------------------------
    // HANN WINDOW
    // -------------------------------------------------------------------------

    final List<double> hannWindow =
    List<double>.generate(
      windowSize,
          (int i) {
        return 0.5 *
            (1 -
                cos(
                  (2 * pi * i) /
                      (windowSize - 1),
                ));
      },
    );

    // -------------------------------------------------------------------------
    // PROCESS EACH FRAME
    // -------------------------------------------------------------------------

    for (
    int i = 0;
    i + windowSize <=
        audioSamples.length;
    i += hopSize
    ) {
      final List<double> frame =
      List<double>.generate(
        windowSize,
            (int j) {
          return audioSamples[i + j] *
              hannWindow[j];
        },
      );

      // Calculate frequency spectrum.
      final List<double> magnitudes =
      _performDFT(frame);

      if (magnitudes.isEmpty) {
        continue;
      }

      // -----------------------------------------------------------------------
      // RMS ENERGY
      // -----------------------------------------------------------------------

      double sumSquares = 0.0;

      for (final double sample
      in frame) {
        sumSquares +=
            sample * sample;
      }

      final double rms =
      sqrt(
        sumSquares /
            frame.length,
      );

      // -----------------------------------------------------------------------
      // PEAK FREQUENCY
      // -----------------------------------------------------------------------

      int maxMagnitudeIndex = 1;

      for (
      int k = 2;
      k < magnitudes.length;
      k++
      ) {
        if (magnitudes[k] >
            magnitudes[
            maxMagnitudeIndex]) {
          maxMagnitudeIndex = k;
        }
      }

      final double frequencyResolution =
          sampleRate / windowSize;

      final double peakFrequencyHz =
          maxMagnitudeIndex *
              frequencyResolution;

      // -----------------------------------------------------------------------
      // FUNDAMENTAL ENERGY
      // -----------------------------------------------------------------------

      const double bandWidth =
      500.0;

      final int fundamentalBinStart =
      max(
        0,
        ((fundamentalFrequency -
            bandWidth) /
            frequencyResolution)
            .floor(),
      );

      final int fundamentalBinEnd =
      min(
        magnitudes.length - 1,
        ((fundamentalFrequency +
            bandWidth) /
            frequencyResolution)
            .ceil(),
      );

      double fundamentalEnergy = 0.0;

      for (
      int k =
          fundamentalBinStart;
      k <= fundamentalBinEnd;
      k++
      ) {
        fundamentalEnergy +=
            magnitudes[k] *
                magnitudes[k];
      }

      // -----------------------------------------------------------------------
      // TOTAL ENERGY
      // -----------------------------------------------------------------------

      double totalEnergy = 0.0;

      for (final double magnitude
      in magnitudes) {
        totalEnergy +=
            magnitude * magnitude;
      }

      // -----------------------------------------------------------------------
      // HARMONIC ENERGY RATIO
      // -----------------------------------------------------------------------

      final double harmonicEnergyRatio =
      totalEnergy > 0
          ? (fundamentalEnergy /
          totalEnergy)
          .clamp(
        0.0,
        1.0,
      )
          : 0.0;

      // -----------------------------------------------------------------------
      // STORE FEATURES
      // -----------------------------------------------------------------------

      spectrumMatrix.add([
        rms,
        peakFrequencyHz,
        harmonicEnergyRatio,
      ]);

      energyProfile.add(rms);
    }

    return MathematicalRepresentation(
      spectrumMatrix: spectrumMatrix,
      energyProfile: energyProfile,
    );
  }

  // ---------------------------------------------------------------------------
  // WAV DATA CHUNK FINDER
  // ---------------------------------------------------------------------------

  /// Finds the offset of the 'data' chunk in a WAV file.
  /// Assumes the input bytes are a valid WAV file.
  int? _findWavDataChunkOffset(Uint8List bytes) {
    if (bytes.length < 12) {
      debugPrint('WAV parsing: File too small (less than 12 bytes). Length: ${bytes.length}');
      return null;
    }

    final String riff = String.fromCharCodes(bytes.sublist(0, 4));
    final String wave = String.fromCharCodes(bytes.sublist(8, 12));

    if (riff != 'RIFF' || wave != 'WAVE') {
      debugPrint('WAV parsing: Not a valid RIFF WAV file. RIFF ID: $riff, WAVE ID: $wave');
      return null;
    }

    // Start searching for chunks after the main header
    int offset = 12;
    debugPrint('WAV parsing: Starting chunk scan from offset $offset.');
    while (offset + 8 <= bytes.length) {
      final String chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final int chunkSize = ByteData.sublistView(bytes).getUint32(offset + 4, Endian.little);

      debugPrint('WAV parsing: Found chunk ID: ''$chunkId'', size: $chunkSize, header offset: $offset');

      if (chunkId == 'data') {
        debugPrint('WAV parsing: *** Found data chunk at offset: ${offset + 8} ***');
        return offset + 8;
      }

      offset += 8 + chunkSize;
      if (chunkSize.isOdd) {
        offset++;
      }
    }
    debugPrint('WAV parsing: Data chunk not found after searching all chunks.');
    return null;
  }

  // ---------------------------------------------------------------------------
  // DFT
  // ---------------------------------------------------------------------------

  List<double> _performDFT(
      List<double> samples,
      ) {
    final int n =
        samples.length;

    if (n == 0) {
      return [];
    }

    final int halfN =
        n ~/ 2;

    final List<double> magnitudes =
    List<double>.filled(
      halfN,
      0.0,
    );

    for (
    int k = 0;
    k < halfN;
    k++
    ) {
      double real = 0.0;
      double imag = 0.0;

      for (
      int sampleIndex = 0;
      sampleIndex < n;
      sampleIndex++
      ) {
        final double angle =
            2 *
                pi *
                k *
                sampleIndex /
                n;

        real +=
            samples[sampleIndex] *
                cos(angle);

        imag -=
            samples[sampleIndex] *
                sin(angle);
      }

      magnitudes[k] =
          sqrt(
            real * real +
                imag * imag,
          );
    }

    return magnitudes;
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    _spatialLogTimer?.cancel();

    _spatialLogTimer = null;

    try {
      await _audioPlayer.stop();
    } catch (_) {}

    await _audioPlayer.dispose();

    await _audioRecorder.dispose();

    _isScanning = false;

    _scanStartTime = null;
  }
}