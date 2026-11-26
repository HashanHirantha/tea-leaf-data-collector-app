import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'settings_service.dart';

/// Immutable snapshot of device and app provenance attached to captured photos.
class DeviceMetadata {
  final String deviceId;
  final String platform;
  final String manufacturer;
  final String model;
  final String osVersion;
  final String appVersion;

  const DeviceMetadata({
    required this.deviceId,
    required this.platform,
    required this.manufacturer,
    required this.model,
    required this.osVersion,
    required this.appVersion,
  });
}

/// Collects device hardware/OS details and app version without storing PII.
class DeviceInfoService {
  DeviceInfoService._();

  static final DeviceInfoService instance = DeviceInfoService._();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Reads platform device information and app version.
  /// Unavailable fields default to `'unknown'`.
  Future<DeviceMetadata> getDeviceMetadata() async {
    final deviceId = await SettingsService.instance.getOrCreateDeviceId();

    var appVersion = 'unknown';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (_) {
      appVersion = 'unknown';
    }

    var platform = 'unknown';
    var manufacturer = 'unknown';
    var model = 'unknown';
    var osVersion = 'unknown';

    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        platform = 'Android';
        manufacturer =
            info.manufacturer.isNotEmpty ? info.manufacturer : 'unknown';
        model = info.model.isNotEmpty ? info.model : 'unknown';
        osVersion = info.version.release.isNotEmpty
            ? 'Android ${info.version.release} (SDK ${info.version.sdkInt})'
            : 'SDK ${info.version.sdkInt}';
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        platform = 'iOS';
        manufacturer = 'Apple';
        model = info.utsname.machine.isNotEmpty
            ? info.utsname.machine
            : (info.model.isNotEmpty ? info.model : 'unknown');
        osVersion = info.systemVersion.isNotEmpty
            ? '${info.systemName} ${info.systemVersion}'
            : 'unknown';
      } else {
        platform = Platform.operatingSystem;
        osVersion = Platform.operatingSystemVersion;
      }
    } catch (_) {
      // Retain safe 'unknown' defaults if platform channel fails.
    }

    return DeviceMetadata(
      deviceId: deviceId,
      platform: platform,
      manufacturer: manufacturer,
      model: model,
      osVersion: osVersion,
      appVersion: appVersion,
    );
  }
}
