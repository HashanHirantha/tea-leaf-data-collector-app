import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_date_utils.dart';
import '../database/app_database.dart';
import '../models/leaf_photo.dart';
import '../models/leaf_sample.dart';
import 'sample_repository.dart';

/// Repository managing SQLite persistence for [LeafPhoto] records.
class PhotoRepository {
  PhotoRepository({
    AppDatabase? database,
    SampleRepository? sampleRepository,
  })  : _db = database ?? AppDatabase.instance,
        _sampleRepo = sampleRepository ?? SampleRepository(database: database);

  final AppDatabase _db;
  final SampleRepository _sampleRepo;

  Future<Database> get _database => _db.database;

  /// Saves a newly captured original photo and marks any earlier primary photo
  /// on the same [leafSide] as non-primary (retaining retake audit trail).
  Future<void> savePhoto(
    LeafPhoto photo, {
    bool markPreviousNonPrimary = true,
    bool allowSingleSideComplete = false,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      if (markPreviousNonPrimary && photo.isPrimary == 1) {
        await txn.update(
          'leaf_photos',
          {'is_primary': 0},
          where:
              'sample_uuid = ? AND leaf_side = ? AND is_primary = 1 AND deleted_at_utc IS NULL',
          whereArgs: [photo.sampleUuid, photo.leafSide],
        );
      }

      await txn.insert(
        'leaf_photos',
        photo.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    await _sampleRepo.recalculateSampleStatus(
      photo.sampleUuid,
      allowSingleSideComplete: allowSingleSideComplete,
    );
  }

  /// Inserts an imported photo without altering existing primary photos unless none exist.
  Future<void> insertImportedPhoto(
    LeafPhoto photo, {
    bool allowSingleSideComplete = false,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      final existingPrimary = await txn.query(
        'leaf_photos',
        columns: ['photo_uuid'],
        where:
            'sample_uuid = ? AND leaf_side = ? AND is_primary = 1 AND deleted_at_utc IS NULL',
        whereArgs: [photo.sampleUuid, photo.leafSide],
        limit: 1,
      );

      final toInsert = existingPrimary.isNotEmpty && photo.isPrimary == 1
          ? photo.copyWith(isPrimary: 0)
          : photo;

      await txn.insert(
        'leaf_photos',
        toInsert.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });

    await _sampleRepo.recalculateSampleStatus(
      photo.sampleUuid,
      allowSingleSideComplete: allowSingleSideComplete,
    );
  }

  /// Returns all photos for [sampleUuid].
  Future<List<LeafPhoto>> getPhotosForSample(
    String sampleUuid, {
    bool includeNonPrimary = true,
    bool includeDeleted = false,
  }) async {
    final db = await _database;
    final whereParts = <String>['sample_uuid = ?'];
    final args = <Object?>[sampleUuid];

    if (!includeNonPrimary) {
      whereParts.add('is_primary = 1');
    }
    if (!includeDeleted) {
      whereParts.add('deleted_at_utc IS NULL');
    }

    final rows = await db.query(
      'leaf_photos',
      where: whereParts.join(' AND '),
      whereArgs: args,
      orderBy: 'is_primary DESC, captured_at_utc DESC',
    );
    return rows.map(LeafPhoto.fromMap).toList();
  }

  /// Returns the primary upper and lower photos for a single sample.
  Future<({LeafPhoto? upper, LeafPhoto? lower})> getPrimaryPhotosForSample(
    String sampleUuid,
  ) async {
    final photos = await getPhotosForSample(
      sampleUuid,
      includeNonPrimary: false,
      includeDeleted: false,
    );

    LeafPhoto? upper;
    LeafPhoto? lower;
    for (final p in photos) {
      if (p.leafSide == LeafSide.upper.databaseKey) upper ??= p;
      if (p.leafSide == LeafSide.lower.databaseKey) lower ??= p;
    }
    return (upper: upper, lower: lower);
  }

  /// Batch-loads primary upper and lower photos for a list of sample UUIDs.
  Future<Map<String, ({LeafPhoto? upper, LeafPhoto? lower})>>
      getPrimaryPhotosForSamples(List<String> sampleUuids) async {
    if (sampleUuids.isEmpty) return {};
    final db = await _database;
    final placeholders = List.filled(sampleUuids.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT * FROM leaf_photos
      WHERE sample_uuid IN ($placeholders)
        AND is_primary = 1
        AND deleted_at_utc IS NULL
    ''', sampleUuids);

    final map = <String, ({LeafPhoto? upper, LeafPhoto? lower})>{};
    for (final row in rows) {
      final photo = LeafPhoto.fromMap(row);
      final current = map[photo.sampleUuid] ?? (upper: null, lower: null);
      if (photo.isUpper) {
        map[photo.sampleUuid] = (upper: photo, lower: current.lower);
      } else {
        map[photo.sampleUuid] = (upper: current.upper, lower: photo);
      }
    }
    return map;
  }

  /// Returns all photos linked to the given [sampleUuids].
  Future<List<LeafPhoto>> getPhotosForSamples(
    List<String> sampleUuids, {
    bool includeDeleted = false,
    bool primaryOnly = false,
  }) async {
    if (sampleUuids.isEmpty) return [];
    final db = await _database;
    final placeholders = List.filled(sampleUuids.length, '?').join(',');
    final whereParts = <String>['sample_uuid IN ($placeholders)'];
    if (!includeDeleted) {
      whereParts.add('deleted_at_utc IS NULL');
    }
    if (primaryOnly) {
      whereParts.add('is_primary = 1');
    }

    final rows = await db.rawQuery('''
      SELECT * FROM leaf_photos
      WHERE ${whereParts.join(' AND ')}
      ORDER BY captured_at_utc ASC
    ''', sampleUuids);
    return rows.map(LeafPhoto.fromMap).toList();
  }

  /// Returns all active photos for a project (or globally).
  Future<List<LeafPhoto>> getAllActivePhotos({
    String? projectCode,
    bool primaryOnly = false,
  }) async {
    final db = await _database;
    final whereParts = <String>[
      'p.deleted_at_utc IS NULL',
      's.deleted_at_utc IS NULL',
    ];
    final args = <Object?>[];

    if (projectCode != null && projectCode.isNotEmpty) {
      whereParts.add('s.project_code = ?');
      args.add(projectCode);
    }
    if (primaryOnly) {
      whereParts.add('p.is_primary = 1');
    }

    final rows = await db.rawQuery('''
      SELECT p.*
      FROM leaf_photos p
      INNER JOIN leaf_samples s ON s.sample_uuid = p.sample_uuid
      WHERE ${whereParts.join(' AND ')}
      ORDER BY p.captured_at_utc DESC
    ''', args);
    return rows.map(LeafPhoto.fromMap).toList();
  }

  /// Returns a photo by UUID.
  Future<LeafPhoto?> getPhotoByUuid(String photoUuid) async {
    final db = await _database;
    final rows = await db.query(
      'leaf_photos',
      where: 'photo_uuid = ?',
      whereArgs: [photoUuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LeafPhoto.fromMap(rows.first);
  }

  /// Checks whether an active or trashed photo with [photoUuid] or exact [sha256]
  /// (within the same sample) already exists.
  Future<bool> isPhotoDuplicate({
    required String photoUuid,
    required String sampleUuid,
    required String sha256,
  }) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT 1 FROM leaf_photos
      WHERE photo_uuid = ?
         OR (sample_uuid = ? AND sha256 = ? AND deleted_at_utc IS NULL)
      LIMIT 1
      ''',
      [photoUuid, sampleUuid, sha256],
    );
    return rows.isNotEmpty;
  }

  /// Checks whether exact [sha256] already exists anywhere in the database.
  Future<List<LeafPhoto>> findBySha256(String sha256) async {
    final db = await _database;
    final rows = await db.query(
      'leaf_photos',
      where: 'sha256 = ? AND deleted_at_utc IS NULL',
      whereArgs: [sha256],
    );
    return rows.map(LeafPhoto.fromMap).toList();
  }

  /// Soft-deletes a single photo without trashing the parent sample.
  Future<void> movePhotoToTrash(
    String photoUuid, {
    bool allowSingleSideComplete = false,
  }) async {
    final photo = await getPhotoByUuid(photoUuid);
    if (photo == null) return;

    final db = await _database;
    final now = AppDateUtils.nowUtcIso();

    await db.transaction((txn) async {
      await txn.update(
        'leaf_photos',
        {'deleted_at_utc': now, 'is_primary': 0},
        where: 'photo_uuid = ?',
        whereArgs: [photoUuid],
      );

      // Promote the most recent remaining non-deleted photo on the same side if any.
      final fallback = await txn.query(
        'leaf_photos',
        where:
            'sample_uuid = ? AND leaf_side = ? AND deleted_at_utc IS NULL',
        whereArgs: [photo.sampleUuid, photo.leafSide],
        orderBy: 'captured_at_utc DESC',
        limit: 1,
      );
      if (fallback.isNotEmpty) {
        await txn.update(
          'leaf_photos',
          {'is_primary': 1},
          where: 'photo_uuid = ?',
          whereArgs: [fallback.first['photo_uuid']],
        );
      }
    });

    await _sampleRepo.recalculateSampleStatus(
      photo.sampleUuid,
      allowSingleSideComplete: allowSingleSideComplete,
    );
  }

  /// Restores a single trashed photo.
  Future<void> restorePhoto(
    String photoUuid, {
    bool allowSingleSideComplete = false,
  }) async {
    final photo = await getPhotoByUuid(photoUuid);
    if (photo == null) return;

    final db = await _database;
    await db.transaction((txn) async {
      // Only promote to primary if no active primary exists for this side.
      final existingPrimary = await txn.query(
        'leaf_photos',
        columns: ['photo_uuid'],
        where:
            'sample_uuid = ? AND leaf_side = ? AND is_primary = 1 AND deleted_at_utc IS NULL',
        whereArgs: [photo.sampleUuid, photo.leafSide],
        limit: 1,
      );

      await txn.update(
        'leaf_photos',
        {
          'deleted_at_utc': null,
          'is_primary': existingPrimary.isEmpty ? 1 : 0,
        },
        where: 'photo_uuid = ?',
        whereArgs: [photoUuid],
      );
    });

    await _sampleRepo.recalculateSampleStatus(
      photo.sampleUuid,
      allowSingleSideComplete: allowSingleSideComplete,
    );
  }

  /// Permanently removes a single photo row from SQLite.
  Future<void> permanentlyDeletePhotoRow(
    String photoUuid, {
    bool allowSingleSideComplete = false,
  }) async {
    final photo = await getPhotoByUuid(photoUuid);
    if (photo == null) return;
    final db = await _database;
    await db.delete(
      'leaf_photos',
      where: 'photo_uuid = ?',
      whereArgs: [photoUuid],
    );
    await _sampleRepo.recalculateSampleStatus(
      photo.sampleUuid,
      allowSingleSideComplete: allowSingleSideComplete,
    );
  }

  /// Returns active photo count for a project (or globally).
  Future<int> getActivePhotoCount({String? projectCode}) async {
    final db = await _database;
    final where = projectCode != null && projectCode.isNotEmpty
        ? 'p.deleted_at_utc IS NULL AND s.deleted_at_utc IS NULL AND s.project_code = ?'
        : 'p.deleted_at_utc IS NULL AND s.deleted_at_utc IS NULL';
    final args =
        projectCode != null && projectCode.isNotEmpty ? [projectCode] : null;
    final result = await db.rawQuery('''
      SELECT COUNT(*) AS cnt
      FROM leaf_photos p
      INNER JOIN leaf_samples s ON s.sample_uuid = p.sample_uuid
      WHERE $where
    ''', args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Returns singly-trashed photos whose parent sample is still active.
  Future<List<LeafPhoto>> getIndividuallyTrashedPhotos() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT p.*
      FROM leaf_photos p
      INNER JOIN leaf_samples s ON s.sample_uuid = p.sample_uuid
      WHERE p.deleted_at_utc IS NOT NULL
        AND s.deleted_at_utc IS NULL
      ORDER BY p.deleted_at_utc DESC
    ''');
    return rows.map(LeafPhoto.fromMap).toList();
  }
}
