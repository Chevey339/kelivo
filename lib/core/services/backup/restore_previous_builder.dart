import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../database/app_database.dart';
import '../../../utils/app_directories.dart';
import 'backup_file_digest.dart';
import 'backup_archive_limits.dart';
import 'backup_isolate_runner.dart';
import 'backup_task_progress.dart';
import 'restore_durability.dart';
import 'restore_previous_plan.dart';
import 'restore_receipt.dart';

final class RestorePreviousBundle {
  const RestorePreviousBundle({required this.plan});

  final RestorePreviousPlan plan;
}

/// Describes the closed live bundle before any restore object is moved.
///
/// File contents are hashed as streams. The resulting immutable plan is the
/// authority used by later cutover phases; this builder never mutates the
/// live database or asset roots.
final class RestorePreviousBuilder {
  RestorePreviousBuilder._();

  static const assetRootNames = RestorePreviousAssetsPlan.rootNames;
  static const _databaseSidecarSuffixes = ['-wal', '-shm', '-journal'];
  static const _maximumAssetPathBytes = 8 * 1024 * 1024;
  static const _maximumSinglePathBytes = 0xffff;

  static Future<RestorePreviousBundle> build({
    required Directory appDataDirectory,
    required RestoreReceipt preparedReceipt,
    Iterable<String> assetRoots = assetRootNames,
    BackupProgressSink? onProgress,
  }) async {
    if (preparedReceipt.state != RestoreReceiptState.prepared ||
        preparedReceipt.sequence != 1) {
      throw ArgumentError('restore_previous_builder_receipt');
    }
    if (await FileSystemEntity.type(
          appDataDirectory.path,
          followLinks: false,
        ) !=
        FileSystemEntityType.directory) {
      throw StateError('restore_previous_builder_app_data');
    }

    final database = await inspectDatabase(
      appDataDirectory,
      onProgress: onProgress,
    );
    final assets =
        preparedReceipt.selectedComponents.contains(RestoreComponent.assets)
        ? await inspectAssets(
            await AppDirectories.contentDirectoryFor(appDataDirectory),
            rootNames: assetRoots,
            onProgress: onProgress,
          )
        : null;
    final totalBytes =
        (database.descriptor?.bytes ?? 0) +
        (assets?.entries.values.fold<int>(
              0,
              (total, descriptor) => total + descriptor.bytes,
            ) ??
            0);
    if (totalBytes > BackupArchiveLimits.totalBytes) {
      throw StateError('restore_previous_total_budget');
    }
    final plan = RestorePreviousPlan.forPreparedReceipt(
      receipt: preparedReceipt,
      database: database,
      assets: assets,
    );
    if (utf8.encode(jsonEncode(plan.toJson())).length >
        BackupArchiveLimits.manifestBytes) {
      throw StateError('restore_previous_manifest_budget');
    }
    return RestorePreviousBundle(plan: plan);
  }

  static Future<void> validateLive({
    required Directory appDataDirectory,
    required RestorePreviousPlan expected,
  }) async {
    if (await FileSystemEntity.type(
          appDataDirectory.path,
          followLinks: false,
        ) !=
        FileSystemEntityType.directory) {
      throw StateError('restore_previous_builder_app_data');
    }
    final actualDatabase = await inspectDatabase(appDataDirectory);
    if (!_sameDatabase(actualDatabase, expected.database)) {
      throw StateError('restore_previous_database_changed');
    }
    if (expected.assets != null) {
      final actual = await inspectAssets(
        await AppDirectories.contentDirectoryFor(appDataDirectory),
        rootNames: expected.assets!.rootStates.keys,
      );
      if (!_sameAssets(actual, expected.assets!)) {
        throw StateError('restore_previous_assets_changed');
      }
    }
  }

  static Future<RestorePreviousDatabasePlan> inspectDatabase(
    Directory root, {
    BackupProgressSink? onProgress,
  }) => _inspectDatabaseFile(
    File(p.join(root.path, AppDatabase.databaseFileName)),
    onProgress: onProgress,
  );

