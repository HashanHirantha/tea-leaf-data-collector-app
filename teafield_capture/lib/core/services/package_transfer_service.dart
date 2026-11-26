import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../data/models/import_record.dart';
import '../../data/models/leaf_photo.dart';
import '../../data/models/leaf_sample.dart';
import '../../data/models/transfer_manifest.dart';
import '../../data/repositories/backup_repository.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/sample_repository.dart';
import '../constants/app_constants.dart';
import '../utils/app_date_utils.dart';
import '../utils/checksum.dart';
import '../utils/id_generator.dart';
import 'device_info_service.dart';
import 'file_storage_service.dart';
import 'settings_service.dart';

/// Result of exporting a research ZIP or CSV package.
class ExportPackageResult {
  final String filePath;
  final String fileName;
  final String sha256;
  final int fileSizeBytes;
  final int sampleCount;
  final int photoCount;

  const ExportPackageResult({
    required this.filePath,
    required this.fileName,
    required this.sha256,
    required this.fileSizeBytes,
    required this.sampleCount,
    required this.photoCount,
  });
}

/// Preview metadata read from a ZIP package before importing.
class PackagePreview {
  final String zipPath;
  final String fileName;
  final TransferManifest manifest;
  final String packageSha256;

  const PackagePreview({
    required this.zipPath,
    required this.fileName,
    required this.manifest,
    required this.packageSha256,
  });
}

/// Handles exporting research ZIP/CSV/JSON packages and offline ZIP merging.
class PackageTransferService {
  PackageTransferService({
    SampleRepository? sampleRepository,
    PhotoRepository? photoRepository,
    BackupRepository? backupRepository,
    FileStorageService? fileStorageService,
    SettingsService? settingsService,
  })  : _sampleRepo = sampleRepository ?? SampleRepository(),
        _photoRepo = photoRepository ?? PhotoRepository(),
        _backupRepo = backupRepository ?? BackupRepository(),
        _storage = fileStorageService ?? FileStorageService.instance,
        _settings = settingsService ?? SettingsService.instance;

  static final PackageTransferService instance = PackageTransferService();

  final SampleRepository _sampleRepo;
  final PhotoRepository _photoRepo;
  final BackupRepository _backupRepo;
  final FileStorageService _storage;
  final SettingsService _settings;

  /// Exports a full archival research ZIP containing original photos,
  /// `manifest.json`, `samples.json`, `photos.json`, `samples.csv`,
  /// `photos.csv`, and `checksums.sha256`.
  Future<ExportPackageResult> exportResearchZip({
    required List<LeafSample> samples,
    String? customFileName,
    bool omitGps = false,
    bool includeRetakeHistory = true,
    void Function(double progress)? onProgress,
  }) async {
    final deviceMeta = await DeviceInfoService.instance.getDeviceMetadata();
    final projectCode = await _settings.getProjectCode();
    final exportsDir = await _storage.getExportsDirectory();

    final sampleUuids = samples.map((s) => s.sampleUuid).toList();
    final allPhotos = await _photoRepo.getPhotosForSamples(
      sampleUuids,
      primaryOnly: !includeRetakeHistory,
    );

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now().toUtc());
    final shortDevice = IdGenerator.getDeviceShortId(deviceMeta.deviceId);
    final fileName =
        customFileName ?? 'teafield_export_${shortDevice}_$timestamp.zip';
    final zipPath = p.join(exportsDir.path, fileName);

    final sanitizedSamples = samples
        .map((s) => omitGps ? _redactSampleGps(s) : s)
        .toList();

