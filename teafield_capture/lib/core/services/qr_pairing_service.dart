import 'dart:convert';

import '../constants/app_constants.dart';

/// Compact QR payload shared between two phones photographing the same leaf.
///
/// Intentionally excludes GPS coordinates, collector PII, and review notes.
class QrPairingData {
  final String app;
  final int version;
  final String projectCode;
  final String sampleUuid;
  final String sampleCode;

  const QrPairingData({
    this.app = AppConstants.qrAppIdentifier,
    this.version = AppConstants.qrSchemaVersion,
    required this.projectCode,
    required this.sampleUuid,
    required this.sampleCode,
  });

  Map<String, dynamic> toJsonMap() => {
        'app': app,
        'version': version,
        'project_code': projectCode,
        'sample_uuid': sampleUuid,
        'sample_code': sampleCode,
      };
}

/// Validation result for a scanned sample QR code.
class QrValidationResult {
  final QrPairingData? data;
  final String? errorMessage;

  const QrValidationResult({this.data, this.errorMessage});

  bool get isValid => data != null && errorMessage == null;
}

/// Generates and validates cross-device QR pairing payloads.
class QrPairingService {
  QrPairingService._();

  static final QrPairingService instance = QrPairingService._();

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Encodes the sample identity into a compact JSON string for QR display.
  String generateQrPayload({
    required String projectCode,
    required String sampleUuid,
    required String sampleCode,
  }) {
    final payload = QrPairingData(
      projectCode: projectCode,
      sampleUuid: sampleUuid,
      sampleCode: sampleCode,
    );
    return json.encode(payload.toJsonMap());
  }

  /// Parses and validates a scanned QR string against [expectedProjectCode].
  QrValidationResult parseAndValidate(
    String rawData, {
    required String expectedProjectCode,
  }) {
    try {
      final decoded = json.decode(rawData);
      if (decoded is! Map<String, dynamic>) {
        return const QrValidationResult(
          errorMessage: 'QR code is not a valid TeaField JSON payload.',
        );
      }

      final app = decoded['app'];
      if (app != AppConstants.qrAppIdentifier) {
        return const QrValidationResult(
          errorMessage: 'This QR code does not belong to TeaField Capture.',
        );
      }

      final version = decoded['version'];
      if (version is! int || version != AppConstants.qrSchemaVersion) {
        return QrValidationResult(
          errorMessage: 'Unsupported QR schema version: $version.',
        );
      }

      final projectCode = decoded['project_code'] as String?;
      if (projectCode == null || projectCode.isEmpty) {
        return const QrValidationResult(
          errorMessage: 'QR code is missing a project code.',
        );
      }
      if (projectCode != expectedProjectCode) {
        return QrValidationResult(
          errorMessage:
              'Project mismatch: QR belongs to "$projectCode", but this phone is set to "$expectedProjectCode".',
        );
      }

      final sampleUuid = decoded['sample_uuid'] as String?;
      if (sampleUuid == null || !_uuidRegex.hasMatch(sampleUuid)) {
        return const QrValidationResult(
          errorMessage: 'QR code contains an invalid sample UUID.',
        );
      }

      final sampleCode = decoded['sample_code'] as String?;
      if (sampleCode == null || sampleCode.isEmpty) {
        return const QrValidationResult(
          errorMessage: 'QR code is missing a sample code.',
        );
      }

      return QrValidationResult(
        data: QrPairingData(
          app: app as String,
          version: version,
          projectCode: projectCode,
          sampleUuid: sampleUuid,
          sampleCode: sampleCode,
        ),
      );
    } catch (_) {
      return const QrValidationResult(
        errorMessage: 'Could not parse QR code. Scan a valid TeaField sample QR.',
      );
    }
  }
}
