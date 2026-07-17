import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/app_database.dart';
import 'restore_bundle_mover.dart';
import 'restore_bundle_staging.dart';
import 'restore_durability.dart';
import 'restore_live_database.dart';
import 'restore_previous_builder.dart';
import 'restore_previous_store.dart';
import 'restore_receipt.dart';
import 'restore_settings_store.dart';
import 'restore_settings_transition.dart';
import 'restore_workspace_lock.dart';

typedef _PreviousTransition = ({
  PersistedRestorePrevious previous,
  RestoreSettingsTransition transition,
  ValidatedRestoreCandidate candidate,
});

/// Reports that cutover failed and its compensating rollback also failed.
///
/// The original objects and stack traces remain available for diagnostics,
/// while [toString] exposes only error types so propagating this exception
/// cannot accidentally include paths or persisted values.
final class RestoreCutoverRollbackException extends StateError {
  RestoreCutoverRollbackException({
    required this.cutoverError,
    required this.cutoverStackTrace,
    required this.rollbackError,
    required this.rollbackStackTrace,
  }) : super('restore_cutover_rollback');

  final Object cutoverError;
  final StackTrace cutoverStackTrace;
  final Object rollbackError;
  final StackTrace rollbackStackTrace;

  @override
  String toString() =>
      'RestoreCutoverRollbackException('
      'cutoverError: ${cutoverError.runtimeType}, '
      'rollbackError: ${rollbackError.runtimeType})';
}

/// Converges one published restore run while the startup workspace lock is
/// held and no business persistence has been opened.
final class RestoreCutoverExecutor {
  factory RestoreCutoverExecutor({
    required Directory appDataDirectory,
    required String runId,
    required SharedPreferences preferences,
    required RestoreWorkspaceLock workspaceLock,
    RestoreDurability? durability,
    bool archived = false,
  }) {
    final resolvedDurability = durability ?? RestorePlatformDurability();
    return RestoreCutoverExecutor._(
      appDataDirectory: appDataDirectory,
      runId: runId,
      preferences: preferences,
      workspaceLock: workspaceLock,
      durability: resolvedDurability,
      archived: archived,
    );
  }

  RestoreCutoverExecutor._({
    required this.appDataDirectory,
    required this.runId,
    required SharedPreferences preferences,
    required this.workspaceLock,
    required this.durability,
    required bool archived,
  }) : settingsStore = RestoreSettingsStore(preferences),
       receiptStore = RestoreReceiptStore(
         appDataDirectory: appDataDirectory,
         runId: runId,
         durability: durability,
         archived: archived,
       ) {
    previousStore = RestorePreviousStore(
      runDirectory: receiptStore.runDirectory,
      durability: durability,
    );
    mover = RestoreBundleMover(
      appDataDirectory: appDataDirectory,
      candidateDirectory: candidateDirectory,
      previousStore: previousStore,
      durability: durability,
    );
  }

  final Directory appDataDirectory;
  final String runId;
  final RestoreWorkspaceLock workspaceLock;
  final RestoreDurability durability;
  final RestoreSettingsStore settingsStore;
  final RestoreReceiptStore receiptStore;
  late final RestorePreviousStore previousStore;
  late final RestoreBundleMover mover;

  Directory get candidateDirectory =>
      Directory(p.join(receiptStore.runDirectory.path, 'candidate'));

