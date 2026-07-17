import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

abstract interface class RestoreDurability {
  Future<void> restrictFile(File file);

  Future<void> restrictDirectory(Directory directory);

  Future<void> syncFile(File file, {bool fullBarrier = false});

  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false});

  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  });
}

final class RestorePlatformDurability implements RestoreDurability {
  RestorePlatformDurability()
    : _implementation = Platform.isWindows
          ? _WindowsRestoreDurability()
          : _PosixRestoreDurability();

  final RestoreDurability _implementation;

  @override
  Future<void> restrictFile(File file) => _implementation.restrictFile(file);

  @override
  Future<void> restrictDirectory(Directory directory) =>
      _implementation.restrictDirectory(directory);

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) =>
      _implementation.syncFile(file, fullBarrier: fullBarrier);

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) =>
      _implementation.syncDirectory(directory, fullBarrier: fullBarrier);

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) => _implementation.renameAndSync(source: source, targetPath: targetPath);
}

typedef _OpenNative = Int32 Function(Pointer<Utf8>, Int32);
typedef _OpenDart = int Function(Pointer<Utf8>, int);
typedef _FdCallNative = Int32 Function(Int32);
typedef _FdCallDart = int Function(int);
typedef _FcntlNative = Int32 Function(Int32, Int32);
typedef _FcntlDart = int Function(int, int);
typedef _ChmodNative = Int32 Function(Pointer<Utf8>, Uint32);
typedef _ChmodDart = int Function(Pointer<Utf8>, int);
typedef _ErrnoNative = Pointer<Int32> Function();
typedef _ErrnoDart = Pointer<Int32> Function();

final class _PosixRestoreDurability implements RestoreDurability {
  _PosixRestoreDurability()
    : _library = DynamicLibrary.process(),
      _isApple = Platform.isMacOS || Platform.isIOS {
    _open = _library.lookupFunction<_OpenNative, _OpenDart>('open');
    _fsync = _library.lookupFunction<_FdCallNative, _FdCallDart>('fsync');
    _close = _library.lookupFunction<_FdCallNative, _FdCallDart>('close');
    _fcntl = _library.lookupFunction<_FcntlNative, _FcntlDart>('fcntl');
    _chmod = _library.lookupFunction<_ChmodNative, _ChmodDart>('chmod');
    final errnoSymbol = Platform.isAndroid
        ? '__errno'
        : _isApple
        ? '__error'
        : '__errno_location';
    _errno = _library.lookupFunction<_ErrnoNative, _ErrnoDart>(errnoSymbol);
  }

  static const _eintr = 4;
  static const _oReadWrite = 2;
  static const _fFullFsync = 51;

  final DynamicLibrary _library;
  final bool _isApple;
  late final _OpenDart _open;
  late final _FdCallDart _fsync;
  late final _FdCallDart _close;
  late final _FcntlDart _fcntl;
  late final _ChmodDart _chmod;
  late final _ErrnoDart _errno;

  int get _oDirectory => _isApple ? 0x00100000 : 0x00010000;
  int get _oNoFollow => _isApple ? 0x00000100 : 0x00020000;
  int get _oCloseOnExec => _isApple ? 0x01000000 : 0x00080000;
  int get _lastError => _errno().value;

  @override
  Future<void> restrictFile(File file) =>
      _restrictPath(file, expectedType: FileSystemEntityType.file, mode: 0x180);

  @override
  Future<void> restrictDirectory(Directory directory) => _restrictPath(
    directory,
    expectedType: FileSystemEntityType.directory,
    mode: 0x1c0,
  );

