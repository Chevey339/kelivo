import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/services/backup/restore_bundle_staging.dart';
import 'package:Kelivo/core/services/backup/restore_business_lease.dart';
import 'package:Kelivo/core/services/backup/restore_cutover_executor.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_previous_store.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_settings_cold_ack.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

import 'support/restore_complete_bundle_fixture.dart';
import 'support/restore_process_control.dart';
import 'support/restore_process_hooks.dart';

const _leaseInstancePattern = r'^[a-f0-9]{32}$';

enum _BundleLocation { live, candidate, previousPending, previous }

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('executes one host-controlled restore process phase', (
    tester,
  ) async {
    if (!Platform.isMacOS) {
      throw UnsupportedError('restore_harness_macos_only');
    }
    final control = await RestoreHarnessControl.readFromEnvironment();
    _requireControlSequence(control);
    await _requireRunnerBoundary(control);
    SharedPreferences.setPrefix(control.preferencesPrefix);
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();

    switch (control) {
      case RestoreProcessHarnessControl():
        switch (control.phase) {
          case RestoreProcessHarnessPhase.setup:
            await _runSetup(control, preferences);
          case RestoreProcessHarnessPhase.cutoverKill:
            await _runCutoverKill(control, preferences);
          case RestoreProcessHarnessPhase.resumeToColdAck:
            await _runResumeToColdAck(control, preferences);
          case RestoreProcessHarnessPhase.coldFinalize:
            await _runColdFinalize(control, preferences);
        }
      case RestoreTerminalProcessHarnessControl():
        switch (control.phase) {
          case RestoreTerminalProcessHarnessPhase.setup:
            await _runSetup(control, preferences);
          case RestoreTerminalProcessHarnessPhase.commitToColdAck:
            await _runTerminalCommitToColdAck(control, preferences);
          case RestoreTerminalProcessHarnessPhase.recoverTerminal:
            await _runTerminalRecovery(control, preferences);
          case RestoreTerminalProcessHarnessPhase.verifyBusinessReady:
            await _runTerminalVerify(control, preferences);
        }
      case RestoreRollbackProcessHarnessControl():
        switch (control.phase) {
          case RestoreRollbackProcessHarnessPhase.setup:
            await _runSetup(control, preferences);
          case RestoreRollbackProcessHarnessPhase.triggerRollbackKill:
            await _runRollbackKill(control, preferences);
          case RestoreRollbackProcessHarnessPhase.recoverToColdAck:
            await _runRollbackRecoverToColdAck(control, preferences);
          case RestoreRollbackProcessHarnessPhase.verifyBusinessReady:
            await _runRollbackVerifyBusinessReady(control, preferences);
        }
    }
  });
}

Future<void> _runSetup(
  RestoreHarnessControl control,
  SharedPreferences preferences,
) async {
  await _requireMissing(control.stateFile, 'restore_harness_setup_state');
  await _requireMissing(
    control.appDataDirectory,
    'restore_harness_setup_app_data',
  );
  await _requireMissing(
    control.sourceDirectory,
    'restore_harness_setup_source',
  );
  final preferenceSeed = _preferenceSeed(control);
  for (final entry in preferenceSeed.entries) {
    if (preferences.containsKey(entry.key)) {
      throw StateError('restore_harness_setup_preference:${entry.key}');
    }
    if (!await preferences.setString(entry.key, entry.value)) {
      throw StateError('restore_harness_setup_preference_write:${entry.key}');
    }
  }
  await preferences.reload();
  for (final entry in preferenceSeed.entries) {
    expect(preferences.getString(entry.key), entry.value);
  }

  final state = await prepareCompleteBundleFixture(control);
  _requireStateBinding(control, state);
  expect(state.primaryPreferenceKey, preferenceSeed.keys.elementAt(0));
  expect(state.primaryOldPreferenceValue, preferenceSeed.values.elementAt(0));
  expect(state.secondaryPreferenceKey, preferenceSeed.keys.elementAt(1));
  expect(state.secondaryOldPreferenceValue, preferenceSeed.values.elementAt(1));
  expect(state.secretPreferenceKey, preferenceSeed.keys.elementAt(2));
  expect(state.secretOldPreferenceValue, preferenceSeed.values.elementAt(2));
  expect(
    state.targetOnlyPreferenceKey,
    'restore_harness_${control.scenarioId}_target_only',
  );
  expect(preferences.containsKey(state.targetOnlyPreferenceKey), isFalse);

  final pending = await RestoreStartupGate.inspect(
    appDataDirectory: control.appDataDirectory,
  );
  expect(pending, isNotNull);
  expect(pending!.runId, state.runId);
  expect(pending.markerFileName, RestoreWorkspaceLock.activeRunFileName);
  expect(pending.receipt.state, RestoreReceiptState.prepared);
  expect(pending.receipt.checksum, state.preparedReceiptChecksum);
  expect(
    pending.receipt.candidateManifestSha256,
    state.candidateManifestSha256,
  );
  expect(pending.receipt.selectedComponents, {
    RestoreComponent.settings,
    RestoreComponent.database,
    RestoreComponent.assets,
  });

  final receiptStore = _activeReceiptStore(control, state);
  final candidate = await RestoreBundleStaging.validateExistingCandidate(
    candidateDirectory: _candidateDirectory(receiptStore),
    expectedManifestSha256: state.candidateManifestSha256,
  );
  expect(candidate.includeChats, isTrue);
  expect(candidate.includeFiles, isTrue);
  expect(candidate.entries.keys.toSet(), {
    'settings.json',
    'database/${AppDatabase.databaseFileName}',
    for (final root in restoreHarnessAssetRoots) '$root/new.txt',
  });
  expect(await harnessConversationIds(_liveDatabase(control)), [
    state.oldConversationId,
  ]);
  expect(await harnessConversationIds(_candidateDatabase(receiptStore)), [
    state.newConversationId,
  ]);
  await _expectInitialAssets(control, receiptStore);

  await writeDurableHarnessJson(control.stateFile, state.toJson());
  await _publishEvent(control, {
    'status': 'completed',
    'runId': state.runId,
    'receiptState': RestoreReceiptState.prepared.name,
  });
}

Future<void> _runCutoverKill(
  RestoreProcessHarnessControl control,
  SharedPreferences preferences,
) async {
  final state = await _readBoundState(control);
  final setupEvent = await _readSetupEvent(control, state);
  expect(setupEvent['pid'], isNot(pid));
  _expectBeforePreferences(preferences, state);
  final pending = await RestoreStartupGate.inspect(
    appDataDirectory: control.appDataDirectory,
  );
  expect(pending, isNotNull);
  expect(pending!.runId, state.runId);
  expect(pending.markerFileName, RestoreWorkspaceLock.activeRunFileName);
  expect(pending.receipt.state, RestoreReceiptState.prepared);
  expect(pending.receipt.checksum, state.preparedReceiptChecksum);

  final receiptStore = _activeReceiptStore(control, state);
  final platformDurability = RestorePlatformDurability();
  final lease = await RestoreBusinessLease.acquire(
    appDataDirectory: control.appDataDirectory,
    durability: platformDurability,
  );
  final preferenceDelegate = SharedPreferencesStorePlatform.instance;
  Future<void> onReached(Map<String, dynamic> observation) async {
    await preferences.reload();
    await _expectForwardCrashTopology(
      control: control,
      state: state,
      preferences: preferences,
      receiptStore: receiptStore,
    );
    final history = await receiptStore.readHistoryWhileWorkspaceLocked();
    await _publishEvent(control, {
      'status': 'readyForKill',
      'marker': control.failpoint.name,
      'runId': state.runId,
      'leaseInstanceId': lease.instanceId,
      'observedReceiptState': history.last.state.name,
      ...observation,
    });
  }

  final matcher = _durabilityMatcher(control, state, receiptStore);
  final RestoreDurability durability;
  if (matcher == null) {
    durability = platformDurability;
  } else {
    durability = OneShotBlockingRestoreDurability(
      delegate: platformDurability,
      matcher: matcher,
      onMatched: (observation) =>
          onReached(_durabilityObservationJson(observation)),
    );
  }
  final settingsHook = _settingsFailpointStore(
    control: control,
    state: state,
    delegate: preferenceDelegate,
    onMatched: (observation) =>
        onReached(_preferenceObservationJson(control, observation)),
  );
  if ((matcher == null) == (settingsHook == null)) {
    throw StateError(
      'restore_harness_failpoint_trigger:${control.failpoint.name}',
    );
  }
  try {
    if (settingsHook != null) {
      SharedPreferencesStorePlatform.instance = settingsHook;
    }
    await RestoreStartupGate.recoverAndRequireBusinessReady(
      appDataDirectory: control.appDataDirectory,
      preferences: preferences,
      businessLease: lease,
      durability: durability,
    );
    throw StateError('restore_harness_cutover_returned');
  } finally {
    SharedPreferencesStorePlatform.instance = preferenceDelegate;
    await lease.close();
  }
}

Future<void> _runResumeToColdAck(
  RestoreProcessHarnessControl control,
  SharedPreferences preferences,
) async {
  final state = await _readBoundState(control);
  final cutoverEvent = await _readCutoverEvent(control, state);
  expect(cutoverEvent['pid'], isNot(pid));

  final receiptStore = _activeReceiptStore(control, state);
  await _expectForwardCrashTopology(
    control: control,
    state: state,
    preferences: preferences,
    receiptStore: receiptStore,
  );
  final pendingBefore = await RestoreStartupGate.inspect(
    appDataDirectory: control.appDataDirectory,
  );
  expect(pendingBefore, isNotNull);
  expect(pendingBefore!.runId, state.runId);
  expect(
    pendingBefore.markerFileName,
    RestoreWorkspaceLock.publishingRunFileName,
  );
  expect(
    pendingBefore.receipt.state,
    _expectedPublishedReceiptState(control.failpoint),
  );

  final durability = RestorePlatformDurability();
  final lease = await RestoreBusinessLease.acquire(
    appDataDirectory: control.appDataDirectory,
    durability: durability,
  );
  expect(lease.processId, pid);
  expect(lease.processId, isNot(cutoverEvent['pid']));
  expect(lease.instanceId, isNot(cutoverEvent['leaseInstanceId']));
  late final RestoreSettingsColdAck coldAck;
  late final RestoreReceipt terminal;
  try {
    try {
      await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: control.appDataDirectory,
        preferences: preferences,
        businessLease: lease,
        durability: durability,
      );
      throw StateError('restore_harness_resume_returned');
    } on RestoreColdRestartRequired catch (error) {
      expect(error.state, RestoreReceiptState.committed);
    }

    final pendingAfter = await RestoreStartupGate.inspect(
      appDataDirectory: control.appDataDirectory,
    );
    expect(pendingAfter, isNotNull);
    expect(pendingAfter!.runId, state.runId);
    expect(
      pendingAfter.markerFileName,
      RestoreWorkspaceLock.publishingRunFileName,
    );
    expect(pendingAfter.receipt.state, RestoreReceiptState.committed);
    terminal = pendingAfter.receipt;
    final persistedAck = await RestoreSettingsColdAckStore(
      runDirectory: receiptStore.runDirectory,
    ).read();
    expect(persistedAck, isNotNull);
    coldAck = persistedAck!;
    expect(coldAck.terminalReceiptChecksum, terminal.checksum);
    expect(coldAck.expected, RestoreSettingsColdAckExpected.target);
    expect(coldAck.processId, lease.processId);
    expect(coldAck.leaseInstanceId, lease.instanceId);
    _expectTargetPreferences(preferences, state);
    await _expectInstalledBundle(control, receiptStore, state);
  } finally {
    await lease.close();
  }
  expect(lease.isClosed, isTrue);
  await _expectNoLeaseOwnerFiles(control);

  await _publishEvent(control, {
    'status': 'completed',
    'runId': state.runId,
    'receiptState': terminal.state.name,
    'leaseInstanceId': coldAck.leaseInstanceId,
    'coldAckProcessId': coldAck.processId,
    'coldAckLeaseInstanceId': coldAck.leaseInstanceId,
  });
}

Future<void> _runColdFinalize(
  RestoreProcessHarnessControl control,
  SharedPreferences preferences,
) async {
  final state = await _readBoundState(control);
  final resumeEvent = await _readResumeEvent(control, state);
  expect(resumeEvent['pid'], isNot(pid));
  _expectTargetPreferences(preferences, state);

  final activeStore = _activeReceiptStore(control, state);
  final pending = await RestoreStartupGate.inspect(
    appDataDirectory: control.appDataDirectory,
  );
  expect(pending, isNotNull);
  expect(pending!.runId, state.runId);
  expect(pending.receipt.state, RestoreReceiptState.committed);
  final observedAck = await RestoreSettingsColdAckStore(
    runDirectory: activeStore.runDirectory,
  ).read();
  expect(observedAck, isNotNull);
  expect(observedAck!.terminalReceiptChecksum, pending.receipt.checksum);
  expect(observedAck.expected, RestoreSettingsColdAckExpected.target);
  expect(observedAck.processId, resumeEvent['coldAckProcessId']);
  expect(observedAck.leaseInstanceId, resumeEvent['coldAckLeaseInstanceId']);

  final durability = RestorePlatformDurability();
  final lease = await RestoreBusinessLease.acquire(
    appDataDirectory: control.appDataDirectory,
    durability: durability,
  );
  expect(lease.processId, pid);
  expect(lease.processId, isNot(observedAck.processId));
  expect(lease.instanceId, isNot(observedAck.leaseInstanceId));
  final preferenceDelegate = SharedPreferencesStorePlatform.instance;
  final mutationGuard = RejectingMutationPreferencesStore(preferenceDelegate);
  late final RestoreReceipt terminal;
  try {
    SharedPreferencesStorePlatform.instance = mutationGuard;
    try {
      final recovered = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: control.appDataDirectory,
        preferences: preferences,
        businessLease: lease,
        durability: durability,
      );
      expect(recovered, isNotNull);
      terminal = recovered!;
    } finally {
      SharedPreferencesStorePlatform.instance = preferenceDelegate;
    }

    expect(terminal.state, RestoreReceiptState.committed);
    expect(mutationGuard.mutationAttempts, 0);
    expect(
      await RestoreStartupGate.inspect(
        appDataDirectory: control.appDataDirectory,
      ),
      isNull,
    );
    expect(await activeStore.runDirectory.exists(), isFalse);

    final archivedStore = RestoreReceiptStore(
      appDataDirectory: control.appDataDirectory,
      runId: state.runId,
      archived: true,
    );
    expect(await archivedStore.runDirectory.exists(), isTrue);
    final history = await archivedStore.readHistory();
    expect(history.map((receipt) => receipt.state), [
      RestoreReceiptState.prepared,
      RestoreReceiptState.oldRenamed,
      RestoreReceiptState.newInstalled,
      RestoreReceiptState.verified,
      RestoreReceiptState.committed,
    ]);
    expect(history.first.checksum, state.preparedReceiptChecksum);
    expect(
      history.first.candidateManifestSha256,
      state.candidateManifestSha256,
    );
    expect(history.last.checksum, terminal.checksum);
    expect(history.last.selectedComponents, {
      RestoreComponent.settings,
      RestoreComponent.database,
      RestoreComponent.assets,
    });
    final previousStore = RestorePreviousStore(
      runDirectory: archivedStore.runDirectory,
    );
    final previous = await previousStore.readPrevious(
      preparedReceipt: history.first,
    );
    await previousStore.validateComplete(previous);
    expect(previous.manifestSha256, history.last.previousManifestSha256);
    expect(jsonDecode(utf8.decode(previous.settingsSnapshotBytes)), {
      state.primaryPreferenceKey: state.primaryOldPreferenceValue,
      state.secondaryPreferenceKey: state.secondaryOldPreferenceValue,
      state.secretPreferenceKey: state.secretOldPreferenceValue,
    });

    final archivedAck = await RestoreSettingsColdAckStore(
      runDirectory: archivedStore.runDirectory,
    ).read();
    expect(archivedAck, isNotNull);
    expect(archivedAck!.checksum, observedAck.checksum);
    await preferences.reload();
    _expectTargetPreferences(preferences, state);
    await _expectFinalArchivedBundle(control, archivedStore, state);
  } finally {
    SharedPreferencesStorePlatform.instance = preferenceDelegate;
    await lease.close();
  }
  expect(lease.isClosed, isTrue);

  await _publishEvent(control, {
    'status': 'completed',
    'runId': state.runId,
    'receiptState': terminal.state.name,
    'observedAckProcessId': observedAck.processId,
    'observedAckLeaseInstanceId': observedAck.leaseInstanceId,
    'leaseInstanceId': lease.instanceId,
    'settingsMutationAttempts': mutationGuard.mutationAttempts,
  });
  for (final key in [
    state.primaryPreferenceKey,
    state.secondaryPreferenceKey,
    state.secretPreferenceKey,
    state.targetOnlyPreferenceKey,
  ]) {
    if (preferences.containsKey(key) && !await preferences.remove(key)) {
      throw StateError('restore_harness_preference_cleanup:$key');
    }
  }
  await preferences.reload();
  expect(preferences.containsKey(state.primaryPreferenceKey), isFalse);
  expect(preferences.containsKey(state.secondaryPreferenceKey), isFalse);
  expect(preferences.containsKey(state.secretPreferenceKey), isFalse);
  expect(preferences.containsKey(state.targetOnlyPreferenceKey), isFalse);
}

