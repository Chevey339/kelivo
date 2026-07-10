import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_settings_cold_ack.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

import '../../../../integration_test/support/restore_process_hooks.dart';

const _runId = '0123456789abcdef0123456789abcdef';
const _receiptChecksum =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherReceiptChecksum =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _leaseInstanceId = 'fedcba9876543210fedcba9876543210';
const _otherLeaseInstanceId = '11111111111111111111111111111111';
const _processId = 4242;

void main() {
  group('terminal cold-ack durability matchers', () {
    late Directory temporary;
    late Directory runDirectory;

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp(
        'kelivo_restore_terminal_ack_hook_',
      );
      runDirectory = Directory(
        p.join(
          temporary.path,
          RestoreWorkspaceLock.workspaceRootName,
          'run_$_runId',
        ),
      );
      await runDirectory.create(recursive: true);
    });

    tearDown(() async {
      if (await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    });

    test(
      'matches canonical temp-durable and exact dynamic-temp publish',
      () async {
        final temporaryAck = await _writeColdAckTemporary(runDirectory);
        final tempMatcher = _tempMatcher(runDirectory);
        final publishMatcher = _publishMatcher(runDirectory);

        final tempObservation = await tempMatcher.matchFileSync(
          file: temporaryAck,
          fullBarrier: true,
        );
        expect(tempObservation, isA<RestoreColdAckDurabilityObservation>());
        final temp = tempObservation! as RestoreColdAckDurabilityObservation;
        expect(temp.boundary, RestoreColdAckDurabilityBoundary.tempDurable);
        expect(temp.runId, _runId);
        expect(temp.terminalReceiptChecksum, _receiptChecksum);
        expect(temp.expected, RestoreSettingsColdAckExpected.target);
        expect(temp.processId, _processId);
        expect(temp.leaseInstanceId, _leaseInstanceId);
        expect(temp.ackChecksum, hasLength(64));
        expect(temp.temporaryPath, temporaryAck.path);
        expect(temp.targetPath, isNull);

        final publishObservation = await publishMatcher.matchRename(
          source: temporaryAck,
          targetPath: publishMatcher.targetPath,
        );
        expect(publishObservation, isA<RestoreColdAckDurabilityObservation>());
        final published =
            publishObservation! as RestoreColdAckDurabilityObservation;
        expect(published.boundary, RestoreColdAckDurabilityBoundary.published);
        expect(published.temporaryPath, temporaryAck.path);
        expect(
          published.targetPath,
          p.join(runDirectory.path, RestoreSettingsColdAckStore.fileName),
        );
      },
    );

    test(
      'rejects non-full, wrong path or direction, and mismatched bindings',
      () async {
        final matching = await _writeColdAckTemporary(runDirectory);
        final tempMatcher = _tempMatcher(runDirectory);
        final publishMatcher = _publishMatcher(runDirectory);

        expect(
          await tempMatcher.matchFileSync(file: matching, fullBarrier: false),
          isNull,
        );

        final otherRunDirectory = Directory(
          p.join(temporary.path, 'other', 'run_$_runId'),
        );
        await otherRunDirectory.create(recursive: true);
        final wrongPath = await _writeColdAckTemporary(otherRunDirectory);
        expect(
          await tempMatcher.matchFileSync(file: wrongPath, fullBarrier: true),
          isNull,
        );
        expect(
          await publishMatcher.matchRename(
            source: matching,
            targetPath: '${publishMatcher.targetPath}.other',
          ),
          isNull,
        );
        final finalAck = File(publishMatcher.targetPath);
        await finalAck.writeAsString(await matching.readAsString());
        expect(
          await publishMatcher.matchRename(
            source: finalAck,
            targetPath: publishMatcher.targetPath,
          ),
          isNull,
        );
        expect(
          await publishMatcher.matchRename(
            source: matching,
            targetPath: matching.path,
          ),
          isNull,
        );

        final wrongChecksum = await _writeColdAckTemporary(
          runDirectory,
          timestamp: 2,
          terminalReceiptChecksum: _otherReceiptChecksum,
        );
        expect(
          await tempMatcher.matchFileSync(
            file: wrongChecksum,
            fullBarrier: true,
          ),
          isNull,
        );
        final wrongProcess = await _writeColdAckTemporary(
          runDirectory,
          timestamp: 3,
          processId: _processId + 1,
        );
        expect(
          await tempMatcher.matchFileSync(
            file: wrongProcess,
            fullBarrier: true,
          ),
          isNull,
        );
        final forgedProcessName = File(
          p.join(
            runDirectory.path,
            '${RestoreSettingsColdAckStore.fileName}.8_${_processId}_0.tmp',
          ),
        );
        await forgedProcessName.writeAsString(
          await wrongProcess.readAsString(),
        );
        expect(
          await tempMatcher.matchFileSync(
            file: forgedProcessName,
            fullBarrier: true,
          ),
          isNull,
        );
        final wrongLease = await _writeColdAckTemporary(
          runDirectory,
          timestamp: 4,
          leaseInstanceId: _otherLeaseInstanceId,
        );
        expect(
          await tempMatcher.matchFileSync(file: wrongLease, fullBarrier: true),
          isNull,
        );
        final wrongExpected = await _writeColdAckTemporary(
          runDirectory,
          timestamp: 5,
          expected: RestoreSettingsColdAckExpected.before,
        );
        expect(
          await tempMatcher.matchFileSync(
            file: wrongExpected,
            fullBarrier: true,
          ),
          isNull,
        );
      },
    );

    test(
      'requires canonical ack bytes for a matching temporary name',
      () async {
        final ack = _coldAck();
        final json = ack.toJson();
        final reordered = <String, dynamic>{
          'checksum': json['checksum'],
          'processId': json['processId'],
          'leaseInstanceId': json['leaseInstanceId'],
          'expected': json['expected'],
          'terminalReceiptChecksum': json['terminalReceiptChecksum'],
          'runId': json['runId'],
          'version': json['version'],
        };
        final source = File(
          p.join(
            runDirectory.path,
            '${RestoreSettingsColdAckStore.fileName}.6_${_processId}_0.tmp',
          ),
        );
        await source.writeAsString(jsonEncode(reordered));

        await expectLater(
          _tempMatcher(
            runDirectory,
          ).matchFileSync(file: source, fullBarrier: true),
          throwsFormatException,
        );

        final corruptedChecksum = ack.toJson()
          ..['checksum'] = 'c' * _receiptChecksum.length;
        final corrupted = File(
          p.join(
            runDirectory.path,
            '${RestoreSettingsColdAckStore.fileName}.7_${_processId}_0.tmp',
          ),
        );
        await corrupted.writeAsString(jsonEncode(corruptedChecksum));
        await expectLater(
          _tempMatcher(
            runDirectory,
          ).matchFileSync(file: corrupted, fullBarrier: true),
          throwsFormatException,
        );
      },
    );

    test('notifies only after a successful durability delegate call', () async {
      final source = await _writeColdAckTemporary(runDirectory);
      final successfulDelegate = _ControllableDurability();
      final matched = Completer<RestoreColdAckDurabilityObservation>();
      final hook = OneShotBlockingRestoreDurability(
        delegate: successfulDelegate,
        matcher: _tempMatcher(runDirectory),
        onMatched: (observation) async {
          expect(successfulDelegate.fileSyncCompleted, isTrue);
          matched.complete(observation as RestoreColdAckDurabilityObservation);
        },
      );

      final blocked = hook.syncFile(source, fullBarrier: true);
      expect(
        (await matched.future).boundary,
        RestoreColdAckDurabilityBoundary.tempDurable,
      );
      expect(hook.didMatch, isTrue);
      expect(blocked, doesNotComplete);

      final failedDelegate = _ControllableDurability(failFileSync: true);
      var callbackCalled = false;
      final failedHook = OneShotBlockingRestoreDurability(
        delegate: failedDelegate,
        matcher: _tempMatcher(runDirectory),
        onMatched: (_) async => callbackCalled = true,
      );
      await expectLater(
        failedHook.syncFile(source, fullBarrier: true),
        throwsStateError,
      );
      expect(callbackCalled, isFalse);
      expect(failedHook.didMatch, isFalse);
    });
  });

  group('terminal workspace sync matcher', () {
    late Directory temporary;
    late Directory workspaceRoot;
    late Directory completedRunsRoot;
    late Directory activeRun;
    late Directory completedRun;
    late File publishingMarker;
    late File archivingMarker;
    late RestoreTerminalWorkspaceSyncMatcher completedRootMatcher;
    late RestoreTerminalWorkspaceSyncMatcher markerRemovedMatcher;

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp(
        'kelivo_restore_terminal_workspace_hook_',
      );
      workspaceRoot = Directory(
        p.join(temporary.path, RestoreWorkspaceLock.workspaceRootName),
      );
      completedRunsRoot = Directory(
        p.join(
          workspaceRoot.path,
          RestoreWorkspaceLock.completedRunsDirectoryName,
        ),
      );
      activeRun = Directory(p.join(workspaceRoot.path, 'run_$_runId'));
      completedRun = Directory(p.join(completedRunsRoot.path, 'run_$_runId'));
      publishingMarker = File(
        p.join(workspaceRoot.path, RestoreWorkspaceLock.publishingRunFileName),
      );
      archivingMarker = File(
        p.join(workspaceRoot.path, RestoreWorkspaceLock.archivingRunFileName),
      );
      completedRootMatcher = RestoreTerminalWorkspaceSyncMatcher(
        workspaceRootPath: workspaceRoot.path,
        runId: _runId,
        boundary: RestoreTerminalWorkspaceSyncBoundary.completedRunsRootDurable,
      );
      markerRemovedMatcher = RestoreTerminalWorkspaceSyncMatcher(
        workspaceRootPath: workspaceRoot.path,
        runId: _runId,
        boundary:
            RestoreTerminalWorkspaceSyncBoundary.archivingMarkerRemovedDurable,
      );
      await completedRunsRoot.create(recursive: true);
    });

    tearDown(() async {
      if (await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    });

    test(
      'distinguishes completed-root durability from post-archive marker removal',
      () async {
        await activeRun.create();
        await publishingMarker.writeAsString(_runId);

        final completedObservation = await completedRootMatcher
            .matchDirectorySync(directory: workspaceRoot, fullBarrier: true);
        expect(
          completedObservation,
          isA<RestoreTerminalWorkspaceSyncObservation>(),
        );
        final completed =
            completedObservation! as RestoreTerminalWorkspaceSyncObservation;
        expect(
          completed.boundary,
          RestoreTerminalWorkspaceSyncBoundary.completedRunsRootDurable,
        );
        expect(completed.activeRunPath, activeRun.path);
        expect(completed.completedRunPath, completedRun.path);
        expect(
          await markerRemovedMatcher.matchDirectorySync(
            directory: workspaceRoot,
            fullBarrier: true,
          ),
          isNull,
        );

        await publishingMarker.rename(archivingMarker.path);
        await activeRun.rename(completedRun.path);
        expect(
          await markerRemovedMatcher.matchDirectorySync(
            directory: workspaceRoot,
            fullBarrier: true,
          ),
          isNull,
          reason: 'archiving marker still protects the already moved run',
        );
        await archivingMarker.delete();

        final removedObservation = await markerRemovedMatcher
            .matchDirectorySync(directory: workspaceRoot, fullBarrier: true);
        expect(
          removedObservation,
          isA<RestoreTerminalWorkspaceSyncObservation>(),
        );
        final removed =
            removedObservation! as RestoreTerminalWorkspaceSyncObservation;
        expect(
          removed.boundary,
          RestoreTerminalWorkspaceSyncBoundary.archivingMarkerRemovedDurable,
        );
        expect(await activeRun.exists(), isFalse);
        expect(await completedRun.exists(), isTrue);
        expect(
          await completedRootMatcher.matchDirectorySync(
            directory: workspaceRoot,
            fullBarrier: true,
          ),
          isNull,
        );
      },
    );

    test(
      'rejects non-full, wrong path, marker overlap, and wrong entity types',
      () async {
        await activeRun.create();
        await publishingMarker.writeAsString(_runId);
        final otherDirectory = Directory(p.join(temporary.path, 'other'));
        await otherDirectory.create();

        expect(
          await completedRootMatcher.matchDirectorySync(
            directory: workspaceRoot,
            fullBarrier: false,
          ),
          isNull,
        );
        expect(
          await completedRootMatcher.matchDirectorySync(
            directory: otherDirectory,
            fullBarrier: true,
          ),
          isNull,
        );
        await archivingMarker.writeAsString(_runId);
        expect(
          await completedRootMatcher.matchDirectorySync(
            directory: workspaceRoot,
            fullBarrier: true,
          ),
          isNull,
        );
        await archivingMarker.delete();
        final wrongTargetType = File(completedRun.path);
        await wrongTargetType.writeAsString('not-a-directory');
        expect(
          await completedRootMatcher.matchDirectorySync(
            directory: workspaceRoot,
            fullBarrier: true,
          ),
          isNull,
        );
      },
    );
  });

  group('counting mutation preferences store', () {
    test(
      'passes through reads and counts each successful mutation attempt',
      () async {
        final delegate = _ControllablePreferencesStore();
        final store = CountingMutationPreferencesStore(delegate);
        final filter = PreferencesFilter(
          prefix: 'restore.',
          allowList: {'restore.primary'},
        );
        final getParameters = GetAllParameters(filter: filter);
        final clearParameters = ClearParameters(filter: filter);

        expect(await store.getAll(), {'existing': 'value'});
        expect(await store.getAllWithParameters(getParameters), {
          'existing': 'value',
        });
        expect(store.mutationAttempts, 0);

        expect(await store.clear(), isTrue);
        expect(await store.clearWithParameters(clearParameters), isTrue);
        expect(await store.remove('restore.primary'), isTrue);
        expect(
          await store.setValue(
            'String',
            'restore.primary',
            'sensitive-setting-value',
          ),
          isTrue,
        );
        expect(store.mutationAttempts, 4);
        expect(delegate.mutationAttempts, 4);
        expect(delegate.lastSetValueType, 'String');
        expect(delegate.lastSetKey, 'restore.primary');
        expect(delegate.lastClearParameters, same(clearParameters));
      },
    );

    test(
      'counts delegated false results and thrown mutation attempts',
      () async {
        final delegate = _ControllablePreferencesStore(mutationResult: false);
        final store = CountingMutationPreferencesStore(delegate);

        expect(await store.remove('restore.primary'), isFalse);
        expect(store.mutationAttempts, 1);
        expect(delegate.mutationAttempts, 1);

        delegate.throwOnMutation = true;
        await expectLater(
          store.setValue(
            'String',
            'restore.primary',
            'must-not-be-retained-by-wrapper',
          ),
          throwsStateError,
        );
        expect(store.mutationAttempts, 2);
        expect(delegate.mutationAttempts, 2);
      },
    );
  });
}

