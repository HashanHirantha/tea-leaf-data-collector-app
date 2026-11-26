# Core Workflows — TeaField Capture

## Workflow A: Single-Phone Paired Leaf Capture
1. Opening **New Leaf Sample** creates a `CaptureViewModel` draft immediately and persists a `leaf_samples` row (`sample_uuid`, generated `TEA-YYYYMMDD-XXXX-NNNNN` `sample_code`, current `project_code`, `created_by_device_id`). Early persistence prevents losing samples if interrupted.
2. `LocationService.getCurrentGpsFix()` attempts a foreground GPS fix (`LocationAccuracy.high`, `12s` timeout). Failure marks status (`permission_denied`, `service_disabled`, `timeout`, `unavailable`) without blocking capture.
3. On `NewSampleScreen`, tapping **Take upper photo** or **Take lower photo** opens `/camera/:sampleUuid/:leafSide` (`CameraScreen`), returning an `XFile`.
4. `FileStorageService.saveCapturedPhoto()` copies raw unmodified bytes to `<app_documents>/teafield/photos/<sample_uuid>/<photo_uuid>_<side>.jpg`, extracts width/height via `ui.instantiateImageCodec`, and computes `sha256`.
5. `DeviceInfoService.getDeviceMetadata()` and a per-photo GPS fix populate the `LeafPhoto` record; `PhotoRepository.savePhoto()` marks any previous primary photo on that side `is_primary = 0` and recalculates `sample_status` (`incomplete` vs `ready_for_review` based on both sides or `allowSingleSideComplete` setting).

## Workflow B: Two-Phone Offline QR Pairing & ZIP Merge
1. **Phone A** creates a sample, captures one surface, enters shared estate/label details, and opens `/show-qr/:sampleUuid` (`ShowSampleQrScreen`). `QrPairingService.generateQrPayload` encodes `app`, `version`, `project_code`, `sample_uuid`, and `sample_code` (no GPS/PII).
2. **Phone B** opens `/join-sample` (`JoinSampleScreen` / `JoinSampleViewModel`), scans the QR via `mobile_scanner`, validates `project_code` and UUIDv4 format, creates or loads the local `LeafSample` stub with the matching `sample_uuid`, selects `upper` or `lower`, and captures its own photo + provenance locally offline.
3. **Export:** Either phone uses `ExportScreen` (`ExportViewModel` → `PackageTransferService`) to produce a full archival ZIP (`exportResearchZip`) or standalone CSV (`exportSampleSummaryCsv` / `exportImageLevelCsv`), with an optional **Omit GPS** toggle that sets `sample_gps_status`/`gps_status = 'redacted'` and nulls coordinates in exported artifacts without touching local SQLite.
4. **Merge:** On the receiving phone (`ImportScreen` → `ImportViewModel` → `PackageTransferService.importZipPackage`):
   - Validates every ZIP entry path against traversal (`validateSafeRelativePath`), verifies every file hash in `checksums.sha256`, checks `project_code` match.
   - Merges samples by `sample_uuid` (fills only blank metadata fields; never overwrites existing conflicting `field_label` or `expert_label` values; surfaces differing fields as `ImportConflict` items).
   - Deduplicates photos by `photo_uuid` OR matching `(sample_uuid, sha256)` (`PhotoRepository.isPhotoDuplicate`), verifies photo byte SHA-256, writes image bytes to private storage, and logs to `import_history`.

## Workflow C: Manual Google Drive Backup
1. Triggered only from `/drive-backup` (`DriveBackupScreen` / `DriveBackupViewModel`); capture paths never invoke network calls.
2. Startup hook in `lib/main.dart` calls `BackupRepository().recoverInterruptedUploads()` to convert orphaned `preparing`/`uploading` rows into retryable `failed` batches.
3. Collector picks **All active records**, **Selected samples**, or **New or changed records** (`GoogleDriveBackupService.getChangedOrUnbackedSamples` compares `SampleRepository.computeSampleContentSha256` against the latest `uploaded` `drive_backup_items`).
4. On explicit upload tap:
   - `GoogleDriveAuthService.authorizeForDrive()` obtains `drive.file` access token in memory.
   - `PackageTransferService.exportResearchZip()` builds the timestamped ZIP archive.
   - Batch + per-sample checksums insert into `drive_backup_batches` / `drive_backup_items` (`preparing` → `uploading`).
   - `GoogleDriveBackupService` ensures `My Drive/TeaField Capture/<PROJECT_CODE>/backups/` (storing Drive folder IDs in `SettingsService`), uploads via multipart (`<= 5 MB`) or `512 KB` chunked resumable upload (`> 5 MB`, handling HTTP `308` resume and `401` token refresh, checking `BackupCancellationToken`), and persists `drive_file_id` + `uploaded` status only after Drive confirms creation.
   - Failed uploads retain local ZIP/records and can be retried from `DriveBackupHistoryScreen` (`retryBatch`).

## Workflow D: Two-Stage Trash & Full Project Reset
1. **Soft delete:** `SampleDeletionService.moveSamplesToTrash` or `movePhotoToTrash` sets `deleted_at_utc` inside a transaction while leaving image files intact. Deleting one photo promotes the newest remaining non-deleted photo on that side (if any) to `is_primary = 1` and recalculates `sample_status`.
2. **Trash management (`/trash`):** Lists trashed samples and singly-trashed photos (`PhotoRepository.getIndividuallyTrashedPhotos`) with **Restore** and **Permanently delete** actions.
3. **Permanent sample deletion:** Removes local image files via `FileStorageService`, deletes DB rows, cleans empty directories, and checks `getAffectedDriveBatches` so shared Drive ZIPs containing other samples are never deleted silently.
4. **Full project reset (`/data-management`):** `DataManagementViewModel` loads `ProjectDataCounts` (samples, photos, local exports, tracked Drive backups, pending cloud deletions). Requires typing `DELETE ALL DATA` before calling `SampleDeletionService.deleteAllProjectData`: deletes local photos/exports/imports, wipes project DB tables via `BackupRepository.resetLocalResearchData`, verifies `0` active and trashed samples remain, and handles Drive deletions through `pending_cloud_deletions` (online `DELETE /drive/v3/files/{fileId}` or offline retry queue).
