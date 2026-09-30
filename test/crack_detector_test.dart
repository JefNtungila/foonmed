import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:foonmed/services/crack_detector.dart';

const int _sampleRate = 44100;
const int _hopSize = 512;
const double _fundamental = 5000.0;

/// Builds a healthy scan: strong, stable 5 kHz response with small
/// deterministic wobble so median/MAD statistics are non-degenerate.
List<List<double>> buildBaseline(int count) {
  final Random random = Random(42);
  final List<List<double>> frames = [];

  for (int i = 0; i < count; i++) {
    frames.add([
      0.20 + 0.004 * sin(i * 0.13) + 0.002 * random.nextDouble(),
      _fundamental + 20.0 * sin(i * 0.21),
      0.985 + 0.004 * sin(i * 0.17),
      0.012 + 0.002 * sin(i * 0.11),
      0.006 + 0.001 * sin(i * 0.19),
      0.100 + 0.010 * sin(i * 0.07),
    ]);
  }

  return frames;
}

/// Overlays a crack-like signature: fundamental collapse, sideband and
/// second-harmonic growth, energy drop, peak-frequency deviation.
void applyCrack(List<List<double>> frames, int start, int length) {
  for (int i = start; i < start + length && i < frames.length; i++) {
    frames[i][0] *= 0.4; // ~ -8 dB energy drop
    frames[i][1] = _fundamental + 400.0 * sin(i * 0.3); // off-resonance peak
    frames[i][2] = 0.25; // harmonic ratio collapse
    frames[i][3] = 0.18; // sideband growth
    frames[i][4] = 0.06; // second harmonic growth
  }
}

DetectionResult runDetect(List<List<double>> features) {
  return detect(
    features: features,
    sampleRate: _sampleRate,
    hopSize: _hopSize,
    fundamentalFrequency: _fundamental,
  );
}

void main() {
  test('clean baseline reports no crack', () {
    final List<List<double>> frames = buildBaseline(600);

    // Leading silence must be ignored, not treated as an anomaly.
    for (int i = 0; i < 50; i++) {
      frames[i][0] = 0.0;
    }

    final DetectionResult result = runDetect(frames);

    expect(result.verdict, Verdict.none);
    expect(result.crackDetected, isFalse);
    expect(result.score, lessThan(kScoreInconclusiveThreshold));
    expect(result.segments, isEmpty);
    expect(result.confidence, greaterThan(0.8));
  });

  test('sustained crack signature is detected', () {
    final List<List<double>> frames = buildBaseline(800);
    applyCrack(frames, 300, 250);

    final DetectionResult result = runDetect(frames);

    expect(result.verdict, Verdict.crack);
    expect(result.crackDetected, isTrue);
    expect(result.score, greaterThan(kScoreCrackThreshold));
    expect(result.segments, isNotEmpty);
    expect(result.featureScores.keys,
        containsAll(['harmonicRatio', 'sidebandRatio', 'rmsDb']));
    expect(result.segments.first.startMs, greaterThanOrEqualTo(0));
    expect(result.segments.first.endMs,
        greaterThan(result.segments.first.startMs));
  });

  test('brief transient fails the persistence gate', () {
    final List<List<double>> frames = buildBaseline(600);
    applyCrack(frames, 300, 20); // ~0.23 s, under one segment

    final DetectionResult result = runDetect(frames);

    expect(result.verdict, Verdict.none);
    expect(result.score, lessThan(kScoreInconclusiveThreshold));
    expect(result.crackDetected, isFalse);
  });

  test('result survives a JSON round-trip', () {
    final List<List<double>> frames = buildBaseline(800);
    applyCrack(frames, 300, 250);

    final DetectionResult result = runDetect(frames);
    final DetectionResult restored =
        DetectionResult.fromJson(result.toJson());

    expect(restored.verdict, result.verdict);
    expect(restored.score, closeTo(result.score, 1e-9));
    expect(restored.confidence, closeTo(result.confidence, 1e-9));
    expect(restored.segments.length, result.segments.length);
    expect(restored.featureScores.length, result.featureScores.length);
    expect(restored.crackDetected, result.crackDetected);
  });

  test('empty input returns an empty result', () {
    final DetectionResult result = runDetect([]);

    expect(result.verdict, Verdict.none);
    expect(result.score, 0.0);
    expect(result.confidence, 0.0);
    expect(result.segments, isEmpty);
  });
}
