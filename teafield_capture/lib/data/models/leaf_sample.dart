/// Enumerations and data model for a physical tea leaf sample.
///
/// A leaf sample represents one physical leaf. Its upper and lower surface
/// photographs are separate [LeafPhoto] records linked to the same sample UUID.

/// Which surface of the leaf a photo shows.
enum LeafSide {
  upper('upper', 'Upper surface (adaxial)'),
  lower('lower', 'Lower surface (abaxial)');

  const LeafSide(this.databaseKey, this.displayName);
  final String databaseKey;
  final String displayName;

  static LeafSide fromDatabaseKey(String key) =>
      LeafSide.values.firstWhere((e) => e.databaseKey == key,
          orElse: () => LeafSide.upper);
}

/// Workflow status of the sample.
enum SampleStatus {
  incomplete('incomplete', 'Incomplete'),
  readyForReview('ready_for_review', 'Ready for review'),
  verified('verified', 'Verified'),
  needsRecheck('needs_recheck', 'Needs recheck');

  const SampleStatus(this.databaseKey, this.displayName);
  final String databaseKey;
  final String displayName;

  static SampleStatus fromDatabaseKey(String? key) =>
      SampleStatus.values.firstWhere(
        (e) => e.databaseKey == key,
        orElse: () => SampleStatus.incomplete,
      );
}

/// Expert-review label status.
enum LabelStatus {
  pending('pending', 'Pending'),
  confirmed('confirmed', 'Confirmed'),
  rejectedOrRelabelled('rejected_or_relabelled', 'Rejected / Relabelled');

  const LabelStatus(this.databaseKey, this.displayName);
  final String databaseKey;
  final String displayName;

  static LabelStatus fromDatabaseKey(String? key) =>
      LabelStatus.values.firstWhere(
        (e) => e.databaseKey == key,
        orElse: () => LabelStatus.pending,
      );
}

/// GPS acquisition status.
enum GpsStatus {
  notRequested('not_requested', 'Not requested'),
  captured('captured', 'Captured'),
  permissionDenied('permission_denied', 'Permission denied'),
  serviceDisabled('service_disabled', 'Service disabled'),
  timeout('timeout', 'Timeout'),
  unavailable('unavailable', 'Unavailable');

  const GpsStatus(this.databaseKey, this.displayName);
  final String databaseKey;
  final String displayName;

  static GpsStatus fromDatabaseKey(String? key) =>
      GpsStatus.values.firstWhere(
        (e) => e.databaseKey == key,
        orElse: () => GpsStatus.notRequested,
      );
}

/// Represents one physical tea leaf sample record.
class LeafSample {
  final String sampleUuid;
  final String sampleCode;
  final String projectCode;
  final String createdAtUtc;
  final String updatedAtUtc;
  final String createdByDeviceId;
  final String? masterDeviceId;

  final String? estateName;
  final String? region;
  final String? district;
  final String? bushPlotCode;
  final String? collectorCode;

  final String fieldLabel;
  final String? expertLabel;
  final String labelStatus;
  final String? expertReviewerCode;
  final String? expertReviewedAtUtc;

  final int? severity;
  final String? symptomNotes;
  final String? otherNotes;

  final double? sampleLatitude;
  final double? sampleLongitude;
  final double? sampleGpsAccuracyM;
  final String? sampleGpsCapturedAtUtc;
  final String sampleGpsStatus;

  final String sampleStatus;
  final String? deletedAtUtc;
  final int isImported;
  final String? sourceSampleUuid;

  const LeafSample({
    required this.sampleUuid,
    required this.sampleCode,
    required this.projectCode,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.createdByDeviceId,
    this.masterDeviceId,
    this.estateName,
    this.region,
    this.district,
    this.bushPlotCode,
    this.collectorCode,
    this.fieldLabel = 'not_sure',
    this.expertLabel,
    this.labelStatus = 'pending',
    this.expertReviewerCode,
    this.expertReviewedAtUtc,
    this.severity,
    this.symptomNotes,
    this.otherNotes,
    this.sampleLatitude,
    this.sampleLongitude,
    this.sampleGpsAccuracyM,
    this.sampleGpsCapturedAtUtc,
    this.sampleGpsStatus = 'not_requested',
    this.sampleStatus = 'incomplete',
    this.deletedAtUtc,
    this.isImported = 0,
    this.sourceSampleUuid,
  });

  bool get isDeleted => deletedAtUtc != null;
  bool get hasGps => sampleGpsStatus == 'captured' && sampleLatitude != null;

