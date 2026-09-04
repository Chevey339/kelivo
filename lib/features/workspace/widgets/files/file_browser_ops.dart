import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

enum FileBrowserSortField { name, modified, size }

class FileBrowserEntry {
  const FileBrowserEntry({
    required this.name,
    required this.hostPath,
    required this.isDirectory,
    required this.size,
    required this.modified,
    this.childCount,
  });

  final String name;
  final String hostPath;
  final bool isDirectory;
  final int size;
  final DateTime modified;

  /// Immediate child count for directories when it was cheap to collect.
  final int? childCount;
}

/// Host-side mutation routed through [FileBrowser.mutationRunner].
sealed class FileMutation {
  const FileMutation({required this.rootPath});

  final String rootPath;
}

final class CreateFolderMutation extends FileMutation {
  const CreateFolderMutation({
    required super.rootPath,
    required this.parentPath,
    required this.name,
  });

  final String parentPath;
  final String name;
}

final class CreateFileMutation extends FileMutation {
  const CreateFileMutation({
    required super.rootPath,
    required this.parentPath,
    required this.name,
  });

  final String parentPath;
  final String name;
}

final class RenameMutation extends FileMutation {
  const RenameMutation({
    required super.rootPath,
    required this.hostPath,
    required this.newName,
  });

  final String hostPath;
  final String newName;
}

final class MoveMutation extends FileMutation {
  const MoveMutation({
    required super.rootPath,
    required this.hostPath,
    required this.destDirPath,
  });

  final String hostPath;
  final String destDirPath;
}

final class DeleteMutation extends FileMutation {
  const DeleteMutation({required super.rootPath, required this.hostPath});

  final String hostPath;
}

final class CopyIntoMutation extends FileMutation {
  const CopyIntoMutation({
    required super.rootPath,
    required this.sourcePath,
    required this.destDirPath,
  });

  final String sourcePath;
  final String destDirPath;
}

final class ZipDirectoryMutation extends FileMutation {
  const ZipDirectoryMutation({
    required super.rootPath,
    required this.sourcePath,
    required this.destPath,
  });

  final String sourcePath;
  final String destPath;
}

/// Path-safe file operations that always stay inside [rootPath].
class FileBrowserOps {
  FileBrowserOps._();

  static String canonicalize(String path) => p.canonicalize(path);

  static bool isWithinRoot(String rootPath, String candidatePath) {
    final root = canonicalize(rootPath);
    final candidate = canonicalize(candidatePath);
    return p.equals(root, candidate) || p.isWithin(root, candidate);
  }

  static String? resolveInsideRoot(String rootPath, String candidatePath) {
    if (candidatePath.contains('\u0000')) return null;
    final candidate = canonicalize(candidatePath);
    return isWithinRoot(rootPath, candidate) ? candidate : null;
  }

  /// Join [relative] onto [rootPath]. Returns null if the result would escape.
  static String? joinInsideRoot(String rootPath, String relative) {
    if (relative.contains('\u0000')) return null;
    final posix = relative.replaceAll('\\', '/');
    if (posix.startsWith('/') || posix.contains(':')) return null;
    final normalized = p.posix.normalize(posix);
    if (normalized == '..' || normalized.startsWith('../')) return null;
    if (normalized.split('/').contains('..')) return null;
    if (normalized == '.' || normalized.isEmpty) {
      return canonicalize(rootPath);
    }
    final hostRel = normalized.split('/').join(p.separator);
    return resolveInsideRoot(rootPath, p.join(rootPath, hostRel));
  }

  static String? posixRelative(String rootPath, String hostPath) {
    final resolved = resolveInsideRoot(rootPath, hostPath);
    if (resolved == null) return null;
    final root = canonicalize(rootPath);
    if (p.equals(root, resolved)) return '';
    return p.relative(resolved, from: root).replaceAll('\\', '/');
  }

  static bool isHiddenName(String name) => name.startsWith('.');

