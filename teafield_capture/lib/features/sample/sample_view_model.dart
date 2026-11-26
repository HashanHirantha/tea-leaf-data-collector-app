import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/sample_deletion_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/models/leaf_photo.dart';
import '../../data/models/leaf_sample.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/sample_repository.dart';

class SampleListState {
  final List<LeafSample> samples;
  final Map<String, ({LeafPhoto? upper, LeafPhoto? lower})> photosBySample;
  final List<String> availableEstates;
  final String searchQuery;
  final String statusFilter;
  final String estateFilter;
  final String labelFilter;
  final String missingSideFilter;
  final Set<String> selectedSampleUuids;
  final bool isSelectionMode;
  final bool isLoading;
  final String? errorMessage;

  const SampleListState({
    this.samples = const [],
    this.photosBySample = const {},
    this.availableEstates = const [],
    this.searchQuery = '',
    this.statusFilter = 'all',
    this.estateFilter = 'all',
    this.labelFilter = 'all',
    this.missingSideFilter = 'none',
    this.selectedSampleUuids = const {},
    this.isSelectionMode = false,
    this.isLoading = true,
    this.errorMessage,
  });

  SampleListState copyWith({
    List<LeafSample>? samples,
    Map<String, ({LeafPhoto? upper, LeafPhoto? lower})>? photosBySample,
    List<String>? availableEstates,
    String? searchQuery,
    String? statusFilter,
    String? estateFilter,
    String? labelFilter,
    String? missingSideFilter,
    Set<String>? selectedSampleUuids,
    bool? isSelectionMode,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SampleListState(
      samples: samples ?? this.samples,
      photosBySample: photosBySample ?? this.photosBySample,
      availableEstates: availableEstates ?? this.availableEstates,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      estateFilter: estateFilter ?? this.estateFilter,
      labelFilter: labelFilter ?? this.labelFilter,
      missingSideFilter: missingSideFilter ?? this.missingSideFilter,
      selectedSampleUuids: selectedSampleUuids ?? this.selectedSampleUuids,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SampleListViewModel extends StateNotifier<SampleListState> {
  SampleListViewModel() : super(const SampleListState()) {
    loadSamples();
  }

  final SampleRepository _sampleRepo = SampleRepository();
  final PhotoRepository _photoRepo = PhotoRepository();
  final SampleDeletionService _deletionService = SampleDeletionService.instance;
  final SettingsService _settings = SettingsService.instance;

  Future<void> loadSamples() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final projectCode = await _settings.getProjectCode();
      final estates = await _sampleRepo.getDistinctEstates();
      final samples = await _sampleRepo.searchSamples(
        projectCode: projectCode,
        query: state.searchQuery,
        status: state.statusFilter,
        estate: state.estateFilter,
        fieldLabel: state.labelFilter,
        missingSide: state.missingSideFilter == 'none'
            ? null
            : state.missingSideFilter,
      );
      final photosMap = await _photoRepo.getPrimaryPhotosForSamples(
        samples.map((s) => s.sampleUuid).toList(),
      );

      state = state.copyWith(
        samples: samples,
        photosBySample: photosMap,
        availableEstates: estates,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load samples: $e',
      );
    }
  }

  Future<void> setSearchQuery(String query) async {
    state = state.copyWith(searchQuery: query);
    await loadSamples();
  }

  Future<void> setStatusFilter(String status) async {
    state = state.copyWith(statusFilter: status);
    await loadSamples();
  }

  Future<void> setEstateFilter(String estate) async {
    state = state.copyWith(estateFilter: estate);
    await loadSamples();
  }

  Future<void> setLabelFilter(String label) async {
    state = state.copyWith(labelFilter: label);
    await loadSamples();
  }

  Future<void> setMissingSideFilter(String side) async {
    state = state.copyWith(missingSideFilter: side);
    await loadSamples();
  }

  void toggleSelection(String sampleUuid) {
    final next = Set<String>.from(state.selectedSampleUuids);
    if (next.contains(sampleUuid)) {
      next.remove(sampleUuid);
    } else {
      next.add(sampleUuid);
    }
    state = state.copyWith(
      selectedSampleUuids: next,
      isSelectionMode: next.isNotEmpty,
    );
  }

  void selectAll() {
    state = state.copyWith(
      selectedSampleUuids: state.samples.map((s) => s.sampleUuid).toSet(),
      isSelectionMode: state.samples.isNotEmpty,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      selectedSampleUuids: const {},
      isSelectionMode: false,
    );
  }

  Future<void> moveSelectedToTrash() async {
    if (state.selectedSampleUuids.isEmpty) return;
    await _deletionService
        .moveSamplesToTrash(state.selectedSampleUuids.toList());
    clearSelection();
    await loadSamples();
  }
}

final sampleListViewModelProvider =
    StateNotifierProvider.autoDispose<SampleListViewModel, SampleListState>(
  (ref) => SampleListViewModel(),
);

class SampleDetailState {
  final LeafSample? sample;
  final List<LeafPhoto> allPhotos;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  const SampleDetailState({
    this.sample,
    this.allPhotos = const [],
    this.isLoading = true,
    this.isSaving = false,
    this.errorMessage,
  });

  LeafPhoto? get upperPrimary => _findPrimary(LeafSide.upper.databaseKey);
  LeafPhoto? get lowerPrimary => _findPrimary(LeafSide.lower.databaseKey);

  List<LeafPhoto> get upperHistory => allPhotos
      .where((p) => p.leafSide == LeafSide.upper.databaseKey && p.isPrimary == 0)
      .toList();

  List<LeafPhoto> get lowerHistory => allPhotos
      .where((p) => p.leafSide == LeafSide.lower.databaseKey && p.isPrimary == 0)
      .toList();

  LeafPhoto? _findPrimary(String side) {
    for (final p in allPhotos) {
      if (p.leafSide == side && p.isPrimary == 1) return p;
    }
    return null;
  }

  SampleDetailState copyWith({
    LeafSample? sample,
    List<LeafPhoto>? allPhotos,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SampleDetailState(
      sample: sample ?? this.sample,
      allPhotos: allPhotos ?? this.allPhotos,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SampleDetailViewModel extends StateNotifier<SampleDetailState> {
  SampleDetailViewModel(this.sampleUuid) : super(const SampleDetailState()) {
    load();
  }

  final String sampleUuid;
  final SampleRepository _sampleRepo = SampleRepository();
  final PhotoRepository _photoRepo = PhotoRepository();
  final SampleDeletionService _deletionService = SampleDeletionService.instance;
  final SettingsService _settings = SettingsService.instance;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final sample = await _sampleRepo.getSampleByUuid(sampleUuid);
      final photos = await _photoRepo.getPhotosForSample(
        sampleUuid,
        includeNonPrimary: true,
      );
      state = state.copyWith(
        sample: sample,
        allPhotos: photos,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load sample: $e',
      );
    }
  }

  Future<void> updateFieldLabel(String fieldLabelKey) async {
    final sample = state.sample;
    if (sample == null) return;
    state = state.copyWith(isSaving: true);
    final updated = sample.copyWith(
      fieldLabel: fieldLabelKey,
      updatedAtUtc: AppDateUtils.nowUtcIso(),
    );
    await _sampleRepo.updateSample(updated);
    final allowSingle = await _settings.getAllowSingleSideComplete();
    await _sampleRepo.recalculateSampleStatus(
      sampleUuid,
      allowSingleSideComplete: allowSingle,
    );
    await load();
    state = state.copyWith(isSaving: false);
  }

  Future<void> submitExpertReview({
    required String expertLabelKey,
    required LabelStatus labelStatus,
    required String reviewerCode,
    bool markNeedsRecheck = false,
  }) async {
    state = state.copyWith(isSaving: true);
    await _sampleRepo.updateExpertReview(
      sampleUuid: sampleUuid,
      expertLabel: expertLabelKey,
      labelStatus: labelStatus,
      reviewerCode: reviewerCode.trim(),
      overrideSampleStatus:
          markNeedsRecheck ? SampleStatus.needsRecheck : null,
    );
    await load();
    state = state.copyWith(isSaving: false);
  }

  Future<void> movePhotoToTrash(String photoUuid) async {
    await _deletionService.movePhotoToTrash(photoUuid);
    await load();
  }

  Future<void> moveSampleToTrash() async {
    await _deletionService.moveSamplesToTrash([sampleUuid]);
  }
}

final sampleDetailViewModelProvider = StateNotifierProvider.autoDispose
    .family<SampleDetailViewModel, SampleDetailState, String>(
  (ref, sampleUuid) => SampleDetailViewModel(sampleUuid),
);