Future<void> _runTerminalCommitToColdAck(
  RestoreTerminalProcessHarnessControl control,
  SharedPreferences preferences,
) async {
  final state = await _readBoundState(control);
  final setupEvent = await _readTerminalSetupEvent(control, state);
  expect(setupEvent['pid'], isNot(pid));
  _expectBeforePreferences(preferences, state);
  final pending = await RestoreStartupGate.inspect(
    appDataDirectory: control.appDataDirectory,
  );
  expect(pending?.runId, state.runId);
  expect(pending?.markerFileName, RestoreWorkspaceLock.activeRunFileName);
  expect(pending?.receipt.state, RestoreReceiptState.prepared);

  final platformDurability = RestorePlatformDurability();
  final lease = await RestoreBusinessLease.acquire(
    appDataDirectory: control.appDataDirectory,
    durability: platformDurability,
  );
  expect(lease.processId, pid);
  expect(lease.processId, isNot(setupEvent['pid']));
  if (_isTerminalColdAckFailpoint(control.failpoint)) {
    try {
      final terminal = await _convergeCommittedWithoutColdAck(
        control: control,
        state: state,
        preferences: preferences,
        durability: platformDurability,
      );
      final receiptStore = _activeReceiptStore(control, state);
      final ackStore = RestoreSettingsColdAckStore(
        runDirectory: receiptStore.runDirectory,
        durability: platformDurability,
      );
      expect(await ackStore.read(), isNull);
      final matcher = _terminalColdAckMatcher(
        control: control,
        state: state,
        terminal: terminal,
        lease: lease,
      );
      final durability = OneShotBlockingRestoreDurability(
        delegate: platformDurability,
        matcher: matcher,
        onMatched: (observation) async {
          final coldAck = observation as RestoreColdAckDurabilityObservation;
          await preferences.reload();
          _expectTargetPreferences(preferences, state);
          final history = await receiptStore.readHistoryWhileWorkspaceLocked();
          expect(history.last.state, RestoreReceiptState.committed);
          expect(history.last.checksum, terminal.checksum);
          expect(coldAck.terminalReceiptChecksum, terminal.checksum);
          expect(coldAck.processId, lease.processId);
          expect(coldAck.leaseInstanceId, lease.instanceId);
          await _expectInstalledBundle(control, receiptStore, state);
          await _expectTerminalColdAckCrashTopology(
            control: control,
            state: state,
            terminal: terminal,
            observation: coldAck,
          );
          await _publishEvent(control, {
            'status': 'readyForKill',
            'marker': control.failpoint.name,
            'runId': state.runId,
            'leaseInstanceId': lease.instanceId,
            'observedReceiptState': history.last.state.name,
            ..._durabilityObservationJson(coldAck),
          });
        },
      );
      await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: control.appDataDirectory,
        preferences: preferences,
        businessLease: lease,
        durability: durability,
      );
      throw StateError('restore_terminal_harness_ack_returned');
    } finally {
      await lease.close();
    }
  }

  late final RestoreReceipt terminal;
  late final RestoreSettingsColdAck coldAck;
  try {
    try {
      await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: control.appDataDirectory,
        preferences: preferences,
        businessLease: lease,
        durability: platformDurability,
      );
      throw StateError('restore_terminal_harness_arm_returned');
    } on RestoreColdRestartRequired catch (error) {
      expect(error.state, RestoreReceiptState.committed);
    }
    final armed = await RestoreStartupGate.inspect(
      appDataDirectory: control.appDataDirectory,
    );
    expect(armed?.runId, state.runId);
    expect(armed?.markerFileName, RestoreWorkspaceLock.publishingRunFileName);
    expect(armed?.receipt.state, RestoreReceiptState.committed);
    terminal = armed!.receipt;
    final receiptStore = _activeReceiptStore(control, state);
    final persistedAck = await RestoreSettingsColdAckStore(
      runDirectory: receiptStore.runDirectory,
      durability: platformDurability,
    ).read();
    expect(persistedAck, isNotNull);
    coldAck = persistedAck!;
    expect(coldAck.terminalReceiptChecksum, terminal.checksum);
    expect(coldAck.expected, RestoreSettingsColdAckExpected.target);
    expect(coldAck.processId, lease.processId);
    expect(coldAck.leaseInstanceId, lease.instanceId);
    await preferences.reload();
    _expectTargetPreferences(preferences, state);
    await _expectInstalledBundle(control, receiptStore, state);
  } finally {
    await lease.close();
  }
  await _expectNoLeaseOwnerFiles(control);
  await _publishEvent(control, {
    'status': 'completed',
    'runId': state.runId,
    'receiptState': terminal.state.name,
    'leaseInstanceId': coldAck.leaseInstanceId,
    'coldAckProcessId': coldAck.processId,
    'coldAckLeaseInstanceId': coldAck.leaseInstanceId,
    'coldAckChecksum': coldAck.checksum,
    'terminalReceiptChecksum': terminal.checksum,
  });
}

Future<RestoreReceipt> _convergeCommittedWithoutColdAck({
  required RestoreTerminalProcessHarnessControl control,
  required RestoreCompleteBundleFixtureState state,
  required SharedPreferences preferences,
  required RestoreDurability durability,
}) async {
  final workspaceLock = RestoreWorkspaceLock(
    appDataDirectory: control.appDataDirectory,
    durability: durability,
  );
  return workspaceLock.synchronized(() async {
    final executor = RestoreCutoverExecutor(
      appDataDirectory: control.appDataDirectory,
      runId: state.runId,
      preferences: preferences,
      workspaceLock: workspaceLock,
      durability: durability,
    );
    final result = await executor.executeWhileWorkspaceLocked(
      observedMarkerFileName: RestoreWorkspaceLock.activeRunFileName,
    );
    expect(result.state, RestoreReceiptState.committed);
    return executor.revalidateTerminalWhileWorkspaceLocked(result);
  });
}

RestoreDurabilityMatcher _terminalColdAckMatcher({
  required RestoreTerminalProcessHarnessControl control,
  required RestoreCompleteBundleFixtureState state,
  required RestoreReceipt terminal,
  required RestoreBusinessLease lease,
}) {
  final runDirectory = _activeReceiptStore(control, state).runDirectory.path;
  return switch (control.failpoint) {
    RestoreTerminalProcessFailpoint.coldAckTempDurable =>
      RestoreColdAckTempDurableMatcher(
        runDirectoryPath: _absolutePath(runDirectory),
        terminalReceiptChecksum: terminal.checksum,
        expected: RestoreSettingsColdAckExpected.target,
        processId: lease.processId,
        leaseInstanceId: lease.instanceId,
      ),
    RestoreTerminalProcessFailpoint.coldAckPublished =>
      RestoreColdAckPublishedMatcher(
        runDirectoryPath: _absolutePath(runDirectory),
        terminalReceiptChecksum: terminal.checksum,
        expected: RestoreSettingsColdAckExpected.target,
        processId: lease.processId,
        leaseInstanceId: lease.instanceId,
      ),
    _ => throw StateError('restore_terminal_harness_ack_failpoint'),
  };
}

bool _isTerminalColdAckFailpoint(RestoreTerminalProcessFailpoint failpoint) =>
    failpoint == RestoreTerminalProcessFailpoint.coldAckTempDurable ||
    failpoint == RestoreTerminalProcessFailpoint.coldAckPublished;

Future<void> _runTerminalRecovery(
  RestoreTerminalProcessHarnessControl control,
  SharedPreferences preferences,
) => _isTerminalColdAckFailpoint(control.failpoint)
    ? _recoverTerminalColdAck(control, preferences)
    : _runTerminalArchiveKill(control, preferences);

Future<void> _recoverTerminalColdAck(
  RestoreTerminalProcessHarnessControl control,
  SharedPreferences preferences,
) async {
  final state = await _readBoundState(control);
  final killEvent = await _readTerminalCommitEvent(control, state);
  expect(killEvent['pid'], isNot(pid));
  await _expectTerminalColdAckTopologyFromEvent(
    control: control,
    state: state,
    event: killEvent,
  );
  await preferences.reload();
  _expectTargetPreferences(preferences, state);

  final durability = RestorePlatformDurability();
  final lease = await RestoreBusinessLease.acquire(
    appDataDirectory: control.appDataDirectory,
    durability: durability,
  );
  expect(lease.processId, pid);
  expect(lease.processId, isNot(killEvent['pid']));
  expect(lease.instanceId, isNot(killEvent['leaseInstanceId']));
  final preferenceDelegate = SharedPreferencesStorePlatform.instance;
  final mutationCounter = CountingMutationPreferencesStore(preferenceDelegate);
  RestoreReceipt? gateResult;
  late final String outcome;
  try {
    SharedPreferencesStorePlatform.instance = mutationCounter;
    try {
      gateResult = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: control.appDataDirectory,
        preferences: preferences,
        businessLease: lease,
        durability: durability,
      );
      expect(gateResult?.state, RestoreReceiptState.committed);
      outcome = 'archived';
    } on RestoreColdRestartRequired catch (error) {
      expect(error.state, RestoreReceiptState.committed);
      outcome = 'coldRestartRequired';
    } finally {
      SharedPreferencesStorePlatform.instance = preferenceDelegate;
    }
    if (control.failpoint ==
        RestoreTerminalProcessFailpoint.coldAckTempDurable) {
      expect(outcome, 'coldRestartRequired');
      expect(mutationCounter.mutationAttempts, greaterThan(0));
    } else {
      expect(outcome, 'archived');
      expect(mutationCounter.mutationAttempts, 0);
    }

    final archived = outcome == 'archived';
    final store = RestoreReceiptStore(
      appDataDirectory: control.appDataDirectory,
      runId: state.runId,
      archived: archived,
    );
    final ack = await RestoreSettingsColdAckStore(
      runDirectory: store.runDirectory,
      durability: durability,
    ).read();
    expect(ack, isNotNull);
    expect(ack!.terminalReceiptChecksum, killEvent['terminalReceiptChecksum']);
    expect(ack.expected, RestoreSettingsColdAckExpected.target);
    if (outcome == 'coldRestartRequired') {
      expect(ack.processId, lease.processId);
      expect(ack.leaseInstanceId, lease.instanceId);
      final pending = await RestoreStartupGate.inspect(
        appDataDirectory: control.appDataDirectory,
      );
      expect(pending?.runId, state.runId);
      expect(pending?.receipt.state, RestoreReceiptState.committed);
      expect(
        pending?.markerFileName,
        RestoreWorkspaceLock.publishingRunFileName,
      );
      await _expectInstalledBundle(control, store, state);
    } else {
      expect(ack.processId, killEvent['ackProcessId']);
      expect(ack.leaseInstanceId, killEvent['ackLeaseInstanceId']);
      await _expectArchivedTerminalEvidence(
        control: control,
        state: state,
        expectedAck: ack,
      );
    }
    await _publishEvent(control, {
      'status': 'completed',
      'runId': state.runId,
      'receiptState': RestoreReceiptState.committed.name,
      'outcome': outcome,
      'leaseInstanceId': lease.instanceId,
      'ackProcessId': ack.processId,
      'ackLeaseInstanceId': ack.leaseInstanceId,
      'terminalReceiptChecksum': ack.terminalReceiptChecksum,
      'settingsMutationAttempts': mutationCounter.mutationAttempts,
    });
  } finally {
    SharedPreferencesStorePlatform.instance = preferenceDelegate;
    await lease.close();
  }
  await _expectNoLeaseOwnerFiles(control);
}

Future<void> _runTerminalArchiveKill(
  RestoreTerminalProcessHarnessControl control,
  SharedPreferences preferences,
) async {
  final state = await _readBoundState(control);
  final armEvent = await _readTerminalCommitEvent(control, state);
  expect(armEvent['pid'], isNot(pid));
  final activeStore = _activeReceiptStore(control, state);
  final pending = await RestoreStartupGate.inspect(
    appDataDirectory: control.appDataDirectory,
  );
  expect(pending?.runId, state.runId);
  expect(pending?.receipt.state, RestoreReceiptState.committed);
  expect(pending?.markerFileName, RestoreWorkspaceLock.publishingRunFileName);
  final observedAck = await RestoreSettingsColdAckStore(
    runDirectory: activeStore.runDirectory,
  ).read();
  expect(observedAck, isNotNull);
  expect(observedAck!.checksum, armEvent['coldAckChecksum']);
  expect(observedAck.processId, armEvent['coldAckProcessId']);
  expect(observedAck.leaseInstanceId, armEvent['coldAckLeaseInstanceId']);
  await preferences.reload();
  _expectTargetPreferences(preferences, state);
  await _expectInstalledBundle(control, activeStore, state);

  final platformDurability = RestorePlatformDurability();
  final lease = await RestoreBusinessLease.acquire(
    appDataDirectory: control.appDataDirectory,
    durability: platformDurability,
  );
  expect(lease.processId, pid);
  expect(lease.processId, isNot(observedAck.processId));
  expect(lease.instanceId, isNot(observedAck.leaseInstanceId));
  final preferenceDelegate = SharedPreferencesStorePlatform.instance;
  final mutationGuard = RejectingMutationPreferencesStore(preferenceDelegate);
  final matcher = _terminalArchiveMatcher(control, state);
  final durability = OneShotBlockingRestoreDurability(
    delegate: platformDurability,
    matcher: matcher,
    onMatched: (observation) async {
      expect(mutationGuard.mutationAttempts, 0);
      await preferences.reload();
      _expectTargetPreferences(preferences, state);
      await _expectTerminalArchiveCrashTopology(
        control: control,
        state: state,
        expectedAck: observedAck,
      );
      await _publishEvent(control, {
        'status': 'readyForKill',
        'marker': control.failpoint.name,
        'runId': state.runId,
        'leaseInstanceId': lease.instanceId,
        'observedReceiptState': RestoreReceiptState.committed.name,
        'coldAckProcessId': observedAck.processId,
        'coldAckLeaseInstanceId': observedAck.leaseInstanceId,
        'ackProcessId': observedAck.processId,
        'ackLeaseInstanceId': observedAck.leaseInstanceId,
        'terminalReceiptChecksum': observedAck.terminalReceiptChecksum,
        'settingsMutationAttempts': mutationGuard.mutationAttempts,
        ..._durabilityObservationJson(observation),
      });
    },
  );
  try {
    SharedPreferencesStorePlatform.instance = mutationGuard;
    await RestoreStartupGate.recoverAndRequireBusinessReady(
      appDataDirectory: control.appDataDirectory,
      preferences: preferences,
      businessLease: lease,
      durability: durability,
    );
    throw StateError('restore_terminal_harness_archive_returned');
  } finally {
    SharedPreferencesStorePlatform.instance = preferenceDelegate;
    await lease.close();
  }
}

RestoreDurabilityMatcher _terminalArchiveMatcher(
  RestoreTerminalProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
) {
  final store = _activeReceiptStore(control, state);
  final workspace = _absolutePath(store.workspaceRoot.path);
  final activeRun = _absolutePath(store.runDirectory.path);
  final completedRun = _absolutePath(
    RestoreReceiptStore(
      appDataDirectory: control.appDataDirectory,
      runId: state.runId,
      archived: true,
    ).runDirectory.path,
  );
  return switch (control.failpoint) {
    RestoreTerminalProcessFailpoint.completedRunsRootDurable =>
      RestoreTerminalWorkspaceSyncMatcher(
        workspaceRootPath: workspace,
        runId: state.runId,
        boundary: RestoreTerminalWorkspaceSyncBoundary.completedRunsRootDurable,
      ),
    RestoreTerminalProcessFailpoint.archivingMarkerPublished =>
      RestoreExactRenameMatcher(
        sourcePath: _absolutePath(
          p.join(workspace, RestoreWorkspaceLock.publishingRunFileName),
        ),
        targetPath: _absolutePath(
          p.join(workspace, RestoreWorkspaceLock.archivingRunFileName),
        ),
        sourceKind: RestoreProcessEntityKind.file,
      ),
    RestoreTerminalProcessFailpoint.terminalRunArchived =>
      RestoreExactRenameMatcher(
        sourcePath: activeRun,
        targetPath: completedRun,
        sourceKind: RestoreProcessEntityKind.directory,
      ),
    RestoreTerminalProcessFailpoint.archivingMarkerRemovedDurable =>
      RestoreTerminalWorkspaceSyncMatcher(
        workspaceRootPath: workspace,
        runId: state.runId,
        boundary:
            RestoreTerminalWorkspaceSyncBoundary.archivingMarkerRemovedDurable,
      ),
    _ => throw StateError('restore_terminal_harness_archive_failpoint'),
  };
}

