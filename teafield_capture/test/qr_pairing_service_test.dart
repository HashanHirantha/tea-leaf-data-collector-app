import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:teafield_capture/core/services/qr_pairing_service.dart';
import 'package:teafield_capture/core/utils/id_generator.dart';

void main() {
  final service = QrPairingService.instance;

  test('generates compact QR JSON without GPS or personal info', () {
    final uuid = IdGenerator.generateSampleUuid();
    final payload = service.generateQrPayload(
      projectCode: 'SL_TEA_RESEARCH',
      sampleUuid: uuid,
      sampleCode: 'TEA-20261126-A7K3-B2C4D',
    );

    final decoded = json.decode(payload) as Map<String, dynamic>;
    expect(decoded['app'], 'teafield');
    expect(decoded['version'], 1);
    expect(decoded['project_code'], 'SL_TEA_RESEARCH');
    expect(decoded['sample_uuid'], uuid);
    expect(decoded['sample_code'], 'TEA-20261126-A7K3-B2C4D');
    expect(decoded.containsKey('latitude'), isFalse);
    expect(decoded.containsKey('longitude'), isFalse);
    expect(decoded.containsKey('collector_code'), isFalse);
  });

  test('validates matching project and valid UUID', () {
    final uuid = IdGenerator.generateSampleUuid();
    final payload = service.generateQrPayload(
      projectCode: 'SL_TEA_RESEARCH',
      sampleUuid: uuid,
      sampleCode: 'TEA-20261126-A7K3-00042',
    );

    final result = service.parseAndValidate(
      payload,
      expectedProjectCode: 'SL_TEA_RESEARCH',
    );

    expect(result.isValid, isTrue);
    expect(result.data?.sampleUuid, uuid);
    expect(result.data?.sampleCode, 'TEA-20261126-A7K3-00042');
  });

  test('rejects mismatched project code', () {
    final uuid = IdGenerator.generateSampleUuid();
    final payload = service.generateQrPayload(
      projectCode: 'OTHER_PROJECT',
      sampleUuid: uuid,
      sampleCode: 'TEA-20261126-A7K3-00042',
    );

    final result = service.parseAndValidate(
      payload,
      expectedProjectCode: 'SL_TEA_RESEARCH',
    );

    expect(result.isValid, isFalse);
    expect(result.errorMessage, contains('Project mismatch'));
  });

  test('rejects malformed UUID', () {
    const raw = '{"app":"teafield","version":1,"project_code":"SL_TEA_RESEARCH","sample_uuid":"not-a-uuid","sample_code":"TEA-1"}';
    final result = service.parseAndValidate(
      raw,
      expectedProjectCode: 'SL_TEA_RESEARCH',
    );

    expect(result.isValid, isFalse);
    expect(result.errorMessage, contains('UUID'));
  });
}
