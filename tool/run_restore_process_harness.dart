import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../integration_test/support/restore_process_control.dart';

const _bundleIdentifier = 'com.psyche.kelivo.restoreharness';
const _integrationTestPath =
    'integration_test/restore_process_harness_test.dart';
const _phaseTimeout = Duration(minutes: 12);
const _exitTimeout = Duration(minutes: 2);
const _maximumLogCharacters = 64 * 1024;

enum _Tier { smoke, core, full }

Future<void> main(List<String> arguments) async {
  final selection = _Selection.parse(arguments);
  final projectRoot = Directory.current.absolute;
  final matrixRunId = _newIdentifier();
  final containerTemporaryDirectory = await _containerTemporaryDirectory();
  final matrixRoot = Directory(
    p.join(
      containerTemporaryDirectory.path,
      'kelivo_restore_process_harness',
      matrixRunId,
    ),
  );
  await matrixRoot.create(recursive: true);
  var passed = 0;
  final stopwatch = Stopwatch()..start();
  try {
    for (final failpoint in selection.failpoints) {
      final scenarioId = _newIdentifier();
      final scenarioRoot = Directory(p.join(matrixRoot.path, scenarioId));
      await scenarioRoot.create();
      stdout.writeln(
        'restore harness: ${failpoint.scenario}/${failpoint.name}',
      );
      for (final phase in RestoreProcessHarnessPhase.values) {
        final control = RestoreProcessHarnessControl(
          generation: phase.index + 1,
          matrixRunId: matrixRunId,
          scenarioId: scenarioId,
          phase: phase,
          failpoint: failpoint,
          scenarioRoot: scenarioRoot.path,
        );
        await _writeControl(control);
        await _runPhase(projectRoot: projectRoot, control: control);
      }
      passed++;
    }
  } catch (error, stackTrace) {
    stderr.writeln('restore harness failed: $error\n$stackTrace');
    stderr.writeln('artifacts preserved at ${matrixRoot.path}');
    exitCode = 1;
    return;
  } finally {
    stopwatch.stop();
  }
  stdout.writeln(
    'restore harness passed: $passed/${selection.failpoints.length} '
    'cases in ${stopwatch.elapsed}',
  );
  await matrixRoot.delete(recursive: true);
}

Future<Directory> _containerTemporaryDirectory() async {
  final userHome = Platform.environment['HOME'];
  if (userHome == null || userHome.isEmpty || !p.isAbsolute(userHome)) {
    throw StateError('restore_harness_home');
  }
  final candidate = Directory(
    p.normalize(
      p.absolute(
        p.join(
          userHome,
          'Library',
          'Containers',
          _bundleIdentifier,
          'Data',
          'tmp',
        ),
      ),
    ),
  );
  final type = await FileSystemEntity.type(candidate.path, followLinks: false);
  if (type == FileSystemEntityType.notFound) {
    await candidate.create(recursive: true);
  } else if (type != FileSystemEntityType.directory) {
    throw StateError('restore_harness_container_tmp');
  }
  final canonical = Directory(
    p.normalize(p.absolute(await candidate.resolveSymbolicLinks())),
  );
  if (!p.equals(canonical.path, candidate.path)) {
    throw StateError('restore_harness_container_tmp_canonical');
  }
  return canonical;
}

final class _Selection {
  const _Selection(this.failpoints);

  final List<RestoreProcessFailpoint> failpoints;

  static _Selection parse(List<String> arguments) {
    _Tier tier = _Tier.smoke;
    String? scenario;
    RestoreProcessFailpoint? single;
    for (final argument in arguments) {
      if (argument.startsWith('--tier=')) {
        final name = argument.substring('--tier='.length);
        tier = _Tier.values.firstWhere(
          (value) => value.name == name,
          orElse: () => throw ArgumentError('unknown tier: $name'),
        );
        continue;
      }
      if (argument.startsWith('--scenario=')) {
        scenario = argument.substring('--scenario='.length);
        if (!const {
          'commit',
          'rollback',
          'terminal',
          'partial-marker',
        }.contains(scenario)) {
          throw ArgumentError('unknown scenario: $scenario');
        }
        continue;
      }
      if (argument.startsWith('--failpoint=')) {
        final name = argument.substring('--failpoint='.length);
        single = RestoreProcessFailpoint.values.firstWhere(
          (value) => value.name == name,
          orElse: () => throw ArgumentError('unknown failpoint: $name'),
        );
        continue;
      }
      throw ArgumentError(
        'usage: dart run tool/run_restore_process_harness.dart '
        '[--tier=smoke|core|full] '
        '[--scenario=commit|rollback|terminal|partial-marker] '
        '[--failpoint=<name>]',
      );
    }

    final tierValues = switch (tier) {
      _Tier.smoke => restoreProcessSmokeFailpoints,
      _Tier.core => restoreProcessCoreFailpoints,
      _Tier.full => restoreProcessFullFailpoints,
    };
    var selected = single == null
        ? List<RestoreProcessFailpoint>.from(tierValues)
        : <RestoreProcessFailpoint>[single];
    if (scenario != null) {
      selected = selected
          .where((value) => value.scenario == scenario)
          .toList(growable: false);
    }
    if (selected.isEmpty) {
      throw ArgumentError('no restore process failpoints selected');
    }
    return _Selection(List.unmodifiable(selected));
  }
}

