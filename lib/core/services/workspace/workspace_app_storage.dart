import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'atomic_file.dart';
import 'workspace_file_coordinator.dart';

typedef _Staged = ({String path, String version, int bytes});

/// Bounded UTF-8 storage for one single-file application's data directory.
/// Hashing, decoding, synchronous metadata checks and disk I/O run off the UI
/// isolate. No watcher, polling timer or worker is kept alive while idle.
class WorkspaceAppStorage {
  WorkspaceAppStorage({
    required this.root,
    required this.directory,
    required this.authorize,
  });
  final String root;
  final String directory;
  final Future<void> Function(String relativePath, bool write) authorize;
  static const maxBytes = 2 * 1024 * 1024;
  static const _extensions = {'.json', '.txt', '.md', '.csv'};
  static final _deviceName = RegExp(
    r'^(con|prn|aux|nul|conin\$|conout\$|com[1-9¹²³]|lpt[1-9¹²³])(?:[ .]|$)',
    caseSensitive: false,
  );

  String _relative(String name) {
    final parts = name.split('/');
    if (name.length > 512 ||
        parts.length > 8 ||
        parts.any(
          (part) =>
              part.isEmpty ||
              part == '.' ||
              part == '..' ||
              part.contains(RegExp(r'[\\:\x00-\x1f]')) ||
              part.endsWith('.') ||
              part != part.trim() ||
              _deviceName.hasMatch(part),
        ) ||
        !_extensions.contains(p.posix.extension(name).toLowerCase())) {
      throw StateError('storage_invalid_path');
    }
    return p.posix.join(directory, name);
  }

  Future<Map<String, Object?>> read(String name) async {
    final relative = _relative(name);
    final rootPath = root;
    return _withFileLock(relative, () async {
      await authorize(relative, false);
      final result = await _readInWorker(rootPath, relative);
      await authorize(relative, false);
      return result;
    });
  }

  Future<Map<String, Object?>> write(
    String name,
    String content,
    String? version,
  ) async {
    if (content.length > maxBytes) throw StateError('storage_too_large');
    if (version != null && !RegExp(r'^[0-9a-f]{64}$').hasMatch(version)) {
      throw StateError('storage_invalid_version');
    }
    final relative = _relative(name);
    final rootPath = root;
    return _withFileLock(relative, () async {
      await authorize(relative, true);
      final staged = await _stageInWorker(rootPath, relative, content, version);
      try {
        await authorize(relative, true);
        final result = await _commitInWorker(
          rootPath,
          relative,
          staged,
          version,
        );
        WorkspaceFileCoordinator.changed(p.join(rootPath, relative));
        return result;
      } finally {
        await _cleanupInWorker(staged.path);
      }
    });
  }

  Future<Map<String, Object?>> _withFileLock(
    String relative,
    Future<Map<String, Object?>> Function() operation,
  ) async {
    try {
      // The page RPC expires after 30 seconds. Reject long lock waits well
      // before that deadline, without leaving a write queued to run later.
      return await WorkspaceFileCoordinator.run(
        p.join(root, relative),
        operation,
        waitTimeout: const Duration(seconds: 5),
      );
    } on TimeoutException {
      throw StateError('storage_busy');
    }
  }

  // Separate closure contexts keep UI/native objects captured by authorize
  // out of isolate messages, including on successful read-only requests.
  static Future<Map<String, Object?>> _readInWorker(
    String root,
    String relative,
  ) => Isolate.run(() => _read(root, relative));
  static Future<_Staged> _stageInWorker(
    String root,
    String relative,
    String content,
    String? version,
  ) => Isolate.run(() => _stage(root, relative, content, version));
  static Future<void> _cleanupInWorker(String path) => Isolate.run(() {
    final staging = File(path).parent;
    if (staging.existsSync()) staging.deleteSync(recursive: true);
  });
  static Future<Map<String, Object?>> _commitInWorker(
    String root,
    String relative,
    _Staged staged,
    String? version,
  ) => Isolate.run(() {
    final target = _target(root, relative);
    if (_read(root, relative)['version'] != version) {
      throw StateError('storage_conflict');
    }
    try {
      publishFileAtomicallySync(staged.path, target, replace: version != null);
    } on StateError catch (error) {
      if (error.message == 'browser_workspace_file_exists') {
        throw StateError('storage_conflict');
      }
      rethrow;
    }
    return <String, Object?>{'version': staged.version, 'bytes': staged.bytes};
  });

  static String _target(
    String root,
    String relative, {
    bool createParents = false,
  }) {
    if (Directory(root).resolveSymbolicLinksSync() != root ||
        FileSystemEntity.typeSync(root, followLinks: false) !=
            FileSystemEntityType.directory) {
      throw StateError('storage_symlink_denied');
    }
    final parts = p.posix.split(relative);
    if (!p.isAbsolute(root) ||
        parts.isEmpty ||
        parts.any((s) => s == '..' || s == '.' || s.contains(r'\')) ||
        p.posix.isAbsolute(relative)) {
      throw StateError('storage_invalid_path');
    }
    var current = root;
    for (var i = 0; i < parts.length; i++) {
      current = p.join(current, parts[i]);
      final type = FileSystemEntity.typeSync(current, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw StateError('storage_symlink_denied');
      }
      if (i < parts.length - 1) {
        if (type == FileSystemEntityType.notFound) {
          if (createParents) Directory(current).createSync();
        } else if (type != FileSystemEntityType.directory) {
          throw StateError('storage_not_directory');
        }
      } else if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw StateError('storage_not_file');
      }
    }
    return current;
  }

  static Map<String, Object?> _read(String root, String relative) {
    final target = _target(root, relative);
    if (!File(target).existsSync()) return {'content': null, 'version': null};
    final handle = File(target).openSync();
    try {
      final length = handle.lengthSync();
      if (length > maxBytes) throw StateError('storage_too_large');
      final bytes = handle.readSync(length);
      if (bytes.length != length || handle.lengthSync() != length) {
        throw StateError('storage_conflict');
      }
      final String content;
      try {
        content = utf8.decode(bytes);
      } on FormatException {
        throw StateError('storage_invalid_utf8');
      }
      return {'content': content, 'version': sha256.convert(bytes).toString()};
    } finally {
      handle.closeSync();
    }
  }

  static _Staged _stage(
    String root,
    String relative,
    String content,
    String? version,
  ) {
    final bytes = utf8.encode(content);
    if (bytes.length > maxBytes) throw StateError('storage_too_large');
    if (utf8.decode(bytes) != content) throw StateError('storage_invalid_utf8');
    if (_read(root, relative)['version'] != version) {
      throw StateError('storage_conflict');
    }
    final target = _target(root, relative, createParents: true);
    final staging = File(target).parent.createTempSync('.kelivo-data-');
    try {
      final file = File(p.join(staging.path, 'data'))
        ..writeAsBytesSync(bytes, flush: true);
      return (
        path: file.path,
        version: sha256.convert(bytes).toString(),
        bytes: bytes.length,
      );
    } catch (_) {
      staging.deleteSync(recursive: true);
      rethrow;
    }
  }
}
