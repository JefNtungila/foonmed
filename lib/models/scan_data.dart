
import 'dart:convert';

class ScanData {
  final String audioFilePath;
  final ScanMetadata metadata;
  final MathematicalRepresentation mathematicalRepresentation;
  final List<SpatialTimeLogEntry> spatialTimeLog;

  ScanData({
    required this.audioFilePath,
    required this.metadata,
    required this.mathematicalRepresentation,
    required this.spatialTimeLog,
  });

  Map<String, dynamic> toJson() {
    return {
      'audioFilePath': audioFilePath,
      'metadata': metadata.toJson(),
      'mathematicalRepresentation': mathematicalRepresentation.toJson(),
      'spatialTimeLog': spatialTimeLog.map((e) => e.toJson()).toList(),
    };
  }

  factory ScanData.fromJson(Map<String, dynamic> json) {
    return ScanData(
      audioFilePath: json['audioFilePath'],
      metadata: ScanMetadata.fromJson(json['metadata']),
      mathematicalRepresentation: MathematicalRepresentation.fromJson(json['mathematicalRepresentation']),
      spatialTimeLog: (json['spatialTimeLog'] as List)
          .map((e) => SpatialTimeLogEntry.fromJson(e))
          .toList(),
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}

class ScanMetadata {
  final DateTime startTime;
  final DateTime endTime;
  final int totalDurationMs;
  final int sampleRate;

  ScanMetadata({
    required this.startTime,
    required this.endTime,
    required this.totalDurationMs,
    required this.sampleRate,
  });

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'totalDurationMs': totalDurationMs,
      'sampleRate': sampleRate,
    };
  }

  factory ScanMetadata.fromJson(Map<String, dynamic> json) {
    return ScanMetadata(
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      totalDurationMs: json['totalDurationMs'],
      sampleRate: json['sampleRate'],
    );
  }
}

class MathematicalRepresentation {
  final List<List<double>> spectrumMatrix; // List of frequency/amplitude vectors over time
  final List<double> energyProfile; // Normalized array of amplitude values

  MathematicalRepresentation({
    required this.spectrumMatrix,
    required this.energyProfile,
  });

  Map<String, dynamic> toJson() {
    return {
      'spectrumMatrix': spectrumMatrix,
      'energyProfile': energyProfile,
    };
  }

  factory MathematicalRepresentation.fromJson(Map<String, dynamic> json) {
    return MathematicalRepresentation(
      spectrumMatrix: (json['spectrumMatrix'] as List)
          .map((e) => (e as List).map((f) => f as double).toList())
          .toList(),
      energyProfile: (json['energyProfile'] as List).map((e) => e as double).toList(),
    );
  }
}

class SpatialTimeLogEntry {
  final int timestampMs;
  final int row;
  final int column;

  SpatialTimeLogEntry({
    required this.timestampMs,
    required this.row,
    required this.column,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestampMs': timestampMs,
      'row': row,
      'column': column,
    };
  }

  factory SpatialTimeLogEntry.fromJson(Map<String, dynamic> json) {
    return SpatialTimeLogEntry(
      timestampMs: json['timestampMs'],
      row: json['row'],
      column: json['column'],
    );
  }
}