  factory LeafSample.fromMap(Map<String, dynamic> map) {
    return LeafSample(
      sampleUuid: map['sample_uuid'] as String,
      sampleCode: map['sample_code'] as String,
      projectCode: map['project_code'] as String,
      createdAtUtc: map['created_at_utc'] as String,
      updatedAtUtc: map['updated_at_utc'] as String,
      createdByDeviceId: map['created_by_device_id'] as String,
      masterDeviceId: map['master_device_id'] as String?,
      estateName: map['estate_name'] as String?,
      region: map['region'] as String?,
      district: map['district'] as String?,
      bushPlotCode: map['bush_plot_code'] as String?,
      collectorCode: map['collector_code'] as String?,
      fieldLabel: (map['field_label'] as String?) ?? 'not_sure',
      expertLabel: map['expert_label'] as String?,
      labelStatus: (map['label_status'] as String?) ?? 'pending',
      expertReviewerCode: map['expert_reviewer_code'] as String?,
      expertReviewedAtUtc: map['expert_reviewed_at_utc'] as String?,
      severity: map['severity'] as int?,
      symptomNotes: map['symptom_notes'] as String?,
      otherNotes: map['other_notes'] as String?,
      sampleLatitude: (map['sample_latitude'] as num?)?.toDouble(),
      sampleLongitude: (map['sample_longitude'] as num?)?.toDouble(),
      sampleGpsAccuracyM: (map['sample_gps_accuracy_m'] as num?)?.toDouble(),
      sampleGpsCapturedAtUtc: map['sample_gps_captured_at_utc'] as String?,
      sampleGpsStatus:
          (map['sample_gps_status'] as String?) ?? 'not_requested',
      sampleStatus: (map['sample_status'] as String?) ?? 'incomplete',
      deletedAtUtc: map['deleted_at_utc'] as String?,
      isImported: (map['is_imported'] as int?) ?? 0,
      sourceSampleUuid: map['source_sample_uuid'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sample_uuid': sampleUuid,
      'sample_code': sampleCode,
      'project_code': projectCode,
      'created_at_utc': createdAtUtc,
      'updated_at_utc': updatedAtUtc,
      'created_by_device_id': createdByDeviceId,
      'master_device_id': masterDeviceId,
      'estate_name': estateName,
      'region': region,
      'district': district,
      'bush_plot_code': bushPlotCode,
      'collector_code': collectorCode,
      'field_label': fieldLabel,
      'expert_label': expertLabel,
      'label_status': labelStatus,
      'expert_reviewer_code': expertReviewerCode,
      'expert_reviewed_at_utc': expertReviewedAtUtc,
      'severity': severity,
      'symptom_notes': symptomNotes,
      'other_notes': otherNotes,
      'sample_latitude': sampleLatitude,
      'sample_longitude': sampleLongitude,
      'sample_gps_accuracy_m': sampleGpsAccuracyM,
      'sample_gps_captured_at_utc': sampleGpsCapturedAtUtc,
      'sample_gps_status': sampleGpsStatus,
      'sample_status': sampleStatus,
      'deleted_at_utc': deletedAtUtc,
      'is_imported': isImported,
      'source_sample_uuid': sourceSampleUuid,
    };
  }

  LeafSample copyWith({
    String? sampleUuid,
    String? sampleCode,
    String? projectCode,
    String? createdAtUtc,
    String? updatedAtUtc,
    String? createdByDeviceId,
    String? masterDeviceId,
    String? estateName,
    String? region,
    String? district,
    String? bushPlotCode,
    String? collectorCode,
    String? fieldLabel,
    String? expertLabel,
    String? labelStatus,
    String? expertReviewerCode,
    String? expertReviewedAtUtc,
    int? severity,
    String? symptomNotes,
    String? otherNotes,
    double? sampleLatitude,
    double? sampleLongitude,
    double? sampleGpsAccuracyM,
    String? sampleGpsCapturedAtUtc,
    String? sampleGpsStatus,
    String? sampleStatus,
    String? deletedAtUtc,
    int? isImported,
    String? sourceSampleUuid,
  }) {
    return LeafSample(
      sampleUuid: sampleUuid ?? this.sampleUuid,
      sampleCode: sampleCode ?? this.sampleCode,
      projectCode: projectCode ?? this.projectCode,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
      masterDeviceId: masterDeviceId ?? this.masterDeviceId,
      estateName: estateName ?? this.estateName,
      region: region ?? this.region,
      district: district ?? this.district,
      bushPlotCode: bushPlotCode ?? this.bushPlotCode,
      collectorCode: collectorCode ?? this.collectorCode,
      fieldLabel: fieldLabel ?? this.fieldLabel,
      expertLabel: expertLabel ?? this.expertLabel,
      labelStatus: labelStatus ?? this.labelStatus,
      expertReviewerCode: expertReviewerCode ?? this.expertReviewerCode,
      expertReviewedAtUtc: expertReviewedAtUtc ?? this.expertReviewedAtUtc,
      severity: severity ?? this.severity,
      symptomNotes: symptomNotes ?? this.symptomNotes,
      otherNotes: otherNotes ?? this.otherNotes,
      sampleLatitude: sampleLatitude ?? this.sampleLatitude,
      sampleLongitude: sampleLongitude ?? this.sampleLongitude,
      sampleGpsAccuracyM: sampleGpsAccuracyM ?? this.sampleGpsAccuracyM,
      sampleGpsCapturedAtUtc:
          sampleGpsCapturedAtUtc ?? this.sampleGpsCapturedAtUtc,
      sampleGpsStatus: sampleGpsStatus ?? this.sampleGpsStatus,
      sampleStatus: sampleStatus ?? this.sampleStatus,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      isImported: isImported ?? this.isImported,
      sourceSampleUuid: sourceSampleUuid ?? this.sourceSampleUuid,
    );
  }
}
