/// Data model for a single photograph of one side of a leaf.
class LeafPhoto {
  final String photoUuid;
  final String sampleUuid;
  final String leafSide; // 'upper' or 'lower'
  final String filePath;
  final String? originalFileName;
  final String sha256;
  final int? widthPx;
  final int? heightPx;
  final int? fileSizeBytes;
  final String capturedAtUtc;

  final String deviceId;
  final String? devicePlatform;
  final String? deviceManufacturer;
  final String? deviceModel;
  final String? osVersion;
  final String? appVersion;

  final double? latitude;
  final double? longitude;
  final double? gpsAccuracyM;
  final String? gpsCapturedAtUtc;
  final String gpsStatus;

  final int isPrimary;
  final String photoReviewStatus;
  final String? deletedAtUtc;
  final String createdAtUtc;

  const LeafPhoto({
    required this.photoUuid,
    required this.sampleUuid,
    required this.leafSide,
    required this.filePath,
    this.originalFileName,
    required this.sha256,
    this.widthPx,
    this.heightPx,
    this.fileSizeBytes,
    required this.capturedAtUtc,
    required this.deviceId,
    this.devicePlatform,
    this.deviceManufacturer,
    this.deviceModel,
    this.osVersion,
    this.appVersion,
    this.latitude,
    this.longitude,
    this.gpsAccuracyM,
    this.gpsCapturedAtUtc,
    this.gpsStatus = 'not_requested',
    this.isPrimary = 1,
    this.photoReviewStatus = 'accepted',
    this.deletedAtUtc,
    required this.createdAtUtc,
  });

  bool get isDeleted => deletedAtUtc != null;
  bool get isUpper => leafSide == 'upper';
  bool get isLower => leafSide == 'lower';

  factory LeafPhoto.fromMap(Map<String, dynamic> map) {
    return LeafPhoto(
      photoUuid: map['photo_uuid'] as String,
      sampleUuid: map['sample_uuid'] as String,
      leafSide: map['leaf_side'] as String,
      filePath: map['file_path'] as String,
      originalFileName: map['original_file_name'] as String?,
      sha256: map['sha256'] as String,
      widthPx: map['width_px'] as int?,
      heightPx: map['height_px'] as int?,
      fileSizeBytes: map['file_size_bytes'] as int?,
      capturedAtUtc: map['captured_at_utc'] as String,
      deviceId: map['device_id'] as String,
      devicePlatform: map['device_platform'] as String?,
      deviceManufacturer: map['device_manufacturer'] as String?,
      deviceModel: map['device_model'] as String?,
      osVersion: map['os_version'] as String?,
      appVersion: map['app_version'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      gpsAccuracyM: (map['gps_accuracy_m'] as num?)?.toDouble(),
      gpsCapturedAtUtc: map['gps_captured_at_utc'] as String?,
      gpsStatus: (map['gps_status'] as String?) ?? 'not_requested',
      isPrimary: (map['is_primary'] as int?) ?? 1,
      photoReviewStatus:
          (map['photo_review_status'] as String?) ?? 'accepted',
      deletedAtUtc: map['deleted_at_utc'] as String?,
      createdAtUtc: map['created_at_utc'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photo_uuid': photoUuid,
      'sample_uuid': sampleUuid,
      'leaf_side': leafSide,
      'file_path': filePath,
      'original_file_name': originalFileName,
      'sha256': sha256,
      'width_px': widthPx,
      'height_px': heightPx,
      'file_size_bytes': fileSizeBytes,
      'captured_at_utc': capturedAtUtc,
      'device_id': deviceId,
      'device_platform': devicePlatform,
      'device_manufacturer': deviceManufacturer,
      'device_model': deviceModel,
      'os_version': osVersion,
      'app_version': appVersion,
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy_m': gpsAccuracyM,
      'gps_captured_at_utc': gpsCapturedAtUtc,
      'gps_status': gpsStatus,
      'is_primary': isPrimary,
      'photo_review_status': photoReviewStatus,
      'deleted_at_utc': deletedAtUtc,
      'created_at_utc': createdAtUtc,
    };
  }

  LeafPhoto copyWith({
    String? photoUuid,
    String? sampleUuid,
    String? leafSide,
    String? filePath,
    String? originalFileName,
    String? sha256,
    int? widthPx,
    int? heightPx,
    int? fileSizeBytes,
    String? capturedAtUtc,
    String? deviceId,
    String? devicePlatform,
    String? deviceManufacturer,
    String? deviceModel,
    String? osVersion,
    String? appVersion,
    double? latitude,
    double? longitude,
    double? gpsAccuracyM,
    String? gpsCapturedAtUtc,
    String? gpsStatus,
    int? isPrimary,
    String? photoReviewStatus,
    String? deletedAtUtc,
    String? createdAtUtc,
  }) {
    return LeafPhoto(
      photoUuid: photoUuid ?? this.photoUuid,
      sampleUuid: sampleUuid ?? this.sampleUuid,
      leafSide: leafSide ?? this.leafSide,
      filePath: filePath ?? this.filePath,
      originalFileName: originalFileName ?? this.originalFileName,
      sha256: sha256 ?? this.sha256,
      widthPx: widthPx ?? this.widthPx,
      heightPx: heightPx ?? this.heightPx,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      capturedAtUtc: capturedAtUtc ?? this.capturedAtUtc,
      deviceId: deviceId ?? this.deviceId,
      devicePlatform: devicePlatform ?? this.devicePlatform,
      deviceManufacturer: deviceManufacturer ?? this.deviceManufacturer,
      deviceModel: deviceModel ?? this.deviceModel,
      osVersion: osVersion ?? this.osVersion,
      appVersion: appVersion ?? this.appVersion,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracyM: gpsAccuracyM ?? this.gpsAccuracyM,
      gpsCapturedAtUtc: gpsCapturedAtUtc ?? this.gpsCapturedAtUtc,
      gpsStatus: gpsStatus ?? this.gpsStatus,
      isPrimary: isPrimary ?? this.isPrimary,
      photoReviewStatus: photoReviewStatus ?? this.photoReviewStatus,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    );
  }
}
