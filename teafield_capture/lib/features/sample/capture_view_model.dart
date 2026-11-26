import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/disease_classes.dart';
import '../../core/services/location_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/leaf_photo.dart';
import '../../data/models/leaf_sample.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/sample_repository.dart';

class CaptureState {
  final LeafSample? sample;
  final LeafPhoto? upperPhoto;
  final LeafPhoto? lowerPhoto;
  final GpsResult gpsResult;
  final bool isLoadingGps;
  final bool isInitializing;
  final bool isSaving;
  final List<String> estates;
  final List<String> regions;
  final List<String> districts;
  final String? selectedEstate;
  final String? selectedRegion;
  final String? selectedDistrict;
  final String bushPlotCode;
  final String collectorCode;
  final String fieldLabelKey;
  final int? severity;
  final String symptomNotes;
  final String otherNotes;
  final String? errorMessage;

  const CaptureState({
    this.sample,
    this.upperPhoto,
    this.lowerPhoto,
    this.gpsResult = const GpsResult(status: GpsStatus.notRequested),
    this.isLoadingGps = false,
    this.isInitializing = true,
    this.isSaving = false,
    this.estates = const [],
    this.regions = const [],
    this.districts = const [],
    this.selectedEstate,
    this.selectedRegion,
    this.selectedDistrict,
    this.bushPlotCode = '',
    this.collectorCode = '',
    this.fieldLabelKey = 'not_sure',
    this.severity,
    this.symptomNotes = '',
    this.otherNotes = '',
    this.errorMessage,
  });

  bool get hasUpper => upperPhoto != null;
  bool get hasLower => lowerPhoto != null;
  bool get hasAnyPhoto => hasUpper || hasLower;
  bool get hasBothPhotos => hasUpper && hasLower;