Future<void> _runTerminalVerify(
  RestoreTerminalProcessHarnessControl control,
  SharedPreferences preferences,
) async {
  final state = await _readBoundState(control);
  final priorEvent = await _readTerminalRecoveryEvent(control, state);
  expect(priorEvent['pid'], isNot(pid));
  await preferences.reload();
  _expectTargetPreferences(preferences, state);

  final durability = RestorePlatformDurability();
  final lease = await RestoreBusinessLease.acquire(
    appDataDirectory: control.appDataDirectory,
    durability: durability,
  );
  expect(lease.processId, pid);
  expect(lease.processId, isNot(priorEvent['pid']));
  expect(lease.instanceId, isNot(priorEvent['leaseInstanceId']));
  final preferenceDelegate = SharedPreferencesStorePlatform.instance;
  final mutationGuard = RejectingMutationPreferencesStore(preferenceDelegate);
  RestoreReceipt? gateResult;
  try {
    SharedPreferencesStorePlatform.instance = mutationGuard;
    try {
      gateResult = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: control.appDataDirectory,
        preferences: preferences,
        businessLease: lease,
        durability: durability,
      );
    } finally {
      SharedPreferencesStorePlatform.instance = preferenceDelegate;
    }
    final expectNoGateResult =
        (_isTerminalColdAckFailpoint(control.failpoint) &&
            priorEvent['outcome'] == 'archived') ||
        control.failpoint ==
            RestoreTerminalProcessFailpoint.archivingMarkerRemovedDurable;
    if (expectNoGateResult) {
      expect(gateResult, isNull);
    } else {
      expect(gateResult?.state, RestoreReceiptState.committed);
    }
    expect(mutationGuard.mutationAttempts, 0);
    final expectedAck = RestoreSettingsColdAck(
      runId: state.runId,
      terminalReceiptChecksum: priorEvent['terminalReceiptChecksum'] as String,
      expected: RestoreSettingsColdAckExpected.target,
      leaseInstanceId: priorEvent['ackLeaseInstanceId'] as String,
      processId: priorEvent['ackProcessId'] as int,
    );
    final evidence = await _expectArchivedTerminalEvidence(
      control: control,
      state: state,
      expectedAck: expectedAck,
    );
    await _publishEvent(control, {
      'status': 'completed',
      'runId': state.runId,
      'receiptState': evidence.terminal.state.name,
      'gateResult': gateResult?.state.name ?? 'none',
      'observedAckProcessId': evidence.ack.processId,
      'observedAckLeaseInstanceId': evidence.ack.leaseInstanceId,
      'leaseInstanceId': lease.instanceId,
      'settingsMutationAttempts': mutationGuard.mutationAttempts,
    });
  } finally {
    SharedPreferencesStorePlatform.instance = preferenceDelegate;
    await lease.close();
  }
  await _expectNoLeaseOwnerFiles(control);
  for (final key in [
    state.primaryPreferenceKey,
    state.secondaryPreferenceKey,
    state.secretPreferenceKey,
    state.targetOnlyPreferenceKey,
  ]) {
    if (preferences.containsKey(key) && !await preferences.remove(key)) {
      throw StateError('restore_terminal_harness_preference_cleanup:$key');
    }
  }
  await preferences.reload();
  expect(preferences.containsKey(state.primaryPreferenceKey), isFalse);
  expect(preferences.containsKey(state.secondaryPreferenceKey), isFalse);
  expect(preferences.containsKey(state.secretPreferenceKey), isFalse);
  expect(preferences.containsKey(state.targetOnlyPreferenceKey), isFalse);
}

Future<void> _runRollbackKill(
  RestoreRollbackProcessHarnessControl control,
  SharedPreferences preferences,
) async {
  final state = await _readBoundState(control);
  final setupEvent = await _readRollbackSetupEvent(control, state);
  expect(setupEvent['pid'], isNot(pid));
  _expectBeforePreferences(preferences, state);
  final pending = await RestoreStartupGate.inspect(
    appDataDirectory: control.appDataDirectory,
  );
  expect(pending?.runId, state.runId);
  expect(pending?.receipt.state, RestoreReceiptState.prepared);
  expect(pending?.markerFileName, RestoreWorkspaceLock.activeRunFileName);

  final receiptStore = _activeReceiptStore(control, state);
  final platformDurability = RestorePlatformDurability();
  final lease = await RestoreBusinessLease.acquire(
    appDataDirectory: control.appDataDirectory,
    durability: platformDurability,
  );
  final preferenceDelegate = SharedPreferencesStorePlatform.instance;
  final trigger = NthExactSetFailurePreferencesStore(
    delegate: preferenceDelegate,
    prefixedKey: '${control.preferencesPrefix}${state.primaryPreferenceKey}',
    failOnMatch: 3,
  );

  Future<void> onReached(Map<String, dynamic> observation) async {
    expect(trigger.didFail, isTrue);
    expect(trigger.successfulMatches, 2);
    await preferences.reload();
    final history = await receiptStore.readHistoryWhileWorkspaceLocked();
    await _expectRollbackCrashTopology(
      control: control,
      state: state,
      preferences: preferences,
      receiptStore: receiptStore,
      history: history,
    );
    await _publishEvent(control, {
      'status': 'readyForKill',
      'marker': control.failpoint.name,
      'runId': state.runId,
      'leaseInstanceId': lease.instanceId,
      'rollbackOriginReceiptState': RestoreReceiptState.verified.name,
      'triggerKind': 'repeatedTargetSetRejected',
      'triggerPreferenceKey': state.primaryPreferenceKey,
      'triggerFailureCount': 1,
      'observedReceiptState': history.last.state.name,
      ...observation,
    });
  }

  final matcher = _rollbackDurabilityMatcher(control, state, receiptStore);
  final durability = matcher == null
      ? platformDurability
      : OneShotBlockingRestoreDurability(
          delegate: platformDurability,
          matcher: matcher,
          onMatched: (observation) =>
              onReached(_durabilityObservationJson(observation)),
        );
  final settingsBlocker = _rollbackSettingsBlocker(
    control: control,
    state: state,
    delegate: trigger,
    isArmed: () => trigger.didFail,
    onMatched: (observation) =>
        onReached(_preferenceObservationJson(control, observation)),
  );
  if ((matcher == null) == (settingsBlocker == null)) {
    throw StateError(
      'restore_rollback_harness_failpoint_trigger:${control.failpoint.name}',
    );
  }
  try {
    SharedPreferencesStorePlatform.instance = settingsBlocker ?? trigger;
    await RestoreStartupGate.recoverAndRequireBusinessReady(
      appDataDirectory: control.appDataDirectory,
      preferences: preferences,
      businessLease: lease,
      durability: durability,
    );
    throw StateError('restore_rollback_harness_kill_returned');
  } finally {
    SharedPreferencesStorePlatform.instance = preferenceDelegate;
    await lease.close();
  }
}

Future<void> _runRollbackRecoverToColdAck(
  RestoreRollbackProcessHarnessControl control,
  SharedPreferences preferences,
) async {
  final state = await _readBoundState(control);
  final killEvent = await _readRollbackKillEvent(control, state);
  expect(killEvent['pid'], isNot(pid));
  await preferences.reload();
  final receiptStore = _activeReceiptStore(control, state);
  await _expectRollbackCrashTopology(
    control: control,
    state: state,
    preferences: preferences,
    receiptStore: receiptStore,
    history: await receiptStore.readHistory(),
  );

  final durability = RestorePlatformDurability();
  final lease = await RestoreBusinessLease.acquire(
    appDataDirectory: control.appDataDirectory,
    durability: durability,
  );
  expect(lease.processId, pid);
  expect(lease.processId, isNot(killEvent['pid']));
  expect(lease.instanceId, isNot(killEvent['leaseInstanceId']));
  final preferenceDelegate = SharedPreferencesStorePlatform.instance;
  final mutationCounter = CountingMutationPreferencesStore(preferenceDelegate);
  final repeatsVerifiedFailure =
      control.failpoint ==
      RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable;
  final repeatedTrigger = repeatsVerifiedFailure
      ? NthExactSetFailurePreferencesStore(
          delegate: mutationCounter,
          prefixedKey:
              '${control.preferencesPrefix}${state.primaryPreferenceKey}',
          failOnMatch: 1,
        )
      : null;
  late final RestoreReceipt terminal;
  try {
    SharedPreferencesStorePlatform.instance =
        repeatedTrigger ?? mutationCounter;
    try {
      await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: control.appDataDirectory,
        preferences: preferences,
        businessLease: lease,
        durability: durability,
      );
      throw StateError('restore_rollback_harness_recovery_returned');
    } on RestoreColdRestartRequired catch (error) {
      expect(error.state, RestoreReceiptState.rolledBack);
    } finally {
      SharedPreferencesStorePlatform.instance = preferenceDelegate;
    }
    expect(repeatedTrigger?.didFail ?? false, repeatsVerifiedFailure);
    expect(mutationCounter.mutationAttempts, greaterThan(0));
    final pending = await RestoreStartupGate.inspect(
      appDataDirectory: control.appDataDirectory,
    );
    expect(pending?.runId, state.runId);
    expect(pending?.markerFileName, RestoreWorkspaceLock.publishingRunFileName);
    expect(pending?.receipt.state, RestoreReceiptState.rolledBack);
    terminal = pending!.receipt;
    final ack = await RestoreSettingsColdAckStore(
      runDirectory: receiptStore.runDirectory,
      durability: durability,
    ).read();
    expect(ack, isNotNull);
    expect(ack!.terminalReceiptChecksum, terminal.checksum);
    expect(ack.expected, RestoreSettingsColdAckExpected.before);
    expect(ack.processId, lease.processId);
    expect(ack.leaseInstanceId, lease.instanceId);
    await preferences.reload();
    _expectBeforePreferences(preferences, state);
    await _expectRolledBackActiveEvidence(
      control: control,
      state: state,
      receiptStore: receiptStore,
      expectedAck: ack,
    );
    await _publishEvent(control, {
      'status': 'completed',
      'runId': state.runId,
      'receiptState': terminal.state.name,
      'outcome': 'coldRestartRequired',
      'leaseInstanceId': lease.instanceId,
      'terminalReceiptChecksum': terminal.checksum,
      'ackExpected': ack.expected.name,
      'ackProcessId': ack.processId,
      'ackLeaseInstanceId': ack.leaseInstanceId,
      'coldAckChecksum': ack.checksum,
      'settingsMutationAttempts': mutationCounter.mutationAttempts,
      'triggerFailureCount': repeatedTrigger?.didFail == true ? 1 : 0,
    });
  } finally {
    SharedPreferencesStorePlatform.instance = preferenceDelegate;
    await lease.close();
  }
  await _expectNoLeaseOwnerFiles(control);
}

Future<void> _runRollbackVerifyBusinessReady(
  RestoreRollbackProcessHarnessControl control,
  SharedPreferences preferences,
) async {
  final state = await _readBoundState(control);
  final recoveryEvent = await _readRollbackRecoveryEvent(control, state);
  expect(recoveryEvent['pid'], isNot(pid));
  await preferences.reload();
  _expectBeforePreferences(preferences, state);

  final durability = RestorePlatformDurability();
  final lease = await RestoreBusinessLease.acquire(
    appDataDirectory: control.appDataDirectory,
    durability: durability,
  );
  expect(lease.processId, pid);
  expect(lease.processId, isNot(recoveryEvent['pid']));
  expect(lease.instanceId, isNot(recoveryEvent['leaseInstanceId']));
  final preferenceDelegate = SharedPreferencesStorePlatform.instance;
  final mutationGuard = RejectingMutationPreferencesStore(preferenceDelegate);
  late final RestoreReceipt terminal;
  try {
    SharedPreferencesStorePlatform.instance = mutationGuard;
    try {
      final result = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: control.appDataDirectory,
        preferences: preferences,
        businessLease: lease,
        durability: durability,
      );
      expect(result?.state, RestoreReceiptState.rolledBack);
      terminal = result!;
    } finally {
      SharedPreferencesStorePlatform.instance = preferenceDelegate;
    }
    expect(mutationGuard.mutationAttempts, 0);
    final expectedAck = RestoreSettingsColdAck(
      runId: state.runId,
      terminalReceiptChecksum:
          recoveryEvent['terminalReceiptChecksum'] as String,
      expected: RestoreSettingsColdAckExpected.before,
      leaseInstanceId: recoveryEvent['ackLeaseInstanceId'] as String,
      processId: recoveryEvent['ackProcessId'] as int,
    );
    final evidence = await _expectArchivedRolledBackEvidence(
      control: control,
      state: state,
      expectedAck: expectedAck,
    );
    expect(terminal.checksum, evidence.terminal.checksum);
    await _publishEvent(control, {
      'status': 'completed',
      'runId': state.runId,
      'receiptState': evidence.terminal.state.name,
      'gateResult': terminal.state.name,
      'archiveState': 'archived',
      'observedAckProcessId': evidence.ack.processId,
      'observedAckLeaseInstanceId': evidence.ack.leaseInstanceId,
      'observedAckChecksum': evidence.ack.checksum,
      'leaseInstanceId': lease.instanceId,
      'settingsMutationAttempts': mutationGuard.mutationAttempts,
    });
  } finally {
    SharedPreferencesStorePlatform.instance = preferenceDelegate;
    await lease.close();
  }
  await _expectNoLeaseOwnerFiles(control);
  for (final key in [
    state.primaryPreferenceKey,
    state.secondaryPreferenceKey,
    state.secretPreferenceKey,
    state.targetOnlyPreferenceKey,
  ]) {
    if (preferences.containsKey(key) && !await preferences.remove(key)) {
      throw StateError('restore_rollback_harness_preference_cleanup:$key');
    }
  }
  await preferences.reload();
  expect(preferences.containsKey(state.primaryPreferenceKey), isFalse);
  expect(preferences.containsKey(state.secondaryPreferenceKey), isFalse);
  expect(preferences.containsKey(state.secretPreferenceKey), isFalse);
  expect(preferences.containsKey(state.targetOnlyPreferenceKey), isFalse);
}

Future<void> _expectRollbackCrashTopology({
  required RestoreRollbackProcessHarnessControl control,
  required RestoreCompleteBundleFixtureState state,
  required SharedPreferences preferences,
  required RestoreReceiptStore receiptStore,
  required List<RestoreReceipt> history,
}) async {
  final expectedState = _rollbackObservedReceiptState(control.failpoint);
  expect(
    history.map((receipt) => receipt.state),
    _rollbackHistory(expectedState),
  );
  expect(history.first.checksum, state.preparedReceiptChecksum);
  expect(history.first.candidateManifestSha256, state.candidateManifestSha256);
  expect(history.last.state, expectedState);
  expect(
    history.last.previousManifestSha256,
    isNotEmpty,
    reason: control.failpoint.name,
  );
  await _expectExactTerminalMarkers(
    receiptStore.workspaceRoot,
    runId: state.runId,
    expectedMarker: RestoreWorkspaceLock.publishingRunFileName,
  );
  expect(await receiptStore.runDirectory.exists(), isTrue);
  expect(
    await RestoreReceiptStore(
      appDataDirectory: control.appDataDirectory,
      runId: state.runId,
      archived: true,
    ).runDirectory.exists(),
    isFalse,
  );
  await _expectRollbackReceiptTemporaries(
    control: control,
    receiptStore: receiptStore,
    history: history,
    canonicalComplete: false,
  );
  await _expectRollbackDatabaseTopology(control, state, receiptStore);
  await _expectRollbackAssetTopology(control, receiptStore);
  _expectRollbackCrashPreferences(preferences, state, control.failpoint);
}

Future<void> _expectRollbackDatabaseTopology(
  RestoreRollbackProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
  RestoreReceiptStore receiptStore,
) async {
  final live = _liveDatabase(control);
  final candidate = _candidateDatabase(receiptStore);
  final previous = File(
    p.join(
      _previousDirectory(receiptStore).path,
      'database',
      AppDatabase.databaseFileName,
    ),
  );
  final returned = _rollbackHasReached(
    control.failpoint,
    RestoreRollbackProcessFailpoint.newDatabaseReturnedToCandidate,
  );
  final restored = _rollbackHasReached(
    control.failpoint,
    RestoreRollbackProcessFailpoint.previousDatabaseRestoredToLive,
  );
  if (!returned) {
    expect(await harnessConversationIds(live), [state.newConversationId]);
    expect(await candidate.exists(), isFalse);
    expect(await harnessConversationIds(previous), [state.oldConversationId]);
  } else if (!restored) {
    expect(await live.exists(), isFalse);
    expect(await harnessConversationIds(candidate), [state.newConversationId]);
    expect(await harnessConversationIds(previous), [state.oldConversationId]);
  } else {
    expect(await harnessConversationIds(live), [state.oldConversationId]);
    expect(await harnessConversationIds(candidate), [state.newConversationId]);
    expect(await previous.exists(), isFalse);
    final previousDatabaseDirectory = previous.parent;
    if (control.failpoint ==
        RestoreRollbackProcessFailpoint.previousDatabaseRestoredToLive) {
      expect(await previousDatabaseDirectory.exists(), isTrue);
      expect(
        await previousDatabaseDirectory.list(followLinks: false).isEmpty,
        isTrue,
      );
    } else {
      expect(await previousDatabaseDirectory.exists(), isFalse);
    }
  }
  for (final database in [live, candidate, previous]) {
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      expect(await File('${database.path}$suffix').exists(), isFalse);
    }
  }
}

Future<void> _expectRollbackAssetTopology(
  RestoreRollbackProcessHarnessControl control,
  RestoreReceiptStore receiptStore,
) async {
  final candidate = _candidateDirectory(receiptStore);
  final previous = _previousDirectory(receiptStore);
  for (final root in restoreHarnessAssetRoots) {
    final newReturned = _rollbackHasReached(
      control.failpoint,
      _rollbackNewAssetFailpoint(root),
    );
    final oldRestored = _rollbackHasReached(
      control.failpoint,
      _rollbackOldAssetFailpoint(root),
    );
    final liveRoot = Directory(p.join(control.appDataDirectory.path, root));
    final candidateRoot = Directory(p.join(candidate.path, root));
    final previousRoot = Directory(p.join(previous.path, root));
    if (!newReturned) {
      expect(
        await File(p.join(liveRoot.path, 'new.txt')).readAsString(),
        'new:$root',
      );
      expect(await candidateRoot.exists(), isFalse);
      expect(
        await File(p.join(previousRoot.path, 'old.txt')).readAsString(),
        'old:$root',
      );
    } else if (!oldRestored) {
      expect(await liveRoot.exists(), isFalse);
      expect(
        await File(p.join(candidateRoot.path, 'new.txt')).readAsString(),
        'new:$root',
      );
      expect(
        await File(p.join(previousRoot.path, 'old.txt')).readAsString(),
        'old:$root',
      );
    } else {
      expect(
        await File(p.join(liveRoot.path, 'old.txt')).readAsString(),
        'old:$root',
      );
      expect(
        await File(p.join(candidateRoot.path, 'new.txt')).readAsString(),
        'new:$root',
      );
      expect(await previousRoot.exists(), isFalse);
    }
  }
}

