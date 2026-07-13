import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_settings_cold_ack.dart';

import '../../../../integration_test/support/restore_process_hooks.dart';

const _runId = '0123456789abcdef0123456789abcdef';
const _manifestChecksum =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _previousChecksum =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _terminalChecksum =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _leaseInstanceId = '11111111111111111111111111111111';
const _primaryKey = 'rollback.prefix.primary';

void main() {
  group('rollback SharedPreferences hooks', () {
    test('fails only the configured exact set after prior successes', () async {
      final delegate = _ControllablePreferencesStore();
      final store = NthExactSetFailurePreferencesStore(
        delegate: delegate,
        prefixedKey: _primaryKey,
        failOnMatch: 3,
      );

      expect(
        await store.setValue('String', '$_primaryKey.other', 'ignored'),
        isTrue,
      );
      expect(store.successfulMatches, 0);
      expect(await store.setValue('String', _primaryKey, 'target-1'), isTrue);
      expect(await store.setValue('String', _primaryKey, 'target-2'), isTrue);
      expect(store.successfulMatches, 2);
      expect(store.didFail, isFalse);

      expect(await store.setValue('String', _primaryKey, 'target-3'), isFalse);
      expect(store.didFail, isTrue);
      expect(delegate.setCalls[_primaryKey], 2);

      expect(await store.setValue('String', _primaryKey, 'before'), isTrue);
      expect(delegate.setCalls[_primaryKey], 3);
      expect(store.successfulMatches, 2);
    });

    test('delegate false or throw never arms the injected failure', () async {
      final delegate = _ControllablePreferencesStore(setResult: false);
      final store = NthExactSetFailurePreferencesStore(
        delegate: delegate,
        prefixedKey: _primaryKey,
        failOnMatch: 3,
      );

      expect(await store.setValue('String', _primaryKey, 'target'), isFalse);
      expect(store.successfulMatches, 0);
      expect(store.didFail, isFalse);

      delegate
        ..setResult = true
        ..setError = StateError('delegate_set');
      await expectLater(
        store.setValue('String', _primaryKey, 'target'),
        throwsStateError,
      );
      expect(store.successfulMatches, 0);
      expect(store.didFail, isFalse);

      delegate.setError = null;
      expect(await store.setValue('String', _primaryKey, 'target-1'), isTrue);
      expect(await store.setValue('String', _primaryKey, 'target-2'), isTrue);
      expect(await store.setValue('String', _primaryKey, 'target-3'), isFalse);
      expect(store.didFail, isTrue);
    });

    test(
      'arms an exact set blocker only after the verified-stage failure',
      () async {
        const secretValue = 'must-not-appear-in-observation';
        final delegate = _ControllablePreferencesStore();
        final matched = Completer<RestorePreferenceMutationObservation>();
        late final NthExactSetFailurePreferencesStore trigger;
        final blocker = OneShotBlockingPreferencesStore(
          delegate: delegate,
          prefixedKey: _primaryKey,
          mutationKind: RestorePreferenceMutationKind.set,
          isArmed: () => trigger.didFail,
          onMatched: (observation) async => matched.complete(observation),
        );
        trigger = NthExactSetFailurePreferencesStore(
          delegate: blocker,
          prefixedKey: _primaryKey,
          failOnMatch: 3,
        );

        expect(
          await trigger.setValue('String', _primaryKey, 'target-1'),
          isTrue,
        );
        expect(
          await trigger.setValue('String', _primaryKey, 'target-2'),
          isTrue,
        );
        expect(blocker.didMatch, isFalse, reason: 'wrong stage must not block');
        expect(
          await trigger.setValue('String', _primaryKey, 'target-3'),
          isFalse,
        );
        expect(trigger.didFail, isTrue);

        expect(
          await trigger.setValue('String', '$_primaryKey.other', 'wrong-key'),
          isTrue,
        );
        expect(await trigger.remove(_primaryKey), isTrue);
        expect(blocker.didMatch, isFalse);

        final blocked = trigger.setValue('String', _primaryKey, secretValue);
        final observation = await matched.future;
        expect(observation.kind, RestorePreferenceMutationKind.set);
        expect(observation.prefixedKey, _primaryKey);
        expect(observation.valueType, 'String');
        expect(observation.toString(), isNot(contains(secretValue)));
        expect(blocker.didMatch, isTrue);
        expect(blocked, doesNotComplete);
      },
    );

    test(
      'post-failure remove blocker rejects wrong stage, key, and kind',
      () async {
        const targetOnlyKey = 'rollback.prefix.target_only';
        final delegate = _ControllablePreferencesStore();
        final matched = Completer<RestorePreferenceMutationObservation>();
        var armed = false;
        final blocker = OneShotBlockingPreferencesStore(
          delegate: delegate,
          prefixedKey: targetOnlyKey,
          mutationKind: RestorePreferenceMutationKind.remove,
          isArmed: () => armed,
          onMatched: (observation) async => matched.complete(observation),
        );

        expect(await blocker.remove(targetOnlyKey), isTrue);
        expect(blocker.didMatch, isFalse, reason: 'wrong stage must not block');
        armed = true;
        expect(await blocker.remove('$targetOnlyKey.other'), isTrue);
        expect(
          await blocker.setValue('String', targetOnlyKey, 'wrong-kind'),
          isTrue,
        );
        expect(blocker.didMatch, isFalse);

        final blocked = blocker.remove(targetOnlyKey);
        final observation = await matched.future;
        expect(observation.kind, RestorePreferenceMutationKind.remove);
        expect(observation.prefixedKey, targetOnlyKey);
        expect(observation.valueType, isNull);
        expect(blocker.didMatch, isTrue);
        expect(blocked, doesNotComplete);
      },
    );

    test(
      'blocker does not match when its delegate returns false or throws',
      () async {
        final delegate = _ControllablePreferencesStore(setResult: false);
        final blocker = OneShotBlockingPreferencesStore(
          delegate: delegate,
          prefixedKey: _primaryKey,
          mutationKind: RestorePreferenceMutationKind.set,
          isArmed: () => true,
          onMatched: (_) async => fail('unsuccessful mutation matched'),
        );

        expect(
          await blocker.setValue('String', _primaryKey, 'before'),
          isFalse,
        );
        expect(blocker.didMatch, isFalse);
        delegate
          ..setResult = true
          ..setError = StateError('delegate_set');
        await expectLater(
          blocker.setValue('String', _primaryKey, 'before'),
          throwsStateError,
        );
        expect(blocker.didMatch, isFalse);
      },
    );

    test('rejects invalid exact-set failure configuration', () {
      final delegate = _ControllablePreferencesStore();
      expect(
        () => NthExactSetFailurePreferencesStore(
          delegate: delegate,
          prefixedKey: '',
          failOnMatch: 3,
        ),
        throwsArgumentError,
      );
      expect(
        () => NthExactSetFailurePreferencesStore(
          delegate: delegate,
          prefixedKey: _primaryKey,
          failOnMatch: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('rollback database parent matcher', () {
    late Directory temporary;
    late Directory previous;
    late Directory previousDatabaseDirectory;
    late File previousDatabase;
    late File candidateDatabase;
    late File liveDatabase;
    late RestoreRollbackDatabaseParentSyncMatcher matcher;

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp(
        'kelivo_restore_rollback_hooks_',
      );
      previous = Directory(p.join(temporary.path, 'run_$_runId', 'previous'));
      previousDatabaseDirectory = Directory(p.join(previous.path, 'database'));
      previousDatabase = File(
        p.join(previousDatabaseDirectory.path, 'kelivo.db'),
      );
      candidateDatabase = File(
        p.join(
          temporary.path,
          'run_$_runId',
          'candidate',
          'database',
          'kelivo.db',
        ),
      );
      liveDatabase = File(p.join(temporary.path, 'app_data', 'kelivo.db'));
      await previousDatabase.parent.create(recursive: true);
      await previousDatabase.writeAsString('old');
      await liveDatabase.parent.create(recursive: true);
      await liveDatabase.writeAsString('new');
      matcher = RestoreRollbackDatabaseParentSyncMatcher(
        previousDirectoryPath: previous.path,
        previousDatabaseDirectoryPath: previousDatabaseDirectory.path,
        candidateDatabasePath: candidateDatabase.path,
        liveDatabasePath: liveDatabase.path,
      );
    });

    tearDown(() async {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    });

    test('matches only after both reverse moves and parent removal', () async {
      expect(
        await matcher.matchDirectorySync(
          directory: previous,
          fullBarrier: true,
        ),
        isNull,
        reason: 'new database has not returned to candidate',
      );

      await candidateDatabase.parent.create(recursive: true);
      await liveDatabase.rename(candidateDatabase.path);
      expect(
        await matcher.matchDirectorySync(
          directory: previous,
          fullBarrier: true,
        ),
        isNull,
        reason: 'old database has not returned to live',
      );

      await previousDatabase.rename(liveDatabase.path);
      expect(
        await matcher.matchDirectorySync(
          directory: previous,
          fullBarrier: true,
        ),
        isNull,
        reason: 'empty previous database parent is still visible',
      );

      await previousDatabaseDirectory.delete();
      expect(
        await matcher.matchDirectorySync(
          directory: previous,
          fullBarrier: false,
        ),
        isNull,
      );
      expect(
        await matcher.matchDirectorySync(
          directory: Directory(p.join(temporary.path, 'other')),
          fullBarrier: true,
        ),
        isNull,
      );

      final observation = await matcher.matchDirectorySync(
        directory: previous,
        fullBarrier: true,
      );
      expect(observation, isA<RestoreDirectorySyncObservation>());
      final sync = observation! as RestoreDirectorySyncObservation;
      expect(sync.path, previous.path);
      expect(sync.fullBarrier, isTrue);

      await liveDatabase.delete();
      expect(
        await matcher.matchDirectorySync(
          directory: previous,
          fullBarrier: true,
        ),
        isNull,
      );
    });

    test('requires the previous database directory to be a direct child', () {
      expect(
        () => RestoreRollbackDatabaseParentSyncMatcher(
          previousDirectoryPath: previous.path,
          previousDatabaseDirectoryPath: p.join(
            previous.path,
            'nested',
            'database',
          ),
          candidateDatabasePath: candidateDatabase.path,
          liveDatabasePath: liveDatabase.path,
        ),
        throwsArgumentError,
      );
    });
  });

  test(
    'rollback receipt matchers accept verified-origin sequences 5 and 6',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'kelivo_restore_rollback_receipts_',
      );
      addTearDown(() async {
        if (await temporary.exists()) await temporary.delete(recursive: true);
      });
      final receiptDirectory = Directory(
        p.join(temporary.path, 'run_$_runId', 'receipts'),
      );
      await receiptDirectory.create(recursive: true);
      final prepared = RestoreReceipt.prepared(
        runId: _runId,
        createdAtUtc: DateTime.utc(2026, 7, 10),
        restoreChats: true,
        restoreFiles: true,
        candidateManifestSha256: _manifestChecksum,
      );
      final oldRenamed = prepared.advance(
        RestoreReceiptState.oldRenamed,
        previousManifestSha256: _previousChecksum,
      );
      final verified = oldRenamed
          .advance(RestoreReceiptState.newInstalled)
          .advance(RestoreReceiptState.verified);
      final rollingBack = verified.advance(RestoreReceiptState.rollingBack);
      final rolledBack = rollingBack.advance(RestoreReceiptState.rolledBack);
      expect(rollingBack.sequence, 5);
      expect(rolledBack.sequence, 6);

      for (final receipt in [rollingBack, rolledBack]) {
        final digits = receipt.sequence.toString().padLeft(16, '0');
        final temporaryReceipt = File(
          p.join(receiptDirectory.path, 'receipt_$digits.json.123_456.tmp'),
        );
        await temporaryReceipt.writeAsString(jsonEncode(receipt.toJson()));
        final tempObservation = await RestoreReceiptTempDurableMatcher(
          receiptDirectoryPath: receiptDirectory.path,
          sequence: receipt.sequence,
          state: receipt.state,
        ).matchFileSync(file: temporaryReceipt, fullBarrier: true);
        expect(tempObservation, isA<RestoreReceiptDurabilityObservation>());
        expect(
          (tempObservation! as RestoreReceiptDurabilityObservation).boundary,
          RestoreReceiptDurabilityBoundary.tempDurable,
        );

        final publishedObservation =
            await RestoreReceiptPublishedMatcher(
              receiptDirectoryPath: receiptDirectory.path,
              sequence: receipt.sequence,
              state: receipt.state,
            ).matchRename(
              source: temporaryReceipt,
              targetPath: p.join(receiptDirectory.path, 'receipt_$digits.json'),
            );
        expect(
          publishedObservation,
          isA<RestoreReceiptDurabilityObservation>(),
        );
        expect(
          (publishedObservation! as RestoreReceiptDurabilityObservation)
              .boundary,
          RestoreReceiptDurabilityBoundary.published,
        );
      }
    },
  );

  test('cold-ack matchers accept the rolled-back before projection', () async {
    const processId = 456;
    final temporary = await Directory.systemTemp.createTemp(
      'kelivo_restore_rollback_ack_',
    );
    addTearDown(() async {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    });
    final runDirectory = Directory(p.join(temporary.path, 'run_$_runId'));
    await runDirectory.create();
    final ack = RestoreSettingsColdAck(
      runId: _runId,
      terminalReceiptChecksum: _terminalChecksum,
      expected: RestoreSettingsColdAckExpected.before,
      processId: processId,
      leaseInstanceId: _leaseInstanceId,
    );
    final temporaryAck = File(
      p.join(
        runDirectory.path,
        '${RestoreSettingsColdAckStore.fileName}.123_${processId}_0.tmp',
      ),
    );
    await temporaryAck.writeAsString(jsonEncode(ack.toJson()));

    final tempObservation = await RestoreColdAckTempDurableMatcher(
      runDirectoryPath: runDirectory.path,
      terminalReceiptChecksum: _terminalChecksum,
      expected: RestoreSettingsColdAckExpected.before,
      processId: processId,
      leaseInstanceId: _leaseInstanceId,
    ).matchFileSync(file: temporaryAck, fullBarrier: true);
    expect(tempObservation, isA<RestoreColdAckDurabilityObservation>());
    expect(
      (tempObservation! as RestoreColdAckDurabilityObservation).expected,
      RestoreSettingsColdAckExpected.before,
    );

    final publishedObservation =
        await RestoreColdAckPublishedMatcher(
          runDirectoryPath: runDirectory.path,
          terminalReceiptChecksum: _terminalChecksum,
          expected: RestoreSettingsColdAckExpected.before,
          processId: processId,
          leaseInstanceId: _leaseInstanceId,
        ).matchRename(
          source: temporaryAck,
          targetPath: p.join(
            runDirectory.path,
            RestoreSettingsColdAckStore.fileName,
          ),
        );
    expect(publishedObservation, isA<RestoreColdAckDurabilityObservation>());
    expect(
      (publishedObservation! as RestoreColdAckDurabilityObservation).expected,
      RestoreSettingsColdAckExpected.before,
    );
  });
}

final class _ControllablePreferencesStore
    extends SharedPreferencesStorePlatform {
  _ControllablePreferencesStore({this.setResult = true});

  bool setResult;
  Object? setError;
  final removeCalls = <String, int>{};
  final setCalls = <String, int>{};

  @override
  Future<bool> clear() async => true;

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async => true;

  @override
  Future<Map<String, Object>> getAll() async => const {};

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async => const {};

  @override
  Future<bool> remove(String key) async {
    removeCalls.update(key, (count) => count + 1, ifAbsent: () => 1);
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    setCalls.update(key, (count) => count + 1, ifAbsent: () => 1);
    final error = setError;
    if (error != null) throw error;
    return setResult;
  }
}
