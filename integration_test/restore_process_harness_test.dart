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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('executes one host-controlled restore process phase', (
    tester,
  ) async {
    if (!Platform.isMacOS) {
      throw UnsupportedError('restore_harness_macos_only');
    }
    final control = await RestoreProcessHarnessControl.readFromEnvironment();
    _requireControlSequence(control);
    await _requireRunnerBoundary(control);
    SharedPreferences.setPrefix(control.preferencesPrefix);
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();

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
  });
}

Future<void> _runSetup(
  RestoreProcessHarnessControl control,
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
  final preferenceKey = 'restore_harness_${control.scenarioId}';
  if (preferences.containsKey(preferenceKey)) {
    throw StateError('restore_harness_setup_preference');
  }
  if (!await preferences.setString(preferenceKey, 'old')) {
    throw StateError('restore_harness_setup_preference_write');
  }
  await preferences.reload();
  expect(preferences.getString(preferenceKey), 'old');

  final state = await prepareCompleteBundleFixture(control);
  _requireStateBinding(control, state);
  expect(state.preferenceKey, preferenceKey);
  expect(state.oldPreferenceValue, 'old');
  expect(state.newPreferenceValue, 'new');

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
  expect(preferences.getString(state.preferenceKey), state.oldPreferenceValue);
  final pending = await RestoreStartupGate.inspect(
    appDataDirectory: control.appDataDirectory,
  );
  expect(pending, isNotNull);
  expect(pending!.runId, state.runId);
  expect(pending.markerFileName, RestoreWorkspaceLock.activeRunFileName);
  expect(pending.receipt.state, RestoreReceiptState.prepared);
  expect(pending.receipt.checksum, state.preparedReceiptChecksum);

  final receiptStore = _activeReceiptStore(control, state);
  final candidateDatabase = _candidateDatabase(receiptStore);
  final liveDatabase = _liveDatabase(control);
  late final RestoreBusinessLease lease;
  final durability = BlockAfterCandidateDatabaseInstallDurability(
    delegate: RestorePlatformDurability(),
    candidateDatabasePath: candidateDatabase.path,
    liveDatabasePath: liveDatabase.path,
    onInstalled: () async {
      await preferences.reload();
      expect(
        preferences.getString(state.preferenceKey),
        state.newPreferenceValue,
      );
      expect(await candidateDatabase.exists(), isFalse);
      expect(await harnessConversationIds(liveDatabase), [
        state.newConversationId,
      ]);
      final history = await receiptStore.readHistoryWhileWorkspaceLocked();
      expect(history.map((receipt) => receipt.state), [
        RestoreReceiptState.prepared,
        RestoreReceiptState.oldRenamed,
      ]);
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
        await harnessConversationIds(
          File(
            p.join(
              _previousDirectory(receiptStore).path,
              'database',
              AppDatabase.databaseFileName,
            ),
          ),
        ),
        [state.oldConversationId],
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
      await _expectInterruptedAssetSplit(control, receiptStore);
      await _publishEvent(control, {
        'status': 'readyForKill',
        'marker': restoreHarnessScenario,
        'runId': state.runId,
        'leaseInstanceId': lease.instanceId,
        'liveDatabasePath': p.normalize(p.absolute(liveDatabase.path)),
      });
    },
  );
  lease = await RestoreBusinessLease.acquire(
    appDataDirectory: control.appDataDirectory,
    durability: durability,
  );
  try {
    await RestoreStartupGate.recoverAndRequireBusinessReady(
      appDataDirectory: control.appDataDirectory,
      preferences: preferences,
      businessLease: lease,
      durability: durability,
    );
    throw StateError('restore_harness_cutover_returned');
  } finally {
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
  expect(preferences.getString(state.preferenceKey), state.newPreferenceValue);

  final receiptStore = _activeReceiptStore(control, state);
  final pendingBefore = await RestoreStartupGate.inspect(
    appDataDirectory: control.appDataDirectory,
  );
  expect(pendingBefore, isNotNull);
  expect(pendingBefore!.runId, state.runId);
  expect(
    pendingBefore.markerFileName,
    RestoreWorkspaceLock.publishingRunFileName,
  );
  expect(pendingBefore.receipt.state, RestoreReceiptState.oldRenamed);
  expect(await harnessConversationIds(_liveDatabase(control)), [
    state.newConversationId,
  ]);
  expect(await _candidateDatabase(receiptStore).exists(), isFalse);
  await _expectInterruptedAssetSplit(control, receiptStore);

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
    expect(
      preferences.getString(state.preferenceKey),
      state.newPreferenceValue,
    );
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
  expect(preferences.getString(state.preferenceKey), state.newPreferenceValue);

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
      state.preferenceKey: state.oldPreferenceValue,
    });

    final archivedAck = await RestoreSettingsColdAckStore(
      runDirectory: archivedStore.runDirectory,
    ).read();
    expect(archivedAck, isNotNull);
    expect(archivedAck!.checksum, observedAck.checksum);
    await preferences.reload();
    expect(
      preferences.getString(state.preferenceKey),
      state.newPreferenceValue,
    );
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
  if (!await preferences.remove(state.preferenceKey)) {
    throw StateError('restore_harness_preference_cleanup');
  }
  await preferences.reload();
  expect(preferences.containsKey(state.preferenceKey), isFalse);
}

