import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import 'upload_dedupe.dart';

class FileImportHelper {
  /// Copies a file (represented by XFile) to the target directory with duplicate handling.
  ///
  /// Duplicates are decided by content: when the target directory already holds
  /// a byte-identical file saved under the same name, that file is reused
  /// instead of storing a second copy. Otherwise the file is written under a
  /// versioned name (e.g. "file(1).ext") so a same-named but different file
  /// never overwrites it.
  ///
  /// Returns the path of the saved/reused file, or null if operation failed.
  static Future<String?> copyXFile(XFile xFile, Directory targetDir) async {
    try {
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // XFile.name is the preferred filename
      final String originalName = xFile.name.isNotEmpty
          ? xFile.name
          : (xFile.path.isNotEmpty
                ? p.basename(xFile.path)
                : DateTime.now().millisecondsSinceEpoch.toString());

      final staging = await targetDir.createTemp('.import-');
      try {
        // File picking, paste and desktop drop can all carry large binaries.
        // Keep both copying and duplicate detection bounded in memory.
        final temp = File(p.join(staging.path, 'file'));
        final output = await temp.open(mode: FileMode.write);
        try {
          await for (final chunk in xFile.openRead()) {
            await output.writeFrom(chunk);
          }
        } finally {
          await output.close();
        }
        final digest = await sha256.bind(temp.openRead()).first;
        final existing = await UploadDedupe.findIdenticalDigest(
          targetDir,
          await temp.length(),
          digest.bytes,
          originalName,
        );
        if (existing != null) return existing;
        final dest = await UploadDedupe.reserveUniqueFile(
          targetDir,
          originalName,
        );
        try {
          await temp.rename(dest.path);
        } catch (_) {
          await dest.delete();
          rethrow;
        }
        return dest.path;
      } finally {
        await staging.delete(recursive: true);
      }
    } catch (_) {
      return null;
    }
  }
}
