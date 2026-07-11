import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../../integration_test/support/restore_process_control.dart';

const _matrixRunId = '1234567890abcdef1234567890abcdef';
const _scenarioId = 'abcdef1234567890abcdef1234567890';

void main() {
  group('RestoreLegacyArchivingMarkerProcessHarnessControl', () {
    test(
      'publishes the ordered v1 phases, failpoints, and isolated prefix',
      () {
        expect(RestoreLegacyArchivingMarkerProcessHarnessControl.version, 1);
        expect(RestoreLegacyArchivingMarkerProcessHarnessPhase.values, [
          RestoreLegacyArchivingMarkerProcessHarnessPhase.setup,
          RestoreLegacyArchivingMarkerProcessHarnessPhase.commitToColdAck,
          RestoreLegacyArchivingMarkerProcessHarnessPhase
              .killLegacyMarkerPublish,
          RestoreLegacyArchivingMarkerProcessHarnessPhase.verifyBusinessReady,
        ]);
        expect(RestoreLegacyArchivingMarkerProcessFailpoint.values, [
          RestoreLegacyArchivingMarkerProcessFailpoint
              .archivingMarkerEmptyRestricted,
          RestoreLegacyArchivingMarkerProcessFailpoint
              .archivingMarkerTempDurable,
          RestoreLegacyArchivingMarkerProcessFailpoint.archivingMarkerPublished,
        ]);
        expect(
          _prefix(
            RestoreLegacyArchivingMarkerProcessFailpoint
                .archivingMarkerEmptyRestricted,
          ),
          'kelivo.restore.legacy.archiving.marker.harness.$_matrixRunId.'
          '$_scenarioId.archivingMarkerEmptyRestricted.',
        );
      },
    );

    test('round-trips every failpoint and phase through strict dispatch', () {
      for (final failpoint
          in RestoreLegacyArchivingMarkerProcessFailpoint.values) {
        for (final phase
            in RestoreLegacyArchivingMarkerProcessHarnessPhase.values) {
          final control = _control(phase: phase, failpoint: failpoint);

          final decoded =
              RestoreLegacyArchivingMarkerProcessHarnessControl.fromJson(
                control.toJson(),
              );
          final dispatched = RestoreHarnessControl.fromJson(control.toJson());

          expect(decoded.generation, phase.index + 1);
          expect(decoded.matrixRunId, _matrixRunId);
          expect(decoded.scenario, restoreLegacyArchivingMarkerHarnessScenario);
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
            isA<RestoreLegacyArchivingMarkerProcessHarnessControl>(),
          );
          expect(dispatched.toJson(), control.toJson());
        }
      }
    });

    test('rejects schema, enum, identity, root, and prefix changes', () {
      final wrongScenario = _validJson()
        ..['scenario'] = restoreTerminalHarnessScenario;
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
          RestoreLegacyArchivingMarkerProcessFailpoint
              .archivingMarkerTempDurable,
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
          () =>
              RestoreLegacyArchivingMarkerProcessHarnessControl.fromJson(json),
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
        () => RestoreLegacyArchivingMarkerProcessHarnessControl(
          generation: 1,
          matrixRunId: 'invalid',
          scenarioId: _scenarioId,
          phase: RestoreLegacyArchivingMarkerProcessHarnessPhase.setup,
          failpoint: RestoreLegacyArchivingMarkerProcessFailpoint
              .archivingMarkerEmptyRestricted,
          scenarioRoot: _scenarioRoot(),
          preferencesPrefix: _prefix(
            RestoreLegacyArchivingMarkerProcessFailpoint
                .archivingMarkerEmptyRestricted,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => RestoreLegacyArchivingMarkerProcessHarnessControl(
          generation: 1,
          matrixRunId: _matrixRunId,
          scenarioId: _scenarioId,
          phase: RestoreLegacyArchivingMarkerProcessHarnessPhase.setup,
          failpoint: RestoreLegacyArchivingMarkerProcessFailpoint
              .archivingMarkerEmptyRestricted,
          scenarioRoot: 'relative/scenario',
          preferencesPrefix: _prefix(
            RestoreLegacyArchivingMarkerProcessFailpoint
                .archivingMarkerEmptyRestricted,
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}

RestoreLegacyArchivingMarkerProcessHarnessControl _control({
  required RestoreLegacyArchivingMarkerProcessHarnessPhase phase,
  required RestoreLegacyArchivingMarkerProcessFailpoint failpoint,
}) => RestoreLegacyArchivingMarkerProcessHarnessControl(
  generation: phase.index + 1,
  matrixRunId: _matrixRunId,
  scenarioId: _scenarioId,
  phase: phase,
  failpoint: failpoint,
  scenarioRoot: _scenarioRoot(),
  preferencesPrefix: _prefix(failpoint),
);

Map<String, dynamic> _validJson() => _control(
  phase: RestoreLegacyArchivingMarkerProcessHarnessPhase.setup,
  failpoint: RestoreLegacyArchivingMarkerProcessFailpoint
      .archivingMarkerEmptyRestricted,
).toJson();

String _scenarioRoot() => p.normalize(
  p.absolute(
    p.join(Directory.systemTemp.path, 'kelivo_restore_process_$_scenarioId'),
  ),
);

String _prefix(RestoreLegacyArchivingMarkerProcessFailpoint failpoint) =>
    restoreLegacyArchivingMarkerProcessPreferencesPrefix(
      matrixRunId: _matrixRunId,
      scenarioId: _scenarioId,
      failpoint: failpoint,
    );
