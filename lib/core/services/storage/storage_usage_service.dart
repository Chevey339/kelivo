import 'dart:io';

import 'package:path/path.dart' as p;

import '../../database/app_database.dart';
import '../database_v2_rollout_ledger.dart';
import '../legacy_data_retirement_service.dart';
import '../backup/restore_trace_service.dart';
import '../../../utils/app_directories.dart';
import '../../../utils/avatar_cache.dart';
import '../logging/flutter_logger.dart';
import '../network/request_logger.dart';

enum StorageUsageCategoryKey {
  images,
  files,
  chatData,
  legacyChatData,
  restoreTraces,
  assistantData,
  cache,
  logs,
  other,
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
  const StorageUsageSubcategory({
    required this.id,
    required this.stats,
    this.path,
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

class StorageFileEntry {
  final String path;
  final String name;
  final int bytes;
  final DateTime modifiedAt;
  const StorageFileEntry({
    required this.path,
    required this.name,
    required this.bytes,
    required this.modifiedAt,
  });
}

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

  static Future<StorageUsageReport> computeReport() async {
    final root = await AppDirectories.getAppDataDirectory();
    var migrationCompleted = false;
    try {
      migrationCompleted = await DatabaseV2RolloutLedger(root).read() != null;
    } catch (_) {
      // A malformed rollout receipt must not make legacy files clearable.
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

    final cacheSubs = <String, _MutableStats>{
      'avatar_cache': _MutableStats(),
      'other_cache': _MutableStats(),
      'system_cache': _MutableStats(),
    };

    final logsSubs = <String, _MutableStats>{
      'flutter_logs': _MutableStats(),
      'request_logs': _MutableStats(),
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
            StorageUsageCategory(
              key: k,
              stats: const StorageUsageStats(fileCount: 0, bytes: 0),
            ),
        ],
      );
    }

    try {
      await for (final ent in root.list(recursive: true, followLinks: false)) {
        if (ent is! File) continue;
        int bytes = 0;
        try {
          bytes = await ent.length();
        } catch (_) {
          bytes = 0;
        }
        totalFiles += 1;
        totalBytes += bytes;

        final rel = p.relative(ent.path, from: root.path);
        final parts = p.split(rel);
        if (parts.isEmpty) {
          byCat[StorageUsageCategoryKey.other]!.add(bytes);
          continue;
        }

        // Root-level chat data is stored by Drift in the SQLite database file
        // family. Legacy Hive boxes are migration inputs only and should not
        // affect the steady-state chat records size.
        if (parts.length == 1) {
          final name = parts.first;
          final chatSubId = _chatDatabaseSubcategoryId(name);
          if (chatSubId != null) {
            byCat[StorageUsageCategoryKey.chatData]!.add(bytes);
            chatSubs[chatSubId]!.add(bytes);
          } else if (migrationCompleted &&
              LegacyDataRetirementService.hiveArtifactNames.contains(name)) {
            byCat[StorageUsageCategoryKey.legacyChatData]!.add(bytes);
            legacyChatSubs[name]!.add(bytes);
          } else {
            byCat[StorageUsageCategoryKey.other]!.add(bytes);
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
          case 'upload':
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
          case 'images':
            // Inline/generated images are stored under appData/images.
            // Treat them as "Images" so users can manage them together.
            byCat[StorageUsageCategoryKey.images]!.add(bytes);
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
            if (name.startsWith('flutter_logs')) {
              logsSubs['flutter_logs']!.add(bytes);
            } else if (name.startsWith('logs')) {
              logsSubs['request_logs']!.add(bytes);
            } else {
              logsSubs['other_logs']!.add(bytes);
            }
            break;
          default:
            byCat[StorageUsageCategoryKey.other]!.add(bytes);
            break;
        }
      }
    } catch (_) {
      // If listing fails for any reason, fall back to 0s; UI will show load failed.
    }

    final avatarsDir = await AppDirectories.getAvatarsDirectory();
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
            id: 'flutter_logs',
            stats: logsSubs['flutter_logs']!.toStats(),
            path: logsDir.path,
          ),
          StorageUsageSubcategory(
            id: 'request_logs',
            stats: logsSubs['request_logs']!.toStats(),
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
      await _deleteDirectoryContents(logsDir);
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
    final migration = await DatabaseV2RolloutLedger(root).read();
    if (migration == null) {
      throw StateError('legacy_retirement_untracked');
    }
    await LegacyDataRetirementService(root).retireHiveArtifacts();
  }

  static Future<void> clearRestoreTraces() async {
    final root = await AppDirectories.getAppDataDirectory();
    await RestoreTraceService(root).clear();
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
    }) async {
      if (!await d.exists()) return;
      try {
        await for (final ent in d.list(recursive: true, followLinks: false)) {
          if (ent is! File) continue;
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
            ),
          );
        }
      } catch (_) {
        // Ignore listing errors and return partial results.
      }
    }

    // Chat attachments live under upload/. Inline/generated images live under images/.
    await addFromDir(dir, includeImages: images, includeNonImages: !images);
    if (images) {
      await addFromDir(imagesDir, includeImages: true, includeNonImages: false);
    }
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
      p.normalize(Directory(dir.path).absolute.path),
      if (images) p.normalize(Directory(imagesDir.path).absolute.path),
    ];
    int deleted = 0;
    for (final raw in paths) {
      try {
        final abs = p.normalize(File(raw).absolute.path);
        final allowed = roots.any(
          (root) => p.isWithin(root, abs) || abs == root,
        );
        if (!allowed) continue;
        final f = File(abs);
        if (await f.exists()) {
          await f.delete();
          deleted += 1;
        }
      } catch (_) {}
    }
    return deleted;
  }

  static Future<void> _deleteDirectoryContents(Directory dir) async {
    if (!await dir.exists()) return;
    try {
      await for (final ent in dir.list(recursive: true, followLinks: false)) {
        try {
          if (ent is File) {
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

  StorageUsageStats toStats() =>
      StorageUsageStats(fileCount: fileCount, bytes: bytes);
}

const List<StorageUsageCategoryKey> _categoryOrder = <StorageUsageCategoryKey>[
  StorageUsageCategoryKey.images,
  StorageUsageCategoryKey.files,
  StorageUsageCategoryKey.chatData,
  StorageUsageCategoryKey.legacyChatData,
  StorageUsageCategoryKey.restoreTraces,
  StorageUsageCategoryKey.assistantData,
  StorageUsageCategoryKey.cache,
  StorageUsageCategoryKey.logs,
];