  Future<RestoreReceipt> executeWhileWorkspaceLocked({
    required String observedMarkerFileName,
  }) async {
    var history = await receiptStore.readHistoryWhileWorkspaceLocked();
    if (history.isEmpty ||
        history.first.state != RestoreReceiptState.prepared) {
      throw StateError('restore_cutover_receipt_history');
    }
    final preparedReceipt = history.first;
    await workspaceLock.claimCutoverRunWhileWorkspaceLocked(
      runId: runId,
      observedMarkerFileName: observedMarkerFileName,
    );

    while (true) {
      history = await receiptStore.readHistoryWhileWorkspaceLocked();
      if (history.isEmpty ||
          history.first.checksum != preparedReceipt.checksum) {
        throw StateError('restore_cutover_receipt_history');
      }
      final latest = history.last;
      switch (latest.state) {
        case RestoreReceiptState.prepared:
          final candidate =
              await RestoreBundleStaging.validateExistingCandidate(
                candidateDirectory: candidateDirectory,
                expectedManifestSha256: preparedReceipt.candidateManifestSha256,
              );
          final previous = await _completePrevious(
            preparedReceipt: preparedReceipt,
            candidate: candidate,
          );
          await receiptStore.publishWhileWorkspaceLocked(
            latest.advance(
              RestoreReceiptState.oldRenamed,
              previousManifestSha256: previous.previous.manifestSha256,
            ),
          );
          continue;
        case RestoreReceiptState.oldRenamed:
          try {
            final state = await _loadPreviousTransition(preparedReceipt);
            await mover.installCandidate(
              receipt: latest,
              candidate: state.candidate,
              settingsTransition: state.transition,
              settingsStore: settingsStore,
            );
          } catch (error, stackTrace) {
            return _rollbackAfterCutoverFailure(
              latest: latest,
              preparedReceipt: preparedReceipt,
              cutoverError: error,
              cutoverStackTrace: stackTrace,
            );
          }
          await receiptStore.publishWhileWorkspaceLocked(
            latest.advance(RestoreReceiptState.newInstalled),
          );
          continue;
        case RestoreReceiptState.newInstalled:
          try {
            final state = await _loadPreviousTransition(preparedReceipt);
            await mover.validateInstalled(
              receipt: latest,
              candidate: state.candidate,
              settingsTransition: state.transition,
              settingsStore: settingsStore,
              previous: state.previous,
            );
          } catch (error, stackTrace) {
            return _rollbackAfterCutoverFailure(
              latest: latest,
              preparedReceipt: preparedReceipt,
              cutoverError: error,
              cutoverStackTrace: stackTrace,
            );
          }
          await receiptStore.publishWhileWorkspaceLocked(
            latest.advance(RestoreReceiptState.verified),
          );
          continue;
        case RestoreReceiptState.verified:
          try {
            final state = await _loadPreviousTransition(preparedReceipt);
            await mover.validateInstalled(
              receipt: latest,
              candidate: state.candidate,
              settingsTransition: state.transition,
              settingsStore: settingsStore,
              previous: state.previous,
            );
          } catch (error, stackTrace) {
            return _rollbackAfterCutoverFailure(
              latest: latest,
              preparedReceipt: preparedReceipt,
              cutoverError: error,
              cutoverStackTrace: stackTrace,
            );
          }
          final committed = latest.advance(RestoreReceiptState.committed);
          await receiptStore.publishWhileWorkspaceLocked(committed);
          return committed;
        case RestoreReceiptState.committed:
          return revalidateTerminalWhileWorkspaceLocked(latest);
        case RestoreReceiptState.rollingBack:
          return _completeRollback(
            rollingBack: latest,
            preparedReceipt: preparedReceipt,
          );
        case RestoreReceiptState.rolledBack:
          return revalidateTerminalWhileWorkspaceLocked(latest);
      }
    }
  }

  /// Re-converges a terminal run before its evidence leaves active admission.
  /// A committed run is never rolled back here: any unexplained divergence
  /// remains fail-closed. A rolled-back run may repeat its idempotent reverse
  /// moves so an interrupted terminal barrier cannot expose mixed state.
  Future<RestoreReceipt> revalidateTerminalWhileWorkspaceLocked(
    RestoreReceipt terminalReceipt, {
    bool repairSettings = true,
  }) async {
    final history = await receiptStore.readHistoryWhileWorkspaceLocked();
    if (history.isEmpty ||
        history.first.state != RestoreReceiptState.prepared ||
        history.last.checksum != terminalReceipt.checksum) {
      throw StateError('restore_cutover_terminal_history');
    }
    final preparedReceipt = history.first;
    switch (terminalReceipt.state) {
      case RestoreReceiptState.committed:
        final state = await _loadPreviousTransition(preparedReceipt);
        await mover.validateInstalled(
          receipt: terminalReceipt,
          candidate: state.candidate,
          settingsTransition: state.transition,
          settingsStore: settingsStore,
          previous: state.previous,
          repairSettings: repairSettings,
        );
        return terminalReceipt;
      case RestoreReceiptState.rolledBack:
        final state = await _loadRollbackTransition(preparedReceipt);
        await mover.rollbackToPrevious(
          receipt: terminalReceipt,
          candidate: state.candidate,
          settingsTransition: state.transition,
          settingsStore: settingsStore,
          previous: state.previous,
          repairSettings: repairSettings,
        );
        await mover.validateRolledBack(
          receipt: terminalReceipt,
          candidate: state.candidate,
          settingsTransition: state.transition,
          settingsStore: settingsStore,
          previous: state.previous,
        );
        return terminalReceipt;
      case RestoreReceiptState.prepared:
      case RestoreReceiptState.oldRenamed:
      case RestoreReceiptState.newInstalled:
      case RestoreReceiptState.verified:
      case RestoreReceiptState.rollingBack:
        throw StateError('restore_cutover_terminal_state');
    }
  }

