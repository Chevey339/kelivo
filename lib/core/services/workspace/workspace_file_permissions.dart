import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../../../utils/windows_file_path.dart';
import 'atomic_file.dart';

@Native<Int32 Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>)>(
  symbol: 'workspace_replace_document',
)
external int _replaceDocument(
  Pointer<Utf16> target,
  Pointer<Utf16> staged,
  Pointer<Utf16> backup,
);

void replaceWindowsWorkspaceDocument(String target, String staged) {
  final backup = '$staged.original';
  final error = using(
    (arena) => _replaceDocument(
      _path(target, arena).cast(),
      _path(staged, arena).cast(),
      _path(backup, arena).cast(),
    ),
  );
  finishWindowsWorkspaceReplacement(target, backup, error);
}

/// A supplied backup keeps the original in place for error 1176. For 1177
/// Windows moved the original to the backup path and left the draft staged.
void finishWindowsWorkspaceReplacement(
  String target,
  String backup,
  int error,
) {
  if (error == 0) {
    try {
      File(backup).deleteSync();
    } on FileSystemException {
      // The replacement is already committed even if cleanup failed.
    }
    return;
  }
  if (error == 1177) {
    try {
      publishFileAtomicallySync(backup, target);
    } catch (_) {
      // A new file may already occupy the old name. Keep both files.
      throw FileSystemException(
        'Could not restore original file',
        backup,
        OSError('', error),
      );
    }
  }
  throw FileSystemException(
    'Could not replace file',
    target,
    OSError('', error),
  );
}

@Native<Int32 Function(Pointer<Void>, Pointer<Void>)>(
  symbol: 'workspace_can_edit',
)
external int _canEdit(Pointer<Void> path, Pointer<Void> parent);

@Native<Int32 Function(Pointer<Void>, Pointer<Void>, Uint32)>(
  symbol: 'workspace_set_permissions',
)
external int _setPermissions(
  Pointer<Void> path,
  Pointer<Void> source,
  int mode,
);

@Native<Int32 Function(Pointer<Utf8>, Pointer<Utf8>)>(
  symbol: 'workspace_copy_exclusive',
)
external int _copyExclusive(Pointer<Utf8> source, Pointer<Utf8> target);

void copyWorkspaceFileExclusively(String source, String target) {
  final error = using(
    (arena) => _copyExclusive(
      source.toNativeUtf8(allocator: arena),
      target.toNativeUtf8(allocator: arena),
    ),
  );
  if (error == 17) throw StateError('browser_workspace_file_exists');
  if (error != 0) {
    throw FileSystemException(
      'Could not create draft copy',
      target,
      OSError('', error),
    );
  }
}

Pointer<Void> _path(String path, Arena arena) => Platform.isWindows
    ? extendedWindowsFilePath(path).toNativeUtf16(allocator: arena).cast()
    : path.toNativeUtf8(allocator: arena).cast();

/// Queries the current user's access without creating or truncating the file.
bool canWriteWorkspaceFile(File file) => using(
  (arena) =>
      _canEdit(_path(file.path, arena), _path(file.parent.path, arena)) != 0,
);

/// Copy the existing file's access rules. New draft copies and the staging
/// directory start with owner-only access on volumes with per-file permissions.
void setWorkspaceFilePermissions(
  String path, {
  String? source,
  int mode = 0x180,
}) {
  final error = using(
    (arena) => _setPermissions(
      _path(path, arena),
      source == null ? nullptr : _path(source, arena),
      mode,
    ),
  );
  if (error != 0) {
    throw FileSystemException(
      'Could not preserve file permissions',
      path,
      OSError('', error),
    );
  }
}
