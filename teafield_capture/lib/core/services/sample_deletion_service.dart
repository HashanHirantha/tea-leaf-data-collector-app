import '../../data/models/drive_backup_batch.dart';
import '../../data/repositories/backup_repository.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/sample_repository.dart';
import 'file_storage_service.dart';
import 'google_drive_backup_service.dart';
import 'settings_service.dart';

/// Separate outcome report for local vs cloud deletion.
class DeletionOutcomeReport {
  final int localSamplesDeleted;
  final int localPhotosDeleted;
  final List<String> localFileFailures;
  final bool cloudDeletionRequested;
  final int driveArchivesDeleted;
  final int driveArchivesPending;
  final String? cloudErrorMessage;

  const DeletionOutcomeReport({
    required this.localSamplesDeleted,
    required this.localPhotosDeleted,
    this.localFileFailures = const [],
    this.cloudDeletionRequested = false,
    this.driveArchivesDeleted = 0,
    this.driveArchivesPending = 0,
    this.cloudErrorMessage,
  });
}

/// Summary counts displayed before full project reset confirmation.
class ProjectDataCounts {
  final int activeSamples;
  final int trashedSamples;
  final int photoFiles;
  final int localExportFiles;
  final int driveBackupFiles;
  final int pendingCloudDeletions;

  const ProjectDataCounts({
    required this.activeSamples,
    required this.trashedSamples,
    required this.photoFiles,
    required this.localExportFiles,
    required this.driveBackupFiles,
    required this.pendingCloudDeletions,
  });

  int get totalSamples => activeSamples + trashedSamples;
}

/// Manages soft-deletion (Trash), restoration, permanent local removal,
/// and optional Google Drive archive deletion.
class SampleDeletionService {
  SampleDeletionService({
    SampleRepository? sampleRepository,
    PhotoRepository? photoRepository,
    BackupRepository? backupRepository,
    FileStorageService? fileStorageService,
    GoogleDriveBackupService? driveBackupService,
    SettingsService? settingsService,
  })  : _sampleRepo = sampleRepository ?? SampleRepository(),
        _photoRepo = photoRepository ?? PhotoRepository(),
        _backupRepo = backupRepository ?? BackupRepository(),
        _storage = fileStorageService ?? FileStorageService.instance,
        _driveBackup = driveBackupService ?? GoogleDriveBackupService.instance,
        _settings = settingsService ?? SettingsService.instance;

  static final SampleDeletionService instance = SampleDeletionService();

  final SampleRepository _sampleRepo;
  final PhotoRepository _photoRepo;
  final BackupRepository _backupRepo;
  final FileStorageService _storage;
  final GoogleDriveBackupService _driveBackup;
  final SettingsService _settings;

  Future<void> moveSamplesToTrash(List<String> sampleUuids) async {
    await _sampleRepo.moveSamplesToTrash(sampleUuids);
  }

  Future<void> movePhotoToTrash(String photoUuid) async {
    final allowSingle = await _settings.getAllowSingleSideComplete();
    await _photoRepo.movePhotoToTrash(
      photoUuid,
      allowSingleSideComplete: allowSingle,
    );
  }

  Future<void> restoreSamples(List<String> sampleUuids) async {
    await _sampleRepo.restoreSamples(sampleUuids);
    final allowSingle = await _settings.getAllowSingleSideComplete();
    for (final uuid in sampleUuids) {
      await _sampleRepo.recalculateSampleStatus(
        uuid,
        allowSingleSideComplete: allowSingle,
      );
    }
  }

  Future<void> restorePhoto(String photoUuid) async {
    final allowSingle = await _settings.getAllowSingleSideComplete();
    await _photoRepo.restorePhoto(
      photoUuid,
      allowSingleSideComplete: allowSingle,
    );
  }

  /// Lists tracked Drive backup archives that include any of [sampleUuids].
  Future<List<DriveBackupBatch>> getAffectedDriveBatches(
    List<String> sampleUuids,
  ) async {
    final seen = <String, DriveBackupBatch>{};
    for (final uuid in sampleUuids) {
      final batches = await _backupRepo.getBatchesContainingSample(uuid);
      for (final b in batches) {
        seen[b.backupId] = b;
      }
    }
    return seen.values.toList();
  }

  /// Permanently deletes a single trashed photo and its local file.
  Future<void> permanentlyDeletePhoto(String photoUuid) async {
    final photo = await _photoRepo.getPhotoByUuid(photoUuid);
    if (photo == null) return;
    await _storage.deleteFileIfExists(photo.filePath);
    final allowSingle = await _settings.getAllowSingleSideComplete();
    await _photoRepo.permanentlyDeletePhotoRow(
      photoUuid,
      allowSingleSideComplete: allowSingle,
    );
    await _storage.cleanupEmptySampleDirectory(photo.sampleUuid);
  }