  Future<void> _restrictPath(
    FileSystemEntity entity, {
    required FileSystemEntityType expectedType,
    required int mode,
  }) async {
    if (await FileSystemEntity.type(entity.path, followLinks: false) !=
        expectedType) {
      throw FileSystemException('restore_durability_path_type', entity.path);
    }
    final nativePath = entity.absolute.path.toNativeUtf8();
    try {
      _callWithEintrRetry(
        () => _chmod(nativePath, mode),
        operation: 'chmod',
        path: entity.path,
      );
    } finally {
      malloc.free(nativePath);
    }
    final actualMode = (await entity.stat()).mode & 0x1ff;
    if (actualMode != mode) {
      throw FileSystemException(
        'restore_durability_mode:$actualMode',
        entity.path,
      );
    }
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw FileSystemException('restore_durability_file_type', file.path);
    }
    final fd = _openPath(
      file.absolute.path,
      _oReadWrite | _oNoFollow | _oCloseOnExec,
    );
    Object? operationError;
    try {
      _callWithEintrRetry(
        () => _fsync(fd),
        operation: 'fsync',
        path: file.path,
      );
      if (fullBarrier && _isApple) {
        _callWithEintrRetry(
          () => _fcntl(fd, _fFullFsync),
          operation: 'fullfsync',
          path: file.path,
        );
      }
    } catch (error) {
      operationError = error;
      rethrow;
    } finally {
      _closeDescriptor(fd, path: file.path, priorError: operationError);
    }
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw FileSystemException('restore_durability_file_changed', file.path);
    }
  }

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw FileSystemException(
        'restore_durability_directory_type',
        directory.path,
      );
    }
    final fd = _openPath(
      directory.absolute.path,
      _oDirectory | _oNoFollow | _oCloseOnExec,
    );
    Object? operationError;
    try {
      _callWithEintrRetry(
        () => _fsync(fd),
        operation: 'fsync_directory',
        path: directory.path,
      );
      if (fullBarrier && _isApple) {
        _callWithEintrRetry(
          () => _fcntl(fd, _fFullFsync),
          operation: 'fullfsync_directory',
          path: directory.path,
        );
      }
    } catch (error) {
      operationError = error;
      rethrow;
    } finally {
      _closeDescriptor(fd, path: directory.path, priorError: operationError);
    }
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    final sourcePath = source.absolute.path;
    final target = p.absolute(targetPath);
    final sourceType = await FileSystemEntity.type(
      sourcePath,
      followLinks: false,
    );
    if (sourceType != FileSystemEntityType.file &&
        sourceType != FileSystemEntityType.directory) {
      throw FileSystemException('restore_durability_source_type', sourcePath);
    }
    if (await FileSystemEntity.type(target, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException('restore_durability_target_exists', target);
    }

    if (sourceType == FileSystemEntityType.file) {
      await File(sourcePath).rename(target);
    } else {
      await Directory(sourcePath).rename(target);
    }
    await _requireRenameResult(
      sourcePath: sourcePath,
      targetPath: target,
      expectedType: sourceType,
    );
    final sourceParent = Directory(p.dirname(sourcePath));
    final targetParent = Directory(p.dirname(target));
    await syncDirectory(targetParent, fullBarrier: true);
    if (!p.equals(sourceParent.absolute.path, targetParent.absolute.path)) {
      await syncDirectory(sourceParent, fullBarrier: true);
    }
  }

  int _openPath(String path, int flags) {
    final nativePath = path.toNativeUtf8();
    try {
      while (true) {
        final fd = _open(nativePath, flags);
        if (fd >= 0) return fd;
        final error = _lastError;
        if (error != _eintr) {
          throw FileSystemException('restore_durability_open:$error', path);
        }
      }
    } finally {
      malloc.free(nativePath);
    }
  }

  void _callWithEintrRetry(
    int Function() action, {
    required String operation,
    required String path,
  }) {
    while (true) {
      if (action() == 0) return;
      final error = _lastError;
      if (error != _eintr) {
        throw FileSystemException('restore_durability_$operation:$error', path);
      }
    }
  }

  void _closeDescriptor(
    int fd, {
    required String path,
    required Object? priorError,
  }) {
    if (_close(fd) != 0 && priorError == null) {
      throw FileSystemException('restore_durability_close:$_lastError', path);
    }
  }
}

typedef _CreateFileNative =
    IntPtr Function(
      Pointer<Utf16>,
      Uint32,
      Uint32,
      Pointer<Void>,
      Uint32,
      Uint32,
      IntPtr,
    );
typedef _CreateFileDart =
    int Function(Pointer<Utf16>, int, int, Pointer<Void>, int, int, int);
typedef _HandleCallNative = Int32 Function(IntPtr);
typedef _HandleCallDart = int Function(int);
typedef _MoveFileNative =
    Int32 Function(Pointer<Utf16>, Pointer<Utf16>, Uint32);
typedef _MoveFileDart = int Function(Pointer<Utf16>, Pointer<Utf16>, int);
typedef _GetLastErrorNative = Uint32 Function();
typedef _GetLastErrorDart = int Function();

final class _WindowsRestoreDurability implements RestoreDurability {
  _WindowsRestoreDurability() : _library = DynamicLibrary.open('kernel32.dll') {
    _createFile = _library.lookupFunction<_CreateFileNative, _CreateFileDart>(
      'CreateFileW',
    );
    _flushFileBuffers = _library
        .lookupFunction<_HandleCallNative, _HandleCallDart>('FlushFileBuffers');
    _closeHandle = _library.lookupFunction<_HandleCallNative, _HandleCallDart>(
      'CloseHandle',
    );
    _moveFileEx = _library.lookupFunction<_MoveFileNative, _MoveFileDart>(
      'MoveFileExW',
    );
    _getLastError = _library
        .lookupFunction<_GetLastErrorNative, _GetLastErrorDart>('GetLastError');
  }

