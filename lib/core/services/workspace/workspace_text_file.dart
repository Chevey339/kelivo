import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:path/path.dart' as p;

import 'atomic_file.dart';
import 'workspace_file_permissions.dart';
import 'workspace_file_coordinator.dart';
import 'workspace_paths.dart';

enum WorkspaceTextProblem implements Exception {
  large,
  encoding,
  readOnly,
  conflict,
}

/// Limits shared with rich preview. Paged previews never open an edit session.
abstract final class WorkspaceTextLimits {
  static const bytes = 128 * 1024;
  static const lines = 2000;
  static const lineLength = 2048;
  static bool fitsLines(List<String> value) =>
      value.length <= lines && value.every((line) => line.length <= lineLength);
}

class WorkspaceTextSnapshot {
  WorkspaceTextSnapshot._(
    this.root,
    this.path,
    this.bytes,
    this.mode,
    String source,
    this.lineEnding,
  ) : text = lineEnding == '\r\n' || lineEnding == '\r'
          ? source.replaceAll(lineEnding, '\n')
          : source;

  final String root;
  final String path;
  final Uint8List bytes;
  final int mode;
  final String lineEnding;
  final String text;

  // Mixed endings are edited verbatim. For uniform CRLF/CR, the keyboard can
  // use LF internally and newly inserted lines inherit the document's style.
  static String _lineEnding(String source) {
    if (!source.contains('\r')) return '\n';
    final endings = RegExp(r'\r\n|\r|\n').allMatches(source);
    final first = endings.first.group(0)!;
    return endings.every((m) => m.group(0) == first) ? first : '';
  }

  static Future<void> checkWritable(String root, String path) =>
      Isolate.run(() {
        _checkWritable(File(_target(root, path)));
      });

  static Future<WorkspaceTextSnapshot> open(String root, String path) =>
      Isolate.run(() {
        final target = _target(root, path);
        final file = File(target);
        _checkWritable(file);
        final bytes = _readBounded(file);
        final String source;
        try {
          source = utf8.decode(bytes);
        } on FormatException {
          throw WorkspaceTextProblem.encoding;
        }
        if (source.contains('\x00')) throw WorkspaceTextProblem.encoding;
        if (!WorkspaceTextLimits.fitsLines(
          source.split(RegExp(r'\r\n|\r|\n')),
        )) {
          throw WorkspaceTextProblem.large;
        }
        return WorkspaceTextSnapshot._(
          Directory(root).resolveSymbolicLinksSync(),
          target,
          bytes,
          file.statSync().mode,
          source,
          _lineEnding(source),
        );
      });

  static String _target(String root, String path) {
    final resolvedRoot = Directory(root).resolveSymbolicLinksSync();
    final target = _resolveEntryPath(path);
    if (!p.isWithin(resolvedRoot, target)) throw WorkspaceTextProblem.readOnly;
    return target;
  }

  static String _resolveEntryPath(String path) => p.join(
    Directory(p.dirname(path)).resolveSymbolicLinksSync(),
    p.basename(path),
  );

  static void _checkWritable(File file, {bool replacing = false}) {
    final type = FileSystemEntity.typeSync(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound ||
        replacing && type != FileSystemEntityType.file) {
      throw WorkspaceTextProblem.conflict;
    }
    if (type != FileSystemEntityType.file ||
        file.statSync().mode & 0x92 == 0 ||
        !canWriteWorkspaceFile(file)) {
      throw WorkspaceTextProblem.readOnly;
    }
  }

  static Uint8List _readBounded(File file) {
    final handle = file.openSync();
    try {
      final size = handle.lengthSync();
      if (size > WorkspaceTextLimits.bytes) throw WorkspaceTextProblem.large;
      final data = handle.readSync(size);
      if (data.length != size || handle.lengthSync() != size) {
        throw WorkspaceTextProblem.conflict;
      }
      return data;
    } finally {
      handle.closeSync();
    }
  }

