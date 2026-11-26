import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/google_drive_auth_service.dart';
import '../../core/services/google_drive_backup_service.dart';
import '../../core/services/sample_deletion_service.dart';
import '../../core/services/settings_service.dart';
import '../../data/models/drive_backup_batch.dart';
import '../../data/models/leaf_sample.dart';
import '../../data/repositories/backup_repository.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/sample_repository.dart';

class DriveBackupState {
  final bool isConnected;
  final String? connectedEmail;
  final String projectCode;
  final DriveBackupType backupType;
  final List<LeafSample> allActiveSamples;
  final List<LeafSample> changedSamples;
  final Set<String> selectedUuids;
  final int targetPhotoCount;
  final bool includeGps;
  final bool isLoading;
  final bool isUploading;
  final double progress;
  final String stageMessage;
  final DriveUploadOutcome? lastOutcome;
  final List<DriveBackupBatch> history;
  final String? errorMessage;

  const DriveBackupState({
    this.isConnected = false,
    this.connectedEmail,
    this.projectCode = 'SL_TEA_RESEARCH',
    this.backupType = DriveBackupType.changed,
    this.allActiveSamples = const [],
    this.changedSamples = const [],
    this.selectedUuids = const {},
    this.targetPhotoCount = 0,
    this.includeGps = true,
    this.isLoading = true,
    this.isUploading = false,
    this.progress = 0.0,
    this.stageMessage = '',
    this.lastOutcome,
    this.history = const [],
    this.errorMessage,
  });

  List<LeafSample> get targetSamples {
    switch (backupType) {
      case DriveBackupType.all:
        return allActiveSamples;
      case DriveBackupType.changed:
        return changedSamples;
      case DriveBackupType.selected:
        return allActiveSamples
            .where((s) => selectedUuids.contains(s.sampleUuid))
            .toList();
    }
  }

