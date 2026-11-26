# Architecture — TeaField Capture

## 1. Repository & Flutter Layout

Total Dart source files: **54** (`52` under `teafield_capture/lib/`, `2` under `teafield_capture/test/`).

```text
teafield_capture/
├── pubspec.yaml                  # Flutter >=3.16.0, Dart >=3.2.0 <4.0.0
├── analysis_options.yaml         # flutter_lints + const/single-quote/no-print rules
├── README.md                     # Setup & Google Drive OAuth instructions
├── assets/models/README.md       # Placeholder for Phase 2 frozen LiteRT/TFLite model
├── android/app/src/main/AndroidManifest.xml
├── ios/Runner/Info.plist
├── test/
│   ├── models_and_csv_test.dart
│   └── qr_pairing_service_test.dart
└── lib/
    ├── main.dart                 # Init DB, device_id, recover interrupted Drive uploads
    ├── app.dart                  # TeaFieldApp (MaterialApp.router, Material 3, seed #2E7D32)
    ├── router.dart               # GoRouter configuration (14 routes)
    ├── core/
    │   ├── constants/
    │   │   ├── app_constants.dart
    │   │   └── disease_classes.dart
    │   ├── services/
    │   │   ├── camera_service.dart
    │   │   ├── device_info_service.dart
    │   │   ├── file_storage_service.dart
    │   │   ├── google_drive_auth_service.dart
    │   │   ├── google_drive_backup_service.dart
    │   │   ├── location_service.dart
    │   │   ├── package_transfer_service.dart
    │   │   ├── qr_pairing_service.dart
    │   │   ├── sample_deletion_service.dart
    │   │   └── settings_service.dart
    │   └── utils/
    │       ├── app_date_utils.dart
    │       ├── checksum.dart
    │       └── id_generator.dart
    ├── data/
    │   ├── database/
    │   │   ├── app_database.dart
    │   │   └── database_migrations.dart
    │   ├── models/
    │   │   ├── drive_backup_batch.dart
    │   │   ├── import_record.dart
    │   │   ├── leaf_photo.dart
    │   │   ├── leaf_sample.dart
    │   │   ├── project_config.dart
    │   │   └── transfer_manifest.dart
    │   └── repositories/
    │       ├── backup_repository.dart
    │       ├── photo_repository.dart
    │       └── sample_repository.dart
    └── features/
        ├── camera/screens/camera_screen.dart
        ├── dashboard/
        │   ├── dashboard_view_model.dart
        │   └── screens/dashboard_screen.dart
        ├── data_management/
        │   ├── data_management_view_model.dart
        │   └── screens/data_management_screen.dart
        ├── drive_backup/
        │   ├── drive_backup_view_model.dart
        │   └── screens/{drive_backup_screen.dart, drive_backup_history_screen.dart}
        ├── export/
        │   ├── transfer_view_model.dart
        │   └── screens/export_screen.dart
        ├── import/screens/import_screen.dart
        ├── sample/
        │   ├── capture_view_model.dart
        │   ├── pairing_view_model.dart
        │   ├── sample_view_model.dart
        │   ├── screens/{join_sample_screen.dart, new_sample_screen.dart, sample_detail_screen.dart, sample_list_screen.dart, show_sample_qr_screen.dart}
        │   └── widgets/photo_slot_card.dart
        ├── settings/
        │   ├── settings_view_model.dart
        │   └── screens/settings_screen.dart
        └── trash/screens/trash_screen.dart
```

---

## 2. Navigation Routes (`lib/router.dart`)