  /// Revalidate after staging, since resolving a mount or writing a file on an
  /// external volume can take time. All participating writers share this lock.
  Future<String> save({
    required String path,
    required String draft,
    required Future<String> Function(String directory) writableRoot,
    bool copy = false,
  }) async {
    // Choose the real destination before checking mounts. A missing parent
    // can only recover a copy in the still-authorized workspace root.
    final directory = await _destinationDirectory(path, copy: copy);
    try {
      return await WorkspaceFileCoordinator.run(directory, () async {
        final root = await writableRoot(directory);
        final staged = await _stageInWorker(
          this,
          root,
          path,
          draft,
          copy,
          directory,
        );
        try {
          final liveRoot = await writableRoot(directory);
          final published = await _publishInWorker(
            this,
            liveRoot,
            path,
            staged,
            copy,
          );
          WorkspaceFileCoordinator.changed(published);
          return published;
        } finally {
          await _removeStaging(staged);
        }
      });
    } on PathResolutionException {
      // The selected directory disappeared while its lock or grant was resolving.
      throw WorkspaceTextProblem.conflict;
    }
  }

  Uint8List _encodeDraft(String draft) {
    final source = lineEnding.isEmpty || lineEnding == '\n'
        ? draft
        : draft
              .replaceAll('\r\n', '\n')
              .replaceAll('\r', '\n')
              .replaceAll('\n', lineEnding);
    final encoded = utf8.encode(source);
    if (source.contains('\x00') ||
        utf8.decode(encoded) !=
            (source.startsWith('\uFEFF') ? source.substring(1) : source)) {
      throw WorkspaceTextProblem.encoding;
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xef &&
        bytes[1] == 0xbb &&
        bytes[2] == 0xbf) {
      return Uint8List(encoded.length + 3)
        ..setRange(0, 3, bytes)
        ..setRange(3, encoded.length + 3, encoded);
    }
    return encoded;
  }

  static String _verifiedTarget(
    WorkspaceTextSnapshot snapshot,
    String root,
    String path, {
    bool recoverInRoot = false,
  }) {
    if (!p.equals(Directory(root).resolveSymbolicLinksSync(), snapshot.root)) {
      throw WorkspaceTextProblem.readOnly;
    }
    try {
      if (p.equals(_resolveEntryPath(path), snapshot.path)) {
        return snapshot.path;
      }
    } on FileSystemException catch (error) {
      final missing = Platform.isWindows ? const {2, 3, 267} : const {2, 20};
      if (!missing.contains(error.osError?.errorCode)) rethrow;
    }
    // An absent or redirected parent no longer identifies the opened document.
    // Only a separately authorized copy can be written in the original root.
    if (!recoverInRoot) throw WorkspaceTextProblem.conflict;
    return p.join(snapshot.root, p.basename(snapshot.path));
  }

  Future<String> _destinationDirectory(String path, {required bool copy}) =>
      Isolate.run(
        () => p.dirname(_verifiedTarget(this, root, path, recoverInRoot: copy)),
      );

  Future<String> pathForReload(String root, String path) => Isolate.run(() {
    final target = _verifiedTarget(this, root, path);
    final type = FileSystemEntity.typeSync(target, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw PathNotFoundException(target, const OSError('File not found', 2));
    }
    if (type != FileSystemEntityType.file) throw WorkspaceTextProblem.readOnly;
    return target;
  });

  static Future<String> _stageInWorker(
    WorkspaceTextSnapshot snapshot,
    String root,
    String path,
    String draft,
    bool copy,
    String directory,
  ) => Isolate.run(() {
    final target = _verifiedTarget(snapshot, root, path, recoverInRoot: copy);
    if (!p.equals(p.dirname(target), directory)) {
      throw WorkspaceTextProblem.conflict;
    }
    final bytes = snapshot._encodeDraft(draft);
    final staging = File(target).parent.createTempSync('.kelivo-edit-');
    final staged = File(p.join(staging.path, 'content'));
    try {
      setWorkspaceFilePermissions(staging.path, mode: 0x1c0);
      staged.writeAsBytesSync(bytes, flush: true);
      return staged.path;
    } catch (_) {
      _cleanStaging(staged);
      rethrow;
    }
  });