Future<void> _writeControl(RestoreProcessHarnessControl control) async {
  final file = _controlFile(control);
  await writeDurableHarnessJson(file, control.toJson());
  final readback = RestoreProcessHarnessControl.fromJson(
    await readHarnessJson(file),
  );
  if (jsonEncode(readback.toJson()) != jsonEncode(control.toJson())) {
    throw StateError('restore_harness_control_readback');
  }
}

File _controlFile(RestoreProcessHarnessControl control) => File(
  p.join(
    control.scenarioRoot,
    'control',
    '${control.generation.toString().padLeft(2, '0')}_'
        '${control.phase.name}.json',
  ),
);

Future<void> _runPhase({
  required Directory projectRoot,
  required RestoreProcessHarnessControl control,
}) async {
  final arguments = [
    'test',
    '--no-pub',
    '-d',
    'macos',
    '--flavor',
    'restoreHarness',
    '--no-uninstall',
    '--dart-define=$restoreHarnessControlDefine=${_controlFile(control).path}',
    _integrationTestPath,
  ];
  final process = await Process.start(
    'flutter',
    arguments,
    workingDirectory: projectRoot.path,
    runInShell: false,
  );
  final output = _TailBuffer(_maximumLogCharacters);
  final stdoutDone = process.stdout
      .transform(utf8.decoder)
      .listen(output.add)
      .asFuture<void>();
  final stderrDone = process.stderr
      .transform(utf8.decoder)
      .listen(output.add)
      .asFuture<void>();

  try {
    final event = await _waitForEvent(control, process);
    _validateEvent(control, event);
    if (control.phase == RestoreProcessHarnessPhase.interrupt &&
        !control.failpoint.isPartialMarker) {
      final processId = event['processId'];
      if (processId is! int || processId < 1 || processId == pid) {
        throw StateError('restore_harness_event_process');
      }
      if (!Process.killPid(processId, ProcessSignal.sigkill)) {
        throw StateError('restore_harness_kill_failed:$processId');
      }
      await process.exitCode.timeout(_exitTimeout);
    } else {
      final code = await process.exitCode.timeout(_exitTimeout);
      if (code != 0) {
        throw StateError(
          'restore_harness_phase_exit:${control.phaseName}:$code',
        );
      }
    }
  } catch (error) {
    process.kill(ProcessSignal.sigterm);
    stderr.writeln(output.value);
    rethrow;
  } finally {
    await Future.wait([
      stdoutDone.timeout(_exitTimeout, onTimeout: () {}),
      stderrDone.timeout(_exitTimeout, onTimeout: () {}),
    ]);
  }
}

Future<Map<String, dynamic>> _waitForEvent(
  RestoreProcessHarnessControl control,
  Process process,
) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < _phaseTimeout) {
    final type = await FileSystemEntity.type(
      control.eventFile.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.file) {
      return readHarnessJson(control.eventFile);
    }
    if (type != FileSystemEntityType.notFound) {
      throw StateError('restore_harness_event_type');
    }
    final exited = await Future.any<bool>([
      process.exitCode.then((_) => true),
      Future<bool>.delayed(const Duration(milliseconds: 100), () => false),
    ]);
    if (exited) {
      throw StateError('restore_harness_event_missing:${control.phaseName}');
    }
  }
  throw TimeoutException('restore_harness_event_timeout:${control.phaseName}');
}

void _validateEvent(
  RestoreProcessHarnessControl control,
  Map<String, dynamic> event,
) {
  if (event['format'] != restoreHarnessFormat ||
      event['version'] != 1 ||
      event['matrixRunId'] != control.matrixRunId ||
      event['scenarioId'] != control.scenarioId ||
      event['generation'] != control.generation ||
      event['phase'] != control.phaseName ||
      event['failpoint'] != control.failpointName ||
      event['processId'] is! int) {
    throw StateError('restore_harness_event_binding');
  }
  if (control.phase == RestoreProcessHarnessPhase.interrupt &&
      !control.failpoint.isPartialMarker &&
      (event['status'] != 'boundary' ||
          event['boundary'] != control.failpointName)) {
    throw StateError('restore_harness_boundary_event');
  }
}

String _newIdentifier() {
  final random = Random.secure();
  final buffer = StringBuffer();
  for (var index = 0; index < 16; index++) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

final class _TailBuffer {
  _TailBuffer(this.maximumCharacters);

  final int maximumCharacters;
  String _value = '';

  String get value => _value;

  void add(String chunk) {
    _value += chunk;
    if (_value.length > maximumCharacters) {
      _value = _value.substring(_value.length - maximumCharacters);
    }
  }
}
