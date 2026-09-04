import 'dart:io';

import 'package:path/path.dart' as p;

/// Snapshots file mtimes under workspace-related roots so a later `shell`
/// call can report which files it created or modified.
class FileSnapshot {
  /// Returns host path → mtime milliseconds. Skips dot-directories and
  /// `.l2s.*` overlay files. Caps at [maxEntries].
  static Future<Map<String, int>> snapshot(
    List<Directory> roots, {
    int maxEntries = 20000,
  }) async {
    final out = <String, int>{};
    for (final root in roots) {
      if (!await root.exists()) continue;
      await _walk(root, out, maxEntries);
      if (out.length >= maxEntries) break;
    }
    return out;
  }

  /// Host paths that are new in [after] or whose mtime changed.
  static List<String> changedSince(
    Map<String, int> before,
    Map<String, int> after,
  ) {
    final changed = <String>[];
    for (final entry in after.entries) {
      final previous = before[entry.key];
      if (previous == null || previous != entry.value) {
        changed.add(entry.key);
      }
    }
    return changed;
  }

  static Future<void> _walk(
    Directory dir,
    Map<String, int> out,
    int maxEntries,
  ) async {
    final children = await dir.list(followLinks: false).toList();
    for (final entity in children) {
      if (out.length >= maxEntries) return;
      final name = p.basename(entity.path);
      if (name.startsWith('.l2s.')) continue;
      if (entity is Directory) {
        if (name.startsWith('.')) continue;
        await _walk(entity, out, maxEntries);
        continue;
      }
      try {
        final stat = await entity.stat();
        out[entity.path] = stat.modified.millisecondsSinceEpoch;
      } on FileSystemException {
        // Skip unreadable entries.
      }
    }
  }
}
