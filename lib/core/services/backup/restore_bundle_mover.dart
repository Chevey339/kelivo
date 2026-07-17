import 'dart:io';

import 'package:path/path.dart' as p;

import '../../database/app_database.dart';
import '../../database/chat_database_repository.dart';
import 'restore_bundle_staging.dart';
import 'restore_durability.dart';
import 'restore_previous_builder.dart';
import 'restore_previous_plan.dart';
import 'restore_previous_store.dart';
import 'restore_receipt.dart';
import 'restore_settings_store.dart';
import 'restore_settings_transition.dart';

/// Performs only descriptor-guarded, same-volume bundle moves.
final class RestoreBundleMover {
  RestoreBundleMover({
    required this.appDataDirectory,
    required this.candidateDirectory,
    required this.previousStore,
    RestoreDurability? durability,
  }) : durability = durability ?? RestorePlatformDurability();

  static const _databaseEntry = 'database/kelivo.db';

  final Directory appDataDirectory;
  final Directory candidateDirectory;
  final RestorePreviousStore previousStore;
  final RestoreDurability durability;

  Future<void> moveLiveToPending(PersistedRestorePrevious previous) async {
    if (p.normalize(previous.directory.absolute.path) !=
        p.normalize(previousStore.pendingDirectory.absolute.path)) {
      throw StateError('restore_mover_pending_identity');
    }
    final plan = previous.plan;
    if (plan.assets != null) {
      await _movePreviousAssets(plan.assets!);
    }
    if (plan.database != null) {
      await _movePreviousDatabase(plan.database!);
    }
    await previousStore.validateComplete(previous);
  }

  Future<void> installCandidate({
    required RestoreReceipt receipt,
    required ValidatedRestoreCandidate candidate,
    required RestoreSettingsTransition settingsTransition,
    required RestoreSettingsStore settingsStore,
  }) async {
    _requireCandidateBinding(receipt, candidate);
    await settingsStore.apply(settingsTransition);
    if (receipt.selectedComponents.contains(RestoreComponent.database)) {
      final descriptor = candidate.entries[_databaseEntry];
      if (descriptor == null || candidate.databaseInfo == null) {
        throw StateError('restore_mover_candidate_database');
      }
      await _moveExactFile(
        source: File(
          p.joinAll([candidateDirectory.path, ..._databaseEntry.split('/')]),
        ),
        target: File(
          p.join(appDataDirectory.path, AppDatabase.databaseFileName),
        ),
        expected: RestoreFileDescriptor(
          bytes: descriptor.bytes,
          sha256: descriptor.sha256,
        ),
        databaseFamily: true,
      );
    }
    if (receipt.selectedComponents.contains(RestoreComponent.assets)) {
      final expected = _candidateAssetsPlan(candidate);
      await _moveAssetRoots(
        sourceContainer: candidateDirectory,
        targetContainer: appDataDirectory,
        expected: expected,
      );
    }
  }

  Future<void> validateInstalled({
    required RestoreReceipt receipt,
    required ValidatedRestoreCandidate candidate,
    required RestoreSettingsTransition settingsTransition,
    required RestoreSettingsStore settingsStore,
    required PersistedRestorePrevious previous,
    bool repairSettings = true,
  }) async {
    _requireCandidateBinding(receipt, candidate);
    if (repairSettings) {
      await settingsStore.apply(settingsTransition);
    } else {
      await settingsStore.validateTarget(settingsTransition);
    }
    if (receipt.selectedComponents.contains(RestoreComponent.database)) {
      final descriptor = candidate.entries[_databaseEntry]!;
      final source = File(
        p.joinAll([candidateDirectory.path, ..._databaseEntry.split('/')]),
      );
      final target = File(
        p.join(appDataDirectory.path, AppDatabase.databaseFileName),
      );
      if (await _exactFilePresence(
            source,
            RestoreFileDescriptor(
              bytes: descriptor.bytes,
              sha256: descriptor.sha256,
            ),
            databaseFamily: true,
          ) ||
          !await _exactFilePresence(
            target,
            RestoreFileDescriptor(
              bytes: descriptor.bytes,
              sha256: descriptor.sha256,
            ),
            databaseFamily: true,
          )) {
        throw StateError('restore_mover_database_not_installed');
      }
      final actual = await ChatDatabaseRepository.inspectPreparedSnapshot(
        target,
      );
      if (actual != candidate.databaseInfo) {
        throw StateError('restore_mover_database_metadata');
      }
    }
    if (receipt.selectedComponents.contains(RestoreComponent.assets)) {
      final expected = _candidateAssetsPlan(candidate);
      final source = await RestorePreviousBuilder.inspectAssets(
        candidateDirectory,
      );
      final target = await RestorePreviousBuilder.inspectAssets(
        appDataDirectory,
      );
      for (final root in RestorePreviousAssetsPlan.rootNames) {
        if (_exactAssetRootPresence(source, expected, root) ||
            !_exactAssetRootPresence(target, expected, root)) {
          throw StateError('restore_mover_assets_not_installed:$root');
        }
      }
    }
    await previousStore.validateComplete(previous);
  }

