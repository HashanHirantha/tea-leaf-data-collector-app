# TeaField Capture

Offline-first Flutter field-collection application for paired upper (adaxial) and lower (abaxial) tea leaf photography, immediate provisional labeling, automatic provenance capture, cross-device QR pairing, research ZIP/CSV export & merge, manual Google Drive backup, and two-stage Trash/purge controls.

---

## Features Implemented

- **Single-Screen Paired Leaf Capture** (`New Leaf Sample`):
  - Upper surface (`adaxial`) and lower surface (`abaxial`) photo slots on one shared form linked to a single `sample_uuid`.
  - Early draft persistence in SQLite so incomplete samples are never discarded if interrupted.
  - Immutable original photos stored under app-private storage (`teafield/photos/<sample_uuid>/`) with SHA-256 checksums, dimensions, and retake audit history (`is_primary = 0`).
  - Foreground-only GPS capture (`geolocator`) and device/OS/app provenance (`device_info_plus`, `package_info_plus`). Location refusal or timeout never blocks saving.
- **Immediate Field Labeling & Separate Expert Verification**:
  - Provisional `field_label` (Healthy, Suspected algal leaf spot, Suspected gray blight, Suspected blister blight, Other/unknown, Mixed symptoms, Not sure), optional severity (0–3), symptom notes, estate/region/district/bush presets.
  - Separate `expert_label`, `label_status`, `expert_reviewer_code`, and `expert_reviewed_at_utc` fields so field guesses never overwrite expert ground truth.
- **Two-Phone Offline QR Pairing**:
  - Phone A generates a compact QR (`app`, `version`, `project_code`, `sample_uuid`, `sample_code`) excluding GPS and collector PII.
  - Phone B scans via `Join Existing Sample`, picks `upper` or `lower`, and captures its own photo and provenance against the shared `sample_uuid`.
- **ZIP Export / Import & Research CSVs**:
  - Full Research ZIP (`manifest.json`, `samples.json`, `photos.json`, `samples.csv`, `photos.csv`, `checksums.sha256`, and original images).
  - One-row-per-leaf `samples.csv` and one-row-per-image `photos.csv`, with an optional GPS redaction toggle for external/public sharing.
  - Safe ZIP import with path-traversal protection, SHA-256 verification, `sample_uuid` merging, `photo_uuid`/`sha256` deduplication, and explicit conflict resolution (never silently overwriting labels).
- **Manual Google Drive Backup (`drive.file` scope)**:
  - Explicit user-triggered backup (`All active records`, `Selected samples`, `New or changed records` via content SHA-256 comparison).
  - Never uploads automatically during capture or deletes local data after upload.
  - Uses multipart upload (≤ 5 MB) and resumable chunked upload (> 5 MB) with cancellation and retry.
- **Trash & Project Data Removal**:
  - Soft-delete (`deleted_at_utc`) for individual photos, individual samples, or multi-selected samples, with full Restore.
  - Permanent sample deletion, Empty Trash, and full `DELETE ALL DATA` reset with separate local vs Google Drive outcomes and an offline-resilient `pending_cloud_deletions` retry queue.

---

## Setup & Build Instructions

> **Note:** Android APK builds can be generated on Windows, macOS, or Linux. Building and signing an iOS binary requires macOS with Xcode.

1. **Generate native platform wrapper files** (inside `teafield_capture/`):
   ```bash
   flutter create . --platforms=android,ios
   ```
   *(If `flutter create` overwrites `android/app/src/main/AndroidManifest.xml` or `ios/Runner/Info.plist`, ensure the foreground `CAMERA`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, and `INTERNET` permissions — without `ACCESS_BACKGROUND_LOCATION` — remain present.)*

2. **Resolve dependencies and run checks**:
   ```bash
   flutter pub get
   flutter analyze
   flutter test
   ```

3. **Run on a connected Android device or emulator**:
   ```bash
   flutter run
   ```

4. **Build an Android release APK for field testing**:
   ```bash
   flutter build apk --release
   ```
   Output APK: `build/app/outputs/flutter-apk/app-release.apk`.

---

## Google Drive OAuth Setup (Before Testing Cloud Backup)

1. Create or select a Google Cloud project and enable the **Google Drive API**.
2. Configure the OAuth consent screen (`https://www.googleapis.com/auth/drive.file` scope) and add field-tester Google accounts while in Testing mode.
3. Create an **Android OAuth Client** matching your application ID (e.g. `com.example.teafield_capture`) and signing key SHA-1 fingerprint (`keytool` / `./gradlew signingReport`).
4. Create a **Web OAuth Client** in the same Google Cloud project and enter its Client ID under **Settings → Google Web Client ID** (required by `google_sign_in` 7.x / Android Credential Manager).
5. For iOS builds, create an **iOS OAuth Client** with your bundle ID and register its reversed client ID URL scheme in `ios/Runner/Info.plist`.
