import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/disease_classes.dart';
import '../../core/services/qr_pairing_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/models/leaf_sample.dart';
import '../../data/repositories/sample_repository.dart';

class JoinSampleState {
  final QrPairingData? parsedData;
  final LeafSide selectedSide;
  final bool alreadyExistsLocally;
  final String? errorMessage;
  final bool isProcessing;

  const JoinSampleState({
    this.parsedData,
    this.selectedSide = LeafSide.lower,
    this.alreadyExistsLocally = false,
    this.errorMessage,
    this.isProcessing = false,
  });

  bool get isValid => parsedData != null && errorMessage == null;

  JoinSampleState copyWith({
    QrPairingData? parsedData,
    bool clearParsed = false,
    LeafSide? selectedSide,
    bool? alreadyExistsLocally,
    String? errorMessage,
    bool clearError = false,
    bool? isProcessing,
  }) {
    return JoinSampleState(
      parsedData: clearParsed ? null : (parsedData ?? this.parsedData),
      selectedSide: selectedSide ?? this.selectedSide,
      alreadyExistsLocally:
          alreadyExistsLocally ?? this.alreadyExistsLocally,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class JoinSampleViewModel extends StateNotifier<JoinSampleState> {
  JoinSampleViewModel() : super(const JoinSampleState());

  final QrPairingService _qrService = QrPairingService.instance;
  final SampleRepository _sampleRepo = SampleRepository();
  final SettingsService _settings = SettingsService.instance;

  Future<void> handleScannedRawData(String rawData) async {
    if (state.isProcessing) return;
    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      final expectedProject = await _settings.getProjectCode();
      final result = _qrService.parseAndValidate(
        rawData,
        expectedProjectCode: expectedProject,
      );

      if (!result.isValid || result.data == null) {
        state = state.copyWith(
          clearParsed: true,
          errorMessage: result.errorMessage ?? 'Invalid QR code.',
          isProcessing: false,
        );
        return;
      }

      final existing =
          await _sampleRepo.getSampleByUuid(result.data!.sampleUuid);

      state = state.copyWith(
        parsedData: result.data,
        alreadyExistsLocally: existing != null,
        clearError: true,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(
        clearParsed: true,
        errorMessage: 'Error validating QR: $e',
        isProcessing: false,
      );
    }
  }

  void setSelectedSide(LeafSide side) {
    state = state.copyWith(selectedSide: side);
  }

  void resetScan() {
    state = const JoinSampleState();
  }

  /// Finds an existing local sample with the scanned `sample_uuid` or creates
  /// a linked local stub so the second phone can immediately photograph the
  /// assigned side offline.
  Future<LeafSample?> ensureLocalLinkedSample() async {
    final data = state.parsedData;
    if (data == null) return null;

    final existing = await _sampleRepo.getSampleByUuid(data.sampleUuid);
    if (existing != null) return existing;

    final deviceId = await _settings.getOrCreateDeviceId();
    final collectorCode = await _settings.getCollectorCode();
    final now = AppDateUtils.nowUtcIso();

    final stub = LeafSample(
      sampleUuid: data.sampleUuid,
      sampleCode: data.sampleCode,
      projectCode: data.projectCode,
      createdAtUtc: now,
      updatedAtUtc: now,
      createdByDeviceId: deviceId,
      collectorCode: collectorCode,
      fieldLabel: DiseaseClass.notSure.databaseKey,
      labelStatus: LabelStatus.pending.databaseKey,
      sampleGpsStatus: GpsStatus.notRequested.databaseKey,
      sampleStatus: SampleStatus.incomplete.databaseKey,
      isImported: 1,
      sourceSampleUuid: data.sampleUuid,
    );

    await _sampleRepo.createSample(stub);
    return stub;
  }
}

final joinSampleViewModelProvider =
    StateNotifierProvider.autoDispose<JoinSampleViewModel, JoinSampleState>(
  (ref) => JoinSampleViewModel(),
);
