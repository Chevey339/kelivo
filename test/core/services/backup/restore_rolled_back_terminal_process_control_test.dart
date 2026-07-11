import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../../integration_test/support/restore_process_control.dart';

const _matrixRunId = 'abcdef0123456789abcdef0123456789';
const _scenarioId = '9876543210abcdef9876543210abcdef';

void main() {
  group('RestoreRolledBackTerminalProcessHarnessControl', () {
    test('publishes the ordered v1 phases and six unique failpoints', () {
      expect(RestoreRolledBackTerminalProcessHarnessControl.version, 1);
      expect(RestoreRolledBackTerminalProcessHarnessPhase.values, [
        RestoreRolledBackTerminalProcessHarnessPhase.setup,
        RestoreRolledBackTerminalProcessHarnessPhase.rollbackToColdAck,
        RestoreRolledBackTerminalProcessHarnessPhase.recoverTerminal,
        RestoreRolledBackTerminalProcessHarnessPhase.verifyBusinessReady,
      ]);
      expect(RestoreTerminalProcessFailpoint.values, [
        RestoreTerminalProcessFailpoint.coldAckTempDurable,
        RestoreTerminalProcessFailpoint.coldAckPublished,
        RestoreTerminalProcessFailpoint.completedRunsRootDurable,
        RestoreTerminalProcessFailpoint.archivingMarkerPublished,
        RestoreTerminalProcessFailpoint.terminalRunArchived,
        RestoreTerminalProcessFailpoint.archivingMarkerRemovedDurable,
      ]);
      expect(
        _prefix(RestoreTerminalProcessFailpoint.coldAckTempDurable),
        'kelivo.restore.rolledback.terminal.harness.$_matrixRunId.'
        '$_scenarioId.coldAckTempDurable.',
      );
    });

    test('round-trips all failpoints and phases through strict dispatch', () {
      for (final failpoint in RestoreTerminalProcessFailpoint.values) {
        for (final phase
            in RestoreRolledBackTerminalProcessHarnessPhase.values) {
          final control = _control(phase: phase, failpoint: failpoint);

          final decoded =
              RestoreRolledBackTerminalProcessHarnessControl.fromJson(
                control.toJson(),
              );
          final dispatched = RestoreHarnessControl.fromJson(control.toJson());

          expect(decoded.generation, phase.index + 1);
          expect(decoded.matrixRunId, _matrixRunId);
          expect(decoded.scenario, restoreRolledBackTerminalHarnessScenario);
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
          expect(decoded.preferencesPrefix, _prefix(failpoint));
          expect(
            dispatched,
            isA<RestoreRolledBackTerminalProcessHarnessControl>(),
          );
          expect(dispatched.toJson(), control.toJson());
        }
      }
    });

    test('rejects schema, enum, identity, root, and prefix changes', () {
      final wrongScenario = _validJson()
        ..['scenario'] = restoreRollbackHarnessScenario;
      final unknownScenario = _validJson()..['scenario'] = 'unknownMatrix';
      final wrongVersion = _validJson()..['version'] = 2;
      final unknownField = _validJson()..['unknown'] = true;
      final missingField = _validJson()..remove('matrixRunId');
      final nonStringField = Map<dynamic, dynamic>.from(_validJson())
        ..remove('matrixRunId')
        ..[1] = _matrixRunId;
      final wrongType = _validJson()..['generation'] = 1.0;
      final unknownPhase = _validJson()..['phase'] = 'unknownPhase';
      final unknownFailpoint = _validJson()..['failpoint'] = 'unknownFailpoint';
      final wrongGeneration = _validJson()..['generation'] = 2;
      final wrongMatrix = _validJson()
        ..['matrixRunId'] = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final wrongScenarioId = _validJson()
        ..['scenarioId'] = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final wrongRoot = _validJson()
        ..['scenarioRoot'] = p.join(
          Directory.systemTemp.path,
          'kelivo_restore_process_wrong',
        );
      final wrongPrefix = _validJson()
        ..['preferencesPrefix'] = _prefix(
          RestoreTerminalProcessFailpoint.coldAckPublished,
        );

      for (final json in [
        wrongScenario,
        wrongVersion,
        unknownField,
        missingField,
        nonStringField,
        wrongType,
        unknownPhase,
        unknownFailpoint,
        wrongGeneration,
        wrongMatrix,
        wrongScenarioId,
        wrongRoot,
        wrongPrefix,
      ]) {
        expect(
          () => RestoreRolledBackTerminalProcessHarnessControl.fromJson(json),
          throwsFormatException,
        );
      }
      expect(
        () => RestoreHarnessControl.fromJson(wrongScenario),
        throwsFormatException,
      );
      expect(
        () => RestoreHarnessControl.fromJson(unknownScenario),
        throwsFormatException,
      );
      expect(
        () => RestoreRolledBackTerminalProcessHarnessControl(
          generation: 1,
          matrixRunId: 'invalid',
          scenarioId: _scenarioId,
          phase: RestoreRolledBackTerminalProcessHarnessPhase.setup,
          failpoint: RestoreTerminalProcessFailpoint.coldAckTempDurable,
          scenarioRoot: _scenarioRoot(),
          preferencesPrefix: _prefix(
            RestoreTerminalProcessFailpoint.coldAckTempDurable,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => RestoreRolledBackTerminalProcessHarnessControl(
          generation: 1,
          matrixRunId: _matrixRunId,
          scenarioId: _scenarioId,
          phase: RestoreRolledBackTerminalProcessHarnessPhase.setup,
          failpoint: RestoreTerminalProcessFailpoint.coldAckTempDurable,
          scenarioRoot: 'relative/scenario',
          preferencesPrefix: _prefix(
            RestoreTerminalProcessFailpoint.coldAckTempDurable,
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}

RestoreRolledBackTerminalProcessHarnessControl _control({
  required RestoreRolledBackTerminalProcessHarnessPhase phase,
  required RestoreTerminalProcessFailpoint failpoint,
}) => RestoreRolledBackTerminalProcessHarnessControl(
  generation: phase.index + 1,
  matrixRunId: _matrixRunId,
  scenarioId: _scenarioId,
  phase: phase,
  failpoint: failpoint,
  scenarioRoot: _scenarioRoot(),
  preferencesPrefix: _prefix(failpoint),
);

Map<String, dynamic> _validJson() => _control(
  phase: RestoreRolledBackTerminalProcessHarnessPhase.setup,
  failpoint: RestoreTerminalProcessFailpoint.coldAckTempDurable,
).toJson();

String _scenarioRoot() => p.normalize(
  p.absolute(
    p.join(Directory.systemTemp.path, 'kelivo_restore_process_$_scenarioId'),
  ),
);

String _prefix(RestoreTerminalProcessFailpoint failpoint) =>
    restoreRolledBackTerminalProcessPreferencesPrefix(
      matrixRunId: _matrixRunId,
      scenarioId: _scenarioId,
      failpoint: failpoint,
    );