  Future<void> validateRollbackStart({
    required RestoreReceipt receipt,
    required ValidatedRestoreCandidate candidate,
    required RestoreSettingsTransition settingsTransition,
    required RestoreSettingsStore settingsStore,
    required PersistedRestorePrevious previous,
  }) async {
    if (receipt.state != RestoreReceiptState.oldRenamed &&
        receipt.state != RestoreReceiptState.newInstalled &&
        receipt.state != RestoreReceiptState.verified) {
      throw StateError('restore_mover_rollback_state');
    }
    _requireCandidateBinding(receipt, candidate);
    await previousStore.validateComplete(previous);
    await settingsStore.validateRecoverable(settingsTransition);
    if (receipt.selectedComponents.contains(RestoreComponent.database)) {
      final descriptor = candidate.entries[_databaseEntry];
      if (descriptor == null || previous.plan.database == null) {
        throw StateError('restore_mover_rollback_database');
      }
      await _requireNewDatabaseSplit(
        RestoreFileDescriptor(
          bytes: descriptor.bytes,
          sha256: descriptor.sha256,
        ),
      );
    }
    if (receipt.selectedComponents.contains(RestoreComponent.assets)) {
      final expected = _candidateAssetsPlan(candidate);
      final candidateActual = await RestorePreviousBuilder.inspectAssets(
        candidateDirectory,
      );
      final liveActual = await RestorePreviousBuilder.inspectAssets(
        appDataDirectory,
      );
      for (final root in RestorePreviousAssetsPlan.rootNames) {
        _requireAssetSplit(
          candidateActual: candidateActual,
          liveActual: liveActual,
          expected: expected,
          root: root,
        );
      }
    }
  }

  Future<void> rollbackToPrevious({
    required RestoreReceipt receipt,
    required ValidatedRestoreCandidate candidate,
    required RestoreSettingsTransition settingsTransition,
    required RestoreSettingsStore settingsStore,
    required PersistedRestorePrevious previous,
    bool repairSettings = true,
  }) async {
    if (receipt.state != RestoreReceiptState.rollingBack &&
        receipt.state != RestoreReceiptState.rolledBack) {
      throw StateError('restore_mover_rollback_state');
    }
    _requireCandidateBinding(receipt, candidate);
    if (receipt.selectedComponents.contains(RestoreComponent.database)) {
      final descriptor = candidate.entries[_databaseEntry];
      final oldDatabase = previous.plan.database;
      if (descriptor == null || oldDatabase == null) {
        throw StateError('restore_mover_rollback_database');
      }
      await _rollbackDatabase(
        newDescriptor: RestoreFileDescriptor(
          bytes: descriptor.bytes,
          sha256: descriptor.sha256,
        ),
        oldDatabase: oldDatabase,
      );
    }
    if (receipt.selectedComponents.contains(RestoreComponent.assets)) {
      final oldAssets = previous.plan.assets;
      if (oldAssets == null) {
        throw StateError('restore_mover_rollback_assets');
      }
      final newAssets = _candidateAssetsPlan(candidate);
      for (final root in RestorePreviousAssetsPlan.rootNames) {
        await _rollbackAssetRoot(
          root: root,
          newAssets: newAssets,
          oldAssets: oldAssets,
        );
      }
    }
    if (repairSettings) {
      await settingsStore.rollback(settingsTransition);
    }
  }