Future<RestoreCompleteBundleFixtureState> _readBoundState(
  RestoreProcessHarnessControl control,
) async {
  final state = await RestoreCompleteBundleFixtureState.read(control);
  _requireStateBinding(control, state);
  return state;
}

void _requireStateBinding(
  RestoreProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
) {
  if (state.preferenceKey != 'restore_harness_${control.scenarioId}' ||
      state.oldConversationId != 'old-${control.scenarioId}' ||
      state.newConversationId != 'new-${control.scenarioId}' ||
      !RegExp(r'^[a-f0-9]{32}$').hasMatch(state.runId) ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(state.preparedReceiptChecksum) ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(state.candidateManifestSha256)) {
    throw const FormatException('restore_harness_state_binding');
  }
}

void _requireControlSequence(RestoreProcessHarnessControl control) {
  if (control.generation != control.phase.index + 1) {
    throw StateError('restore_harness_control_sequence');
  }
}

Future<void> _requireRunnerBoundary(
  RestoreProcessHarnessControl control,
) async {
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
  RestoreProcessHarnessControl control,
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

File _liveDatabase(RestoreProcessHarnessControl control) =>
    File(p.join(control.appDataDirectory.path, AppDatabase.databaseFileName));

Directory _previousDirectory(RestoreReceiptStore store) => Directory(
  p.join(store.runDirectory.path, RestorePreviousStore.previousDirectoryName),
);

Future<void> _expectInitialAssets(
  RestoreProcessHarnessControl control,
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

Future<void> _expectInterruptedAssetSplit(
  RestoreProcessHarnessControl control,
  RestoreReceiptStore store,
) async {
  final candidate = _candidateDirectory(store);
  final previous = _previousDirectory(store);
  for (final root in restoreHarnessAssetRoots) {
    expect(
      await FileSystemEntity.type(
        p.join(control.appDataDirectory.path, root),
        followLinks: false,
      ),
      FileSystemEntityType.notFound,
    );
    expect(
      await File(p.join(candidate.path, root, 'new.txt')).readAsString(),
      'new:$root',
    );
    expect(
      await File(p.join(previous.path, root, 'old.txt')).readAsString(),
      'old:$root',
    );
  }
}

Future<void> _expectInstalledBundle(
  RestoreProcessHarnessControl control,
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
  RestoreProcessHarnessControl control,
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

Future<Map<String, dynamic>> _readCutoverEvent(
  RestoreProcessHarnessControl control,
  RestoreCompleteBundleFixtureState state,
) async {
  final event = await _readPriorEvent(
    control,
    generation: 2,
    phase: RestoreProcessHarnessPhase.cutoverKill,
    phaseKeys: const {'marker', 'runId', 'leaseInstanceId', 'liveDatabasePath'},
  );
  if (event['status'] != 'readyForKill' ||
      event['marker'] != restoreHarnessScenario ||
      event['runId'] != state.runId ||
      event['leaseInstanceId'] is! String ||
      !RegExp(
        _leaseInstancePattern,
      ).hasMatch(event['leaseInstanceId'] as String) ||
      event['liveDatabasePath'] !=
          p.normalize(p.absolute(_liveDatabase(control).path))) {
    throw const FormatException('restore_harness_cutover_event');
  }
  return event;
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
    'scenario',
    'scenarioId',
    'phase',
    'pid',
    'status',
    ...phaseKeys,
  };
  if (event.length != expectedKeys.length ||
      !event.keys.toSet().containsAll(expectedKeys) ||
      event['format'] != restoreHarnessFormat ||
      event['version'] != RestoreProcessHarnessControl.version ||
      event['generation'] != generation ||
      event['scenario'] != restoreHarnessScenario ||
      event['scenarioId'] != control.scenarioId ||
      event['phase'] != phase.name ||
      event['pid'] is! int ||
      (event['pid'] as int) < 1 ||
      event['status'] is! String) {
    throw const FormatException('restore_harness_event');
  }
  return event;
}

Future<void> _publishEvent(
  RestoreProcessHarnessControl control,
  Map<String, dynamic> phaseValues,
) {
  return writeDurableHarnessJson(control.eventFile, {
    'format': restoreHarnessFormat,
    'version': RestoreProcessHarnessControl.version,
    'generation': control.generation,
    'scenario': restoreHarnessScenario,
    'scenarioId': control.scenarioId,
    'phase': control.phase.name,
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

Future<void> _expectNoLeaseOwnerFiles(
  RestoreProcessHarnessControl control,
) async {
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
