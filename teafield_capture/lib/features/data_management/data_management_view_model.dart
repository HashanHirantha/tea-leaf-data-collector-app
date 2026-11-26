import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/file_storage_service.dart';
import '../../core/services/google_drive_backup_service.dart';
import '../../core/services/sample_deletion_service.dart';
import '../../core/services/settings_service.dart';
import '../../data/models/drive_backup_batch.dart';
import '../../data/models/leaf_photo.dart';
import '../../data/models/leaf_sample.dart';
import '../../data/repositories/backup_repository.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/sample_repository.dart';

class DataManagementState {
  final String projectCode;
  final ProjectDataCounts counts;
  final int storageBytesUsed;
  final List<LeafSample> trashedSamples;
  final Map<String, int> trashedPhotoCountBySample;
  final List<LeafPhoto> individuallyTrashedPhotos;
  final List<PendingCloudDeletion> pendingCloudDeletions;
  final Set<String> selectedTrashUuids;
  final bool isLoading;
  final bool isWorking;
  final DeletionOutcomeReport? lastReport;
  final String? errorMessage;

  const DataManagementState({
    this.projectCode = 'SL_TEA_RESEARCH',
    this.counts = const ProjectDataCounts(
      activeSamples: 0,
      trashedSamples: 0,
      photoFiles: 0,
      localExportFiles: 0,
      driveBackupFiles: 0,
      pendingCloudDeletions: 0,
    ),
    this.storageBytesUsed = 0,
    this.trashedSamples = const [],
    this.trashedPhotoCountBySample = const {},
    this.individuallyTrashedPhotos = const [],
    this.pendingCloudDeletions = const [],
    this.selectedTrashUuids = const {},
    this.isLoading = true,
    this.isWorking = false,
    this.lastReport,
    this.errorMessage,
  });

