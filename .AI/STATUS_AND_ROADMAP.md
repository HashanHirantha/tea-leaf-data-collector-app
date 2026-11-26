# Project Status & Roadmap

## 1. Current Implementation Status

| Milestone | Scope | Code Status | Runtime Verified? |
|---|---|---|---|
| 1. Project Setup | Flutter structure, Material 3 theme, 14 GoRouter routes, Settings (`SettingsService`) | Implemented | Pending Flutter SDK |
| 2. Local Data Layer | `AppDatabase`, 6 SQLite tables, 7 indexes, models, 3 repositories, UUID/SHA-256 utils | Implemented | Pending Flutter SDK |
| 3. Single-Screen Capture | `NewSampleScreen`, dual `PhotoSlotCard` (`upper`/`lower`), reusable `CameraScreen`, retake audit trail | Implemented | Pending Flutter SDK |
| 4. Immediate Labeling | `DiseaseClass` provisional field labels, severity, symptom notes, estate/region/district presets | Implemented | Pending Flutter SDK |
| 5. GPS & Device Provenance | Foreground `LocationService` (12s timeout, no `0,0`) & `DeviceInfoService` | Implemented | Pending Flutter SDK |
| 6. Offline QR Pairing | `QrPairingService`, `ShowSampleQrScreen`, `JoinSampleScreen` (`mobile_scanner`) | Implemented | Pending Flutter SDK |
| 7. Export & Merge | `PackageTransferService` ZIP export/import, path-traversal + SHA-256 checks, `ImportConflict` reporting | Implemented | Pending Flutter SDK |
| 8. Research QA | One-row-per-leaf `samples.csv`, image-level `photos.csv`, GPS redaction toggle, 2 unit test files | Implemented | Pending `flutter test` |
| 9. Google Drive Backup | `GoogleDriveAuthService` (`google_sign_in` 7.x, `drive.file`), `GoogleDriveBackupService`, multipart + resumable upload, history & retry | Implemented | Pending GCP OAuth & device test |
| 10. Deletion & Purge | Soft-delete Trash, restore, single/batch permanent delete, `DELETE ALL DATA`, offline `pending_cloud_deletions` queue | Implemented | Pending Flutter SDK |
| 11. On-Device Classifier | Optional LiteRT/TFLite disease prediction & calibration threshold referral UI | **Not started (Phase 2)** | — |

---

## 2. Immediate Pending Setup & Verification Checklist

Because `flutter` was **not installed on PATH** on the Windows development machine (`where.exe flutter` failed), run the following steps in `teafield_capture/` once Flutter SDK + Android Studio are available:

1. **Generate native Android/iOS runner scaffolding:**
   ```bash
   cd teafield_capture
   flutter create . --platforms=android,ios
   ```
   - After running `flutter create`, verify `android/app/src/main/AndroidManifest.xml` still retains `CAMERA`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, `INTERNET`, and **no** `ACCESS_BACKGROUND_LOCATION`, and verify `ios/Runner/Info.plist` retains the custom research privacy strings.
   - Check generated Android `build.gradle(.kts)` `minSdk` meets requirements for `camera`, `geolocator`, `mobile_scanner`, and `google_sign_in` (typically Android API 21+ / 23+).

2. **Resolve packages, analyze, and run tests:**
   ```bash
   flutter pub get
   flutter analyze
   flutter test
   ```
   - Watch for potential Flutter SDK minor deprecation warnings (e.g., `withOpacity` vs `withValues` on newer Flutter releases) and confirm all imports/nullability checks pass `flutter analyze`.
   - Unit tests currently cover:
     - [`test/models_and_csv_test.dart`](../teafield_capture/test/models_and_csv_test.dart)
     - [`test/qr_pairing_service_test.dart`](../teafield_capture/test/qr_pairing_service_test.dart)

3. **Configure Google Drive OAuth (required before testing backup/cloud deletion):**
   - Enable **Google Drive API** in Google Cloud Console and add test user emails (`drive.file` scope).
   - Create an **Android OAuth Client** (matching application ID + debug/release signing SHA-1).
   - Create a **Web OAuth Client** and enter its Client ID under **Settings → Google Web Client ID** in the app (`SettingsService.setGoogleServerClientId`).
   - For iOS (macOS + Xcode required), configure an **iOS OAuth Client** and URL scheme in `ios/Runner/Info.plist`.

4. **Field / Two-Device QA before Pilot:**
   - Verify camera autofocus, JPEG rotation, GPS timeout behavior, and offline capture on physical phones (Android + iPhone if used in pair workflow).
   - Verify two-phone QR pairing + ZIP export/import produces 1 `leaf_samples` row and 2 distinct-device `leaf_photos` rows, rejects duplicates on re-import, and surfaces label conflicts cleanly.
   - Verify Drive backup upload, interrupted upload recovery across app restart, and offline `pending_cloud_deletions` retry.

---

## 3. Phase 2 Roadmap (Milestone 11 — After Model Training & Validation)

Do **not** block field collection or add inference heuristics before the model is trained and calibrated:

1. Freeze the trained model in **LiteRT / TensorFlow Lite** format and place it alongside a metadata JSON file (version, input size, color channel order, normalization constants, ordered class labels, calibrated confidence threshold) in [`teafield_capture/assets/models/`](../teafield_capture/assets/models/).
2. Preferred Android integration: implement LiteRT natively in a small Android Kotlin module invoked over a Flutter `MethodChannel` / platform channel.
3. Persist predictions in a separate predictions table/structure (`prediction_id`, `sample_uuid`, `model_version`, `predicted_class`, `raw_confidence`, `calibrated_confidence`, `threshold_used`, `referral_flag`, `inference_device_model`, `inference_duration_ms`, `inference_created_at_utc`).
4. Never silently overwrite `field_label` or `expert_label`; surface **Refer for expert review** when calibrated confidence falls below the source-only validation threshold (never tune thresholds on held-out test estate images).
