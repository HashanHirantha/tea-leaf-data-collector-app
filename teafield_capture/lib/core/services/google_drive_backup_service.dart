import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../data/models/drive_backup_batch.dart';
import '../../data/models/leaf_sample.dart';
import '../../data/repositories/backup_repository.dart';
import '../../data/repositories/sample_repository.dart';
import '../constants/app_constants.dart';
import '../utils/app_date_utils.dart';
import '../utils/id_generator.dart';
import 'google_drive_auth_service.dart';
import 'package_transfer_service.dart';
import 'settings_service.dart';

/// Allows cancelling an in-progress Google Drive upload without touching local data.
class BackupCancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Result returned when an upload finishes or fails.
class DriveUploadOutcome {
  final DriveBackupBatch batch;
  final bool succeeded;
  final String? webViewLink;
  final String? errorMessage;

  const DriveUploadOutcome({
    required this.batch,
    required this.succeeded,
    this.webViewLink,
    this.errorMessage,
  });
}

/// Manages explicit, user-initiated Google Drive backups using `drive.file`.
class GoogleDriveBackupService {
  GoogleDriveBackupService({
    GoogleDriveAuthService? authService,
    BackupRepository? backupRepository,
    SampleRepository? sampleRepository,
    PackageTransferService? transferService,
    SettingsService? settingsService,
  })  : _auth = authService ?? GoogleDriveAuthService.instance,
        _backupRepo = backupRepository ?? BackupRepository(),
        _sampleRepo = sampleRepository ?? SampleRepository(),
        _transfer = transferService ?? PackageTransferService.instance,
        _settings = settingsService ?? SettingsService.instance;

  static final GoogleDriveBackupService instance = GoogleDriveBackupService();

  final GoogleDriveAuthService _auth;
  final BackupRepository _backupRepo;
  final SampleRepository _sampleRepo;
  final PackageTransferService _transfer;
  final SettingsService _settings;

  static const String _driveFilesApi =
      'https://www.googleapis.com/drive/v3/files';
  static const String _driveUploadApi =
      'https://www.googleapis.com/upload/drive/v3/files';

  /// Determines which active samples have never been backed up or have changed
  /// since their last confirmed Drive upload.
  Future<List<LeafSample>> getChangedOrUnbackedSamples({
    String? projectCode,
  }) async {
    final activeSamples =
        await _sampleRepo.getAllActiveSamples(projectCode: projectCode);
    final uploadedChecksums =
        await _backupRepo.getLatestUploadedSampleChecksums();

    final changed = <LeafSample>[];
    for (final sample in activeSamples) {
      final currentHash =
          await _sampleRepo.computeSampleContentSha256(sample.sampleUuid);
      final previousHash = uploadedChecksums[sample.sampleUuid];
      if (previousHash == null || previousHash != currentHash) {
        changed.add(sample);
      }
    }
    return changed;
  }

  /// Creates the ZIP archive and uploads it to the user's Google Drive
  /// (`My Drive / TeaField Capture / <PROJECT_CODE> / backups/`).
  Future<DriveUploadOutcome> uploadBackup({
    required DriveBackupType backupType,
    required List<LeafSample> samples,
    bool includeGps = true,
    BackupCancellationToken? cancellationToken,
    void Function(double progress, String stage)? onProgress,
  }) async {
    if (samples.isEmpty) {
      throw StateError('No samples selected for backup.');
    }

    final projectCode = await _settings.getProjectCode();
    final backupId = IdGenerator.generateBackupId();
    final stamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now().toUtc());
    final driveFileName = 'teafield_${backupType.databaseKey}_$stamp.zip';

    // 1. Authenticate & authorize in memory
    onProgress?.call(0.05, 'Authorizing Google Drive...');
    var credentials = await _auth.authorizeForDrive();

    // 2. Build local research ZIP archive
    onProgress?.call(0.10, 'Preparing research ZIP archive...');
    final checksumsBySample = <String, String>{};
    for (final s in samples) {
      final sha = await _sampleRepo.computeSampleContentSha256(s.sampleUuid);
      checksumsBySample[s.sampleUuid] = sha ?? '';
    }

    final exportResult = await _transfer.exportResearchZip(
      samples: samples,
      customFileName: driveFileName,
      omitGps: !includeGps,
      onProgress: (p) => onProgress?.call(0.10 + (p * 0.25), 'Packaging ZIP...'),
    );

