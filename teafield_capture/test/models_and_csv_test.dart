import 'package:flutter_test/flutter_test.dart';
import 'package:teafield_capture/core/services/package_transfer_service.dart';
import 'package:teafield_capture/core/utils/checksum.dart';
import 'package:teafield_capture/core/utils/id_generator.dart';
import 'package:teafield_capture/data/models/leaf_photo.dart';
import 'package:teafield_capture/data/models/leaf_sample.dart';

void main() {
  test('LeafSample round-trips through toMap and fromMap', () {
    const sample = LeafSample(
      sampleUuid: '11111111-1111-4111-8111-111111111111',
      sampleCode: 'TEA-20261126-ABCD-12345',
      projectCode: 'SL_TEA_RESEARCH',
      createdAtUtc: '2026-11-26T05:00:00Z',
      updatedAtUtc: '2026-11-26T05:00:00Z',
      createdByDeviceId: 'dev-1',
      estateName: 'Pedro Estate',
      fieldLabel: 'blister_blight',
      sampleLatitude: 6.968,
      sampleLongitude: 80.783,
      sampleGpsAccuracyM: 8.4,
      sampleGpsStatus: 'captured',
      sampleStatus: 'ready_for_review',
    );

    final restored = LeafSample.fromMap(sample.toMap());
    expect(restored.sampleUuid, sample.sampleUuid);
    expect(restored.estateName, 'Pedro Estate');
    expect(restored.fieldLabel, 'blister_blight');
    expect(restored.sampleLatitude, 6.968);
    expect(restored.hasGps, isTrue);
  });

  test('buildSamplesCsvString outputs exactly one row per physical leaf', () {
    final service = PackageTransferService.instance;

    const sample = LeafSample(
      sampleUuid: '11111111-1111-4111-8111-111111111111',
      sampleCode: 'TEA-20261126-ABCD-12345',
      projectCode: 'SL_TEA_RESEARCH',
      createdAtUtc: '2026-11-26T05:00:00Z',
      updatedAtUtc: '2026-11-26T05:00:00Z',
      createdByDeviceId: 'dev-1',
      estateName: 'Hantana Research Plot',
      fieldLabel: 'gray_blight',
    );

    const upperPhoto = LeafPhoto(
      photoUuid: '22222222-2222-4222-8222-222222222222',
      sampleUuid: '11111111-1111-4111-8111-111111111111',
      leafSide: 'upper',
      filePath: '/tmp/upper.jpg',
      sha256: 'abc',
      capturedAtUtc: '2026-11-26T05:00:05Z',
      deviceId: 'dev-1',
      deviceModel: 'Redmi Note',
      createdAtUtc: '2026-11-26T05:00:05Z',
    );

    const lowerPhoto = LeafPhoto(
      photoUuid: '33333333-3333-4333-8333-333333333333',
      sampleUuid: '11111111-1111-4111-8111-111111111111',
      leafSide: 'lower',
      filePath: '/tmp/lower.jpg',
      sha256: 'def',
      capturedAtUtc: '2026-11-26T05:00:25Z',
      deviceId: 'dev-2',
      deviceModel: 'iPhone 14',
      createdAtUtc: '2026-11-26T05:00:25Z',
    );

    final csv = service.buildSamplesCsvString(
      samples: const [sample],
      photos: const [upperPhoto, lowerPhoto],
    );

    final lines = csv.trim().split('\n');
    expect(lines.length, 2); // 1 header + 1 leaf row
    expect(lines[1], contains('Redmi Note'));
    expect(lines[1], contains('iPhone 14'));
  });

  test('IdGenerator produces valid sample codes and SHA-256 helper is deterministic', () {
    final code = IdGenerator.generateSampleCode('a7k3');
    expect(code, startsWith('TEA-'));
    expect(code, contains('-A7K3-'));

    final hash1 = Checksum.calculateBytesChecksum([1, 2, 3, 4]);
    final hash2 = Checksum.calculateBytesChecksum([1, 2, 3, 4]);
    expect(hash1, hash2);
    expect(hash1.length, 64);
  });
}