  Future<void> validateRolledBack({
    required RestoreReceipt receipt,
    required ValidatedRestoreCandidate candidate,
    required RestoreSettingsTransition settingsTransition,
    required RestoreSettingsStore settingsStore,
    required PersistedRestorePrevious previous,
  }) async {
    if (receipt.state != RestoreReceiptState.rollingBack &&
        receipt.state != RestoreReceiptState.rolledBack) {
      throw StateError('restore_mover_rollback_state');
    }
    _requireCandidateBinding(receipt, candidate);
    await settingsStore.validateBefore(settingsTransition);
    await RestorePreviousBuilder.validateLive(
      appDataDirectory: appDataDirectory,
      expected: previous.plan,
    );
    final restoredCandidate =
        await RestoreBundleStaging.validateExistingCandidate(
          candidateDirectory: candidateDirectory,
          expectedManifestSha256: candidate.manifestSha256,
        );
    _requireCandidateBinding(receipt, restoredCandidate);
    await previousStore.validateControlOnlyAfterRollback(previous);
  }

  Future<void> _requireNewDatabaseSplit(RestoreFileDescriptor expected) async {
    final candidate = await _databaseDescriptor(
      File(p.joinAll([candidateDirectory.path, ..._databaseEntry.split('/')])),
    );
    final live = await _databaseDescriptor(
      File(p.join(appDataDirectory.path, AppDatabase.databaseFileName)),
    );
    _requireFileSplit(
      candidate: candidate,
      live: live,
      expected: expected,
      error: 'restore_mover_rollback_new_database',
    );
  }

  Future<void> _rollbackDatabase({
    required RestoreFileDescriptor newDescriptor,
    required RestorePreviousDatabasePlan oldDatabase,
  }) async {
    final candidateFile = File(
      p.joinAll([candidateDirectory.path, ..._databaseEntry.split('/')]),
    );
    final liveFile = File(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
    );
    final previousFile = File(
      p.joinAll([
        previousStore.previousDirectory.path,
        ...RestorePreviousDatabasePlan.databasePath.split('/'),
      ]),
    );
    final previousDescriptor = await _databaseDescriptor(previousFile);

    if (oldDatabase.state == RestorePreviousDatabaseState.missing) {
      if (previousDescriptor != null ||
          await FileSystemEntity.type(
                previousFile.parent.path,
                followLinks: false,
              ) !=
              FileSystemEntityType.notFound) {
        throw StateError('restore_mover_rollback_old_database_missing');
      }
      await _returnNewDatabaseToCandidate(
        candidateFile: candidateFile,
        liveFile: liveFile,
        expected: newDescriptor,
      );
      return;
    }

    final oldDescriptor = oldDatabase.descriptor!;
    if (previousDescriptor != null) {
      if (!_sameDescriptor(previousDescriptor, oldDescriptor)) {
        throw StateError('restore_mover_rollback_old_database');
      }
      await _returnNewDatabaseToCandidate(
        candidateFile: candidateFile,
        liveFile: liveFile,
        expected: newDescriptor,
      );
      await durability.renameAndSync(
        source: previousFile,
        targetPath: liveFile.path,
      );
    } else {
      final candidateDescriptor = await _databaseDescriptor(candidateFile);
      final liveDescriptor = await _databaseDescriptor(liveFile);
      if (!_sameDescriptor(candidateDescriptor, newDescriptor) ||
          !_sameDescriptor(liveDescriptor, oldDescriptor)) {
        throw StateError('restore_mover_rollback_database_position');
      }
    }
    await _removeEmptyPreviousDatabaseDirectory(previousFile.parent);
    if (!_sameDescriptor(
          await _databaseDescriptor(candidateFile),
          newDescriptor,
        ) ||
        !_sameDescriptor(await _databaseDescriptor(liveFile), oldDescriptor)) {
      throw StateError('restore_mover_rollback_database_result');
    }
  }

