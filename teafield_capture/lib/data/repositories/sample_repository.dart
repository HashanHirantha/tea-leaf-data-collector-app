import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_date_utils.dart';
import '../database/app_database.dart';
import '../models/leaf_sample.dart';

/// Repository managing SQLite persistence for [LeafSample] records.
class SampleRepository {
  SampleRepository({AppDatabase? database})
      : _db = database ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  /// Inserts a new sample record.
  Future<void> createSample(LeafSample sample) async {
    final db = await _database;
    await db.insert(
      'leaf_samples',
      sample.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Inserts or replaces an imported sample record.
  Future<void> upsertImportedSample(LeafSample sample) async {
    final db = await _database;
    await db.insert(
      'leaf_samples',
      sample.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates an existing sample record.
  Future<void> updateSample(LeafSample sample) async {
    final db = await _database;
    await db.update(
      'leaf_samples',
      sample.toMap(),
      where: 'sample_uuid = ?',
      whereArgs: [sample.sampleUuid],
    );
  }

  /// Returns a sample by [sampleUuid], excluding trashed rows by default.
  Future<LeafSample?> getSampleByUuid(
    String sampleUuid, {
    bool includeDeleted = false,
  }) async {
    final db = await _database;
    final where = includeDeleted
        ? 'sample_uuid = ?'
        : 'sample_uuid = ? AND deleted_at_utc IS NULL';
    final rows = await db.query(
      'leaf_samples',
      where: where,
      whereArgs: [sampleUuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LeafSample.fromMap(rows.first);
  }

  /// Returns all active (non-trashed) samples ordered newest first.
  Future<List<LeafSample>> getAllActiveSamples({String? projectCode}) async {
    final db = await _database;
    final whereParts = <String>['deleted_at_utc IS NULL'];
    final args = <Object?>[];

    if (projectCode != null && projectCode.isNotEmpty) {
      whereParts.add('project_code = ?');
      args.add(projectCode);
    }

    final rows = await db.query(
      'leaf_samples',
      where: whereParts.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at_utc DESC',
    );
    return rows.map(LeafSample.fromMap).toList();
  }

  /// Searches and filters active samples.
  Future<List<LeafSample>> searchSamples({
    String? query,
    String? status,
    String? estate,
    String? fieldLabel,
    String? missingSide,
    String? startDateIso,
    String? endDateIso,
    String? projectCode,
  }) async {
    final db = await _database;
    final whereParts = <String>['s.deleted_at_utc IS NULL'];
    final args = <Object?>[];

    if (projectCode != null && projectCode.isNotEmpty) {
      whereParts.add('s.project_code = ?');
      args.add(projectCode);
    }

    if (query != null && query.trim().isNotEmpty) {
      final like = '%${query.trim()}%';
      whereParts.add(
        '(s.sample_code LIKE ? OR s.estate_name LIKE ? OR s.bush_plot_code LIKE ? OR s.field_label LIKE ? OR s.collector_code LIKE ?)',
      );
      args.addAll([like, like, like, like, like]);
    }

    if (status != null && status.isNotEmpty && status != 'all') {
      whereParts.add('s.sample_status = ?');
      args.add(status);
    }

    if (estate != null && estate.isNotEmpty && estate != 'all') {
      whereParts.add('s.estate_name = ?');
      args.add(estate);
    }

    if (fieldLabel != null && fieldLabel.isNotEmpty && fieldLabel != 'all') {
      whereParts.add('s.field_label = ?');
      args.add(fieldLabel);
    }

    if (startDateIso != null && startDateIso.isNotEmpty) {
      whereParts.add('s.created_at_utc >= ?');
      args.add(startDateIso);
    }

    if (endDateIso != null && endDateIso.isNotEmpty) {
      whereParts.add('s.created_at_utc <= ?');
      args.add(endDateIso);
    }

    if (missingSide == 'upper' || missingSide == 'lower') {
      whereParts.add('''
        NOT EXISTS (
          SELECT 1 FROM leaf_photos p
          WHERE p.sample_uuid = s.sample_uuid
            AND p.leaf_side = ?
            AND p.is_primary = 1
            AND p.deleted_at_utc IS NULL
        )
      ''');
      args.add(missingSide);
    } else if (missingSide == 'any') {
      whereParts.add('''
        (
          NOT EXISTS (
            SELECT 1 FROM leaf_photos p
            WHERE p.sample_uuid = s.sample_uuid
              AND p.leaf_side = 'upper'
              AND p.is_primary = 1
              AND p.deleted_at_utc IS NULL
          )
          OR NOT EXISTS (
            SELECT 1 FROM leaf_photos p
            WHERE p.sample_uuid = s.sample_uuid
              AND p.leaf_side = 'lower'
              AND p.is_primary = 1
              AND p.deleted_at_utc IS NULL
          )
        )
      ''');
    }

    final rows = await db.rawQuery('''
      SELECT s.*
      FROM leaf_samples s
      WHERE ${whereParts.join(' AND ')}
      ORDER BY s.created_at_utc DESC
    ''', args);

    return rows.map(LeafSample.fromMap).toList();
  }

  /// Returns active samples that are incomplete.
  Future<List<LeafSample>> getIncompleteSamples({String? projectCode}) async {
    return searchSamples(status: 'incomplete', projectCode: projectCode);
  }

  /// Returns all trashed samples ordered by deletion timestamp descending.
  Future<List<LeafSample>> getTrashedSamples({String? projectCode}) async {
    final db = await _database;
    final whereParts = <String>['deleted_at_utc IS NOT NULL'];
    final args = <Object?>[];

    if (projectCode != null && projectCode.isNotEmpty) {
      whereParts.add('project_code = ?');
      args.add(projectCode);
    }

    final rows = await db.query(
      'leaf_samples',
      where: whereParts.join(' AND '),
      whereArgs: args,
      orderBy: 'deleted_at_utc DESC',
    );
    return rows.map(LeafSample.fromMap).toList();
  }

  /// Returns total active sample count.
  Future<int> getActiveSampleCount({String? projectCode}) async {
    final db = await _database;
    final where = projectCode != null && projectCode.isNotEmpty
        ? 'deleted_at_utc IS NULL AND project_code = ?'
        : 'deleted_at_utc IS NULL';
    final args =
        projectCode != null && projectCode.isNotEmpty ? [projectCode] : null;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM leaf_samples WHERE $where',
      args,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Returns incomplete active sample count.
  Future<int> getIncompleteSampleCount({String? projectCode}) async {
    final db = await _database;
    final where = projectCode != null && projectCode.isNotEmpty
        ? "deleted_at_utc IS NULL AND sample_status = 'incomplete' AND project_code = ?"
        : "deleted_at_utc IS NULL AND sample_status = 'incomplete'";
    final args =
        projectCode != null && projectCode.isNotEmpty ? [projectCode] : null;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM leaf_samples WHERE $where',
      args,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Returns trashed sample count.
  Future<int> getTrashedSampleCount({String? projectCode}) async {
    final db = await _database;
    final where = projectCode != null && projectCode.isNotEmpty
        ? 'deleted_at_utc IS NOT NULL AND project_code = ?'
        : 'deleted_at_utc IS NOT NULL';
    final args =
        projectCode != null && projectCode.isNotEmpty ? [projectCode] : null;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM leaf_samples WHERE $where',
      args,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Soft deletes a sample and all its linked photos in one transaction.
  Future<void> moveSampleToTrash(String sampleUuid) async {
    await moveSamplesToTrash([sampleUuid]);
  }

  /// Soft deletes multiple samples and their linked photos in one transaction.
  Future<void> moveSamplesToTrash(List<String> sampleUuids) async {
    if (sampleUuids.isEmpty) return;
    final now = AppDateUtils.nowUtcIso();
    final db = await _database;

    await db.transaction((txn) async {
      final placeholders = List.filled(sampleUuids.length, '?').join(',');
      await txn.rawUpdate(
        'UPDATE leaf_samples SET deleted_at_utc = ?, updated_at_utc = ? WHERE sample_uuid IN ($placeholders) AND deleted_at_utc IS NULL',
        [now, now, ...sampleUuids],
      );
      await txn.rawUpdate(
        'UPDATE leaf_photos SET deleted_at_utc = ? WHERE sample_uuid IN ($placeholders) AND deleted_at_utc IS NULL',
        [now, ...sampleUuids],
      );
    });
  }

  /// Restores a sample and its linked photos from Trash in one transaction.
  Future<void> restoreSample(String sampleUuid) async {
    await restoreSamples([sampleUuid]);
  }

  /// Restores multiple samples and their linked photos from Trash.
  Future<void> restoreSamples(List<String> sampleUuids) async {
    if (sampleUuids.isEmpty) return;
    final now = AppDateUtils.nowUtcIso();
    final db = await _database;

    await db.transaction((txn) async {
      final placeholders = List.filled(sampleUuids.length, '?').join(',');
      await txn.rawUpdate(
        'UPDATE leaf_samples SET deleted_at_utc = NULL, updated_at_utc = ? WHERE sample_uuid IN ($placeholders)',
        [now, ...sampleUuids],
      );
      await txn.rawUpdate(
        'UPDATE leaf_photos SET deleted_at_utc = NULL WHERE sample_uuid IN ($placeholders)',
        sampleUuids,
      );
    });
  }

  /// Permanently removes sample and photo rows from SQLite (files must be
  /// removed by the deletion service).
  Future<void> permanentlyDeleteSamplesFromDb(List<String> sampleUuids) async {
    if (sampleUuids.isEmpty) return;
    final db = await _database;
    final placeholders = List.filled(sampleUuids.length, '?').join(',');
    await db.transaction((txn) async {
      await txn.rawDelete(
        'DELETE FROM leaf_photos WHERE sample_uuid IN ($placeholders)',
        sampleUuids,
      );
      await txn.rawDelete(
        'DELETE FROM leaf_samples WHERE sample_uuid IN ($placeholders)',
        sampleUuids,
      );
    });
  }

  /// Recalculates [sampleStatus] based on accepted primary photos and expert review state.
  Future<SampleStatus> recalculateSampleStatus(
    String sampleUuid, {
    bool allowSingleSideComplete = false,
  }) async {
    final db = await _database;
    final sample = await getSampleByUuid(sampleUuid, includeDeleted: true);
    if (sample == null) return SampleStatus.incomplete;

    // Preserve verified or needs_recheck if expert review already occurred.
    if (sample.labelStatus == LabelStatus.confirmed.databaseKey) {
      if (sample.sampleStatus != SampleStatus.verified.databaseKey) {
        await db.update(
          'leaf_samples',
          {
            'sample_status': SampleStatus.verified.databaseKey,
            'updated_at_utc': AppDateUtils.nowUtcIso(),
          },
          where: 'sample_uuid = ?',
          whereArgs: [sampleUuid],
        );
      }
      return SampleStatus.verified;
    }

    if (sample.sampleStatus == SampleStatus.needsRecheck.databaseKey) {
      return SampleStatus.needsRecheck;
    }

    final photos = await db.query(
      'leaf_photos',
      columns: ['leaf_side'],
      where:
          "sample_uuid = ? AND is_primary = 1 AND deleted_at_utc IS NULL AND photo_review_status = 'accepted'",
      whereArgs: [sampleUuid],
    );

    final sides = photos.map((r) => r['leaf_side'] as String).toSet();
    final hasUpper = sides.contains('upper');
    final hasLower = sides.contains('lower');

    final isComplete =
        (hasUpper && hasLower) || (allowSingleSideComplete && (hasUpper || hasLower));

    final newStatus = isComplete && sample.fieldLabel.isNotEmpty
        ? SampleStatus.readyForReview
        : SampleStatus.incomplete;

    if (sample.sampleStatus != newStatus.databaseKey) {
      await db.update(
        'leaf_samples',
        {
          'sample_status': newStatus.databaseKey,
          'updated_at_utc': AppDateUtils.nowUtcIso(),
        },
        where: 'sample_uuid = ?',
        whereArgs: [sampleUuid],
      );
    }

    return newStatus;
  }

  /// Applies an expert review without overwriting the original [fieldLabel].
  Future<void> updateExpertReview({
    required String sampleUuid,
    required String expertLabel,
    required LabelStatus labelStatus,
    required String reviewerCode,
    SampleStatus? overrideSampleStatus,
  }) async {
    final db = await _database;
    final now = AppDateUtils.nowUtcIso();

    final SampleStatus nextStatus = overrideSampleStatus ??
        (labelStatus == LabelStatus.confirmed ||
                labelStatus == LabelStatus.rejectedOrRelabelled
            ? SampleStatus.verified
            : SampleStatus.readyForReview);

    await db.update(
      'leaf_samples',
      {
        'expert_label': expertLabel,
        'label_status': labelStatus.databaseKey,
        'expert_reviewer_code': reviewerCode,
        'expert_reviewed_at_utc': now,
        'sample_status': nextStatus.databaseKey,
        'updated_at_utc': now,
      },
      where: 'sample_uuid = ?',
      whereArgs: [sampleUuid],
    );
  }

  /// Computes a deterministic SHA-256 fingerprint of a sample and its active photos.
  /// Used to detect new or modified samples since the last Google Drive backup.
  Future<String?> computeSampleContentSha256(String sampleUuid) async {
    final db = await _database;
    final sample = await getSampleByUuid(sampleUuid);
    if (sample == null) return null;

    final photos = await db.query(
      'leaf_photos',
      columns: ['photo_uuid', 'leaf_side', 'sha256', 'is_primary'],
      where: 'sample_uuid = ? AND deleted_at_utc IS NULL',
      whereArgs: [sampleUuid],
      orderBy: 'photo_uuid ASC',
    );

    final payload = json.encode({
      'sample': sample.toMap(),
      'photos': photos,
    });
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// Returns distinct non-empty estate names stored locally.
  Future<List<String>> getDistinctEstates() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT estate_name
      FROM leaf_samples
      WHERE deleted_at_utc IS NULL
        AND estate_name IS NOT NULL
        AND TRIM(estate_name) != ''
      ORDER BY estate_name ASC
    ''');
    return rows.map((r) => r['estate_name'] as String).toList();
  }
}
