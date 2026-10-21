import 'dart:convert';
import 'dart:io';
import '../services/backup/data_sync.dart';
import '../services/backup/restore_startup_gate.dart';
import 'startup_recovery_service.dart';
import 'database_installation_gate.dart';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../services/backup/restore_business_lease.dart';
import '../services/backup/restore_durability.dart';
import '../services/storage/device_storage_probe.dart';

/// One-way activation of private iOS storage. The source is never deleted.
/// A complete, verified copy is published by directory rename. A durable
/// installation record outside the data directory prevents a missing private
/// directory from being silently repopulated with stale Documents data.
abstract final class PrivateDataStorage {
  static const recordName = '.kelivo_storage_installation.json';
  static const readyName = '.kelivo_private_ready.json';
  static const noticeName = '.kelivo_storage_notice';
  static const sourceManifestName = '.kelivo_private_source.json';

  static Future<void> prepare({
    required Directory source,
    required Directory target,
    void Function()? onCopying,
    RestoreDurability? durability,
  }) async {
    if (p.equals(source.absolute.path, target.absolute.path) ||
        p.isWithin(source.absolute.path, target.absolute.path)) {
      throw StateError('private_storage_overlapping_directories');
    }
    final targetType = await FileSystemEntity.type(
      target.path,
      followLinks: false,
    );
    if (targetType != FileSystemEntityType.notFound &&
        targetType != FileSystemEntityType.directory) {
      throw StateError('private_storage_path_type');
    }
    final io = durability ?? RestorePlatformDurability();
    final parent = target.parent;
    await parent.create(recursive: true);
    final lock = await RestoreBusinessLease.acquire(
      appDataDirectory: parent,
      durability: io,
    );
    RestoreBusinessLease? sourceLock;
    try {
      if (await FileSystemEntity.type(
            p.join(parent.path, recoveryName),
            followLinks: false,
          ) !=
          FileSystemEntityType.notFound) {
        final targetLease = await RestoreBusinessLease.acquire(
          appDataDirectory: target,
          durability: io,
        );
        try {
          await _finishRecovery(target, io);
        } finally {
          await targetLease.close();
        }
      }
      final record = File(p.join(parent.path, recordName));
      if (await record.exists()) {
        final value = await _readRecord(record);
        final id = value['id'] as String;
        if (await target.exists()) {
          final ready = await _readRecord(File(p.join(target.path, readyName)));
          if (ready['id'] != id) {
            throw StateError('private_storage_identity_mismatch');
          }
          return;
        }
        final staged = Directory(
          p.join(parent.path, '.kelivo-data-staging-$id'),
        );
        if (!await staged.exists()) throw StateError('private_storage_missing');
        onCopying?.call();
        sourceLock = await RestoreBusinessLease.acquire(
          appDataDirectory: source,
          durability: io,
        );
        final ready = await _readRecord(
          File(p.join(staged.path, sourceManifestName)),
        );
        if (ready['id'] != id ||
            jsonEncode(await _inventory(source)) !=
                jsonEncode(ready['source'])) {
          throw StateError('private_storage_source_changed');
        }
        await _verifyCopy(
          staged,
          (ready['source'] as Map).cast<String, dynamic>(),
        );
        await io.renameAndSync(source: staged, targetPath: target.path);
        return;
      }
      if (await FileSystemEntity.type(target.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('private_storage_untracked_directory');
      }
      onCopying?.call();
      sourceLock = await RestoreBusinessLease.acquire(
        appDataDirectory: source,
        durability: io,
      );
      final before = await _inventory(source);
      var id = const Uuid().v4();
      Directory? reusable;
      await for (final entry in parent.list(followLinks: false)) {
        if (entry is! Directory ||
            !p.basename(entry.path).startsWith('.kelivo-data-staging-')) {
          continue;
        }
        try {
          final origin = await _readRecord(
            File(p.join(entry.path, sourceManifestName)),
          );
          if (p.basename(entry.path) ==
                  '.kelivo-data-staging-${origin['id']}' &&
              jsonEncode(origin['source']) == jsonEncode(before)) {
            reusable = entry;
            id = origin['id'] as String;
            break;
          }
        } catch (_) {
          // Unrecognized remnants stay intact for investigation.
        }
      }
      final staged =
          reusable ??
          Directory(p.join(parent.path, '.kelivo-data-staging-$id'));
      final completeFiles = <String>{};
      var requiredBytes = 64 * 1024 * 1024;
      for (final entry in before.entries) {
        final value = entry.value as Map;
        if (value['kind'] != 'file') continue;
        if (await _matchesFile(File(p.join(staged.path, entry.key)), value)) {
          completeFiles.add(entry.key);
        } else {
          requiredBytes += value['bytes'] as int;
        }
      }
      final freeBytes = await DeviceStorageProbe.freeBytes();
      if (freeBytes != null && freeBytes < requiredBytes) {
        throw StateError('private_storage_insufficient_space');
      }
      await staged.create(recursive: true);
      await io.restrictDirectory(staged);
      await _write(File(p.join(staged.path, sourceManifestName)), {
        'version': 1,
        'id': id,
        'source': before,
      }, io);
      for (final entry in before.entries) {
        final from = p.join(source.path, entry.key);
        final to = p.join(staged.path, entry.key);
        final value = entry.value as Map;
        switch (value['kind']) {
          case 'directory':
            final dir = await Directory(to).create(recursive: true);
            await io.restrictDirectory(dir);
          case 'link':
            await Directory(p.dirname(to)).create(recursive: true);
            if (await FileSystemEntity.type(to, followLinks: false) ==
                FileSystemEntityType.notFound) {
              await Link(to).create(value['target'] as String);
            } else if (await Link(to).target() != value['target']) {
              throw StateError('private_storage_copy_mismatch');
            }
          case 'file':
            if (completeFiles.contains(entry.key)) {
              await io.restrictFile(File(to));
              await io.syncFile(File(to), fullBarrier: true);
              continue;
            }
            await Directory(p.dirname(to)).create(recursive: true);
            final targetType = await FileSystemEntity.type(
              to,
              followLinks: false,
            );
            if (targetType != FileSystemEntityType.notFound &&
                targetType != FileSystemEntityType.file) {
              throw StateError('private_storage_copy_mismatch');
            }
            final file = await File(from).copy(to);
            await io.restrictFile(file);
            await io.syncFile(file, fullBarrier: true);
        }
      }
      await _verifyCopy(staged, before);
      if (jsonEncode(before) != jsonEncode(await _inventory(source))) {
        throw StateError('private_storage_source_changed');
      }
      await _write(File(p.join(staged.path, readyName)), {
        'version': 1,
        'id': id,
      }, io);
      await _write(File(p.join(staged.path, noticeName)), {
        'version': 1,
        'id': id,
      }, io);
      // Persist all directory entries before publishing the activation intent.
      for (final name in before.keys.toList().reversed) {
        if ((before[name] as Map)['kind'] == 'directory') {
          await io.syncDirectory(
            Directory(p.join(staged.path, name)),
            fullBarrier: true,
          );
        }
      }
      await io.syncDirectory(staged, fullBarrier: true);
      await _write(record, {'version': 1, 'id': id}, io);
      await io.renameAndSync(source: staged, targetPath: target.path);
    } finally {
      await sourceLock?.close();
      await lock.close();
    }
  }

  static const recoveryName = '.kelivo_storage_recovery.json';

  static Directory diagnosticsDirectory(Directory target) =>
      Directory(p.join(target.parent.path, '.kelivo-storage-diagnostics'));

  /// Complete staging copies are candidates; partial copies remain available
  /// in the full data export but must never be opened as complete databases.
  static Future<List<Directory>> recoveryDirectories({
    required Directory source,
    required Directory target,
  }) async {
    final result = <Directory>[];
    for (final root in [target, source]) {
      if (await FileSystemEntity.type(root.path, followLinks: false) ==
          FileSystemEntityType.directory) {
        result.add(root);
      }
    }
    if (!await target.parent.exists()) return result;
    await for (final entry in target.parent.list(followLinks: false)) {
      if (entry is! Directory ||
          !p.basename(entry.path).startsWith('.kelivo-data-staging-')) {
        continue;
      }
      try {
        final manifest = await _readRecord(
          File(p.join(entry.path, sourceManifestName)),
        );
        if (p.basename(entry.path) !=
            '.kelivo-data-staging-${manifest['id']}') {
          continue;
        }
        await _verifyCopy(
          entry,
          (manifest['source'] as Map).cast<String, dynamic>(),
        );
        result.add(entry);
      } catch (_) {
        // Export preserves the entire parent, including these partial copies.
      }
    }
    return result;
  }

  /// Only invoked after the user confirms a validated copy or a fresh start.
  /// A durable intent makes metadata publication resumable. Neither old roots
  /// nor activation records are overwritten or discarded.
  static Future<void> recover({
    required Directory source,
    required Directory target,
    File? snapshot,
    RestoreDurability? durability,
  }) async {
    final io = durability ?? RestorePlatformDurability();
    final type = await FileSystemEntity.type(target.path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory) {
      throw StateError('private_storage_path_type');
    }
    final parentLease = await RestoreBusinessLease.acquire(
      appDataDirectory: target.parent,
      durability: io,
    );
    RestoreBusinessLease? lease;
    try {
      lease = await RestoreBusinessLease.acquire(
        appDataDirectory: target,
        durability: io,
      );
      final id = const Uuid().v4();
      final intent = <String, dynamic>{'version': 1, 'id': id};
      if (snapshot != null) {
        // Snapshots omit attachments. Restore missing managed assets from
        // retained roots before preparing the database's attachment references.
        for (final root in await recoveryDirectories(
          source: source,
          target: target,
        )) {
          if (!p.equals(root.path, target.path)) {
            await _copyMissingAssets(root, target, io);
          }
        }
        await DataSync.prepareStartupSnapshotRestore(
          appDataDirectory: target,
          snapshot: snapshot,
          businessLease: lease,
        );
        final pending = await RestoreStartupGate.inspect(
          appDataDirectory: target,
        );
        if (pending == null) {
          throw StateError('private_storage_recovery_candidate_missing');
        }
        intent['runId'] = pending.runId;
      } else {
        await StartupRecoveryService.reset(
          appDataDirectory: target,
          businessLease: lease,
          durability: io,
        );
        intent['databaseId'] = (await DatabaseInstallationGate.read(
          appDataDirectory: target,
        ))!.databaseId;
      }
      final file = File(p.join(target.parent.path, recoveryName));
      await _retainMetadata(file, target, io);
      await _write(file, intent, io);
      await _finishRecovery(target, io);
    } finally {
      await lease?.close();
      await parentLease.close();
    }
  }

  static Future<void> _finishRecovery(
    Directory target,
    RestoreDurability io,
  ) async {
    final intentFile = File(p.join(target.parent.path, recoveryName));
    final intent = await _readRecord(intentFile);
    if (intent['runId'] is String) {
      final pending = await RestoreStartupGate.inspect(
        appDataDirectory: target,
      );
      if (pending?.runId != intent['runId']) {
        throw StateError('private_storage_recovery_candidate_missing');
      }
    } else if (intent['databaseId'] is String) {
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: target,
        durability: io,
      );
      if (receipt.databaseId != intent['databaseId']) {
        throw StateError('private_storage_recovery_identity');
      }
    } else {
      throw StateError('private_storage_record_invalid');
    }
    for (final file in [
      File(p.join(target.parent.path, recordName)),
      File(p.join(target.path, readyName)),
      File(p.join(target.path, noticeName)),
    ]) {
      var matches = false;
      try {
        matches = (await _readRecord(file))['id'] == intent['id'];
      } catch (_) {}
      if (!matches) {
        await _retainMetadata(file, target, io);
        await _write(file, {'version': 1, 'id': intent['id']}, io);
      }
    }
    // Retain the completed authorization as well as the superseded records.
    await _retainMetadata(intentFile, target, io);
  }