  /// Checks only the terminal settings projection. No value is written.
  ///
  /// This is used after a process boundary so the startup gate can distinguish
  /// a durable readback from a recoverable before/target mixture.
  Future<RestoreSettingsReadback> inspectTerminalSettingsWhileWorkspaceLocked(
    RestoreReceipt terminalReceipt,
  ) async {
    final history = await receiptStore.readHistoryWhileWorkspaceLocked();
    if (history.isEmpty ||
        history.first.state != RestoreReceiptState.prepared ||
        history.last.checksum != terminalReceipt.checksum) {
      throw StateError('restore_cutover_terminal_history');
    }
    final preparedReceipt = history.first;
    switch (terminalReceipt.state) {
      case RestoreReceiptState.committed:
        final state = await _loadPreviousTransition(preparedReceipt);
        return settingsStore.inspectReadback(
          transition: state.transition,
          expected: RestoreSettingsExpectedProjection.target,
        );
      case RestoreReceiptState.rolledBack:
        final state = await _loadRollbackTransition(preparedReceipt);
        return settingsStore.inspectReadback(
          transition: state.transition,
          expected: RestoreSettingsExpectedProjection.before,
        );
      case RestoreReceiptState.prepared:
      case RestoreReceiptState.oldRenamed:
      case RestoreReceiptState.newInstalled:
      case RestoreReceiptState.verified:
      case RestoreReceiptState.rollingBack:
        throw StateError('restore_cutover_terminal_state');
    }
  }

  Future<RestoreReceipt> _beginRollback({
    required RestoreReceipt latest,
    required RestoreReceipt preparedReceipt,
  }) async {
    final state = await _loadPreviousTransition(preparedReceipt);
    await mover.validateRollbackStart(
      receipt: latest,
      candidate: state.candidate,
      settingsTransition: state.transition,
      settingsStore: settingsStore,
      previous: state.previous,
    );
    final rollingBack = latest.advance(RestoreReceiptState.rollingBack);
    await receiptStore.publishWhileWorkspaceLocked(rollingBack);
    return _completeRollback(
      rollingBack: rollingBack,
      preparedReceipt: preparedReceipt,
      state: state,
    );
  }

  Future<RestoreReceipt> _rollbackAfterCutoverFailure({
    required RestoreReceipt latest,
    required RestoreReceipt preparedReceipt,
    required Object cutoverError,
    required StackTrace cutoverStackTrace,
  }) async {
    developer.log(
      'Restore cutover failed; starting rollback.',
      name: 'Kelivo.restore.cutover',
      error: cutoverError,
      stackTrace: cutoverStackTrace,
    );
    try {
      return await _beginRollback(
        latest: latest,
        preparedReceipt: preparedReceipt,
      );
    } catch (rollbackError, rollbackStackTrace) {
      developer.log(
        'Restore rollback failed after cutover failure.',
        name: 'Kelivo.restore.cutover',
        error: rollbackError,
        stackTrace: rollbackStackTrace,
      );
      Error.throwWithStackTrace(
        RestoreCutoverRollbackException(
          cutoverError: cutoverError,
          cutoverStackTrace: cutoverStackTrace,
          rollbackError: rollbackError,
          rollbackStackTrace: rollbackStackTrace,
        ),
        rollbackStackTrace,
      );
    }
  }

  Future<RestoreReceipt> _completeRollback({
    required RestoreReceipt rollingBack,
    required RestoreReceipt preparedReceipt,
    _PreviousTransition? state,
  }) async {
    final rollbackState =
        state ?? await _loadRollbackTransition(preparedReceipt);
    await mover.rollbackToPrevious(
      receipt: rollingBack,
      candidate: rollbackState.candidate,
      settingsTransition: rollbackState.transition,
      settingsStore: settingsStore,
      previous: rollbackState.previous,
    );
    await mover.validateRolledBack(
      receipt: rollingBack,
      candidate: rollbackState.candidate,
      settingsTransition: rollbackState.transition,
      settingsStore: settingsStore,
      previous: rollbackState.previous,
    );
    final rolledBack = rollingBack.advance(RestoreReceiptState.rolledBack);
    await receiptStore.publishWhileWorkspaceLocked(rolledBack);
    return rolledBack;
  }