void _expectRollbackCrashPreferences(
  SharedPreferences preferences,
  RestoreCompleteBundleFixtureState state,
  RestoreRollbackProcessFailpoint failpoint,
) {
  if (!_rollbackHasReached(
    failpoint,
    RestoreRollbackProcessFailpoint.settingsFirstRestored,
  )) {
    _expectTargetPreferences(preferences, state);
    return;
  }
  expect(
    preferences.getString(state.primaryPreferenceKey),
    state.primaryOldPreferenceValue,
  );
  if (failpoint == RestoreRollbackProcessFailpoint.settingsFirstRestored) {
    expect(
      preferences.getString(state.secondaryPreferenceKey),
      state.secondaryNewPreferenceValue,
    );
    expect(preferences.containsKey(state.secretPreferenceKey), isFalse);
    expect(
      preferences.getString(state.targetOnlyPreferenceKey),
      state.targetOnlyNewPreferenceValue,
    );
    return;
  }
  expect(
    preferences.getString(state.secondaryPreferenceKey),
    state.secondaryOldPreferenceValue,
  );
  expect(
    preferences.getString(state.secretPreferenceKey),
    state.secretOldPreferenceValue,
  );
  if (failpoint == RestoreRollbackProcessFailpoint.settingsSecretRestored) {
    expect(
      preferences.getString(state.targetOnlyPreferenceKey),
      state.targetOnlyNewPreferenceValue,
    );
    return;
  }
  _expectBeforePreferences(preferences, state);
}

Future<void> _expectRollbackReceiptTemporaries({
  required RestoreRollbackProcessHarnessControl control,
  required RestoreReceiptStore receiptStore,
  required List<RestoreReceipt> history,
  required bool canonicalComplete,
}) async {
  final expectedSequence = switch (control.failpoint) {
    RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable => 5,
    RestoreRollbackProcessFailpoint.rolledBackReceiptTempDurable => 6,
    _ => null,
  };
  final temporaryPattern = RegExp(
    r'^receipt_([0-9]{16})\.json\.([1-9][0-9]*)_([1-9][0-9]*)\.tmp$',
  );
  final temporaries = <File>[];
  await for (final entity in receiptStore.receiptDirectory.list(
    followLinks: false,
  )) {
    final name = p.basename(entity.path);
    if (temporaryPattern.hasMatch(name)) temporaries.add(File(entity.path));
  }
  if (expectedSequence == null) {
    expect(temporaries, isEmpty);
    return;
  }
  expect(temporaries, hasLength(1));
  final match = temporaryPattern.firstMatch(
    p.basename(temporaries.single.path),
  );
  expect(int.parse(match![1]!), expectedSequence);
  final decoded = jsonDecode(await temporaries.single.readAsString());
  expect(decoded, isA<Map>());
  final temporaryReceipt = RestoreReceipt.fromJson(decoded as Map);
  expect(temporaryReceipt.sequence, expectedSequence);
  expect(
    temporaryReceipt.state,
    expectedSequence == 5
        ? RestoreReceiptState.rollingBack
        : RestoreReceiptState.rolledBack,
  );
  if (canonicalComplete) {
    final canonical = history.singleWhere(
      (receipt) => receipt.sequence == expectedSequence,
    );
    expect(temporaryReceipt.checksum, canonical.checksum);
    expect(temporaryReceipt.previousChecksum, canonical.previousChecksum);
  } else {
    expect(temporaryReceipt.previousChecksum, history.last.checksum);
    expect(history.last.sequence, expectedSequence - 1);
  }
}

Future<void> _expectRolledBackActiveEvidence({
  required RestoreRollbackProcessHarnessControl control,
  required RestoreCompleteBundleFixtureState state,
  required RestoreReceiptStore receiptStore,
  required RestoreSettingsColdAck expectedAck,
}) async {
  final history = await receiptStore.readHistory();
  expect(
    history.map((receipt) => receipt.state),
    _rollbackHistory(RestoreReceiptState.rolledBack),
  );
  expect(history.first.checksum, state.preparedReceiptChecksum);
  expect(history.last.checksum, expectedAck.terminalReceiptChecksum);
  await _expectRollbackReceiptTemporaries(
    control: control,
    receiptStore: receiptStore,
    history: history,
    canonicalComplete: true,
  );
  await _expectRolledBackBundle(control, state, receiptStore, history);
  final ack = await RestoreSettingsColdAckStore(
    runDirectory: receiptStore.runDirectory,
  ).read();
  expect(ack?.checksum, expectedAck.checksum);
}

Future<({RestoreReceipt terminal, RestoreSettingsColdAck ack})>
_expectArchivedRolledBackEvidence({
  required RestoreRollbackProcessHarnessControl control,
  required RestoreCompleteBundleFixtureState state,
  required RestoreSettingsColdAck expectedAck,
}) async {
  expect(
    await RestoreStartupGate.inspect(
      appDataDirectory: control.appDataDirectory,
    ),
    isNull,
  );
  expect(
    await _activeReceiptStore(control, state).runDirectory.exists(),
    isFalse,
  );
  final archivedStore = RestoreReceiptStore(
    appDataDirectory: control.appDataDirectory,
    runId: state.runId,
    archived: true,
  );
  expect(await archivedStore.runDirectory.exists(), isTrue);
  final history = await archivedStore.readHistory();
  expect(
    history.map((receipt) => receipt.state),
    _rollbackHistory(RestoreReceiptState.rolledBack),
  );
  await _expectRollbackReceiptTemporaries(
    control: control,
    receiptStore: archivedStore,
    history: history,
    canonicalComplete: true,
  );
  await _expectRolledBackBundle(control, state, archivedStore, history);
  final ack = await RestoreSettingsColdAckStore(
    runDirectory: archivedStore.runDirectory,
  ).read();
  expect(ack, isNotNull);
  expect(ack!.checksum, expectedAck.checksum);
  expect(ack.expected, RestoreSettingsColdAckExpected.before);
  expect(ack.terminalReceiptChecksum, history.last.checksum);
  return (terminal: history.last, ack: ack);
}

Future<void> _expectRolledBackBundle(
  RestoreRollbackProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
  RestoreReceiptStore receiptStore,
  List<RestoreReceipt> history,
) async {
  expect(await harnessConversationIds(_liveDatabase(control)), [
    state.oldConversationId,
  ]);
  expect(await harnessConversationIds(_candidateDatabase(receiptStore)), [
    state.newConversationId,
  ]);
  for (final database in [
    _liveDatabase(control),
    _candidateDatabase(receiptStore),
  ]) {
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      expect(await File('${database.path}$suffix').exists(), isFalse);
    }
  }
  for (final root in restoreHarnessAssetRoots) {
    expect(
      await File(
        p.join(control.appDataDirectory.path, root, 'old.txt'),
      ).readAsString(),
      'old:$root',
    );
    expect(
      await File(
        p.join(_candidateDirectory(receiptStore).path, root, 'new.txt'),
      ).readAsString(),
      'new:$root',
    );
  }
  final previousStore = RestorePreviousStore(
    runDirectory: receiptStore.runDirectory,
  );
  final previous = await previousStore.readPrevious(
    preparedReceipt: history.first,
  );
  await previousStore.validateControlOnlyAfterRollback(previous);
  expect(previous.manifestSha256, history.last.previousManifestSha256);
  expect(jsonDecode(utf8.decode(previous.settingsSnapshotBytes)), {
    state.primaryPreferenceKey: state.primaryOldPreferenceValue,
    state.secondaryPreferenceKey: state.secondaryOldPreferenceValue,
    state.secretPreferenceKey: state.secretOldPreferenceValue,
  });
}

List<RestoreReceiptState> _rollbackHistory(RestoreReceiptState last) {
  return switch (last) {
    RestoreReceiptState.verified => const [
      RestoreReceiptState.prepared,
      RestoreReceiptState.oldRenamed,
      RestoreReceiptState.newInstalled,
      RestoreReceiptState.verified,
    ],
    RestoreReceiptState.rollingBack => const [
      RestoreReceiptState.prepared,
      RestoreReceiptState.oldRenamed,
      RestoreReceiptState.newInstalled,
      RestoreReceiptState.verified,
      RestoreReceiptState.rollingBack,
    ],
    RestoreReceiptState.rolledBack => const [
      RestoreReceiptState.prepared,
      RestoreReceiptState.oldRenamed,
      RestoreReceiptState.newInstalled,
      RestoreReceiptState.verified,
      RestoreReceiptState.rollingBack,
      RestoreReceiptState.rolledBack,
    ],
    _ => throw StateError('restore_rollback_harness_history'),
  };
}

RestoreReceiptState _rollbackObservedReceiptState(
  RestoreRollbackProcessFailpoint failpoint,
) {
  if (failpoint ==
      RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable) {
    return RestoreReceiptState.verified;
  }
  if (failpoint == RestoreRollbackProcessFailpoint.rolledBackReceiptPublished) {
    return RestoreReceiptState.rolledBack;
  }
  return RestoreReceiptState.rollingBack;
}

bool _rollbackHasReached(
  RestoreRollbackProcessFailpoint current,
  RestoreRollbackProcessFailpoint boundary,
) => current.index >= boundary.index;

RestoreRollbackProcessFailpoint _rollbackNewAssetFailpoint(String root) {
  return switch (root) {
    'upload' => RestoreRollbackProcessFailpoint.newUploadReturnedToCandidate,
    'images' => RestoreRollbackProcessFailpoint.newImagesReturnedToCandidate,
    'avatars' => RestoreRollbackProcessFailpoint.newAvatarsReturnedToCandidate,
    'fonts' => RestoreRollbackProcessFailpoint.newFontsReturnedToCandidate,
    _ => throw StateError('restore_rollback_harness_asset_root'),
  };
}

RestoreRollbackProcessFailpoint _rollbackOldAssetFailpoint(String root) {
  return switch (root) {
    'upload' => RestoreRollbackProcessFailpoint.previousUploadRestoredToLive,
    'images' => RestoreRollbackProcessFailpoint.previousImagesRestoredToLive,
    'avatars' => RestoreRollbackProcessFailpoint.previousAvatarsRestoredToLive,
    'fonts' => RestoreRollbackProcessFailpoint.previousFontsRestoredToLive,
    _ => throw StateError('restore_rollback_harness_asset_root'),
  };
}

Future<void> _expectTerminalColdAckCrashTopology({
  required RestoreTerminalProcessHarnessControl control,
  required RestoreCompleteBundleFixtureState state,
  required RestoreReceipt terminal,
  required RestoreColdAckDurabilityObservation observation,
}) => _expectTerminalColdAckTopology(
  control: control,
  state: state,
  boundary: observation.boundary,
  terminalReceiptChecksum: terminal.checksum,
  ackProcessId: observation.processId,
  ackLeaseInstanceId: observation.leaseInstanceId,
  ackChecksum: observation.ackChecksum,
  temporaryPath: observation.temporaryPath,
  targetPath:
      observation.targetPath ??
      p.join(
        p.dirname(observation.temporaryPath),
        RestoreSettingsColdAckStore.fileName,
      ),
);

Future<void> _expectTerminalColdAckTopologyFromEvent({
  required RestoreTerminalProcessHarnessControl control,
  required RestoreCompleteBundleFixtureState state,
  required Map<String, dynamic> event,
}) => _expectTerminalColdAckTopology(
  control: control,
  state: state,
  boundary:
      control.failpoint == RestoreTerminalProcessFailpoint.coldAckTempDurable
      ? RestoreColdAckDurabilityBoundary.tempDurable
      : RestoreColdAckDurabilityBoundary.published,
  terminalReceiptChecksum: event['terminalReceiptChecksum'] as String,
  ackProcessId: event['ackProcessId'] as int,
  ackLeaseInstanceId: event['ackLeaseInstanceId'] as String,
  ackChecksum: event['ackChecksum'] as String,
  temporaryPath: event['temporaryPath'] as String,
  targetPath: event['targetPath'] as String,
);

Future<void> _expectTerminalColdAckTopology({
  required RestoreTerminalProcessHarnessControl control,
  required RestoreCompleteBundleFixtureState state,
  required RestoreColdAckDurabilityBoundary boundary,
  required String terminalReceiptChecksum,
  required int ackProcessId,
  required String ackLeaseInstanceId,
  required String ackChecksum,
  required String temporaryPath,
  required String targetPath,
}) async {
  final store = _activeReceiptStore(control, state);
  await _expectExactTerminalMarkers(
    store.workspaceRoot,
    runId: state.runId,
    expectedMarker: RestoreWorkspaceLock.publishingRunFileName,
  );
  expect(await store.runDirectory.exists(), isTrue);
  expect(
    await RestoreReceiptStore(
      appDataDirectory: control.appDataDirectory,
      runId: state.runId,
      archived: true,
    ).runDirectory.exists(),
    isFalse,
  );
  final history = await store.readHistoryWhileWorkspaceLocked();
  expect(history.last.state, RestoreReceiptState.committed);
  expect(history.last.checksum, terminalReceiptChecksum);
  final ackTarget = File(
    p.join(store.runDirectory.path, RestoreSettingsColdAckStore.fileName),
  );
  expect(_absolutePath(ackTarget.path), targetPath);
  final temporaryFiles = <File>[];
  await for (final entity in store.runDirectory.list(followLinks: false)) {
    if (p
        .basename(entity.path)
        .startsWith('${RestoreSettingsColdAckStore.fileName}.')) {
      expect(entity, isA<File>());
      temporaryFiles.add(File(entity.path));
    }
  }
  final RestoreSettingsColdAck ack;
  switch (boundary) {
    case RestoreColdAckDurabilityBoundary.tempDurable:
      expect(await ackTarget.exists(), isFalse);
      expect(temporaryFiles, hasLength(1));
      expect(_absolutePath(temporaryFiles.single.path), temporaryPath);
      final decoded = jsonDecode(await temporaryFiles.single.readAsString());
      expect(decoded, isA<Map>());
      ack = RestoreSettingsColdAck.fromJson(decoded as Map);
    case RestoreColdAckDurabilityBoundary.published:
      expect(temporaryFiles, isEmpty);
      final persisted = await RestoreSettingsColdAckStore(
        runDirectory: store.runDirectory,
      ).read();
      expect(persisted, isNotNull);
      ack = persisted!;
  }
  expect(ack.runId, state.runId);
  expect(ack.terminalReceiptChecksum, terminalReceiptChecksum);
  expect(ack.expected, RestoreSettingsColdAckExpected.target);
  expect(ack.processId, ackProcessId);
  expect(ack.leaseInstanceId, ackLeaseInstanceId);
  expect(ack.checksum, ackChecksum);
  await _expectInstalledBundle(control, store, state);
}

Future<void> _expectTerminalArchiveCrashTopology({
  required RestoreTerminalProcessHarnessControl control,
  required RestoreCompleteBundleFixtureState state,
  required RestoreSettingsColdAck expectedAck,
}) async {
  final runInCompleted =
      control.failpoint ==
          RestoreTerminalProcessFailpoint.terminalRunArchived ||
      control.failpoint ==
          RestoreTerminalProcessFailpoint.archivingMarkerRemovedDurable;
  final store = RestoreReceiptStore(
    appDataDirectory: control.appDataDirectory,
    runId: state.runId,
    archived: runInCompleted,
  );
  final expectedMarker = switch (control.failpoint) {
    RestoreTerminalProcessFailpoint.completedRunsRootDurable =>
      RestoreWorkspaceLock.publishingRunFileName,
    RestoreTerminalProcessFailpoint.archivingMarkerPublished ||
    RestoreTerminalProcessFailpoint.terminalRunArchived =>
      RestoreWorkspaceLock.archivingRunFileName,
    RestoreTerminalProcessFailpoint.archivingMarkerRemovedDurable => null,
    _ => throw StateError('restore_terminal_harness_archive_topology'),
  };
  await _expectExactTerminalMarkers(
    store.workspaceRoot,
    runId: state.runId,
    expectedMarker: expectedMarker,
  );
  final activeStore = _activeReceiptStore(control, state);
  final archivedStore = RestoreReceiptStore(
    appDataDirectory: control.appDataDirectory,
    runId: state.runId,
    archived: true,
  );
  expect(await activeStore.runDirectory.exists(), !runInCompleted);
  expect(await archivedStore.runDirectory.exists(), runInCompleted);
  expect(await archivedStore.runDirectory.parent.exists(), isTrue);
  final history = await store.readHistoryWhileWorkspaceLocked();
  expect(history.map((receipt) => receipt.state), [
    RestoreReceiptState.prepared,
    RestoreReceiptState.oldRenamed,
    RestoreReceiptState.newInstalled,
    RestoreReceiptState.verified,
    RestoreReceiptState.committed,
  ]);
  final ack = await RestoreSettingsColdAckStore(
    runDirectory: store.runDirectory,
  ).read();
  expect(ack?.checksum, expectedAck.checksum);
  await _expectInstalledBundle(control, store, state);
}

Future<void> _expectExactTerminalMarkers(
  Directory workspaceRoot, {
  required String runId,
  required String? expectedMarker,
}) async {
  for (final marker in const {
    RestoreWorkspaceLock.activeRunFileName,
    RestoreWorkspaceLock.publishingRunFileName,
    RestoreWorkspaceLock.discardingRunFileName,
    RestoreWorkspaceLock.archivingRunFileName,
  }) {
    final file = File(p.join(workspaceRoot.path, marker));
    if (marker == expectedMarker) {
      expect(await file.readAsString(), runId);
    } else {
      expect(await file.exists(), isFalse);
    }
  }
}

