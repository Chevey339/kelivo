import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'restore_durability.dart';
import 'restore_previous_builder.dart';
import 'restore_previous_plan.dart';
import 'restore_receipt.dart';

final class PersistedRestorePrevious {
  PersistedRestorePrevious({
    required this.directory,
    required this.plan,
    required this.manifestSha256,
  });

  final Directory directory;
  final RestorePreviousPlan plan;
  final String manifestSha256;
}

/// Owns the immutable previous control files inside one restore run.
///
/// `manifest.json` is published last. No live file may be moved until
/// [persistPending] has returned and [readPending] can reopen the exact plan.
final class RestorePreviousStore {
  RestorePreviousStore({
    required this.runDirectory,
    RestoreDurability? durability,
  }) : durability = durability ?? RestorePlatformDurability() {
    if (!RegExp(
      r'^run_[a-f0-9]{32}$',
    ).hasMatch(p.basename(runDirectory.path))) {
      throw ArgumentError.value(runDirectory.path, 'runDirectory');
    }
  }

  static const pendingDirectoryName = 'previous.pending';
  static const previousDirectoryName = 'previous';
  static const manifestFileName = 'manifest.json';
  static const _maximumControlBytes = 16 * 1024 * 1024;

  final Directory runDirectory;
  final RestoreDurability durability;

  Directory get pendingDirectory =>
      Directory(p.join(runDirectory.path, pendingDirectoryName));

  Directory get previousDirectory =>
      Directory(p.join(runDirectory.path, previousDirectoryName));

  Future<PersistedRestorePrevious> persistPending({
    required RestorePreviousBundle bundle,
    required RestoreReceipt preparedReceipt,
  }) async {
    bundle.plan.validatePreparedReceipt(preparedReceipt);
    await _requireRunDirectory();
    if (await FileSystemEntity.type(
          previousDirectory.path,
          followLinks: false,
        ) !=
        FileSystemEntityType.notFound) {
      throw StateError('restore_previous_already_promoted');
    }

    final pendingType = await FileSystemEntity.type(
      pendingDirectory.path,
      followLinks: false,
    );
    if (pendingType == FileSystemEntityType.notFound) {
      await pendingDirectory.create();
      await durability.restrictDirectory(pendingDirectory);
      await durability.syncDirectory(runDirectory, fullBarrier: true);
    } else if (pendingType != FileSystemEntityType.directory) {
      throw StateError('restore_previous_pending_type');
    } else {
      await durability.restrictDirectory(pendingDirectory);
    }

    final manifest = File(p.join(pendingDirectory.path, manifestFileName));
    final manifestType = await FileSystemEntity.type(
      manifest.path,
      followLinks: false,
    );
    if (manifestType == FileSystemEntityType.file) {
      final existing = await readPending(preparedReceipt: preparedReceipt);
      _requireSameBundle(existing, bundle);
      return existing;
    }
    if (manifestType != FileSystemEntityType.notFound) {
      throw StateError('restore_previous_manifest_type');
    }

    await _requirePartialControlTopology();
    final manifestBytes = utf8.encode(jsonEncode(bundle.plan.toJson()));
    if (manifestBytes.length > _maximumControlBytes) {
      throw StateError('restore_previous_manifest_size');
    }
    await _publishControlFile(
      targetName: manifestFileName,
      bytes: manifestBytes,
      fullBarrier: true,
    );
    final persisted = await readPending(preparedReceipt: preparedReceipt);
    _requireSameBundle(persisted, bundle);
    return persisted;
  }

  Future<PersistedRestorePrevious> readPending({
    required RestoreReceipt preparedReceipt,
  }) => _readDirectory(
    directory: pendingDirectory,
    preparedReceipt: preparedReceipt,
  );

  Future<PersistedRestorePrevious> readPrevious({
    required RestoreReceipt preparedReceipt,
  }) => _readDirectory(
    directory: previousDirectory,
    preparedReceipt: preparedReceipt,
  );

  Future<PersistedRestorePrevious> promotePending({
    required RestoreReceipt preparedReceipt,
  }) async {
    final pendingType = await FileSystemEntity.type(
      pendingDirectory.path,
      followLinks: false,
    );
    final previousType = await FileSystemEntity.type(
      previousDirectory.path,
      followLinks: false,
    );
    if (pendingType == FileSystemEntityType.notFound &&
        previousType == FileSystemEntityType.directory) {
      final existing = await readPrevious(preparedReceipt: preparedReceipt);
      await validateComplete(existing);
      return existing;
    }
    if (pendingType != FileSystemEntityType.directory ||
        previousType != FileSystemEntityType.notFound) {
      throw StateError('restore_previous_promotion_topology');
    }

    final pending = await readPending(preparedReceipt: preparedReceipt);
    await validateComplete(pending);
    await durability.renameAndSync(
      source: pendingDirectory,
      targetPath: previousDirectory.path,
    );
    final previous = await readPrevious(preparedReceipt: preparedReceipt);
    if (previous.manifestSha256 != pending.manifestSha256 ||
        previous.plan.checksum != pending.plan.checksum) {
      throw StateError('restore_previous_promotion_identity');
    }
    await validateComplete(previous);
    return previous;
  }

  Future<void> validateComplete(PersistedRestorePrevious previous) async {
    await _requireCompleteTopLevel(previous.directory, previous.plan);
    await RestorePreviousBuilder.validateStoredPayload(
      directory: previous.directory,
      expected: previous.plan,
    );
  }

