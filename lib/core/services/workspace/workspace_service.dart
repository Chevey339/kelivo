import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../utils/app_directories.dart';

/// A single grep match: file path, line number, line content, and optional
/// surrounding context lines.
class GrepMatch {
  final String relativePath;
  final String fileName;
  final int lineNumber;
  final String lineContent;
  final List<String> contextBefore;
  final List<String> contextAfter;

  const GrepMatch({
    required this.relativePath,
    required this.fileName,
    required this.lineNumber,
    required this.lineContent,
    this.contextBefore = const [],
    this.contextAfter = const [],
  });
}

/// A single entry (file or directory) inside a conversation workspace.
class WorkspaceEntry {
  final String name;
  // Path relative to the workspace root, using the host path separator.
  final String relativePath;
  final bool isDir;
  final int size; // bytes; directories report 0.
  final DateTime modifiedAt;

  const WorkspaceEntry({
    required this.name,
    required this.relativePath,
    required this.isDir,
    required this.size,
    required this.modifiedAt,
  });
}

/// Manages per-conversation workspace directories under
/// `<app_data>/workspaces/<conversation_id>/` where `<app_data>` is resolved
/// via [AppDirectories.getAppDataDirectory] (Application Support on desktop,
/// Application Documents on mobile).
///
/// All methods are static and stateless. [resolveSafePath] is the security
/// boundary for any caller-supplied relative path: it must never let a
/// relative path escape its workspace root.
abstract final class WorkspaceService {
  WorkspaceService._();

  /// Returns the absolute workspace root for [conversationId]:
  /// `<app_data>/workspaces/<conversation_id>/`.
  ///
  /// Does not create the directory.
  static Future<String> getWorkspaceRoot(String conversationId) async {
    final root = await AppDirectories.getAppDataDirectory();
    return p.join(root.path, 'workspaces', conversationId);
  }

  /// Returns the workspace root, creating it (recursive) when missing.
  static Future<String> ensureWorkspace(String conversationId) async {
    final root = await getWorkspaceRoot(conversationId);
    final dir = Directory(root);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return root;
  }