  static bool isValidFileName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '.' || trimmed == '..') return false;
    if (trimmed.contains('\u0000')) return false;
    if (trimmed.contains('/') || trimmed.contains('\\')) return false;
    return true;
  }

  /// Empty string is allowed (workspace root). Otherwise a relative path
  /// without `..` or absolute segments.
  static bool isValidRelativePath(String path) {
    if (path.isEmpty) return true;
    if (path.contains('\u0000')) return false;
    final posix = path.trim().replaceAll('\\', '/');
    if (posix.startsWith('/')) return false;
    final normalized = p.posix.normalize(posix);
    if (normalized == '..' || normalized.startsWith('../')) return false;
    return !normalized.split('/').contains('..');
  }

  static String uniqueName(Directory dir, String desiredName) {
    if (!_exists(p.join(dir.path, desiredName))) {
      return desiredName;
    }
    final ext = p.extension(desiredName);
    final stem = ext.isEmpty
        ? desiredName
        : desiredName.substring(0, desiredName.length - ext.length);
    var n = 2;
    while (true) {
      final candidate = '$stem ($n)$ext';
      if (!_exists(p.join(dir.path, candidate))) {
        return candidate;
      }
      n += 1;
    }
  }

  static bool _exists(String path) {
    return FileSystemEntity.typeSync(path, followLinks: false) !=
        FileSystemEntityType.notFound;
  }

  static Future<List<FileBrowserEntry>> listDir(
    Directory dir, {
    required String rootPath,
    required bool showHidden,
    required FileBrowserSortField sort,
    required bool ascending,
    bool foldersFirst = true,
    bool directoriesOnly = false,
    String? excludePath,
  }) async {
    final resolved = resolveInsideRoot(rootPath, dir.path);
    if (resolved == null) {
      throw StateError('path escapes root');
    }
    final exclude = excludePath == null
        ? null
        : resolveInsideRoot(rootPath, excludePath);
    final entities = await Directory(
      resolved,
    ).list(followLinks: false).toList();
    final entries = <FileBrowserEntry>[];
    for (final entity in entities) {
      final name = p.basename(entity.path);
      if (!showHidden && isHiddenName(name)) continue;
      final entityPath = resolveInsideRoot(rootPath, entity.path);
      if (entityPath == null) continue;
      if (exclude != null &&
          (p.equals(entityPath, exclude) || p.isWithin(exclude, entityPath))) {
        continue;
      }
      final stat = await entity.stat();
      final isDirectory = stat.type == FileSystemEntityType.directory;
      if (directoriesOnly && !isDirectory) continue;
      entries.add(
        FileBrowserEntry(
          name: name,
          hostPath: entity.path,
          isDirectory: isDirectory,
          size: stat.size,
          modified: stat.modified,
        ),
      );
    }
    entries.sort((a, b) {
      if (foldersFirst && a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      final int cmp;
      switch (sort) {
        case FileBrowserSortField.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case FileBrowserSortField.modified:
          cmp = a.modified.compareTo(b.modified);
        case FileBrowserSortField.size:
          cmp = a.size.compareTo(b.size);
      }
      return ascending ? cmp : -cmp;
    });
    return entries;
  }

  /// Default host `dart:io` runner used when [FileBrowser.mutationRunner] is null.
  static Future<void> runMutation(FileMutation mutation) async {
    switch (mutation) {
      case CreateFolderMutation(
        :final rootPath,
        :final parentPath,
        :final name,
      ):
        await createFolder(
          rootPath: rootPath,
          parent: Directory(parentPath),
          name: name,
        );
      case CreateFileMutation(:final rootPath, :final parentPath, :final name):
        await createFile(
          rootPath: rootPath,
          parent: Directory(parentPath),
          name: name,
        );
      case RenameMutation(:final rootPath, :final hostPath, :final newName):
        await renameEntry(
          rootPath: rootPath,
          hostPath: hostPath,
          newName: newName,
        );
      case MoveMutation(:final rootPath, :final hostPath, :final destDirPath):
        await moveEntry(
          rootPath: rootPath,
          hostPath: hostPath,
          destDir: Directory(destDirPath),
        );
      case DeleteMutation(:final rootPath, :final hostPath):
        await deleteEntry(rootPath: rootPath, hostPath: hostPath);
      case CopyIntoMutation(
        :final rootPath,
        :final sourcePath,
        :final destDirPath,
      ):
        await copyInto(
          rootPath: rootPath,
          source: File(sourcePath),
          destDir: Directory(destDirPath),
        );
      case ZipDirectoryMutation(
        :final rootPath,
        :final sourcePath,
        :final destPath,
      ):
        await zipDirectory(
          rootPath: rootPath,
          source: Directory(sourcePath),
          dest: File(destPath),
        );
    }
  }

  static Future<int> directorySize(Directory dir) async {
    var total = 0;
    if (!await dir.exists()) return 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  static Future<void> createFolder({
    required String rootPath,
    required Directory parent,
    required String name,
  }) async {
    if (!isValidFileName(name)) {
      throw ArgumentError('invalid name');
    }
    final parentPath = resolveInsideRoot(rootPath, parent.path);
    if (parentPath == null) throw StateError('path escapes root');
    final dest = joinInsideRoot(
      rootPath,
      _relChild(rootPath, parentPath, name),
    );
    if (dest == null) throw StateError('path escapes root');
    await Directory(dest).create();
  }

  static Future<void> createFile({
    required String rootPath,
    required Directory parent,
    required String name,
  }) async {
    if (!isValidFileName(name)) {
      throw ArgumentError('invalid name');
    }
    final parentPath = resolveInsideRoot(rootPath, parent.path);
    if (parentPath == null) throw StateError('path escapes root');
    final dest = joinInsideRoot(
      rootPath,
      _relChild(rootPath, parentPath, name),
    );
    if (dest == null) throw StateError('path escapes root');
    await File(dest).create();
  }

  static Future<void> renameEntry({
    required String rootPath,
    required String hostPath,
    required String newName,
  }) async {
    if (!isValidFileName(newName)) {
      throw ArgumentError('invalid name');
    }
    final source = resolveInsideRoot(rootPath, hostPath);
    if (source == null) throw StateError('path escapes root');
    if (p.equals(canonicalize(rootPath), source)) {
      throw StateError('cannot rename root');
    }
    final dest = joinInsideRoot(
      rootPath,
      _relChild(rootPath, p.dirname(source), newName),
    );
    if (dest == null) throw StateError('path escapes root');
    await _movePath(source, dest);
  }

  static Future<void> moveEntry({
    required String rootPath,
    required String hostPath,
    required Directory destDir,
  }) async {
    final source = resolveInsideRoot(rootPath, hostPath);
    final destDirPath = resolveInsideRoot(rootPath, destDir.path);
    if (source == null || destDirPath == null) {
      throw StateError('path escapes root');
    }
    if (p.equals(canonicalize(rootPath), source)) {
      throw StateError('cannot move root');
    }
    if (p.equals(source, destDirPath) || p.isWithin(source, destDirPath)) {
      throw StateError('invalid move');
    }
    final name = uniqueName(Directory(destDirPath), p.basename(source));
    final dest = joinInsideRoot(
      rootPath,
      _relChild(rootPath, destDirPath, name),
    );
    if (dest == null) throw StateError('path escapes root');
    if (p.equals(source, dest)) return;
    await _movePath(source, dest);
  }

  static Future<void> deleteEntry({
    required String rootPath,
    required String hostPath,
  }) async {
    final resolved = resolveInsideRoot(rootPath, hostPath);
    if (resolved == null) throw StateError('path escapes root');
    if (p.equals(canonicalize(rootPath), resolved)) {
      throw StateError('cannot delete root');
    }
    final type = FileSystemEntity.typeSync(resolved, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(resolved).delete(recursive: true);
    } else {
      await File(resolved).delete();
    }
  }

  static Future<void> copyInto({
    required String rootPath,
    required File source,
    required Directory destDir,
  }) async {
    final destDirPath = resolveInsideRoot(rootPath, destDir.path);
    if (destDirPath == null) throw StateError('path escapes root');
    final name = uniqueName(Directory(destDirPath), p.basename(source.path));
    final dest = joinInsideRoot(
      rootPath,
      _relChild(rootPath, destDirPath, name),
    );
    if (dest == null) throw StateError('path escapes root');
    await source.copy(dest);
  }

  static Future<File> zipDirectory({
    required String rootPath,
    required Directory source,
    required File dest,
  }) async {
    final resolved = resolveInsideRoot(rootPath, source.path);
    if (resolved == null) throw StateError('path escapes root');
    final destResolved = resolveInsideRoot(rootPath, dest.path);
    // Destination may be outside the workspace (temp / user-chosen save).
    final destPath = destResolved ?? dest.path;
    final archive = Archive();
    await for (final entity in Directory(
      resolved,
    ).list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final filePath = resolveInsideRoot(rootPath, entity.path);
      if (filePath == null) continue;
      final rel = p.relative(filePath, from: resolved).replaceAll('\\', '/');
      archive.addFile(ArchiveFile.bytes(rel, await entity.readAsBytes()));
    }
    final out = File(destPath);
    await out.parent.create(recursive: true);
    await out.writeAsBytes(ZipEncoder().encodeBytes(archive), flush: true);
    return out;
  }

  static String _relChild(String rootPath, String parentPath, String name) {
    final parentRel = posixRelative(rootPath, parentPath) ?? '';
    if (parentRel.isEmpty) return name;
    return '$parentRel/$name';
  }

  static Future<void> _movePath(String source, String dest) async {
    final type = FileSystemEntity.typeSync(source, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(source).rename(dest);
    } else {
      await File(source).rename(dest);
    }
  }
}

class WorkspaceModelPaths {
  WorkspaceModelPaths._();

  static bool get useGuestPaths => Platform.isAndroid || Platform.isIOS;

  static String workspaceFile(String hostPath, String workspaceRoot) {
    if (!useGuestPaths) return hostPath;
    final rel = FileBrowserOps.posixRelative(workspaceRoot, hostPath);
    if (rel == null || rel.isEmpty) return '/workspace';
    return '/workspace/$rel';
  }

  static String chatFile(String hostPath, String zoneRoot, String zone) {
    if (!useGuestPaths) return hostPath;
    final rel = FileBrowserOps.posixRelative(zoneRoot, hostPath);
    if (rel == null || rel.isEmpty) return '/chat/$zone';
    return '/chat/$zone/$rel';
  }
}