  Future<void> validateControlOnlyAfterRollback(
    PersistedRestorePrevious previous,
  ) async {
    if (p.normalize(previous.directory.absolute.path) !=
        p.normalize(previousDirectory.absolute.path)) {
      throw StateError('restore_previous_rollback_identity');
    }
    final expected = <String, FileSystemEntityType>{
      manifestFileName: FileSystemEntityType.file,
    };
    final found = <String>{};
    await for (final entity in previous.directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final expectedType = expected[name];
      if (expectedType == null ||
          !found.add(name) ||
          await FileSystemEntity.type(entity.path, followLinks: false) !=
              expectedType) {
        throw StateError('restore_previous_rollback_topology');
      }
    }
    if (found.length != expected.length || !found.containsAll(expected.keys)) {
      throw StateError('restore_previous_rollback_topology');
    }
    final manifestBytes = await _readBounded(
      File(p.join(previous.directory.path, manifestFileName)),
    );
    if (sha256.convert(manifestBytes).toString() != previous.manifestSha256) {
      throw StateError('restore_previous_rollback_manifest');
    }
  }

  Future<PersistedRestorePrevious> _readDirectory({
    required Directory directory,
    required RestoreReceipt preparedReceipt,
  }) async {
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('restore_previous_directory');
    }
    final manifestFile = File(p.join(directory.path, manifestFileName));
    final manifestBytes = await _readBounded(manifestFile);
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(manifestBytes));
    } on FormatException {
      throw const FormatException('restore_previous_manifest');
    }
    if (decoded is! Map) {
      throw const FormatException('restore_previous_manifest');
    }
    final plan = RestorePreviousPlan.fromJson(
      decoded,
      preparedReceipt: preparedReceipt,
    );
    final canonical = utf8.encode(jsonEncode(plan.toJson()));
    if (!_sameBytes(canonical, manifestBytes)) {
      throw const FormatException('restore_previous_manifest_canonical');
    }
    return PersistedRestorePrevious(
      directory: directory,
      plan: plan,
      manifestSha256: sha256.convert(manifestBytes).toString(),
    );
  }

  Future<void> _requireRunDirectory() async {
    if (await FileSystemEntity.type(runDirectory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('restore_previous_run_directory');
    }
  }

  Future<void> _requirePartialControlTopology() async {
    const allowed = {'$manifestFileName.tmp'};
    await for (final entity in pendingDirectory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (!allowed.contains(name) || type != FileSystemEntityType.file) {
        throw StateError('restore_previous_partial_topology');
      }
    }
  }

  Future<void> _publishControlFile({
    required String targetName,
    required List<int> bytes,
    required bool fullBarrier,
  }) async {
    if (bytes.length > _maximumControlBytes) {
      throw StateError('restore_previous_control_size');
    }
    final target = File(p.join(pendingDirectory.path, targetName));
    final targetType = await FileSystemEntity.type(
      target.path,
      followLinks: false,
    );
    if (targetType == FileSystemEntityType.file) {
      if (!_sameBytes(await _readBounded(target), bytes)) {
        throw StateError('restore_previous_control_collision:$targetName');
      }
      return;
    }
    if (targetType != FileSystemEntityType.notFound) {
      throw StateError('restore_previous_control_type:$targetName');
    }

    final temporary = File('${target.path}.tmp');
    final temporaryType = await FileSystemEntity.type(
      temporary.path,
      followLinks: false,
    );
    if (temporaryType == FileSystemEntityType.file) {
      await temporary.delete();
      await durability.syncDirectory(pendingDirectory, fullBarrier: true);
    } else if (temporaryType != FileSystemEntityType.notFound) {
      throw StateError('restore_previous_control_temp:$targetName');
    }
    await temporary.create(exclusive: true);
    await durability.restrictFile(temporary);
    await temporary.writeAsBytes(bytes, flush: true);
    await durability.syncFile(temporary, fullBarrier: fullBarrier);
    if (!_sameBytes(await _readBounded(temporary), bytes)) {
      throw StateError('restore_previous_control_staging:$targetName');
    }
    await durability.renameAndSync(source: temporary, targetPath: target.path);
    if (!_sameBytes(await _readBounded(target), bytes)) {
      throw StateError('restore_previous_control_publish:$targetName');
    }
  }

  Future<void> _requireCompleteTopLevel(
    Directory directory,
    RestorePreviousPlan plan,
  ) async {
    final expected = <String, FileSystemEntityType>{
      manifestFileName: FileSystemEntityType.file,
      if (plan.database.state == RestorePreviousDatabaseState.file)
        'database': FileSystemEntityType.directory,
      if (plan.assets != null)
        for (final root in RestorePreviousAssetsPlan.rootNames)
          if (plan.assets!.rootStates[root] ==
              RestorePreviousAssetRootState.directory)
            root: FileSystemEntityType.directory,
    };
    final found = <String>{};
    await for (final entity in directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final expectedType = expected[name];
      if (expectedType == null ||
          !found.add(name) ||
          await FileSystemEntity.type(entity.path, followLinks: false) !=
              expectedType) {
        throw StateError('restore_previous_complete_topology');
      }
    }
    if (found.length != expected.length || !found.containsAll(expected.keys)) {
      throw StateError('restore_previous_complete_topology');
    }
  }

  Future<List<int>> _readBounded(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('restore_previous_control_file');
    }
    final expectedLength = await file.length();
    if (expectedLength <= 0 || expectedLength > _maximumControlBytes) {
      throw const FormatException('restore_previous_control_size');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (builder.length + chunk.length > _maximumControlBytes) {
        throw const FormatException('restore_previous_control_size');
      }
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    if (bytes.length != expectedLength) {
      throw const FormatException('restore_previous_control_changed');
    }
    return bytes;
  }

  static void _requireSameBundle(
    PersistedRestorePrevious persisted,
    RestorePreviousBundle expected,
  ) {
    if (persisted.plan.checksum != expected.plan.checksum) {
      throw StateError('restore_previous_bundle_collision');
    }
  }
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