  static Future<void> validateStoredPayload({
    required Directory directory,
    required RestorePreviousPlan expected,
    BackupProgressSink? onProgress,
  }) async {
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('restore_previous_stored_directory');
    }
    final databaseFile = File(
      p.joinAll([
        directory.path,
        ...RestorePreviousDatabasePlan.databasePath.split('/'),
      ]),
    );
    final actual = await _inspectDatabaseFile(
      databaseFile,
      onProgress: onProgress,
    );
    if (!_sameDatabase(actual, expected.database)) {
      throw StateError('restore_previous_stored_database');
    }
    final databaseDirectory = databaseFile.parent;
    if (expected.database.state == RestorePreviousDatabaseState.file) {
      final entries = await databaseDirectory.list(followLinks: false).toList();
      if (entries.length != 1 ||
          p.basename(entries.single.path) != AppDatabase.databaseFileName ||
          await FileSystemEntity.type(
                entries.single.path,
                followLinks: false,
              ) !=
              FileSystemEntityType.file) {
        throw StateError('restore_previous_stored_database_topology');
      }
    } else if (await FileSystemEntity.type(
          databaseDirectory.path,
          followLinks: false,
        ) !=
        FileSystemEntityType.notFound) {
      throw StateError('restore_previous_stored_database_topology');
    }
    if (expected.assets != null) {
      final actual = await inspectAssets(
        directory,
        rootNames: expected.assets!.rootStates.keys,
        onProgress: onProgress,
      );
      if (!_sameAssets(actual, expected.assets!)) {
        throw StateError('restore_previous_stored_assets');
      }
    }
  }

  static Future<RestorePreviousDatabasePlan> _inspectDatabaseFile(
    File database, {
    BackupProgressSink? onProgress,
  }) async {
    for (final suffix in _databaseSidecarSuffixes) {
      if (await FileSystemEntity.type(
            '${database.path}$suffix',
            followLinks: false,
          ) !=
          FileSystemEntityType.notFound) {
        throw StateError('restore_previous_database_sidecar:$suffix');
      }
    }
    final type = await FileSystemEntity.type(database.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return RestorePreviousDatabasePlan.missing();
    }
    if (type != FileSystemEntityType.file) {
      throw StateError('restore_previous_database_type');
    }
    final descriptor = await describeFile(database, onProgress: onProgress);
    if (descriptor.bytes > BackupArchiveLimits.entryBytes) {
      throw StateError('restore_previous_database_budget');
    }
    return RestorePreviousDatabasePlan.file(descriptor);
  }

  static Future<RestorePreviousAssetsPlan> inspectAssets(
    Directory root, {
    Iterable<String> rootNames = assetRootNames,
    BackupProgressSink? onProgress,
  }) => runBackupIsolate(
    body: _inspectAssets,
    payload: (root: root, names: rootNames.toList(growable: false)),
    onProgress: onProgress,
  );

  static Future<RestorePreviousAssetsPlan> _inspectAssets(
    BackupIsolateContext ctx,
    ({Directory root, List<String> names}) args,
  ) async {
    final root = args.root;
    final rootNames = args.names;
    if (rootNames.isEmpty ||
        rootNames.any((name) => !assetRootNames.contains(name))) {
      throw ArgumentError.value(rootNames, 'rootNames');
    }
    final rootStates = <String, RestorePreviousAssetRootState>{};
    final entries = <String, RestoreAssetDescriptor>{};
    final foldedNames = <String, FileSystemEntityType>{};
    final pendingFiles = <({File file, String name, FileStat stat})>[];
    var totalPathBytes = 0;
    var totalBytes = 0;
    var entryCount = 0;

    for (final rootName in rootNames) {
      final assetRoot = Directory(p.join(root.path, rootName));
      final rootType = FileSystemEntity.typeSync(
        assetRoot.path,
        followLinks: false,
      );
      if (rootType == FileSystemEntityType.notFound) {
        rootStates[rootName] = RestorePreviousAssetRootState.missing;
        continue;
      }
      if (rootType != FileSystemEntityType.directory) {
        throw StateError('restore_previous_asset_root:$rootName:$rootType');
      }
      rootStates[rootName] = RestorePreviousAssetRootState.directory;

      await for (final entity in assetRoot.list(
        recursive: true,
        followLinks: false,
      )) {
        final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
        final relativeName = _portableRelativePath(root: root, entity: entity);
        final pathBytes = utf8.encode(relativeName).length;
        totalPathBytes += pathBytes;
        if (pathBytes > _maximumSinglePathBytes ||
            totalPathBytes > _maximumAssetPathBytes) {
          throw StateError('restore_previous_asset_budget');
        }
        // Directories are implicit in the asset manifest. The filesystem
        // can distinguish their paths while their child entries stay unique.
        final foldedName = relativeName.toLowerCase();
        final previousType = foldedNames[foldedName];
        if (previousType != null &&
            (previousType != FileSystemEntityType.directory ||
                type != FileSystemEntityType.directory)) {
          throw StateError('restore_previous_asset_case_collision');
        }
        foldedNames[foldedName] = type;
        if (type == FileSystemEntityType.directory) {
          continue;
        }
        if (++entryCount > BackupArchiveLimits.entries) {
          throw StateError('restore_previous_asset_budget');
        }
        ctx.reportProgress(
          BackupProgress(
            phase: BackupPhase.scanning,
            processed: entryCount,
            unit: BackupProgressUnit.items,
          ),
        );
        if (type == FileSystemEntityType.link) {
          final target = Link(entity.path).targetSync();
          final targetBytes = utf8.encode(target).length;
          totalPathBytes += targetBytes;
          totalBytes += targetBytes;
          if (targetBytes > _maximumSinglePathBytes ||
              totalPathBytes > _maximumAssetPathBytes ||
              totalBytes > BackupArchiveLimits.totalBytes) {
            throw StateError('restore_previous_asset_budget');
          }
          entries[relativeName] = RestoreAssetDescriptor.link(target);
          continue;
        }
        if (type == FileSystemEntityType.pipe) {
          entries[relativeName] = const RestoreAssetDescriptor.pipe();
          continue;
        }
        if (type == FileSystemEntityType.unixDomainSock) {
          entries[relativeName] = const RestoreAssetDescriptor.socket();
          continue;
        }
        if (type != FileSystemEntityType.file) {
          throw StateError(
            'restore_previous_asset_entry_type:$relativeName:$type',
          );
        }
        final stat = File(entity.path).statSync();
        totalBytes += stat.size;
        if (stat.type != FileSystemEntityType.file ||
            stat.size > BackupArchiveLimits.entryBytes ||
            totalBytes > BackupArchiveLimits.totalBytes) {
          throw StateError('restore_previous_asset_budget');
        }
        pendingFiles.add((
          file: File(entity.path),
          name: relativeName,
          stat: stat,
        ));
      }
    }
    pendingFiles.sort((left, right) => left.name.compareTo(right.name));
    final meter = BackupByteProgress(
      phase: BackupPhase.validating,
      total: pendingFiles.fold<int>(0, (sum, file) => sum + file.stat.size),
      onProgress: ctx.reportProgress,
    );
    var checkedFiles = 0;
    void reportEmptyFiles() => ctx.reportProgress(
      BackupProgress(
        phase: BackupPhase.validating,
        processed: checkedFiles,
        total: pendingFiles.length,
        unit: BackupProgressUnit.items,
      ),
    );
    if (meter.total > 0) {
      meter.report();
    } else if (pendingFiles.isNotEmpty) {
      reportEmptyFiles();
    }
    late final buffer = Uint8List(1024 * 1024);
    for (final pending in pendingFiles) {
      final descriptor = _describeFileSync(
        ctx,
        pending.file,
        buffer: buffer,
        meter: meter,
      );
      if (descriptor.bytes != pending.stat.size) {
        throw StateError('restore_previous_file_changed');
      }
      entries[pending.name] = RestoreAssetDescriptor.file(descriptor);
      if (meter.total == 0) {
        checkedFiles++;
        reportEmptyFiles();
      }
    }
    return RestorePreviousAssetsPlan(rootStates: rootStates, entries: entries);
  }

  /// Makes the selected live asset roots durable before the first rename.
  ///
  /// Regular files are synchronized first, followed by their directories from
  /// the deepest level to [root]. Links and IPC entries are persisted through
  /// their parent directories, never by opening them. The final root barrier
  /// also orders all earlier file and directory flushes on Apple platforms.
  static Future<void> syncAssetRoots({
    required Directory root,
    required RestorePreviousAssetsPlan expected,
    required Set<String> rootNames,
    required RestoreDurability durability,
    BackupProgressSink? onProgress,
  }) async {
    if (await FileSystemEntity.type(root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('restore_previous_asset_sync_root');
    }
    if (rootNames.any((name) => !assetRootNames.contains(name))) {
      throw ArgumentError.value(rootNames, 'rootNames');
    }
    if (rootNames.isEmpty) return;

    for (final rootName in rootNames) {
      if (expected.rootStates[rootName] !=
          RestorePreviousAssetRootState.directory) {
        throw StateError('restore_previous_asset_sync_changed:$rootName');
      }
    }

    final selectedEntries =
        expected.entries.entries
            .where(
              (entry) => rootNames.any(
                (rootName) => entry.key.startsWith('$rootName/'),
              ),
            )
            .toList()
          ..sort((left, right) => left.key.compareTo(right.key));
    for (final entry in selectedEntries) {
      if (entry.value.type != RestoreAssetEntryType.file) continue;
      await durability.syncFile(
        File(p.joinAll([root.path, ...entry.key.split('/')])),
      );
    }

    final relativeDirectories = <String>{...rootNames};
    for (final entry in selectedEntries) {
      var relativeDirectory = p.posix.dirname(entry.key);
      while (relativeDirectory != '.') {
        relativeDirectories.add(relativeDirectory);
        if (rootNames.contains(relativeDirectory)) break;
        relativeDirectory = p.posix.dirname(relativeDirectory);
      }
    }
    final orderedDirectories = relativeDirectories.toList()
      ..sort((left, right) {
        final depth = p.posix
            .split(right)
            .length
            .compareTo(p.posix.split(left).length);
        return depth != 0 ? depth : left.compareTo(right);
      });
    for (final relativeDirectory in orderedDirectories) {
      await durability.syncDirectory(
        Directory(p.joinAll([root.path, ...relativeDirectory.split('/')])),
      );
    }
    await durability.syncDirectory(root, fullBarrier: true);

    final after = await inspectAssets(
      root,
      rootNames: rootNames,
      onProgress: onProgress,
    );
    for (final rootName in rootNames) {
      if (!_sameAssetRoot(after, expected, rootName)) {
        throw StateError('restore_previous_asset_sync_changed:$rootName');
      }
    }
  }

  static bool _sameDatabase(
    RestorePreviousDatabasePlan left,
    RestorePreviousDatabasePlan right,
  ) {
    return left.state == right.state &&
        _sameDescriptor(left.descriptor, right.descriptor);
  }

  static bool _sameAssets(
    RestorePreviousAssetsPlan left,
    RestorePreviousAssetsPlan right,
  ) {
    if (left.rootStates.length != right.rootStates.length ||
        left.entries.length != right.entries.length) {
      return false;
    }
    return left.rootStates.keys.every(
      (rootName) => _sameAssetRoot(left, right, rootName),
    );
  }

  static bool _sameAssetRoot(
    RestorePreviousAssetsPlan left,
    RestorePreviousAssetsPlan right,
    String rootName,
  ) {
    if (left.rootStates[rootName] != right.rootStates[rootName]) return false;
    final prefix = '$rootName/';
    final leftEntries = left.entries.entries.where(
      (entry) => entry.key.startsWith(prefix),
    );
    final rightEntries = {
      for (final entry in right.entries.entries)
        if (entry.key.startsWith(prefix)) entry.key: entry.value,
    };
    final values = leftEntries.toList(growable: false);
    if (values.length != rightEntries.length) return false;
    return values.every(
      (entry) => entry.value.matches(rightEntries[entry.key]),
    );
  }

  static bool _sameDescriptor(
    RestoreFileDescriptor? left,
    RestoreFileDescriptor? right,
  ) {
    if (left == null || right == null) return left == right;
    return left.bytes == right.bytes && left.sha256 == right.sha256;
  }

  static Future<RestoreFileDescriptor> describeFile(
    File file, {
    BackupProgressSink? onProgress,
  }) => runBackupIsolate(
    body: _describeFileSync,
    payload: file,
    onProgress: onProgress,
  );

  static RestoreFileDescriptor _describeFileSync(
    BackupIsolateContext ctx,
    File file, {
    Uint8List? buffer,
    BackupByteProgress? meter,
  }) {
    if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('restore_previous_file_type');
    }
    final before = file.statSync();
    meter ??= BackupByteProgress(
      phase: BackupPhase.validating,
      total: before.size,
      onProgress: ctx.reportProgress,
    )..report();
    final digest = digestBackupFile(file, buffer: buffer, onBytes: meter.add);
    final afterType = FileSystemEntity.typeSync(file.path, followLinks: false);
    final after = file.statSync();
    if (afterType != FileSystemEntityType.file ||
        before.type != FileSystemEntityType.file ||
        after.type != FileSystemEntityType.file ||
        digest.bytes != before.size ||
        before.size != after.size ||
        before.modified != after.modified ||
        before.changed != after.changed) {
      throw StateError('restore_previous_file_changed');
    }
    return RestoreFileDescriptor(bytes: after.size, sha256: digest.sha256);
  }

  static String _portableRelativePath({
    required Directory root,
    required FileSystemEntity entity,
  }) {
    final relative = p.relative(entity.path, from: root.path);
    if (p.isAbsolute(relative)) {
      throw StateError('restore_previous_asset_path');
    }
    final segments = p.split(relative);
    if (segments.length < 2 ||
        !assetRootNames.contains(segments.first) ||
        segments.any(
          (segment) => segment.isEmpty || segment == '.' || segment == '..',
        )) {
      throw StateError('restore_previous_asset_path');
    }
    final portable = p.posix.joinAll(segments);
    if (p.posix.normalize(portable) != portable) {
      throw StateError('restore_previous_asset_path');
    }
    return portable;
  }
}
