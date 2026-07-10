import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../database/app_database.dart';
import 'restore_durability.dart';
import 'restore_previous_plan.dart';
import 'restore_receipt.dart';
import 'restore_settings_transition.dart';

final class RestorePreviousBundle {
  const RestorePreviousBundle({
    required this.plan,
    required this.settingsSnapshotBytes,
  });

  final RestorePreviousPlan plan;
  final List<int> settingsSnapshotBytes;
}

/// Describes the closed live bundle before any restore object is moved.
///
/// File contents are hashed as streams. The resulting immutable plan is the
/// authority used by later cutover phases; this builder never mutates live
/// settings, the database, or asset roots.
final class RestorePreviousBuilder {
  RestorePreviousBuilder._();

  static const assetRootNames = RestorePreviousAssetsPlan.rootNames;
  static const _databaseSidecarSuffixes = ['-wal', '-shm', '-journal'];
  static const _maximumEntryBytes = 8 * 1024 * 1024 * 1024;
  static const _maximumTotalBytes = 16 * 1024 * 1024 * 1024;
  static const _maximumAssetEntries = 0xffff;
  static const _maximumAssetPathBytes = 8 * 1024 * 1024;
  static const _maximumSinglePathBytes = 0xffff;
  static const _maximumManifestBytes = 16 * 1024 * 1024;
  static const _maximumSettingsBytes = 16 * 1024 * 1024;