Future<({RestoreReceipt terminal, RestoreSettingsColdAck ack})>
_expectArchivedTerminalEvidence({
  required RestoreHarnessControl control,
  required RestoreCompleteBundleFixtureState state,
  required RestoreSettingsColdAck expectedAck,
}) async {
  expect(
    await RestoreStartupGate.inspect(
      appDataDirectory: control.appDataDirectory,
    ),
    isNull,
  );
  final activeStore = _activeReceiptStore(control, state);
  expect(await activeStore.runDirectory.exists(), isFalse);
  final archivedStore = RestoreReceiptStore(
    appDataDirectory: control.appDataDirectory,
    runId: state.runId,
    archived: true,
  );
  expect(await archivedStore.runDirectory.exists(), isTrue);
  final history = await archivedStore.readHistory();
  expect(history.map((receipt) => receipt.state), [
    RestoreReceiptState.prepared,
    RestoreReceiptState.oldRenamed,
    RestoreReceiptState.newInstalled,
    RestoreReceiptState.verified,
    RestoreReceiptState.committed,
  ]);
  expect(history.first.checksum, state.preparedReceiptChecksum);
  expect(history.first.candidateManifestSha256, state.candidateManifestSha256);
  final terminal = history.last;
  expect(terminal.selectedComponents, {
    RestoreComponent.settings,
    RestoreComponent.database,
    RestoreComponent.assets,
  });
  final previousStore = RestorePreviousStore(
    runDirectory: archivedStore.runDirectory,
  );
  final previous = await previousStore.readPrevious(
    preparedReceipt: history.first,
  );
  await previousStore.validateComplete(previous);
  expect(previous.manifestSha256, terminal.previousManifestSha256);
  expect(jsonDecode(utf8.decode(previous.settingsSnapshotBytes)), {
    state.primaryPreferenceKey: state.primaryOldPreferenceValue,
    state.secondaryPreferenceKey: state.secondaryOldPreferenceValue,
    state.secretPreferenceKey: state.secretOldPreferenceValue,
  });
  final ack = await RestoreSettingsColdAckStore(
    runDirectory: archivedStore.runDirectory,
  ).read();
  expect(ack, isNotNull);
  expect(ack!.runId, state.runId);
  expect(ack.terminalReceiptChecksum, terminal.checksum);
  expect(ack.expected, RestoreSettingsColdAckExpected.target);
  expect(ack.processId, expectedAck.processId);
  expect(ack.leaseInstanceId, expectedAck.leaseInstanceId);
  await _expectFinalArchivedBundle(control, archivedStore, state);
  return (terminal: terminal, ack: ack);
}

void _expectTargetPreferences(
  SharedPreferences preferences,
  RestoreCompleteBundleFixtureState state,
) {
  expect(
    preferences.getString(state.primaryPreferenceKey),
    state.primaryNewPreferenceValue,
  );
  expect(
    preferences.getString(state.secondaryPreferenceKey),
    state.secondaryNewPreferenceValue,
  );
  expect(preferences.containsKey(state.secretPreferenceKey), isFalse);
  expect(
    preferences.getString(state.targetOnlyPreferenceKey),
    state.targetOnlyNewPreferenceValue,
  );
}

Future<RestoreCompleteBundleFixtureState> _readBoundState(
  RestoreHarnessControl control,
) async {
  final state = await RestoreCompleteBundleFixtureState.read(control);
  _requireStateBinding(control, state);
  return state;
}

void _requireStateBinding(
  RestoreHarnessControl control,
  RestoreCompleteBundleFixtureState state,
) {
  final seed = _preferenceSeed(control);
  if (state.matrixRunId != control.matrixRunId ||
      state.failpoint != control.failpointName ||
      state.primaryPreferenceKey != seed.keys.elementAt(0) ||
      state.primaryOldPreferenceValue != seed.values.elementAt(0) ||
      state.secondaryPreferenceKey != seed.keys.elementAt(1) ||
      state.secondaryOldPreferenceValue != seed.values.elementAt(1) ||
      state.secretPreferenceKey != seed.keys.elementAt(2) ||
      state.secretOldPreferenceValue != seed.values.elementAt(2) ||
      state.targetOnlyPreferenceKey !=
          'restore_harness_${control.scenarioId}_target_only' ||
      state.targetOnlyNewPreferenceValue != 'new-target-only' ||
      state.oldConversationId != 'old-${control.scenarioId}' ||
      state.newConversationId != 'new-${control.scenarioId}' ||
      !RegExp(r'^[a-f0-9]{32}$').hasMatch(state.runId) ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(state.preparedReceiptChecksum) ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(state.candidateManifestSha256)) {
    throw const FormatException('restore_harness_state_binding');
  }
}

Map<String, String> _preferenceSeed(RestoreHarnessControl control) => {
  'restore_harness_${control.scenarioId}_primary': 'old-primary',
  'restore_harness_${control.scenarioId}_secondary': 'old-secondary',
  'restore_harness_${control.scenarioId}_secret_api_key': 'old-secret',
};

void _requireControlSequence(RestoreHarnessControl control) {
  final expectedGeneration = switch (control) {
    RestoreProcessHarnessControl() => control.phase.index + 1,
    RestoreTerminalProcessHarnessControl() => control.phase.index + 1,
    RestoreRollbackProcessHarnessControl() => control.phase.index + 1,
    _ => throw StateError('restore_harness_control_type'),
  };
  if (control.generation != expectedGeneration) {
    throw StateError('restore_harness_control_sequence');
  }
}

Future<void> _requireRunnerBoundary(RestoreHarnessControl control) async {
  final systemTemporary = p.normalize(
    p.absolute(await Directory.systemTemp.resolveSymbolicLinks()),
  );
  final scenarioRoot = p.normalize(
    p.absolute(await control.rootDirectory.resolveSymbolicLinks()),
  );
  if (!p.isWithin(systemTemporary, scenarioRoot) ||
      p.basename(scenarioRoot) !=
          'kelivo_restore_process_${control.scenarioId}') {
    throw StateError('restore_harness_runner_boundary');
  }
}

RestoreReceiptStore _activeReceiptStore(
  RestoreHarnessControl control,
  RestoreCompleteBundleFixtureState state,
) {
  return RestoreReceiptStore(
    appDataDirectory: control.appDataDirectory,
    runId: state.runId,
  );
}

Directory _candidateDirectory(RestoreReceiptStore store) =>
    Directory(p.join(store.runDirectory.path, 'candidate'));

File _candidateDatabase(RestoreReceiptStore store) => File(
  p.join(
    _candidateDirectory(store).path,
    'database',
    AppDatabase.databaseFileName,
  ),
);

File _liveDatabase(RestoreHarnessControl control) =>
    File(p.join(control.appDataDirectory.path, AppDatabase.databaseFileName));

Directory _previousDirectory(RestoreReceiptStore store) => Directory(
  p.join(store.runDirectory.path, RestorePreviousStore.previousDirectoryName),
);

Directory _previousPendingDirectory(RestoreReceiptStore store) => Directory(
  p.join(store.runDirectory.path, RestorePreviousStore.pendingDirectoryName),
);

RestoreDurabilityMatcher? _rollbackDurabilityMatcher(
  RestoreRollbackProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
  RestoreReceiptStore receiptStore,
) {
  final candidate = _candidateDirectory(receiptStore);
  final previous = _previousDirectory(receiptStore);
  final liveDatabase = _liveDatabase(control);
  final candidateDatabase = _candidateDatabase(receiptStore);
  final previousDatabase = File(
    p.join(previous.path, 'database', AppDatabase.databaseFileName),
  );
  return switch (control.failpoint) {
    RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable =>
      RestoreReceiptTempDurableMatcher(
        receiptDirectoryPath: _absolutePath(receiptStore.receiptDirectory.path),
        sequence: 5,
        state: RestoreReceiptState.rollingBack,
      ),
    RestoreRollbackProcessFailpoint.rollingBackReceiptPublished =>
      RestoreReceiptPublishedMatcher(
        receiptDirectoryPath: _absolutePath(receiptStore.receiptDirectory.path),
        sequence: 5,
        state: RestoreReceiptState.rollingBack,
      ),
    RestoreRollbackProcessFailpoint.newDatabaseReturnedToCandidate =>
      RestoreExactRenameMatcher(
        sourcePath: _absolutePath(liveDatabase.path),
        targetPath: _absolutePath(candidateDatabase.path),
        sourceKind: RestoreProcessEntityKind.file,
      ),
    RestoreRollbackProcessFailpoint.previousDatabaseRestoredToLive =>
      RestoreExactRenameMatcher(
        sourcePath: _absolutePath(previousDatabase.path),
        targetPath: _absolutePath(liveDatabase.path),
        sourceKind: RestoreProcessEntityKind.file,
      ),
    RestoreRollbackProcessFailpoint.previousDatabaseParentRemovedDurable =>
      RestoreRollbackDatabaseParentSyncMatcher(
        previousDirectoryPath: _absolutePath(previous.path),
        previousDatabaseDirectoryPath: _absolutePath(
          previousDatabase.parent.path,
        ),
        candidateDatabasePath: _absolutePath(candidateDatabase.path),
        liveDatabasePath: _absolutePath(liveDatabase.path),
      ),
    RestoreRollbackProcessFailpoint.newUploadReturnedToCandidate ||
    RestoreRollbackProcessFailpoint.newImagesReturnedToCandidate ||
    RestoreRollbackProcessFailpoint.newAvatarsReturnedToCandidate ||
    RestoreRollbackProcessFailpoint.newFontsReturnedToCandidate =>
      RestoreExactRenameMatcher(
        sourcePath: _absolutePath(
          p.join(
            control.appDataDirectory.path,
            _rollbackAssetRoot(control.failpoint),
          ),
        ),
        targetPath: _absolutePath(
          p.join(candidate.path, _rollbackAssetRoot(control.failpoint)),
        ),
        sourceKind: RestoreProcessEntityKind.directory,
      ),
    RestoreRollbackProcessFailpoint.previousUploadRestoredToLive ||
    RestoreRollbackProcessFailpoint.previousImagesRestoredToLive ||
    RestoreRollbackProcessFailpoint.previousAvatarsRestoredToLive ||
    RestoreRollbackProcessFailpoint.previousFontsRestoredToLive =>
      RestoreExactRenameMatcher(
        sourcePath: _absolutePath(
          p.join(previous.path, _rollbackAssetRoot(control.failpoint)),
        ),
        targetPath: _absolutePath(
          p.join(
            control.appDataDirectory.path,
            _rollbackAssetRoot(control.failpoint),
          ),
        ),
        sourceKind: RestoreProcessEntityKind.directory,
      ),
    RestoreRollbackProcessFailpoint.rolledBackReceiptTempDurable =>
      RestoreReceiptTempDurableMatcher(
        receiptDirectoryPath: _absolutePath(receiptStore.receiptDirectory.path),
        sequence: 6,
        state: RestoreReceiptState.rolledBack,
      ),
    RestoreRollbackProcessFailpoint.rolledBackReceiptPublished =>
      RestoreReceiptPublishedMatcher(
        receiptDirectoryPath: _absolutePath(receiptStore.receiptDirectory.path),
        sequence: 6,
        state: RestoreReceiptState.rolledBack,
      ),
    RestoreRollbackProcessFailpoint.settingsFirstRestored ||
    RestoreRollbackProcessFailpoint.settingsSecretRestored ||
    RestoreRollbackProcessFailpoint.settingsTargetOnlyRemoved => null,
  };
}

OneShotBlockingPreferencesStore? _rollbackSettingsBlocker({
  required RestoreRollbackProcessHarnessControl control,
  required RestoreCompleteBundleFixtureState state,
  required SharedPreferencesStorePlatform delegate,
  required bool Function() isArmed,
  required Future<void> Function(
    RestorePreferenceMutationObservation observation,
  )
  onMatched,
}) {
  final (key, kind) = switch (control.failpoint) {
    RestoreRollbackProcessFailpoint.settingsFirstRestored => (
      state.primaryPreferenceKey,
      RestorePreferenceMutationKind.set,
    ),
    RestoreRollbackProcessFailpoint.settingsSecretRestored => (
      state.secretPreferenceKey,
      RestorePreferenceMutationKind.set,
    ),
    RestoreRollbackProcessFailpoint.settingsTargetOnlyRemoved => (
      state.targetOnlyPreferenceKey,
      RestorePreferenceMutationKind.remove,
    ),
    _ => (null, null),
  };
  if (key == null || kind == null) return null;
  return OneShotBlockingPreferencesStore(
    delegate: delegate,
    prefixedKey: '${control.preferencesPrefix}$key',
    mutationKind: kind,
    isArmed: isArmed,
    onMatched: onMatched,
  );
}

String _rollbackAssetRoot(RestoreRollbackProcessFailpoint failpoint) {
  return switch (failpoint) {
    RestoreRollbackProcessFailpoint.newUploadReturnedToCandidate ||
    RestoreRollbackProcessFailpoint.previousUploadRestoredToLive => 'upload',
    RestoreRollbackProcessFailpoint.newImagesReturnedToCandidate ||
    RestoreRollbackProcessFailpoint.previousImagesRestoredToLive => 'images',
    RestoreRollbackProcessFailpoint.newAvatarsReturnedToCandidate ||
    RestoreRollbackProcessFailpoint.previousAvatarsRestoredToLive => 'avatars',
    RestoreRollbackProcessFailpoint.newFontsReturnedToCandidate ||
    RestoreRollbackProcessFailpoint.previousFontsRestoredToLive => 'fonts',
    _ => throw StateError('restore_rollback_harness_asset_failpoint'),
  };
}

RestoreDurabilityMatcher? _durabilityMatcher(
  RestoreProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
  RestoreReceiptStore receiptStore,
) {
  final candidate = _candidateDirectory(receiptStore);
  final pending = _previousPendingDirectory(receiptStore);
  final previous = _previousDirectory(receiptStore);
  final liveDatabase = _liveDatabase(control);
  return switch (control.failpoint) {
    RestoreProcessFailpoint.cutoverClaimPublished => RestoreExactRenameMatcher(
      sourcePath: _absolutePath(
        p.join(
          receiptStore.workspaceRoot.path,
          RestoreWorkspaceLock.activeRunFileName,
        ),
      ),
      targetPath: _absolutePath(
        p.join(
          receiptStore.workspaceRoot.path,
          RestoreWorkspaceLock.publishingRunFileName,
        ),
      ),
      sourceKind: RestoreProcessEntityKind.file,
    ),
    RestoreProcessFailpoint.liveDatabaseNormalized =>
      RestoreExactDirectorySyncMatcher(
        path: _absolutePath(control.appDataDirectory.path),
        fullBarrier: true,
      ),
    RestoreProcessFailpoint.previousSettingsPublished =>
      RestoreExactRenameMatcher(
        sourcePath: _absolutePath(
          p.join(pending.path, '${RestorePreviousStore.settingsFileName}.tmp'),
        ),
        targetPath: _absolutePath(
          p.join(pending.path, RestorePreviousStore.settingsFileName),
        ),
        sourceKind: RestoreProcessEntityKind.file,
      ),
    RestoreProcessFailpoint.previousManifestPublished =>
      RestoreExactRenameMatcher(
        sourcePath: _absolutePath(
          p.join(pending.path, '${RestorePreviousStore.manifestFileName}.tmp'),
        ),
        targetPath: _absolutePath(
          p.join(pending.path, RestorePreviousStore.manifestFileName),
        ),
        sourceKind: RestoreProcessEntityKind.file,
      ),
    RestoreProcessFailpoint.previousUploadMoved ||
    RestoreProcessFailpoint.previousImagesMoved ||
    RestoreProcessFailpoint.previousAvatarsMoved ||
    RestoreProcessFailpoint.previousFontsMoved => RestoreExactRenameMatcher(
      sourcePath: _absolutePath(
        p.join(
          control.appDataDirectory.path,
          _assetRootForFailpoint(control.failpoint),
        ),
      ),
      targetPath: _absolutePath(
        p.join(pending.path, _assetRootForFailpoint(control.failpoint)),
      ),
      sourceKind: RestoreProcessEntityKind.directory,
    ),
    RestoreProcessFailpoint.previousDatabaseMoved => RestoreExactRenameMatcher(
      sourcePath: _absolutePath(liveDatabase.path),
      targetPath: _absolutePath(
        p.join(pending.path, 'database', AppDatabase.databaseFileName),
      ),
      sourceKind: RestoreProcessEntityKind.file,
    ),
    RestoreProcessFailpoint.previousPromoted => RestoreExactRenameMatcher(
      sourcePath: _absolutePath(pending.path),
      targetPath: _absolutePath(previous.path),
      sourceKind: RestoreProcessEntityKind.directory,
    ),
    RestoreProcessFailpoint.oldRenamedReceiptTempDurable =>
      RestoreReceiptTempDurableMatcher(
        receiptDirectoryPath: _absolutePath(receiptStore.receiptDirectory.path),
        sequence: 2,
        state: RestoreReceiptState.oldRenamed,
      ),
    RestoreProcessFailpoint.oldRenamedReceiptPublished =>
      RestoreReceiptPublishedMatcher(
        receiptDirectoryPath: _absolutePath(receiptStore.receiptDirectory.path),
        sequence: 2,
        state: RestoreReceiptState.oldRenamed,
      ),
    RestoreProcessFailpoint.settingsSecretRemoved ||
    RestoreProcessFailpoint.settingsFirstSet => null,
    RestoreProcessFailpoint.candidateDatabaseMoved => RestoreExactRenameMatcher(
      sourcePath: _absolutePath(_candidateDatabase(receiptStore).path),
      targetPath: _absolutePath(liveDatabase.path),
      sourceKind: RestoreProcessEntityKind.file,
    ),
    RestoreProcessFailpoint.candidateUploadMoved ||
    RestoreProcessFailpoint.candidateImagesMoved ||
    RestoreProcessFailpoint.candidateAvatarsMoved ||
    RestoreProcessFailpoint.candidateFontsMoved => RestoreExactRenameMatcher(
      sourcePath: _absolutePath(
        p.join(candidate.path, _assetRootForFailpoint(control.failpoint)),
      ),
      targetPath: _absolutePath(
        p.join(
          control.appDataDirectory.path,
          _assetRootForFailpoint(control.failpoint),
        ),
      ),
      sourceKind: RestoreProcessEntityKind.directory,
    ),
    RestoreProcessFailpoint.newInstalledReceiptTempDurable =>
      RestoreReceiptTempDurableMatcher(
        receiptDirectoryPath: _absolutePath(receiptStore.receiptDirectory.path),
        sequence: 3,
        state: RestoreReceiptState.newInstalled,
      ),
    RestoreProcessFailpoint.newInstalledReceiptPublished =>
      RestoreReceiptPublishedMatcher(
        receiptDirectoryPath: _absolutePath(receiptStore.receiptDirectory.path),
        sequence: 3,
        state: RestoreReceiptState.newInstalled,
      ),
    RestoreProcessFailpoint.verifiedReceiptTempDurable =>
      RestoreReceiptTempDurableMatcher(
        receiptDirectoryPath: _absolutePath(receiptStore.receiptDirectory.path),
        sequence: 4,
        state: RestoreReceiptState.verified,
      ),
    RestoreProcessFailpoint.verifiedReceiptPublished =>
      RestoreReceiptPublishedMatcher(
        receiptDirectoryPath: _absolutePath(receiptStore.receiptDirectory.path),
        sequence: 4,
        state: RestoreReceiptState.verified,
      ),
    RestoreProcessFailpoint.committedReceiptTempDurable =>
      RestoreReceiptTempDurableMatcher(
        receiptDirectoryPath: _absolutePath(receiptStore.receiptDirectory.path),
        sequence: 5,
        state: RestoreReceiptState.committed,
      ),
    RestoreProcessFailpoint.committedReceiptPublished =>
      RestoreReceiptPublishedMatcher(
        receiptDirectoryPath: _absolutePath(receiptStore.receiptDirectory.path),
        sequence: 5,
        state: RestoreReceiptState.committed,
      ),
  };
}

