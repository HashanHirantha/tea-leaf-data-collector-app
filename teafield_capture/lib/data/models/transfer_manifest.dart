import 'dart:convert';

/// Manifest included in every export ZIP package.
class TransferManifest {
  final int schemaVersion;
  final String projectCode;
  final String exportDeviceId;
  final String exportTimeUtc;
  final int sampleCount;
  final int photoCount;
  final String? appVersion;

  const TransferManifest({
    this.schemaVersion = 1,
    required this.projectCode,
    required this.exportDeviceId,
    required this.exportTimeUtc,
    required this.sampleCount,
    required this.photoCount,
    this.appVersion,
  });

  factory TransferManifest.fromJson(String jsonStr) {
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    return TransferManifest(
      schemaVersion: (map['schema_version'] as int?) ?? 1,
      projectCode: map['project_code'] as String,
      exportDeviceId: map['export_device_id'] as String,
      exportTimeUtc: map['export_time_utc'] as String,
      sampleCount: (map['sample_count'] as int?) ?? 0,
      photoCount: (map['photo_count'] as int?) ?? 0,
      appVersion: map['app_version'] as String?,
    );
  }

  String toJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'schema_version': schemaVersion,
      'project_code': projectCode,
      'export_device_id': exportDeviceId,
      'export_time_utc': exportTimeUtc,
      'sample_count': sampleCount,
      'photo_count': photoCount,
      'app_version': appVersion,
    });
  }
}
