import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_durability.dart';

import '../../../../integration_test/support/restore_process_control.dart';
import '../../../../integration_test/support/restore_process_hooks.dart';

const _matrixRunId = 'fedcba9876543210fedcba9876543210';
const _scenarioId = '0123456789abcdef0123456789abcdef';
const _runId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  group('two-leg process harness control', () {
    test('round trips every failpoint through all process phases', () {
      for (final failpoint in RestoreProcessFailpoint.values) {
        for (final phase in RestoreProcessHarnessPhase.values) {
          final control = _control(phase: phase, failpoint: failpoint);

          final decoded = RestoreProcessHarnessControl.fromJson(
            control.toJson(),
          );

          expect(decoded.generation, phase.index + 1);
          expect(decoded.phase, phase);
          expect(decoded.failpoint, failpoint);
          expect(decoded.scenario, failpoint.scenario);
          expect(decoded.scenarioRoot, _scenarioRoot());
          expect(decoded.eventFile.path, contains(phase.name));
        }
      }
    });

    test('contains no retired settings or cold-ack failpoints', () {
      final names = RestoreProcessFailpoint.values
          .map((value) => value.name.toLowerCase())
          .toList();

      expect(names.where((name) => name.contains('settings')), isEmpty);
      expect(names.where((name) => name.contains('cold')), isEmpty);
      expect(
        RestoreProcessFailpoint.values.where((value) => value.triggersRollback),
        isNotEmpty,
      );
      expect(
        RestoreProcessFailpoint.values.where(
          (value) => value.isTerminalBoundary,
        ),
        isNotEmpty,
      );
      expect(
        RestoreProcessFailpoint.values.where((value) => value.isPartialMarker),
        [RestoreProcessFailpoint.publishingMarkerWithoutRun],
      );
    });

    test('publishes stable smoke, core, and full tiers', () {
      expect(
        restoreProcessSmokeFailpoints,
        containsAll(<RestoreProcessFailpoint>{
          RestoreProcessFailpoint.candidateDatabaseMoved,
          RestoreProcessFailpoint.newDatabaseReturnedToCandidate,
          RestoreProcessFailpoint.terminalRunArchived,
          RestoreProcessFailpoint.publishingMarkerWithoutRun,
        }),
      );
      expect(
        restoreProcessCoreFailpoints.toSet().length,
        restoreProcessCoreFailpoints.length,
      );
      expect(restoreProcessFullFailpoints, RestoreProcessFailpoint.values);
    });

    test('rejects unknown fields and mismatched bindings', () {
      final valid = _control(
        phase: RestoreProcessHarnessPhase.setup,
        failpoint: RestoreProcessFailpoint.candidateDatabaseMoved,
      ).toJson();

      expect(
        () => RestoreProcessHarnessControl.fromJson({...valid, 'extra': true}),
        throwsFormatException,
      );
      expect(
        () =>
            RestoreProcessHarnessControl.fromJson({...valid, 'generation': 2}),
        throwsFormatException,
      );
      expect(
        () => RestoreProcessHarnessControl.fromJson({
          ...valid,
          'scenario': 'rollback',
        }),
        throwsFormatException,
      );
      expect(
        () => RestoreProcessHarnessControl.fromJson({
          ...valid,
          'failpoint': 'settingsFirstSet',
        }),
        throwsFormatException,
      );
    });
  });

  group('two-leg process durability hooks', () {
    late Directory root;
    late Directory appData;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'kelivo_restore_process_hook_test_',
      );
      appData = Directory(p.join(root.path, 'app_data'));
      await appData.create();
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('notifies after the exact candidate database rename', () async {
      final source = File(
        p.join(
          appData.path,
          '.kelivo_restore',
          'run_$_runId',
          'candidate',
          'database',
          'kelivo.db',
        ),
      );
      await source.parent.create(recursive: true);
      await source.writeAsBytes([1, 2, 3], flush: true);
      final reached = <RestoreProcessFailpoint>[];
      final hook = RestoreProcessBoundaryDurability(
        appDataDirectory: appData,
        runId: _runId,
        failpoint: RestoreProcessFailpoint.candidateDatabaseMoved,
        delegate: RestorePlatformDurability(),
        onBoundary: (value) async => reached.add(value),
      );

      await hook.renameAndSync(
        source: source,
        targetPath: p.join(appData.path, 'kelivo.db'),
      );

      expect(reached, [RestoreProcessFailpoint.candidateDatabaseMoved]);
    });

    test(
      'forces rollback once, then observes the reverse database move',
      () async {
        final candidate = File(
          p.join(
            appData.path,
            '.kelivo_restore',
            'run_$_runId',
            'candidate',
            'database',
            'kelivo.db',
          ),
        );
        await candidate.parent.create(recursive: true);
        await candidate.writeAsBytes([1, 2, 3], flush: true);
        final live = File(p.join(appData.path, 'kelivo.db'));
        final reached = <RestoreProcessFailpoint>[];
        final hook = RestoreProcessBoundaryDurability(
          appDataDirectory: appData,
          runId: _runId,
          failpoint: RestoreProcessFailpoint.newDatabaseReturnedToCandidate,
          delegate: RestorePlatformDurability(),
          triggerRollback: true,
          onBoundary: (value) async => reached.add(value),
        );

        await expectLater(
          hook.renameAndSync(source: candidate, targetPath: live.path),
          throwsA(isA<StateError>()),
        );
        await hook.renameAndSync(source: live, targetPath: candidate.path);

        expect(reached, [
          RestoreProcessFailpoint.newDatabaseReturnedToCandidate,
        ]);
      },
    );

    test(
      'forces rollback after an asset install so its reverse move is reachable',
      () async {
        final candidate = Directory(
          p.join(
            appData.path,
            '.kelivo_restore',
            'run_$_runId',
            'candidate',
            'upload',
          ),
        );
        await candidate.create(recursive: true);
        await File(
          p.join(candidate.path, 'new.txt'),
        ).writeAsString('new', flush: true);
        final live = Directory(p.join(appData.path, 'upload'));
        final reached = <RestoreProcessFailpoint>[];
        final hook = RestoreProcessBoundaryDurability(
          appDataDirectory: appData,
          runId: _runId,
          failpoint: RestoreProcessFailpoint.newAssetsReturnedToCandidate,
          delegate: RestorePlatformDurability(),
          triggerRollback: true,
          onBoundary: (value) async => reached.add(value),
        );

        await expectLater(
          hook.renameAndSync(source: candidate, targetPath: live.path),
          throwsA(isA<StateError>()),
        );
        await hook.renameAndSync(source: live, targetPath: candidate.path);

        expect(reached, [RestoreProcessFailpoint.newAssetsReturnedToCandidate]);
      },
    );

    test('binds receipt publication to its terminal state', () async {
      final receipts = Directory(
        p.join(appData.path, '.kelivo_restore', 'run_$_runId', 'receipts'),
      );
      await receipts.create(recursive: true);
      final temporary = File(
        p.join(receipts.path, 'receipt_0000000000000005.json.tmp'),
      );
      await temporary.writeAsString(
        jsonEncode({'state': 'committed'}),
        flush: true,
      );
      final reached = <RestoreProcessFailpoint>[];
      final hook = RestoreProcessBoundaryDurability(
        appDataDirectory: appData,
        runId: _runId,
        failpoint: RestoreProcessFailpoint.committedReceiptPublished,
        delegate: RestorePlatformDurability(),
        onBoundary: (value) async => reached.add(value),
      );

      await hook.renameAndSync(
        source: temporary,
        targetPath: p.join(receipts.path, 'receipt_0000000000000005.json'),
      );

      expect(reached, [RestoreProcessFailpoint.committedReceiptPublished]);
    });
  });

  test('durable harness JSON publishes and reads back strictly', () async {
    final root = await Directory.systemTemp.createTemp(
      'kelivo_restore_process_json_test_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final file = File(p.join(root.path, 'event.json'));
    final payload = <String, dynamic>{'format': 'test', 'value': 7};

    await writeDurableHarnessJson(file, payload);

    expect(await readHarnessJson(file), payload);
  });
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
  );
}

String _scenarioRoot() => p.join(
  Directory.systemTemp.path,
  'kelivo_restore_process_matrix',
  _matrixRunId,
  _scenarioId,
);
