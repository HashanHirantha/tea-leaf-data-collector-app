import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../utils/checksum.dart';

/// Metadata extracted after storing an immutable original photo file.
class StoredPhotoFileInfo {
  final String filePath;
  final String originalFileName;
  final String sha256;
  final int fileSizeBytes;
  final int? widthPx;
  final int? heightPx;

  const StoredPhotoFileInfo({
    required this.filePath,
    required this.originalFileName,
    required this.sha256,
    required this.fileSizeBytes,
    this.widthPx,
    this.heightPx,
  });
}

/// Manages app-private file storage for original photos, exports, and imports.
class FileStorageService {
  FileStorageService._();

  static final FileStorageService instance = FileStorageService._();

  Future<Directory> getRootDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docsDir.path, AppConstants.appRootFolder));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<Directory> getPhotosBaseDirectory() async {
    final root = await getRootDirectory();
    final dir = Directory(p.join(root.path, AppConstants.photosFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getSamplePhotosDirectory(String sampleUuid) async {
    final base = await getPhotosBaseDirectory();
    final safeSampleId = _sanitizeIdSegment(sampleUuid);
    final dir = Directory(p.join(base.path, safeSampleId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getExportsDirectory() async {
    final root = await getRootDirectory();
    final dir = Directory(p.join(root.path, AppConstants.exportsFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getImportsDirectory() async {
    final root = await getRootDirectory();
    final dir = Directory(p.join(root.path, AppConstants.importsFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies a captured [XFile] into app-private storage without modifying the
  /// original image bytes, then computes size, SHA-256, and pixel dimensions.
  Future<StoredPhotoFileInfo> saveCapturedPhoto({
    required String sampleUuid,
    required String photoUuid,
    required String leafSide,
    required XFile sourceFile,
  }) async {
    final sampleDir = await getSamplePhotosDirectory(sampleUuid);
    final ext = p.extension(sourceFile.path).isNotEmpty
        ? p.extension(sourceFile.path).toLowerCase()
        : '.jpg';
    final fileName = '${_sanitizeIdSegment(photoUuid)}_$leafSide$ext';
    final destPath = p.join(sampleDir.path, fileName);

    final bytes = await File(sourceFile.path).readAsBytes();
    final destFile = File(destPath);
    await destFile.writeAsBytes(bytes, flush: true);

    final checksum = Checksum.calculateBytesChecksum(bytes);
    final dimensions = await _readImageDimensions(bytes);

    return StoredPhotoFileInfo(
      filePath: destPath,
      originalFileName: p.basename(sourceFile.path),
      sha256: checksum,
      fileSizeBytes: bytes.length,
      widthPx: dimensions.$1,
      heightPx: dimensions.$2,
    );
  }

  /// Saves raw imported image bytes into app-private storage safely.
  Future<String> saveImportedPhotoBytes({
    required String sampleUuid,
    required String photoUuid,
    required String leafSide,
    required Uint8List bytes,
    String extension = '.jpg',
  }) async {
    final sampleDir = await getSamplePhotosDirectory(sampleUuid);
    final safeExt = extension.startsWith('.') ? extension : '.$extension';
    final fileName = '${_sanitizeIdSegment(photoUuid)}_$leafSide$safeExt';
    final destPath = p.join(sampleDir.path, fileName);
    await File(destPath).writeAsBytes(bytes, flush: true);
    return destPath;
  }

  Future<(int?, int?)> _readImageDimensions(Uint8List bytes) async {
    ui.Codec? codec;
    ui.FrameInfo? frame;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      frame = await codec.getNextFrame();
      return (frame.image.width, frame.image.height);
    } catch (_) {
      return (null, null);
    } finally {
      frame?.image.dispose();
      codec?.dispose();
    }
  }

  /// Validates that an archive entry path does not escape [targetRoot]
  /// (ZIP path-traversal protection).
  String validateSafeRelativePath(String archiveEntryPath) {
    final unixNormalized = archiveEntryPath.replaceAll('\\', '/');
    if (unixNormalized.isEmpty ||
        unixNormalized.startsWith('/') ||
        unixNormalized.contains(':') ||
        unixNormalized.split('/').contains('..')) {
      throw FormatException(
        'Unsafe file path detected inside archive: $archiveEntryPath',
      );
    }
    return unixNormalized;
  }

  /// Resolves [relativePath] safely inside [baseDir] and verifies containment.
  String resolveSafeChildPath(Directory baseDir, String relativePath) {
    final safeRel = validateSafeRelativePath(relativePath);
    final resolved = p.normalize(p.joinAll([baseDir.path, ...safeRel.split('/')]));
    final baseNormalized = p.normalize(baseDir.path);
    if (!p.isWithin(baseNormalized, resolved) && resolved != baseNormalized) {
      throw FormatException('Path escapes app storage directory: $relativePath');
    }
    return resolved;
  }

  /// Deletes a photo file if it exists inside app-private storage.
  Future<bool> deleteFileIfExists(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deletes empty sample photo directory if all files inside were deleted.
  Future<void> cleanupEmptySampleDirectory(String sampleUuid) async {
    try {
      final dir = await getSamplePhotosDirectory(sampleUuid);
      if (await dir.exists()) {
        final entries = await dir.list().toList();
        if (entries.isEmpty) {
          await dir.delete();
        }
      }
    } catch (_) {
      // Non-fatal cleanup.
    }
  }

  /// Counts files in the local exports directory.
  Future<int> getLocalExportFileCount() async {
    final dir = await getExportsDirectory();
    if (!await dir.exists()) return 0;
    final entities = await dir.list().toList();
    return entities.whereType<File>().length;
  }

  /// Lists local export files sorted newest first.
  Future<List<File>> listLocalExportFiles() async {
    final dir = await getExportsDirectory();
    if (!await dir.exists()) return [];
    final files = (await dir.list().toList()).whereType<File>().toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Calculates total bytes used by local photos and exports.
  Future<int> getTotalStorageBytesUsed() async {
    final root = await getRootDirectory();
    if (!await root.exists()) return 0;
    var total = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// Removes all photo directories and local export/import temporary packages.
  /// Returns a list of paths that failed to delete, if any.
  Future<List<String>> deleteAllLocalFiles() async {
    final failures = <String>[];
    final root = await getRootDirectory();
    for (final folderName in [
      AppConstants.photosFolder,
      AppConstants.exportsFolder,
      AppConstants.importsFolder,
    ]) {
      final dir = Directory(p.join(root.path, folderName));
      if (!await dir.exists()) continue;
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        failures.add(dir.path);
      }
    }
    return failures;
  }

  String _sanitizeIdSegment(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
    if (cleaned.isEmpty) {
      throw const FormatException('Invalid identifier segment.');
    }
    return cleaned;
  }
}
