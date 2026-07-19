import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

import 'support/restore_complete_bundle_fixture.dart';
import 'support/restore_process_control.dart';
import 'support/restore_process_hooks.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('executes one host-controlled two-leg restore phase', (
    tester,
  ) async {
    final control = await RestoreProcessHarnessControl.readFromEnvironment();
    switch (control.phase) {
      case RestoreProcessHarnessPhase.setup:
        await _setup(control);
      case RestoreProcessHarnessPhase.interrupt:
        await _interrupt(control);
      case RestoreProcessHarnessPhase.resume:
        await _resume(control);
      case RestoreProcessHarnessPhase.verify:
        await _verify(control);
    }
  });
}

Future<void> _setup(RestoreProcessHarnessControl control) async {
  if (await FileSystemEntity.type(control.stateFile.path, followLinks: false) !=
      FileSystemEntityType.notFound) {
    throw StateError('restore_harness_setup_existing_state');
  }
  String runId;
  if (control.failpoint.isPartialMarker) {
    runId = control.scenarioId;
    final workspace = Directory(
      p.join(
        control.appDataDirectory.path,
        RestoreWorkspaceLock.workspaceRootName,
      ),
    );
    await workspace.create(recursive: true);
    await File(
      p.join(workspace.path, RestoreWorkspaceLock.publishingRunFileName),
    ).writeAsString(runId, flush: true);
    await writeDurableHarnessJson(control.stateFile, {
      'format': restoreHarnessFormat,
      'version': 1,
      'matrixRunId': control.matrixRunId,
      'failpoint': control.failpointName,
      'runId': runId,
    });
  } else {
    final fixture = await prepareCompleteBundleFixture(control);
    runId = fixture.runId;
    await writeDurableHarnessJson(control.stateFile, fixture.toJson());
  }
  await _publishEvent(control, {
    'status': 'setup',
    'runId': runId,
    'processId': pid,
  });
}

Future<void> _interrupt(RestoreProcessHarnessControl control) async {
  if (control.failpoint.isPartialMarker) {
    await _expectMarkerFailClosed(control);
    await _publishEvent(control, {
      'status': 'failClosed',
      'runId': control.scenarioId,
      'processId': pid,
    });
    return;
  }

  final state = await RestoreCompleteBundleFixtureState.read(control);
  final durability = RestoreProcessBoundaryDurability(
    appDataDirectory: control.appDataDirectory,
    runId: state.runId,
    failpoint: control.failpoint,
    delegate: RestorePlatformDurability(),
    triggerRollback: control.failpoint.triggersRollback,
    onBoundary: (failpoint) async {
      await _publishEvent(control, {
        'status': 'boundary',
        'runId': state.runId,
        'boundary': failpoint.name,
        'processId': pid,
      });
      await Completer<void>().future;
    },
  );

  await RestoreStartupGate.recoverAndRequireBusinessReady(
    appDataDirectory: control.appDataDirectory,
    durability: durability,
  );
  throw StateError('restore_harness_boundary_not_reached');
}

Future<void> _resume(RestoreProcessHarnessControl control) async {
  if (control.failpoint.isPartialMarker) {
    await _expectMarkerFailClosed(control);
    await _publishEvent(control, {
      'status': 'resumedFailClosed',
      'runId': control.scenarioId,
      'processId': pid,
    });
    return;
  }

  final state = await RestoreCompleteBundleFixtureState.read(control);
  final terminal = await RestoreStartupGate.recoverAndRequireBusinessReady(
    appDataDirectory: control.appDataDirectory,
  );
  final expectedState = control.failpoint.triggersRollback
      ? RestoreReceiptState.rolledBack
      : RestoreReceiptState.committed;
  if (terminal == null) {
    if (control.failpoint !=
        RestoreProcessFailpoint.archivingMarkerRemovedDurable) {
      throw StateError('restore_harness_resume_missing_terminal');
    }
  } else if (terminal.state != expectedState) {
    throw StateError('restore_harness_resume_terminal_state');
  }
  await _validateBundleProjection(
    control: control,
    state: state,
    rolledBack: control.failpoint.triggersRollback,
  );
  await _publishEvent(control, {
    'status': 'resumed',
    'runId': state.runId,
    'terminalState': expectedState.name,
    'processId': pid,
  });
}

