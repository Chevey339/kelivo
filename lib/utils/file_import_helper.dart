import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import '../shared/dialogs/file_duplicate_dialog.dart';

class FileImportHelper {
  /// Copies a file (represented by XFile) to the target directory with duplicate handling.
  ///
  /// If a file with the same name exists:
  /// - Compares size and modification time.
  /// - If identical, asks user whether to use existing or upload as new copy.
  /// - If not identical or user chooses new copy, generates a versioned name (e.g. "file(1).ext").
  ///
  /// Returns the path of the saved/reused file, or null if operation failed.
  static Future<String?> copyXFile(
    XFile xFile,
    Directory targetDir,
    BuildContext context,
  ) async {
    try {
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // XFile.name is the preferred filename
      final String originalName = xFile.name.isNotEmpty 
          ? xFile.name 
          : (xFile.path.isNotEmpty ? p.basename(xFile.path) : DateTime.now().millisecondsSinceEpoch.toString());
      
      final File sourceFile = File(xFile.path);
      FileStat? srcStat;
      if (xFile.path.isNotEmpty) {
        try {
          srcStat = await sourceFile.stat();
        } catch (_) {}
      }

      File dest = File(p.join(targetDir.path, originalName));

      if (await dest.exists()) {
        FileStat? destStat;
        try {
          destStat = await dest.stat();
        } catch (_) {}

        final srcModifiedSec = srcStat == null ? null : (srcStat.modified.millisecondsSinceEpoch ~/ 1000);
        final destModifiedSec = destStat == null ? null : (destStat.modified.millisecondsSinceEpoch ~/ 1000);
        
        final sameSize = srcStat != null && destStat != null && srcStat.size == destStat.size;
        final sameModified = srcModifiedSec != null && destModifiedSec != null && srcModifiedSec == destModifiedSec;

        if (sameSize && sameModified) {
          final useExisting = await FileDuplicateDialog.show(context, originalName);
          if (useExisting) {
            return dest.path;
          }
        }

        // Generate versioned name
        final base = p.basenameWithoutExtension(originalName);
        final ext = p.extension(originalName);
        var counter = 1;
        String candidate;
        do {
          candidate = p.join(targetDir.path, '$base($counter)$ext');
          counter++;
        } while (await File(candidate).exists());
        dest = File(candidate);
      }

      // Perform copy
      await dest.writeAsBytes(await xFile.readAsBytes());
      
      // Keep modified time to help cache keying
      if (srcStat != null) {
        try {
          await dest.setLastModified(srcStat.modified);
        } catch (_) {}
      }
      
      return dest.path;
    } catch (_) {
      return null;
    }
  }
}