  DataManagementState copyWith({
    String? projectCode,
    ProjectDataCounts? counts,
    int? storageBytesUsed,
    List<LeafSample>? trashedSamples,
    Map<String, int>? trashedPhotoCountBySample,
    List<LeafPhoto>? individuallyTrashedPhotos,
    List<PendingCloudDeletion>? pendingCloudDeletions,
    Set<String>? selectedTrashUuids,
    bool? isLoading,
    bool? isWorking,
    DeletionOutcomeReport? lastReport,
    bool clearReport = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DataManagementState(
      projectCode: projectCode ?? this.projectCode,
      counts: counts ?? this.counts,
      storageBytesUsed: storageBytesUsed ?? this.storageBytesUsed,
      trashedSamples: trashedSamples ?? this.trashedSamples,
      trashedPhotoCountBySample:
          trashedPhotoCountBySample ?? this.trashedPhotoCountBySample,
      individuallyTrashedPhotos:
          individuallyTrashedPhotos ?? this.individuallyTrashedPhotos,
      pendingCloudDeletions:
          pendingCloudDeletions ?? this.pendingCloudDeletions,
      selectedTrashUuids: selectedTrashUuids ?? this.selectedTrashUuids,
      isLoading: isLoading ?? this.isLoading,
      isWorking: isWorking ?? this.isWorking,
      lastReport: clearReport ? null : (lastReport ?? this.lastReport),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DataManagementViewModel extends StateNotifier<DataManagementState> {
  DataManagementViewModel() : super(const DataManagementState()) {
    refresh();
  }

  final SampleRepository _sampleRepo = SampleRepository();
  final PhotoRepository _photoRepo = PhotoRepository();
  final BackupRepository _backupRepo = BackupRepository();
  final SampleDeletionService _deletionService = SampleDeletionService.instance;
  final GoogleDriveBackupService _driveBackup =
      GoogleDriveBackupService.instance;
  final FileStorageService _storage = FileStorageService.instance;
  final SettingsService _settings = SettingsService.instance;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final projectCode = await _settings.getProjectCode();
      final counts = await _deletionService.getProjectDataCounts();
      final bytesUsed = await _storage.getTotalStorageBytesUsed();
      final trashedSamples =
          await _sampleRepo.getTrashedSamples(projectCode: projectCode);
      final trashedPhotos = await _photoRepo.getPhotosForSamples(
        trashedSamples.map((s) => s.sampleUuid).toList(),
        includeDeleted: true,
      );

      final countMap = <String, int>{};
      for (final p in trashedPhotos) {
        countMap[p.sampleUuid] = (countMap[p.sampleUuid] ?? 0) + 1;
      }

      final singlePhotos = await _photoRepo.getIndividuallyTrashedPhotos();
      final pendingCloud = await _backupRepo.getPendingCloudDeletions();

      state = state.copyWith(
        projectCode: projectCode,
        counts: counts,
        storageBytesUsed: bytesUsed,
        trashedSamples: trashedSamples,
        trashedPhotoCountBySample: countMap,
        individuallyTrashedPhotos: singlePhotos,
        pendingCloudDeletions: pendingCloud,
        selectedTrashUuids: const {},
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load data statistics: $e',
      );
    }
  }

  void toggleTrashSelection(String sampleUuid) {
    final next = Set<String>.from(state.selectedTrashUuids);
    if (next.contains(sampleUuid)) {
      next.remove(sampleUuid);
    } else {
      next.add(sampleUuid);
    }
    state = state.copyWith(selectedTrashUuids: next);
  }

  Future<void> restoreSamples(List<String> sampleUuids) async {
    state = state.copyWith(isWorking: true);
    await _deletionService.restoreSamples(sampleUuids);
    await refresh();
    state = state.copyWith(isWorking: false);
  }

  Future<void> restoreSinglePhoto(String photoUuid) async {
    state = state.copyWith(isWorking: true);
    await _deletionService.restorePhoto(photoUuid);
    await refresh();
    state = state.copyWith(isWorking: false);
  }

  Future<void> permanentlyDeleteSinglePhoto(String photoUuid) async {
    state = state.copyWith(isWorking: true);
    await _deletionService.permanentlyDeletePhoto(photoUuid);
    await refresh();
    state = state.copyWith(isWorking: false);
  }

  Future<List<DriveBackupBatch>> getAffectedDriveBatches(
    List<String> sampleUuids,
  ) {
    return _deletionService.getAffectedDriveBatches(sampleUuids);
  }

  Future<DeletionOutcomeReport> permanentlyDeleteSamples(
    List<String> sampleUuids, {
    List<DriveBackupBatch> driveArchivesToDelete = const [],
  }) async {
    state = state.copyWith(isWorking: true, clearError: true);
    final report = await _deletionService.permanentlyDeleteSamples(
      sampleUuids,
      driveArchivesToDelete: driveArchivesToDelete,
    );
    await refresh();
    state = state.copyWith(isWorking: false, lastReport: report);
    return report;
  }

  Future<DeletionOutcomeReport> deleteAllProjectData({
    required bool alsoDeleteDriveBackups,
  }) async {
    state = state.copyWith(isWorking: true, clearError: true, clearReport: true);
    try {
      final report = await _deletionService.deleteAllProjectData(
        alsoDeleteDriveBackups: alsoDeleteDriveBackups,
      );
      await refresh();
      state = state.copyWith(isWorking: false, lastReport: report);
      return report;
    } catch (e) {
      state = state.copyWith(
        isWorking: false,
        errorMessage: 'Reset failed: $e',
      );
      rethrow;
    }
  }

  Future<({int deletedCount, int remainingCount})>
      retryPendingCloudDeletions() async {
    state = state.copyWith(isWorking: true, clearError: true);
    final result = await _driveBackup.processPendingCloudDeletions();
    await refresh();
    state = state.copyWith(isWorking: false);
    return result;
  }
}

final dataManagementViewModelProvider = StateNotifierProvider.autoDispose<
    DataManagementViewModel, DataManagementState>(
  (ref) => DataManagementViewModel(),
);