  static Future<RestorePreviousBundle> build({
    required Directory appDataDirectory,
    required RestoreReceipt preparedReceipt,
    required RestoreSettingsTransition settingsTransition,
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

    final snapshotBytes = List<int>.unmodifiable(
      settingsTransition.snapshotBytes,
    );
    if (snapshotBytes.length > _maximumSettingsBytes) {
      throw StateError('restore_previous_settings_budget');
    }
    settingsTransition.plan.validateSnapshotBytes(snapshotBytes);
    settingsTransition.plan.validateTargetProjection(
      settingsTransition.valuesToSet,
    );

    final database =
        preparedReceipt.selectedComponents.contains(RestoreComponent.database)
        ? await inspectDatabase(appDataDirectory)
        : null;
    final assets =
        preparedReceipt.selectedComponents.contains(RestoreComponent.assets)
        ? await inspectAssets(appDataDirectory)
        : null;
    final totalBytes =
        (database?.descriptor?.bytes ?? 0) +
        (assets?.entries.values.fold<int>(
              0,
              (total, descriptor) => total + descriptor.bytes,
            ) ??
            0);
    if (totalBytes > _maximumTotalBytes) {
      throw StateError('restore_previous_total_budget');
    }
    final plan = RestorePreviousPlan.forPreparedReceipt(
      receipt: preparedReceipt,
      settings: settingsTransition.plan,
      database: database,
      assets: assets,
    );
    if (utf8.encode(jsonEncode(plan.toJson())).length > _maximumManifestBytes) {
      throw StateError('restore_previous_manifest_budget');
    }
    return RestorePreviousBundle(
      plan: plan,
      settingsSnapshotBytes: snapshotBytes,
    );
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
    if (expected.database != null) {
      final actual = await inspectDatabase(appDataDirectory);
      if (!_sameDatabase(actual, expected.database!)) {
        throw StateError('restore_previous_database_changed');
      }
    }
    if (expected.assets != null) {
      final actual = await inspectAssets(appDataDirectory);
      if (!_sameAssets(actual, expected.assets!)) {
        throw StateError('restore_previous_assets_changed');
      }
    }
  }

  static Future<RestorePreviousDatabasePlan> inspectDatabase(Directory root) =>
      _inspectDatabaseFile(
        File(p.join(root.path, AppDatabase.databaseFileName)),
      );

  static Future<void> validateStoredPayload({
    required Directory directory,
    required RestorePreviousPlan expected,
  }) async {
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('restore_previous_stored_directory');
    }
    if (expected.database != null) {
      final databaseFile = File(
        p.joinAll([
          directory.path,
          ...RestorePreviousDatabasePlan.databasePath.split('/'),
        ]),
      );
      final actual = await _inspectDatabaseFile(databaseFile);
      if (!_sameDatabase(actual, expected.database!)) {
        throw StateError('restore_previous_stored_database');
      }
      final databaseDirectory = databaseFile.parent;
      if (expected.database!.state == RestorePreviousDatabaseState.file) {
        final entries = await databaseDirectory
            .list(followLinks: false)
            .toList();
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
    }
    if (expected.assets != null) {
      final actual = await inspectAssets(directory);
      if (!_sameAssets(actual, expected.assets!)) {
        throw StateError('restore_previous_stored_assets');
      }
    }
  }

  static Future<RestorePreviousDatabasePlan> _inspectDatabaseFile(
    File database,
  ) async {
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
    final descriptor = await describeFile(database);
    if (descriptor.bytes > _maximumEntryBytes) {
      throw StateError('restore_previous_database_budget');
    }
    return RestorePreviousDatabasePlan.file(descriptor);
  }

  static Future<RestorePreviousAssetsPlan> inspectAssets(Directory root) async {
    final rootStates = <String, RestorePreviousAssetRootState>{};
    final entries = <String, RestoreFileDescriptor>{};
    final foldedNames = <String>{};
    final pendingFiles = <({File file, String name, FileStat stat})>[];
    var totalPathBytes = 0;
    var totalBytes = 0;

    for (final rootName in assetRootNames) {
      final assetRoot = Directory(p.join(root.path, rootName));
      final rootType = await FileSystemEntity.type(
        assetRoot.path,
        followLinks: false,
      );
      if (rootType == FileSystemEntityType.notFound) {
        rootStates[rootName] = RestorePreviousAssetRootState.missing;
        continue;
      }
      if (rootType != FileSystemEntityType.directory) {
        throw StateError('restore_previous_asset_root:$rootName');
      }
      rootStates[rootName] = RestorePreviousAssetRootState.directory;

      await for (final entity in assetRoot.list(
        recursive: true,
        followLinks: false,
      )) {
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        final relativeName = _portableRelativePath(root: root, entity: entity);
        final pathBytes = utf8.encode(relativeName).length;
        totalPathBytes += pathBytes;
        if (pathBytes > _maximumSinglePathBytes ||
            totalPathBytes > _maximumAssetPathBytes) {
          throw StateError('restore_previous_asset_budget');
        }
        if (!foldedNames.add(relativeName.toLowerCase())) {
          throw StateError('restore_previous_asset_case_collision');
        }
        if (type == FileSystemEntityType.directory) {
          continue;
        }
        if (type != FileSystemEntityType.file) {
          throw StateError('restore_previous_asset_entry_type');
        }
        if (pendingFiles.length >= _maximumAssetEntries) {
          throw StateError('restore_previous_asset_budget');
        }
        final stat = await File(entity.path).stat();
        totalBytes += stat.size;
        if (stat.type != FileSystemEntityType.file ||
            stat.size > _maximumEntryBytes ||
            totalBytes > _maximumTotalBytes) {
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
    for (final pending in pendingFiles) {
      final descriptor = await describeFile(pending.file);
      if (descriptor.bytes != pending.stat.size) {
        throw StateError('restore_previous_file_changed');
      }
      entries[pending.name] = descriptor;
    }
    return RestorePreviousAssetsPlan(rootStates: rootStates, entries: entries);
  }

  /// Makes the selected live asset roots durable before the first rename.
  ///
  /// Files are synchronized first, followed by their directories from the
  /// deepest level to [root]. The final root barrier also orders all earlier
  /// file and directory flushes on Apple platforms.
  static Future<void> syncAssetRoots({
    required Directory root,
    required RestorePreviousAssetsPlan expected,
    required Set<String> rootNames,
    required RestoreDurability durability,
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

    final after = await inspectAssets(root);
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
    return assetRootNames.every(
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
      (entry) => _sameDescriptor(entry.value, rightEntries[entry.key]),
    );
  }

  static bool _sameDescriptor(
    RestoreFileDescriptor? left,
    RestoreFileDescriptor? right,
  ) {
    if (left == null || right == null) return left == right;
    return left.bytes == right.bytes && left.sha256 == right.sha256;
  }

  static Future<RestoreFileDescriptor> describeFile(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('restore_previous_file_type');
    }
    final before = await file.stat();
    final digest = await sha256.bind(file.openRead()).first;
    final afterType = await FileSystemEntity.type(
      file.path,
      followLinks: false,
    );
    final after = await file.stat();
    if (afterType != FileSystemEntityType.file ||
        before.type != FileSystemEntityType.file ||
        after.type != FileSystemEntityType.file ||
        before.size != after.size ||
        before.modified != after.modified ||
        before.changed != after.changed) {
      throw StateError('restore_previous_file_changed');
    }
    return RestoreFileDescriptor(bytes: after.size, sha256: digest.toString());
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