    var batch = DriveBackupBatch(
      backupId: backupId,
      googleAccountEmail: credentials.email,
      driveFileName: driveFileName,
      localZipPath: exportResult.filePath,
      packageSha256: exportResult.sha256,
      sampleCount: exportResult.sampleCount,
      photoCount: exportResult.photoCount,
      backupType: backupType.databaseKey,
      status: DriveBackupStatus.preparing.databaseKey,
      createdAtUtc: AppDateUtils.nowUtcIso(),
    );

    await _backupRepo.insertBatch(batch, checksumsBySample);

    if (cancellationToken?.isCancelled ?? false) {
      return _markFailed(batch, 'Backup cancelled before upload.');
    }

    try {
      // 3. Ensure My Drive/TeaField Capture/<PROJECT_CODE>/backups exists
      onProgress?.call(0.38, 'Preparing Drive folder...');
      final folderId = await _ensureBackupFolderHierarchy(
        accessToken: credentials.accessToken,
        projectCode: projectCode,
      );

      batch = batch.copyWith(
        driveFolderId: folderId,
        status: DriveBackupStatus.uploading.databaseKey,
      );
      await _backupRepo.updateBatch(batch);

      // 4. Upload ZIP (multipart <= 5MB, resumable > 5MB)
      final file = File(exportResult.filePath);
      final fileSize = await file.length();

      final uploadedMeta = fileSize > AppConstants.resumableUploadThreshold
          ? await _uploadResumable(
              file: file,
              fileSize: fileSize,
              fileName: driveFileName,
              folderId: folderId,
              credentials: credentials,
              cancellationToken: cancellationToken,
              onRefreshToken: () async {
                credentials = await _auth.authorizeForDrive(
                  forceInteractive: false,
                );
                return credentials.accessToken;
              },
              onProgress: (p) =>
                  onProgress?.call(0.40 + (p * 0.58), 'Uploading to Drive...'),
            )
          : await _uploadMultipart(
              file: file,
              fileName: driveFileName,
              folderId: folderId,
              accessToken: credentials.accessToken,
              onProgress: (p) =>
                  onProgress?.call(0.40 + (p * 0.58), 'Uploading to Drive...'),
            );

      final fileId = uploadedMeta['id'] as String?;
      if (fileId == null || fileId.isEmpty) {
        return await _markFailed(batch, 'Drive did not confirm a file ID.');
      }

      final completedBatch = batch.copyWith(
        driveFileId: fileId,
        status: DriveBackupStatus.uploaded.databaseKey,
        uploadedAtUtc: AppDateUtils.nowUtcIso(),
        lastError: null,
      );
      await _backupRepo.updateBatch(completedBatch);
      onProgress?.call(1.0, 'Backup uploaded');

      return DriveUploadOutcome(
        batch: completedBatch,
        succeeded: true,
        webViewLink: uploadedMeta['webViewLink'] as String?,
      );
    } on SocketException {
      return _markFailed(batch, 'No connection — backup not uploaded.');
    } on TimeoutException {
      return _markFailed(batch, 'Network timeout — tap Retry when connected.');
    } catch (e) {
      return _markFailed(batch, e.toString());
    }
  }

  /// Retries an existing failed backup batch using its saved local ZIP if present.
  Future<DriveUploadOutcome> retryBatch(
    DriveBackupBatch failedBatch, {
    BackupCancellationToken? cancellationToken,
    void Function(double progress, String stage)? onProgress,
  }) async {
    final localZip = failedBatch.localZipPath;
    if (localZip == null || !await File(localZip).exists()) {
      // Fall back to re-exporting active records if the local ZIP is gone.
      final samples = await _sampleRepo.getAllActiveSamples();
      return uploadBackup(
        backupType: DriveBackupType.fromDatabaseKey(failedBatch.backupType),
        samples: samples,
        cancellationToken: cancellationToken,
        onProgress: onProgress,
      );
    }

    onProgress?.call(0.05, 'Authorizing Google Drive...');
    var credentials = await _auth.authorizeForDrive();
    final projectCode = await _settings.getProjectCode();

    var batch = failedBatch.copyWith(
      googleAccountEmail: credentials.email,
      status: DriveBackupStatus.uploading.databaseKey,
      lastError: null,
    );
    await _backupRepo.updateBatch(batch);

    try {
      final folderId = batch.driveFolderId ??
          await _ensureBackupFolderHierarchy(
            accessToken: credentials.accessToken,
            projectCode: projectCode,
          );
      batch = batch.copyWith(driveFolderId: folderId);

      final file = File(localZip);
      final fileSize = await file.length();

      final uploadedMeta = fileSize > AppConstants.resumableUploadThreshold
          ? await _uploadResumable(
              file: file,
              fileSize: fileSize,
              fileName: batch.driveFileName,
              folderId: folderId,
              credentials: credentials,
              cancellationToken: cancellationToken,
              onRefreshToken: () async {
                credentials = await _auth.authorizeForDrive(
                  forceInteractive: false,
                );
                return credentials.accessToken;
              },
              onProgress: (p) =>
                  onProgress?.call(0.15 + (p * 0.85), 'Retrying upload...'),
            )
          : await _uploadMultipart(
              file: file,
              fileName: batch.driveFileName,
              folderId: folderId,
              accessToken: credentials.accessToken,
              onProgress: (p) =>
                  onProgress?.call(0.15 + (p * 0.85), 'Retrying upload...'),
            );

      final fileId = uploadedMeta['id'] as String?;
      if (fileId == null || fileId.isEmpty) {
        return await _markFailed(batch, 'Drive did not confirm a file ID.');
      }

      final completed = batch.copyWith(
        driveFileId: fileId,
        status: DriveBackupStatus.uploaded.databaseKey,
        uploadedAtUtc: AppDateUtils.nowUtcIso(),
        lastError: null,
      );
      await _backupRepo.updateBatch(completed);
      onProgress?.call(1.0, 'Backup uploaded');

      return DriveUploadOutcome(
        batch: completed,
        succeeded: true,
        webViewLink: uploadedMeta['webViewLink'] as String?,
      );
    } on SocketException {
      return _markFailed(batch, 'No connection — backup not uploaded.');
    } catch (e) {
      return _markFailed(batch, e.toString());
    }
  }

  /// Deletes a single app-created Drive backup archive by its stored [driveFileId].
  /// Never deletes local sample records.
  Future<({bool deleted, String? error})> deleteTrackedDriveFile({
    required String driveFileId,
    required String driveFileName,
    String? googleAccountEmail,
  }) async {
    try {
      final creds = await _auth.authorizeForDrive();
      final response = await http.delete(
        Uri.parse('$_driveFilesApi/$driveFileId'),
        headers: {'Authorization': 'Bearer ${creds.accessToken}'},
      );

      if (response.statusCode == 204 ||
          response.statusCode == 200 ||
          response.statusCode == 404) {
        await _backupRepo.markCloudDeletionCompleted(driveFileId);
        return (deleted: true, error: null);
      }

      final msg =
          'Drive returned HTTP ${response.statusCode} while deleting $driveFileName.';
      await _backupRepo.enqueuePendingCloudDeletions([
        PendingCloudDeletion(
          driveFileId: driveFileId,
          driveFileName: driveFileName,
          googleAccountEmail: googleAccountEmail ?? creds.email,
          requestedAtUtc: AppDateUtils.nowUtcIso(),
          status: 'failed',
          lastError: msg,
        ),
      ]);
      return (deleted: false, error: msg);
    } on SocketException {
      const msg = 'Offline — Drive archive remains queued for deletion.';
      await _backupRepo.enqueuePendingCloudDeletions([
        PendingCloudDeletion(
          driveFileId: driveFileId,
          driveFileName: driveFileName,
          googleAccountEmail: googleAccountEmail,
          requestedAtUtc: AppDateUtils.nowUtcIso(),
          status: 'pending',
          lastError: msg,
        ),
      ]);
      return (deleted: false, error: msg);
    } catch (e) {
      final msg = e.toString();
      await _backupRepo.enqueuePendingCloudDeletions([
        PendingCloudDeletion(
          driveFileId: driveFileId,
          driveFileName: driveFileName,
          googleAccountEmail: googleAccountEmail,
          requestedAtUtc: AppDateUtils.nowUtcIso(),
          status: 'failed',
          lastError: msg,
        ),
      ]);
      return (deleted: false, error: msg);
    }
  }

  /// Retries all entries in `pending_cloud_deletions`.
  Future<({int deletedCount, int remainingCount})>
      processPendingCloudDeletions() async {
    final pending = await _backupRepo.getPendingCloudDeletions();
    if (pending.isEmpty) {
      return (deletedCount: 0, remainingCount: 0);
    }

    var deletedCount = 0;
    for (final item in pending) {
      final result = await deleteTrackedDriveFile(
        driveFileId: item.driveFileId,
        driveFileName: item.driveFileName,
        googleAccountEmail: item.googleAccountEmail,
      );
      if (result.deleted) {
        deletedCount++;
      }
    }

    final remaining = await _backupRepo.getPendingCloudDeletions();
    return (deletedCount: deletedCount, remainingCount: remaining.length);
  }

  Future<String> _ensureBackupFolderHierarchy({
    required String accessToken,
    required String projectCode,
  }) async {
    var rootId = await _settings.getDriveRootFolderId();
    if (rootId == null || !(await _driveItemExists(accessToken, rootId))) {
      rootId = await _createDriveFolder(
        accessToken: accessToken,
        name: AppConstants.driveFolderName,
      );
      await _settings.setDriveRootFolderId(rootId);
    }

    var projectFolderId =
        await _settings.getDriveProjectFolderId(projectCode);
    if (projectFolderId == null ||
        !(await _driveItemExists(accessToken, projectFolderId))) {
      projectFolderId = await _createDriveFolder(
        accessToken: accessToken,
        name: projectCode,
        parentId: rootId,
      );
      await _settings.setDriveProjectFolderId(projectCode, projectFolderId);
      await _uploadReadmeText(
        accessToken: accessToken,
        parentId: projectFolderId,
        projectCode: projectCode,
      );
    }

    var backupsFolderId =
        await _settings.getDriveBackupsFolderId(projectCode);
    if (backupsFolderId == null ||
        !(await _driveItemExists(accessToken, backupsFolderId))) {
      backupsFolderId = await _createDriveFolder(
        accessToken: accessToken,
        name: AppConstants.driveBackupsSubfolder,
        parentId: projectFolderId,
      );
      await _settings.setDriveBackupsFolderId(projectCode, backupsFolderId);
    }

    return backupsFolderId;
  }

  Future<bool> _driveItemExists(String accessToken, String fileId) async {
    final res = await http.get(
      Uri.parse('$_driveFilesApi/$fileId?fields=id,trashed'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode != 200) return false;
    final body = json.decode(res.body) as Map<String, dynamic>;
    return body['trashed'] != true;
  }

  Future<String> _createDriveFolder({
    required String accessToken,
    required String name,
    String? parentId,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'mimeType': 'application/vnd.google-apps.folder',
      if (parentId != null) 'parents': [parentId],
    };

    final res = await http.post(
      Uri.parse('$_driveFilesApi?fields=id'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(payload),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException(
        'Failed to create Drive folder "$name" (HTTP ${res.statusCode}): ${res.body}',
      );
    }

    final decoded = json.decode(res.body) as Map<String, dynamic>;
    return decoded['id'] as String;
  }

  Future<void> _uploadReadmeText({
    required String accessToken,
    required String parentId,
    required String projectCode,
  }) async {
    final readme = '''
TeaField Capture — Research Backup Folder
Project code: $projectCode

Each ZIP archive inside backups/ is a self-contained research package containing:
- Original upper (adaxial) and lower (abaxial) tea leaf photos
- samples.json & samples.csv (one row per physical leaf sample)
- photos.json & photos.csv (one row per captured photograph)
- manifest.json & checksums.sha256

Do not modify filenames manually if you intend to re-import these archives into TeaField Capture.
''';

    final boundary = 'teafield_${DateTime.now().millisecondsSinceEpoch}';
    final metadataJson = json.encode({
      'name': 'README_backup_contents.txt',
      'parents': [parentId],
    });

    final body = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadataJson\r\n'
        '--$boundary\r\n'
        'Content-Type: text/plain; charset=UTF-8\r\n\r\n'
        '$readme\r\n'
        '--$boundary--';

    await http.post(
      Uri.parse('$_driveUploadApi?uploadType=multipart'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: utf8.encode(body),
    );
  }

  Future<Map<String, dynamic>> _uploadMultipart({
    required File file,
    required String fileName,
    required String folderId,
    required String accessToken,
    void Function(double)? onProgress,
  }) async {
    onProgress?.call(0.2);
    final bytes = await file.readAsBytes();
    final boundary = 'teafield_zip_${DateTime.now().millisecondsSinceEpoch}';
    final metadata = json.encode({
      'name': fileName,
      'parents': [folderId],
    });

    final prefix = utf8.encode(
      '--$boundary\r\n'
      'Content-Type: application/json; charset=UTF-8\r\n\r\n'
      '$metadata\r\n'
      '--$boundary\r\n'
      'Content-Type: application/zip\r\n\r\n',
    );
    final suffix = utf8.encode('\r\n--$boundary--');

    final builder = BytesBuilder(copy: false)
      ..add(prefix)
      ..add(bytes)
      ..add(suffix);

    onProgress?.call(0.6);
    final res = await http.post(
      Uri.parse('$_driveUploadApi?uploadType=multipart&fields=id,name,webViewLink'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: builder.takeBytes(),
    );
    onProgress?.call(1.0);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Drive upload failed (HTTP ${res.statusCode}): ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _uploadResumable({
    required File file,
    required int fileSize,
    required String fileName,
    required String folderId,
    required DriveAuthCredentials credentials,
    required Future<String> Function() onRefreshToken,
    BackupCancellationToken? cancellationToken,
    void Function(double)? onProgress,
  }) async {
    var token = credentials.accessToken;

    // 1. Initiate resumable session
    final initRes = await http.post(
      Uri.parse('$_driveUploadApi?uploadType=resumable&fields=id,name,webViewLink'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': 'application/zip',
        'X-Upload-Content-Length': '$fileSize',
      },
      body: json.encode({
        'name': fileName,
        'parents': [folderId],
      }),
    );

    if (initRes.statusCode < 200 || initRes.statusCode >= 300) {
      throw HttpException(
        'Could not initiate resumable upload (HTTP ${initRes.statusCode}): ${initRes.body}',
      );
    }

    final sessionUri = initRes.headers['location'];
    if (sessionUri == null || sessionUri.isEmpty) {
      throw const HttpException('Drive did not return a resumable upload URI.');
    }

    // 2. Stream 512 KB chunks
    const chunkSize = 512 * 1024;
    final raf = await file.open();
    var offset = 0;

    try {
      while (offset < fileSize) {
        if (cancellationToken?.isCancelled ?? false) {
          throw StateError('Upload cancelled by user.');
        }

        final remaining = fileSize - offset;
        final currentChunkLen = remaining < chunkSize ? remaining : chunkSize;
        await raf.setPosition(offset);
        final chunk = await raf.read(currentChunkLen);
        final endByte = offset + chunk.length - 1;

        var res = await http.put(
          Uri.parse(sessionUri),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Length': '${chunk.length}',
            'Content-Range': 'bytes $offset-$endByte/$fileSize',
          },
          body: chunk,
        );

        if (res.statusCode == 401) {
          token = await onRefreshToken();
          res = await http.put(
            Uri.parse(sessionUri),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Length': '${chunk.length}',
              'Content-Range': 'bytes $offset-$endByte/$fileSize',
            },
            body: chunk,
          );
        }

        if (res.statusCode == 200 || res.statusCode == 201) {
          onProgress?.call(1.0);
          return json.decode(res.body) as Map<String, dynamic>;
        }

        if (res.statusCode == 308) {
          final rangeHeader = res.headers['range'];
          if (rangeHeader != null && rangeHeader.contains('-')) {
            final lastAck = int.tryParse(rangeHeader.split('-').last);
            offset = lastAck != null ? lastAck + 1 : offset + chunk.length;
          } else {
            offset += chunk.length;
          }
          onProgress?.call(offset / fileSize);
          continue;
        }

        throw HttpException(
          'Resumable chunk failed (HTTP ${res.statusCode}): ${res.body}',
        );
      }
    } finally {
      await raf.close();
    }

    throw const HttpException('Upload ended unexpectedly without confirmation.');
  }

  Future<DriveUploadOutcome> _markFailed(
    DriveBackupBatch batch,
    String error,
  ) async {
    final failed = batch.copyWith(
      status: DriveBackupStatus.failed.databaseKey,
      lastError: error,
    );
    await _backupRepo.updateBatch(failed);
    return DriveUploadOutcome(
      batch: failed,
      succeeded: false,
      errorMessage: error,
    );
  }
}