  static const _invalidHandleValue = -1;
  static const _genericWrite = 0x40000000;
  static const _shareReadWriteDelete = 0x00000007;
  static const _openExisting = 3;
  static const _fileAttributeNormal = 0x00000080;
  static const _fileFlagBackupSemantics = 0x02000000;
  static const _fileFlagOpenReparsePoint = 0x00200000;
  static const _moveFileWriteThrough = 0x00000008;

  final DynamicLibrary _library;
  late final _CreateFileDart _createFile;
  late final _HandleCallDart _flushFileBuffers;
  late final _HandleCallDart _closeHandle;
  late final _MoveFileDart _moveFileEx;
  late final _GetLastErrorDart _getLastError;

  @override
  Future<void> restrictFile(File file) =>
      _requirePathType(file, FileSystemEntityType.file);

  @override
  Future<void> restrictDirectory(Directory directory) =>
      _requirePathType(directory, FileSystemEntityType.directory);

  static Future<void> _requirePathType(
    FileSystemEntity entity,
    FileSystemEntityType expected,
  ) async {
    if (await FileSystemEntity.type(entity.path, followLinks: false) !=
        expected) {
      throw FileSystemException('restore_durability_path_type', entity.path);
    }
    // Files under Windows Application Support inherit its user ACL. Explicit
    // chmod-style mode changes do not exist; the write-through operations
    // below preserve that inherited security boundary.
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {
    await _syncPath(file, directory: false);
  }

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {
    // Windows has no separate Apple-style F_FULLFSYNC primitive. Keep using
    // the existing FlushFileBuffers path; its directory behavior remains a
    // platform acceptance boundary until exercised on supported filesystems.
    await _syncPath(directory, directory: true);
  }

  Future<void> _syncPath(
    FileSystemEntity entity, {
    required bool directory,
  }) async {
    final expectedType = directory
        ? FileSystemEntityType.directory
        : FileSystemEntityType.file;
    if (await FileSystemEntity.type(entity.path, followLinks: false) !=
        expectedType) {
      throw FileSystemException('restore_durability_path_type', entity.path);
    }
    final nativePath = entity.absolute.path.toNativeUtf16();
    late final int handle;
    var openError = 0;
    try {
      handle = _createFile(
        nativePath,
        _genericWrite,
        _shareReadWriteDelete,
        nullptr,
        _openExisting,
        _fileFlagOpenReparsePoint |
            (directory ? _fileFlagBackupSemantics : _fileAttributeNormal),
        0,
      );
      if (handle == _invalidHandleValue) openError = _getLastError();
    } finally {
      malloc.free(nativePath);
    }
    if (handle == _invalidHandleValue) {
      throw FileSystemException(
        'restore_durability_open:$openError',
        entity.path,
      );
    }
    Object? operationError;
    try {
      if (_flushFileBuffers(handle) == 0) {
        throw FileSystemException(
          'restore_durability_flush:${_getLastError()}',
          entity.path,
        );
      }
    } catch (error) {
      operationError = error;
      rethrow;
    } finally {
      if (_closeHandle(handle) == 0 && operationError == null) {
        throw FileSystemException(
          'restore_durability_close:${_getLastError()}',
          entity.path,
        );
      }
    }
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    final sourcePath = source.absolute.path;
    final target = p.absolute(targetPath);
    final sourceType = await FileSystemEntity.type(
      sourcePath,
      followLinks: false,
    );
    if (sourceType != FileSystemEntityType.file &&
        sourceType != FileSystemEntityType.directory) {
      throw FileSystemException('restore_durability_source_type', sourcePath);
    }
    if (await FileSystemEntity.type(target, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException('restore_durability_target_exists', target);
    }
    final nativeSource = sourcePath.toNativeUtf16();
    final nativeTarget = target.toNativeUtf16();
    try {
      // MOVEFILE_WRITE_THROUGH is the only durability primitive used here.
      // Same-volume rename and directory metadata remain Windows acceptance
      // boundaries until exercised on every supported filesystem.
      if (_moveFileEx(nativeSource, nativeTarget, _moveFileWriteThrough) == 0) {
        throw FileSystemException(
          'restore_durability_rename:${_getLastError()}:$target',
          sourcePath,
        );
      }
    } finally {
      malloc.free(nativeSource);
      malloc.free(nativeTarget);
    }
    await _requireRenameResult(
      sourcePath: sourcePath,
      targetPath: target,
      expectedType: sourceType,
    );
  }
}

Future<void> _requireRenameResult({
  required String sourcePath,
  required String targetPath,
  required FileSystemEntityType expectedType,
}) async {
  if (await FileSystemEntity.type(sourcePath, followLinks: false) !=
          FileSystemEntityType.notFound ||
      await FileSystemEntity.type(targetPath, followLinks: false) !=
          expectedType) {
    throw FileSystemException(
      'restore_durability_rename_result:$targetPath',
      sourcePath,
    );
  }
}
