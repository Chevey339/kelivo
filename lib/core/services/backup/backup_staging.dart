import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../utils/app_directories.dart';
import 'restore_durability.dart';

/// Working files only. User exports and published snapshots live elsewhere.
abstract final class BackupStaging {
  static const directoryName = 'kelivo_backup_staging';
  static final _live = <String>{};
  static final _legacySwept = <String>{};

  static void register(String path) => _live.add(p.normalize(p.absolute(path)));
  static void release(String path) =>
      _live.remove(p.normalize(p.absolute(path)));

  static bool _inUse(String path) => _live.any(
    (live) =>
        p.equals(live, path) ||
        p.isWithin(path, live) ||
        p.isWithin(live, path),
  );

  // Linux and Windows return a shared system temp directory. A working ZIP
  // may still be plaintext, so keep desktop staging in the owning data root.
  static Future<Directory> _parent() => Platform.isLinux || Platform.isWindows
      ? AppDirectories.getAppDataDirectory()
      : getTemporaryDirectory();

  static Future<Directory> root({Directory? temporary}) async {
    final dir = Directory(
      p.join((temporary ?? await _parent()).path, directoryName),
    );
    if (await FileSystemEntity.type(dir.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw FileSystemException('Invalid backup staging directory', dir.path);
    }
    await dir.create(recursive: true);
    if (!Platform.isWindows && (await dir.stat()).mode & 0x1ff != 0x1c0) {
      await RestorePlatformDurability().restrictDirectory(dir);
    }
    return dir;
  }

  static Future<Directory> createDirectory(String name) async {
    final dir = Directory(p.join((await root()).path, name));
    register(dir.path);
    try {
      return await dir.create();
    } catch (_) {
      release(dir.path);
      rethrow;
    }
  }

  static Future<File> createDownload() async {
    final file = File(
      p.join((await root()).path, 'kelivo_restore_${const Uuid().v4()}.zip'),
    );
    register(file.path);
    try {
      return await file.create(exclusive: true);
    } catch (_) {
      release(file.path);
      rethrow;
    }
  }

  static bool _legacy(FileSystemEntity entry, String name) {
    if (name == directoryName) return false;
    if (entry is Directory) {
      return name.startsWith('kelivo_backup_') ||
          name.startsWith('kelivo_decrypted_');
    }
    return entry is File &&
        (RegExp(r'^kelivo_backup_.+\.(zip|kbackup)$').hasMatch(name) ||
            RegExp(r'^kelivo_restore_.+\.zip$').hasMatch(name) ||
            const {
              '_bk_settings.json',
              '_bk_manifest.json',
              '_bk_kelivo.db',
              '_bk_chats.json',
            }.contains(name));
  }

  static Future<void> sweep({Directory? temporary}) async {
    final parent = temporary ?? await _parent();
    final staging = await root(temporary: parent);
    Future<void> clean(Directory dir, {required bool legacy}) async {
      await for (final entry in dir.list(followLinks: false)) {
        if (legacy && !_legacy(entry, p.basename(entry.path))) continue;
        if (_inUse(p.normalize(p.absolute(entry.path)))) continue;
        try {
          await entry.delete(recursive: entry is Directory);
        } on FileSystemException {
          // A concurrent sweep or an unavailable file can wait for the next run.
        }
      }
    }

    // A shared system temp directory has no per-installation ownership proof
    // for legacy files. Reclaim old names only in private app cache roots.
    final privateLegacyRoot =
        temporary != null ||
        Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS;
    if (privateLegacyRoot && _legacySwept.add(parent.path)) {
      try {
        await clean(parent, legacy: true);
      } on FileSystemException {
        _legacySwept.remove(parent.path);
      }
    }
    await clean(staging, legacy: false);
  }
}
