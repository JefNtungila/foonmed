import 'dart:math';

// ---------------------------------------------------------------------------
// TUNABLE CONSTANTS
//
// No labelled training data is available yet, so these are conservative
// defaults. Validate against known-good / known-cracked recordings and
// adjust before trusting field results.
// ---------------------------------------------------------------------------

/// Frames with RMS below this are treated as silence (not a measurement)
/// and excluded from analysis so leading/trailing silence cannot pollute
/// the baseline or fake an energy-drop anomaly.
const double kNoiseFloorRms = 0.002;

/// Leading analyzed frames skipped after the first non-silent frame so the
/// excitation tone can ramp up before statistics are gathered.
const int kWarmupFrames = 10;

/// Aggregation window used for the persistence gate (ms).
const int kSegmentDurationMs = 500;

/// Minimum anomalous 0.5 s segments required before a crack can be
/// reported (persistence gate).
const int kMinAnomalousSegments = 3;

/// Number of anomalous segments at which the persistence factor saturates.
const int kFullPersistenceSegments = 6;

/// Robust z-score magnitude required for a feature to contribute
/// meaningfully to the frame score.
const double kZThreshold = 3.0;

/// Per-frame z-scores are clamped here to keep sigmoids numerically sane.
const double kZCap = 20.0;

/// A segment counts as anomalous when the mean of its top-quartile frame
/// scores reaches this value.
const double kSegmentScoreThreshold = 0.45;

/// Score >= this reports a crack; >= kScoreInconclusiveThreshold reports
/// inconclusive; below that reports no crack.
const double kScoreCrackThreshold = 0.7;
const double kScoreInconclusiveThreshold = 0.4;

/// When the persistence gate fails, the score is capped to this value so
/// the reported score can never contradict the NONE verdict.
const double kScoreGateCap = 0.35;

/// Minimum analyzed frames before statistics are trusted at all.
const int kMinAnalyzedFrames = 30;

/// Per-feature MAD floors (guard against division by ~0 on flat signals).
const double kMinScaleRmsDb = 0.5;
const double kMinScaleRatio = 1e-4;
const double kMinScalePeakHz = 5.0;

/// Weights for combining per-feature anomaly strengths (sum = 1.0).
const Map<String, double> kFeatureWeights = {
  'rmsDb': 0.25,
  'harmonicRatio': 0.30,
  'sidebandRatio': 0.20,
  'secondHarmonicRatio': 0.15,
  'peakDeviationHz': 0.10,
};

/// Direction of anomaly per feature: +1 means growth is anomalous,
/// -1 means collapse is anomalous.
const Map<String, int> kFeatureDirections = {
  'rmsDb': -1,
  'harmonicRatio': -1,
  'sidebandRatio': 1,
  'secondHarmonicRatio': 1,
  'peakDeviationHz': 1,
};

enum Verdict { none, inconclusive, crack }

// ---------------------------------------------------------------------------
// RESULT MODELS
// ---------------------------------------------------------------------------

class AnomalySegment {
  const AnomalySegment({
    required this.startMs,
    required this.endMs,
    required this.dominantFeature,
    required this.score,
  });

  final int startMs;
  final int endMs;
  final String dominantFeature;
  final double score;

  Map<String, dynamic> toJson() {
    return {
      'startMs': startMs,
      'endMs': endMs,
      'dominantFeature': dominantFeature,
      'score': score,
    };
  }

