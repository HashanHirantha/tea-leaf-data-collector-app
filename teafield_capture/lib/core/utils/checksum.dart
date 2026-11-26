import 'dart:io';
import 'package:crypto/crypto.dart';

/// Utility for computing SHA-256 checksums on files and byte arrays.
class Checksum {
  Checksum._();

  /// Compute the SHA-256 checksum of a file at [filePath].
  static Future<String> calculateFileChecksum(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  /// Compute the SHA-256 checksum of raw bytes.
  static String calculateBytesChecksum(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }
}
