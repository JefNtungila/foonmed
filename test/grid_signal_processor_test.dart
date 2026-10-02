import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:foonmed/models/accel_sample.dart';
import 'package:foonmed/services/grid_signal_processor.dart';

void main() {
  group('removeMean', () {
    test('centers a constant signal to zero', () {
      final result = GridSignalProcessor.removeMean([5, 5, 5, 5]);
      expect(result, everyElement(closeTo(0, 1e-9)));
    });

    test('preserves signal shape', () {
      final result = GridSignalProcessor.removeMean([1, 2, 3]);
      expect(result[0], closeTo(-1, 1e-9));
      expect(result[2], closeTo(1, 1e-9));
    });

    test('returns empty list for empty input', () {
      expect(GridSignalProcessor.removeMean(const []), isEmpty);
    });
  });

  group('computeRms', () {
    test('constant signal returns its magnitude', () {
      expect(GridSignalProcessor.computeRms([3, 3, 3]), closeTo(3, 1e-9));
    });

    test('sine wave returns amplitude / sqrt(2)', () {
      final samples = [
        for (var i = 0; i < 200; i++)
          2.0 * math.sin(i * 2 * math.pi / 100),
      ];
      expect(
        GridSignalProcessor.computeRms(samples),
        closeTo(2 / math.sqrt2, 0.01),
      );
    });

    test('empty input returns zero', () {
      expect(GridSignalProcessor.computeRms(const []), 0.0);
    });
  });

  group('estimateSampleRateHz', () {
    test('computes rate from spaced timestamps', () {
      final start = DateTime(2026, 1, 1);
      final samples = [
        for (var i = 0; i < 51; i++)
          AccelSample(
            x: 0,
            y: 0,
            z: 0,
            timestamp: start.add(Duration(milliseconds: i * 20)),
          ),
      ];
      expect(
        GridSignalProcessor.estimateSampleRateHz(samples),
        closeTo(50, 0.01),
      );
    });

    test('fewer than two samples returns zero', () {
      final sample = AccelSample(
        x: 0,
        y: 0,
        z: 0,
        timestamp: DateTime(2026, 1, 1),
      );
      expect(GridSignalProcessor.estimateSampleRateHz([sample]), 0.0);
      expect(GridSignalProcessor.estimateSampleRateHz(const []), 0.0);
    });
  });

  group('computeCell', () {
    test('removes gravity DC offset from Z and combines axes', () {
      final start = DateTime(2026, 1, 1);
      final samples = [
        for (var i = 0; i < 25; i++)
          AccelSample(
            x: i.isEven ? 1.0 : -1.0,
            y: 0,
            z: 9.81 + (i.isEven ? 1.0 : -1.0),
            timestamp: start.add(Duration(milliseconds: i * 20)),
          ),
      ];
      final signal = GridSignalProcessor.computeCell(
        samples,
        warmupDiscardMs: 0,
        minSamples: 10,
      );
      expect(signal.rmsX, closeTo(1.0, 0.01));
      expect(signal.rmsY, 0.0);
      expect(signal.rmsZ, closeTo(1.0, 0.01),
          reason: 'gravity (9.81) must be removed as DC offset');
      expect(
        signal.contactRms,
        closeTo(math.sqrt(2.0), 0.01),
      );
      expect(signal.samples, 25);
      expect(signal.sampleRateHz, closeTo(50, 0.01));
    });

    test('discards warmup samples before computing RMS', () {
      final start = DateTime(2026, 1, 1);
      final samples = [
        for (var i = 0; i < 25; i++)
          AccelSample(
            x: (i.isEven ? 1.0 : -1.0) * (i < 8 ? 50.0 : 1.0),
            y: 0,
            z: 9.81 + (i.isEven ? 1.0 : -1.0) * (i < 8 ? 50.0 : 1.0),
            timestamp: start.add(Duration(milliseconds: i * 20)),
          ),
      ];
      final signal = GridSignalProcessor.computeCell(
        samples,
        warmupDiscardMs: 150,
        minSamples: 5,
      );
      expect(signal.samples, 17);
      expect(
        signal.rmsX,
        closeTo(1.0, 0.05),
        reason: 'transient spin-up samples must be excluded',
      );
    });

    test('throws when sample count is below minimum', () {
      final start = DateTime(2026, 1, 1);
      final samples = [
        for (var i = 0; i < 3; i++)
          AccelSample(
            x: 1,
            y: 0,
            z: 9.81,
            timestamp: start.add(Duration(milliseconds: i * 20)),
          ),
      ];
      expect(
        () => GridSignalProcessor.computeCell(
          samples,
          warmupDiscardMs: 0,
          minSamples: 10,
        ),
        throwsStateError,
      );
    });
  });

  group('normalize', () {
    test('divides by baseline when baseline is positive', () {
      expect(
        GridSignalProcessor.normalize(rms: 1.5, baselineRms: 3.0),
        closeTo(0.5, 1e-9),
      );
    });

    test('guards zero baseline by returning raw rms', () {
      expect(GridSignalProcessor.normalize(rms: 1.5, baselineRms: 0.0), 1.5);
      expect(GridSignalProcessor.normalize(rms: 1.5, baselineRms: -1.0), 1.5);
    });
  });

  group('normalizeMatrix / flatten', () {
    test('normalizes every cell and flattens row-major', () {
      final matrix = [
        [2.0, 4.0],
        [6.0, 8.0],
      ];
      final normalized =
          GridSignalProcessor.normalizeMatrix(matrix, baselineRms: 2.0);
      expect(normalized, [
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      expect(GridSignalProcessor.flatten(normalized), [1.0, 2.0, 3.0, 4.0]);
    });
  });
}