OneShotBlockingPreferencesStore? _settingsFailpointStore({
  required RestoreProcessHarnessControl control,
  required RestoreCompleteBundleFixtureState state,
  required SharedPreferencesStorePlatform delegate,
  required Future<void> Function(
    RestorePreferenceMutationObservation observation,
  )
  onMatched,
}) {
  return switch (control.failpoint) {
    RestoreProcessFailpoint.settingsSecretRemoved =>
      OneShotBlockingPreferencesStore(
        delegate: delegate,
        prefixedKey: '${control.preferencesPrefix}${state.secretPreferenceKey}',
        mutationKind: RestorePreferenceMutationKind.remove,
        onMatched: onMatched,
      ),
    RestoreProcessFailpoint.settingsFirstSet => OneShotBlockingPreferencesStore(
      delegate: delegate,
      prefixedKey: '${control.preferencesPrefix}${state.primaryPreferenceKey}',
      mutationKind: RestorePreferenceMutationKind.set,
      onMatched: onMatched,
    ),
    _ => null,
  };
}

Map<String, dynamic> _durabilityObservationJson(
  RestoreDurabilityObservation observation,
) {
  return switch (observation) {
    RestoreRenameObservation() => {
      'operationKind': 'renameAfter',
      'sourcePath': observation.sourcePath,
      'targetPath': observation.targetPath,
      'sourceKind': observation.sourceKind.name,
    },
    RestoreFileSyncObservation() => {
      'operationKind': 'fileSyncAfter',
      'path': observation.path,
      'fullBarrier': observation.fullBarrier,
    },
    RestoreDirectorySyncObservation() => {
      'operationKind': 'directorySyncAfter',
      'path': observation.path,
      'fullBarrier': observation.fullBarrier,
    },
    RestoreReceiptDurabilityObservation() => {
      'operationKind': switch (observation.boundary) {
        RestoreReceiptDurabilityBoundary.tempDurable => 'receiptTempDurable',
        RestoreReceiptDurabilityBoundary.published => 'receiptPublished',
      },
      'receiptSequence': observation.sequence,
      'receiptState': observation.state.name,
      'temporaryPath': observation.temporaryPath,
      'targetPath':
          observation.targetPath ??
          p.join(
            p.dirname(observation.temporaryPath),
            'receipt_${observation.sequence.toString().padLeft(16, '0')}.json',
          ),
    },
    RestoreColdAckDurabilityObservation() => {
      'operationKind': switch (observation.boundary) {
        RestoreColdAckDurabilityBoundary.tempDurable => 'coldAckTempDurable',
        RestoreColdAckDurabilityBoundary.published => 'coldAckPublished',
      },
      'runId': observation.runId,
      'terminalReceiptChecksum': observation.terminalReceiptChecksum,
      'expected': observation.expected.name,
      'ackProcessId': observation.processId,
      'ackLeaseInstanceId': observation.leaseInstanceId,
      'ackChecksum': observation.ackChecksum,
      'temporaryPath': observation.temporaryPath,
      'targetPath':
          observation.targetPath ??
          p.join(
            p.dirname(observation.temporaryPath),
            RestoreSettingsColdAckStore.fileName,
          ),
    },
    RestoreTerminalWorkspaceSyncObservation() => {
      'operationKind': 'terminalWorkspaceSyncAfter',
      'boundary': observation.boundary.name,
      'path': observation.workspaceRootPath,
      'fullBarrier': observation.fullBarrier,
    },
  };
}

Map<String, dynamic> _preferenceObservationJson(
  RestoreHarnessControl control,
  RestorePreferenceMutationObservation observation,
) {
  if (!observation.prefixedKey.startsWith(control.preferencesPrefix)) {
    throw StateError('restore_harness_settings_observation_prefix');
  }
  return {
    'operationKind': switch (observation.kind) {
      RestorePreferenceMutationKind.remove => 'preferenceRemoveAfter',
      RestorePreferenceMutationKind.set => 'preferenceSetAfter',
    },
    'preferenceKey': observation.prefixedKey.substring(
      control.preferencesPrefix.length,
    ),
    'valueType': observation.valueType ?? '',
  };
}

Future<void> _expectForwardCrashTopology({
  required RestoreProcessHarnessControl control,
  required RestoreCompleteBundleFixtureState state,
  required SharedPreferences preferences,
  required RestoreReceiptStore receiptStore,
}) async {
  final expectedReceipt = _expectedPublishedReceiptState(control.failpoint);
  final history = await receiptStore.readHistoryWhileWorkspaceLocked();
  expect(
    history.map((receipt) => receipt.state),
    _receiptHistory(expectedReceipt),
  );
  expect(history.first.checksum, state.preparedReceiptChecksum);
  expect(
    await File(
      p.join(
        receiptStore.workspaceRoot.path,
        RestoreWorkspaceLock.publishingRunFileName,
      ),
    ).readAsString(),
    state.runId,
  );
  expect(
    await File(
      p.join(
        receiptStore.runDirectory.path,
        RestoreSettingsColdAckStore.fileName,
      ),
    ).exists(),
    isFalse,
  );
  await _expectPreviousControlTopology(control.failpoint, receiptStore);
  await _expectReceiptTemporaryTopology(control.failpoint, receiptStore);
  await _expectCrashDatabases(control, state, receiptStore);
  await _expectCrashAssets(control, receiptStore);
  _expectCrashPreferences(preferences, state, control.failpoint);
}

RestoreReceiptState _expectedPublishedReceiptState(
  RestoreProcessFailpoint failpoint,
) {
  if (_hasReached(
    failpoint,
    RestoreProcessFailpoint.committedReceiptPublished,
  )) {
    return RestoreReceiptState.committed;
  }
  if (_hasReached(
    failpoint,
    RestoreProcessFailpoint.verifiedReceiptPublished,
  )) {
    return RestoreReceiptState.verified;
  }
  if (_hasReached(
    failpoint,
    RestoreProcessFailpoint.newInstalledReceiptPublished,
  )) {
    return RestoreReceiptState.newInstalled;
  }
  if (_hasReached(
    failpoint,
    RestoreProcessFailpoint.oldRenamedReceiptPublished,
  )) {
    return RestoreReceiptState.oldRenamed;
  }
  return RestoreReceiptState.prepared;
}

Iterable<RestoreReceiptState> _receiptHistory(
  RestoreReceiptState latest,
) sync* {
  yield RestoreReceiptState.prepared;
  if (latest == RestoreReceiptState.prepared) return;
  yield RestoreReceiptState.oldRenamed;
  if (latest == RestoreReceiptState.oldRenamed) return;
  yield RestoreReceiptState.newInstalled;
  if (latest == RestoreReceiptState.newInstalled) return;
  yield RestoreReceiptState.verified;
  if (latest == RestoreReceiptState.verified) return;
  yield RestoreReceiptState.committed;
}

Future<void> _expectPreviousControlTopology(
  RestoreProcessFailpoint failpoint,
  RestoreReceiptStore receiptStore,
) async {
  final pending = _previousPendingDirectory(receiptStore);
  final previous = _previousDirectory(receiptStore);
  if (_hasReached(failpoint, RestoreProcessFailpoint.previousPromoted)) {
    expect(await pending.exists(), isFalse);
    expect(await previous.exists(), isTrue);
    expect(
      await File(
        p.join(previous.path, RestorePreviousStore.settingsFileName),
      ).exists(),
      isTrue,
    );
    expect(
      await File(
        p.join(previous.path, RestorePreviousStore.manifestFileName),
      ).exists(),
      isTrue,
    );
    return;
  }
  expect(await previous.exists(), isFalse);
  if (!_hasReached(
    failpoint,
    RestoreProcessFailpoint.previousSettingsPublished,
  )) {
    expect(await pending.exists(), isFalse);
    return;
  }
  expect(await pending.exists(), isTrue);
  expect(
    await File(
      p.join(pending.path, RestorePreviousStore.settingsFileName),
    ).exists(),
    isTrue,
  );
  expect(
    await File(
      p.join(pending.path, RestorePreviousStore.manifestFileName),
    ).exists(),
    _hasReached(failpoint, RestoreProcessFailpoint.previousManifestPublished),
  );
}

Future<void> _expectReceiptTemporaryTopology(
  RestoreProcessFailpoint failpoint,
  RestoreReceiptStore receiptStore,
) async {
  final expectation = switch (failpoint) {
    RestoreProcessFailpoint.oldRenamedReceiptTempDurable => (
      sequence: 2,
      state: RestoreReceiptState.oldRenamed,
    ),
    RestoreProcessFailpoint.newInstalledReceiptTempDurable => (
      sequence: 3,
      state: RestoreReceiptState.newInstalled,
    ),
    RestoreProcessFailpoint.verifiedReceiptTempDurable => (
      sequence: 4,
      state: RestoreReceiptState.verified,
    ),
    RestoreProcessFailpoint.committedReceiptTempDurable => (
      sequence: 5,
      state: RestoreReceiptState.committed,
    ),
    _ => null,
  };
  final temporaryFiles = <File>[];
  await for (final entity in receiptStore.receiptDirectory.list(
    followLinks: false,
  )) {
    if (!p.basename(entity.path).endsWith('.tmp')) continue;
    expect(entity, isA<File>());
    temporaryFiles.add(File(entity.path));
  }
  if (expectation == null) {
    expect(temporaryFiles, isEmpty);
    return;
  }
  final targetName =
      'receipt_${expectation.sequence.toString().padLeft(16, '0')}.json';
  expect(
    await File(p.join(receiptStore.receiptDirectory.path, targetName)).exists(),
    isFalse,
  );
  expect(temporaryFiles, hasLength(1));
  final temporary = temporaryFiles.single;
  expect(p.basename(temporary.path), startsWith('$targetName.'));
  final decoded = jsonDecode(await temporary.readAsString());
  final receipt = RestoreReceipt.fromJson(decoded as Map);
  expect(receipt.sequence, expectation.sequence);
  expect(receipt.state, expectation.state);
}

Future<void> _expectCrashDatabases(
  RestoreProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
  RestoreReceiptStore receiptStore,
) async {
  final previousLocation =
      _hasReached(control.failpoint, RestoreProcessFailpoint.previousPromoted)
      ? _BundleLocation.previous
      : _hasReached(
          control.failpoint,
          RestoreProcessFailpoint.previousDatabaseMoved,
        )
      ? _BundleLocation.previousPending
      : _BundleLocation.live;
  final candidateLocation =
      _hasReached(
        control.failpoint,
        RestoreProcessFailpoint.candidateDatabaseMoved,
      )
      ? _BundleLocation.live
      : _BundleLocation.candidate;
  final paths = _databasePaths(control, receiptStore);
  final expected = <String, String>{
    paths[previousLocation]!: state.oldConversationId,
    paths[candidateLocation]!: state.newConversationId,
  };
  expect(expected, hasLength(2));
  for (final path in paths.values) {
    final expectedId = expected[path];
    final file = File(path);
    if (expectedId == null) {
      expect(await file.exists(), isFalse, reason: path);
    } else {
      expect(await harnessConversationIds(file), [expectedId], reason: path);
    }
  }
}

Map<_BundleLocation, String> _databasePaths(
  RestoreProcessHarnessControl control,
  RestoreReceiptStore receiptStore,
) => {
  _BundleLocation.live: _liveDatabase(control).path,
  _BundleLocation.candidate: _candidateDatabase(receiptStore).path,
  _BundleLocation.previousPending: p.join(
    _previousPendingDirectory(receiptStore).path,
    'database',
    AppDatabase.databaseFileName,
  ),
  _BundleLocation.previous: p.join(
    _previousDirectory(receiptStore).path,
    'database',
    AppDatabase.databaseFileName,
  ),
};

Future<void> _expectCrashAssets(
  RestoreProcessHarnessControl control,
  RestoreReceiptStore receiptStore,
) async {
  for (final root in restoreHarnessAssetRoots) {
    final previousLocation =
        _hasReached(control.failpoint, RestoreProcessFailpoint.previousPromoted)
        ? _BundleLocation.previous
        : _hasReached(control.failpoint, _previousAssetFailpoint(root))
        ? _BundleLocation.previousPending
        : _BundleLocation.live;
    final candidateLocation =
        _hasReached(control.failpoint, _candidateAssetFailpoint(root))
        ? _BundleLocation.live
        : _BundleLocation.candidate;
    final containers = _assetContainers(control, receiptStore);
    final expected = <String, String>{
      p.join(containers[previousLocation]!, root, 'old.txt'): 'old:$root',
      p.join(containers[candidateLocation]!, root, 'new.txt'): 'new:$root',
    };
    expect(expected, hasLength(2));
    for (final container in containers.values) {
      for (final name in const ['old.txt', 'new.txt']) {
        final path = p.join(container, root, name);
        final expectedValue = expected[path];
        final file = File(path);
        if (expectedValue == null) {
          expect(await file.exists(), isFalse, reason: path);
        } else {
          expect(await file.readAsString(), expectedValue, reason: path);
        }
      }
    }
  }
}

Map<_BundleLocation, String> _assetContainers(
  RestoreProcessHarnessControl control,
  RestoreReceiptStore receiptStore,
) => {
  _BundleLocation.live: control.appDataDirectory.path,
  _BundleLocation.candidate: _candidateDirectory(receiptStore).path,
  _BundleLocation.previousPending: _previousPendingDirectory(receiptStore).path,
  _BundleLocation.previous: _previousDirectory(receiptStore).path,
};

void _expectCrashPreferences(
  SharedPreferences preferences,
  RestoreCompleteBundleFixtureState state,
  RestoreProcessFailpoint failpoint,
) {
  if (!_hasReached(failpoint, RestoreProcessFailpoint.settingsSecretRemoved)) {
    _expectBeforePreferences(preferences, state);
    return;
  }
  expect(preferences.containsKey(state.secretPreferenceKey), isFalse);
  if (failpoint == RestoreProcessFailpoint.settingsSecretRemoved) {
    expect(
      preferences.getString(state.primaryPreferenceKey),
      state.primaryOldPreferenceValue,
    );
    expect(
      preferences.getString(state.secondaryPreferenceKey),
      state.secondaryOldPreferenceValue,
    );
    expect(preferences.containsKey(state.targetOnlyPreferenceKey), isFalse);
    return;
  }
  if (failpoint == RestoreProcessFailpoint.settingsFirstSet) {
    expect(
      preferences.getString(state.primaryPreferenceKey),
      state.primaryNewPreferenceValue,
    );
    expect(
      preferences.getString(state.secondaryPreferenceKey),
      state.secondaryOldPreferenceValue,
    );
    expect(preferences.containsKey(state.targetOnlyPreferenceKey), isFalse);
    return;
  }
  _expectTargetPreferences(preferences, state);
}

void _expectBeforePreferences(
  SharedPreferences preferences,
  RestoreCompleteBundleFixtureState state,
) {
  expect(
    preferences.getString(state.primaryPreferenceKey),
    state.primaryOldPreferenceValue,
  );
  expect(
    preferences.getString(state.secondaryPreferenceKey),
    state.secondaryOldPreferenceValue,
  );
  expect(
    preferences.getString(state.secretPreferenceKey),
    state.secretOldPreferenceValue,
  );
  expect(preferences.containsKey(state.targetOnlyPreferenceKey), isFalse);
}