  /// Recursively deletes the workspace for [conversationId].
  /// No-op (not an error) when the workspace does not exist.
  static Future<void> deleteWorkspace(String conversationId) async {
    final root = await getWorkspaceRoot(conversationId);
    final dir = Directory(root);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Returns true when the workspace directory exists.
  static Future<bool> workspaceExists(String conversationId) async {
    final root = await getWorkspaceRoot(conversationId);
    return Directory(root).exists();
  }

  /// Resolves [relativePath] against the workspace root for [conversationId]
  /// and returns the normalized absolute path, or `null` when the path would
  /// escape the workspace root.
  ///
  /// Safety rules enforced (returns `null` on violation):
  ///   * [relativePath] must not be absolute on the host platform.
  ///   * [relativePath] must not look like a Windows drive path (e.g. `C:\...`
  ///     or `D:/...`), even on non-Windows hosts.
  ///   * [relativePath] must not begin with a separator (`/` or `\`).
  ///   * After joining and normalizing, the result must equal the root or live
  ///     underneath it; the root-relative form must not start with `..`.
  ///
  /// An empty [relativePath] resolves to the workspace root itself.
  ///
  /// Expected behavior for the canonical cases (kept as a comment spec because
  /// this method has no dedicated unit test in this task):
  ///   * `../etc/passwd`            -> null (escapes root)
  ///   * `/etc/passwd`              -> null (absolute path)
  ///   * `C:\Windows\system32`      -> null (Windows absolute path)
  ///   * `subdir/../file.txt`       -> `<root>/file.txt` (stays inside root)
  ///   * `subdir/file.txt`          -> `<root>/subdir/file.txt`
  ///   * `` (empty)                 -> `<root>` (root itself)
  static Future<String?> resolveSafePath(
    String conversationId,
    String relativePath,
  ) async {
    final root = await getWorkspaceRoot(conversationId);
    final rootNorm = p.normalize(root);

    if (relativePath.isEmpty) return rootNorm;

    // Reject host-absolute paths (Unix `/...`, Windows `C:\...` on Windows).
    if (p.isAbsolute(relativePath)) return null;

    // Reject Windows drive-prefixed paths on any host: the `path` package only
    // treats them as absolute under the Windows style, so a host running on
    // macOS/Linux would otherwise let `C:\Windows` slip through.
    if (_looksLikeWindowsDrivePath(relativePath)) return null;

    // Reject leading separators so `/etc/passwd` is blocked on Windows where
    // p.isAbsolute may return false for drive-less absolute-looking inputs.
    if (relativePath.startsWith('/') || relativePath.startsWith(r'\')) {
      return null;
    }

    final absolute = p.join(root, relativePath);
    final normalized = p.normalize(absolute);

    // Must be the root itself or live underneath it.
    if (normalized == rootNorm) return normalized;
    if (!p.isWithin(rootNorm, normalized)) return null;

    // Defense-in-depth: the root-relative form must not start with `..`.
    final rel = p.relative(normalized, from: rootNorm);
    if (rel.startsWith('..') || p.isAbsolute(rel)) return null;

    return normalized;
  }

  /// Lists direct children of the workspace root (or of [subPath] when given).
  ///
  /// Returns an empty list when the workspace does not exist or [subPath] is
  /// rejected by [resolveSafePath]. Listing is non-recursive.
  static Future<List<WorkspaceEntry>> listFiles(
    String conversationId, [
    String? subPath,
  ]) async {
    final root = await getWorkspaceRoot(conversationId);
    final rootNorm = p.normalize(root);

    Directory target;
    if (subPath == null || subPath.isEmpty) {
      target = Directory(rootNorm);
    } else {
      final safe = await resolveSafePath(conversationId, subPath);
      if (safe == null) return const <WorkspaceEntry>[];
      target = Directory(safe);
    }

    if (!await target.exists()) return const <WorkspaceEntry>[];

    final out = <WorkspaceEntry>[];
    try {
      await for (final ent in target.list(followLinks: false)) {
        final isDir = ent is Directory;
        final name = p.basename(ent.path);
        final relPath = p.relative(ent.path, from: rootNorm);
        int size = 0;
        DateTime modified = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        try {
          final stat = await ent.stat();
          size = isDir ? 0 : stat.size;
          modified = stat.modified;
        } catch (_) {
          // Keep defaults; entry is still reported.
        }
        out.add(
          WorkspaceEntry(
            name: name,
            relativePath: relPath,
            isDir: isDir,
            size: size,
            modifiedAt: modified,
          ),
        );
      }
    } catch (_) {
      // Ignore listing errors and return whatever was collected.
    }
    return out;
  }

  /// Recursively searches file contents under the workspace root for
  /// [query]. Returns matching lines (with optional context) grouped by file.
  ///
  /// Only text files under 512 KB are searched. Search is case-insensitive.
  /// [maxResults] caps the total number of matches. [contextLines] controls
  /// how many lines before and after each match are included.
  static Future<List<GrepMatch>> grep(
    String conversationId,
    String query, {
    int maxResults = 50,
    int contextLines = 0,
  }) async {
    if (query.isEmpty) return const <GrepMatch>[];

    final root = await getWorkspaceRoot(conversationId);
    final rootDir = Directory(root);
    if (!await rootDir.exists()) return const <GrepMatch>[];

    final matches = <GrepMatch>[];
    final lowerQuery = query.toLowerCase();

    await for (final entity
        in rootDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (matches.length >= maxResults) break;

      final stat = await entity.stat();
      if (stat.size > 512 * 1024) continue; // skip files > 512 KB

      final relPath = p.relative(entity.path, from: root);
      try {
        final lines = await entity.readAsLines();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].toLowerCase().contains(lowerQuery)) {
            final ctxStart = (i - contextLines).clamp(0, lines.length - 1);
            final ctxEnd = (i + contextLines).clamp(0, lines.length - 1);
            matches.add(
              GrepMatch(
                relativePath: relPath,
                fileName: p.basename(entity.path),
                lineNumber: i + 1,
                lineContent: lines[i],
                contextBefore: contextLines > 0
                    ? lines.sublist(ctxStart, i)
                    : const [],
                contextAfter: contextLines > 0
                    ? lines.sublist(i + 1, ctxEnd + 1)
                    : const [],
              ),
            );
            if (matches.length >= maxResults) break;
          }
        }
      } catch (_) {
        // Binary or unreadable file — skip.
      }
    }

    return matches;
  }

  static bool _looksLikeWindowsDrivePath(String s) {
    if (s.length < 2) return false;
    final a = s.codeUnitAt(0);
    final b = s.codeUnitAt(1);
    final isAlpha = (a >= 65 && a <= 90) || (a >= 97 && a <= 122); // A-Z / a-z
    return isAlpha && b == 58; // ':'
  }
}