Future<void> _verify(RestoreProcessHarnessControl control) async {
  if (control.failpoint.isPartialMarker) {
    await _expectMarkerFailClosed(control);
    await _publishEvent(control, {
      'status': 'verifiedFailClosed',
      'runId': control.scenarioId,
      'processId': pid,
    });
    return;
  }

  final state = await RestoreCompleteBundleFixtureState.read(control);
  final result = await RestoreStartupGate.recoverAndRequireBusinessReady(
    appDataDirectory: control.appDataDirectory,
  );
  if (result != null) {
    throw StateError('restore_harness_verify_pending_restore');
  }
  await _validateBundleProjection(
    control: control,
    state: state,
    rolledBack: control.failpoint.triggersRollback,
  );
  await _publishEvent(control, {
    'status': 'verified',
    'runId': state.runId,
    'processId': pid,
  });
}

Future<void> _validateBundleProjection({
  required RestoreProcessHarnessControl control,
  required RestoreCompleteBundleFixtureState state,
  required bool rolledBack,
}) async {
  final expectedConversation = rolledBack
      ? state.oldConversationId
      : state.newConversationId;
  final conversations = await harnessConversationIds(
    File(p.join(control.appDataDirectory.path, AppDatabase.databaseFileName)),
  );
  if (conversations.length != 1 ||
      conversations.single != expectedConversation) {
    throw StateError('restore_harness_database_projection');
  }
  for (final root in restoreHarnessAssetRoots) {
    final expectedName = rolledBack ? 'old.txt' : 'new.txt';
    final expectedContents = rolledBack ? 'old:$root' : 'new:$root';
    final file = File(
      p.join(control.appDataDirectory.path, root, expectedName),
    );
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.readAsString() != expectedContents) {
      throw StateError('restore_harness_asset_projection:$root');
    }
  }

  final archivedRun = Directory(
    p.join(
      control.appDataDirectory.path,
      RestoreWorkspaceLock.workspaceRootName,
      RestoreWorkspaceLock.completedRunsDirectoryName,
      'run_${state.runId}',
    ),
  );
  if (await FileSystemEntity.type(archivedRun.path, followLinks: false) !=
      FileSystemEntityType.directory) {
    throw StateError('restore_harness_terminal_archive');
  }
  await for (final entity in archivedRun.list(
    recursive: true,
    followLinks: false,
  )) {
    final name = p.basename(entity.path);
    if (name == 'settings.json' || name.startsWith('settings_cold_ack.json')) {
      throw StateError('restore_harness_retired_settings_trace');
    }
  }
}

Future<void> _expectMarkerFailClosed(
  RestoreProcessHarnessControl control,
) async {
  Object? failure;
  try {
    await RestoreStartupGate.recoverAndRequireBusinessReady(
      appDataDirectory: control.appDataDirectory,
    );
  } catch (error) {
    failure = error;
  }
  if (failure is! StateError) {
    throw StateError('restore_harness_marker_not_fail_closed');
  }
  final marker = File(
    p.join(
      control.appDataDirectory.path,
      RestoreWorkspaceLock.workspaceRootName,
      RestoreWorkspaceLock.publishingRunFileName,
    ),
  );
  if (await FileSystemEntity.type(marker.path, followLinks: false) !=
          FileSystemEntityType.file ||
      await marker.readAsString() != control.scenarioId) {
    throw StateError('restore_harness_marker_mutated');
  }
}

Future<void> _publishEvent(
  RestoreProcessHarnessControl control,
  Map<String, dynamic> payload,
) {
  return writeDurableHarnessJson(control.eventFile, {
    'format': restoreHarnessFormat,
    'version': 1,
    'matrixRunId': control.matrixRunId,
    'scenarioId': control.scenarioId,
    'generation': control.generation,
    'phase': control.phaseName,
    'failpoint': control.failpointName,
    ...payload,
  });
}
