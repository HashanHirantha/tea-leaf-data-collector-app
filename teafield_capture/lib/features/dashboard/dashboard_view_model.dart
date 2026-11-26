import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/settings_service.dart';
import '../../data/repositories/backup_repository.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/sample_repository.dart';

class DashboardState {
  final int totalSamples;
  final int incompleteSamples;
  final int totalPhotos;
  final String? lastBackupDateUtc;
  final String projectCode;
  final String collectorCode;
  final int pendingCloudDeletions;
  final bool isLoading;

  const DashboardState({
    this.totalSamples = 0,
    this.incompleteSamples = 0,
    this.totalPhotos = 0,
    this.lastBackupDateUtc,
    this.projectCode = AppConstants.projectCodeDefault,
    this.collectorCode = '',
    this.pendingCloudDeletions = 0,
    this.isLoading = true,
  });

  DashboardState copyWith({
    int? totalSamples,
    int? incompleteSamples,
    int? totalPhotos,
    String? lastBackupDateUtc,
    bool clearBackupDate = false,
    String? projectCode,
    String? collectorCode,
    int? pendingCloudDeletions,
    bool? isLoading,
  }) {
    return DashboardState(
      totalSamples: totalSamples ?? this.totalSamples,
      incompleteSamples: incompleteSamples ?? this.incompleteSamples,
      totalPhotos: totalPhotos ?? this.totalPhotos,
      lastBackupDateUtc:
          clearBackupDate ? null : (lastBackupDateUtc ?? this.lastBackupDateUtc),
      projectCode: projectCode ?? this.projectCode,
      collectorCode: collectorCode ?? this.collectorCode,
      pendingCloudDeletions:
          pendingCloudDeletions ?? this.pendingCloudDeletions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DashboardViewModel extends StateNotifier<DashboardState> {
  DashboardViewModel() : super(const DashboardState()) {
    refresh();
  }

  final SampleRepository _sampleRepo = SampleRepository();
  final PhotoRepository _photoRepo = PhotoRepository();
  final BackupRepository _backupRepo = BackupRepository();
  final SettingsService _settings = SettingsService.instance;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final projectCode = await _settings.getProjectCode();
      final collectorCode = await _settings.getCollectorCode();
      final totalSamples =
          await _sampleRepo.getActiveSampleCount(projectCode: projectCode);
      final incompleteSamples =
          await _sampleRepo.getIncompleteSampleCount(projectCode: projectCode);
      final totalPhotos =
          await _photoRepo.getActivePhotoCount(projectCode: projectCode);
      final lastBackup = await _backupRepo.getLastSuccessfulUploadDate();
      final pendingDeletions = await _backupRepo.getPendingCloudDeletions();

      state = state.copyWith(
        totalSamples: totalSamples,
        incompleteSamples: incompleteSamples,
        totalPhotos: totalPhotos,
        lastBackupDateUtc: lastBackup,
        clearBackupDate: lastBackup == null,
        projectCode: projectCode,
        collectorCode: collectorCode,
        pendingCloudDeletions: pendingDeletions.length,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final dashboardViewModelProvider =
    StateNotifierProvider<DashboardViewModel, DashboardState>((ref) {
  return DashboardViewModel();
});
