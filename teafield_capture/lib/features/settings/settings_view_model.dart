import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/settings_service.dart';

class SettingsState {
  final String projectCode;
  final String collectorCode;
  final String deviceId;
  final List<String> estates;
  final List<String> regions;
  final List<String> districts;
  final String imageQuality;
  final bool allowSingleSideComplete;
  final String? driveAccountEmail;
  final String googleServerClientId;
  final String appVersion;
  final bool isLoading;
  final bool isSaving;

  const SettingsState({
    this.projectCode = AppConstants.projectCodeDefault,
    this.collectorCode = '',
    this.deviceId = '',
    this.estates = const [],
    this.regions = const [],
    this.districts = const [],
    this.imageQuality = 'high',
    this.allowSingleSideComplete = false,
    this.driveAccountEmail,
    this.googleServerClientId = '',
    this.appVersion = '1.0.0',
    this.isLoading = true,
    this.isSaving = false,
  });

  SettingsState copyWith({
    String? projectCode,
    String? collectorCode,
    String? deviceId,
    List<String>? estates,
    List<String>? regions,
    List<String>? districts,
    String? imageQuality,
    bool? allowSingleSideComplete,
    String? driveAccountEmail,
    String? googleServerClientId,
    String? appVersion,
    bool? isLoading,
    bool? isSaving,
  }) {
    return SettingsState(
      projectCode: projectCode ?? this.projectCode,
      collectorCode: collectorCode ?? this.collectorCode,
      deviceId: deviceId ?? this.deviceId,
      estates: estates ?? this.estates,
      regions: regions ?? this.regions,
      districts: districts ?? this.districts,
      imageQuality: imageQuality ?? this.imageQuality,
      allowSingleSideComplete:
          allowSingleSideComplete ?? this.allowSingleSideComplete,
      driveAccountEmail: driveAccountEmail ?? this.driveAccountEmail,
      googleServerClientId: googleServerClientId ?? this.googleServerClientId,
      appVersion: appVersion ?? this.appVersion,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class SettingsViewModel extends StateNotifier<SettingsState> {
  SettingsViewModel() : super(const SettingsState()) {
    load();
  }

  final SettingsService _settings = SettingsService.instance;

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final projectCode = await _settings.getProjectCode();
    final collectorCode = await _settings.getCollectorCode();
    final deviceId = await _settings.getOrCreateDeviceId();
    final estates = await _settings.getEstates();
    final regions = await _settings.getRegions();
    final districts = await _settings.getDistricts();
    final imageQuality = await _settings.getImageQuality();
    final allowSingle = await _settings.getAllowSingleSideComplete();
    final driveEmail = await _settings.getDriveAccountEmail();
    final serverClientId = await _settings.getGoogleServerClientId() ?? '';

    var appVer = '1.0.0';
    try {
      final pkg = await PackageInfo.fromPlatform();
      appVer = '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {
      // Fallback on unsupported test platforms.
    }

    state = state.copyWith(
      projectCode: projectCode,
      collectorCode: collectorCode,
      deviceId: deviceId,
      estates: estates,
      regions: regions,
      districts: districts,
      imageQuality: imageQuality,
      allowSingleSideComplete: allowSingle,
      driveAccountEmail: driveEmail,
      googleServerClientId: serverClientId,
      appVersion: appVer,
      isLoading: false,
    );
  }

  Future<void> saveSettings({
    required String projectCode,
    required String collectorCode,
    required String imageQuality,
    required bool allowSingleSideComplete,
    required String googleServerClientId,
  }) async {
    state = state.copyWith(isSaving: true);
    await _settings.setProjectCode(projectCode);
    await _settings.setCollectorCode(collectorCode);
    await _settings.setImageQuality(imageQuality);
    await _settings.setAllowSingleSideComplete(allowSingleSideComplete);
    await _settings.setGoogleServerClientId(googleServerClientId);
    await load();
    state = state.copyWith(isSaving: false);
  }

  Future<void> addEstate(String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty || state.estates.contains(cleaned)) return;
    final next = [...state.estates, cleaned];
    await _settings.setEstates(next);
    state = state.copyWith(estates: next);
  }

  Future<void> removeEstate(String name) async {
    final next = state.estates.where((e) => e != name).toList();
    await _settings.setEstates(next);
    state = state.copyWith(estates: next);
  }

  Future<void> addRegion(String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty || state.regions.contains(cleaned)) return;
    final next = [...state.regions, cleaned];
    await _settings.setRegions(next);
    state = state.copyWith(regions: next);
  }

  Future<void> removeRegion(String name) async {
    final next = state.regions.where((e) => e != name).toList();
    await _settings.setRegions(next);
    state = state.copyWith(regions: next);
  }

  Future<void> addDistrict(String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty || state.districts.contains(cleaned)) return;
    final next = [...state.districts, cleaned];
    await _settings.setDistricts(next);
    state = state.copyWith(districts: next);
  }

  Future<void> removeDistrict(String name) async {
    final next = state.districts.where((e) => e != name).toList();
    await _settings.setDistricts(next);
    state = state.copyWith(districts: next);
  }
}

final settingsViewModelProvider =
    StateNotifierProvider.autoDispose<SettingsViewModel, SettingsState>(
  (ref) => SettingsViewModel(),
);
