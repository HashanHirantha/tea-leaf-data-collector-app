import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_date_utils.dart';
import '../database/app_database.dart';
import '../models/drive_backup_batch.dart';
import '../models/import_record.dart';

/// Repository for Google Drive backup batches, pending cloud deletions, and import history.
class BackupRepository {
  BackupRepository({AppDatabase? database})
      : _db = database ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  // ── Drive Backup Batches ──────────────────────────────────────────

  Future<void> insertBatch(
    DriveBackupBatch batch,
    Map<String, String> sampleChecksums,
  ) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert(
        'drive_backup_batches',
        batch.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final entry in sampleChecksums.entries) {
        await txn.insert(
          'drive_backup_items',
          {
            'backup_id': batch.backupId,
            'sample_uuid': entry.key,
            'sample_content_sha256': entry.value,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> updateBatch(DriveBackupBatch batch) async {
    final db = await _database;
    await db.update(
      'drive_backup_batches',
      batch.toMap(),
      where: 'backup_id = ?',
      whereArgs: [batch.backupId],
    );
  }

  Future<DriveBackupBatch?> getBatchById(String backupId) async {
    final db = await _database;
    final rows = await db.query(
      'drive_backup_batches',
      where: 'backup_id = ?',
      whereArgs: [backupId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DriveBackupBatch.fromMap(rows.first);
  }

  Future<List<DriveBackupBatch>> getAllBatches() async {
    final db = await _database;
    final rows = await db.query(
      'drive_backup_batches',
      orderBy: 'created_at_utc DESC',
    );
    return rows.map(DriveBackupBatch.fromMap).toList();
  }

  Future<String?> getLastSuccessfulUploadDate() async {
    final db = await _database;
    final rows = await db.query(
      'drive_backup_batches',
      columns: ['uploaded_at_utc'],
      where: "status = 'uploaded' AND uploaded_at_utc IS NOT NULL",
      orderBy: 'uploaded_at_utc DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['uploaded_at_utc'] as String?;
  }

  /// Returns a map of `sample_uuid -> sample_content_sha256` representing the
  /// most recent successfully uploaded backup state for each sample.
  Future<Map<String, String>> getLatestUploadedSampleChecksums() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT i.sample_uuid, i.sample_content_sha256
      FROM drive_backup_items i
      INNER JOIN drive_backup_batches b ON b.backup_id = i.backup_id
      WHERE b.status = 'uploaded'
      ORDER BY b.uploaded_at_utc ASC
    ''');

    final map = <String, String>{};
    for (final row in rows) {
      final uuid = row['sample_uuid'] as String;
      final sha = row['sample_content_sha256'] as String? ?? '';
      map[uuid] = sha;
    }
    return map;
  }

  /// Returns uploaded Drive batches that contain [sampleUuid].
  Future<List<DriveBackupBatch>> getBatchesContainingSample(
    String sampleUuid,
  ) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT b.*
      FROM drive_backup_batches b
      INNER JOIN drive_backup_items i ON i.backup_id = b.backup_id
      WHERE i.sample_uuid = ? AND b.drive_file_id IS NOT NULL
      ORDER BY b.created_at_utc DESC
    ''', [sampleUuid]);
    return rows.map(DriveBackupBatch.fromMap).toList();
  }

  /// Returns all Drive backup batches that currently have a stored Drive file ID.
  Future<List<DriveBackupBatch>> getTrackedDriveBackups() async {
    final db = await _database;
    final rows = await db.query(
      'drive_backup_batches',
      where: "drive_file_id IS NOT NULL AND status IN ('uploaded', 'delete_pending')",
      orderBy: 'created_at_utc DESC',
    );
    return rows.map(DriveBackupBatch.fromMap).toList();
  }

  /// Removes a batch row after confirmed Drive deletion.
  Future<void> removeBatchRecord(String backupId) async {
    final db = await _database;
    await db.delete(
      'drive_backup_batches',
      where: 'backup_id = ?',
      whereArgs: [backupId],
    );
  }

  // ── Pending Cloud Deletions ───────────────────────────────────────

  Future<void> enqueuePendingCloudDeletions(
    List<PendingCloudDeletion> deletions,
  ) async {
    if (deletions.isEmpty) return;
    final db = await _database;
    await db.transaction((txn) async {
      for (final item in deletions) {
        await txn.insert(
          'pending_cloud_deletions',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<PendingCloudDeletion>> getPendingCloudDeletions() async {
    final db = await _database;
    final rows = await db.query(
      'pending_cloud_deletions',
      where: "status IN ('pending', 'failed')",
      orderBy: 'requested_at_utc ASC',
    );
    return rows.map(PendingCloudDeletion.fromMap).toList();
  }

  Future<void> markCloudDeletionCompleted(String driveFileId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(
        'pending_cloud_deletions',
        where: 'drive_file_id = ?',
        whereArgs: [driveFileId],
      );
      await txn.delete(
        'drive_backup_batches',
        where: 'drive_file_id = ?',
        whereArgs: [driveFileId],
      );
    });
  }

  Future<void> markCloudDeletionFailed(
    String driveFileId,
    String error,
  ) async {
    final db = await _database;
    await db.update(
      'pending_cloud_deletions',
      {
        'status': 'failed',
        'last_error': error,
      },
      where: 'drive_file_id = ?',
      whereArgs: [driveFileId],
    );
  }

  /// Recover any interrupted preparing/uploading batches on app startup.
  Future<void> recoverInterruptedUploads() async {
    final db = await _database;
    await db.update(
      'drive_backup_batches',
      {
        'status': 'failed',
        'last_error': 'Upload interrupted before confirmation.',
      },
      where: "status IN ('preparing', 'uploading')",
    );
  }

  // ── Import History ────────────────────────────────────────────────

  Future<void> insertImportRecord(ImportRecord record) async {
    final db = await _database;
    await db.insert(
      'import_history',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ImportRecord>> getImportHistory() async {
    final db = await _database;
    final rows = await db.query(
      'import_history',
      orderBy: 'imported_at_utc DESC',
    );
    return rows.map(ImportRecord.fromMap).toList();
  }

  // ── Full Local Data Reset ─────────────────────────────────────────

  /// Erases all local research data for [projectCode].
  ///
  /// - If [queueDriveDeletions] is true, copies tracked Drive file IDs into
  ///   `pending_cloud_deletions` before clearing local backup batch metadata.
  /// - If [queueDriveDeletions] is false, clears per-sample `drive_backup_items`
  ///   for deleted samples while keeping the minimal `drive_backup_batches` index
  ///   so the collector can still view/manage existing Drive backups later.
  Future<void> resetLocalResearchData({
    required String projectCode,
    required bool queueDriveDeletions,
  }) async {
    final db = await _database;
    final now = AppDateUtils.nowUtcIso();

    await db.transaction((txn) async {
      final sampleRows = await txn.query(
        'leaf_samples',
        columns: ['sample_uuid'],
        where: 'project_code = ?',
        whereArgs: [projectCode],
      );
      final sampleUuids =
          sampleRows.map((r) => r['sample_uuid'] as String).toList();

      if (queueDriveDeletions) {
        final trackedBatches = await txn.query(
          'drive_backup_batches',
          where: 'drive_file_id IS NOT NULL',
        );
        for (final row in trackedBatches) {
          final fileId = row['drive_file_id'] as String?;
          if (fileId == null || fileId.isEmpty) continue;
          await txn.insert(
            'pending_cloud_deletions',
            PendingCloudDeletion(
              driveFileId: fileId,
              driveFileName: row['drive_file_name'] as String,
              googleAccountEmail: row['google_account_email'] as String?,
              requestedAtUtc: now,
              status: 'pending',
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        await txn.delete('drive_backup_items');
        await txn.delete('drive_backup_batches');
      } else if (sampleUuids.isNotEmpty) {
        final placeholders = List.filled(sampleUuids.length, '?').join(',');
        await txn.rawDelete(
          'DELETE FROM drive_backup_items WHERE sample_uuid IN ($placeholders)',
          sampleUuids,
        );
      }

      if (sampleUuids.isNotEmpty) {
        final placeholders = List.filled(sampleUuids.length, '?').join(',');
        await txn.rawDelete(
          'DELETE FROM leaf_photos WHERE sample_uuid IN ($placeholders)',
          sampleUuids,
        );
        await txn.rawDelete(
          'DELETE FROM leaf_samples WHERE sample_uuid IN ($placeholders)',
          sampleUuids,
        );
      }

      await txn.delete('import_history');
    });
  }
}