    final photoZipRelPaths = <String, String>{};
    final includedPhotos = <LeafPhoto>[];
    final checksumLines = <String>[];

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    try {
      // 1. Add original photos first and record their ZIP-relative paths & checksums.
      for (var i = 0; i < allPhotos.length; i++) {
        final photo = allPhotos[i];
        final file = File(photo.filePath);
        if (!await file.exists()) continue;

        final ext = p.extension(photo.filePath).isNotEmpty
            ? p.extension(photo.filePath).toLowerCase()
            : '.jpg';
        final zipRelPath =
            'photos/${photo.sampleUuid}/${photo.photoUuid}_${photo.leafSide}$ext';

        await encoder.addFile(file, zipRelPath);
        final fileSha = await Checksum.calculateFileChecksum(photo.filePath);
        checksumLines.add('$fileSha  $zipRelPath');

        photoZipRelPaths[photo.photoUuid] = zipRelPath;
        includedPhotos.add(omitGps ? _redactPhotoGps(photo) : photo);

        if (onProgress != null && allPhotos.isNotEmpty) {
          onProgress(0.75 * ((i + 1) / allPhotos.length));
        }
      }

      // 2. Build samples.json & photos.json
      final samplesJsonBytes = utf8.encode(
        const JsonEncoder.withIndent('  ')
            .convert(sanitizedSamples.map((s) => s.toMap()).toList()),
      );
      final photosJsonList = includedPhotos.map((photo) {
        final map = photo.toMap();
        map['zip_path'] = photoZipRelPaths[photo.photoUuid];
        return map;
      }).toList();
      final photosJsonBytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(photosJsonList),
      );

      // 3. Build samples.csv & photos.csv
      final samplesCsvBytes = utf8.encode(
        buildSamplesCsvString(
          samples: sanitizedSamples,
          photos: includedPhotos,
          zipRelativePaths: photoZipRelPaths,
        ),
      );
      final photosCsvBytes = utf8.encode(
        buildPhotosCsvString(
          photos: includedPhotos,
          zipRelativePaths: photoZipRelPaths,
        ),
      );

      // 4. Build manifest.json
      final manifest = TransferManifest(
        schemaVersion: AppConstants.qrSchemaVersion,
        projectCode: projectCode,
        exportDeviceId: deviceMeta.deviceId,
        exportTimeUtc: AppDateUtils.nowUtcIso(),
        sampleCount: sanitizedSamples.length,
        photoCount: includedPhotos.length,
        appVersion: deviceMeta.appVersion,
      );
      final manifestBytes = utf8.encode(manifest.toJson());

      // Add metadata files & record checksums for every metadata file.
      final metadataEntries = <(String, List<int>)>[
        ('manifest.json', manifestBytes),
        ('samples.json', samplesJsonBytes),
        ('photos.json', photosJsonBytes),
        ('samples.csv', samplesCsvBytes),
        ('photos.csv', photosCsvBytes),
      ];

      for (final entry in metadataEntries) {
        final name = entry.$1;
        final bytes = entry.$2;
        encoder.addArchiveFile(ArchiveFile(name, bytes.length, bytes));
        final sha = Checksum.calculateBytesChecksum(bytes);
        checksumLines.add('$sha  $name');
      }

