import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../utils/id_generator.dart';

/// Persists non-secret application settings, presets, and generated device ID.
class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  static const String _keyDeviceId = 'device_id';
  static const String _keyProjectCode = 'project_code';
  static const String _keyCollectorCode = 'collector_code';
  static const String _keyEstates = 'estates_list';
  static const String _keyRegions = 'regions_list';
  static const String _keyDistricts = 'districts_list';
  static const String _keyImageQuality = 'image_quality';
  static const String _keyAllowSingleSideComplete =
      'allow_single_side_complete';
  static const String _keyIncludeGpsInDriveBackup =
      'include_gps_in_drive_backup';
  static const String _keyDriveRootFolderId = 'drive_root_folder_id';
  static const String _keyDriveProjectFolderId = 'drive_project_folder_id';
  static const String _keyDriveBackupsFolderId = 'drive_backups_folder_id';
  static const String _keyDriveAccountEmail = 'drive_account_email';
  static const String _keyGoogleServerClientId = 'google_server_client_id';
  static const String _keyCustomLabels = 'custom_disease_labels';

  static const List<String> defaultEstates = [
    'Pedro Estate',
    'Hantana Research Plot',
    'Talawakelle TRI',
    'Ratnapura TRI',
    'Passara TRI',
    'Kottawa Estate',
    'Dambatenne Estate',
    'Haputale Estate',
  ];

  static const List<String> defaultRegions = [
    'Up Country',
    'Mid Country',
    'Low Country',
    'Uva',
  ];

  static const List<String> defaultDistricts = [
    'Nuwara Eliya',
    'Kandy',
    'Badulla',
    'Ratnapura',
    'Matara',
    'Galle',
    'Kegalle',
    'Matale',
    'Kalutara',
  ];

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Returns the app-generated random device UUID (created once on first launch).
  Future<String> getOrCreateDeviceId() async {
    final prefs = await _preferences;
    var deviceId = prefs.getString(_keyDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = IdGenerator.generateDeviceId();
      await prefs.setString(_keyDeviceId, deviceId);
    }
    return deviceId;
  }

  Future<String> getProjectCode() async {
    final prefs = await _preferences;
    return prefs.getString(_keyProjectCode) ?? AppConstants.projectCodeDefault;
  }

  Future<void> setProjectCode(String code) async {
    final prefs = await _preferences;
    final cleaned = code.trim().isEmpty
        ? AppConstants.projectCodeDefault
        : code.trim().toUpperCase();
    await prefs.setString(_keyProjectCode, cleaned);
  }

  Future<String> getCollectorCode() async {
    final prefs = await _preferences;
    return prefs.getString(_keyCollectorCode) ?? '';
  }

  Future<void> setCollectorCode(String code) async {
    final prefs = await _preferences;
    await prefs.setString(_keyCollectorCode, code.trim());
  }

  Future<List<String>> getEstates() async {
    final prefs = await _preferences;
    return prefs.getStringList(_keyEstates) ?? List<String>.from(defaultEstates);
  }

  Future<void> setEstates(List<String> estates) async {
    final prefs = await _preferences;
    await prefs.setStringList(_keyEstates, estates);
  }

  Future<List<String>> getRegions() async {
    final prefs = await _preferences;
    return prefs.getStringList(_keyRegions) ?? List<String>.from(defaultRegions);
  }

  Future<void> setRegions(List<String> regions) async {
    final prefs = await _preferences;
    await prefs.setStringList(_keyRegions, regions);
  }

  Future<List<String>> getDistricts() async {
    final prefs = await _preferences;
    return prefs.getStringList(_keyDistricts) ??
        List<String>.from(defaultDistricts);
  }

  Future<void> setDistricts(List<String> districts) async {
    final prefs = await _preferences;
    await prefs.setStringList(_keyDistricts, districts);
  }

  Future<String> getImageQuality() async {
    final prefs = await _preferences;
    return prefs.getString(_keyImageQuality) ?? 'high';
  }

  Future<void> setImageQuality(String quality) async {
    final prefs = await _preferences;
    await prefs.setString(_keyImageQuality, quality);
  }

  Future<bool> getAllowSingleSideComplete() async {
    final prefs = await _preferences;
    return prefs.getBool(_keyAllowSingleSideComplete) ?? false;
  }

  Future<void> setAllowSingleSideComplete(bool allow) async {
    final prefs = await _preferences;
    await prefs.setBool(_keyAllowSingleSideComplete, allow);
  }

  Future<bool> getIncludeGpsInDriveBackup() async {
    final prefs = await _preferences;
    return prefs.getBool(_keyIncludeGpsInDriveBackup) ?? true;
  }

  Future<void> setIncludeGpsInDriveBackup(bool include) async {
    final prefs = await _preferences;
    await prefs.setBool(_keyIncludeGpsInDriveBackup, include);
  }

  Future<List<String>?> getCustomLabelKeys() async {
    final prefs = await _preferences;
    return prefs.getStringList(_keyCustomLabels);
  }

  Future<void> setCustomLabelKeys(List<String> keys) async {
    final prefs = await _preferences;
    await prefs.setStringList(_keyCustomLabels, keys);
  }

  Future<String?> getDriveRootFolderId() async {
    final prefs = await _preferences;
    return prefs.getString(_keyDriveRootFolderId);
  }

  Future<void> setDriveRootFolderId(String? id) async {
    final prefs = await _preferences;
    if (id == null) {
      await prefs.remove(_keyDriveRootFolderId);
    } else {
      await prefs.setString(_keyDriveRootFolderId, id);
    }
  }

  Future<String?> getDriveProjectFolderId(String projectCode) async {
    final prefs = await _preferences;
    return prefs.getString('${_keyDriveProjectFolderId}_$projectCode');
  }

  Future<void> setDriveProjectFolderId(String projectCode, String? id) async {
    final prefs = await _preferences;
    if (id == null) {
      await prefs.remove('${_keyDriveProjectFolderId}_$projectCode');
    } else {
      await prefs.setString('${_keyDriveProjectFolderId}_$projectCode', id);
    }
  }

  Future<String?> getDriveBackupsFolderId(String projectCode) async {
    final prefs = await _preferences;
    return prefs.getString('${_keyDriveBackupsFolderId}_$projectCode');
  }

  Future<void> setDriveBackupsFolderId(String projectCode, String? id) async {
    final prefs = await _preferences;
    if (id == null) {
      await prefs.remove('${_keyDriveBackupsFolderId}_$projectCode');
    } else {
      await prefs.setString('${_keyDriveBackupsFolderId}_$projectCode', id);
    }
  }

  Future<String?> getDriveAccountEmail() async {
    final prefs = await _preferences;
    return prefs.getString(_keyDriveAccountEmail);
  }

  Future<void> setDriveAccountEmail(String? email) async {
    final prefs = await _preferences;
    if (email == null) {
      await prefs.remove(_keyDriveAccountEmail);
    } else {
      await prefs.setString(_keyDriveAccountEmail, email);
    }
  }

  Future<String?> getGoogleServerClientId() async {
    final prefs = await _preferences;
    return prefs.getString(_keyGoogleServerClientId);
  }

  Future<void> setGoogleServerClientId(String? clientId) async {
    final prefs = await _preferences;
    if (clientId == null || clientId.trim().isEmpty) {
      await prefs.remove(_keyGoogleServerClientId);
    } else {
      await prefs.setString(_keyGoogleServerClientId, clientId.trim());
    }
  }
}
