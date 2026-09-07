import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../database/app_database.dart';
import '../../database/database_installation_gate.dart';
import '../hive_migration_marker.dart';
import '../legacy_data_retirement_service.dart';
import '../backup/local_snapshot_schedule.dart';
import '../backup/restore_trace_service.dart';
import '../../../utils/app_directories.dart';
import '../../../utils/avatar_cache.dart';
import '../logging/flutter_logger.dart';
import '../network/request_logger.dart';
import '../sandbox/rootfs_disk_usage.dart';
import '../workspace/workspace_session_sync.dart';

enum StorageUsageCategoryKey {
  images,
  files,
  chatData,
  legacyChatData,
  restoreTraces,
  displacedDatabases,
  localSnapshots,
  assistantData,
  cache,
  logs,
  other,
  workspaceFiles,
  sandboxEnvironment,
  skills,
  sessionFiles,
}

class StorageUsageStats {
  final int fileCount;
  final int bytes;
  const StorageUsageStats({required this.fileCount, required this.bytes});

  StorageUsageStats operator +(StorageUsageStats other) {
    return StorageUsageStats(
      fileCount: fileCount + other.fileCount,
      bytes: bytes + other.bytes,
    );
  }
}

class StorageUsageSubcategory {
  final String id;
  final StorageUsageStats stats;
  final String? path;
  final bool isDirectory;
  const StorageUsageSubcategory({
    required this.id,
    required this.stats,
    this.path,
    this.isDirectory = false,
  });
}

class StorageUsageCategory {
  final StorageUsageCategoryKey key;
  final StorageUsageStats stats;
  final List<StorageUsageSubcategory> subcategories;
  const StorageUsageCategory({
    required this.key,
    required this.stats,
    this.subcategories = const <StorageUsageSubcategory>[],
  });
}

class StorageUsageReport {
  final int totalBytes;
  final int totalFiles;
  final StorageUsageStats clearable;
  final List<StorageUsageCategory> categories;
  const StorageUsageReport({
    required this.totalBytes,
    required this.totalFiles,
    required this.clearable,
    required this.categories,
  });
}

enum StorageFileSource { userUpload, assistant }

class StorageFileEntry {
  final String path;
  final String name;
  final int bytes;
  final DateTime modifiedAt;
  final StorageFileSource source;
  const StorageFileEntry({
    required this.path,
    required this.name,
    required this.bytes,
    required this.modifiedAt,
    required this.source,
  });
}

/// Name of the append-only record written before an unattended database
/// rebuild. Lives in `logs/` so the in-app viewer can surface it, but is
/// deliberately exempt from "clear logs".
const String startupRecoveryLogFileName = 'startup-recovery.log';

abstract final class StorageUsageService {
  StorageUsageService._();

  static bool _isImageExt(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.ico');
  }

  static String? _chatDatabaseSubcategoryId(String name) {
    switch (name.toLowerCase()) {
      case AppDatabase.databaseFileName:
        return 'sqlite_database';
      case '${AppDatabase.databaseFileName}-wal':
        return 'sqlite_wal';
      case '${AppDatabase.databaseFileName}-shm':
        return 'sqlite_shm';
      default:
        return null;
    }
  }

  static const _displacedDatabasePrefix =
      '${AppDatabase.databaseFileName}'
      '${DatabaseInstallationGate.displacedDatabasePrefix}';

  static String _chatDatabaseFileName(String subcategoryId) {
    switch (subcategoryId) {
      case 'sqlite_wal':
        return '${AppDatabase.databaseFileName}-wal';
      case 'sqlite_shm':
        return '${AppDatabase.databaseFileName}-shm';
      case 'sqlite_database':
      default:
        return AppDatabase.databaseFileName;
    }
  }