| Route Path | Route Name | Screen Class | Parameters / Extra |
|---|---|---|---|
| `/` | `dashboard` | `DashboardScreen` | — |
| `/new-sample` | `new-sample` | `NewSampleScreen` | Query `sampleUuid` (optional) |
| `/camera/:sampleUuid/:leafSide` | `camera` | `CameraScreen` | Path `sampleUuid`, `leafSide` |
| `/join-sample` | `join-sample` | `JoinSampleScreen` | — |
| `/show-qr/:sampleUuid` | `show-qr` | `ShowSampleQrScreen` | Path `sampleUuid` |
| `/samples` | `samples` | `SampleListScreen` | — |
| `/sample/:sampleUuid` | `sample-detail` | `SampleDetailScreen` | Path `sampleUuid` |
| `/export` | `export` | `ExportScreen` | `extra` (`List<String>?` UUIDs) |
| `/import` | `import` | `ImportScreen` | — |
| `/drive-backup` | `drive-backup` | `DriveBackupScreen` | `extra` (`List<String>?` UUIDs) |
| `/drive-backup/history` | `drive-backup-history` | `DriveBackupHistoryScreen` | — |
| `/trash` | `trash` | `TrashScreen` | — |
| `/data-management` | `data-management` | `DataManagementScreen` | — |
| `/settings` | `settings` | `SettingsScreen` | — |

---

## 3. State Management (Riverpod)

| Provider | ViewModel / State | File |
|---|---|---|
| `dashboardViewModelProvider` | `DashboardViewModel` / `DashboardState` | `features/dashboard/dashboard_view_model.dart` |
| `captureViewModelProvider` (`.autoDispose`) | `CaptureViewModel` / `CaptureState` | `features/sample/capture_view_model.dart` |
| `joinSampleViewModelProvider` | `JoinSampleViewModel` / `JoinSampleState` | `features/sample/pairing_view_model.dart` |
| `sampleListViewModelProvider` | `SampleListViewModel` / `SampleListState` | `features/sample/sample_view_model.dart` |
| `sampleDetailViewModelProvider` (`.autoDispose`) | `SampleDetailViewModel` / `SampleDetailState` | `features/sample/sample_view_model.dart` |
| `exportViewModelProvider` (`.autoDispose`) | `ExportViewModel` / `ExportState` | `features/export/transfer_view_model.dart` |
| `importViewModelProvider` | `ImportViewModel` / `ImportState` | `features/export/transfer_view_model.dart` |
| `driveBackupViewModelProvider` (`.autoDispose`) | `DriveBackupViewModel` / `DriveBackupState` | `features/drive_backup/drive_backup_view_model.dart` |
| `dataManagementViewModelProvider` (`.autoDispose`) | `DataManagementViewModel` / `DataManagementState` | `features/data_management/data_management_view_model.dart` |
| `settingsViewModelProvider` | `SettingsViewModel` / `SettingsState` | `features/settings/settings_view_model.dart` |

---

## 4. SQLite Schema (`teafield_capture.db`, Version 1)

Managed by `AppDatabase` (`lib/data/database/app_database.dart`) with `PRAGMA foreign_keys = ON`. Test hook: `AppDatabase.instance.setTestDatabase(db)`.

### Tables (`lib/data/database/database_migrations.dart`)

1. **`leaf_samples`** (PK: `sample_uuid`)
   - Identity & provenance: `sample_code`, `project_code`, `created_at_utc`, `updated_at_utc`, `created_by_device_id`, `master_device_id`
   - Field metadata: `estate_name`, `region`, `district`, `bush_plot_code`, `collector_code`
   - Labels: `field_label` (default `'not_sure'`), `expert_label`, `label_status` (`'pending'`, `'confirmed'`, `'rejected_or_relabelled'`), `expert_reviewer_code`, `expert_reviewed_at_utc`, `severity`, `symptom_notes`, `other_notes`
   - Sample GPS: `sample_latitude`, `sample_longitude`, `sample_gps_accuracy_m`, `sample_gps_captured_at_utc`, `sample_gps_status` (default `'not_requested'`)
   - Workflow & Trash: `sample_status` (`'incomplete'`, `'ready_for_review'`, `'verified'`, `'needs_recheck'`), `deleted_at_utc`, `is_imported` (0/1), `source_sample_uuid`
