import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import './app_directories.dart';

// TODO: If Web support is required, guard dart:io usage or use conditional imports.
/// Resolves persisted absolute file paths that include the iOS sandbox UUID
/// to the current app container path after an app update.
///
/// Example:
///   Before update: /var/mobile/Containers/Data/Application/ABC/Documents/upload/x.png
///   After update:  /var/mobile/Containers/Data/Application/XYZ/Documents/upload/x.png
///
/// We store absolute paths in message content. On iOS, the container prefix
/// changes after update. This helper rewrites any path that points into our
/// previous container's Documents subfolders (upload/avatars) to the current
/// Documents directory. If the rewritten file exists, it returns the new path;
/// otherwise returns the original path.
class SandboxPathResolver {
  SandboxPathResolver._();

  static String? _docsDir;
  static String? _supportDir;
  static bool debug = false;

  /// Call once during app startup to cache the current Documents directory.
  static Future<void> init() async {
    try {
      // Use the platform-specific app data directory
      final dir = await AppDirectories.getAppDataDirectory();
      _docsDir = dir.path;
      try {
        final sup = await getApplicationSupportDirectory();
        _supportDir = sup.path;
      } catch (_) {
        _supportDir = null;
      }
      if (debug) {
        debugPrint('[SandboxPathResolver.init] docsDir=$_docsDir supportDir=$_supportDir');
      }
    } catch (_) {
      // Leave null; fix() will no-op in this case.
      _docsDir = null;
      _supportDir = null;
    }
  }

  /// Synchronously map an old absolute path to the current container's path
  /// when it points under our managed subfolders (upload/images/avatars).
  /// If mapping succeeds and the target exists, returns the mapped path;
  /// otherwise returns [path] unchanged.
  static String fix(String path) {
    if (path.isEmpty) return path;

    // Strip file:// scheme if present
    final String raw0 = path.startsWith('file://') ? path.substring(7) : path;
    // Normalize backslashes to forward slashes for matching
    final String raw = raw0.replaceAll('\\', '/');

    final docs = _docsDir;
    final support = _supportDir;
    if (docs == null || docs.isEmpty) return raw;

    // Determine root and tail to map
    // Cases we support:
    // - iOS/macOS: .../Documents/<subdir>/...
    // - Android: .../app_flutter/<subdir>/... or .../files/<subdir>/...
    // - Windows: .../AppData/Local/Kelivo/<subdir>/... or .../Kelivo/<subdir>/...
    const subdirs = ['avatars', 'images', 'upload'];
    String? tail; // starts with '/'
    String rootType = 'unknown';

    final int iosIdx = raw.indexOf('/Documents/');
    if (iosIdx != -1) {
      final candidateTail = raw.substring(iosIdx + '/Documents'.length); // includes leading '/'
      // Check subdir presence to avoid false positives
      if (subdirs.any((s) => candidateTail.startsWith('/$s/'))) {
        tail = candidateTail;
        rootType = 'documents';
      }
    }

    // Try to match Windows AppData paths (exported from Windows, imported elsewhere)
    if (tail == null) {
      final int kelivoIdx = raw.indexOf('/kelivo/');
      if (kelivoIdx != -1) {
        final candidateTail = raw.substring(kelivoIdx + '/kelivo'.length); // includes leading '/'
        if (subdirs.any((s) => candidateTail.startsWith('/$s/'))) {
          tail = candidateTail;
          rootType = 'windows_kelivo';
        }
      }
    }

    if (tail == null) {
      for (final androidRoot in const ['/app_flutter/', '/files/']) {
        final int aidx = raw.indexOf(androidRoot);
        if (aidx != -1) {
          final after = raw.substring(aidx + androidRoot.length);
          if (subdirs.any((s) => after.startsWith('$s/'))) {
            tail = '/$after';
            rootType = androidRoot.replaceAll('/', '');
            break;
          }
        }
      }
    }

    // Final generic fallback: detect '/avatars/' '/images/' '/upload/' anywhere in the path
    if (tail == null) {
      for (final s in subdirs) {
        final i = raw.indexOf('/$s/');
        if (i != -1) {
          tail = raw.substring(i); // includes leading '/'
          rootType = 'generic_subdir';
          break;
        }
      }
    }

    if (tail == null) {
      if (debug) debugPrint('[SandboxPathResolver.fix] input=$path -> skipped (no known subdir pattern found)');
      return raw;
    }

    // Primary: map to current ApplicationDocumentsDirectory
    final String mapped = '$docs$tail';
    try {
      if (File(mapped).existsSync()) {
        if (debug) debugPrint('[SandboxPathResolver.fix] root=$rootType input=$path -> mappedDocs=$mapped (exists)');
        return mapped;
      } else {
        if (debug) debugPrint('[SandboxPathResolver.fix] root=$rootType tried mappedDocs=$mapped (missing)');
      }
    } catch (e) {
      if (debug) debugPrint('[SandboxPathResolver.fix] root=$rootType mappedDocs error: $e');
    }

    // Secondary: try ApplicationSupportDirectory
    if (support != null && support.isNotEmpty) {
      final alt = '$support$tail';
      try {
        if (File(alt).existsSync()) {
          if (debug) debugPrint('[SandboxPathResolver.fix] root=$rootType input=$path -> mappedSupport=$alt (exists)');
          return alt;
        } else {
          if (debug) debugPrint('[SandboxPathResolver.fix] root=$rootType tried mappedSupport=$alt (missing)');
        }
      } catch (e) {
        if (debug) debugPrint('[SandboxPathResolver.fix] root=$rootType mappedSupport error: $e');
      }
    }

    // Fallback: search by basename under common folders in both roots
    final String base = _basename(tail);
    for (final root in <String?>[docs, support]) {
      if (root == null || root.isEmpty) continue;
      for (final sub in const ['avatars', 'images', 'upload']) {
        final probe = '$root/$sub/$base';
        try {
          if (File(probe).existsSync()) {
            if (debug) debugPrint('[SandboxPathResolver.fix] root=$rootType input=$path -> basenameProbe=$probe (exists)');
            return probe;
          } else {
            if (debug) debugPrint('[SandboxPathResolver.fix] root=$rootType tried basenameProbe=$probe (missing)');
          }
        } catch (e) {
          if (debug) debugPrint('[SandboxPathResolver.fix] root=$rootType basenameProbe error: $e');
        }
      }
    }
    if (debug) debugPrint('[SandboxPathResolver.fix] root=$rootType input=$path -> unchanged=$raw (no match)');
    return raw;
  }

  static String _basename(String p) {
    if (p.isEmpty) return p;
    final norm = p.replaceAll('\\', '/');
    final i = norm.lastIndexOf('/');
    return i == -1 ? norm : norm.substring(i + 1);
  }

  // Expose current dirs for diagnostic purposes
  static String? get docsDir => _docsDir;
  static String? get supportDir => _supportDir;
}
