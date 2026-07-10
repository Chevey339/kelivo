import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';

import '../../../../integration_test/support/restore_complete_bundle_fixture.dart';
import '../../../../integration_test/support/restore_process_control.dart';
import '../../../../integration_test/support/restore_process_hooks.dart';

const _scenarioId = '0123456789abcdef0123456789abcdef';
const _matrixRunId = 'fedcba9876543210fedcba9876543210';
const _checksumA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _checksumB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  group('RestoreProcessHarnessControl', () {
    test('round-trips every failpoint through all four ordered phases', () {
      for (final failpoint in RestoreProcessFailpoint.values) {
        for (final phase in RestoreProcessHarnessPhase.values) {
          final control = _control(phase: phase, failpoint: failpoint);

          final decoded = RestoreProcessHarnessControl.fromJson(
            control.toJson(),
          );
          expect(decoded.generation, phase.index + 1);
          expect(decoded.matrixRunId, _matrixRunId);
          expect(decoded.phase, phase);
          expect(decoded.failpoint, failpoint);
          expect(decoded.scenarioId, _scenarioId);
          expect(decoded.scenarioRoot, _scenarioRoot());
          expect(
            decoded.preferencesPrefix,
            restoreProcessPreferencesPrefix(
              matrixRunId: _matrixRunId,
              scenarioId: _scenarioId,
              failpoint: failpoint,
            ),
          );
        }
      }
    });

    test('publishes stable smoke, core, and full tiers', () {
      expect(RestoreProcessFailpoint.values, [
        RestoreProcessFailpoint.cutoverClaimPublished,
        RestoreProcessFailpoint.liveDatabaseNormalized,
        RestoreProcessFailpoint.previousSettingsPublished,
        RestoreProcessFailpoint.previousManifestPublished,
        RestoreProcessFailpoint.previousUploadMoved,
        RestoreProcessFailpoint.previousImagesMoved,
        RestoreProcessFailpoint.previousAvatarsMoved,
        RestoreProcessFailpoint.previousFontsMoved,
        RestoreProcessFailpoint.previousDatabaseMoved,
        RestoreProcessFailpoint.previousPromoted,
        RestoreProcessFailpoint.oldRenamedReceiptTempDurable,
        RestoreProcessFailpoint.oldRenamedReceiptPublished,
        RestoreProcessFailpoint.settingsSecretRemoved,
        RestoreProcessFailpoint.settingsFirstSet,
        RestoreProcessFailpoint.candidateDatabaseMoved,
        RestoreProcessFailpoint.candidateUploadMoved,
        RestoreProcessFailpoint.candidateImagesMoved,
        RestoreProcessFailpoint.candidateAvatarsMoved,
        RestoreProcessFailpoint.candidateFontsMoved,
        RestoreProcessFailpoint.newInstalledReceiptTempDurable,
        RestoreProcessFailpoint.newInstalledReceiptPublished,
        RestoreProcessFailpoint.verifiedReceiptTempDurable,
        RestoreProcessFailpoint.verifiedReceiptPublished,
        RestoreProcessFailpoint.committedReceiptTempDurable,
        RestoreProcessFailpoint.committedReceiptPublished,
      ]);
      expect(restoreProcessSmokeFailpoints, [
        RestoreProcessFailpoint.candidateDatabaseMoved,
      ]);
      expect(restoreProcessFullFailpoints, RestoreProcessFailpoint.values);
      expect(
        restoreProcessFullFailpoints.toSet().length,
        RestoreProcessFailpoint.values.length,
      );
      expect(
        restoreProcessCoreFailpoints.toSet().length,
        restoreProcessCoreFailpoints.length,
      );
      expect(
        restoreProcessCoreFailpoints,
        containsAll(<RestoreProcessFailpoint>{
          RestoreProcessFailpoint.cutoverClaimPublished,
          RestoreProcessFailpoint.liveDatabaseNormalized,
          RestoreProcessFailpoint.previousSettingsPublished,
          RestoreProcessFailpoint.previousManifestPublished,
          RestoreProcessFailpoint.previousUploadMoved,
          RestoreProcessFailpoint.previousDatabaseMoved,
          RestoreProcessFailpoint.previousPromoted,
          RestoreProcessFailpoint.oldRenamedReceiptTempDurable,
          RestoreProcessFailpoint.oldRenamedReceiptPublished,
          RestoreProcessFailpoint.settingsSecretRemoved,
          RestoreProcessFailpoint.settingsFirstSet,
          RestoreProcessFailpoint.candidateDatabaseMoved,
          RestoreProcessFailpoint.candidateUploadMoved,
          RestoreProcessFailpoint.candidateImagesMoved,
          RestoreProcessFailpoint.candidateAvatarsMoved,
          RestoreProcessFailpoint.candidateFontsMoved,
          RestoreProcessFailpoint.newInstalledReceiptPublished,
          RestoreProcessFailpoint.verifiedReceiptPublished,
          RestoreProcessFailpoint.committedReceiptPublished,
        }),
      );
    });

    test(
      'rejects mismatched phase, unknown fields, and unknown failpoints',
      () {
        final json = _validControlJson();
        json['generation'] = 2;
        expect(
          () => RestoreProcessHarnessControl.fromJson(json),
          throwsFormatException,
        );

        final withUnknown = _validControlJson()..['unknown'] = true;
        expect(
          () => RestoreProcessHarnessControl.fromJson(withUnknown),
          throwsFormatException,
        );

        final unknownFailpoint = _validControlJson()
          ..['failpoint'] = 'notARealFailpoint';
        expect(
          () => RestoreProcessHarnessControl.fromJson(unknownFailpoint),
          throwsFormatException,
        );
      },
    );

    test(
      'rejects invalid matrix, scenario, root, prefix, and JSON binding',
      () {
        expect(
          () => RestoreProcessHarnessControl(
            generation: 1,
            matrixRunId: 'invalid',
            scenarioId: _scenarioId,
            phase: RestoreProcessHarnessPhase.setup,
            failpoint: RestoreProcessFailpoint.candidateDatabaseMoved,
            scenarioRoot: _scenarioRoot(),
            preferencesPrefix: _preferencesPrefix(
              RestoreProcessFailpoint.candidateDatabaseMoved,
            ),
          ),
          throwsArgumentError,
        );
        expect(
          () => RestoreProcessHarnessControl(
            generation: 1,
            matrixRunId: _matrixRunId,
            scenarioId: _scenarioId,
            phase: RestoreProcessHarnessPhase.setup,
            failpoint: RestoreProcessFailpoint.candidateDatabaseMoved,
            scenarioRoot: 'relative/scenario',
            preferencesPrefix: _preferencesPrefix(
              RestoreProcessFailpoint.candidateDatabaseMoved,
            ),
          ),
          throwsArgumentError,
        );
        expect(
          () => RestoreProcessHarnessControl(
            generation: 1,
            matrixRunId: _matrixRunId,
            scenarioId: _scenarioId,
            phase: RestoreProcessHarnessPhase.setup,
            failpoint: RestoreProcessFailpoint.candidateDatabaseMoved,
            scenarioRoot: p.join(
              Directory.systemTemp.path,
              'kelivo_restore_process_wrong',
            ),
            preferencesPrefix: _preferencesPrefix(
              RestoreProcessFailpoint.candidateDatabaseMoved,
            ),
          ),
          throwsArgumentError,
        );

        final mismatchedPrefix = _validControlJson()
          ..['preferencesPrefix'] = _preferencesPrefix(
            RestoreProcessFailpoint.candidateUploadMoved,
          );
        expect(
          () => RestoreProcessHarnessControl.fromJson(mismatchedPrefix),
          throwsFormatException,
        );
        final mismatchedScenario = _validControlJson()
          ..['scenario'] = 'anotherScenario';
        expect(
          () => RestoreProcessHarnessControl.fromJson(mismatchedScenario),
          throwsFormatException,
        );
        final mismatchedMatrix = _validControlJson()
          ..['matrixRunId'] = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        expect(
          () => RestoreProcessHarnessControl.fromJson(mismatchedMatrix),
          throwsFormatException,
        );
      },
    );
  });

  group('one-shot restore durability hooks', () {
    late Directory temporary;
    late _RecordingDurability delegate;

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp(
        'kelivo_restore_harness_hooks_',
      );
      delegate = _RecordingDurability();
    });

    tearDown(() async {
      if (await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    });

    test('exact rename matcher ignores wrong direction and path', () async {
      final source = File(p.join(temporary.path, 'source'));
      final target = p.join(temporary.path, 'target');
      final wrong = p.join(temporary.path, 'wrong');
      final hook = OneShotBlockingRestoreDurability(
        delegate: delegate,
        matcher: RestoreExactRenameMatcher(
          sourcePath: source.path,
          targetPath: target,
          sourceKind: RestoreProcessEntityKind.file,
        ),
        onMatched: (_) async => fail('wrong rename matched'),
      );

      await hook.renameAndSync(source: source, targetPath: wrong);
      await hook.renameAndSync(source: File(target), targetPath: source.path);
      await hook.renameAndSync(
        source: Directory(source.path),
        targetPath: target,
      );

      expect(hook.didMatch, isFalse);
      expect(delegate.renames, hasLength(3));
    });

    test(
      'exact rename matcher reports only after the delegate returns',
      () async {
        final source = File(p.join(temporary.path, 'source'));
        final target = p.join(temporary.path, 'target');
        final matched = Completer<RestoreDurabilityObservation>();
        final hook = OneShotBlockingRestoreDurability(
          delegate: delegate,
          matcher: RestoreExactRenameMatcher(
            sourcePath: source.path,
            targetPath: target,
            sourceKind: RestoreProcessEntityKind.file,
          ),
          onMatched: (observation) async {
            expect(delegate.renames, hasLength(1));
            matched.complete(observation);
          },
        );

        final blocked = hook.renameAndSync(source: source, targetPath: target);
        final observation = await matched.future;

        expect(observation, isA<RestoreRenameObservation>());
        expect(
          (observation as RestoreRenameObservation).sourcePath,
          source.path,
        );
        expect(observation.targetPath, target);
        expect(observation.sourceKind, RestoreProcessEntityKind.file);
        expect(hook.didMatch, isTrue);
        expect(blocked, doesNotComplete);
      },
    );

    test('exact file and directory sync match path and barrier', () async {
      final file = File(p.join(temporary.path, 'file'));
      final directory = Directory(p.join(temporary.path, 'directory'));
      final fileMatched = Completer<RestoreDurabilityObservation>();
      final fileHook = OneShotBlockingRestoreDurability(
        delegate: delegate,
        matcher: RestoreExactFileSyncMatcher(
          path: file.path,
          fullBarrier: true,
        ),
        onMatched: (observation) async => fileMatched.complete(observation),
      );

      await fileHook.syncFile(file);
      await fileHook.syncFile(File('${file.path}.other'), fullBarrier: true);
      expect(fileHook.didMatch, isFalse);
      final blockedFile = fileHook.syncFile(file, fullBarrier: true);
      final fileObservation = await fileMatched.future;
      expect(fileObservation, isA<RestoreFileSyncObservation>());
      expect(blockedFile, doesNotComplete);

      final directoryMatched = Completer<RestoreDurabilityObservation>();
      final directoryHook = OneShotBlockingRestoreDurability(
        delegate: delegate,
        matcher: RestoreExactDirectorySyncMatcher(
          path: directory.path,
          fullBarrier: true,
        ),
        onMatched: (observation) async =>
            directoryMatched.complete(observation),
      );
      await directoryHook.syncDirectory(directory);
      expect(directoryHook.didMatch, isFalse);
      final blockedDirectory = directoryHook.syncDirectory(
        directory,
        fullBarrier: true,
      );
      final directoryObservation = await directoryMatched.future;
      expect(directoryObservation, isA<RestoreDirectorySyncObservation>());
      expect(blockedDirectory, doesNotComplete);
    });

    test('receipt temp matcher parses and binds sequence and state', () async {
      final receiptDirectory = Directory(
        p.join(temporary.path, 'run_$_scenarioId', 'receipts'),
      );
      await receiptDirectory.create(recursive: true);
      final prepared = RestoreReceipt.prepared(
        runId: _scenarioId,
        createdAtUtc: DateTime.utc(2026, 7, 10),
        restoreChats: true,
        restoreFiles: true,
        candidateManifestSha256: _checksumA,
      );
      final oldRenamed = prepared.advance(
        RestoreReceiptState.oldRenamed,
        previousManifestSha256: _checksumB,
      );
      final temporaryReceipt = File(
        p.join(
          receiptDirectory.path,
          'receipt_0000000000000002.json.123_456.tmp',
        ),
      );
      await temporaryReceipt.writeAsString(jsonEncode(oldRenamed.toJson()));

      final wrongStateHook = OneShotBlockingRestoreDurability(
        delegate: delegate,
        matcher: RestoreReceiptTempDurableMatcher(
          receiptDirectoryPath: receiptDirectory.path,
          sequence: 3,
          state: RestoreReceiptState.newInstalled,
        ),
        onMatched: (_) async => fail('wrong receipt state matched'),
      );
      await wrongStateHook.syncFile(temporaryReceipt, fullBarrier: true);
      expect(wrongStateHook.didMatch, isFalse);

      final tempMatched = Completer<RestoreDurabilityObservation>();
      final tempHook = OneShotBlockingRestoreDurability(
        delegate: delegate,
        matcher: RestoreReceiptTempDurableMatcher(
          receiptDirectoryPath: receiptDirectory.path,
          sequence: 2,
          state: RestoreReceiptState.oldRenamed,
        ),
        onMatched: (observation) async => tempMatched.complete(observation),
      );
      final blockedTemp = tempHook.syncFile(
        temporaryReceipt,
        fullBarrier: true,
      );
      final tempObservation =
          await tempMatched.future as RestoreReceiptDurabilityObservation;
      expect(
        tempObservation.boundary,
        RestoreReceiptDurabilityBoundary.tempDurable,
      );
      expect(tempObservation.sequence, 2);
      expect(tempObservation.state, RestoreReceiptState.oldRenamed);
      expect(blockedTemp, doesNotComplete);

      final publishMatched = Completer<RestoreDurabilityObservation>();
      final publishHook = OneShotBlockingRestoreDurability(
        delegate: delegate,
        matcher: RestoreReceiptPublishedMatcher(
          receiptDirectoryPath: receiptDirectory.path,
          sequence: 2,
          state: RestoreReceiptState.oldRenamed,
        ),
        onMatched: (observation) async => publishMatched.complete(observation),
      );
      final target = p.join(
        receiptDirectory.path,
        'receipt_0000000000000002.json',
      );
      final blockedPublish = publishHook.renameAndSync(
        source: temporaryReceipt,
        targetPath: target,
      );
      final publishObservation =
          await publishMatched.future as RestoreReceiptDurabilityObservation;
      expect(
        publishObservation.boundary,
        RestoreReceiptDurabilityBoundary.published,
      );
      expect(publishObservation.targetPath, target);
      expect(blockedPublish, doesNotComplete);
    });
  });

  group('one-shot SharedPreferences hooks', () {
    test('remove matches only the exact successful prefixed key', () async {
      const key = 'kelivo.restore.harness.matrix.scenario.failpoint.secret';
      final delegate = _ControllablePreferencesStore(removeResult: false);
      final matched = Completer<RestorePreferenceMutationObservation>();
      final hook = OneShotBlockingPreferencesStore(
        delegate: delegate,
        prefixedKey: key,
        mutationKind: RestorePreferenceMutationKind.remove,
        onMatched: (observation) async => matched.complete(observation),
      );

      expect(await hook.remove(key), isFalse);
      delegate.removeResult = true;
      expect(await hook.remove('$key.other'), isTrue);
      expect(hook.didMatch, isFalse);

      final blocked = hook.remove(key);
      final observation = await matched.future;
      expect(observation.kind, RestorePreferenceMutationKind.remove);
      expect(observation.prefixedKey, key);
      expect(observation.valueType, isNull);
      expect(blocked, doesNotComplete);
    });

    test(
      'set matches only after success and never retains the value',
      () async {
        const key =
            'kelivo.restore.harness.matrix.scenario.failpoint.first_set';
        const secretValue = 'must-not-appear-in-observation';
        final delegate = _ControllablePreferencesStore(setResult: false);
        final matched = Completer<RestorePreferenceMutationObservation>();
        final hook = OneShotBlockingPreferencesStore(
          delegate: delegate,
          prefixedKey: key,
          mutationKind: RestorePreferenceMutationKind.set,
          onMatched: (observation) async => matched.complete(observation),
        );

        expect(await hook.setValue('String', key, secretValue), isFalse);
        delegate.setResult = true;
        expect(
          await hook.setValue('String', '$key.other', secretValue),
          isTrue,
        );
        expect(hook.didMatch, isFalse);

        final blocked = hook.setValue('String', key, secretValue);
        final observation = await matched.future;
        expect(observation.kind, RestorePreferenceMutationKind.set);
        expect(observation.prefixedKey, key);
        expect(observation.valueType, 'String');
        expect(observation.toString(), isNot(contains(secretValue)));
        expect(blocked, doesNotComplete);
      },
    );
  });

  group('restore harness durable JSON', () {
    late Directory temporary;

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp(
        'kelivo_restore_harness_protocol_',
      );
    });

    tearDown(() async {
      if (await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    });

    test('publishes, reads back, and refuses an existing event', () async {
      final target = File(p.join(temporary.path, 'event.json'));
      const value = <String, dynamic>{'phase': 'setup', 'generation': 1};

      await writeDurableHarnessJson(target, value);
      expect(await readHarnessJson(target), value);
      await expectLater(
        writeDurableHarnessJson(target, value),
        throwsStateError,
      );
    });

    test('rejects a missing, empty, or non-object JSON file', () async {
      await expectLater(
        readHarnessJson(File(p.join(temporary.path, 'missing.json'))),
        throwsStateError,
      );

      final empty = File(p.join(temporary.path, 'empty.json'));
      await empty.create();
      await expectLater(readHarnessJson(empty), throwsFormatException);

      final list = File(p.join(temporary.path, 'list.json'));
      await list.writeAsString('[]');
      await expectLater(readHarnessJson(list), throwsFormatException);
    });
  });

  test('fixture state rejects an unknown or mistyped field', () {
    final state = RestoreCompleteBundleFixtureState(
      matrixRunId: _matrixRunId,
      failpoint: RestoreProcessFailpoint.candidateDatabaseMoved.name,
      runId: 'cccccccccccccccccccccccccccccccc',
      preparedReceiptChecksum: _checksumA,
      candidateManifestSha256: _checksumB,
      primaryPreferenceKey: 'restore_harness_primary_$_scenarioId',
      primaryOldPreferenceValue: 'primary-old',
      primaryNewPreferenceValue: 'primary-new',
      secondaryPreferenceKey: 'restore_harness_secondary_$_scenarioId',
      secondaryOldPreferenceValue: 'secondary-old',
      secondaryNewPreferenceValue: 'secondary-new',
      secretPreferenceKey: 'restore_harness_secret_$_scenarioId',
      secretOldPreferenceValue: 'secret-old',
      oldConversationId: 'old-$_scenarioId',
      newConversationId: 'new-$_scenarioId',
    );
    expect(
      RestoreCompleteBundleFixtureState.fromJson(state.toJson()).runId,
      state.runId,
    );

    final unknown = state.toJson()..['unknown'] = true;
    expect(
      () => RestoreCompleteBundleFixtureState.fromJson(unknown),
      throwsFormatException,
    );
    final mistyped = state.toJson()..['runId'] = 1;
    expect(
      () => RestoreCompleteBundleFixtureState.fromJson(mistyped),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _validControlJson() {
  return _control(
    phase: RestoreProcessHarnessPhase.setup,
    failpoint: RestoreProcessFailpoint.candidateDatabaseMoved,
  ).toJson();
}

RestoreProcessHarnessControl _control({
  required RestoreProcessHarnessPhase phase,
  required RestoreProcessFailpoint failpoint,
}) {
  return RestoreProcessHarnessControl(
    generation: phase.index + 1,
    matrixRunId: _matrixRunId,
    scenarioId: _scenarioId,
    phase: phase,
    failpoint: failpoint,
    scenarioRoot: _scenarioRoot(),
    preferencesPrefix: _preferencesPrefix(failpoint),
  );
}

String _preferencesPrefix(RestoreProcessFailpoint failpoint) =>
    restoreProcessPreferencesPrefix(
      matrixRunId: _matrixRunId,
      scenarioId: _scenarioId,
      failpoint: failpoint,
    );

String _scenarioRoot() => p.normalize(
  p.absolute(
    p.join(Directory.systemTemp.path, 'kelivo_restore_process_$_scenarioId'),
  ),
);

final class _RecordingDurability implements RestoreDurability {
  final List<({String source, String target})> renames = [];
  final List<({String path, bool fullBarrier})> fileSyncs = [];
  final List<({String path, bool fullBarrier})> directorySyncs = [];

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    renames.add((source: source.path, target: targetPath));
  }

  @override
  Future<void> restrictDirectory(Directory directory) async {}

  @override
  Future<void> restrictFile(File file) async {}

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {
    directorySyncs.add((path: directory.path, fullBarrier: fullBarrier));
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {
    fileSyncs.add((path: file.path, fullBarrier: fullBarrier));
  }
}

final class _ControllablePreferencesStore
    extends SharedPreferencesStorePlatform {
  _ControllablePreferencesStore({
    this.removeResult = true,
    this.setResult = true,
  });

  bool removeResult;
  bool setResult;

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
  Future<bool> remove(String key) async => removeResult;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      setResult;
}