  Future<_PreviousTransition> _completePrevious({
    required RestoreReceipt preparedReceipt,
    required ValidatedRestoreCandidate candidate,
  }) async {
    final pendingType = await FileSystemEntity.type(
      previousStore.pendingDirectory.path,
      followLinks: false,
    );
    final previousType = await FileSystemEntity.type(
      previousStore.previousDirectory.path,
      followLinks: false,
    );
    if (pendingType != FileSystemEntityType.notFound &&
        pendingType != FileSystemEntityType.directory) {
      throw StateError('restore_cutover_pending_type');
    }
    if (previousType != FileSystemEntityType.notFound &&
        previousType != FileSystemEntityType.directory) {
      throw StateError('restore_cutover_previous_type');
    }
    if (pendingType == FileSystemEntityType.directory &&
        previousType == FileSystemEntityType.directory) {
      throw StateError('restore_cutover_previous_collision');
    }
    if (previousType == FileSystemEntityType.directory) {
      final previous = await previousStore.readPrevious(
        preparedReceipt: preparedReceipt,
      );
      await previousStore.validateComplete(previous);
      final transition = _resumeTransition(previous, candidate);
      await settingsStore.validateBefore(transition);
      return (previous: previous, transition: transition, candidate: candidate);
    }

    PersistedRestorePrevious pending;
    RestoreSettingsTransition transition;
    var validateWholeLiveBeforeMove = false;
    final manifestType = await FileSystemEntity.type(
      p.join(previousStore.pendingDirectory.path, 'manifest.json'),
      followLinks: false,
    );
    if (pendingType == FileSystemEntityType.directory &&
        manifestType == FileSystemEntityType.file) {
      pending = await previousStore.readPending(
        preparedReceipt: preparedReceipt,
      );
      transition = _resumeTransition(pending, candidate);
    } else {
      if (manifestType != FileSystemEntityType.notFound) {
        throw StateError('restore_cutover_previous_manifest_type');
      }
      transition = await settingsStore.buildTransition(
        candidateSettings: candidate.settings,
        secretsIncluded: candidate.secretsIncluded,
      );
      if (preparedReceipt.selectedComponents.contains(
        RestoreComponent.database,
      )) {
        await RestoreLiveDatabase.normalize(
          databaseFile: File(
            p.join(appDataDirectory.path, AppDatabase.databaseFileName),
          ),
          durability: durability,
        );
      }
      final bundle = await RestorePreviousBuilder.build(
        appDataDirectory: appDataDirectory,
        preparedReceipt: preparedReceipt,
        settingsTransition: transition,
      );
      pending = await previousStore.persistPending(
        bundle: bundle,
        preparedReceipt: preparedReceipt,
      );
      validateWholeLiveBeforeMove = true;
    }
    await settingsStore.validateBefore(transition);
    if (validateWholeLiveBeforeMove) {
      await RestorePreviousBuilder.validateLive(
        appDataDirectory: appDataDirectory,
        expected: pending.plan,
      );
    }
    await mover.moveLiveToPending(pending);
    final previous = await previousStore.promotePending(
      preparedReceipt: preparedReceipt,
    );
    return (previous: previous, transition: transition, candidate: candidate);
  }

  Future<_PreviousTransition> _loadPreviousTransition(
    RestoreReceipt preparedReceipt,
  ) async {
    if (await FileSystemEntity.type(
          previousStore.pendingDirectory.path,
          followLinks: false,
        ) !=
        FileSystemEntityType.notFound) {
      throw StateError('restore_cutover_pending_after_old_renamed');
    }
    final previous = await previousStore.readPrevious(
      preparedReceipt: preparedReceipt,
    );
    await previousStore.validateComplete(previous);
    final candidate = await _readCandidateManifest(preparedReceipt);
    return (
      previous: previous,
      transition: _resumeTransition(previous, candidate),
      candidate: candidate,
    );
  }

  Future<_PreviousTransition> _loadRollbackTransition(
    RestoreReceipt preparedReceipt,
  ) async {
    if (await FileSystemEntity.type(
          previousStore.pendingDirectory.path,
          followLinks: false,
        ) !=
        FileSystemEntityType.notFound) {
      throw StateError('restore_cutover_pending_during_rollback');
    }
    final previous = await previousStore.readPrevious(
      preparedReceipt: preparedReceipt,
    );
    final candidate = await _readCandidateManifest(preparedReceipt);
    return (
      previous: previous,
      transition: _resumeTransition(previous, candidate),
      candidate: candidate,
    );
  }

  RestoreSettingsTransition _resumeTransition(
    PersistedRestorePrevious previous,
    ValidatedRestoreCandidate candidate,
  ) {
    return RestoreSettingsTransition.resume(
      plan: previous.plan.settings,
      snapshotBytes: previous.settingsSnapshotBytes,
      candidateSettings: candidate.settings,
      secretsIncluded: candidate.secretsIncluded,
    );
  }

  Future<ValidatedRestoreCandidate> _readCandidateManifest(
    RestoreReceipt preparedReceipt,
  ) {
    return RestoreBundleStaging.readCandidateManifest(
      candidateDirectory: candidateDirectory,
      expectedManifestSha256: preparedReceipt.candidateManifestSha256,
    );
  }
}