String _assetRootForFailpoint(RestoreProcessFailpoint failpoint) {
  return switch (failpoint) {
    RestoreProcessFailpoint.previousUploadMoved ||
    RestoreProcessFailpoint.candidateUploadMoved => 'upload',
    RestoreProcessFailpoint.previousImagesMoved ||
    RestoreProcessFailpoint.candidateImagesMoved => 'images',
    RestoreProcessFailpoint.previousAvatarsMoved ||
    RestoreProcessFailpoint.candidateAvatarsMoved => 'avatars',
    RestoreProcessFailpoint.previousFontsMoved ||
    RestoreProcessFailpoint.candidateFontsMoved => 'fonts',
    _ => throw StateError('restore_harness_asset_failpoint:${failpoint.name}'),
  };
}

RestoreProcessFailpoint _previousAssetFailpoint(String root) => switch (root) {
  'upload' => RestoreProcessFailpoint.previousUploadMoved,
  'images' => RestoreProcessFailpoint.previousImagesMoved,
  'avatars' => RestoreProcessFailpoint.previousAvatarsMoved,
  'fonts' => RestoreProcessFailpoint.previousFontsMoved,
  _ => throw StateError('restore_harness_asset_root:$root'),
};

RestoreProcessFailpoint _candidateAssetFailpoint(String root) => switch (root) {
  'upload' => RestoreProcessFailpoint.candidateUploadMoved,
  'images' => RestoreProcessFailpoint.candidateImagesMoved,
  'avatars' => RestoreProcessFailpoint.candidateAvatarsMoved,
  'fonts' => RestoreProcessFailpoint.candidateFontsMoved,
  _ => throw StateError('restore_harness_asset_root:$root'),
};

bool _hasReached(
  RestoreProcessFailpoint actual,
  RestoreProcessFailpoint boundary,
) => actual.index >= boundary.index;

String _absolutePath(String path) => p.normalize(p.absolute(path));

Future<void> _expectInitialAssets(
  RestoreHarnessControl control,
  RestoreReceiptStore store,
) async {
  final candidate = _candidateDirectory(store);
  for (final root in restoreHarnessAssetRoots) {
    expect(
      await File(
        p.join(control.appDataDirectory.path, root, 'old.txt'),
      ).readAsString(),
      'old:$root',
    );
    expect(
      await File(p.join(candidate.path, root, 'new.txt')).readAsString(),
      'new:$root',
    );
  }
}

Future<void> _expectInstalledBundle(
  RestoreHarnessControl control,
  RestoreReceiptStore store,
  RestoreCompleteBundleFixtureState state,
) async {
  expect(await harnessConversationIds(_liveDatabase(control)), [
    state.newConversationId,
  ]);
  final previous = _previousDirectory(store);
  expect(
    await harnessConversationIds(
      File(p.join(previous.path, 'database', AppDatabase.databaseFileName)),
    ),
    [state.oldConversationId],
  );
  for (final root in restoreHarnessAssetRoots) {
    expect(
      await File(
        p.join(control.appDataDirectory.path, root, 'new.txt'),
      ).readAsString(),
      'new:$root',
    );
    expect(
      await File(p.join(previous.path, root, 'old.txt')).readAsString(),
      'old:$root',
    );
  }
}

Future<void> _expectFinalArchivedBundle(
  RestoreHarnessControl control,
  RestoreReceiptStore archivedStore,
  RestoreCompleteBundleFixtureState state,
) async {
  expect(await harnessConversationIds(_liveDatabase(control)), [
    state.newConversationId,
  ]);
  final previous = _previousDirectory(archivedStore);
  expect(
    await harnessConversationIds(
      File(p.join(previous.path, 'database', AppDatabase.databaseFileName)),
    ),
    [state.oldConversationId],
  );
  for (final suffix in const ['-wal', '-shm', '-journal']) {
    expect(await File('${_liveDatabase(control).path}$suffix').exists(), false);
    expect(
      await File(
        '${p.join(previous.path, 'database', AppDatabase.databaseFileName)}$suffix',
      ).exists(),
      false,
    );
  }
  for (final root in restoreHarnessAssetRoots) {
    final liveRoot = Directory(p.join(control.appDataDirectory.path, root));
    final previousRoot = Directory(p.join(previous.path, root));
    expect(await File(p.join(liveRoot.path, 'old.txt')).exists(), isFalse);
    expect(
      await File(p.join(liveRoot.path, 'new.txt')).readAsString(),
      'new:$root',
    );
    expect(
      await File(p.join(previousRoot.path, 'old.txt')).readAsString(),
      'old:$root',
    );
    expect(await File(p.join(previousRoot.path, 'new.txt')).exists(), isFalse);
  }
}

Future<Map<String, dynamic>> _readSetupEvent(
  RestoreProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
) async {
  final event = await _readPriorEvent(
    control,
    generation: 1,
    phase: RestoreProcessHarnessPhase.setup,
    phaseKeys: const {'runId', 'receiptState'},
  );
  if (event['status'] != 'completed' ||
      event['runId'] != state.runId ||
      event['receiptState'] != RestoreReceiptState.prepared.name) {
    throw const FormatException('restore_harness_setup_event');
  }
  return event;
}

Future<Map<String, dynamic>> _readTerminalSetupEvent(
  RestoreTerminalProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
) async {
  final event = await _readTerminalPriorEvent(
    control,
    generation: 1,
    phase: RestoreTerminalProcessHarnessPhase.setup,
    phaseKeys: const {'runId', 'receiptState'},
  );
  if (event['status'] != 'completed' ||
      event['runId'] != state.runId ||
      event['receiptState'] != RestoreReceiptState.prepared.name) {
    throw const FormatException('restore_terminal_harness_setup_event');
  }
  return event;
}

Future<Map<String, dynamic>> _readRollbackSetupEvent(
  RestoreRollbackProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
) async {
  final event = await _readRollbackPriorEvent(
    control,
    generation: 1,
    phase: RestoreRollbackProcessHarnessPhase.setup,
    phaseKeys: const {'runId', 'receiptState'},
  );
  if (event['status'] != 'completed' ||
      event['runId'] != state.runId ||
      event['receiptState'] != RestoreReceiptState.prepared.name) {
    throw const FormatException('restore_rollback_harness_setup_event');
  }
  return event;
}

Future<Map<String, dynamic>> _readRollbackKillEvent(
  RestoreRollbackProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
) async {
  final event = await _readRollbackPriorEvent(
    control,
    generation: 2,
    phase: RestoreRollbackProcessHarnessPhase.triggerRollbackKill,
    phaseKeys: _rollbackKillEventKeys(control.failpoint),
  );
  if (event['status'] != 'readyForKill' ||
      event['marker'] != control.failpoint.name ||
      event['runId'] != state.runId ||
      !_isIdentifier(event['leaseInstanceId']) ||
      event['rollbackOriginReceiptState'] !=
          RestoreReceiptState.verified.name ||
      event['triggerKind'] != 'repeatedTargetSetRejected' ||
      event['triggerPreferenceKey'] != state.primaryPreferenceKey ||
      event['triggerFailureCount'] != 1 ||
      event['observedReceiptState'] !=
          _rollbackObservedReceiptState(control.failpoint).name) {
    throw const FormatException('restore_rollback_harness_kill_event');
  }
  _validateRollbackKillObservation(control, state, event);
  return event;
}

Set<String> _rollbackKillEventKeys(RestoreRollbackProcessFailpoint failpoint) {
  const common = {
    'marker',
    'runId',
    'leaseInstanceId',
    'rollbackOriginReceiptState',
    'triggerKind',
    'triggerPreferenceKey',
    'triggerFailureCount',
    'observedReceiptState',
  };
  return switch (failpoint) {
    RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable ||
    RestoreRollbackProcessFailpoint.rollingBackReceiptPublished ||
    RestoreRollbackProcessFailpoint.rolledBackReceiptTempDurable ||
    RestoreRollbackProcessFailpoint.rolledBackReceiptPublished => {
      ...common,
      'operationKind',
      'receiptSequence',
      'receiptState',
      'temporaryPath',
      'targetPath',
    },
    RestoreRollbackProcessFailpoint.previousDatabaseParentRemovedDurable => {
      ...common,
      'operationKind',
      'path',
      'fullBarrier',
    },
    RestoreRollbackProcessFailpoint.settingsFirstRestored ||
    RestoreRollbackProcessFailpoint.settingsSecretRestored ||
    RestoreRollbackProcessFailpoint.settingsTargetOnlyRemoved => {
      ...common,
      'operationKind',
      'preferenceKey',
      'valueType',
    },
    _ => {...common, 'operationKind', 'sourcePath', 'targetPath', 'sourceKind'},
  };
}

void _validateRollbackKillObservation(
  RestoreRollbackProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
  Map<String, dynamic> event,
) {
  final receiptStore = _activeReceiptStore(control, state);
  final matcher = _rollbackDurabilityMatcher(control, state, receiptStore);
  switch (control.failpoint) {
    case RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable:
    case RestoreRollbackProcessFailpoint.rolledBackReceiptTempDurable:
      final expected = matcher! as RestoreReceiptTempDurableMatcher;
      _validateReceiptObservation(
        event,
        receiptDirectoryPath: expected.receiptDirectoryPath,
        sequence: expected.sequence,
        state: expected.state,
        operationKind: 'receiptTempDurable',
      );
    case RestoreRollbackProcessFailpoint.rollingBackReceiptPublished:
    case RestoreRollbackProcessFailpoint.rolledBackReceiptPublished:
      final expected = matcher! as RestoreReceiptPublishedMatcher;
      _validateReceiptObservation(
        event,
        receiptDirectoryPath: expected.receiptDirectoryPath,
        sequence: expected.sequence,
        state: expected.state,
        operationKind: 'receiptPublished',
      );
    case RestoreRollbackProcessFailpoint.previousDatabaseParentRemovedDurable:
      final expected = matcher! as RestoreRollbackDatabaseParentSyncMatcher;
      if (event['operationKind'] != 'directorySyncAfter' ||
          event['path'] != expected.previousDirectoryPath ||
          event['fullBarrier'] != true) {
        throw const FormatException('restore_rollback_harness_parent_sync');
      }
    case RestoreRollbackProcessFailpoint.settingsFirstRestored:
      _requireRollbackPreferenceObservation(
        event,
        key: state.primaryPreferenceKey,
        kind: RestorePreferenceMutationKind.set,
      );
    case RestoreRollbackProcessFailpoint.settingsSecretRestored:
      _requireRollbackPreferenceObservation(
        event,
        key: state.secretPreferenceKey,
        kind: RestorePreferenceMutationKind.set,
      );
    case RestoreRollbackProcessFailpoint.settingsTargetOnlyRemoved:
      _requireRollbackPreferenceObservation(
        event,
        key: state.targetOnlyPreferenceKey,
        kind: RestorePreferenceMutationKind.remove,
      );
    default:
      final expected = matcher! as RestoreExactRenameMatcher;
      if (event['operationKind'] != 'renameAfter' ||
          event['sourcePath'] != expected.sourcePath ||
          event['targetPath'] != expected.targetPath ||
          event['sourceKind'] != expected.sourceKind.name) {
        throw const FormatException('restore_rollback_harness_rename');
      }
  }
}

void _requireRollbackPreferenceObservation(
  Map<String, dynamic> event, {
  required String key,
  required RestorePreferenceMutationKind kind,
}) {
  final expectedOperation = kind == RestorePreferenceMutationKind.set
      ? 'preferenceSetAfter'
      : 'preferenceRemoveAfter';
  final expectedType = kind == RestorePreferenceMutationKind.set
      ? 'String'
      : '';
  if (event['operationKind'] != expectedOperation ||
      event['preferenceKey'] != key ||
      event['valueType'] != expectedType) {
    throw const FormatException('restore_rollback_harness_preference');
  }
}

Future<Map<String, dynamic>> _readRollbackRecoveryEvent(
  RestoreRollbackProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
) async {
  final killed = await _readRollbackKillEvent(control, state);
  final event = await _readRollbackPriorEvent(
    control,
    generation: 3,
    phase: RestoreRollbackProcessHarnessPhase.recoverToColdAck,
    phaseKeys: const {
      'runId',
      'receiptState',
      'outcome',
      'leaseInstanceId',
      'terminalReceiptChecksum',
      'ackExpected',
      'ackProcessId',
      'ackLeaseInstanceId',
      'coldAckChecksum',
      'settingsMutationAttempts',
      'triggerFailureCount',
    },
  );
  final expectedTriggerFailures =
      control.failpoint ==
          RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable
      ? 1
      : 0;
  if (event['status'] != 'completed' ||
      event['runId'] != state.runId ||
      event['receiptState'] != RestoreReceiptState.rolledBack.name ||
      event['outcome'] != 'coldRestartRequired' ||
      !_isIdentifier(event['leaseInstanceId']) ||
      event['leaseInstanceId'] == killed['leaseInstanceId'] ||
      !_isSha256(event['terminalReceiptChecksum']) ||
      event['ackExpected'] != RestoreSettingsColdAckExpected.before.name ||
      event['ackProcessId'] != event['pid'] ||
      event['ackLeaseInstanceId'] != event['leaseInstanceId'] ||
      !_isSha256(event['coldAckChecksum']) ||
      event['settingsMutationAttempts'] is! int ||
      (event['settingsMutationAttempts'] as int) < 1 ||
      event['triggerFailureCount'] != expectedTriggerFailures) {
    throw const FormatException('restore_rollback_harness_recovery_event');
  }
  return event;
}

Future<Map<String, dynamic>> _readTerminalCommitEvent(
  RestoreTerminalProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
) async {
  if (_isTerminalColdAckFailpoint(control.failpoint)) {
    final event = await _readTerminalPriorEvent(
      control,
      generation: 2,
      phase: RestoreTerminalProcessHarnessPhase.commitToColdAck,
      phaseKeys: const {
        'marker',
        'runId',
        'leaseInstanceId',
        'observedReceiptState',
        'operationKind',
        'terminalReceiptChecksum',
        'expected',
        'ackProcessId',
        'ackLeaseInstanceId',
        'ackChecksum',
        'temporaryPath',
        'targetPath',
      },
    );
    final expectedOperation =
        control.failpoint == RestoreTerminalProcessFailpoint.coldAckTempDurable
        ? 'coldAckTempDurable'
        : 'coldAckPublished';
    final temporaryPath = event['temporaryPath'];
    final targetPath = event['targetPath'];
    final runDirectory = _activeReceiptStore(control, state).runDirectory.path;
    if (event['status'] != 'readyForKill' ||
        event['marker'] != control.failpoint.name ||
        event['runId'] != state.runId ||
        !_isIdentifier(event['leaseInstanceId']) ||
        event['observedReceiptState'] != RestoreReceiptState.committed.name ||
        event['operationKind'] != expectedOperation ||
        !_isSha256(event['terminalReceiptChecksum']) ||
        event['expected'] != RestoreSettingsColdAckExpected.target.name ||
        event['ackProcessId'] != event['pid'] ||
        event['ackLeaseInstanceId'] != event['leaseInstanceId'] ||
        !_isSha256(event['ackChecksum']) ||
        temporaryPath is! String ||
        targetPath is! String ||
        !p.equals(p.dirname(temporaryPath), runDirectory) ||
        !RegExp(
          '^${RegExp.escape(RestoreSettingsColdAckStore.fileName)}\\.'
          '[1-9][0-9]*_${event['pid']}_[0-9]+\\.tmp\$',
        ).hasMatch(p.basename(temporaryPath)) ||
        !p.equals(
          targetPath,
          p.join(runDirectory, RestoreSettingsColdAckStore.fileName),
        )) {
      throw const FormatException('restore_terminal_harness_commit_event');
    }
    return event;
  }

  final event = await _readTerminalPriorEvent(
    control,
    generation: 2,
    phase: RestoreTerminalProcessHarnessPhase.commitToColdAck,
    phaseKeys: const {
      'runId',
      'receiptState',
      'leaseInstanceId',
      'coldAckProcessId',
      'coldAckLeaseInstanceId',
      'coldAckChecksum',
      'terminalReceiptChecksum',
    },
  );
  if (event['status'] != 'completed' ||
      event['runId'] != state.runId ||
      event['receiptState'] != RestoreReceiptState.committed.name ||
      !_isIdentifier(event['leaseInstanceId']) ||
      event['coldAckProcessId'] != event['pid'] ||
      event['coldAckLeaseInstanceId'] != event['leaseInstanceId'] ||
      !_isSha256(event['coldAckChecksum']) ||
      !_isSha256(event['terminalReceiptChecksum'])) {
    throw const FormatException('restore_terminal_harness_commit_event');
  }
  return event;
}

