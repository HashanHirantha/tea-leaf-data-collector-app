/// Models tracking Google Drive backup batches and pending cloud deletions.

enum DriveBackupType {
  all('all', 'All active records'),
  selected('selected', 'Selected samples'),
  changed('changed', 'New or changed records');

  const DriveBackupType(this.databaseKey, this.displayName);
  final String databaseKey;
  final String displayName;

  static DriveBackupType fromDatabaseKey(String? key) =>
      DriveBackupType.values.firstWhere(
        (e) => e.databaseKey == key,
        orElse: () => DriveBackupType.all,
      );
}

enum DriveBackupStatus {
  preparing('preparing', 'Preparing'),
  uploading('uploading', 'Uploading'),
  uploaded('uploaded', 'Uploaded'),
  failed('failed', 'Failed'),
  deletePending('delete_pending', 'Delete pending');

  const DriveBackupStatus(this.databaseKey, this.displayName);
  final String databaseKey;
  final String displayName;

  static DriveBackupStatus fromDatabaseKey(String? key) =>
      DriveBackupStatus.values.firstWhere(
        (e) => e.databaseKey == key,
        orElse: () => DriveBackupStatus.failed,
      );
}

class DriveBackupBatch {
  final String backupId;
  final String? googleAccountEmail;
  final String? driveFolderId;
  final String? driveFileId;
  final String driveFileName;
  final String? localZipPath;
  final String? packageSha256;
  final int sampleCount;
  final int photoCount;
  final String backupType;
  final String status;
  final String createdAtUtc;
  final String? uploadedAtUtc;
  final String? lastError;

  const DriveBackupBatch({
    required this.backupId,
    this.googleAccountEmail,
    this.driveFolderId,
    this.driveFileId,
    required this.driveFileName,
    this.localZipPath,
    this.packageSha256,
    this.sampleCount = 0,
    this.photoCount = 0,
    required this.backupType,
    required this.status,
    required this.createdAtUtc,
    this.uploadedAtUtc,
    this.lastError,
  });

  factory DriveBackupBatch.fromMap(Map<String, dynamic> map) {
    return DriveBackupBatch(
      backupId: map['backup_id'] as String,
      googleAccountEmail: map['google_account_email'] as String?,
      driveFolderId: map['drive_folder_id'] as String?,
      driveFileId: map['drive_file_id'] as String?,
      driveFileName: map['drive_file_name'] as String,
      localZipPath: map['local_zip_path'] as String?,
      packageSha256: map['package_sha256'] as String?,
      sampleCount: (map['sample_count'] as int?) ?? 0,
      photoCount: (map['photo_count'] as int?) ?? 0,
      backupType: map['backup_type'] as String,
      status: map['status'] as String,
      createdAtUtc: map['created_at_utc'] as String,
      uploadedAtUtc: map['uploaded_at_utc'] as String?,
      lastError: map['last_error'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'backup_id': backupId,
      'google_account_email': googleAccountEmail,
      'drive_folder_id': driveFolderId,
      'drive_file_id': driveFileId,
      'drive_file_name': driveFileName,
      'local_zip_path': localZipPath,
      'package_sha256': packageSha256,
      'sample_count': sampleCount,
      'photo_count': photoCount,
      'backup_type': backupType,
      'status': status,
      'created_at_utc': createdAtUtc,
      'uploaded_at_utc': uploadedAtUtc,
      'last_error': lastError,
    };
  }

  DriveBackupBatch copyWith({
    String? googleAccountEmail,
    String? driveFolderId,
    String? driveFileId,
    String? driveFileName,
    String? localZipPath,
    String? packageSha256,
    int? sampleCount,
    int? photoCount,
    String? backupType,
    String? status,
    String? uploadedAtUtc,
    String? lastError,
  }) {
    return DriveBackupBatch(
      backupId: backupId,
      googleAccountEmail: googleAccountEmail ?? this.googleAccountEmail,
      driveFolderId: driveFolderId ?? this.driveFolderId,
      driveFileId: driveFileId ?? this.driveFileId,
      driveFileName: driveFileName ?? this.driveFileName,
      localZipPath: localZipPath ?? this.localZipPath,
      packageSha256: packageSha256 ?? this.packageSha256,
      sampleCount: sampleCount ?? this.sampleCount,
      photoCount: photoCount ?? this.photoCount,
      backupType: backupType ?? this.backupType,
      status: status ?? this.status,
      createdAtUtc: createdAtUtc,
      uploadedAtUtc: uploadedAtUtc ?? this.uploadedAtUtc,
      lastError: lastError ?? this.lastError,
    );
  }
}

class PendingCloudDeletion {
  final String driveFileId;
  final String driveFileName;
  final String? googleAccountEmail;
  final String requestedAtUtc;
  final String status;
  final String? lastError;

  const PendingCloudDeletion({
    required this.driveFileId,
    required this.driveFileName,
    this.googleAccountEmail,
    required this.requestedAtUtc,
    this.status = 'pending',
    this.lastError,
  });

  factory PendingCloudDeletion.fromMap(Map<String, dynamic> map) {
    return PendingCloudDeletion(
      driveFileId: map['drive_file_id'] as String,
      driveFileName: map['drive_file_name'] as String,
      googleAccountEmail: map['google_account_email'] as String?,
      requestedAtUtc: map['requested_at_utc'] as String,
      status: (map['status'] as String?) ?? 'pending',
      lastError: map['last_error'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'drive_file_id': driveFileId,
      'drive_file_name': driveFileName,
      'google_account_email': googleAccountEmail,
      'requested_at_utc': requestedAtUtc,
      'status': status,
      'last_error': lastError,
    };
  }
}