  CaptureState copyWith({
    LeafSample? sample,
    LeafPhoto? upperPhoto,
    LeafPhoto? lowerPhoto,
    GpsResult? gpsResult,
    bool? isLoadingGps,
    bool? isInitializing,
    bool? isSaving,
    List<String>? estates,
    List<String>? regions,
    List<String>? districts,
    String? selectedEstate,
    String? selectedRegion,
    String? selectedDistrict,
    String? bushPlotCode,
    String? collectorCode,
    String? fieldLabelKey,
    int? severity,
    bool clearSeverity = false,
    String? symptomNotes,
    String? otherNotes,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CaptureState(
      sample: sample ?? this.sample,
      upperPhoto: upperPhoto ?? this.upperPhoto,
      lowerPhoto: lowerPhoto ?? this.lowerPhoto,
      gpsResult: gpsResult ?? this.gpsResult,
      isLoadingGps: isLoadingGps ?? this.isLoadingGps,
      isInitializing: isInitializing ?? this.isInitializing,
      isSaving: isSaving ?? this.isSaving,
      estates: estates ?? this.estates,
      regions: regions ?? this.regions,
      districts: districts ?? this.districts,
      selectedEstate: selectedEstate ?? this.selectedEstate,
      selectedRegion: selectedRegion ?? this.selectedRegion,
      selectedDistrict: selectedDistrict ?? this.selectedDistrict,
      bushPlotCode: bushPlotCode ?? this.bushPlotCode,
      collectorCode: collectorCode ?? this.collectorCode,
      fieldLabelKey: fieldLabelKey ?? this.fieldLabelKey,
      severity: clearSeverity ? null : (severity ?? this.severity),
      symptomNotes: symptomNotes ?? this.symptomNotes,
      otherNotes: otherNotes ?? this.otherNotes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CaptureViewModel extends StateNotifier<CaptureState> {
  CaptureViewModel({String? existingSampleUuid})
      : super(const CaptureState()) {
    initialize(existingSampleUuid: existingSampleUuid);
  }

  final SampleRepository _sampleRepo = SampleRepository();
  final PhotoRepository _photoRepo = PhotoRepository();
  final SettingsService _settings = SettingsService.instance;
  final LocationService _location = LocationService.instance;

  /// Creates an early draft sample in SQLite (or resumes an existing draft)
  /// and starts foreground GPS acquisition.
  Future<void> initialize({String? existingSampleUuid}) async {
    state = state.copyWith(isInitializing: true, clearError: true);

    try {
      final deviceId = await _settings.getOrCreateDeviceId();
      final projectCode = await _settings.getProjectCode();
      final defaultCollector = await _settings.getCollectorCode();
      final estates = await _settings.getEstates();
      final regions = await _settings.getRegions();
      final districts = await _settings.getDistricts();

      LeafSample? sample;
      if (existingSampleUuid != null && existingSampleUuid.isNotEmpty) {
        sample = await _sampleRepo.getSampleByUuid(existingSampleUuid);
      }

      if (sample == null) {
        final now = AppDateUtils.nowUtcIso();
        final sampleUuid = IdGenerator.generateSampleUuid();
        final sampleCode = IdGenerator.generateSampleCode(
          IdGenerator.getDeviceShortId(deviceId),
        );

        sample = LeafSample(
          sampleUuid: sampleUuid,
          sampleCode: sampleCode,
          projectCode: projectCode,
          createdAtUtc: now,
          updatedAtUtc: now,
          createdByDeviceId: deviceId,
          masterDeviceId: deviceId,
          collectorCode: defaultCollector,
          fieldLabel: DiseaseClass.notSure.databaseKey,
          labelStatus: LabelStatus.pending.databaseKey,
          sampleGpsStatus: GpsStatus.notRequested.databaseKey,
          sampleStatus: SampleStatus.incomplete.databaseKey,
        );
        await _sampleRepo.createSample(sample);
      }

      final pair = await _photoRepo.getPrimaryPhotosForSample(sample.sampleUuid);

      state = state.copyWith(
        sample: sample,
        upperPhoto: pair.upper,
        lowerPhoto: pair.lower,
        estates: estates,
        regions: regions,
        districts: districts,
        selectedEstate: sample.estateName,
        selectedRegion: sample.region,
        selectedDistrict: sample.district,
        bushPlotCode: sample.bushPlotCode ?? '',
        collectorCode: sample.collectorCode ?? defaultCollector,
        fieldLabelKey: sample.fieldLabel,
        severity: sample.severity,
        symptomNotes: sample.symptomNotes ?? '',
        otherNotes: sample.otherNotes ?? '',
        gpsResult: GpsResult(
          latitude: sample.sampleLatitude,
          longitude: sample.sampleLongitude,
          accuracyMeters: sample.sampleGpsAccuracyM,
          capturedAtUtc: sample.sampleGpsCapturedAtUtc,
          status: GpsStatus.fromDatabaseKey(sample.sampleGpsStatus),
        ),
        isInitializing: false,
      );

      // Automatically request a GPS fix on form open if none captured yet.
      if (!sample.hasGps) {
        await refreshGpsFix();
      }
    } catch (e) {
      state = state.copyWith(
        isInitializing: false,
        errorMessage: 'Failed to prepare sample form: $e',
      );
    }
  }

  Future<void> refreshGpsFix() async {
    final sample = state.sample;
    if (sample == null) return;

    state = state.copyWith(isLoadingGps: true);
    final gps = await _location.getCurrentGpsFix();

    final updated = sample.copyWith(
      sampleLatitude: gps.isCaptured ? gps.latitude : sample.sampleLatitude,
      sampleLongitude: gps.isCaptured ? gps.longitude : sample.sampleLongitude,
      sampleGpsAccuracyM:
          gps.isCaptured ? gps.accuracyMeters : sample.sampleGpsAccuracyM,
      sampleGpsCapturedAtUtc:
          gps.isCaptured ? gps.capturedAtUtc : sample.sampleGpsCapturedAtUtc,
      sampleGpsStatus: gps.status.databaseKey,
      updatedAtUtc: AppDateUtils.nowUtcIso(),
    );

    await _sampleRepo.updateSample(updated);

    state = state.copyWith(
      sample: updated,
      gpsResult: gps,
      isLoadingGps: false,
    );
  }

  /// Reloads upper/lower photos after returning from the camera screen.
  Future<void> reloadPhotos() async {
    final sample = state.sample;
    if (sample == null) return;
    final pair = await _photoRepo.getPrimaryPhotosForSample(sample.sampleUuid);
    final refreshedSample =
        await _sampleRepo.getSampleByUuid(sample.sampleUuid);

    state = state.copyWith(
      sample: refreshedSample ?? sample,
      upperPhoto: pair.upper,
      lowerPhoto: pair.lower,
    );
  }

  void setEstate(String? value) => state = state.copyWith(selectedEstate: value);
  void setRegion(String? value) => state = state.copyWith(selectedRegion: value);
  void setDistrict(String? value) =>
      state = state.copyWith(selectedDistrict: value);
  void setBushPlotCode(String value) =>
      state = state.copyWith(bushPlotCode: value);
  void setCollectorCode(String value) =>
      state = state.copyWith(collectorCode: value);
  void setFieldLabel(String key) =>
      state = state.copyWith(fieldLabelKey: key);

  void setSeverity(int? value) {
    if (value == null || state.severity == value) {
      state = state.copyWith(clearSeverity: true);
    } else {
      state = state.copyWith(severity: value);
    }
  }

  void setSymptomNotes(String value) =>
      state = state.copyWith(symptomNotes: value);
  void setOtherNotes(String value) => state = state.copyWith(otherNotes: value);

  /// Persists the current sample form metadata and recalculates status.
  Future<LeafSample?> saveSample({bool asIncomplete = false}) async {
    final current = state.sample;
    if (current == null) return null;

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final allowSingleSide = await _settings.getAllowSingleSideComplete();
      final updated = current.copyWith(
        estateName: _emptyToNull(state.selectedEstate),
        region: _emptyToNull(state.selectedRegion),
        district: _emptyToNull(state.selectedDistrict),
        bushPlotCode: _emptyToNull(state.bushPlotCode),
        collectorCode: _emptyToNull(state.collectorCode),
        fieldLabel: state.fieldLabelKey,
        severity: state.severity,
        symptomNotes: _emptyToNull(state.symptomNotes),
        otherNotes: _emptyToNull(state.otherNotes),
        updatedAtUtc: AppDateUtils.nowUtcIso(),
      );

      await _sampleRepo.updateSample(updated);

      if (asIncomplete) {
        final incompleteSample = updated.copyWith(
          sampleStatus: SampleStatus.incomplete.databaseKey,
        );
        await _sampleRepo.updateSample(incompleteSample);
        state = state.copyWith(sample: incompleteSample, isSaving: false);
        return incompleteSample;
      }

      await _sampleRepo.recalculateSampleStatus(
        updated.sampleUuid,
        allowSingleSideComplete: allowSingleSide,
      );
      final finalSample = await _sampleRepo.getSampleByUuid(updated.sampleUuid);
      state = state.copyWith(
        sample: finalSample ?? updated,
        isSaving: false,
      );
      return finalSample ?? updated;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save sample: $e',
      );
      return null;
    }
  }

  String? _emptyToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

final captureViewModelProvider = StateNotifierProvider.autoDispose
    .family<CaptureViewModel, CaptureState, String?>((ref, existingSampleUuid) {
  return CaptureViewModel(existingSampleUuid: existingSampleUuid);
});
