# Conventions, Invariants & Gotchas

## 1. Domain & Research Data Invariants

1. **Physical Leaf Modeling Rule:**
   - One `LeafSample` (`sample_uuid`) = one physical tea leaf.
   - Upper (`adaxial`, `leaf_side = 'upper'`) and lower (`abaxial`, `leaf_side = 'lower'`) photographs are stored as separate `LeafPhoto` rows referencing the same `sample_uuid`.
   - Same-screen UI requirement: both `PhotoSlotCard` widgets (`upper` and `lower`) live inside `NewSampleScreen`; only `CameraScreen` opens separately and returns a captured file for the selected side.
   - Summary export (`samples.csv` via `PackageTransferService.buildSamplesCsvString`) MUST emit **one row per leaf**, never duplicating sample rows for two sides. Image auditing belongs in `photos.csv`.

2. **Provisional Field Labels vs. Expert Verification:**
   - `DiseaseClass` (`lib/core/constants/disease_classes.dart`): `healthy`, `algal_leaf_spot`, `gray_blight`, `blister_blight`, `other_unknown`, `mixed_symptoms`, `not_sure`.
   - `field_label` is always preserved as collected. Expert ground truth is written separately to `expert_label`, `label_status`, `expert_reviewer_code`, and `expert_reviewed_at_utc` (`SampleRepository.updateExpertReview`).
   - Do not silently overwrite `field_label` or an existing `expert_label` during ZIP import. Conflicting non-`not_sure` field labels, estate names, or bush plot codes produce `ImportConflict` entries for explicit review.

3. **Immutable Original Photographs & Retake Audit Trail:**
   - Captured photos are copied directly to app-private storage (`FileStorageService.saveCapturedPhoto`) without resizing, filtering, or overwriting bytes.
   - Retakes do **not** delete or overwrite earlier rows: `PhotoRepository.savePhoto` sets `is_primary = 0` on previous active primary photos of that side and inserts the new capture with `is_primary = 1`.
   - Any derived/resized images added in Phase 2 (e.g., LiteRT preprocessing) must be temporary or stored separately without mutating originals.

4. **Human-Readable IDs vs. Internal Keys:**
   - All merging, deduplication, and foreign keys use UUIDv4 (`sample_uuid`, `photo_uuid`, `backup_id`, `import_id`, random `device_id`).
   - `sample_code` (`TEA-YYYYMMDD-<4-char-device>-<5-char-alnum>`, excluding ambiguous `I, O, 0, 1`) is only for human field notes/labels—never as a merge key.

---

## 2. Privacy, Permissions & Cloud Safety

1. **Foreground-Only Permissions:**
   - `android/app/src/main/AndroidManifest.xml` declares `CAMERA`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, `INTERNET`. **Never add `ACCESS_BACKGROUND_LOCATION`.**
   - `ios/Runner/Info.plist` provides research-specific usage strings (`NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSPhotoLibraryUsageDescription`).
   - `LocationService.getCurrentGpsFix()` uses `AppConstants.gpsTimeoutSeconds = 12`, handles permission/service denial cleanly, guards against `(0.0, 0.0)`, and never blocks saving a sample when GPS fails.

2. **No Hardware Identifiers or QR PII:**
   - `DeviceInfoService` uses an app-generated random UUID (`SettingsService.getOrCreateDeviceId()`) plus manufacturer/model/OS/app version. Never read IMEI, serial numbers, or contacts.
   - QR payloads (`QrPairingService`) contain only `app`, `version`, `project_code`, `sample_uuid`, `sample_code`—never GPS coordinates, collector codes, or notes.

3. **Narrow OAuth & In-Memory Tokens:**
   - `AppConstants.driveScopes` uses only `https://www.googleapis.com/auth/drive.file` (restricts access to app-created files/folders).
   - `GoogleDriveAuthService` keeps `DriveAuthCredentials` (`accessToken`) **strictly in memory** for active requests. Never store tokens in SQLite, `SharedPreferences`, logs, or ZIP exports.
   - Backup requires explicit user action (`Upload`); photo capture, label save, or offline errors never trigger auto-upload or auto-retry.

4. **Two-Stage Trash & Local/Cloud Separation:**
   - Normal queries MUST filter `deleted_at_utc IS NULL`.
   - Moving a sample to Trash soft-deletes the sample and its photos in one SQLite transaction while keeping image files on disk so Restore works.
   - Local deletion never silently deletes Google Drive archives, and Drive backup deletion never silently deletes local data.
   - Full local project reset (`SampleDeletionService.deleteAllProjectData`) copies tracked `drive_file_id`s to `pending_cloud_deletions` when cloud deletion is chosen, allowing offline retries later without retaining research photos.

5. **ZIP Security:**
   - `FileStorageService.validateSafeRelativePath` and `resolveSafeChildPath` reject empty paths, leading `/`, `:` (drive letters), and `..` segments before reading/extracting any archive entries. Every file listed in `checksums.sha256` and every photo `sha256` is verified on import.

---

## 3. Code Style & Lints (`analysis_options.yaml`)

- Based on `package:flutter_lints/flutter.yaml` with enforced rules:
  - `prefer_const_constructors: true`
  - `prefer_const_declarations: true`
  - `avoid_print: true` (never leave `print()` calls in production code)
  - `prefer_single_quotes: true`

---

## 4. Verified Dependency APIs (`pubspec.yaml`)

When modifying services, adhere to the major versions pinned in `pubspec.yaml`:

- **`google_sign_in: ^7.1.0`** — Uses singleton `GoogleSignIn.instance`, `initialize(clientId: ..., serverClientId: ...)`, `authenticationEvents` stream, `attemptLightweightAuthentication()`, `supportsAuthenticate()`, `authenticate()`, and `account.authorizationClient.authorizationForScopes()` / `authorizeScopes()`. Requires a **Web OAuth Client ID** (`serverClientId` configured via Settings → Google Web Client ID) on Android Credential Manager. Do not use obsolete `GoogleSignIn()` constructor / `.signIn()` calls.
- **`archive: ^4.0.2`** — Use `ZipFileEncoder` from `package:archive/archive_io.dart` (`create`, `addFile`, `addArchiveFile`, `close`) and `ZipDecoder().decodeBytes(...)` iterating `ArchiveFile` entries with `.readBytes()`.
- **`mobile_scanner: ^6.0.2`** — `MobileScannerController` exposes state via `ValueListenable<MobileScannerState>` (`controller.value.torchState`), and `MobileScanner` uses `errorBuilder`.
- **`qr_flutter: ^4.1.0`** — Uses `QrImageView` with `QrVersions.auto`.
- **`geolocator: ^13.0.2`** — Pass `timeLimit` inside `LocationSettings(...)` to `Geolocator.getCurrentPosition(locationSettings: ...)`.