Future<Map<String, dynamic>> _readTerminalRecoveryEvent(
  RestoreTerminalProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
) async {
  final commitEvent = await _readTerminalCommitEvent(control, state);
  if (_isTerminalColdAckFailpoint(control.failpoint)) {
    final event = await _readTerminalPriorEvent(
      control,
      generation: 3,
      phase: RestoreTerminalProcessHarnessPhase.recoverTerminal,
      phaseKeys: const {
        'runId',
        'receiptState',
        'outcome',
        'leaseInstanceId',
        'ackProcessId',
        'ackLeaseInstanceId',
        'terminalReceiptChecksum',
        'settingsMutationAttempts',
      },
    );
    final outcome = event['outcome'];
    final mutationAttempts = event['settingsMutationAttempts'];
    final expectsColdRestart =
        control.failpoint == RestoreTerminalProcessFailpoint.coldAckTempDurable;
    if (event['status'] != 'completed' ||
        event['runId'] != state.runId ||
        event['receiptState'] != RestoreReceiptState.committed.name ||
        outcome != (expectsColdRestart ? 'coldRestartRequired' : 'archived') ||
        !_isIdentifier(event['leaseInstanceId']) ||
        !_isIdentifier(event['ackLeaseInstanceId']) ||
        event['ackProcessId'] is! int ||
        (event['ackProcessId'] as int) < 1 ||
        event['terminalReceiptChecksum'] !=
            commitEvent['terminalReceiptChecksum'] ||
        mutationAttempts is! int ||
        (expectsColdRestart ? mutationAttempts < 1 : mutationAttempts != 0)) {
      throw const FormatException('restore_terminal_harness_recovery_event');
    }
    if (outcome == 'coldRestartRequired') {
      if (event['ackProcessId'] != event['pid'] ||
          event['ackLeaseInstanceId'] != event['leaseInstanceId']) {
        throw const FormatException('restore_terminal_harness_recovery_ack');
      }
    } else if (event['ackProcessId'] != commitEvent['ackProcessId'] ||
        event['ackLeaseInstanceId'] != commitEvent['ackLeaseInstanceId']) {
      throw const FormatException('restore_terminal_harness_recovery_ack');
    }
    return event;
  }

  final observationKeys = switch (control.failpoint) {
    RestoreTerminalProcessFailpoint.completedRunsRootDurable ||
    RestoreTerminalProcessFailpoint.archivingMarkerRemovedDurable => const {
      'operationKind',
      'boundary',
      'path',
      'fullBarrier',
    },
    RestoreTerminalProcessFailpoint.archivingMarkerPublished ||
    RestoreTerminalProcessFailpoint.terminalRunArchived => const {
      'operationKind',
      'sourcePath',
      'targetPath',
      'sourceKind',
    },
    _ => throw StateError('restore_terminal_harness_recovery_failpoint'),
  };
  final event = await _readTerminalPriorEvent(
    control,
    generation: 3,
    phase: RestoreTerminalProcessHarnessPhase.recoverTerminal,
    phaseKeys: {
      'marker',
      'runId',
      'leaseInstanceId',
      'observedReceiptState',
      'coldAckProcessId',
      'coldAckLeaseInstanceId',
      'ackProcessId',
      'ackLeaseInstanceId',
      'terminalReceiptChecksum',
      'settingsMutationAttempts',
      ...observationKeys,
    },
  );
  if (event['status'] != 'readyForKill' ||
      event['marker'] != control.failpoint.name ||
      event['runId'] != state.runId ||
      !_isIdentifier(event['leaseInstanceId']) ||
      event['observedReceiptState'] != RestoreReceiptState.committed.name ||
      event['coldAckProcessId'] != commitEvent['coldAckProcessId'] ||
      event['coldAckLeaseInstanceId'] !=
          commitEvent['coldAckLeaseInstanceId'] ||
      event['ackProcessId'] != commitEvent['coldAckProcessId'] ||
      event['ackLeaseInstanceId'] != commitEvent['coldAckLeaseInstanceId'] ||
      event['terminalReceiptChecksum'] !=
          commitEvent['terminalReceiptChecksum'] ||
      event['settingsMutationAttempts'] != 0) {
    throw const FormatException('restore_terminal_harness_recovery_event');
  }
  _validateTerminalArchiveObservation(control, state, event);
  return event;
}

void _validateTerminalArchiveObservation(
  RestoreTerminalProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
  Map<String, dynamic> event,
) {
  final matcher = _terminalArchiveMatcher(control, state);
  switch (control.failpoint) {
    case RestoreTerminalProcessFailpoint.completedRunsRootDurable:
    case RestoreTerminalProcessFailpoint.archivingMarkerRemovedDurable:
      final expected = matcher as RestoreTerminalWorkspaceSyncMatcher;
      if (event['operationKind'] != 'terminalWorkspaceSyncAfter' ||
          event['boundary'] != control.failpoint.name ||
          event['path'] != expected.workspaceRootPath ||
          event['fullBarrier'] != true) {
        throw const FormatException('restore_terminal_harness_workspace_sync');
      }
    case RestoreTerminalProcessFailpoint.archivingMarkerPublished:
    case RestoreTerminalProcessFailpoint.terminalRunArchived:
      final expected = matcher as RestoreExactRenameMatcher;
      if (event['operationKind'] != 'renameAfter' ||
          event['sourcePath'] != expected.sourcePath ||
          event['targetPath'] != expected.targetPath ||
          event['sourceKind'] != expected.sourceKind.name) {
        throw const FormatException('restore_terminal_harness_rename');
      }
    case RestoreTerminalProcessFailpoint.coldAckTempDurable:
    case RestoreTerminalProcessFailpoint.coldAckPublished:
      throw StateError('restore_terminal_harness_archive_observation');
  }
}

Future<Map<String, dynamic>> _readTerminalPriorEvent(
  RestoreTerminalProcessHarnessControl control, {
  required int generation,
  required RestoreTerminalProcessHarnessPhase phase,
  required Set<String> phaseKeys,
}) async {
  final eventFile = File(
    p.join(
      control.eventsDirectory.path,
      '${generation.toString().padLeft(2, '0')}_${phase.name}.json',
    ),
  );
  final event = await readHarnessJson(eventFile);
  final expectedKeys = {
    'format',
    'version',
    'generation',
    'matrixRunId',
    'scenario',
    'scenarioId',
    'phase',
    'failpoint',
    'pid',
    'status',
    ...phaseKeys,
  };
  if (event.length != expectedKeys.length ||
      !event.keys.toSet().containsAll(expectedKeys) ||
      event['format'] != restoreHarnessFormat ||
      event['version'] != RestoreTerminalProcessHarnessControl.version ||
      event['generation'] != generation ||
      event['matrixRunId'] != control.matrixRunId ||
      event['scenario'] != restoreTerminalHarnessScenario ||
      event['scenarioId'] != control.scenarioId ||
      event['phase'] != phase.name ||
      event['failpoint'] != control.failpoint.name ||
      event['pid'] is! int ||
      (event['pid'] as int) < 1 ||
      event['status'] is! String) {
    throw const FormatException('restore_terminal_harness_event');
  }
  return event;
}

Future<Map<String, dynamic>> _readRollbackPriorEvent(
  RestoreRollbackProcessHarnessControl control, {
  required int generation,
  required RestoreRollbackProcessHarnessPhase phase,
  required Set<String> phaseKeys,
}) async {
  final eventFile = File(
    p.join(
      control.eventsDirectory.path,
      '${generation.toString().padLeft(2, '0')}_${phase.name}.json',
    ),
  );
  final event = await readHarnessJson(eventFile);
  final expectedKeys = {
    'format',
    'version',
    'generation',
    'matrixRunId',
    'scenario',
    'scenarioId',
    'phase',
    'failpoint',
    'pid',
    'status',
    ...phaseKeys,
  };
  if (event.length != expectedKeys.length ||
      !event.keys.toSet().containsAll(expectedKeys) ||
      event['format'] != restoreHarnessFormat ||
      event['version'] != RestoreRollbackProcessHarnessControl.version ||
      event['generation'] != generation ||
      event['matrixRunId'] != control.matrixRunId ||
      event['scenario'] != restoreRollbackHarnessScenario ||
      event['scenarioId'] != control.scenarioId ||
      event['phase'] != phase.name ||
      event['failpoint'] != control.failpoint.name ||
      event['pid'] is! int ||
      (event['pid'] as int) < 1 ||
      event['status'] is! String) {
    throw const FormatException('restore_rollback_harness_event');
  }
  return event;
}

bool _isIdentifier(Object? value) =>
    value is String && RegExp(_leaseInstancePattern).hasMatch(value);

bool _isSha256(Object? value) =>
    value is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

Future<Map<String, dynamic>> _readCutoverEvent(
  RestoreProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
) async {
  final event = await _readPriorEvent(
    control,
    generation: 2,
    phase: RestoreProcessHarnessPhase.cutoverKill,
    phaseKeys: _killEventKeys(control.failpoint),
  );
  if (event['status'] != 'readyForKill' ||
      event['marker'] != control.failpoint.name ||
      event['runId'] != state.runId ||
      event['leaseInstanceId'] is! String ||
      !RegExp(
        _leaseInstancePattern,
      ).hasMatch(event['leaseInstanceId'] as String) ||
      event['observedReceiptState'] !=
          _expectedPublishedReceiptState(control.failpoint).name) {
    throw const FormatException('restore_harness_cutover_event');
  }
  _validateKillObservation(control, state, event);
  return event;
}

Set<String> _killEventKeys(RestoreProcessFailpoint failpoint) {
  const common = {'marker', 'runId', 'leaseInstanceId', 'observedReceiptState'};
  return switch (failpoint) {
    RestoreProcessFailpoint.liveDatabaseNormalized => {
      ...common,
      'operationKind',
      'path',
      'fullBarrier',
    },
    RestoreProcessFailpoint.oldRenamedReceiptTempDurable ||
    RestoreProcessFailpoint.oldRenamedReceiptPublished ||
    RestoreProcessFailpoint.newInstalledReceiptTempDurable ||
    RestoreProcessFailpoint.newInstalledReceiptPublished ||
    RestoreProcessFailpoint.verifiedReceiptTempDurable ||
    RestoreProcessFailpoint.verifiedReceiptPublished ||
    RestoreProcessFailpoint.committedReceiptTempDurable ||
    RestoreProcessFailpoint.committedReceiptPublished => {
      ...common,
      'operationKind',
      'receiptSequence',
      'receiptState',
      'temporaryPath',
      'targetPath',
    },
    RestoreProcessFailpoint.settingsSecretRemoved ||
    RestoreProcessFailpoint.settingsFirstSet => {
      ...common,
      'operationKind',
      'preferenceKey',
      'valueType',
    },
    _ => {...common, 'operationKind', 'sourcePath', 'targetPath', 'sourceKind'},
  };
}

void _validateKillObservation(
  RestoreProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
  Map<String, dynamic> event,
) {
  final receiptStore = _activeReceiptStore(control, state);
  final matcher = _durabilityMatcher(control, state, receiptStore);
  switch (control.failpoint) {
    case RestoreProcessFailpoint.liveDatabaseNormalized:
      final expected = matcher! as RestoreExactDirectorySyncMatcher;
      if (event['operationKind'] != 'directorySyncAfter' ||
          event['path'] != expected.path ||
          event['fullBarrier'] != expected.fullBarrier) {
        throw const FormatException('restore_harness_cutover_directory');
      }
    case RestoreProcessFailpoint.oldRenamedReceiptTempDurable:
    case RestoreProcessFailpoint.newInstalledReceiptTempDurable:
    case RestoreProcessFailpoint.verifiedReceiptTempDurable:
    case RestoreProcessFailpoint.committedReceiptTempDurable:
      final expected = matcher! as RestoreReceiptTempDurableMatcher;
      _validateReceiptObservation(
        event,
        receiptDirectoryPath: expected.receiptDirectoryPath,
        sequence: expected.sequence,
        state: expected.state,
        operationKind: 'receiptTempDurable',
      );
    case RestoreProcessFailpoint.oldRenamedReceiptPublished:
    case RestoreProcessFailpoint.newInstalledReceiptPublished:
    case RestoreProcessFailpoint.verifiedReceiptPublished:
    case RestoreProcessFailpoint.committedReceiptPublished:
      final expected = matcher! as RestoreReceiptPublishedMatcher;
      _validateReceiptObservation(
        event,
        receiptDirectoryPath: expected.receiptDirectoryPath,
        sequence: expected.sequence,
        state: expected.state,
        operationKind: 'receiptPublished',
      );
    case RestoreProcessFailpoint.settingsSecretRemoved:
      if (event['operationKind'] != 'preferenceRemoveAfter' ||
          event['preferenceKey'] != state.secretPreferenceKey ||
          event['valueType'] != '') {
        throw const FormatException('restore_harness_cutover_settings');
      }
    case RestoreProcessFailpoint.settingsFirstSet:
      if (event['operationKind'] != 'preferenceSetAfter' ||
          event['preferenceKey'] != state.primaryPreferenceKey ||
          event['valueType'] != 'String') {
        throw const FormatException('restore_harness_cutover_settings');
      }
    default:
      final expected = matcher! as RestoreExactRenameMatcher;
      if (event['operationKind'] != 'renameAfter' ||
          event['sourcePath'] != expected.sourcePath ||
          event['targetPath'] != expected.targetPath ||
          event['sourceKind'] != expected.sourceKind.name) {
        throw const FormatException('restore_harness_cutover_rename');
      }
  }
}

void _validateReceiptObservation(
  Map<String, dynamic> event, {
  required String receiptDirectoryPath,
  required int sequence,
  required RestoreReceiptState state,
  required String operationKind,
}) {
  final targetPath = p.join(
    receiptDirectoryPath,
    'receipt_${sequence.toString().padLeft(16, '0')}.json',
  );
  final temporaryPath = event['temporaryPath'];
  final processId = event['pid'];
  final pattern = RegExp(
    '^${RegExp.escape(p.basename(targetPath))}\\.[1-9][0-9]*_'
    '${RegExp.escape('$processId')}\\.tmp\$',
  );
  if (event['operationKind'] != operationKind ||
      event['receiptSequence'] != sequence ||
      event['receiptState'] != state.name ||
      temporaryPath is! String ||
      !p.equals(p.dirname(temporaryPath), receiptDirectoryPath) ||
      !pattern.hasMatch(p.basename(temporaryPath)) ||
      event['targetPath'] != targetPath) {
    throw const FormatException('restore_harness_cutover_receipt');
  }
}

Future<Map<String, dynamic>> _readResumeEvent(
  RestoreProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
) async {
  final event = await _readPriorEvent(
    control,
    generation: 3,
    phase: RestoreProcessHarnessPhase.resumeToColdAck,
    phaseKeys: const {
      'runId',
      'receiptState',
      'leaseInstanceId',
      'coldAckProcessId',
      'coldAckLeaseInstanceId',
    },
  );
  if (event['status'] != 'completed' ||
      event['runId'] != state.runId ||
      event['receiptState'] != RestoreReceiptState.committed.name ||
      event['leaseInstanceId'] is! String ||
      event['coldAckProcessId'] is! int ||
      (event['coldAckProcessId'] as int) < 1 ||
      event['coldAckLeaseInstanceId'] is! String ||
      event['leaseInstanceId'] != event['coldAckLeaseInstanceId'] ||
      !RegExp(
        _leaseInstancePattern,
      ).hasMatch(event['leaseInstanceId'] as String)) {
    throw const FormatException('restore_harness_resume_event');
  }
  return event;
}

Future<Map<String, dynamic>> _readPriorEvent(
  RestoreProcessHarnessControl control, {
  required int generation,
  required RestoreProcessHarnessPhase phase,
  required Set<String> phaseKeys,
}) async {
  final eventFile = File(
    p.join(
      control.eventsDirectory.path,
      '${generation.toString().padLeft(2, '0')}_${phase.name}.json',
    ),
  );
  final event = await readHarnessJson(eventFile);
  final expectedKeys = {
    'format',
    'version',
    'generation',
    'matrixRunId',
    'scenario',
    'scenarioId',
    'phase',
    'failpoint',
    'pid',
    'status',
    ...phaseKeys,
  };
  if (event.length != expectedKeys.length ||
      !event.keys.toSet().containsAll(expectedKeys) ||
      event['format'] != restoreHarnessFormat ||
      event['version'] != RestoreProcessHarnessControl.version ||
      event['generation'] != generation ||
      event['matrixRunId'] != control.matrixRunId ||
      event['scenario'] != restoreHarnessScenario ||
      event['scenarioId'] != control.scenarioId ||
      event['phase'] != phase.name ||
      event['failpoint'] != control.failpoint.name ||
      event['pid'] is! int ||
      (event['pid'] as int) < 1 ||
      event['status'] is! String) {
    throw const FormatException('restore_harness_event');
  }
  return event;
}

Future<void> _publishEvent(
  RestoreHarnessControl control,
  Map<String, dynamic> phaseValues,
) {
  final version = switch (control) {
    RestoreProcessHarnessControl() => RestoreProcessHarnessControl.version,
    RestoreTerminalProcessHarnessControl() =>
      RestoreTerminalProcessHarnessControl.version,
    RestoreRollbackProcessHarnessControl() =>
      RestoreRollbackProcessHarnessControl.version,
    _ => throw StateError('restore_harness_control_type'),
  };
  return writeDurableHarnessJson(control.eventFile, {
    'format': restoreHarnessFormat,
    'version': version,
    'generation': control.generation,
    'matrixRunId': control.matrixRunId,
    'scenario': control.scenario,
    'scenarioId': control.scenarioId,
    'phase': control.phaseName,
    'failpoint': control.failpointName,
    'pid': pid,
    ...phaseValues,
  });
}

Future<void> _requireMissing(FileSystemEntity entity, String error) async {
  if (await FileSystemEntity.type(entity.path, followLinks: false) !=
      FileSystemEntityType.notFound) {
    throw StateError(error);
  }
}

Future<void> _expectNoLeaseOwnerFiles(RestoreHarnessControl control) async {
  final leaseDirectory = Directory(
    p.join(
      control.appDataDirectory.path,
      RestoreBusinessLease.leaseDirectoryName,
    ),
  );
  await for (final entity in leaseDirectory.list(followLinks: false)) {
    if (p.basename(entity.path).startsWith('owner_')) {
      throw StateError('restore_harness_lease_owner_residue');
    }
  }
}
