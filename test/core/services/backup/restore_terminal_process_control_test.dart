import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../../integration_test/support/restore_process_control.dart';

const _matrixRunId = 'fedcba9876543210fedcba9876543210';
const _scenarioId = '0123456789abcdef0123456789abcdef';

void main() {
  group('RestoreTerminalProcessHarnessControl', () {
    test('publishes the ordered terminal phases and failpoints', () {
      expect(RestoreTerminalProcessHarnessPhase.values, [
        RestoreTerminalProcessHarnessPhase.setup,
        RestoreTerminalProcessHarnessPhase.commitToColdAck,
        RestoreTerminalProcessHarnessPhase.recoverTerminal,
        RestoreTerminalProcessHarnessPhase.verifyBusinessReady,
      ]);
      expect(RestoreTerminalProcessFailpoint.values, [
        RestoreTerminalProcessFailpoint.coldAckTempDurable,
        RestoreTerminalProcessFailpoint.coldAckPublished,
        RestoreTerminalProcessFailpoint.completedRunsRootDurable,
        RestoreTerminalProcessFailpoint.archivingMarkerPublished,
        RestoreTerminalProcessFailpoint.terminalRunArchived,
        RestoreTerminalProcessFailpoint.archivingMarkerRemovedDurable,
      ]);
    });

    test('round-trips all six failpoints through all four phases', () {
      for (final failpoint in RestoreTerminalProcessFailpoint.values) {
        for (final phase in RestoreTerminalProcessHarnessPhase.values) {
          final control = _terminalControl(phase: phase, failpoint: failpoint);

          final decoded = RestoreTerminalProcessHarnessControl.fromJson(
            control.toJson(),
          );
          final dispatched = RestoreHarnessControl.fromJson(control.toJson());

          expect(decoded.generation, phase.index + 1);
          expect(decoded.matrixRunId, _matrixRunId);
          expect(decoded.scenario, restoreTerminalHarnessScenario);
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
            restoreTerminalProcessPreferencesPrefix(
              matrixRunId: _matrixRunId,
              scenarioId: _scenarioId,
              failpoint: failpoint,
            ),
          );
          expect(dispatched, isA<RestoreTerminalProcessHarnessControl>());
          expect(dispatched.toJson(), control.toJson());
        }
      }
    });

    test('strict dispatcher preserves the forward v2 protocol', () {
      final failpoint = RestoreProcessFailpoint.candidateDatabaseMoved;
      final forward = RestoreProcessHarnessControl(
        generation: 1,
        matrixRunId: _matrixRunId,
        scenarioId: _scenarioId,
        phase: RestoreProcessHarnessPhase.setup,
        failpoint: failpoint,
        scenarioRoot: _scenarioRoot(),
        preferencesPrefix: restoreProcessPreferencesPrefix(
          matrixRunId: _matrixRunId,
          scenarioId: _scenarioId,
          failpoint: failpoint,
        ),
      );

      final decoded = RestoreHarnessControl.fromJson(forward.toJson());

      expect(decoded, isA<RestoreProcessHarnessControl>());
      expect(decoded.scenario, restoreHarnessScenario);
      expect(decoded.phaseName, RestoreProcessHarnessPhase.setup.name);
      expect(decoded.failpointName, failpoint.name);
      expect(decoded.toJson()['version'], RestoreProcessHarnessControl.version);
      expect(decoded.toJson(), forward.toJson());
    });

    test('rejects wrong scenario, version, and unknown fields', () {
      final wrongScenario = _validTerminalJson()
        ..['scenario'] = restoreHarnessScenario;
      expect(
        () => RestoreTerminalProcessHarnessControl.fromJson(wrongScenario),
        throwsFormatException,
      );
      expect(
        () => RestoreHarnessControl.fromJson(wrongScenario),
        throwsFormatException,
      );

      final unknownScenario = _validTerminalJson()
        ..['scenario'] = 'unknownMatrix';
      expect(
        () => RestoreHarnessControl.fromJson(unknownScenario),
        throwsFormatException,
      );

      final wrongVersion = _validTerminalJson()..['version'] = 2;
      expect(
        () => RestoreTerminalProcessHarnessControl.fromJson(wrongVersion),
        throwsFormatException,
      );
      expect(
        () => RestoreHarnessControl.fromJson(wrongVersion),
        throwsFormatException,
      );

      final unknownField = _validTerminalJson()..['unknown'] = true;
      expect(
        () => RestoreTerminalProcessHarnessControl.fromJson(unknownField),
        throwsFormatException,
      );
      expect(
        () => RestoreHarnessControl.fromJson(unknownField),
        throwsFormatException,
      );

      final unknownPhase = _validTerminalJson()..['phase'] = 'unknownPhase';
      expect(
        () => RestoreTerminalProcessHarnessControl.fromJson(unknownPhase),
        throwsFormatException,
      );
      final unknownFailpoint = _validTerminalJson()
        ..['failpoint'] = 'unknownFailpoint';
      expect(
        () => RestoreTerminalProcessHarnessControl.fromJson(unknownFailpoint),
        throwsFormatException,
      );
    });

    test('rejects generation, identity, root, and prefix binding changes', () {
      final wrongGeneration = _validTerminalJson()..['generation'] = 2;
      expect(
        () => RestoreTerminalProcessHarnessControl.fromJson(wrongGeneration),
        throwsFormatException,
      );

      final wrongMatrix = _validTerminalJson()
        ..['matrixRunId'] = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      expect(
        () => RestoreTerminalProcessHarnessControl.fromJson(wrongMatrix),
        throwsFormatException,
      );

      final wrongScenarioId = _validTerminalJson()
        ..['scenarioId'] = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      expect(
        () => RestoreTerminalProcessHarnessControl.fromJson(wrongScenarioId),
        throwsFormatException,
      );

      final wrongRoot = _validTerminalJson()
        ..['scenarioRoot'] = p.join(
          Directory.systemTemp.path,
          'kelivo_restore_process_wrong',
        );
      expect(
        () => RestoreTerminalProcessHarnessControl.fromJson(wrongRoot),
        throwsFormatException,
      );

      final wrongPrefix = _validTerminalJson()
        ..['preferencesPrefix'] = restoreTerminalProcessPreferencesPrefix(
          matrixRunId: _matrixRunId,
          scenarioId: _scenarioId,
          failpoint: RestoreTerminalProcessFailpoint.coldAckPublished,
        );
      expect(
        () => RestoreTerminalProcessHarnessControl.fromJson(wrongPrefix),
        throwsFormatException,
      );

      expect(
        () => RestoreTerminalProcessHarnessControl(
          generation: 1,
          matrixRunId: 'invalid',
          scenarioId: _scenarioId,
          phase: RestoreTerminalProcessHarnessPhase.setup,
          failpoint: RestoreTerminalProcessFailpoint.coldAckTempDurable,
          scenarioRoot: _scenarioRoot(),
          preferencesPrefix: _terminalPrefix(
            RestoreTerminalProcessFailpoint.coldAckTempDurable,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => RestoreTerminalProcessHarnessControl(
          generation: 1,
          matrixRunId: _matrixRunId,
          scenarioId: _scenarioId,
          phase: RestoreTerminalProcessHarnessPhase.setup,
          failpoint: RestoreTerminalProcessFailpoint.coldAckTempDurable,
          scenarioRoot: 'relative/scenario',
          preferencesPrefix: _terminalPrefix(
            RestoreTerminalProcessFailpoint.coldAckTempDurable,
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}

RestoreTerminalProcessHarnessControl _terminalControl({
  required RestoreTerminalProcessHarnessPhase phase,
  required RestoreTerminalProcessFailpoint failpoint,
}) {
  return RestoreTerminalProcessHarnessControl(
    generation: phase.index + 1,
    matrixRunId: _matrixRunId,
    scenarioId: _scenarioId,
    phase: phase,
    failpoint: failpoint,
    scenarioRoot: _scenarioRoot(),
    preferencesPrefix: _terminalPrefix(failpoint),
  );
}

Map<String, dynamic> _validTerminalJson() => _terminalControl(
  phase: RestoreTerminalProcessHarnessPhase.setup,
  failpoint: RestoreTerminalProcessFailpoint.coldAckTempDurable,
).toJson();

String _scenarioRoot() => p.normalize(
  p.absolute(
    p.join(Directory.systemTemp.path, 'kelivo_restore_process_$_scenarioId'),
  ),
);

String _terminalPrefix(RestoreTerminalProcessFailpoint failpoint) =>
    restoreTerminalProcessPreferencesPrefix(
      matrixRunId: _matrixRunId,
      scenarioId: _scenarioId,
      failpoint: failpoint,
    );
