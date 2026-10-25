import 'dart:io';
import '../../database/database_family_preserver.dart';
import 'dart:convert';
import 'dart:isolate';
import 'package:archive/archive_io.dart';

import 'package:path/path.dart' as p;

import '../../../utils/app_directories.dart';

/// Finds retained data without moving, opening or deleting any candidate.
/// Restrict traversal to data roots and snapshot folders, never user workspaces.
abstract final class RecoveryFileDiscovery {
  static const _databaseSidecars = ['-wal', '-shm', '-journal'];
  static bool isSnapshotDirectory(String name) => RegExp(
    r'^snapshots(?:[ _-][0-9]+| \([0-9]+\))?$',
    caseSensitive: false,
  ).hasMatch(name);

  static bool isSnapshotArchive(String name) => RegExp(
    r'^(?:kelivo-snapshot-|kelivo_backup_).+\.zip$',
    caseSensitive: false,
  ).hasMatch(name);

  static bool isDatabaseCopy(String name) =>
      !_databaseSidecars.any(name.endsWith) &&
      RegExp(
        r'^kelivo(?:[ _-][0-9]+| \([0-9]+\))?\.db(?:\.displaced-[^/]+|\.premigrate-[^/]+|\.previous)?$',
        caseSensitive: false,
      ).hasMatch(name);

  static bool isDatabaseFamilyFile(String name) =>
      isDatabaseCopy(name) ||
      _databaseSidecars.any(
        (suffix) =>
            name.endsWith(suffix) &&
            isDatabaseCopy(name.substring(0, name.length - suffix.length)),
      );

  static Future<List<Directory>> roots(
    Directory root, {
    List<Directory> additionalRoots = const [],
  }) async {
    final legacy = await AppDirectories.documentsDirectoryFor(root);
    final paths = <String>{};
    final result = <Directory>[];
    for (final directory in [
      root,
      if (legacy != null) legacy,
      ...additionalRoots,
    ]) {
      if (!paths.add(p.normalize(directory.absolute.path))) continue;
      final type = await FileSystemEntity.type(
        directory.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.directory) {
        throw StateError('recovery_directory_type');
      }
      result.add(directory);
    }
    return result;
  }

  static Future<List<File>> archives(
    Directory root, {
    void Function(Object)? onError,
    List<Directory> additionalRoots = const [],
  }) async {
    final files = <File>[];
    for (final directory in await roots(
      root,
      additionalRoots: additionalRoots,
    )) {
      if (!await directory.exists()) continue;
      await for (final entry in _children(directory, onError)) {
        if (entry is File && isSnapshotArchive(p.basename(entry.path))) {
          files.add(entry);
        } else if (entry is Directory &&
            isSnapshotDirectory(p.basename(entry.path))) {
          await for (final child in _children(entry, onError)) {
            if (child is File && isSnapshotArchive(p.basename(child.path))) {
              files.add(child);
            }
          }
        }
      }
    }
    return files;
  }

  static Future<List<File>> databases(
    Directory root, {
    bool includeActiveDatabase = false,
    void Function(Object)? onError,
    List<Directory> additionalRoots = const [],
  }) async {
    final files = <File>[];
    for (final directory in await roots(
      root,
      additionalRoots: additionalRoots,
    )) {
      if (!await directory.exists()) continue;
      await for (final entry in _children(directory, onError)) {
        if (entry is Directory &&
            DatabaseFamilyPreserver.isCopyDirectory(p.basename(entry.path))) {
          final database = File(p.join(entry.path, 'kelivo.db'));
          if (await FileSystemEntity.type(database.path, followLinks: false) ==
              FileSystemEntityType.file) {
            files.add(database);
          }
          continue;
        }
        if (entry is! File || !isDatabaseCopy(p.basename(entry.path))) continue;
        if (!includeActiveDatabase &&
            p.equals(entry.path, p.join(root.path, 'kelivo.db'))) {
          continue;
        }
        files.add(entry);
      }
    }
    return files;
  }

  static Stream<FileSystemEntity> _children(
    Directory directory,
    void Function(Object)? onError,
  ) async* {
    try {
      yield* directory.list(followLinks: false);
    } catch (error) {
      onError?.call(error);
    }
  }

  /// A lightweight hint for an empty live database. Full integrity validation
  /// still runs on the recovery screen; sidecar counts are never authoritative.
  static Future<bool?> archiveHasChats(File file) => Isolate.run(() async {
    InputFileStream? input;
    try {
      input = InputFileStream(file.path);
      final archive = ZipDecoder().decodeStream(input);
      final entry = archive.findFile('manifest.json');
      if (entry == null || !entry.isFile || entry.size > 16 * 1024 * 1024) {
        return null;
      }
      final value = jsonDecode(utf8.decode(entry.readBytes()!));
      if (value is! Map ||
          value['format'] != 'kelivo-backup' ||
          value['database'] is! Map) {
        return null;
      }
      final counts = value['database'] as Map;
      final conversations = counts['conversationCount'];
      final messages = counts['messageCount'];
      if (conversations is! int ||
          conversations < 0 ||
          messages is! int ||
          messages < 0) {
        return null;
      }
      return conversations > 0 || messages > 0;
    } catch (_) {
      return null;
    } finally {
      await input?.close();
    }
  });

  /// Also blocks a new installation when evidence cannot be read. File names
  /// are evidence of previous use, not proof that a backup is safe to restore.
  static Future<bool> hasPriorData(Directory root) async {
    try {
      for (final directory in await roots(root)) {
        if (!await directory.exists()) continue;
        await for (final entry in directory.list(followLinks: false)) {
          final name = p.basename(entry.path);
          if (entry is File &&
              (isDatabaseFamilyFile(name) ||
                  name.startsWith('kelivo.db-') ||
                  name == DatabaseFamilyPreserver.pendingName ||
                  isSnapshotArchive(name) ||
                  name.startsWith('database_installation_receipt_') ||
                  name.startsWith('.kelivo_database_history') ||
                  name.endsWith('.hive') ||
                  name.startsWith('kelivo_backup_'))) {
            return true;
          }
          if (entry is Directory &&
              (isSnapshotDirectory(name) ||
                  DatabaseFamilyPreserver.isCopyDirectory(name) ||
                  name.startsWith('.kelivo-database-copy-') ||
                  const {
                    'images',
                    'upload',
                    'avatars',
                    'fonts',
                    'drafts',
                    'workspaces',
                    'sessions',
                  }.contains(name) ||
                  name.startsWith('.kelivo_restore') ||
                  name.startsWith('.kelivo_retained_receipts'))) {
            if (!await entry.list(followLinks: false).isEmpty) {
              return true;
            }
          }
        }
      }
      return false;
    } catch (_) {
      return true;
    }
  }
}