  static Future<StorageUsageReport> computeReport({
    Future<Directory> Function()? workspacesDirectory,
    Future<Directory> Function()? environmentDirectory,
    Future<Directory> Function()? skillsDirectory,
    Future<Directory> Function()? sessionsDirectory,
    Future<Directory> Function()? rootfsUsageDirectory,
  }) async {
    final root = await AppDirectories.getAppDataDirectory();
    var migrationCompleted = false;
    try {
      migrationCompleted = HiveMigrationMarker.isMigrationComplete(
        File(p.join(root.path, AppDatabase.databaseFileName)),
      );
    } catch (_) {
      // An unreadable database must not make legacy files clearable.
    }
    var restoreTraces = RestoreTraceSnapshot.empty;
    try {
      restoreTraces = await RestoreTraceService(root).inspect();
    } catch (_) {
      // Malformed or active restore workspaces stay hidden and non-clearable.
    }

    final byCat = <StorageUsageCategoryKey, _MutableStats>{
      for (final k in StorageUsageCategoryKey.values) k: _MutableStats(),
    };

    final chatSubs = <String, _MutableStats>{
      'sqlite_database': _MutableStats(),
      'sqlite_wal': _MutableStats(),
      'sqlite_shm': _MutableStats(),
    };
    final legacyChatSubs = <String, _MutableStats>{
      for (final name in LegacyDataRetirementService.hiveArtifactNames)
        name: _MutableStats(),
    };

    final assistantSubs = <String, _MutableStats>{'avatars': _MutableStats()};
    final otherSubs = <String, _MutableStats>{
      'fonts': _MutableStats(),
      'local_models': _MutableStats(),
      'app': _MutableStats(),
    };

    final cacheSubs = <String, _MutableStats>{
      'avatar_cache': _MutableStats(),
      'other_cache': _MutableStats(),
      'system_cache': _MutableStats(),
    };

    final logsSubs = <String, _MutableStats>{
      'context_logs': _MutableStats(),
      'request_logs': _MutableStats(),
      'flutter_logs': _MutableStats(),
      'other_logs': _MutableStats(),
    };

    int totalBytes = 0;
    int totalFiles = 0;

    if (!await root.exists()) {
      return StorageUsageReport(
        totalBytes: 0,
        totalFiles: 0,
        clearable: const StorageUsageStats(fileCount: 0, bytes: 0),
        categories: [
          for (final k in _categoryOrder)
            if (_isAlwaysVisibleCategory(k))
              StorageUsageCategory(
                key: k,
                stats: const StorageUsageStats(fileCount: 0, bytes: 0),
              ),
        ],
      );
    }

    try {
      await for (final ent in _listFiles(
        root,
        excludedTopDirectories: _isolateMeasuredTopDirs,
      )) {
        final rel = p.relative(ent.path, from: root.path);
        final parts = p.split(rel);
        int bytes = 0;
        try {
          bytes = await ent.length();
        } catch (_) {
          bytes = 0;
        }
        totalFiles += 1;
        totalBytes += bytes;

        if (parts.isEmpty) {
          byCat[StorageUsageCategoryKey.other]!.add(bytes);
          otherSubs['app']!.add(bytes);
          continue;
        }

        // Root-level chat data is stored by Drift in the SQLite database file
        // family. Legacy Hive boxes are migration inputs only and should not
        // affect the steady-state chat records size.
        if (parts.length == 1) {
          final name = parts.first;
          final chatSubId = _chatDatabaseSubcategoryId(name);
          if (name.startsWith(_displacedDatabasePrefix)) {
            byCat[StorageUsageCategoryKey.displacedDatabases]!.add(bytes);
          } else if (chatSubId != null) {
            byCat[StorageUsageCategoryKey.chatData]!.add(bytes);
            chatSubs[chatSubId]!.add(bytes);
          } else if (migrationCompleted &&
              LegacyDataRetirementService.hiveArtifactNames.contains(name)) {
            byCat[StorageUsageCategoryKey.legacyChatData]!.add(bytes);
            legacyChatSubs[name]!.add(bytes);
          } else {
            byCat[StorageUsageCategoryKey.other]!.add(bytes);
            otherSubs['app']!.add(bytes);
          }
          continue;
        }

        final top = parts.first.toLowerCase();
        if (restoreTraces.visible &&
            top == '.kelivo_restore' &&
            parts.length >= 4 &&
            parts[1] == 'completed' &&
            RegExp(r'^run_[a-f0-9]{32}$').hasMatch(parts[2])) {
          byCat[StorageUsageCategoryKey.restoreTraces]!.add(bytes);
          continue;
        }
        switch (top) {
          case LocalSnapshotPaths.directoryName:
            byCat[StorageUsageCategoryKey.localSnapshots]!.add(bytes);
            break;
          case 'upload':
          case 'images':
            final name = parts.last;
            if (_isImageExt(name)) {
              byCat[StorageUsageCategoryKey.images]!.add(bytes);
            } else {
              byCat[StorageUsageCategoryKey.files]!.add(bytes);
            }
            break;
          case 'avatars':
            byCat[StorageUsageCategoryKey.assistantData]!.add(bytes);
            assistantSubs['avatars']!.add(bytes);
            break;
          case 'fonts':
            byCat[StorageUsageCategoryKey.other]!.add(bytes);
            otherSubs['fonts']!.add(bytes);
            break;
          case 'asr_models':
            byCat[StorageUsageCategoryKey.other]!.add(bytes);
            otherSubs['local_models']!.add(bytes);
            break;
          case 'cache':
            byCat[StorageUsageCategoryKey.cache]!.add(bytes);
            if (parts.length >= 2 && parts[1].toLowerCase() == 'avatars') {
              cacheSubs['avatar_cache']!.add(bytes);
            } else {
              cacheSubs['other_cache']!.add(bytes);
            }
            break;
          case 'logs':
            byCat[StorageUsageCategoryKey.logs]!.add(bytes);
            final name = parts.last.toLowerCase();
            if (name.startsWith('context_logs')) {
              logsSubs['context_logs']!.add(bytes);
            } else if (name.startsWith('flutter_logs')) {
              logsSubs['flutter_logs']!.add(bytes);
            } else if (name.startsWith('logs')) {
              logsSubs['request_logs']!.add(bytes);
            } else {
              logsSubs['other_logs']!.add(bytes);
            }
            break;
          default:
            byCat[StorageUsageCategoryKey.other]!.add(bytes);
            otherSubs['app']!.add(bytes);
            break;
        }
      }
    } catch (_) {
      // Keep successfully measured files if a file disappears during the scan.
    }

    final [
      workspaceUsage,
      skillsUsage,
      sessionsUsage,
      sandboxUsage,
    ] = await Future.wait([
      _measureContentsOf(
        workspacesDirectory ?? AppDirectories.getWorkspacesDirectory,
      ),
      _measureContentsOf(skillsDirectory ?? AppDirectories.getSkillsDirectory),
      _measureContentsOf(
        sessionsDirectory ?? AppDirectories.getSessionsDirectory,
      ),
      _measureSandboxEnvironment(
        environmentDirectory:
            environmentDirectory ?? AppDirectories.getEnvironmentDirectory,
        rootfsUsageDirectory: rootfsUsageDirectory,
      ),
    ]);
    byCat[StorageUsageCategoryKey.workspaceFiles]!.addStats(
      workspaceUsage.stats,
    );
    byCat[StorageUsageCategoryKey.skills]!.addStats(skillsUsage.stats);
    byCat[StorageUsageCategoryKey.sessionFiles]!.addStats(sessionsUsage.stats);
    byCat[StorageUsageCategoryKey.sandboxEnvironment]!.addStats(
      sandboxUsage.stats,
    );
    totalFiles +=
        workspaceUsage.stats.fileCount +
        skillsUsage.stats.fileCount +
        sessionsUsage.stats.fileCount +
        sandboxUsage.stats.fileCount;
    totalBytes +=
        workspaceUsage.stats.bytes +
        skillsUsage.stats.bytes +
        sessionsUsage.stats.bytes +
        sandboxUsage.stats.bytes;

    final avatarsDir = await AppDirectories.getAvatarsDirectory();
    final fontsDir = await AppDirectories.getFontsDirectory();
    final localModelsDir = Directory(p.join(root.path, 'asr_models'));
    final cacheDir = await AppDirectories.getCacheDirectory();
    final systemCacheDir = await AppDirectories.getSystemCacheDirectory();
    final avatarCacheDir = await AppDirectories.getAvatarCacheDirectory();
    final logsDir = Directory(p.join(root.path, 'logs'));

    // Platform cache directory (e.g. Android /data/user/0/<package>/cache).
    try {
      if (await systemCacheDir.exists()) {
        await for (final ent in systemCacheDir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (ent is! File) continue;
          int bytes = 0;
          try {
            bytes = await ent.length();
          } catch (_) {
            bytes = 0;
          }
          totalFiles += 1;
          totalBytes += bytes;
          byCat[StorageUsageCategoryKey.cache]!.add(bytes);
          cacheSubs['system_cache']!.add(bytes);
        }
      }
    } catch (_) {}

    // Displaced database copies are deliberately absent here. This total is
    // the "space you can reclaim" prompt, and a displaced copy can be the only
    // surviving version of the user's data — inviting a one-tap sweep of it is
    // the opposite of why it was kept. It stays clearable from its own row,
    // where the confirmation says what it is.
    final clearable = StorageUsageStats(
      fileCount:
          byCat[StorageUsageCategoryKey.cache]!.fileCount +
          byCat[StorageUsageCategoryKey.logs]!.fileCount +
          byCat[StorageUsageCategoryKey.legacyChatData]!.fileCount +
          byCat[StorageUsageCategoryKey.restoreTraces]!.fileCount,
      bytes:
          byCat[StorageUsageCategoryKey.cache]!.bytes +
          byCat[StorageUsageCategoryKey.logs]!.bytes +
          byCat[StorageUsageCategoryKey.legacyChatData]!.bytes +
          byCat[StorageUsageCategoryKey.restoreTraces]!.bytes,
    );

    final categories = <StorageUsageCategory>[
      StorageUsageCategory(
        key: StorageUsageCategoryKey.images,
        stats: byCat[StorageUsageCategoryKey.images]!.toStats(),
      ),
      StorageUsageCategory(
        key: StorageUsageCategoryKey.files,
        stats: byCat[StorageUsageCategoryKey.files]!.toStats(),
      ),
      StorageUsageCategory(
        key: StorageUsageCategoryKey.chatData,
        stats: byCat[StorageUsageCategoryKey.chatData]!.toStats(),
        subcategories: [
          for (final e in chatSubs.entries)
            if (e.value.bytes > 0 || e.value.fileCount > 0)
              StorageUsageSubcategory(
                id: e.key,
                stats: e.value.toStats(),
                path: p.join(root.path, _chatDatabaseFileName(e.key)),
              ),
        ],
      ),
      if (byCat[StorageUsageCategoryKey.legacyChatData]!.fileCount > 0)
        StorageUsageCategory(
          key: StorageUsageCategoryKey.legacyChatData,
          stats: byCat[StorageUsageCategoryKey.legacyChatData]!.toStats(),
          subcategories: [
            for (final entry in legacyChatSubs.entries)
              if (entry.value.fileCount > 0)
                StorageUsageSubcategory(
                  id: entry.key,
                  stats: entry.value.toStats(),
                  path: p.join(root.path, entry.key),
                ),
          ],
        ),
      if (byCat[StorageUsageCategoryKey.restoreTraces]!.fileCount > 0)
        StorageUsageCategory(
          key: StorageUsageCategoryKey.restoreTraces,
          stats: byCat[StorageUsageCategoryKey.restoreTraces]!.toStats(),
          subcategories: [
            StorageUsageSubcategory(
              id: 'completed_restore_runs',
              stats: byCat[StorageUsageCategoryKey.restoreTraces]!.toStats(),
              path: p.join(root.path, '.kelivo_restore', 'completed'),
            ),
          ],
        ),
      if (byCat[StorageUsageCategoryKey.displacedDatabases]!.fileCount > 0)
        StorageUsageCategory(
          key: StorageUsageCategoryKey.displacedDatabases,
          stats: byCat[StorageUsageCategoryKey.displacedDatabases]!.toStats(),
          subcategories: [
            StorageUsageSubcategory(
              id: 'displaced_databases',
              stats: byCat[StorageUsageCategoryKey.displacedDatabases]!
                  .toStats(),
              path: root.path,
            ),
          ],
        ),
      if (byCat[StorageUsageCategoryKey.localSnapshots]!.fileCount > 0)
        StorageUsageCategory(
          key: StorageUsageCategoryKey.localSnapshots,
          stats: byCat[StorageUsageCategoryKey.localSnapshots]!.toStats(),
          subcategories: [
            StorageUsageSubcategory(
              id: 'local_snapshots',
              stats: byCat[StorageUsageCategoryKey.localSnapshots]!.toStats(),
              path: LocalSnapshotPaths.directoryIn(root).path,
            ),
          ],
        ),
      StorageUsageCategory(
        key: StorageUsageCategoryKey.assistantData,
        stats: byCat[StorageUsageCategoryKey.assistantData]!.toStats(),
        subcategories: [
          StorageUsageSubcategory(
            id: 'avatars',
            stats: assistantSubs['avatars']!.toStats(),
            path: avatarsDir.path,
          ),
        ],
      ),
      StorageUsageCategory(
        key: StorageUsageCategoryKey.cache,
        stats: byCat[StorageUsageCategoryKey.cache]!.toStats(),
        subcategories: [
          StorageUsageSubcategory(
            id: 'avatar_cache',
            stats: cacheSubs['avatar_cache']!.toStats(),
            path: avatarCacheDir.path,
          ),
          StorageUsageSubcategory(
            id: 'other_cache',
            stats: cacheSubs['other_cache']!.toStats(),
            path: cacheDir.path,
          ),
          if (cacheSubs['system_cache']!.bytes > 0 ||
              cacheSubs['system_cache']!.fileCount > 0)
            StorageUsageSubcategory(
              id: 'system_cache',
              stats: cacheSubs['system_cache']!.toStats(),
              path: systemCacheDir.path,
            ),
        ],
      ),
      StorageUsageCategory(
        key: StorageUsageCategoryKey.logs,
        stats: byCat[StorageUsageCategoryKey.logs]!.toStats(),
        subcategories: [
          StorageUsageSubcategory(
            id: 'context_logs',
            stats: logsSubs['context_logs']!.toStats(),
            path: logsDir.path,
          ),
          StorageUsageSubcategory(
            id: 'request_logs',
            stats: logsSubs['request_logs']!.toStats(),
            path: logsDir.path,
          ),
          StorageUsageSubcategory(
            id: 'flutter_logs',
            stats: logsSubs['flutter_logs']!.toStats(),
            path: logsDir.path,
          ),
          if (logsSubs['other_logs']!.bytes > 0 ||
              logsSubs['other_logs']!.fileCount > 0)
            StorageUsageSubcategory(
              id: 'other_logs',
              stats: logsSubs['other_logs']!.toStats(),
              path: logsDir.path,
            ),
        ],
      ),
      StorageUsageCategory(
        key: StorageUsageCategoryKey.other,
        stats: byCat[StorageUsageCategoryKey.other]!.toStats(),
        subcategories: [
          if (otherSubs['fonts']!.fileCount > 0)
            StorageUsageSubcategory(
              id: 'fonts',
              stats: otherSubs['fonts']!.toStats(),
              path: fontsDir.path,
            ),
          if (otherSubs['local_models']!.fileCount > 0)
            StorageUsageSubcategory(
              id: 'local_models',
              stats: otherSubs['local_models']!.toStats(),
              path: localModelsDir.path,
            ),
          if (otherSubs['app']!.fileCount > 0)
            StorageUsageSubcategory(
              id: 'app',
              stats: otherSubs['app']!.toStats(),
              path: root.path,
            ),
        ],
      ),
      StorageUsageCategory(
        key: StorageUsageCategoryKey.workspaceFiles,
        stats: byCat[StorageUsageCategoryKey.workspaceFiles]!.toStats(),
        subcategories: workspaceUsage.subcategories,
      ),
      StorageUsageCategory(
        key: StorageUsageCategoryKey.sandboxEnvironment,
        stats: byCat[StorageUsageCategoryKey.sandboxEnvironment]!.toStats(),
        subcategories: sandboxUsage.subcategories,
      ),
      StorageUsageCategory(
        key: StorageUsageCategoryKey.skills,
        stats: byCat[StorageUsageCategoryKey.skills]!.toStats(),
        subcategories: skillsUsage.subcategories,
      ),
      StorageUsageCategory(
        key: StorageUsageCategoryKey.sessionFiles,
        stats: byCat[StorageUsageCategoryKey.sessionFiles]!.toStats(),
        subcategories: sessionsUsage.subcategories,
      ),
    ];

    // Ensure consistent ordering.
    categories.sort(
      (a, b) => _categoryOrder
          .indexOf(a.key)
          .compareTo(_categoryOrder.indexOf(b.key)),
    );

    return StorageUsageReport(
      totalBytes: totalBytes,
      totalFiles: totalFiles,
      clearable: clearable,
      categories: categories,
    );
  }

