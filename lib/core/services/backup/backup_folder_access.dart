import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../utils/app_directories.dart';
import 'backup_staging.dart';

enum BackupFolderError implements Exception {
  invalid,
  unavailable,
  permission,
  full,
  bookmark,
}

typedef BackupFolder = ({String path, String bookmark});

class BackupFolderAccess {
  const BackupFolderAccess();
  static const _channel = MethodChannel('kelivo/backup_folder');
  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  Future<BackupFolder?> choose() async {
    if (!isDesktop) throw BackupFolderError.unavailable;
    if (Platform.isMacOS) {
      final Map<String, String>? map;
      try {
        map = await _channel.invokeMapMethod<String, String>('choose');
      } on PlatformException {
        throw BackupFolderError.bookmark;
      }
      if (map == null) return null;
      return (path: map['path']!, bookmark: map['bookmark']!);
    }
    final path = await FilePicker.platform.getDirectoryPath();
    return path == null ? null : (path: p.absolute(path), bookmark: '');
  }

  Future<void> validate(Directory directory) async {
    if (!p.isAbsolute(directory.path) || !await directory.exists()) {
      throw BackupFolderError.unavailable;
    }
    final path = await directory.resolveSymbolicLinks();
    for (final root in [
      await AppDirectories.getAppDataDirectory(),
      await AppDirectories.getContentDirectory(),
      await BackupStaging.root(),
    ]) {
      final protected = await root.resolveSymbolicLinks();
      if (p.equals(protected, path) || p.isWithin(protected, path)) {
        throw BackupFolderError.invalid;
      }
    }
  }

  Future<T> access<T>(
    BackupFolder folder, {
    required Future<void> Function(String) refresh,
    required Future<T> Function(Directory) run,
  }) async {
    if (!isDesktop) throw BackupFolderError.unavailable;
    String? lease;
    try {
      var path = folder.path;
      if (Platform.isMacOS) {
        final map = await _channel.invokeMapMethod<String, String>(
          'start',
          folder.bookmark,
        );
        if (map == null) throw BackupFolderError.bookmark;
        lease = map['lease'];
        path = map['path']!;
        if (!p.equals(path, folder.path)) throw BackupFolderError.unavailable;
        if (map['bookmark'] case final String updated) await refresh(updated);
      }
      final directory = Directory(path);
      await validate(directory);
      return await run(directory);
    } on PlatformException {
      throw BackupFolderError.bookmark;
    } on FileSystemException catch (e) {
      throw classifyBackupFolderError(e);
    } finally {
      if (lease != null) await _channel.invokeMethod<void>('stop', lease);
    }
  }
}

BackupFolderError classifyBackupFolderError(FileSystemException error) {
  final code = error.osError?.errorCode;
  if (Platform.isWindows) {
    if (code == 112 || code == 39) return BackupFolderError.full;
    if (code == 5 || code == 32) return BackupFolderError.permission;
  } else {
    if (code == 28 || code == 122 || (Platform.isMacOS && code == 69)) {
      return BackupFolderError.full;
    }
    if (code == 1 || code == 13 || code == 30) {
      return BackupFolderError.permission;
    }
  }
  return BackupFolderError.unavailable;
}
