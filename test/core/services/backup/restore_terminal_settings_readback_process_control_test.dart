import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../../integration_test/support/restore_process_control.dart';

const _matrixRunId = '1234567890abcdef1234567890abcdef';
const _scenarioId = 'abcdef1234567890abcdef1234567890';

void main() {
  group('RestoreTerminalSettingsReadbackProcessHarnessControl', () {
    test('publishes the ordered v1 contract and isolated prefix', () {
      expect(RestoreTerminalSettingsReadbackProcessHarnessControl.version, 1);
      expect(RestoreTerminalSettingsReadbackProcessHarnessPhase.values, [
        RestoreTerminalSettingsReadbackProcessHarnessPhase.setup,
        RestoreTerminalSettingsReadbackProcessHarnessPhase
            .createTerminalPartial,
        RestoreTerminalSettingsReadbackProcessHarnessPhase.repairToColdAck,
        RestoreTerminalSettingsReadbackProcessHarnessPhase.verifyBusinessReady,
      ]);
      expect(RestoreTerminalSettingsReadbackProcessCase.values, [
        RestoreTerminalSettingsReadbackProcessCase.committedTarget,
        RestoreTerminalSettingsReadbackProcessCase.rolledBackBefore,
      ]);
      expect(
        _prefix(RestoreTerminalSettingsReadbackProcessCase.committedTarget),
        'kelivo.restore.terminal.settings.readback.harness.$_matrixRunId.'
        '$_scenarioId.committedTarget.',
      );
    });

    test('round-trips every phase and case through strict dispatch', () {
      for (final readbackCase
          in RestoreTerminalSettingsReadbackProcessCase.values) {
        for (final phase
            in RestoreTerminalSettingsReadbackProcessHarnessPhase.values) {
          final control = _control(phase: phase, readbackCase: readbackCase);
          final decoded =
              RestoreTerminalSettingsReadbackProcessHarnessControl.fromJson(
                control.toJson(),
              );
          final dispatched = RestoreHarnessControl.fromJson(control.toJson());

          expect(decoded.generation, phase.index + 1);
          expect(decoded.matrixRunId, _matrixRunId);
          expect(
            decoded.scenario,
            restoreTerminalSettingsReadbackHarnessScenario,
          );
          expect(decoded.scenarioId, _scenarioId);
          expect(decoded.phase, phase);
          expect(decoded.phaseName, phase.name);
          expect(decoded.readbackCase, readbackCase);
          expect(decoded.failpointName, readbackCase.name);
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
          expect(decoded.preferencesPrefix, _prefix(readbackCase));
          expect(
            dispatched,
            isA<RestoreTerminalSettingsReadbackProcessHarnessControl>(),
          );
          expect(dispatched.toJson(), control.toJson());
        }
      }
    });

    test('keeps existing control dispatch compatible', () {
      final existing = RestoreTerminalProcessHarnessControl(
        generation: 1,
        matrixRunId: _matrixRunId,
        scenarioId: _scenarioId,
        phase: RestoreTerminalProcessHarnessPhase.setup,
        failpoint: RestoreTerminalProcessFailpoint.coldAckPublished,
        scenarioRoot: _scenarioRoot(),
        preferencesPrefix: restoreTerminalProcessPreferencesPrefix(
          matrixRunId: _matrixRunId,
          scenarioId: _scenarioId,
          failpoint: RestoreTerminalProcessFailpoint.coldAckPublished,
        ),
      );

      expect(
        RestoreHarnessControl.fromJson(existing.toJson()),
        isA<RestoreTerminalProcessHarnessControl>(),
      );
    });

    test('rejects unknown fields and mismatched identity bindings', () {
      final unknownField = _validJson()..['unknown'] = true;
      final missingField = _validJson()..remove('readbackCase');
      final wrongScenario = _validJson()
        ..['scenario'] = restoreTerminalHarnessScenario;
      final wrongVersion = _validJson()..['version'] = 2;
      final wrongGeneration = _validJson()..['generation'] = 2;
      final unknownPhase = _validJson()..['phase'] = 'unknownPhase';
      final unknownCase = _validJson()..['readbackCase'] = 'unknownCase';
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
          RestoreTerminalSettingsReadbackProcessCase.rolledBackBefore,
        );

      for (final json in [
        unknownField,
        missingField,
        wrongScenario,
        wrongVersion,
        wrongGeneration,
        unknownPhase,
        unknownCase,
        wrongMatrix,
        wrongScenarioId,
        wrongRoot,
        wrongPrefix,
      ]) {
        expect(
          () => RestoreTerminalSettingsReadbackProcessHarnessControl.fromJson(
            json,
          ),
          throwsFormatException,
        );
      }
      expect(
        () => RestoreHarnessControl.fromJson(wrongScenario),
        throwsFormatException,
      );
    });
  });
}

RestoreTerminalSettingsReadbackProcessHarnessControl _control({
  required RestoreTerminalSettingsReadbackProcessHarnessPhase phase,
  required RestoreTerminalSettingsReadbackProcessCase readbackCase,
}) => RestoreTerminalSettingsReadbackProcessHarnessControl(
  generation: phase.index + 1,
  matrixRunId: _matrixRunId,
  scenarioId: _scenarioId,
  phase: phase,
  readbackCase: readbackCase,
  scenarioRoot: _scenarioRoot(),
  preferencesPrefix: _prefix(readbackCase),
);

Map<String, dynamic> _validJson() => _control(
  phase: RestoreTerminalSettingsReadbackProcessHarnessPhase.setup,
  readbackCase: RestoreTerminalSettingsReadbackProcessCase.committedTarget,
).toJson();

String _scenarioRoot() => p.normalize(
  p.absolute(
    p.join(Directory.systemTemp.path, 'kelivo_restore_process_$_scenarioId'),
  ),
);

String _prefix(RestoreTerminalSettingsReadbackProcessCase readbackCase) =>
    restoreTerminalSettingsReadbackProcessPreferencesPrefix(
      matrixRunId: _matrixRunId,
      scenarioId: _scenarioId,
      readbackCase: readbackCase,
    );