  static Future<void> _removeStaging(String staged) =>
      Isolate.run(() => _cleanStaging(File(staged)));

  static void _cleanStaging(File staged) {
    final directory = staged.parent;
    try {
      if (!p.equals(directory.resolveSymbolicLinksSync(), directory.path)) {
        return;
      }
      if (FileSystemEntity.typeSync(staged.path, followLinks: false) ==
          FileSystemEntityType.file) {
        staged.deleteSync();
      }
      directory.deleteSync();
    } on FileSystemException {
      // A disconnected volume can prevent cleanup even after a successful save.
    }
  }

  static Future<String> _publishInWorker(
    WorkspaceTextSnapshot snapshot,
    String root,
    String path,
    String staged,
    bool copy,
  ) => Isolate.run(() {
    final target = _verifiedTarget(snapshot, root, path, recoverInRoot: copy);
    final file = File(target);
    if (!p.equals(File(staged).parent.parent.path, file.parent.path)) {
      throw WorkspaceTextProblem.conflict;
    }
    if (copy) {
      setWorkspaceFilePermissions(staged, mode: 0x180 | (snapshot.mode & 0x40));
      final stem = p.basenameWithoutExtension(path), ext = p.extension(path);
      for (var i = 1; ; i++) {
        final sibling = p.join(file.parent.path, '$stem ($i)$ext');
        if (FileSystemEntity.typeSync(sibling, followLinks: false) !=
            FileSystemEntityType.notFound) {
          continue;
        }
        try {
          try {
            publishFileAtomicallySync(staged, sibling);
          } on FileSystemException catch (error) {
            // Android shared storage can support regular renames but reject
            // RENAME_NOREPLACE. Write a new copy through one exclusive handle.
            if (!Platform.isAndroid ||
                !const {22, 38, 95}.contains(error.osError?.errorCode)) {
              rethrow;
            }
            copyWorkspaceFileExclusively(staged, sibling);
          }
          return sibling;
        } on StateError catch (error) {
          if (error.message != 'browser_workspace_file_exists') rethrow;
        }
      }
    }
    _checkWritable(file, replacing: true);
    final before = file.statSync();
    if (before.size != snapshot.bytes.length) {
      throw WorkspaceTextProblem.conflict;
    }
    setWorkspaceFilePermissions(staged, source: target);
    // Shared-volume metadata and resource forks can take time to copy. Check
    // the current document after that work, immediately before replacing it.
    _checkWritable(file, replacing: true);
    try {
      if (!listEquals(_readBounded(file), snapshot.bytes) ||
          file.statSync().changed != before.changed) {
        throw WorkspaceTextProblem.conflict;
      }
    } on WorkspaceTextProblem catch (error) {
      if (error == WorkspaceTextProblem.large) {
        throw WorkspaceTextProblem.conflict;
      }
      rethrow;
    }
    if (Platform.isWindows) {
      replaceWindowsWorkspaceDocument(file.path, staged);
    } else {
      publishFileAtomicallySync(staged, file.path, replace: true);
    }
    return file.path;
  });

  /// A late IME edit may arrive while the old draft is being saved. Keep it
  /// against exactly what this editor published, even if another writer followed.
  Future<WorkspaceTextSnapshot> afterSave(
    String publishedPath,
    String written,
  ) => Isolate.run(() {
    final contents = _encodeDraft(written);
    final source = utf8.decode(contents);
    return WorkspaceTextSnapshot._(
      root,
      publishedPath,
      contents,
      mode,
      source,
      _lineEnding(source),
    );
  });
}