2. **`leaf_photos`** (PK: `photo_uuid`, FK: `sample_uuid` → `leaf_samples` `ON DELETE CASCADE`)
   - Media & integrity: `leaf_side` (`CHECK (leaf_side IN ('upper', 'lower'))`), `file_path`, `original_file_name`, `sha256`, `width_px`, `height_px`, `file_size_bytes`, `captured_at_utc`
   - Per-photo device provenance: `device_id`, `device_platform`, `device_manufacturer`, `device_model`, `os_version`, `app_version`
   - Per-photo GPS: `latitude`, `longitude`, `gps_accuracy_m`, `gps_captured_at_utc`, `gps_status`
   - Audit & Trash: `is_primary` (default `1`), `photo_review_status` (default `'accepted'`), `deleted_at_utc`, `created_at_utc`
3. **`import_history`** (PK: `import_id`) — Tracks merged ZIP packages (`source_device_id`, `imported_at_utc`, `package_name`, `package_checksum`, `result_summary`).
4. **`drive_backup_batches`** (PK: `backup_id`) — Tracks manual Drive ZIP uploads (`google_account_email`, `drive_folder_id`, `drive_file_id`, `drive_file_name`, `local_zip_path`, `package_sha256`, `sample_count`, `photo_count`, `backup_type`, `status`, `created_at_utc`, `uploaded_at_utc`, `last_error`).
5. **`drive_backup_items`** (PK: `(backup_id, sample_uuid)`, FK: `backup_id` → `drive_backup_batches` `ON DELETE CASCADE`) — Stores `sample_content_sha256` per sample per batch for changed-sample detection.
6. **`pending_cloud_deletions`** (PK: `drive_file_id`) — Minimal offline retry queue of Drive file IDs requested for deletion during local purge (`drive_file_name`, `google_account_email`, `requested_at_utc`, `status`, `last_error`).

### Indexes (7)
- `idx_samples_date` on `leaf_samples(created_at_utc)`
- `idx_samples_estate` on `leaf_samples(estate_name)`
- `idx_samples_label` on `leaf_samples(field_label, label_status)`
- `idx_photos_sample_side` on `leaf_photos(sample_uuid, leaf_side)`
- `idx_photos_hash` on `leaf_photos(sha256)`
- `idx_pending_cloud_deletions_status` on `pending_cloud_deletions(status, requested_at_utc)`
- `idx_drive_backup_status` on `drive_backup_batches(status, created_at_utc)`

---

## 5. App-Private File & Package Layouts

### Local Storage (`FileStorageService`)
```text
<app_documents>/teafield/
├── photos/<sample_uuid>/<photo_uuid>_<upper|lower>.jpg
├── exports/
└── imports/
```

### Research ZIP Archive (`PackageTransferService`)
```text
teafield_export_<SHORT_DEVICE>_<yyyyMMdd_HHmmss>.zip
├── manifest.json       # TransferManifest (schema_version, project_code, export_device_id, export_time_utc, counts, app_version)
├── samples.json        # List of LeafSample maps
├── photos.json         # List of LeafPhoto maps + zip_path
├── samples.csv         # One row per physical leaf sample (21 columns)
├── photos.csv          # One row per photograph (21 columns)
├── checksums.sha256    # "<sha256>  <rel_path>" for every photo and metadata file
└── photos/<sample_uuid>/<photo_uuid>_<side>.<ext>
```

### Compact QR Pairing Payload (`QrPairingService`)
```json
{
  "app": "teafield",
  "version": 1,
  "project_code": "SL_TEA_RESEARCH",
  "sample_uuid": "<uuid-v4>",
  "sample_code": "TEA-YYYYMMDD-XXXX-NNNNN"
}
```

### Google Drive Hierarchy (`GoogleDriveBackupService`)
```text
My Drive/TeaField Capture/<PROJECT_CODE>/
├── README_backup_contents.txt
└── backups/teafield_<all|selected|changed>_<yyyy-MM-dd_HHmmss>.zip
```
