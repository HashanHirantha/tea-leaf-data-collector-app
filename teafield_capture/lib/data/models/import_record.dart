import 'leaf_sample.dart';

/// Database record for a ZIP package import event.
class ImportRecord {
  final String importId;
  final String? sourceDeviceId;
  final String importedAtUtc;
  final String packageName;
  final String? packageChecksum;
  final String? resultSummary;

  const ImportRecord({
    required this.importId,
    this.sourceDeviceId,
    required this.importedAtUtc,
    required this.packageName,
    this.packageChecksum,
    this.resultSummary,
  });

  factory ImportRecord.fromMap(Map<String, dynamic> map) {
    return ImportRecord(
      importId: map['import_id'] as String,
      sourceDeviceId: map['source_device_id'] as String?,
      importedAtUtc: map['imported_at_utc'] as String,
      packageName: map['package_name'] as String,
      packageChecksum: map['package_checksum'] as String?,
      resultSummary: map['result_summary'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'import_id': importId,
      'source_device_id': sourceDeviceId,
      'imported_at_utc': importedAtUtc,
      'package_name': packageName,
      'package_checksum': packageChecksum,
      'result_summary': resultSummary,
    };
  }
}

/// Represents a field-label or metadata conflict discovered during ZIP merge.
class ImportConflict {
  final String sampleUuid;
  final String sampleCode;
  final LeafSample localSample;
  final LeafSample incomingSample;
  final List<String> conflictingFields;

  const ImportConflict({
    required this.sampleUuid,
    required this.sampleCode,
    required this.localSample,
    required this.incomingSample,
    required this.conflictingFields,
  });
}

/// Summary returned after importing a research ZIP package.
class ImportResult {
  final int samplesCreated;
  final int samplesMerged;
  final int photosImported;
  final int photosSkippedDuplicate;
  final List<ImportConflict> conflicts;
  final String packageChecksum;

  const ImportResult({
    required this.samplesCreated,
    required this.samplesMerged,
    required this.photosImported,
    required this.photosSkippedDuplicate,
    required this.conflicts,
    required this.packageChecksum,
  });
}