  factory AnomalySegment.fromJson(Map<String, dynamic> json) {
    return AnomalySegment(
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 0,
      dominantFeature: json['dominantFeature'] as String? ?? 'unknown',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DetectionResult {
  const DetectionResult({
    required this.verdict,
    required this.score,
    required this.confidence,
    required this.segments,
    required this.featureScores,
  });

  /// Result used when there is too little signal to analyze anything.
  const DetectionResult.empty()
      : verdict = Verdict.none,
        score = 0.0,
        confidence = 0.0,
        segments = const [],
        featureScores = const {};

  final Verdict verdict;
  final double score;
  final double confidence;
  final List<AnomalySegment> segments;

  /// Mean direction-adjusted z-score per feature (positive = anomalous).
  final Map<String, double> featureScores;

  bool get crackDetected => verdict == Verdict.crack;

  Map<String, dynamic> toJson() {
    return {
      'verdict': verdict.name,
      'score': score,
      'confidence': confidence,
      'segments': segments.map((segment) => segment.toJson()).toList(),
      'featureScores': featureScores,
    };
  }

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      verdict: Verdict.values.firstWhere(
        (value) => value.name == json['verdict'],
        orElse: () => Verdict.none,
      ),
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      segments: ((json['segments'] as List?) ?? const [])
          .map((entry) =>
              AnomalySegment.fromJson(entry as Map<String, dynamic>))
          .toList(),
      featureScores: ((json['featureScores'] as Map?) ?? const {})
          .map((key, value) =>
              MapEntry(key as String, (value as num).toDouble())),
    );
  }
}

// ---------------------------------------------------------------------------
// DETECTION
// ---------------------------------------------------------------------------

/// Analyzes per-frame features extracted by the acoustic scan pipeline and
/// returns a crack verdict.
///
/// [features] rows are expected to be
/// `[rms, peakFrequencyHz, harmonicRatio, sidebandRatio, secondHarmonicRatio, spectralFlatness]`
/// as produced by `AcousticScanService._processAudioData`.
///
/// Method: robust (median/MAD) z-scores per feature, direction-adjusted so
/// positive always means "anomalous", combined into a per-frame score via
/// weighted sigmoids, aggregated into 0.5 s segments, gated by persistence
/// (>= 3 anomalous segments), and mapped to a verdict by score.
DetectionResult detect({
  required List<List<double>> features,
  required int sampleRate,
  required int hopSize,
  required double fundamentalFrequency,
}) {
  if (features.isEmpty || sampleRate <= 0 || hopSize <= 0) {
    return const DetectionResult.empty();
  }

  final double frameDurationMs = hopSize * 1000.0 / sampleRate;

  // -------------------------------------------------------------------------
  // COLLECT NON-SILENT FRAMES (original frame indices keep timestamps honest)
  // -------------------------------------------------------------------------

  final List<double> rmsValues = [];
  final List<double> peakValues = [];
  final List<double> harmonicValues = [];
  final List<double> sidebandValues = [];
  final List<double> secondHarmonicValues = [];
  final List<double> frameTimesMs = [];

  for (int i = 0; i < features.length; i++) {
    final List<double> row = features[i];
    if (row.length < 6) {
      continue;
    }

    final double rms = row[0];
    if (rms < kNoiseFloorRms || !rms.isFinite) {
      continue;
    }

    rmsValues.add(rms);
    peakValues.add(row[1]);
    harmonicValues.add(row[2]);
    sidebandValues.add(row[3]);
    secondHarmonicValues.add(row[4]);
    frameTimesMs.add(i * frameDurationMs);
  }

  // Discard the tone ramp-up frames.
  if (rmsValues.length <= kWarmupFrames) {
    return const DetectionResult.empty();
  }

  rmsValues.removeRange(0, kWarmupFrames);
  peakValues.removeRange(0, kWarmupFrames);
  harmonicValues.removeRange(0, kWarmupFrames);
  sidebandValues.removeRange(0, kWarmupFrames);
  secondHarmonicValues.removeRange(0, kWarmupFrames);
  frameTimesMs.removeRange(0, kWarmupFrames);

  final int frameCount = rmsValues.length;
  if (frameCount < kMinAnalyzedFrames) {
    return const DetectionResult.empty();
  }

  // -------------------------------------------------------------------------
  // DERIVED FEATURE SERIES
  // -------------------------------------------------------------------------

  final Map<String, List<double>> featureValues = {
    'rmsDb': rmsValues
        .map((value) => 20.0 * log(max(value, 1e-12)) / ln10)
        .toList(),
    'harmonicRatio': harmonicValues,
    'sidebandRatio': sidebandValues,
    'secondHarmonicRatio': secondHarmonicValues,
    'peakDeviationHz': peakValues
        .map((value) => (value - fundamentalFrequency).abs())
        .toList(),
  };

  final Map<String, double> minScales = {
    'rmsDb': kMinScaleRmsDb,
    'harmonicRatio': kMinScaleRatio,
    'sidebandRatio': kMinScaleRatio,
    'secondHarmonicRatio': kMinScaleRatio,
    'peakDeviationHz': kMinScalePeakHz,
  };

  // -------------------------------------------------------------------------
  // ROBUST Z-SCORES PER FEATURE (direction-adjusted: positive = anomalous)
  // -------------------------------------------------------------------------

  final Map<String, List<double>> anomalyStrength = {};

  for (final String name in kFeatureWeights.keys) {
    final List<double> values = featureValues[name]!;
    final double median = _median(values);
    final double mad = _median(
      values.map((value) => (value - median).abs()).toList(),
    );
    final double scale = max(1.4826 * mad, minScales[name]!);
    final int direction = kFeatureDirections[name]!;

    anomalyStrength[name] = values
        .map((value) =>
            (direction * (value - median) / scale).clamp(-kZCap, kZCap))
        .toList();
  }

  // -------------------------------------------------------------------------
  // PER-FRAME WEIGHTED SIGMOID SCORE
  // -------------------------------------------------------------------------

  final List<double> frameScores = List<double>.filled(frameCount, 0.0);

  for (int frame = 0; frame < frameCount; frame++) {
    double score = 0.0;

    for (final MapEntry<String, double> entry in kFeatureWeights.entries) {
      final double strength = anomalyStrength[entry.key]![frame];
      score += entry.value * _sigmoid(strength - kZThreshold);
    }

    frameScores[frame] = score;
  }

  // -------------------------------------------------------------------------
  // 0.5 s SEGMENTATION
  // -------------------------------------------------------------------------

  final Map<int, List<int>> framesBySegment = {};
  for (int frame = 0; frame < frameCount; frame++) {
    final int segmentIndex =
        (frameTimesMs[frame] / kSegmentDurationMs).floor();
    framesBySegment.putIfAbsent(segmentIndex, () => []).add(frame);
  }

  final List<int> segmentIndices = framesBySegment.keys.toList()..sort();

  final List<_SegmentStat> anomalousSegments = [];
  for (final int segmentIndex in segmentIndices) {
    final List<int> frames = framesBySegment[segmentIndex]!;
    final List<double> sortedScores =
        frames.map((frame) => frameScores[frame]).toList()..sortDescending();

    final int topCount = max(1, (frames.length / 4).ceil());
    final double topMean = sortedScores
        .take(topCount)
        .reduce((a, b) => a + b) /
        topCount;

    if (topMean >= kSegmentScoreThreshold) {
      anomalousSegments.add(_SegmentStat(segmentIndex, topMean, frames));
    }
  }

  // -------------------------------------------------------------------------
  // MERGE CONSECUTIVE ANOMALOUS SEGMENTS
  // -------------------------------------------------------------------------

  final List<List<_SegmentStat>> mergedGroups = [];
  for (final _SegmentStat stat in anomalousSegments) {
    if (mergedGroups.isNotEmpty &&
        mergedGroups.last.last.segmentIndex == stat.segmentIndex - 1) {
      mergedGroups.last.add(stat);
    } else {
      mergedGroups.add([stat]);
    }
  }

  final List<AnomalySegment> segments = mergedGroups.map((group) {
    final List<int> frames = group.expand((stat) => stat.frames).toList();

    String dominantFeature = kFeatureWeights.keys.first;
    double dominantStrength = double.negativeInfinity;

    for (final String name in kFeatureWeights.keys) {
      double total = 0.0;
      for (final int frame in frames) {
        total += anomalyStrength[name]![frame];
      }
      final double meanStrength = total / frames.length;
      if (meanStrength > dominantStrength) {
        dominantStrength = meanStrength;
        dominantFeature = name;
      }
    }

    final double groupScore =
        group.map((stat) => stat.score).reduce((a, b) => a + b) /
            group.length;

    return AnomalySegment(
      startMs: frameTimesMs[frames.first].round(),
      endMs: (frameTimesMs[frames.last] + frameDurationMs).round(),
      dominantFeature: dominantFeature,
      score: groupScore,
    );
  }).toList();

  // -------------------------------------------------------------------------
  // SCORE, PERSISTENCE GATE, VERDICT
  // -------------------------------------------------------------------------

  final int anomalousCount = anomalousSegments.length;
  final bool gatePassed = anomalousCount >= kMinAnomalousSegments;

  final double intensity = anomalousCount == 0
      ? 0.0
      : anomalousSegments
              .map((stat) => stat.score)
              .reduce((a, b) => a + b) /
          anomalousCount;

  final double persistence =
      0.7 + 0.3 * ((anomalousCount - kMinAnomalousSegments) /
                  (kFullPersistenceSegments - kMinAnomalousSegments))
              .clamp(0.0, 1.0);

  double score = intensity * persistence;
  if (!gatePassed) {
    score = min(score, kScoreGateCap);
  }
  score = score.clamp(0.0, 1.0);

  final Verdict verdict;
  if (score > kScoreCrackThreshold) {
    verdict = Verdict.crack;
  } else if (score >= kScoreInconclusiveThreshold) {
    verdict = Verdict.inconclusive;
  } else {
    verdict = Verdict.none;
  }

  double confidence;
  switch (verdict) {
    case Verdict.crack:
      confidence = score;
      break;
    case Verdict.none:
      confidence = 1.0 - score;
      break;
    case Verdict.inconclusive:
      final double halfBand =
          (kScoreCrackThreshold - kScoreInconclusiveThreshold) / 2;
      confidence = min(
        score - kScoreInconclusiveThreshold,
        kScoreCrackThreshold - score,
      ).clamp(0.0, halfBand) /
          halfBand;
      break;
  }
  confidence = confidence.clamp(0.0, 1.0);

  // -------------------------------------------------------------------------
  // PER-FEATURE SUMMARY SCORES
  // -------------------------------------------------------------------------

  final Set<int> anomalousFrames = anomalousSegments
      .expand((stat) => stat.frames)
      .toSet();
  final List<int> reportingFrames = anomalousFrames.isEmpty
      ? List<int>.generate(frameCount, (index) => index)
      : anomalousFrames.toList();

  final Map<String, double> featureScores = {};
  for (final String name in kFeatureWeights.keys) {
    double total = 0.0;
    for (final int frame in reportingFrames) {
      total += anomalyStrength[name]![frame];
    }
    featureScores[name] = total / reportingFrames.length;
  }

  return DetectionResult(
    verdict: verdict,
    score: score,
    confidence: confidence,
    segments: segments,
    featureScores: featureScores,
  );
}

// ---------------------------------------------------------------------------
// HELPERS
// ---------------------------------------------------------------------------

class _SegmentStat {
  const _SegmentStat(this.segmentIndex, this.score, this.frames);

  final int segmentIndex;
  final double score;
  final List<int> frames;
}

double _sigmoid(double x) => 1.0 / (1.0 + exp(-x));

double _median(List<double> values) {
  if (values.isEmpty) {
    return 0.0;
  }

  final List<double> sorted = values.toList()..sort();
  final int middle = sorted.length ~/ 2;

  if (sorted.length.isOdd) {
    return sorted[middle];
  }

  return (sorted[middle - 1] + sorted[middle]) / 2.0;
}

extension on List<double> {
  void sortDescending() => sort((a, b) => b.compareTo(a));
}
