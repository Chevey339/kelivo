import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../../integration_test/support/restore_process_control.dart';

const _matrixRunId = 'fedcba9876543210fedcba9876543210';
const _scenarioId = '0123456789abcdef0123456789abcdef';

void main() {
  group('RestoreRollbackProcessHarnessControl', () {
    test('publishes the ordered rollback phases and failpoints', () {
      expect(RestoreRollbackProcessHarnessControl.version, 1);
      expect(RestoreRollbackProcessHarnessPhase.values, [
        RestoreRollbackProcessHarnessPhase.setup,
        RestoreRollbackProcessHarnessPhase.triggerRollbackKill,
        RestoreRollbackProcessHarnessPhase.recoverToColdAck,
        RestoreRollbackProcessHarnessPhase.verifyBusinessReady,
      ]);
      expect(RestoreRollbackProcessFailpoint.values, [
        RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable,
        RestoreRollbackProcessFailpoint.rollingBackReceiptPublished,
        RestoreRollbackProcessFailpoint.newDatabaseReturnedToCandidate,
        RestoreRollbackProcessFailpoint.previousDatabaseRestoredToLive,
        RestoreRollbackProcessFailpoint.previousDatabaseParentRemovedDurable,
        RestoreRollbackProcessFailpoint.newUploadReturnedToCandidate,
        RestoreRollbackProcessFailpoint.previousUploadRestoredToLive,
        RestoreRollbackProcessFailpoint.newImagesReturnedToCandidate,
        RestoreRollbackProcessFailpoint.previousImagesRestoredToLive,
        RestoreRollbackProcessFailpoint.newAvatarsReturnedToCandidate,
        RestoreRollbackProcessFailpoint.previousAvatarsRestoredToLive,
        RestoreRollbackProcessFailpoint.newFontsReturnedToCandidate,
        RestoreRollbackProcessFailpoint.previousFontsRestoredToLive,
        RestoreRollbackProcessFailpoint.settingsFirstRestored,
        RestoreRollbackProcessFailpoint.settingsSecretRestored,
        RestoreRollbackProcessFailpoint.settingsTargetOnlyRemoved,
        RestoreRollbackProcessFailpoint.rolledBackReceiptTempDurable,
        RestoreRollbackProcessFailpoint.rolledBackReceiptPublished,
      ]);
      expect(
        _rollbackPrefix(
          RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable,
        ),
        'kelivo.restore.rollback.harness.$_matrixRunId.$_scenarioId.'
        'rollingBackReceiptTempDurable.',
      );
    });

    test('round-trips all 18 failpoints through all four phases', () {
      for (final failpoint in RestoreRollbackProcessFailpoint.values) {
        for (final phase in RestoreRollbackProcessHarnessPhase.values) {
          final control = _rollbackControl(phase: phase, failpoint: failpoint);

          final decoded = RestoreRollbackProcessHarnessControl.fromJson(
            control.toJson(),
          );
          final dispatched = RestoreHarnessControl.fromJson(control.toJson());

          expect(decoded.generation, phase.index + 1);
          expect(decoded.matrixRunId, _matrixRunId);
          expect(decoded.scenario, restoreRollbackHarnessScenario);
          expect(decoded.scenarioId, _scenarioId);
          expect(decoded.phase, phase);
          expect(decoded.phaseName, phase.name);
          expect(decoded.failpoint, failpoint);
          expect(decoded.failpointName, failpoint.name);
          expect(decoded.scenarioRoot, _scenarioRoot());
          expect(decoded.rootDirectory.path, _scenarioRoot());
          expect(
            decoded.appDataDirectory.path,
            p.join(_scenarioRoot(), 'app_data'),
          );
          expect(
            decoded.sourceDirectory.path,
            p.join(_scenarioRoot(), 'source'),
          );
          expect(
            decoded.eventsDirectory.path,
            p.join(_scenarioRoot(), 'events'),
          );
          expect(decoded.stateFile.path, p.join(_scenarioRoot(), 'state.json'));
          expect(
            decoded.eventFile.path,
            p.join(
              _scenarioRoot(),
              'events',
              '${(phase.index + 1).toString().padLeft(2, '0')}_'
                  '${phase.name}.json',
            ),
          );
          expect(
            decoded.preferencesPrefix,
            restoreRollbackProcessPreferencesPrefix(
              matrixRunId: _matrixRunId,
              scenarioId: _scenarioId,
              failpoint: failpoint,
            ),
          );
          expect(dispatched, isA<RestoreRollbackProcessHarnessControl>());
          expect(dispatched.toJson(), control.toJson());
        }
      }
    });

    test('strict dispatcher preserves forward v2 and terminal v1', () {
      final forwardFailpoint = RestoreProcessFailpoint.candidateDatabaseMoved;
      final forward = RestoreProcessHarnessControl(
        generation: 1,
        matrixRunId: _matrixRunId,
        scenarioId: _scenarioId,
        phase: RestoreProcessHarnessPhase.setup,
        failpoint: forwardFailpoint,
        scenarioRoot: _scenarioRoot(),
        preferencesPrefix: restoreProcessPreferencesPrefix(
          matrixRunId: _matrixRunId,
          scenarioId: _scenarioId,
          failpoint: forwardFailpoint,
        ),
      );
      final terminalFailpoint =
          RestoreTerminalProcessFailpoint.coldAckTempDurable;
      final terminal = RestoreTerminalProcessHarnessControl(
        generation: 1,
        matrixRunId: _matrixRunId,
        scenarioId: _scenarioId,
        phase: RestoreTerminalProcessHarnessPhase.setup,
        failpoint: terminalFailpoint,
        scenarioRoot: _scenarioRoot(),
        preferencesPrefix: restoreTerminalProcessPreferencesPrefix(
          matrixRunId: _matrixRunId,
          scenarioId: _scenarioId,
          failpoint: terminalFailpoint,
        ),
      );

      final decodedForward = RestoreHarnessControl.fromJson(forward.toJson());
      final decodedTerminal = RestoreHarnessControl.fromJson(terminal.toJson());

      expect(decodedForward, isA<RestoreProcessHarnessControl>());
      expect(decodedForward.toJson(), forward.toJson());
      expect(decodedTerminal, isA<RestoreTerminalProcessHarnessControl>());
      expect(decodedTerminal.toJson(), terminal.toJson());
    });

    test('rejects wrong protocol identity, schema, and enum values', () {
      final wrongScenario = _validRollbackJson()
        ..['scenario'] = restoreTerminalHarnessScenario;
      expect(
        () => RestoreRollbackProcessHarnessControl.fromJson(wrongScenario),
        throwsFormatException,
      );
      expect(
        () => RestoreHarnessControl.fromJson(wrongScenario),
        throwsFormatException,
      );

      final unknownScenario = _validRollbackJson()
        ..['scenario'] = 'unknownMatrix';
      expect(
        () => RestoreHarnessControl.fromJson(unknownScenario),
        throwsFormatException,
      );

      final wrongVersion = _validRollbackJson()..['version'] = 2;
      expect(
        () => RestoreRollbackProcessHarnessControl.fromJson(wrongVersion),
        throwsFormatException,
      );
      expect(
        () => RestoreHarnessControl.fromJson(wrongVersion),
        throwsFormatException,
      );

      final unknownField = _validRollbackJson()..['unknown'] = true;
      expect(
        () => RestoreRollbackProcessHarnessControl.fromJson(unknownField),
        throwsFormatException,
      );

      final missingField = _validRollbackJson()..remove('matrixRunId');
      expect(
        () => RestoreRollbackProcessHarnessControl.fromJson(missingField),
        throwsFormatException,
      );

      final nonStringField = Map<dynamic, dynamic>.from(_validRollbackJson())
        ..remove('matrixRunId')
        ..[1] = _matrixRunId;
      expect(
        () => RestoreRollbackProcessHarnessControl.fromJson(nonStringField),
        throwsFormatException,
      );

      final wrongType = _validRollbackJson()..['generation'] = 1.0;
      expect(
        () => RestoreRollbackProcessHarnessControl.fromJson(wrongType),
        throwsFormatException,
      );

      final unknownPhase = _validRollbackJson()..['phase'] = 'unknownPhase';
      expect(
        () => RestoreRollbackProcessHarnessControl.fromJson(unknownPhase),
        throwsFormatException,
      );

      final unknownFailpoint = _validRollbackJson()
        ..['failpoint'] = 'unknownFailpoint';
      expect(
        () => RestoreRollbackProcessHarnessControl.fromJson(unknownFailpoint),
        throwsFormatException,
      );
    });

    test('rejects generation, identity, root, and prefix binding changes', () {
      final wrongGeneration = _validRollbackJson()..['generation'] = 2;
      expect(
        () => RestoreRollbackProcessHarnessControl.fromJson(wrongGeneration),
        throwsFormatException,
      );

      final wrongMatrix = _validRollbackJson()
        ..['matrixRunId'] = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      expect(
        () => RestoreRollbackProcessHarnessControl.fromJson(wrongMatrix),
        throwsFormatException,
      );

      final wrongScenarioId = _validRollbackJson()
        ..['scenarioId'] = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      expect(
        () => RestoreRollbackProcessHarnessControl.fromJson(wrongScenarioId),
        throwsFormatException,
      );

      final wrongRoot = _validRollbackJson()
        ..['scenarioRoot'] = p.join(
          Directory.systemTemp.path,
          'kelivo_restore_process_wrong',
        );
      expect(
        () => RestoreRollbackProcessHarnessControl.fromJson(wrongRoot),
        throwsFormatException,
      );

      final wrongPrefix = _validRollbackJson()
        ..['preferencesPrefix'] = restoreRollbackProcessPreferencesPrefix(
          matrixRunId: _matrixRunId,
          scenarioId: _scenarioId,
          failpoint:
              RestoreRollbackProcessFailpoint.rollingBackReceiptPublished,
        );
      expect(
        () => RestoreRollbackProcessHarnessControl.fromJson(wrongPrefix),
        throwsFormatException,
      );

      expect(
        () => RestoreRollbackProcessHarnessControl(
          generation: 1,
          matrixRunId: 'invalid',
          scenarioId: _scenarioId,
          phase: RestoreRollbackProcessHarnessPhase.setup,
          failpoint:
              RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable,
          scenarioRoot: _scenarioRoot(),
          preferencesPrefix: _rollbackPrefix(
            RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => RestoreRollbackProcessHarnessControl(
          generation: 1,
          matrixRunId: _matrixRunId,
          scenarioId: _scenarioId,
          phase: RestoreRollbackProcessHarnessPhase.setup,
          failpoint:
              RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable,
          scenarioRoot: 'relative/scenario',
          preferencesPrefix: _rollbackPrefix(
            RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => restoreRollbackProcessPreferencesPrefix(
          matrixRunId: _matrixRunId,
          scenarioId: 'invalid',
          failpoint:
              RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable,
        ),
        throwsArgumentError,
      );
    });
  });
}

RestoreRollbackProcessHarnessControl _rollbackControl({
  required RestoreRollbackProcessHarnessPhase phase,
  required RestoreRollbackProcessFailpoint failpoint,
}) {
  return RestoreRollbackProcessHarnessControl(
    generation: phase.index + 1,
    matrixRunId: _matrixRunId,
    scenarioId: _scenarioId,
    phase: phase,
    failpoint: failpoint,
    scenarioRoot: _scenarioRoot(),
    preferencesPrefix: _rollbackPrefix(failpoint),
  );
}

Map<String, dynamic> _validRollbackJson() => _rollbackControl(
  phase: RestoreRollbackProcessHarnessPhase.setup,
  failpoint: RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable,
).toJson();

String _scenarioRoot() => p.normalize(
  p.absolute(
    p.join(Directory.systemTemp.path, 'kelivo_restore_process_$_scenarioId'),
  ),
);

String _rollbackPrefix(RestoreRollbackProcessFailpoint failpoint) =>
    restoreRollbackProcessPreferencesPrefix(
      matrixRunId: _matrixRunId,
      scenarioId: _scenarioId,
      failpoint: failpoint,
    );
