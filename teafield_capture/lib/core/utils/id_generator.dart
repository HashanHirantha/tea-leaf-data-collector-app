import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

/// Generates unique identifiers for samples, photos, and devices.
class IdGenerator {
  IdGenerator._();

  static const Uuid _uuid = Uuid();
  static final Random _random = Random.secure();

  /// Generate a UUID v4 for a new leaf sample.
  static String generateSampleUuid() => _uuid.v4();

  /// Generate a UUID v4 for a new photo capture.
  static String generatePhotoUuid() => _uuid.v4();

  /// Generate a UUID v4 for first-launch device identification.
  static String generateDeviceId() => _uuid.v4();

  /// Generate a UUID v4 for a backup batch.
  static String generateBackupId() => _uuid.v4();

  /// Generate a UUID v4 for an import record.
  static String generateImportId() => _uuid.v4();

  /// Generate a human-readable sample code.
  ///
  /// Format: `TEA-YYYYMMDD-XXXX-NNNNN`
  /// where XXXX is a short device identifier and NNNNN is random.
  static String generateSampleCode(String deviceShortId) {
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    final devicePart = deviceShortId.length >= 4
        ? deviceShortId.substring(0, 4).toUpperCase()
        : deviceShortId.padRight(4, '0').toUpperCase();
    final randomPart = _generateRandomAlphanumeric(5);
    return 'TEA-$date-$devicePart-$randomPart';
  }

  /// Generate a short device identifier (first 4 chars of device UUID).
  static String getDeviceShortId(String deviceId) {
    return deviceId.replaceAll('-', '').substring(0, 4).toUpperCase();
  }

  static String _generateRandomAlphanumeric(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I, O, 0, 1
    return List.generate(
      length,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }
}