RestoreColdAckTempDurableMatcher _tempMatcher(Directory runDirectory) {
  return RestoreColdAckTempDurableMatcher(
    runDirectoryPath: runDirectory.path,
    terminalReceiptChecksum: _receiptChecksum,
    expected: RestoreSettingsColdAckExpected.target,
    processId: _processId,
    leaseInstanceId: _leaseInstanceId,
  );
}

RestoreColdAckPublishedMatcher _publishMatcher(Directory runDirectory) {
  return RestoreColdAckPublishedMatcher(
    runDirectoryPath: runDirectory.path,
    terminalReceiptChecksum: _receiptChecksum,
    expected: RestoreSettingsColdAckExpected.target,
    processId: _processId,
    leaseInstanceId: _leaseInstanceId,
  );
}

RestoreSettingsColdAck _coldAck({
  String terminalReceiptChecksum = _receiptChecksum,
  RestoreSettingsColdAckExpected expected =
      RestoreSettingsColdAckExpected.target,
  int processId = _processId,
  String leaseInstanceId = _leaseInstanceId,
}) {
  return RestoreSettingsColdAck(
    runId: _runId,
    terminalReceiptChecksum: terminalReceiptChecksum,
    expected: expected,
    leaseInstanceId: leaseInstanceId,
    processId: processId,
  );
}

