import 'dart:math' as math;

import '../models/accel_sample.dart';

class CellSignal {
  final double rmsX;
  final double rmsY;
  final double rmsZ;
  final double contactRms;
  final int samples;
  final double sampleRateHz;

  const CellSignal({
    required this.rmsX,
    required this.rmsY,
    required this.rmsZ,
    required this.contactRms,
    required this.samples,
    required this.sampleRateHz,
  });

  Map<String, dynamic> toJson() {
    return {
      'rms_x': rmsX,
      'rms_y': rmsY,
      'rms_z': rmsZ,
      'contact_rms': contactRms,
      'samples': samples,
      'sample_rate_hz': sampleRateHz,
    };
  }

  factory CellSignal.fromJson(Map<String, dynamic> json) {
    return CellSignal(
      rmsX: (json['rms_x'] as num).toDouble(),
      rmsY: (json['rms_y'] as num).toDouble(),
      rmsZ: (json['rms_z'] as num).toDouble(),
      contactRms: (json['contact_rms'] as num).toDouble(),
      samples: json['samples'] as int,
      sampleRateHz: (json['sample_rate_hz'] as num).toDouble(),
    );
  }
}

class GridSignalProcessor {
  const GridSignalProcessor._();

  static const int settleMs = 200;
  static const int vibrateMs = 500;
  static const int warmupDiscardMs = 150;
  static const int preRollMs = 50;
  static const int defaultRows = 5;
  static const int defaultCols = 5;
  static const int minSamplesPerCell = 10;

  static List<double> removeMean(List<double> samples) {
    if (samples.isEmpty) return const [];
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    return [for (final s in samples) s - mean];
  }

  static double computeRms(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    var sumSquares = 0.0;
    for (final s in samples) {
      sumSquares += s * s;
    }
    return math.sqrt(sumSquares / samples.length);
  }

  static double estimateSampleRateHz(List<AccelSample> samples) {
    if (samples.length < 2) return 0.0;
    final first = samples.first.timestamp.microsecondsSinceEpoch;
    final last = samples.last.timestamp.microsecondsSinceEpoch;
    final seconds = (last - first) / 1e6;
    if (seconds <= 0) return 0.0;
    return (samples.length - 1) / seconds;
  }

  static CellSignal computeCell(
    List<AccelSample> samples, {
    required int warmupDiscardMs,
    required int minSamples,
  }) {
    final warmupCutoff =
        samples.first.timestamp.add(Duration(milliseconds: warmupDiscardMs));
    final settled = [
      for (final s in samples)
        if (!s.timestamp.isBefore(warmupCutoff)) s,
    ];
    final usable = settled.length >= minSamples ? settled : samples;
    if (usable.length < minSamples) {
      throw StateError(
        'Cell capture produced ${usable.length} samples '
        '(minimum $minSamples required).',
      );
    }

    final rmsX = computeRms(removeMean([for (final s in usable) s.x]));
    final rmsY = computeRms(removeMean([for (final s in usable) s.y]));
    final rmsZ = computeRms(removeMean([for (final s in usable) s.z]));

    return CellSignal(
      rmsX: rmsX,
      rmsY: rmsY,
      rmsZ: rmsZ,
      contactRms: math.sqrt(rmsX * rmsX + rmsY * rmsY + rmsZ * rmsZ),
      samples: usable.length,
      sampleRateHz: estimateSampleRateHz(usable),
    );
  }

  static double normalize({required double rms, required double baselineRms}) {
    if (baselineRms <= 0 || baselineRms.isNaN || rms.isNaN) return rms;
    return rms / baselineRms;
  }

  static List<List<double>> normalizeMatrix(
    List<List<double>> matrix, {
    required double baselineRms,
  }) {
    return [
      for (final row in matrix)
        [for (final v in row) normalize(rms: v, baselineRms: baselineRms)],
    ];
  }

  static List<double> flatten(List<List<double>> matrix) {
    return [for (final row in matrix) ...row];
  }
}
