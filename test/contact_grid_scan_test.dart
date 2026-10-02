import 'package:flutter_test/flutter_test.dart';
import 'package:foonmed/models/contact_grid_scan.dart';
import 'package:foonmed/services/grid_signal_processor.dart';

void main() {
  ContactGridScan buildScan({double baseline = 2.0}) {
    return ContactGridScan(
      scanId: '3f1a8c2e-1111-4222-8333-abcdefabcdef',
      timestamp: DateTime.utc(2026, 10, 2, 19, 21),
      targetType: ContactGridScan.kTargetType,
      gridDimensions: const GridDimensions(rows: 5, cols: 5),
      scanDirection: ContactGridScan.kScanDirection,
      baselineAirRms: baseline,
      capture: CaptureSettings.defaults(),
      device: const ScanProvenance(
        platform: 'android',
        deviceModel: 'sdk_gphone64_arm64',
        appVersion: '1.0.0+1',
      ),
      dataMatrix: [
        for (var r = 0; r < 5; r++)
          [for (var c = 0; c < 5; c++) 1.0 + r + c * 0.1],
      ],
      cellStats: [
        for (var r = 0; r < 5; r++)
          [
            for (var c = 0; c < 5; c++)
              const CellSignal(
                rmsX: 0.5,
                rmsY: 0.1,
                rmsZ: 0.6,
                contactRms: 1.0,
                samples: 25,
                sampleRateHz: 50.0,
              ),
          ],
      ],
    );
  }

  test('flat feature vector is row-major normalized matrix', () {
    final scan = buildScan();
    final flat = scan.flatFeatureVector;
    expect(flat, hasLength(25));

    var index = 0;
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 5; c++) {
        expect(flat[index], closeTo(scan.dataMatrix[r][c] / 2.0, 1e-9));
        index++;
      }
    }
  });

  test('zero baseline does not divide by zero', () {
    final scan = buildScan(baseline: 0.0);
    expect(scan.flatFeatureVector.every((v) => v.isFinite), isTrue);
    expect(scan.flatFeatureVector.first, scan.dataMatrix.first.first);
  });

  test('toJson contains the ML ingestion contract', () {
    final json = buildScan().toJson();
    expect(json['scan_id'], '3f1a8c2e-1111-4222-8333-abcdefabcdef');
    expect(json['timestamp'], '2026-10-02T19:21:00.000Z');
    expect(json['target_type'], 'hand_palmar');
    expect(json['grid_dimensions'], {'rows': 5, 'cols': 5});
    expect(json['scan_direction'], 'top_left_to_bottom_right');
    expect(json['baseline_air_rms'], 2.0);
    expect(json['data_matrix'], hasLength(5));
    expect(json['data_matrix'][0], hasLength(5));
    expect(json['flat_feature_vector'], hasLength(25));
    expect(json['cell_stats'], hasLength(5));
    expect(json['capture'], isA<Map<String, dynamic>>());
    expect(json['device'], isA<Map<String, dynamic>>());
    expect(json['sensor'], isA<Map<String, dynamic>>());
  });

  test('JSON round trip preserves content', () {
    final scan = buildScan();
    final restored = ContactGridScan.fromJson(scan.toJson());
    expect(restored.scanId, scan.scanId);
    expect(restored.timestamp, scan.timestamp);
    expect(restored.gridDimensions.rows, 5);
    expect(restored.baselineAirRms, scan.baselineAirRms);
    expect(restored.dataMatrix, scan.dataMatrix);
    expect(restored.flatFeatureVector, scan.flatFeatureVector);
    expect(restored.cellStats[0][0].samples, 25);
    expect(restored.device.deviceModel, 'sdk_gphone64_arm64');
  });

  test('toJsonString produces parseable JSON', () {
    final text = buildScan().toJsonString();
    expect(text, contains('"scan_id"'));
    expect(text, contains('\n'), reason: 'pretty printed');
  });
}