  DriveBackupState copyWith({
    bool? isConnected,
    String? connectedEmail,
    bool clearEmail = false,
    String? projectCode,
    DriveBackupType? backupType,
    List<LeafSample>? allActiveSamples,
    List<LeafSample>? changedSamples,
    Set<String>? selectedUuids,
    int? targetPhotoCount,
    bool? includeGps,
    bool? isLoading,
    bool? isUploading,
    double? progress,
    String? stageMessage,
    DriveUploadOutcome? lastOutcome,
    bool clearOutcome = false,
    List<DriveBackupBatch>? history,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DriveBackupState(
      isConnected: isConnected ?? this.isConnected,
      connectedEmail:
          clearEmail ? null : (connectedEmail ?? this.connectedEmail),
      projectCode: projectCode ?? this.projectCode,
      backupType: backupType ?? this.backupType,
      allActiveSamples: allActiveSamples ?? this.allActiveSamples,
      changedSamples: changedSamples ?? this.changedSamples,
      selectedUuids: selectedUuids ?? this.selectedUuids,
      targetPhotoCount: targetPhotoCount ?? this.targetPhotoCount,
      includeGps: includeGps ?? this.includeGps,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      stageMessage: stageMessage ?? this.stageMessage,
      lastOutcome: clearOutcome ? null : (lastOutcome ?? this.lastOutcome),
      history: history ?? this.history,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DriveBackupViewModel extends StateNotifier<DriveBackupState> {
  DriveBackupViewModel({List<String>? initialSelectedUuids})
      : super(
          DriveBackupState(
            backupType:
                initialSelectedUuids != null && initialSelectedUuids.isNotEmpty
                    ? DriveBackupType.selected
                    : DriveBackupType.changed,
            selectedUuids: initialSelectedUuids?.toSet() ?? const {},
          ),
        ) {
    load();
  }

  final GoogleDriveAuthService _auth = GoogleDriveAuthService.instance;
  final GoogleDriveBackupService _backupService =
      GoogleDriveBackupService.instance;
  final SampleDeletionService _deletionService = SampleDeletionService.instance;
  final SampleRepository _sampleRepo = SampleRepository();
  final PhotoRepository _photoRepo = PhotoRepository();
  final BackupRepository _backupRepo = BackupRepository();
  final SettingsService _settings = SettingsService.instance;

  BackupCancellationToken? _activeCancelToken;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final email = await _auth.tryRestorePreviousAccount();
      final projectCode = await _settings.getProjectCode();
      final includeGps = await _settings.getIncludeGpsInDriveBackup();
      final allActive =
          await _sampleRepo.getAllActiveSamples(projectCode: projectCode);
      final changed = await _backupService.getChangedOrUnbackedSamples(
        projectCode: projectCode,
      );
      final history = await _backupRepo.getAllBatches();

      state = state.copyWith(
        isConnected: _auth.isSignedIn || (email != null && email.isNotEmpty),
        connectedEmail: email,
        projectCode: projectCode,
        allActiveSamples: allActive,
        changedSamples: changed,
        includeGps: includeGps,
        history: history,
        isLoading: false,
      );
      await _recomputeTargetPhotoCount();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load backup state: $e',
      );
    }
  }

  Future<void> _recomputeTargetPhotoCount() async {
    final uuids = state.targetSamples.map((s) => s.sampleUuid).toList();
    final photos = await _photoRepo.getPhotosForSamples(uuids);
    state = state.copyWith(targetPhotoCount: photos.length);
  }

  Future<void> connectGoogleAccount() async {
    state = state.copyWith(clearError: true);
    try {
      final creds = await _auth.authorizeForDrive(forceInteractive: true);
      state = state.copyWith(
        isConnected: true,
        connectedEmail: creds.email,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Google sign-in failed: $e',
      );
    }
  }

  Future<void> disconnectGoogleAccount() async {
    await _auth.signOut();
    state = state.copyWith(isConnected: false, clearEmail: true);
  }

  Future<void> setBackupType(DriveBackupType type) async {
    state = state.copyWith(backupType: type, clearOutcome: true);
    await _recomputeTargetPhotoCount();
  }

  Future<void> setSelectedSamples(Set<String> uuids) async {
    state = state.copyWith(
      backupType: DriveBackupType.selected,
      selectedUuids: uuids,
      clearOutcome: true,
    );
    await _recomputeTargetPhotoCount();
  }

  Future<void> setIncludeGps(bool include) async {
    await _settings.setIncludeGpsInDriveBackup(include);
    state = state.copyWith(includeGps: include);
  }

  Future<void> startManualUpload() async {
    final targets = state.targetSamples;
    if (targets.isEmpty) {
      state = state.copyWith(errorMessage: 'No samples to upload.');
      return;
    }

    final cancelToken = BackupCancellationToken();
    _activeCancelToken = cancelToken;

    state = state.copyWith(
      isUploading: true,
      progress: 0.02,
      stageMessage: 'Starting backup...',
      clearOutcome: true,
      clearError: true,
    );

    try {
      final outcome = await _backupService.uploadBackup(
        backupType: state.backupType,
        samples: targets,
        includeGps: state.includeGps,
        cancellationToken: cancelToken,
        onProgress: (p, stage) {
          state = state.copyWith(progress: p, stageMessage: stage);
        },
      );

      _activeCancelToken = null;
      await load();
      state = state.copyWith(
        isUploading: false,
        lastOutcome: outcome,
        errorMessage: outcome.succeeded ? null : outcome.errorMessage,
      );
    } catch (e) {
      _activeCancelToken = null;
      await load();
      state = state.copyWith(
        isUploading: false,
        errorMessage: 'Backup failed: $e',
      );
    }
  }

  void cancelUpload() {
    _activeCancelToken?.cancel();
  }

  Future<void> retryBatch(DriveBackupBatch batch) async {
    final cancelToken = BackupCancellationToken();
    _activeCancelToken = cancelToken;

    state = state.copyWith(
      isUploading: true,
      progress: 0.05,
      stageMessage: 'Retrying upload...',
      clearError: true,
      clearOutcome: true,
    );

    try {
      final outcome = await _backupService.retryBatch(
        batch,
        cancellationToken: cancelToken,
        onProgress: (p, stage) {
          state = state.copyWith(progress: p, stageMessage: stage);
        },
      );
      _activeCancelToken = null;
      await load();
      state = state.copyWith(
        isUploading: false,
        lastOutcome: outcome,
        errorMessage: outcome.succeeded ? null : outcome.errorMessage,
      );
    } catch (e) {
      _activeCancelToken = null;
      await load();
      state = state.copyWith(
        isUploading: false,
        errorMessage: 'Retry failed: $e',
      );
    }
  }

  Future<({bool deleted, String? error})> deleteBackupFromDrive(
    DriveBackupBatch batch,
  ) async {
    final result = await _deletionService.deleteSingleDriveBackup(batch);
    await load();
    return result;
  }
}

final driveBackupViewModelProvider = StateNotifierProvider.autoDispose
    .family<DriveBackupViewModel, DriveBackupState, List<String>?>(
  (ref, initialSelected) =>
      DriveBackupViewModel(initialSelectedUuids: initialSelected),
);