  static Future<void> clearCache({required bool avatarsOnly}) async {
    if (avatarsOnly) {
      final dir = await AppDirectories.getAvatarCacheDirectory();
      await _deleteDirectoryContents(dir);
      AvatarCache.clearMemory();
      return;
    }
    final dir = await AppDirectories.getCacheDirectory();
    await _deleteDirectoryContents(dir);
    try {
      final sys = await AppDirectories.getSystemCacheDirectory();
      await _deleteDirectoryContents(sys);
    } catch (_) {}
    AvatarCache.clearMemory();
  }

  static Future<void> clearOtherCache() async {
    final cacheDir = await AppDirectories.getCacheDirectory();
    final avatarCacheDir = await AppDirectories.getAvatarCacheDirectory();
    if (!await cacheDir.exists()) return;

    final String avatarAbs = p.normalize(
      Directory(avatarCacheDir.path).absolute.path,
    );
    try {
      await for (final ent in cacheDir.list(
        recursive: false,
        followLinks: false,
      )) {
        try {
          final entAbs = p.normalize(p.absolute(ent.path));
          if (p.equals(entAbs, avatarAbs)) continue;
          await ent.delete(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Future<void> clearSystemCache() async {
    try {
      final dir = await AppDirectories.getSystemCacheDirectory();
      await _deleteDirectoryContents(dir);
    } catch (_) {}
  }

  static Future<void> clearLogs() async {
    final flutterOn = FlutterLogger.enabled;
    final requestOn = RequestLogger.enabled;

    try {
      if (flutterOn) await FlutterLogger.setEnabled(false);
    } catch (_) {}
    try {
      if (requestOn) await RequestLogger.setEnabled(false);
    } catch (_) {}

    try {
      final root = await AppDirectories.getAppDataDirectory();
      final logsDir = Directory(p.join(root.path, 'logs'));
      // The startup-recovery record is the only trace of an unattended rebuild
      // — the one startup outcome that destroys state without asking. Clearing
      // logs must not erase the evidence of it along with the noise.
      await _deleteDirectoryContents(
        logsDir,
        keepFileNames: const {startupRecoveryLogFileName},
      );
    } finally {
      try {
        if (flutterOn) await FlutterLogger.setEnabled(true);
      } catch (_) {}
      try {
        if (requestOn) await RequestLogger.setEnabled(true);
      } catch (_) {}
    }
  }

  static Future<void> clearLegacyChatData() async {
    final root = await AppDirectories.getAppDataDirectory();
    final databaseFile = File(p.join(root.path, AppDatabase.databaseFileName));
    if (!HiveMigrationMarker.isMigrationComplete(databaseFile)) {
      throw StateError('legacy_retirement_untracked');
    }
    await LegacyDataRetirementService(root).retireHiveArtifacts();
  }

  static Future<void> clearRestoreTraces() async {
    final root = await AppDirectories.getAppDataDirectory();
    await RestoreTraceService(root).clear();
  }

  static Future<void> clearDisplacedDatabases() async {
    final root = await AppDirectories.getAppDataDirectory();
    await DatabaseInstallationGate.clearDisplacedDatabases(
      appDataDirectory: root,
    );
  }

  static Future<List<StorageFileEntry>> listUploadEntries({
    required bool images,
  }) async {
    final dir = await AppDirectories.getUploadDirectory();
    final imagesDir = await AppDirectories.getImagesDirectory();
    final out = <StorageFileEntry>[];
    Future<void> addFromDir(
      Directory d, {
      required bool includeImages,
      required bool includeNonImages,
      required StorageFileSource source,
    }) async {
      if (!await d.exists()) return;
      try {
        await for (final ent in _listFiles(d)) {
          final name = p.basename(ent.path);
          final isImg = _isImageExt(name);
          if (isImg && !includeImages) continue;
          if (!isImg && !includeNonImages) continue;
          int bytes = 0;
          DateTime modifiedAt = DateTime.fromMillisecondsSinceEpoch(0);
          try {
            final stat = await ent.stat();
            bytes = stat.size;
            modifiedAt = stat.modified;
          } catch (_) {
            try {
              bytes = await ent.length();
            } catch (_) {}
          }
          out.add(
            StorageFileEntry(
              path: ent.path,
              name: name,
              bytes: bytes,
              modifiedAt: modifiedAt,
              source: source,
            ),
          );
        }
      } catch (_) {
        // Ignore listing errors and return partial results.
      }
    }

    // Chat attachments live under upload/. Inline/generated images live under images/.
    await addFromDir(
      dir,
      includeImages: images,
      includeNonImages: !images,
      source: StorageFileSource.userUpload,
    );
    await addFromDir(
      imagesDir,
      includeImages: images,
      includeNonImages: !images,
      source: StorageFileSource.assistant,
    );
    out.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return out;
  }

  static Future<int> deleteUploadFiles(
    Iterable<String> paths, {
    required bool images,
  }) async {
    final dir = await AppDirectories.getUploadDirectory();
    final imagesDir = await AppDirectories.getImagesDirectory();
    final roots = <String>[
      p.normalize(dir.absolute.path),
      p.normalize(imagesDir.absolute.path),
    ];
    final realRoots = await Future.wait(
      roots.map((root) async {
        try {
          return await Directory(root).resolveSymbolicLinks();
        } catch (_) {
          return root;
        }
      }),
    );
    final removedPaths = <String>{};
    for (final raw in paths) {
      try {
        final abs = p.normalize(File(raw).absolute.path);
        if (_isImageExt(abs) != images) continue;
        final allowed = roots.any((root) => p.isWithin(root, abs));
        if (!allowed) continue;
        // A symlinked child directory must not let storage cleanup escape the
        // app's upload roots. Only regular files are eligible for deletion.
        final parent = await File(abs).parent.resolveSymbolicLinks();
        if (!realRoots.any(
          (root) => p.equals(root, parent) || p.isWithin(root, parent),
        )) {
          continue;
        }
        if (await FileSystemEntity.type(abs, followLinks: false) !=
            FileSystemEntityType.file) {
          continue;
        }
        await File(abs).delete();
        removedPaths.add(abs);
      } catch (_) {}
    }
    if (removedPaths.isNotEmpty) {
      await deleteSessionAttachmentCopies(
        removedPaths,
        sessionsDirectory: await AppDirectories.getSessionsDirectory(),
      );
    }
    return removedPaths.length;
  }

  static Future<StorageUsageStats> measureOrphanSessionFiles({
    Set<String>? conversationIds,
    Future<Directory> Function()? sessionsDirectory,
  }) async {
    final ids = conversationIds ?? await _readConversationIdsFromDatabase();
    final sessions =
        await (sessionsDirectory ?? AppDirectories.getSessionsDirectory)();
    return _orphanSessionStats(sessions: sessions, conversationIds: ids);
  }

  static Future<StorageUsageStats> clearOrphanSessionFiles({
    Set<String>? conversationIds,
    Future<Directory> Function()? sessionsDirectory,
  }) async {
    final ids = conversationIds ?? await _readConversationIdsFromDatabase();
    final sessions =
        await (sessionsDirectory ?? AppDirectories.getSessionsDirectory)();
    final stats = await _orphanSessionStats(
      sessions: sessions,
      conversationIds: ids,
    );
    if (!await sessions.exists()) return stats;
    try {
      await for (final ent in sessions.list(
        recursive: false,
        followLinks: false,
      )) {
        if (ent is! Directory) continue;
        if (ids.contains(p.basename(ent.path))) continue;
        try {
          await ent.delete(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}
    return stats;
  }

  static Future<StorageUsageStats> _orphanSessionStats({
    required Directory sessions,
    required Set<String> conversationIds,
  }) async {
    if (!await sessions.exists()) {
      return const StorageUsageStats(fileCount: 0, bytes: 0);
    }
    var bytes = 0;
    var fileCount = 0;
    try {
      await for (final ent in sessions.list(
        recursive: false,
        followLinks: false,
      )) {
        if (ent is! Directory) continue;
        if (conversationIds.contains(p.basename(ent.path))) continue;
        final usage = await measureDirectoryUsage(ent);
        bytes += usage.bytes;
        fileCount += usage.fileCount;
      }
    } catch (_) {}
    return StorageUsageStats(fileCount: fileCount, bytes: bytes);
  }

  static Future<Set<String>> _readConversationIdsFromDatabase() async {
    try {
      final root = await AppDirectories.getAppDataDirectory();
      final dbFile = File(p.join(root.path, AppDatabase.databaseFileName));
      if (!await dbFile.exists()) return <String>{};
      final database = sqlite3.open(dbFile.path, mode: OpenMode.readOnly);
      try {
        final rows = database.select('SELECT id FROM conversation_rows');
        return {for (final row in rows) row['id'] as String};
      } finally {
        database.close();
      }
    } catch (_) {
      return <String>{};
    }
  }

  static Future<StorageUsageStats> _measureUsage(Directory dir) async {
    final usage = await measureDirectoryUsage(dir);
    return StorageUsageStats(fileCount: usage.fileCount, bytes: usage.bytes);
  }

  static Future<_StorageContents> _measureContentsOf(
    Future<Directory> Function() directory,
  ) async {
    final path = (await directory()).path;
    // Collect the breakdown during the same background walk as the total.
    return Isolate.run(() {
      final entries = <StorageUsageSubcategory>[];
      try {
        for (final child in Directory(path).listSync(followLinks: false)) {
          try {
            final isDirectory = child is Directory;
            if (!isDirectory && child is! File) continue;
            final usage = isDirectory
                ? measureDirectoryUsageSync(child.path)
                : (bytes: child.statSync().size, fileCount: 1);
            if (usage.fileCount == 0) continue;
            entries.add(
              StorageUsageSubcategory(
                id: p.basename(child.path),
                path: child.path,
                isDirectory: isDirectory,
                stats: StorageUsageStats(
                  fileCount: usage.fileCount,
                  bytes: usage.bytes,
                ),
              ),
            );
          } catch (_) {}
        }
      } catch (_) {}
      return _StorageContents(entries);
    });
  }

  static Future<_StorageContents> _measureSandboxEnvironment({
    required Future<Directory> Function() environmentDirectory,
    Future<Directory> Function()? rootfsUsageDirectory,
  }) async {
    final envDir = await environmentDirectory();
    final rootfsDir = await (rootfsUsageDirectory ?? resolveRootfsUsageDir)();
    final unique = _dedupeNestedDirectories([envDir, rootfsDir]);
    final entries = <StorageUsageSubcategory>[];
    for (final dir in unique) {
      if (p.equals(dir.path, envDir.absolute.path)) {
        entries.addAll(
          (await _measureContentsOf(() async => dir)).subcategories,
        );
      } else {
        final stats = await _measureUsage(dir);
        if (stats.fileCount == 0) continue;
        entries.add(
          StorageUsageSubcategory(
            id: p.basename(dir.path),
            path: dir.path,
            isDirectory: true,
            stats: stats,
          ),
        );
      }
    }
    return _StorageContents(entries);
  }

  /// Prune separately measured trees before descending, and isolate failures
  /// to the unreadable directory rather than aborting all remaining siblings.
  static Stream<File> _listFiles(
    Directory root, {
    Set<String> excludedTopDirectories = const {},
  }) async* {
    final pending = <Directory>[root];
    while (pending.isNotEmpty) {
      final dir = pending.removeLast();
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is Directory) {
            if (dir.path == root.path &&
                excludedTopDirectories.contains(
                  p.basename(entity.path).toLowerCase(),
                )) {
              continue;
            }
            pending.add(entity);
          } else if (entity is File) {
            yield entity;
          }
        }
      } on FileSystemException {
        // Other directories can still be measured/listed.
      }
    }
  }

  static List<Directory> _dedupeNestedDirectories(Iterable<Directory> dirs) {
    final normalized = <String>{};
    for (final dir in dirs) {
      final path = dir.path;
      if (path.isEmpty) continue;
      normalized.add(p.normalize(Directory(path).absolute.path));
    }
    final sorted = normalized.toList()
      ..sort((a, b) => a.length.compareTo(b.length));
    final kept = <String>[];
    for (final path in sorted) {
      final nested = kept.any(
        (outer) => p.equals(outer, path) || p.isWithin(outer, path),
      );
      if (!nested) kept.add(path);
    }
    return [for (final path in kept) Directory(path)];
  }

  static Future<void> _deleteDirectoryContents(
    Directory dir, {
    Set<String> keepFileNames = const <String>{},
  }) async {
    if (!await dir.exists()) return;
    try {
      await for (final ent in dir.list(recursive: true, followLinks: false)) {
        try {
          if (ent is File) {
            if (keepFileNames.contains(p.basename(ent.path))) continue;
            try {
              await ent.delete();
            } catch (_) {
              // Some platforms lock active log files; try truncating.
              try {
                await ent.writeAsBytes(const <int>[], flush: true);
              } catch (_) {}
            }
          } else if (ent is Directory) {
            // We'll delete empty dirs in a second pass.
          } else {
            try {
              await ent.delete();
            } catch (_) {}
          }
        } catch (_) {}
      }

      // Delete empty directories bottom-up.
      final dirs = <Directory>[];
      await for (final ent in dir.list(recursive: true, followLinks: false)) {
        if (ent is Directory) dirs.add(ent);
      }
      dirs.sort((a, b) => b.path.length.compareTo(a.path.length));
      for (final d in dirs) {
        try {
          if (await d.exists()) {
            await d.delete();
          }
        } catch (_) {}
      }
    } catch (_) {}
  }
}

class _MutableStats {
  int fileCount = 0;
  int bytes = 0;
  void add(int b) {
    fileCount += 1;
    bytes += b;
  }

  void addStats(StorageUsageStats stats) {
    fileCount += stats.fileCount;
    bytes += stats.bytes;
  }

  StorageUsageStats toStats() =>
      StorageUsageStats(fileCount: fileCount, bytes: bytes);
}

const List<StorageUsageCategoryKey> _categoryOrder = <StorageUsageCategoryKey>[
  StorageUsageCategoryKey.images,
  StorageUsageCategoryKey.files,
  StorageUsageCategoryKey.chatData,
  StorageUsageCategoryKey.legacyChatData,
  StorageUsageCategoryKey.restoreTraces,
  StorageUsageCategoryKey.displacedDatabases,
  StorageUsageCategoryKey.localSnapshots,
  StorageUsageCategoryKey.assistantData,
  StorageUsageCategoryKey.cache,
  StorageUsageCategoryKey.logs,
  StorageUsageCategoryKey.other,
  StorageUsageCategoryKey.workspaceFiles,
  StorageUsageCategoryKey.sandboxEnvironment,
  StorageUsageCategoryKey.skills,
  StorageUsageCategoryKey.sessionFiles,
];

const Set<String> _isolateMeasuredTopDirs = {
  'workspaces',
  'sessions',
  'skills',
  'environment',
};

bool _isAlwaysVisibleCategory(StorageUsageCategoryKey key) {
  switch (key) {
    case StorageUsageCategoryKey.legacyChatData:
    case StorageUsageCategoryKey.restoreTraces:
    case StorageUsageCategoryKey.displacedDatabases:
    case StorageUsageCategoryKey.localSnapshots:
      return false;
    case StorageUsageCategoryKey.images:
    case StorageUsageCategoryKey.files:
    case StorageUsageCategoryKey.chatData:
    case StorageUsageCategoryKey.assistantData:
    case StorageUsageCategoryKey.cache:
    case StorageUsageCategoryKey.logs:
    case StorageUsageCategoryKey.other:
    case StorageUsageCategoryKey.workspaceFiles:
    case StorageUsageCategoryKey.sandboxEnvironment:
    case StorageUsageCategoryKey.skills:
    case StorageUsageCategoryKey.sessionFiles:
      return true;
  }
}

class _StorageContents {
  _StorageContents(List<StorageUsageSubcategory> entries)
    : subcategories = entries
        ..sort((a, b) => b.stats.bytes.compareTo(a.stats.bytes));

  final List<StorageUsageSubcategory> subcategories;

  StorageUsageStats get stats => subcategories.fold(
    const StorageUsageStats(fileCount: 0, bytes: 0),
    (total, entry) => total + entry.stats,
  );
}