      final checksumBytes = utf8.encode('${checksumLines.join('\n')}\n');
      encoder.addArchiveFile(
        ArchiveFile('checksums.sha256', checksumBytes.length, checksumBytes),
      );
    } finally {
      await encoder.close();
    }

    onProgress?.call(1.0);

    final zipFile = File(zipPath);
    final zipSha = await Checksum.calculateFileChecksum(zipPath);
    final zipSize = await zipFile.length();

    return ExportPackageResult(
      filePath: zipPath,
      fileName: fileName,
      sha256: zipSha,
      fileSizeBytes: zipSize,
      sampleCount: sanitizedSamples.length,
      photoCount: includedPhotos.length,
    );
  }

  /// Exports one-row-per-leaf sample CSV summary.
  Future<ExportPackageResult> exportSampleSummaryCsv({
    required List<LeafSample> samples,
    bool omitGps = false,
  }) async {
    final exportsDir = await _storage.getExportsDirectory();
    final sampleUuids = samples.map((s) => s.sampleUuid).toList();
    final photos = await _photoRepo.getPhotosForSamples(
      sampleUuids,
      primaryOnly: true,
    );

    final sanitized =
        samples.map((s) => omitGps ? _redactSampleGps(s) : s).toList();
    final csvString = buildSamplesCsvString(
      samples: sanitized,
      photos: photos,
    );

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now().toUtc());
    final fileName = 'teafield_samples_$timestamp.csv';
    final path = p.join(exportsDir.path, fileName);
    final bytes = utf8.encode(csvString);
    await File(path).writeAsBytes(bytes, flush: true);

    return ExportPackageResult(
      filePath: path,
      fileName: fileName,
      sha256: Checksum.calculateBytesChecksum(bytes),
      fileSizeBytes: bytes.length,
      sampleCount: sanitized.length,
      photoCount: photos.length,
    );
  }

  /// Exports one-row-per-photograph CSV audit table.
  Future<ExportPackageResult> exportImageLevelCsv({
    required List<LeafSample> samples,
    bool omitGps = false,
  }) async {
    final exportsDir = await _storage.getExportsDirectory();
    final sampleUuids = samples.map((s) => s.sampleUuid).toList();
    final photos = await _photoRepo.getPhotosForSamples(
      sampleUuids,
      primaryOnly: false,
    );

    final sanitizedPhotos =
        photos.map((p) => omitGps ? _redactPhotoGps(p) : p).toList();
    final csvString = buildPhotosCsvString(photos: sanitizedPhotos);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now().toUtc());
    final fileName = 'teafield_photos_$timestamp.csv';
    final path = p.join(exportsDir.path, fileName);
    final bytes = utf8.encode(csvString);
    await File(path).writeAsBytes(bytes, flush: true);

    return ExportPackageResult(
      filePath: path,
      fileName: fileName,
      sha256: Checksum.calculateBytesChecksum(bytes),
      fileSizeBytes: bytes.length,
      sampleCount: samples.length,
      photoCount: sanitizedPhotos.length,
    );
  }

  /// Builds the exact sample-level CSV format specified in Section 11B.
  /// Always one row per physical leaf sample.
  String buildSamplesCsvString({
    required List<LeafSample> samples,
    required List<LeafPhoto> photos,
    Map<String, String>? zipRelativePaths,
  }) {
    final primaryBySample = <String, ({LeafPhoto? upper, LeafPhoto? lower})>{};
    for (final photo in photos) {
      if (photo.isPrimary != 1 || photo.isDeleted) continue;
      final current =
          primaryBySample[photo.sampleUuid] ?? (upper: null, lower: null);
      if (photo.isUpper) {
        primaryBySample[photo.sampleUuid] =
            (upper: photo, lower: current.lower);
      } else {
        primaryBySample[photo.sampleUuid] =
            (upper: current.upper, lower: photo);
      }
    }

    final rows = <List<dynamic>>[
      [
        'sample_uuid',
        'sample_code',
        'project_code',
        'estate_name',
        'region',
        'district',
        'bush_plot_code',
        'field_label',
        'expert_label',
        'label_status',
        'severity',
        'sample_latitude',
        'sample_longitude',
        'sample_gps_accuracy_m',
        'created_at_utc',
        'upper_photo_file',
        'lower_photo_file',
        'upper_device_model',
        'lower_device_model',
        'upper_captured_at_utc',
        'lower_captured_at_utc',
      ],
    ];

    for (final s in samples) {
      final pair = primaryBySample[s.sampleUuid];
      final upper = pair?.upper;
      final lower = pair?.lower;

      final upperFile = upper == null
          ? ''
          : (zipRelativePaths?[upper.photoUuid] ?? upper.filePath);
      final lowerFile = lower == null
          ? ''
          : (zipRelativePaths?[lower.photoUuid] ?? lower.filePath);

      rows.add([
        s.sampleUuid,
        s.sampleCode,
        s.projectCode,
        s.estateName ?? '',
        s.region ?? '',
        s.district ?? '',
        s.bushPlotCode ?? '',
        s.fieldLabel,
        s.expertLabel ?? '',
        s.labelStatus,
        s.severity?.toString() ?? '',
        s.sampleLatitude?.toString() ?? '',
        s.sampleLongitude?.toString() ?? '',
        s.sampleGpsAccuracyM?.toString() ?? '',
        s.createdAtUtc,
        upperFile,
        lowerFile,
        upper?.deviceModel ?? '',
        lower?.deviceModel ?? '',
        upper?.capturedAtUtc ?? '',
        lower?.capturedAtUtc ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Builds the image-level CSV table (one row per photograph).
  String buildPhotosCsvString({
    required List<LeafPhoto> photos,
    Map<String, String>? zipRelativePaths,
  }) {
    final rows = <List<dynamic>>[
      [
        'photo_uuid',
        'sample_uuid',
        'leaf_side',
        'file_path',
        'sha256',
        'width_px',
        'height_px',
        'file_size_bytes',
        'captured_at_utc',
        'device_id',
        'device_platform',
        'device_manufacturer',
        'device_model',
        'os_version',
        'app_version',
        'latitude',
        'longitude',
        'gps_accuracy_m',
        'gps_status',
        'is_primary',
        'photo_review_status',
      ],
    ];

    for (final pItem in photos) {
      rows.add([
        pItem.photoUuid,
        pItem.sampleUuid,
        pItem.leafSide,
        zipRelativePaths?[pItem.photoUuid] ?? pItem.filePath,
        pItem.sha256,
        pItem.widthPx?.toString() ?? '',
        pItem.heightPx?.toString() ?? '',
        pItem.fileSizeBytes?.toString() ?? '',
        pItem.capturedAtUtc,
        pItem.deviceId,
        pItem.devicePlatform ?? '',
        pItem.deviceManufacturer ?? '',
        pItem.deviceModel ?? '',
        pItem.osVersion ?? '',
        pItem.appVersion ?? '',
        pItem.latitude?.toString() ?? '',
        pItem.longitude?.toString() ?? '',
        pItem.gpsAccuracyM?.toString() ?? '',
        pItem.gpsStatus,
        pItem.isPrimary,
        pItem.photoReviewStatus,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Inspects a ZIP package's manifest and verifies structure without modifying SQLite.
  Future<PackagePreview> inspectZipPackage(String zipPath) async {
    final file = File(zipPath);
    if (!await file.exists()) {
      throw FileSystemException('Selected ZIP file does not exist.', zipPath);
    }

    final zipBytes = await file.readAsBytes();
    final packageSha = Checksum.calculateBytesChecksum(zipBytes);
    final archive = ZipDecoder().decodeBytes(zipBytes);

    ArchiveFile? manifestFile;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final rel = _storage.validateSafeRelativePath(entry.name);
      if (rel == 'manifest.json') {
        manifestFile = entry;
      }
    }

    if (manifestFile == null) {
      throw const FormatException(
        'Invalid package: manifest.json is missing from the ZIP archive.',
      );
    }

    final manifestStr = utf8.decode(_requireArchiveBytes(manifestFile));
    final manifest = TransferManifest.fromJson(manifestStr);

    return PackagePreview(
      zipPath: zipPath,
      fileName: p.basename(zipPath),
      manifest: manifest,
      packageSha256: packageSha,
    );
  }

  /// Verifies ZIP paths + checksums and merges samples & photos by UUID.
  Future<ImportResult> importZipPackage(String zipPath) async {
    final file = File(zipPath);
    if (!await file.exists()) {
      throw FileSystemException('ZIP file not found.', zipPath);
    }

    final zipBytes = await file.readAsBytes();
    final packageSha = Checksum.calculateBytesChecksum(zipBytes);
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final entryMap = <String, ArchiveFile>{};
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final relPath = _storage.validateSafeRelativePath(entry.name);
      entryMap[relPath] = entry;
    }

    final manifestEntry = entryMap['manifest.json'];
    final samplesEntry = entryMap['samples.json'];
    final photosEntry = entryMap['photos.json'];
    final checksumsEntry = entryMap['checksums.sha256'];

    if (manifestEntry == null ||
        samplesEntry == null ||
        photosEntry == null ||
        checksumsEntry == null) {
      throw const FormatException(
        'Package is missing required metadata files (manifest.json, samples.json, photos.json, or checksums.sha256).',
      );
    }

    // Verify checksums for every file listed in checksums.sha256.
    final checksumText = utf8.decode(_requireArchiveBytes(checksumsEntry));
    final lines = checksumText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);

    for (final line in lines) {
      final spaceIdx = line.indexOf('  ');
      if (spaceIdx <= 0) {
        throw FormatException('Malformed checksum entry: $line');
      }
      final expectedHash = line.substring(0, spaceIdx).trim().toLowerCase();
      final relPath =
          _storage.validateSafeRelativePath(line.substring(spaceIdx + 2).trim());
      final archiveFile = entryMap[relPath];
      if (archiveFile == null) {
        throw FormatException('Missing file listed in checksums: $relPath');
      }
      final actualHash =
          Checksum.calculateBytesChecksum(_requireArchiveBytes(archiveFile))
              .toLowerCase();
      if (actualHash != expectedHash) {
        throw FormatException(
          'Checksum verification failed for $relPath (package may be corrupted).',
        );
      }
    }

    final manifest = TransferManifest.fromJson(
      utf8.decode(_requireArchiveBytes(manifestEntry)),
    );
    final currentProjectCode = await _settings.getProjectCode();
    if (manifest.projectCode != currentProjectCode) {
      throw FormatException(
        'Project mismatch: package belongs to "${manifest.projectCode}", '
        'but this device is set to "$currentProjectCode".',
      );
    }

    final allowSingleSide = await _settings.getAllowSingleSideComplete();
    final samplesRaw =
        json.decode(utf8.decode(_requireArchiveBytes(samplesEntry)))
            as List<dynamic>;
    final photosRaw =
        json.decode(utf8.decode(_requireArchiveBytes(photosEntry)))
            as List<dynamic>;

    var samplesCreated = 0;
    var samplesMerged = 0;
    var photosImported = 0;
    var photosSkippedDuplicate = 0;
    final conflicts = <ImportConflict>[];

    // 1. Merge samples by sample_uuid
    for (final raw in samplesRaw) {
      final map = Map<String, dynamic>.from(raw as Map);
      final incoming = LeafSample.fromMap(map);
      final existing = await _sampleRepo.getSampleByUuid(
        incoming.sampleUuid,
        includeDeleted: true,
      );

      if (existing == null) {
        await _sampleRepo.createSample(
          incoming.copyWith(
            isImported: 1,
            sourceSampleUuid: incoming.sourceSampleUuid ?? incoming.sampleUuid,
          ),
        );
        samplesCreated++;
      } else {
        samplesMerged++;
        final conflictFields = _detectSampleConflicts(existing, incoming);
        if (conflictFields.isNotEmpty) {
          conflicts.add(
            ImportConflict(
              sampleUuid: existing.sampleUuid,
              sampleCode: existing.sampleCode,
              localSample: existing,
              incomingSample: incoming,
              conflictingFields: conflictFields,
            ),
          );
        }

        // Non-destructive fill of empty fields only; never overwrite expert labels
        // or existing conflicting field labels.
        final merged = existing.copyWith(
          estateName: _pickNonEmpty(existing.estateName, incoming.estateName),
          region: _pickNonEmpty(existing.region, incoming.region),
          district: _pickNonEmpty(existing.district, incoming.district),
          bushPlotCode:
              _pickNonEmpty(existing.bushPlotCode, incoming.bushPlotCode),
          collectorCode:
              _pickNonEmpty(existing.collectorCode, incoming.collectorCode),
          fieldLabel: existing.fieldLabel == 'not_sure' &&
                  incoming.fieldLabel != 'not_sure'
              ? incoming.fieldLabel
              : existing.fieldLabel,
          symptomNotes:
              _pickNonEmpty(existing.symptomNotes, incoming.symptomNotes),
          otherNotes: _pickNonEmpty(existing.otherNotes, incoming.otherNotes),
          // Expert label can only upgrade pending -> confirmed if local has none.
          expertLabel: existing.expertLabel ?? incoming.expertLabel,
          labelStatus: existing.labelStatus == LabelStatus.pending.databaseKey &&
                  incoming.labelStatus != LabelStatus.pending.databaseKey
              ? incoming.labelStatus
              : existing.labelStatus,
          expertReviewerCode:
              existing.expertReviewerCode ?? incoming.expertReviewerCode,
          expertReviewedAtUtc:
              existing.expertReviewedAtUtc ?? incoming.expertReviewedAtUtc,
          updatedAtUtc: AppDateUtils.nowUtcIso(),
        );
        await _sampleRepo.updateSample(merged);
      }
    }

    // 2. Merge photos by photo_uuid and SHA-256 deduplication
    for (final raw in photosRaw) {
      final map = Map<String, dynamic>.from(raw as Map);
      final zipRelPathRaw = map['zip_path'] as String?;
      final incomingPhoto = LeafPhoto.fromMap(map);

      final isDup = await _photoRepo.isPhotoDuplicate(
        photoUuid: incomingPhoto.photoUuid,
        sampleUuid: incomingPhoto.sampleUuid,
        sha256: incomingPhoto.sha256,
      );

      if (isDup) {
        photosSkippedDuplicate++;
        continue;
      }

      // Locate photo bytes inside ZIP
      final candidatePaths = <String>[
        if (zipRelPathRaw != null) _storage.validateSafeRelativePath(zipRelPathRaw),
        'photos/${incomingPhoto.sampleUuid}/${incomingPhoto.photoUuid}_${incomingPhoto.leafSide}.jpg',
      ];

      ArchiveFile? photoEntry;
      for (final candidate in candidatePaths) {
        photoEntry = entryMap[candidate];
        if (photoEntry != null) break;
      }

      if (photoEntry == null) {
        continue;
      }

      final photoBytes = Uint8List.fromList(_requireArchiveBytes(photoEntry));
      final actualSha = Checksum.calculateBytesChecksum(photoBytes);
      if (actualSha != incomingPhoto.sha256) {
        throw FormatException(
          'Photo checksum mismatch for ${incomingPhoto.photoUuid}.',
        );
      }

      final ext = p.extension(photoEntry.name).isNotEmpty
          ? p.extension(photoEntry.name)
          : '.jpg';
      final storedPath = await _storage.saveImportedPhotoBytes(
        sampleUuid: incomingPhoto.sampleUuid,
        photoUuid: incomingPhoto.photoUuid,
        leafSide: incomingPhoto.leafSide,
        bytes: photoBytes,
        extension: ext,
      );

      await _photoRepo.insertImportedPhoto(
        incomingPhoto.copyWith(filePath: storedPath),
        allowSingleSideComplete: allowSingleSide,
      );
      photosImported++;
    }

    // 3. Recalculate completeness for all touched samples
    for (final raw in samplesRaw) {
      final uuid = (raw as Map)['sample_uuid'] as String;
      await _sampleRepo.recalculateSampleStatus(
        uuid,
        allowSingleSideComplete: allowSingleSide,
      );
    }

    final summary =
        'Created $samplesCreated, merged $samplesMerged samples; '
        'imported $photosImported, skipped $photosSkippedDuplicate duplicate photos; '
        '${conflicts.length} conflicts.';

    await _backupRepo.insertImportRecord(
      ImportRecord(
        importId: IdGenerator.generateImportId(),
        sourceDeviceId: manifest.exportDeviceId,
        importedAtUtc: AppDateUtils.nowUtcIso(),
        packageName: p.basename(zipPath),
        packageChecksum: packageSha,
        resultSummary: summary,
      ),
    );

    return ImportResult(
      samplesCreated: samplesCreated,
      samplesMerged: samplesMerged,
      photosImported: photosImported,
      photosSkippedDuplicate: photosSkippedDuplicate,
      conflicts: conflicts,
      packageChecksum: packageSha,
    );
  }

  Uint8List _requireArchiveBytes(ArchiveFile entry) {
    final bytes = entry.readBytes();
    if (bytes == null) {
      throw FormatException('Archive entry "${entry.name}" has no readable bytes.');
    }
    return bytes;
  }

  List<String> _detectSampleConflicts(LeafSample local, LeafSample incoming) {
    final fields = <String>[];
    if (local.fieldLabel != 'not_sure' &&
        incoming.fieldLabel != 'not_sure' &&
        local.fieldLabel != incoming.fieldLabel) {
      fields.add('field_label');
    }
    if (_differsNonEmpty(local.estateName, incoming.estateName)) {
      fields.add('estate_name');
    }
    if (_differsNonEmpty(local.bushPlotCode, incoming.bushPlotCode)) {
      fields.add('bush_plot_code');
    }
    return fields;
  }

  bool _differsNonEmpty(String? a, String? b) {
    final ca = a?.trim() ?? '';
    final cb = b?.trim() ?? '';
    return ca.isNotEmpty && cb.isNotEmpty && ca != cb;
  }

  String? _pickNonEmpty(String? primary, String? fallback) {
    if (primary != null && primary.trim().isNotEmpty) return primary;
    if (fallback != null && fallback.trim().isNotEmpty) return fallback;
    return primary;
  }

  LeafSample _redactSampleGps(LeafSample s) {
    return LeafSample(
      sampleUuid: s.sampleUuid,
      sampleCode: s.sampleCode,
      projectCode: s.projectCode,
      createdAtUtc: s.createdAtUtc,
      updatedAtUtc: s.updatedAtUtc,
      createdByDeviceId: s.createdByDeviceId,
      masterDeviceId: s.masterDeviceId,
      estateName: s.estateName,
      region: s.region,
      district: s.district,
      bushPlotCode: s.bushPlotCode,
      collectorCode: s.collectorCode,
      fieldLabel: s.fieldLabel,
      expertLabel: s.expertLabel,
      labelStatus: s.labelStatus,
      expertReviewerCode: s.expertReviewerCode,
      expertReviewedAtUtc: s.expertReviewedAtUtc,
      severity: s.severity,
      symptomNotes: s.symptomNotes,
      otherNotes: s.otherNotes,
      sampleLatitude: null,
      sampleLongitude: null,
      sampleGpsAccuracyM: null,
      sampleGpsCapturedAtUtc: null,
      sampleGpsStatus: 'redacted',
      sampleStatus: s.sampleStatus,
      deletedAtUtc: s.deletedAtUtc,
      isImported: s.isImported,
      sourceSampleUuid: s.sourceSampleUuid,
    );
  }

  LeafPhoto _redactPhotoGps(LeafPhoto photo) {
    return LeafPhoto(
      photoUuid: photo.photoUuid,
      sampleUuid: photo.sampleUuid,
      leafSide: photo.leafSide,
      filePath: photo.filePath,
      originalFileName: photo.originalFileName,
      sha256: photo.sha256,
      widthPx: photo.widthPx,
      heightPx: photo.heightPx,
      fileSizeBytes: photo.fileSizeBytes,
      capturedAtUtc: photo.capturedAtUtc,
      deviceId: photo.deviceId,
      devicePlatform: photo.devicePlatform,
      deviceManufacturer: photo.deviceManufacturer,
      deviceModel: photo.deviceModel,
      osVersion: photo.osVersion,
      appVersion: photo.appVersion,
      latitude: null,
      longitude: null,
      gpsAccuracyM: null,
      gpsCapturedAtUtc: null,
      gpsStatus: 'redacted',
      isPrimary: photo.isPrimary,
      photoReviewStatus: photo.photoReviewStatus,
      deletedAtUtc: photo.deletedAtUtc,
      createdAtUtc: photo.createdAtUtc,
    );
  }
}