  Future<void> _returnNewDatabaseToCandidate({
    required File candidateFile,
    required File liveFile,
    required RestoreFileDescriptor expected,
  }) async {
    final candidateDescriptor = await _databaseDescriptor(candidateFile);
    final liveDescriptor = await _databaseDescriptor(liveFile);
    _requireFileSplit(
      candidate: candidateDescriptor,
      live: liveDescriptor,
      expected: expected,
      error: 'restore_mover_rollback_new_database',
    );
    if (liveDescriptor != null) {
      await durability.renameAndSync(
        source: liveFile,
        targetPath: candidateFile.path,
      );
    }
    if (!_sameDescriptor(await _databaseDescriptor(candidateFile), expected) ||
        await _databaseDescriptor(liveFile) != null) {
      throw StateError('restore_mover_rollback_new_database_result');
    }
  }

  Future<void> _removeEmptyPreviousDatabaseDirectory(
    Directory directory,
  ) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.directory ||
        !await directory.list(followLinks: false).isEmpty) {
      throw StateError('restore_mover_rollback_database_directory');
    }
    await directory.delete();
    await durability.syncDirectory(
      previousStore.previousDirectory,
      fullBarrier: true,
    );
  }

  Future<void> _rollbackAssetRoot({
    required String root,
    required RestorePreviousAssetsPlan newAssets,
    required RestorePreviousAssetsPlan oldAssets,
  }) async {
    final candidateActual = await RestorePreviousBuilder.inspectAssets(
      candidateDirectory,
    );
    final liveActual = await RestorePreviousBuilder.inspectAssets(
      appDataDirectory,
    );
    final previousActual = await RestorePreviousBuilder.inspectAssets(
      previousStore.previousDirectory,
    );
    final oldState = oldAssets.rootStates[root]!;
    final previousPresent = _exactAssetRootPresence(
      previousActual,
      oldAssets,
      root,
    );

    if (oldState == RestorePreviousAssetRootState.missing) {
      if (previousPresent) {
        throw StateError('restore_mover_rollback_old_asset_missing:$root');
      }
      final liveHasNew = _requireAssetSplit(
        candidateActual: candidateActual,
        liveActual: liveActual,
        expected: newAssets,
        root: root,
      );
      if (liveHasNew) {
        await durability.renameAndSync(
          source: Directory(p.join(appDataDirectory.path, root)),
          targetPath: p.join(candidateDirectory.path, root),
        );
      }
      return;
    }

    if (previousPresent) {
      final liveHasNew = _requireAssetSplit(
        candidateActual: candidateActual,
        liveActual: liveActual,
        expected: newAssets,
        root: root,
      );
      if (liveHasNew) {
        await durability.renameAndSync(
          source: Directory(p.join(appDataDirectory.path, root)),
          targetPath: p.join(candidateDirectory.path, root),
        );
      }
      await durability.renameAndSync(
        source: Directory(p.join(previousStore.previousDirectory.path, root)),
        targetPath: p.join(appDataDirectory.path, root),
      );
      return;
    }

    if (!_exactAssetRootPresence(candidateActual, newAssets, root) ||
        !_exactAssetRootPresence(liveActual, oldAssets, root)) {
      throw StateError('restore_mover_rollback_asset_position:$root');
    }
  }

  static bool _requireAssetSplit({
    required RestorePreviousAssetsPlan candidateActual,
    required RestorePreviousAssetsPlan liveActual,
    required RestorePreviousAssetsPlan expected,
    required String root,
  }) {
    final candidatePresent = _exactAssetRootPresence(
      candidateActual,
      expected,
      root,
    );
    final livePresent = _exactAssetRootPresence(liveActual, expected, root);
    if (candidatePresent == livePresent) {
      throw StateError('restore_mover_rollback_new_asset:$root');
    }
    return livePresent;
  }

  static void _requireFileSplit({
    required RestoreFileDescriptor? candidate,
    required RestoreFileDescriptor? live,
    required RestoreFileDescriptor expected,
    required String error,
  }) {
    if (candidate != null && !_sameDescriptor(candidate, expected)) {
      throw StateError(error);
    }
    if (live != null && !_sameDescriptor(live, expected)) {
      throw StateError(error);
    }
    if ((candidate != null) == (live != null)) throw StateError(error);
  }

  Future<void> _movePreviousDatabase(
    RestorePreviousDatabasePlan expected,
  ) async {
    final source = File(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
    );
    final target = File(
      p.joinAll([
        previousStore.pendingDirectory.path,
        ...RestorePreviousDatabasePlan.databasePath.split('/'),
      ]),
    );
    if (expected.state == RestorePreviousDatabaseState.missing) {
      if (await _anyDatabaseFamilyEntry(source) ||
          await _anyDatabaseFamilyEntry(target) ||
          await FileSystemEntity.type(target.parent.path, followLinks: false) !=
              FileSystemEntityType.notFound) {
        throw StateError('restore_mover_previous_database_missing');
      }
      return;
    }
    final descriptor = expected.descriptor!;
    final sourcePresent = await _exactFilePresence(
      source,
      descriptor,
      databaseFamily: true,
    );
    final targetPresent = await _exactFilePresence(
      target,
      descriptor,
      databaseFamily: true,
    );
    if (sourcePresent == targetPresent) {
      throw StateError('restore_mover_previous_database_position');
    }
    if (!sourcePresent) return;
    final parentType = await FileSystemEntity.type(
      target.parent.path,
      followLinks: false,
    );
    if (parentType == FileSystemEntityType.notFound) {
      await target.parent.create();
      await durability.restrictDirectory(target.parent);
      await durability.syncDirectory(
        previousStore.pendingDirectory,
        fullBarrier: true,
      );
    } else if (parentType != FileSystemEntityType.directory) {
      throw StateError('restore_mover_previous_database_directory');
    }
    await durability.renameAndSync(source: source, targetPath: target.path);
    if (!await _exactFilePresence(target, descriptor, databaseFamily: true)) {
      throw StateError('restore_mover_previous_database_result');
    }
  }

  Future<void> _movePreviousAssets(RestorePreviousAssetsPlan expected) async {
    await _moveAssetRoots(
      sourceContainer: appDataDirectory,
      targetContainer: previousStore.pendingDirectory,
      expected: expected,
      syncSourceBeforeMove: true,
    );
  }

  Future<void> _moveAssetRoots({
    required Directory sourceContainer,
    required Directory targetContainer,
    required RestorePreviousAssetsPlan expected,
    bool syncSourceBeforeMove = false,
  }) async {
    final source = await RestorePreviousBuilder.inspectAssets(sourceContainer);
    final target = await RestorePreviousBuilder.inspectAssets(targetContainer);
    final rootsToMove = <String>{};
    for (final root in RestorePreviousAssetsPlan.rootNames) {
      final expectedState = expected.rootStates[root]!;
      if (expectedState == RestorePreviousAssetRootState.missing) {
        if (source.rootStates[root] != RestorePreviousAssetRootState.missing ||
            target.rootStates[root] != RestorePreviousAssetRootState.missing) {
          throw StateError('restore_mover_asset_missing:$root');
        }
        continue;
      }
      final sourcePresent = _exactAssetRootPresence(source, expected, root);
      final targetPresent = _exactAssetRootPresence(target, expected, root);
      if (sourcePresent == targetPresent) {
        throw StateError('restore_mover_asset_position:$root');
      }
      if (sourcePresent) rootsToMove.add(root);
    }
    if (syncSourceBeforeMove && rootsToMove.isNotEmpty) {
      await RestorePreviousBuilder.syncAssetRoots(
        root: sourceContainer,
        expected: expected,
        rootNames: rootsToMove,
        durability: durability,
      );
    }
    for (final root in RestorePreviousAssetsPlan.rootNames) {
      if (!rootsToMove.contains(root)) continue;
      await durability.renameAndSync(
        source: Directory(p.join(sourceContainer.path, root)),
        targetPath: p.join(targetContainer.path, root),
      );
    }
  }

  Future<void> _moveExactFile({
    required File source,
    required File target,
    required RestoreFileDescriptor expected,
    required bool databaseFamily,
  }) async {
    final sourcePresent = await _exactFilePresence(
      source,
      expected,
      databaseFamily: databaseFamily,
    );
    final targetPresent = await _exactFilePresence(
      target,
      expected,
      databaseFamily: databaseFamily,
    );
    if (sourcePresent == targetPresent) {
      throw StateError('restore_mover_file_position');
    }
    if (!sourcePresent) return;
    await durability.renameAndSync(source: source, targetPath: target.path);
    if (!await _exactFilePresence(
      target,
      expected,
      databaseFamily: databaseFamily,
    )) {
      throw StateError('restore_mover_file_result');
    }
  }

  Future<bool> _exactFilePresence(
    File file,
    RestoreFileDescriptor expected, {
    required bool databaseFamily,
  }) async {
    final actual = databaseFamily
        ? await _databaseDescriptor(file)
        : await _fileDescriptor(file);
    if (actual == null) return false;
    if (!_sameDescriptor(actual, expected)) {
      throw StateError('restore_mover_file_descriptor');
    }
    return true;
  }

  Future<RestoreFileDescriptor?> _databaseDescriptor(File file) async {
    if (await _hasDatabaseSidecar(file)) {
      throw StateError('restore_mover_database_sidecar');
    }
    return _fileDescriptor(file);
  }

  Future<RestoreFileDescriptor?> _fileDescriptor(File file) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw StateError('restore_mover_file_type');
    }
    return RestorePreviousBuilder.describeFile(file);
  }

  Future<bool> _anyDatabaseFamilyEntry(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      return true;
    }
    return _hasDatabaseSidecar(file);
  }

  Future<bool> _hasDatabaseSidecar(File file) async {
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      if (await FileSystemEntity.type(
            '${file.path}$suffix',
            followLinks: false,
          ) !=
          FileSystemEntityType.notFound) {
        return true;
      }
    }
    return false;
  }

  static RestorePreviousAssetsPlan _candidateAssetsPlan(
    ValidatedRestoreCandidate candidate,
  ) {
    if (!candidate.includeFiles) {
      throw StateError('restore_mover_candidate_assets');
    }
    return RestorePreviousAssetsPlan(
      rootStates: {
        for (final root in RestorePreviousAssetsPlan.rootNames)
          root: RestorePreviousAssetRootState.directory,
      },
      entries: {
        for (final entry in candidate.entries.entries)
          if (RestorePreviousAssetsPlan.rootNames.any(
            (root) => entry.key.startsWith('$root/'),
          ))
            entry.key: RestoreFileDescriptor(
              bytes: entry.value.bytes,
              sha256: entry.value.sha256,
            ),
      },
    );
  }

  static bool _assetRootMatches(
    RestorePreviousAssetsPlan actual,
    RestorePreviousAssetsPlan expected,
    String root,
  ) {
    if (actual.rootStates[root] != expected.rootStates[root]) return false;
    final actualEntries = {
      for (final entry in actual.entries.entries)
        if (entry.key.startsWith('$root/')) entry.key: entry.value,
    };
    final expectedEntries = {
      for (final entry in expected.entries.entries)
        if (entry.key.startsWith('$root/')) entry.key: entry.value,
    };
    if (actualEntries.length != expectedEntries.length) return false;
    for (final entry in actualEntries.entries) {
      if (!_sameDescriptor(entry.value, expectedEntries[entry.key])) {
        return false;
      }
    }
    return true;
  }

  static bool _exactAssetRootPresence(
    RestorePreviousAssetsPlan actual,
    RestorePreviousAssetsPlan expected,
    String root,
  ) {
    if (actual.rootStates[root] == RestorePreviousAssetRootState.missing) {
      return false;
    }
    if (!_assetRootMatches(actual, expected, root)) {
      throw StateError('restore_mover_asset_descriptor:$root');
    }
    return true;
  }

  static bool _sameDescriptor(
    RestoreFileDescriptor? left,
    RestoreFileDescriptor? right,
  ) =>
      left != null &&
      right != null &&
      left.bytes == right.bytes &&
      left.sha256 == right.sha256;

  static void _requireCandidateBinding(
    RestoreReceipt receipt,
    ValidatedRestoreCandidate candidate,
  ) {
    if (receipt.candidateManifestSha256 != candidate.manifestSha256 ||
        receipt.selectedComponents.contains(RestoreComponent.database) !=
            candidate.includeChats ||
        receipt.selectedComponents.contains(RestoreComponent.assets) !=
            candidate.includeFiles) {
      throw StateError('restore_mover_candidate_binding');
    }
  }
}