  /// Permanently removes [sampleUuids] and their app-private photo files.
  ///
  /// Does NOT automatically delete shared Drive ZIP archives unless explicitly
  /// requested via [driveArchivesToDelete].
  Future<DeletionOutcomeReport> permanentlyDeleteSamples(
    List<String> sampleUuids, {
    List<DriveBackupBatch> driveArchivesToDelete = const [],
  }) async {
    if (sampleUuids.isEmpty) {
      return const DeletionOutcomeReport(
        localSamplesDeleted: 0,
        localPhotosDeleted: 0,
      );
    }

    final photos = await _photoRepo.getPhotosForSamples(
      sampleUuids,
      includeDeleted: true,
    );

    final fileFailures = <String>[];
    var deletedPhotoCount = 0;
    for (final photo in photos) {
      final ok = await _storage.deleteFileIfExists(photo.filePath);
      if (ok) {
        deletedPhotoCount++;
      } else {
        fileFailures.add(photo.filePath);
      }
    }

    await _sampleRepo.permanentlyDeleteSamplesFromDb(sampleUuids);

    for (final uuid in sampleUuids) {
      await _storage.cleanupEmptySampleDirectory(uuid);
    }

    var driveDeleted = 0;
    var drivePending = 0;
    String? cloudError;

    for (final batch in driveArchivesToDelete) {
      final fileId = batch.driveFileId;
      if (fileId == null || fileId.isEmpty) continue;
      final res = await _driveBackup.deleteTrackedDriveFile(
        driveFileId: fileId,
        driveFileName: batch.driveFileName,
        googleAccountEmail: batch.googleAccountEmail,
      );
      if (res.deleted) {
        driveDeleted++;
      } else {
        drivePending++;
        cloudError ??= res.error;
      }
    }

    return DeletionOutcomeReport(
      localSamplesDeleted: sampleUuids.length,
      localPhotosDeleted: deletedPhotoCount,
      localFileFailures: fileFailures,
      cloudDeletionRequested: driveArchivesToDelete.isNotEmpty,
      driveArchivesDeleted: driveDeleted,
      driveArchivesPending: drivePending,
      cloudErrorMessage: cloudError,
    );
  }

  /// Returns current project counts for the full reset confirmation screen.
  Future<ProjectDataCounts> getProjectDataCounts() async {
    final projectCode = await _settings.getProjectCode();
    final activeSamples =
        await _sampleRepo.getAllActiveSamples(projectCode: projectCode);
    final trashedSamples =
        await _sampleRepo.getTrashedSamples(projectCode: projectCode);
    final allUuids = [
      ...activeSamples.map((s) => s.sampleUuid),
      ...trashedSamples.map((s) => s.sampleUuid),
    ];
    final photos = await _photoRepo.getPhotosForSamples(
      allUuids,
      includeDeleted: true,
    );
    final localExports = await _storage.getLocalExportFileCount();
    final trackedDrive = await _backupRepo.getTrackedDriveBackups();
    final pendingCloud = await _backupRepo.getPendingCloudDeletions();

    return ProjectDataCounts(
      activeSamples: activeSamples.length,
      trashedSamples: trashedSamples.length,
      photoFiles: photos.length,
      localExportFiles: localExports,
      driveBackupFiles: trackedDrive.length,
      pendingCloudDeletions: pendingCloud.length,
    );
  }

  /// Executes a confirmed full reset of the current project's local data,
  /// optionally deleting tracked app-created Google Drive backup archives.
  Future<DeletionOutcomeReport> deleteAllProjectData({
    required bool alsoDeleteDriveBackups,
  }) async {
    final projectCode = await _settings.getProjectCode();
    final countsBefore = await getProjectDataCounts();

    // 1. Delete local photo files and local generated exports/imports.
    final fileFailures = await _storage.deleteAllLocalFiles();

    // 2. Wipe project samples/photos/imports; queue Drive IDs if requested.
    await _backupRepo.resetLocalResearchData(
      projectCode: projectCode,
      queueDriveDeletions: alsoDeleteDriveBackups,
    );

    // 3. Verify zero active or trashed samples remain for this project.
    final remainingActive =
        await _sampleRepo.getActiveSampleCount(projectCode: projectCode);
    final remainingTrashed =
        await _sampleRepo.getTrashedSampleCount(projectCode: projectCode);
    if (remainingActive != 0 || remainingTrashed != 0) {
      throw StateError(
        'Database reset verification failed: $remainingActive active, $remainingTrashed trashed remain.',
      );
    }

    if (!alsoDeleteDriveBackups) {
      return DeletionOutcomeReport(
        localSamplesDeleted: countsBefore.totalSamples,
        localPhotosDeleted: countsBefore.photoFiles,
        localFileFailures: fileFailures,
        cloudDeletionRequested: false,
        driveArchivesDeleted: 0,
        driveArchivesPending: countsBefore.driveBackupFiles,
      );
    }

    // 4. Attempt online deletion of queued Drive files; keep pending queue on error.
    final cloudResult = await _driveBackup.processPendingCloudDeletions();
    final pendingList = await _backupRepo.getPendingCloudDeletions();

    return DeletionOutcomeReport(
      localSamplesDeleted: countsBefore.totalSamples,
      localPhotosDeleted: countsBefore.photoFiles,
      localFileFailures: fileFailures,
      cloudDeletionRequested: true,
      driveArchivesDeleted: cloudResult.deletedCount,
      driveArchivesPending: cloudResult.remainingCount,
      cloudErrorMessage:
          pendingList.isNotEmpty ? pendingList.first.lastError : null,
    );
  }

  /// Convenience wrapper to enqueue deletion of a specific tracked Drive archive.
  Future<({bool deleted, String? error})> deleteSingleDriveBackup(
    DriveBackupBatch batch,
  ) async {
    final fileId = batch.driveFileId;
    if (fileId == null || fileId.isEmpty) {
      await _backupRepo.removeBatchRecord(batch.backupId);
      return (deleted: true, error: null);
    }
    await _backupRepo.updateBatch(
      batch.copyWith(status: DriveBackupStatus.deletePending.databaseKey),
    );
    return _driveBackup.deleteTrackedDriveFile(
      driveFileId: fileId,
      driveFileName: batch.driveFileName,
      googleAccountEmail: batch.googleAccountEmail,
    );
  }
}
