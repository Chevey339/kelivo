import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../../integration_test/support/restore_complete_bundle_fixture.dart';
import '../../../../integration_test/support/restore_process_control.dart';

const _scenarioId = '0123456789abcdef0123456789abcdef';
const _preferencesPrefix = 'kelivo.restore.harness.$_scenarioId.';
const _checksumA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _checksumB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  group('RestoreProcessHarnessControl', () {
    test('round-trips every ordered phase', () {
      final root = p.normalize(
        p.absolute(
          p.join(
            Directory.systemTemp.path,
            'kelivo_restore_process_$_scenarioId',
          ),
        ),
      );

      for (final phase in RestoreProcessHarnessPhase.values) {
        final control = RestoreProcessHarnessControl(
          generation: phase.index + 1,
          scenarioId: _scenarioId,
          phase: phase,
          scenarioRoot: root,
          preferencesPrefix: _preferencesPrefix,
        );

        final decoded = RestoreProcessHarnessControl.fromJson(control.toJson());
        expect(decoded.generation, phase.index + 1);
        expect(decoded.phase, phase);
        expect(decoded.scenarioId, _scenarioId);
        expect(decoded.scenarioRoot, root);
        expect(decoded.preferencesPrefix, _preferencesPrefix);
      }
    });

    test('rejects a phase/generation mismatch and unknown fields', () {
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
    });

    test('rejects relative roots and a prefix bound to another scenario', () {
      expect(
        () => RestoreProcessHarnessControl(
          generation: 1,
          scenarioId: _scenarioId,
          phase: RestoreProcessHarnessPhase.setup,
          scenarioRoot: 'relative/scenario',
          preferencesPrefix: _preferencesPrefix,
        ),
        throwsArgumentError,
      );
      expect(
        () => RestoreProcessHarnessControl(
          generation: 1,
          scenarioId: _scenarioId,
          phase: RestoreProcessHarnessPhase.setup,
          scenarioRoot: _scenarioRoot(),
          preferencesPrefix:
              'kelivo.restore.harness.ffffffffffffffffffffffffffffffff.',
        ),
        throwsArgumentError,
      );
    });
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
      runId: 'cccccccccccccccccccccccccccccccc',
      preparedReceiptChecksum: _checksumA,
      candidateManifestSha256: _checksumB,
      preferenceKey: 'restore_harness_$_scenarioId',
      oldPreferenceValue: 'old',
      newPreferenceValue: 'new',
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
  return RestoreProcessHarnessControl(
    generation: 1,
    scenarioId: _scenarioId,
    phase: RestoreProcessHarnessPhase.setup,
    scenarioRoot: _scenarioRoot(),
    preferencesPrefix: _preferencesPrefix,
  ).toJson();
}

String _scenarioRoot() => p.normalize(
  p.absolute(
    p.join(Directory.systemTemp.path, 'kelivo_restore_process_$_scenarioId'),
  ),
);
