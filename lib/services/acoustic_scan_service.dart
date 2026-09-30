import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/scan_data.dart';
import 'crack_detector.dart';

class AcousticScanService {
  AcousticScanService({
    this.sampleRate = 44100,
    this.numChannels = 1,
    this.fundamentalFrequency = 5000.0,
  });

  /// STFT frame length (power of two, required by the FFT).
  static const int windowSize = 1024;

  /// STFT hop size between frames.
  static const int hopSize = 512;

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
    // CRACK DETECTION
    // -------------------------------------------------------------------------

    final DetectionResult detection = detect(
      features: mathematicalRepresentation.spectrumMatrix,
      sampleRate: sampleRate,
      hopSize: hopSize,
      fundamentalFrequency: fundamentalFrequency,
    );

    debugPrint(
      'AcousticScanService: Crack detection: '
      '${detection.verdict.name} '
      '(score: ${detection.score.toStringAsFixed(2)}, '
      'confidence: ${detection.confidence.toStringAsFixed(2)}, '
      'segments: ${detection.segments.length})',
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
      detection: detection,
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
      _performFFT(frame);

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
      // BAND ENERGIES
      // -----------------------------------------------------------------------

      const double bandWidth =
      500.0;

      final double fundamentalEnergy =
      _bandEnergy(
        magnitudes,
        fundamentalFrequency - bandWidth,
        fundamentalFrequency + bandWidth,
        frequencyResolution,
      );

      final double secondHarmonicEnergy =
      _bandEnergy(
        magnitudes,
        2 * fundamentalFrequency - bandWidth,
        2 * fundamentalFrequency + bandWidth,
        frequencyResolution,
      );

      final double sidebandEnergy =
      _bandEnergy(
            magnitudes,
            fundamentalFrequency - 3 * bandWidth,
            fundamentalFrequency - 1.2 * bandWidth,
            frequencyResolution,
          ) +
          _bandEnergy(
            magnitudes,
            fundamentalFrequency + 1.2 * bandWidth,
            fundamentalFrequency + 3 * bandWidth,
            frequencyResolution,
          );

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
      // ENERGY RATIOS + SPECTRAL FLATNESS
      // -----------------------------------------------------------------------

      double energyRatio(double energy) {
        return totalEnergy > 0
            ? (energy / totalEnergy).clamp(0.0, 1.0)
            : 0.0;
      }

      final double harmonicEnergyRatio =
      energyRatio(fundamentalEnergy);

      final double sidebandRatio =
      energyRatio(sidebandEnergy);

      final double secondHarmonicRatio =
      energyRatio(secondHarmonicEnergy);

      final double spectralFlatness =
      _spectralFlatness(magnitudes);

      // -----------------------------------------------------------------------
      // STORE FEATURES
      //
      // Row layout consumed by crack_detector.dart:
      // [rms, peakHz, harmonicRatio, sidebandRatio,
      //  secondHarmonicRatio, spectralFlatness]
      // -----------------------------------------------------------------------

      spectrumMatrix.add([
        rms,
        peakFrequencyHz,
        harmonicEnergyRatio,
        sidebandRatio,
        secondHarmonicRatio,
        spectralFlatness,
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
  // FFT
  //
  // Radix-2 Cooley-Tukey. Replaces the previous O(N^2) DFT, which was too
  // slow to process a full scan on the UI thread (dropped frames).
  // ---------------------------------------------------------------------------

  /// Returns magnitudes for bins 0..n/2-1.
  /// [samples] length must be a power of two, otherwise [] is returned.
  List<double> _performFFT(
      List<double> samples,
      ) {
    final int n =
        samples.length;

    if (n == 0 ||
        (n & (n - 1)) != 0) {
      return [];
    }

    final List<double> real =
    List<double>.from(samples);

    final List<double> imag =
    List<double>.filled(n, 0.0);

    // Bit-reversal permutation.
    for (
    int i = 1, j = 0;
    i < n;
    i++
    ) {
      int bit = n >> 1;

      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }

      j ^= bit;

      if (i < j) {
        final double tempReal = real[i];
        real[i] = real[j];
        real[j] = tempReal;

        final double tempImag = imag[i];
        imag[i] = imag[j];
        imag[j] = tempImag;
      }
    }

    // Butterfly stages.
    for (
    int length = 2;
    length <= n;
    length <<= 1
    ) {
      final double angle =
          -2 * pi / length;

      final double wReal = cos(angle);
      final double wImag = sin(angle);

      final int half = length >> 1;

      for (
      int i = 0;
      i < n;
      i += length
      ) {
        double curReal = 1.0;
        double curImag = 0.0;

        for (
        int k = 0;
        k < half;
        k++
        ) {
          final int a = i + k;
          final int b = a + half;

          final double vReal =
              real[b] * curReal -
                  imag[b] * curImag;
          final double vImag =
              real[b] * curImag +
                  imag[b] * curReal;

          real[b] = real[a] - vReal;
          imag[b] = imag[a] - vImag;
          real[a] += vReal;
          imag[a] += vImag;

          final double nextReal =
              curReal * wReal -
                  curImag * wImag;
          curImag =
              curReal * wImag +
                  curImag * wReal;
          curReal = nextReal;
        }
      }
    }

    final int halfN = n >> 1;

    final List<double> magnitudes =
    List<double>.filled(halfN, 0.0);

    for (
    int k = 0;
    k < halfN;
    k++
    ) {
      magnitudes[k] =
          sqrt(
            real[k] * real[k] +
                imag[k] * imag[k],
          );
    }

    return magnitudes;
  }

  // ---------------------------------------------------------------------------
  // BAND ENERGY
  // ---------------------------------------------------------------------------

  /// Sum of squared magnitudes for bins covering [lowHz, highHz].
  double _bandEnergy(
      List<double> magnitudes,
      double lowHz,
      double highHz,
      double binWidthHz,
      ) {
    if (magnitudes.length < 2 ||
        highHz <= lowHz) {
      return 0.0;
    }

    final int start =
    max(
      1,
      (lowHz / binWidthHz).floor(),
    );

    final int end =
    min(
      magnitudes.length - 1,
      (highHz / binWidthHz).ceil(),
    );

    double energy = 0.0;

    for (
    int k = start;
    k <= end;
    k++
    ) {
      energy +=
          magnitudes[k] *
              magnitudes[k];
    }

    return energy;
  }

  // ---------------------------------------------------------------------------
  // SPECTRAL FLATNESS
  // ---------------------------------------------------------------------------

  /// Ratio of geometric to arithmetic mean of the magnitudes (0 = tonal,
  /// 1 = white noise). Scale-invariant.
  double _spectralFlatness(
      List<double> magnitudes,
      ) {
    if (magnitudes.length < 2) {
      return 0.0;
    }

    double logSum = 0.0;
    double sum = 0.0;
    int count = 0;

    for (
    int k = 1;
    k < magnitudes.length;
    k++
    ) {
      final double magnitude =
          max(magnitudes[k], 1e-12);

      logSum += log(magnitude);
      sum += magnitude;
      count++;
    }

    final double geometricMean =
        exp(logSum / count);

    final double arithmeticMean =
        sum / count;

    if (arithmeticMean <= 0) {
      return 0.0;
    }

    return (
        geometricMean / arithmeticMean
    ).clamp(
      0.0,
      1.0,
    );
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