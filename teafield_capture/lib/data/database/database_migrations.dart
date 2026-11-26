import 'package:sqflite/sqflite.dart';

/// Database schema creation and future version migrations.
class DatabaseMigrations {
  DatabaseMigrations._();

  /// Creates all initial v1 tables and indexes.
  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS leaf_samples (
        sample_uuid TEXT PRIMARY KEY,
        sample_code TEXT NOT NULL,
        project_code TEXT NOT NULL,
        created_at_utc TEXT NOT NULL,
        updated_at_utc TEXT NOT NULL,
        created_by_device_id TEXT NOT NULL,
        master_device_id TEXT,

        estate_name TEXT,
        region TEXT,
        district TEXT,
        bush_plot_code TEXT,
        collector_code TEXT,

        field_label TEXT NOT NULL DEFAULT 'not_sure',
        expert_label TEXT,
        label_status TEXT NOT NULL DEFAULT 'pending',
        expert_reviewer_code TEXT,
        expert_reviewed_at_utc TEXT,

        severity INTEGER,
        symptom_notes TEXT,
        other_notes TEXT,

        sample_latitude REAL,
        sample_longitude REAL,
        sample_gps_accuracy_m REAL,
        sample_gps_captured_at_utc TEXT,
        sample_gps_status TEXT NOT NULL DEFAULT 'not_requested',

        sample_status TEXT NOT NULL DEFAULT 'incomplete',
        deleted_at_utc TEXT,
        is_imported INTEGER NOT NULL DEFAULT 0,
        source_sample_uuid TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_samples_date
      ON leaf_samples(created_at_utc)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_samples_estate
      ON leaf_samples(estate_name)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_samples_label
      ON leaf_samples(field_label, label_status)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS leaf_photos (
        photo_uuid TEXT PRIMARY KEY,
        sample_uuid TEXT NOT NULL,
        leaf_side TEXT NOT NULL CHECK (leaf_side IN ('upper', 'lower')),
        file_path TEXT NOT NULL,
        original_file_name TEXT,
        sha256 TEXT NOT NULL,
        width_px INTEGER,
        height_px INTEGER,
        file_size_bytes INTEGER,
        captured_at_utc TEXT NOT NULL,

        device_id TEXT NOT NULL,
        device_platform TEXT,
        device_manufacturer TEXT,
        device_model TEXT,
        os_version TEXT,
        app_version TEXT,

        latitude REAL,
        longitude REAL,
        gps_accuracy_m REAL,
        gps_captured_at_utc TEXT,
        gps_status TEXT NOT NULL DEFAULT 'not_requested',

        is_primary INTEGER NOT NULL DEFAULT 1,
        photo_review_status TEXT NOT NULL DEFAULT 'accepted',
        deleted_at_utc TEXT,
        created_at_utc TEXT NOT NULL,

        FOREIGN KEY (sample_uuid) REFERENCES leaf_samples(sample_uuid)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_photos_sample_side
      ON leaf_photos(sample_uuid, leaf_side)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_photos_hash
      ON leaf_photos(sha256)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS import_history (
        import_id TEXT PRIMARY KEY,
        source_device_id TEXT,
        imported_at_utc TEXT NOT NULL,
        package_name TEXT NOT NULL,
        package_checksum TEXT,
        result_summary TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS drive_backup_batches (
        backup_id TEXT PRIMARY KEY,
        google_account_email TEXT,
        drive_folder_id TEXT,
        drive_file_id TEXT,
        drive_file_name TEXT NOT NULL,
        local_zip_path TEXT,
        package_sha256 TEXT,
        sample_count INTEGER NOT NULL DEFAULT 0,
        photo_count INTEGER NOT NULL DEFAULT 0,
        backup_type TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at_utc TEXT NOT NULL,
        uploaded_at_utc TEXT,
        last_error TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS drive_backup_items (
        backup_id TEXT NOT NULL,
        sample_uuid TEXT NOT NULL,
        sample_content_sha256 TEXT,
        PRIMARY KEY (backup_id, sample_uuid),
        FOREIGN KEY (backup_id) REFERENCES drive_backup_batches(backup_id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_cloud_deletions (
        drive_file_id TEXT PRIMARY KEY,
        drive_file_name TEXT NOT NULL,
        google_account_email TEXT,
        requested_at_utc TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        last_error TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pending_cloud_deletions_status
      ON pending_cloud_deletions(status, requested_at_utc)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_drive_backup_status
      ON drive_backup_batches(status, created_at_utc)
    ''');
  }

  /// Handles incremental database upgrades without deleting user data.
  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Future schema migrations go here.
  }
}