Future<File> _writeColdAckTemporary(
  Directory runDirectory, {
  int timestamp = 1,
  String terminalReceiptChecksum = _receiptChecksum,
  RestoreSettingsColdAckExpected expected =
      RestoreSettingsColdAckExpected.target,
  int processId = _processId,
  String leaseInstanceId = _leaseInstanceId,
}) async {
  final ack = _coldAck(
    terminalReceiptChecksum: terminalReceiptChecksum,
    expected: expected,
    processId: processId,
    leaseInstanceId: leaseInstanceId,
  );
  final file = File(
    p.join(
      runDirectory.path,
      '${RestoreSettingsColdAckStore.fileName}.'
      '${timestamp}_${processId}_0.tmp',
    ),
  );
  await file.writeAsString(jsonEncode(ack.toJson()));
  return file;
}

final class _ControllableDurability implements RestoreDurability {
  _ControllableDurability({this.failFileSync = false});

  final bool failFileSync;
  bool fileSyncCompleted = false;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {}

  @override
  Future<void> restrictDirectory(Directory directory) async {}

  @override
  Future<void> restrictFile(File file) async {}

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {}

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {
    if (failFileSync) throw StateError('injected_file_sync_failure');
    fileSyncCompleted = true;
  }
}

final class _ControllablePreferencesStore
    extends SharedPreferencesStorePlatform {
  _ControllablePreferencesStore({this.mutationResult = true});

  final bool mutationResult;
  bool throwOnMutation = false;
  int mutationAttempts = 0;
  String? lastSetValueType;
  String? lastSetKey;
  ClearParameters? lastClearParameters;

  Future<bool> _mutate() async {
    mutationAttempts++;
    if (throwOnMutation) {
      throw StateError('injected_preferences_mutation_failure');
    }
    return mutationResult;
  }

  @override
  Future<bool> clear() => _mutate();

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) {
    lastClearParameters = parameters;
    return _mutate();
  }

  @override
  Future<Map<String, Object>> getAll() async => {'existing': 'value'};

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async => {'existing': 'value'};

  @override
  Future<bool> remove(String key) => _mutate();

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    lastSetValueType = valueType;
    lastSetKey = key;
    return _mutate();
  }
}
