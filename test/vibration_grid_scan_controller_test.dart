import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foonmed/controllers/vibration_grid_scan_controller.dart';
import 'package:foonmed/models/accel_sample.dart';
import 'package:foonmed/models/contact_grid_scan.dart';
import 'package:foonmed/services/accelerometer_source.dart';
import 'package:foonmed/services/vibrator_port.dart';

class FakeVibrator implements VibratorPort {
  bool supported = true;
  int startCount = 0;
  int stopCount = 0;
  final List<int> durations = [];

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<void> start({required int durationMs}) async {
    startCount++;
    durations.add(durationMs);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class FakeAccelerometer implements AccelerometerSource {
  bool constantSignal = false;
  int streamCount = 0;

  @override
  Stream<AccelSample> sampleStream() {
    streamCount++;
    var i = 0;
    return Stream.periodic(const Duration(milliseconds: 1), (_) {
      final odd = i.isOdd;
      i++;
      if (constantSignal) {
        return AccelSample(
          x: 0,
          y: 0,
          z: 0,
          timestamp: DateTime.now(),
        );
      }
      return AccelSample(
        x: odd ? -1.0 : 1.0,
        y: 0,
        z: 9.81 + (odd ? -1.0 : 1.0),
        timestamp: DateTime.now(),
      );
    });
  }
}

const _fakeProvenance = ScanProvenance(
  platform: 'android',
  deviceModel: 'test-device',
  appVersion: '1.0.0+1',
);

VibrationGridScanController buildController({
  FakeVibrator? vibrator,
  FakeAccelerometer? accelerometer,
  int rows = 2,
  int cols = 2,
}) {
  return VibrationGridScanController(
    accelerometer: accelerometer ?? FakeAccelerometer(),
    vibrator: vibrator ?? FakeVibrator(),
    rows: rows,
    cols: cols,
    settleMs: 1,
    vibrateMs: 20,
    warmupDiscardMs: 0,
    preRollMs: 0,
    minSamples: 2,
    provenanceResolver: () async => _fakeProvenance,
  );
}

void main() {
  test('startScan rejects devices without a vibration motor', () async {
    final vibrator = FakeVibrator()..supported = false;
    final controller = buildController(vibrator: vibrator);
    addTearDown(controller.dispose);

    await controller.startScan();

    expect(controller.state, GridScanState.error);
    expect(controller.errorMessage, contains('vibration motor'));
  });

  test('full 2x2 scan walks row-major and completes', () async {
    final vibrator = FakeVibrator();
    final accelerometer = FakeAccelerometer();
    final controller = buildController(
      vibrator: vibrator,
      accelerometer: accelerometer,
    );
    addTearDown(controller.dispose);

    await controller.startScan();
    expect(controller.state, GridScanState.awaitingBaseline);

    await controller.captureBaseline();
    expect(controller.state, GridScanState.awaitingPlacement);
    expect(controller.baselineAirRms, greaterThan(0));
    expect(controller.cellIndex, 0);

    await controller.confirmPlacement();
    expect(controller.state, GridScanState.awaitingPlacement);
    expect(controller.cellIndex, 1);
    expect(controller.currentRow, 0);
    expect(controller.currentCol, 1);
    expect(controller.progress, 0.25);

    await controller.confirmPlacement();
    expect(controller.currentRow, 1);
    expect(controller.currentCol, 0);

    await controller.confirmPlacement();
    expect(controller.cellIndex, 3);

    await controller.confirmPlacement();
    expect(controller.state, GridScanState.completed);

    final scan = controller.lastScan!;
    expect(scan.gridDimensions.rows, 2);
    expect(scan.gridDimensions.cols, 2);
    expect(scan.scanId, isNotEmpty);
    expect(scan.baselineAirRms, controller.baselineAirRms);
    expect(scan.device, _fakeProvenance);
    expect(scan.flatFeatureVector, hasLength(4));
    for (final row in scan.dataMatrix) {
      for (final value in row) {
        expect(value, greaterThan(0));
      }
    }

    expect(vibrator.startCount, 5, reason: 'baseline + 4 cells');
    expect(vibrator.durations, everyElement(20));
    expect(accelerometer.streamCount, 5);
    expect(vibrator.stopCount, greaterThanOrEqualTo(5));
  });

  test('retakeLastCell clears the previous cell and steps back', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    await controller.startScan();
    await controller.captureBaseline();
    await controller.confirmPlacement();

    expect(controller.canRetakeLastCell, isTrue);
    controller.retakeLastCell();

    expect(controller.cellIndex, 0);
    expect(controller.cellValue(0, 0), 0.0);
    expect(controller.state, GridScanState.awaitingPlacement);
  });

  test('abortScan during placement aborts and blocks confirmPlacement', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    await controller.startScan();
    await controller.captureBaseline();
    controller.abortScan();
    expect(controller.state, GridScanState.aborted);

    await controller.confirmPlacement();
    expect(controller.state, GridScanState.aborted);
  });

  test('zero-energy baseline fails the scan instead of dividing by zero',
      () async {
    final accelerometer = FakeAccelerometer()..constantSignal = true;
    final controller = buildController(accelerometer: accelerometer);
    addTearDown(controller.dispose);

    await controller.startScan();
    await controller.captureBaseline();

    expect(controller.state, GridScanState.error);
    expect(controller.errorMessage, contains('Baseline'));
    expect(controller.lastScan, isNull);
  });
}
