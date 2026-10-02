import 'dart:convert';

import '../services/grid_signal_processor.dart';

class GridDimensions {
  final int rows;
  final int cols;

  const GridDimensions({required this.rows, required this.cols});

  int get cellCount => rows * cols;

  Map<String, dynamic> toJson() => {'rows': rows, 'cols': cols};

  factory GridDimensions.fromJson(Map<String, dynamic> json) {
    return GridDimensions(rows: json['rows'] as int, cols: json['cols'] as int);
  }
}

class CaptureSettings {
  final int settleMs;
  final int vibrateMs;
  final int warmupDiscardMs;
  final int preRollMs;
  final int minSamplesPerCell;

  const CaptureSettings({
    required this.settleMs,
    required this.vibrateMs,
    required this.warmupDiscardMs,
    required this.preRollMs,
    required this.minSamplesPerCell,
  });

  factory CaptureSettings.defaults() => const CaptureSettings(
        settleMs: GridSignalProcessor.settleMs,
        vibrateMs: GridSignalProcessor.vibrateMs,
        warmupDiscardMs: GridSignalProcessor.warmupDiscardMs,
        preRollMs: GridSignalProcessor.preRollMs,
        minSamplesPerCell: GridSignalProcessor.minSamplesPerCell,
      );

  Map<String, dynamic> toJson() {
    return {
      'settle_ms': settleMs,
      'vibrate_ms': vibrateMs,
      'warmup_discard_ms': warmupDiscardMs,
      'pre_roll_ms': preRollMs,
      'min_samples_per_cell': minSamplesPerCell,
    };
  }
}

class ScanProvenance {
  final String platform;
  final String deviceModel;
  final String appVersion;

  const ScanProvenance({
    required this.platform,
    required this.deviceModel,
    required this.appVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'model': deviceModel,
      'app_version': appVersion,
    };
  }

  factory ScanProvenance.fromJson(Map<String, dynamic> json) {
    return ScanProvenance(
      platform: json['platform'] as String,
      deviceModel: json['model'] as String,
      appVersion: json['app_version'] as String,
    );
  }
}

class ContactGridScan {
  final String scanId;
  final DateTime timestamp;
  final String targetType;
  final GridDimensions gridDimensions;
  final String scanDirection;
  final double baselineAirRms;
  final CaptureSettings capture;
  final ScanProvenance device;
  final List<List<double>> dataMatrix;
  final List<List<CellSignal>> cellStats;

  const ContactGridScan({
    required this.scanId,
    required this.timestamp,
    required this.targetType,
    required this.gridDimensions,
    required this.scanDirection,
    required this.baselineAirRms,
    required this.capture,
    required this.device,
    required this.dataMatrix,
    required this.cellStats,
  });

  static const String kTargetType = 'hand_palmar';
  static const String kScanDirection = 'top_left_to_bottom_right';
  static const String kAxisMode = 'vector_norm';

  List<List<double>> get normalizedMatrix => GridSignalProcessor.normalizeMatrix(
        dataMatrix,
        baselineRms: baselineAirRms,
      );

  List<double> get flatFeatureVector =>
      GridSignalProcessor.flatten(normalizedMatrix);

  Map<String, dynamic> toJson() {
    return {
      'scan_id': scanId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'target_type': targetType,
      'grid_dimensions': gridDimensions.toJson(),
      'scan_direction': scanDirection,
      'baseline_air_rms': baselineAirRms,
      'capture': capture.toJson(),
      'sensor': {
        'axis_mode': kAxisMode,
      },
      'device': device.toJson(),
      'data_matrix': dataMatrix,
      'cell_stats': [
        for (final row in cellStats) [for (final c in row) c.toJson()],
      ],
      'flat_feature_vector': flatFeatureVector,
    };
  }

  String toJsonString({bool pretty = true}) {
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(toJson());
    }
    return jsonEncode(toJson());
  }

  factory ContactGridScan.fromJson(Map<String, dynamic> json) {
    return ContactGridScan(
      scanId: json['scan_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      targetType: json['target_type'] as String,
      gridDimensions: GridDimensions.fromJson(
        json['grid_dimensions'] as Map<String, dynamic>,
      ),
      scanDirection: json['scan_direction'] as String,
      baselineAirRms: (json['baseline_air_rms'] as num).toDouble(),
      capture: CaptureSettings(
        settleMs: json['capture']['settle_ms'] as int,
        vibrateMs: json['capture']['vibrate_ms'] as int,
        warmupDiscardMs: json['capture']['warmup_discard_ms'] as int,
        preRollMs: json['capture']['pre_roll_ms'] as int,
        minSamplesPerCell: json['capture']['min_samples_per_cell'] as int,
      ),
      device: ScanProvenance.fromJson(
        json['device'] as Map<String, dynamic>,
      ),
      dataMatrix: [
        for (final row in json['data_matrix'] as List)
          [for (final v in row as List) (v as num).toDouble()],
      ],
      cellStats: [
        for (final row in json['cell_stats'] as List)
          [
            for (final c in row as List)
              CellSignal.fromJson(c as Map<String, dynamic>),
          ],
      ],
    );
  }
}