  static Future<void> _retainMetadata(
    File file,
    Directory target,
    RestoreDurability io,
  ) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.file) {
      throw StateError('private_storage_record_invalid');
    }
    final directory = await Directory(
      p.join(target.parent.path, '.kelivo-storage-records'),
    ).create(recursive: true);
    await io.restrictDirectory(directory);
    await io.syncDirectory(target.parent, fullBarrier: true);
    await io.renameAndSync(
      source: file,
      targetPath: p.join(
        directory.path,
        '${const Uuid().v4()}-${p.basename(file.path)}',
      ),
    );
  }

  static Future<void> _copyMissingAssets(
    Directory source,
    Directory target,
    RestoreDurability io,
  ) async {
    Future<void> copy(Directory from, Directory to) async {
      final type = await FileSystemEntity.type(to.path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.directory) {
        return;
      }
      await to.create();
      await io.restrictDirectory(to);
      await for (final child in from.list(followLinks: false)) {
        final path = p.join(to.path, p.basename(child.path));
        if (child is Directory) {
          await copy(child, Directory(path));
        } else if (child is File &&
            await FileSystemEntity.type(path, followLinks: false) ==
                FileSystemEntityType.notFound) {
          final expected = {
            'bytes': await child.length(),
            'sha256': (await sha256.bind(child.openRead()).first).toString(),
          };
          final temp = await child.copy('$path.${const Uuid().v4()}.tmp');
          if (!await _matchesFile(temp, expected)) {
            throw StateError('private_storage_copy_mismatch');
          }
          await io.restrictFile(temp);
          await io.syncFile(temp, fullBarrier: true);
          await io.renameAndSync(source: temp, targetPath: path);
        }
      }
      await io.syncDirectory(to, fullBarrier: true);
    }

    for (final name in [
      'images',
      'upload',
      'avatars',
      'fonts',
      'drafts',
      'workspaces',
      'sessions',
      'skills',
      'environment',
      'asr_models',
    ]) {
      final directory = Directory(p.join(source.path, name));
      if (await FileSystemEntity.type(directory.path, followLinks: false) ==
          FileSystemEntityType.directory) {
        await copy(directory, Directory(p.join(target.path, name)));
      }
    }
    await io.syncDirectory(target, fullBarrier: true);
  }

  static Future<Map<String, dynamic>> _readRecord(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.length() > 32 * 1024 * 1024) {
      throw StateError('private_storage_record_invalid');
    }
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['id'] is! String ||
        !RegExp(r'^[a-f0-9-]{36}$').hasMatch(value['id'] as String)) {
      throw StateError('private_storage_record_invalid');
    }
    return value;
  }

  static Future<Map<String, dynamic>> _inventory(Directory root) async {
    final entries = <String, dynamic>{};
    if (!await root.exists()) return entries;
    Future<void> walk(Directory directory) async {
      final children = await directory.list(followLinks: false).toList();
      children.sort((a, b) => a.path.compareTo(b.path));
      for (final child in children) {
        final relative = p.relative(child.path, from: root.path);
        if (relative == RestoreBusinessLease.leaseDirectoryName) continue;
        if (child is Directory) {
          entries[relative] = {'kind': 'directory'};
          await walk(child);
        } else if (child is File) {
          final stat = await child.stat();
          entries[relative] = {
            'kind': 'file',
            'bytes': stat.size,
            'modified': stat.modified.microsecondsSinceEpoch,
            'sha256': (await sha256.bind(child.openRead()).first).toString(),
          };
        } else if (child is Link) {
          entries[relative] = {'kind': 'link', 'target': await child.target()};
        } else {
          throw StateError('private_storage_entry_type');
        }
      }
    }

    await walk(root);
    return entries;
  }

  static Future<void> _verifyCopy(
    Directory directory,
    Map<String, dynamic> expected,
  ) async {
    for (final entry in expected.entries) {
      if (p.isAbsolute(entry.key) ||
          p.split(entry.key).contains('..') ||
          entry.key.isEmpty) {
        throw StateError('private_storage_record_invalid');
      }
      final value = entry.value as Map;
      final path = p.join(directory.path, entry.key);
      if (value['kind'] == 'file') {
        final file = File(path);
        if (await FileSystemEntity.type(path, followLinks: false) !=
                FileSystemEntityType.file ||
            await file.length() != value['bytes'] ||
            (await sha256.bind(file.openRead()).first).toString() !=
                value['sha256']) {
          throw StateError('private_storage_copy_mismatch');
        }
      } else if (value['kind'] == 'directory') {
        if (await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.directory) {
          throw StateError('private_storage_copy_mismatch');
        }
      } else if (value['kind'] == 'link' &&
          await Link(path).target() != value['target']) {
        throw StateError('private_storage_copy_mismatch');
      }
    }
  }

  static Future<bool> _matchesFile(File file, Map expected) async {
    try {
      return await FileSystemEntity.type(file.path, followLinks: false) ==
              FileSystemEntityType.file &&
          await file.length() == expected['bytes'] &&
          (await sha256.bind(file.openRead()).first).toString() ==
              expected['sha256'];
    } catch (_) {
      return false;
    }
  }

  static Future<void> _write(
    File target,
    Map<String, dynamic> value,
    RestoreDurability io,
  ) async {
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      if (await FileSystemEntity.type(target.path, followLinks: false) !=
              FileSystemEntityType.file ||
          await target.readAsString() != jsonEncode(value)) {
        throw StateError('private_storage_record_invalid');
      }
      await io.syncFile(target, fullBarrier: true);
      return;
    }
    final temp = File('${target.path}.${const Uuid().v4()}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    await io.restrictFile(temp);
    await io.syncFile(temp, fullBarrier: true);
    await io.renameAndSync(source: temp, targetPath: target.path);
  }
}
