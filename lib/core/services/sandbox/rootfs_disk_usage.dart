import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:Kelivo/utils/app_directories.dart';

/// Bytes and file count from a recursive directory walk.
typedef DirectoryUsage = ({int bytes, int fileCount});

/// Recursively sums file sizes under [dir], including `meta.db`.
///
/// Runs on a background isolate with synchronous listing so a full Ubuntu
/// rootfs (~100k entries) does not stall the UI isolate. Symlinks are not
/// followed. Unreadable entries are skipped. Missing directories are 0.
Future<int> measureDirectorySize(Directory dir) async {
  return (await measureDirectoryUsage(dir)).bytes;
}

/// Same isolate walk as [measureDirectorySize], also returning file count.
Future<DirectoryUsage> measureDirectoryUsage(Directory dir) async {
  final path = dir.path;
  if (path.isEmpty || !await dir.exists()) return (bytes: 0, fileCount: 0);
  return Isolate.run(() => measureDirectoryUsageSync(path));
}

/// Synchronous walk used by [measureDirectorySize] (and tests).
int measureDirectorySizeSync(String path) {
  return measureDirectoryUsageSync(path).bytes;
}

/// Synchronous walk used by [measureDirectoryUsage] (and tests).
DirectoryUsage measureDirectoryUsageSync(String path) {
  final root = Directory(path);
  if (!root.existsSync()) return (bytes: 0, fileCount: 0);
  var total = 0;
  var fileCount = 0;
  final queue = <String>[path];
  while (queue.isNotEmpty) {
    final current = queue.removeLast();
    final List<FileSystemEntity> entries;
    try {
      entries = Directory(current).listSync(followLinks: false);
    } catch (_) {
      continue;
    }
    for (final entity in entries) {
      if (entity is Directory) {
        queue.add(entity.path);
      } else if (entity is File) {
        try {
          total += entity.statSync().size;
          fileCount += 1;
        } catch (_) {}
      }
    }
  }
  return (bytes: total, fileCount: fileCount);
}

/// iOS fakefs install root: Application Support/environment/alpine-rootfs
/// (`RootfsInstaller.rootfsDir`).
Future<Directory> iosAlpineRootfsDir() async {
  final support = await getApplicationSupportDirectory();
  return Directory(p.join(support.path, 'environment', 'alpine-rootfs'));
}

/// Directory that actually holds the extracted / fakefs rootfs.
///
/// iOS always measures Application Support `environment/alpine-rootfs`
/// (`RootfsInstaller.rootfsDir` / [iosAlpineRootfsDir]). [rootfsDir] from
/// [EnvironmentState] is often a Documents-style or guest path that is empty
/// to a host walk. Android uses [rootfsDir] when set, otherwise
/// Documents/environment/rootfs.
Future<Directory> resolveRootfsUsageDir({
  String? rootfsDir,
  TargetPlatform? platform,
  Future<Directory> Function()? iosAlpineRootfsDirOverride,
}) async {
  final target = platform ?? defaultTargetPlatform;
  if (!kIsWeb && target == TargetPlatform.iOS) {
    return (iosAlpineRootfsDirOverride ?? iosAlpineRootfsDir)();
  }
  if (rootfsDir != null && rootfsDir.isNotEmpty) {
    return Directory(rootfsDir);
  }
  final envDir = await AppDirectories.getEnvironmentDirectory();
  return Directory(p.join(envDir.path, 'rootfs'));
}
