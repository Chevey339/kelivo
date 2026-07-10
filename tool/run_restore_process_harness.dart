import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../integration_test/support/restore_process_control.dart';

const _bundleIdentifier = 'com.psyche.kelivo.restoreharness';
const _integrationTestPath =
    'integration_test/restore_process_harness_test.dart';
const _hostLockFileName = '.kelivo_restore_process_harness.lock';
const _maximumLogCharacters = 64 * 1024;
const _phaseTimeout = Duration(minutes: 12);
const _killExitTimeout = Duration(minutes: 2);
const _processCleanupTimeout = Duration(seconds: 30);
const _runnerExitTimeout = Duration(seconds: 30);
const _processTableTimeout = Duration(seconds: 10);
const _ioCloseTimeout = Duration(seconds: 10);
const _maximumProcessTableBytes = 8 * 1024 * 1024;
final _identifierPattern = RegExp(r'^[a-f0-9]{32}$');
final _hostProcessId = pid;
final _processTableLinePattern = RegExp(
  r'^\s*([0-9]+)\s+'
  r'([A-Z][a-z]{2}\s+[A-Z][a-z]{2}\s+[0-9]{1,2}\s+'
  r'[0-9]{2}:[0-9]{2}:[0-9]{2}\s+[0-9]{4})\s+(.+?)\s*$',
);

Future<void> main(List<String> arguments) async {
  _RestoreProcessHarnessHost? host;
  try {
    if (arguments.isNotEmpty) {
      throw ArgumentError('run_restore_process_harness takes no arguments');
    }
    host = await _RestoreProcessHarnessHost.create();
    await host.run();
  } catch (error, stackTrace) {
    stderr.writeln('Restore process harness failed: $error');
    stderr.writeln(stackTrace);
    if (host != null) {
      final cleanupErrors = await host.cleanOrphanProcesses();
      for (final cleanupError in cleanupErrors) {
        stderr.writeln('Cleanup failure: $cleanupError');
      }
      stderr.writeln(
        'Scenario retained for diagnosis: ${host.scenarioRoot.path}',
      );
      host.writeProcessDiagnostics(stderr);
    }
    exitCode = 1;
  } finally {
    if (host != null) {
      try {
        await host.releaseHostLock();
      } catch (error, stackTrace) {
        stderr.writeln('Host-lock release failed: $error');
        stderr.writeln(stackTrace);
        exitCode = 1;
      }
    }
  }
}

final class _RestoreProcessHarnessHost {
  _RestoreProcessHarnessHost._({
    required this.projectRoot,
    required this.containerTemporaryDirectory,
    required this.scenarioId,
    required this.scenarioRoot,
    required this.restoreHarnessExecutablePath,
    required this._hostLock,
  });

  static Future<_RestoreProcessHarnessHost> create() async {
    if (!Platform.isMacOS) {
      throw UnsupportedError('restore_process_harness_requires_macos');
    }
    final projectRootCandidate = Directory(
      p.normalize(
        p.absolute(p.join(p.dirname(Platform.script.toFilePath()), '..')),
      ),
    );
    final projectRoot = Directory(
      p.normalize(
        p.absolute(await projectRootCandidate.resolveSymbolicLinks()),
      ),
    );
    if (await FileSystemEntity.type(
          p.join(projectRoot.path, 'pubspec.yaml'),
          followLinks: false,
        ) !=
        FileSystemEntityType.file) {
      throw StateError('restore_harness_project_root');
    }
    if (await FileSystemEntity.type(
          p.join(projectRoot.path, _integrationTestPath),
          followLinks: false,
        ) !=
        FileSystemEntityType.file) {
      throw StateError('restore_harness_integration_test_missing');
    }

    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty || !p.isAbsolute(home)) {
      throw StateError('restore_harness_home');
    }
    final containerTemporaryDirectoryCandidate = Directory(
      p.normalize(
        p.absolute(
          p.join(
            home,
            'Library',
            'Containers',
            _bundleIdentifier,
            'Data',
            'tmp',
          ),
        ),
      ),
    );
    final containerType = await FileSystemEntity.type(
      containerTemporaryDirectoryCandidate.path,
      followLinks: false,
    );
    if (containerType == FileSystemEntityType.notFound) {
      await containerTemporaryDirectoryCandidate.create(recursive: true);
    } else if (containerType != FileSystemEntityType.directory) {
      throw StateError('restore_harness_container_tmp');
    }
    final containerTemporaryDirectory = Directory(
      p.normalize(
        p.absolute(
          await containerTemporaryDirectoryCandidate.resolveSymbolicLinks(),
        ),
      ),
    );
    if (await FileSystemEntity.type(
              containerTemporaryDirectory.path,
              followLinks: false,
            ) !=
            FileSystemEntityType.directory ||
        !p.equals(
          containerTemporaryDirectory.path,
          containerTemporaryDirectoryCandidate.path,
        )) {
      throw StateError('restore_harness_container_tmp_canonical');
    }

    final hostLock = await _acquireHostLock(containerTemporaryDirectory);
    try {
      final scenarioId = _newScenarioId();
      final scenarioRoot = Directory(
        p.join(
          containerTemporaryDirectory.path,
          'kelivo_restore_process_$scenarioId',
        ),
      );
      if (await FileSystemEntity.type(scenarioRoot.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('restore_harness_scenario_collision');
      }
      await scenarioRoot.create();
      final canonicalScenarioRoot = Directory(
        p.normalize(p.absolute(await scenarioRoot.resolveSymbolicLinks())),
      );
      if (!p.equals(canonicalScenarioRoot.path, scenarioRoot.path) ||
          !p.isWithin(
            containerTemporaryDirectory.path,
            canonicalScenarioRoot.path,
          ) ||
          p.basename(canonicalScenarioRoot.path) !=
              'kelivo_restore_process_$scenarioId') {
        throw StateError('restore_harness_scenario_boundary');
      }
      final restoreHarnessExecutablePath = p.normalize(
        p.absolute(
          p.join(
            projectRoot.path,
            'build',
            'macos',
            'Build',
            'Products',
            'Debug-RestoreHarness',
            'kelivo.app',
            'Contents',
            'MacOS',
            'kelivo',
          ),
        ),
      );
      return _RestoreProcessHarnessHost._(
        projectRoot: projectRoot,
        containerTemporaryDirectory: containerTemporaryDirectory,
        scenarioId: scenarioId,
        scenarioRoot: canonicalScenarioRoot,
        restoreHarnessExecutablePath: restoreHarnessExecutablePath,
        hostLock: hostLock,
      );
    } catch (error, stackTrace) {
      try {
        await _releaseHostLockHandle(hostLock);
      } catch (releaseError) {
        throw StateError(
          'restore_harness_create_and_lock_release:'
          '${error.runtimeType}:${releaseError.runtimeType}',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  final Directory projectRoot;
  final Directory containerTemporaryDirectory;
  final String scenarioId;
  final Directory scenarioRoot;
  final String restoreHarnessExecutablePath;
  RandomAccessFile? _hostLock;
  final List<_ManagedProcess> _processes = [];
  final Set<_RunnerIdentity> _activeRunnerIdentities = {};
  final Set<int> _observedRunnerProcessIds = {};

  String get _preferencesPrefix => 'kelivo.restore.harness.$scenarioId.';

  Future<void> releaseHostLock() async {
    final hostLock = _hostLock;
    if (hostLock == null) return;
    _hostLock = null;
    await _releaseHostLockHandle(hostLock);
  }

  Future<void> run() async {
    stdout.writeln('Restore process harness scenario: ${scenarioRoot.path}');

    final setup = await _runNormalPhase(
      RestoreProcessHarnessPhase.setup,
      _validateSetupEvent,
    );
    final runId = setup.requireString('runId');

    final cutover = await _runCutoverPhase(runId);
    final cutoverLeaseInstanceId = cutover.requireIdentifier('leaseInstanceId');

    final resume = await _runNormalPhase(
      RestoreProcessHarnessPhase.resumeToColdAck,
      (event, control, process) => _validateResumeEvent(
        event,
        control,
        process,
        runId: runId,
        cutoverLeaseInstanceId: cutoverLeaseInstanceId,
      ),
    );
    final resumeProcessId = resume.pid;
    final resumeLeaseInstanceId = resume.requireIdentifier('leaseInstanceId');

    await _runNormalPhase(
      RestoreProcessHarnessPhase.coldFinalize,
      (event, control, process) => _validateFinalizeEvent(
        event,
        control,
        process,
        runId: runId,
        resumeProcessId: resumeProcessId,
        resumeLeaseInstanceId: resumeLeaseInstanceId,
        cutoverLeaseInstanceId: cutoverLeaseInstanceId,
      ),
    );

    final cleanupErrors = await cleanOrphanProcesses();
    if (cleanupErrors.isNotEmpty) {
      throw StateError(
        'restore_harness_process_cleanup:${cleanupErrors.join('|')}',
      );
    }
    await _deleteSuccessfulScenario();
    stdout.writeln(
      'Restore process harness passed; Runner PIDs: '
      '${_observedRunnerProcessIds.join(', ')}',
    );
  }

  Future<_HarnessEvent> _runNormalPhase(
    RestoreProcessHarnessPhase phase,
    _EventValidator validate,
  ) async {
    final control = await _writeControl(phase);
    final process = await _startFlutter(control);
    final event = await _waitForEvent(control, process);
    validate(event, control, process);
    final runner = await _recordRunnerProcess(event, process);

    final outerExitCode = await process.waitForExit(_phaseTimeout);
    if (outerExitCode != 0) {
      throw StateError(
        'restore_harness_outer_exit:${phase.name}:$outerExitCode',
      );
    }
    await _requireRunnerExited(runner);
    _activeRunnerIdentities.remove(runner.identity);
    return event;
  }

  Future<_HarnessEvent> _runCutoverPhase(String runId) async {
    final control = await _writeControl(RestoreProcessHarnessPhase.cutoverKill);
    final process = await _startFlutter(control);
    final event = await _waitForEvent(control, process);
    _validateCutoverEvent(event, control, process, runId: runId);
    final runner = await _recordRunnerProcess(event, process);

    await _requireSameRunner(runner);
    if (!Process.killPid(event.pid, ProcessSignal.sigkill)) {
      throw StateError('restore_harness_runner_kill_failed:${event.pid}');
    }
    await _requireRunnerExited(runner);
    _activeRunnerIdentities.remove(runner.identity);

    final outerExitCode = await process.waitForExit(_killExitTimeout);
    if (outerExitCode == 0) {
      throw StateError('restore_harness_cutover_outer_succeeded');
    }
    return event;
  }

  Future<RestoreProcessHarnessControl> _writeControl(
    RestoreProcessHarnessPhase phase,
  ) async {
    final generation = phase.index + 1;
    final control = RestoreProcessHarnessControl(
      generation: generation,
      scenarioId: scenarioId,
      phase: phase,
      scenarioRoot: scenarioRoot.path,
      preferencesPrefix: _preferencesPrefix,
    );
    final controlFile = _controlFile(control);
    await writeDurableHarnessJson(controlFile, control.toJson());
    final persisted = RestoreProcessHarnessControl.fromJson(
      await readHarnessJson(controlFile),
    );
    if (persisted.generation != control.generation ||
        persisted.scenarioId != control.scenarioId ||
        persisted.phase != control.phase ||
        !p.equals(persisted.scenarioRoot, control.scenarioRoot) ||
        persisted.preferencesPrefix != control.preferencesPrefix) {
      throw StateError('restore_harness_control_readback');
    }
    return control;
  }

  File _controlFile(RestoreProcessHarnessControl control) => File(
    p.join(
      scenarioRoot.path,
      'control',
      '${control.generation.toString().padLeft(2, '0')}_'
          '${control.phase.name}.json',
    ),
  );

  Future<_ManagedProcess> _startFlutter(
    RestoreProcessHarnessControl control,
  ) async {
    final runnerBaseline = {
      for (final runner in await _readRestoreHarnessProcesses())
        runner.identity,
    };
    final controlFile = _controlFile(control);
    final arguments = [
      'test',
      '--no-pub',
      '-d',
      'macos',
      '--flavor',
      'restoreHarness',
      '--no-uninstall',
      '--dart-define=$restoreHarnessControlDefine=${controlFile.path}',
      _integrationTestPath,
    ];
    final process = await Process.start(
      'flutter',
      arguments,
      workingDirectory: projectRoot.path,
      runInShell: false,
    );
    final managed = _ManagedProcess(
      phase: control.phase,
      command: ['flutter', ...arguments],
      process: process,
      runnerBaseline: runnerBaseline,
    );
    _processes.add(managed);
    stdout.writeln('Started ${control.phase.name}: outer PID ${process.pid}');
    return managed;
  }

  Future<_HarnessEvent> _waitForEvent(
    RestoreProcessHarnessControl control,
    _ManagedProcess process,
  ) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < _phaseTimeout) {
      await _observePhaseRunner(process);
      final type = await FileSystemEntity.type(
        control.eventFile.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.file) {
        return _HarnessEvent.fromJson(await readHarnessJson(control.eventFile));
      }
      if (type != FileSystemEntityType.notFound) {
        throw StateError('restore_harness_event_type:${control.phase.name}');
      }
      if (process.hasExited) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await _observePhaseRunner(process);
        if (await FileSystemEntity.type(
              control.eventFile.path,
              followLinks: false,
            ) ==
            FileSystemEntityType.file) {
          return _HarnessEvent.fromJson(
            await readHarnessJson(control.eventFile),
          );
        }
        throw StateError(
          'restore_harness_event_missing:${control.phase.name}:'
          '${process.completedExitCode}',
        );
      }
      await Future.any<void>([
        Future<void>.delayed(const Duration(milliseconds: 100)),
        process.exited.then<void>((_) {}),
      ]);
    }
    throw TimeoutException(
      'restore_harness_event_timeout:${control.phase.name}',
      _phaseTimeout,
    );
  }

  Future<void> _observePhaseRunner(_ManagedProcess process) async {
    final candidates = (await _readRestoreHarnessProcesses())
        .where((runner) => !process.runnerBaseline.contains(runner.identity))
        .toList(growable: false);
    if (candidates.isEmpty) return;
    if (candidates.length != 1) {
      throw StateError(
        'restore_harness_phase_runner_count:'
        '${process.phase.name}:${candidates.length}',
      );
    }
    final observed = candidates.single;
    final existing = process.discoveredRunner;
    if (existing != null && existing.identity != observed.identity) {
      throw StateError(
        'restore_harness_phase_runner_changed:${process.phase.name}',
      );
    }
    process.discoveredRunner = observed;
    process.runnerProcessId = observed.pid;
  }

  void _validateSetupEvent(
    _HarnessEvent event,
    RestoreProcessHarnessControl control,
    _ManagedProcess process,
  ) {
    event.requireCommon(
      control,
      process,
      expectedStatus: 'completed',
      phaseSpecificKeys: const {'runId', 'receiptState'},
    );
    event.requireIdentifier('runId');
    event.requireExactString('receiptState', 'prepared');
  }

  void _validateCutoverEvent(
    _HarnessEvent event,
    RestoreProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
  }) {
    event.requireCommon(
      control,
      process,
      expectedStatus: 'readyForKill',
      phaseSpecificKeys: const {
        'marker',
        'runId',
        'leaseInstanceId',
        'liveDatabasePath',
      },
    );
    event.requireExactString('marker', restoreHarnessScenario);
    event.requireExactString('runId', runId);
    event.requireIdentifier('leaseInstanceId');
    final expectedLiveDatabase = p.normalize(
      p.absolute(p.join(control.appDataDirectory.path, 'kelivo.sqlite')),
    );
    final actualLiveDatabase = event.requireString('liveDatabasePath');
    if (!p.isAbsolute(actualLiveDatabase) ||
        !p.equals(
          p.normalize(p.absolute(actualLiveDatabase)),
          expectedLiveDatabase,
        )) {
      throw StateError('restore_harness_event_live_database');
    }
  }

  void _validateResumeEvent(
    _HarnessEvent event,
    RestoreProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
    required String cutoverLeaseInstanceId,
  }) {
    event.requireCommon(
      control,
      process,
      expectedStatus: 'completed',
      phaseSpecificKeys: const {
        'runId',
        'receiptState',
        'leaseInstanceId',
        'coldAckProcessId',
        'coldAckLeaseInstanceId',
      },
    );
    event.requireExactString('runId', runId);
    event.requireExactString('receiptState', 'committed');
    final leaseInstanceId = event.requireIdentifier('leaseInstanceId');
    if (leaseInstanceId == cutoverLeaseInstanceId) {
      throw StateError('restore_harness_resume_lease_reused');
    }
    if (event.requireInt('coldAckProcessId') != event.pid) {
      throw StateError('restore_harness_resume_ack_pid');
    }
    if (event.requireIdentifier('coldAckLeaseInstanceId') != leaseInstanceId) {
      throw StateError('restore_harness_resume_ack_lease');
    }
  }

  void _validateFinalizeEvent(
    _HarnessEvent event,
    RestoreProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
    required int resumeProcessId,
    required String resumeLeaseInstanceId,
    required String cutoverLeaseInstanceId,
  }) {
    event.requireCommon(
      control,
      process,
      expectedStatus: 'completed',
      phaseSpecificKeys: const {
        'runId',
        'receiptState',
        'observedAckProcessId',
        'observedAckLeaseInstanceId',
        'leaseInstanceId',
        'settingsMutationAttempts',
      },
    );
    event.requireExactString('runId', runId);
    event.requireExactString('receiptState', 'committed');
    if (event.requireInt('observedAckProcessId') != resumeProcessId) {
      throw StateError('restore_harness_finalize_ack_pid');
    }
    if (event.requireIdentifier('observedAckLeaseInstanceId') !=
        resumeLeaseInstanceId) {
      throw StateError('restore_harness_finalize_ack_lease');
    }
    final leaseInstanceId = event.requireIdentifier('leaseInstanceId');
    if (leaseInstanceId == resumeLeaseInstanceId ||
        leaseInstanceId == cutoverLeaseInstanceId) {
      throw StateError('restore_harness_finalize_lease_reused');
    }
    if (event.requireInt('settingsMutationAttempts') != 0) {
      throw StateError('restore_harness_finalize_settings_mutation');
    }
  }

  Future<_RunnerProcessSnapshot> _recordRunnerProcess(
    _HarnessEvent event,
    _ManagedProcess process,
  ) async {
    if (event.pid == _hostProcessId || event.pid == process.process.pid) {
      throw StateError('restore_harness_runner_pid_identity:${event.pid}');
    }
    final runner =
        process.discoveredRunner ?? await _readProcessSnapshot(event.pid);
    if (runner == null ||
        runner.pid != event.pid ||
        !runner.matchesExecutable(restoreHarnessExecutablePath) ||
        process.runnerBaseline.contains(runner.identity)) {
      throw StateError('restore_harness_runner_process:${event.pid}');
    }
    if (!_observedRunnerProcessIds.add(event.pid)) {
      throw StateError('restore_harness_runner_pid_reused:${event.pid}');
    }
    _activeRunnerIdentities.add(runner.identity);
    process.runnerProcessId = event.pid;
    return runner;
  }

  Future<void> _requireSameRunner(_RunnerProcessSnapshot expected) async {
    final current = await _readProcessSnapshot(expected.pid);
    if (current == null ||
        current.identity != expected.identity ||
        !current.matchesExecutable(restoreHarnessExecutablePath)) {
      throw StateError('restore_harness_runner_identity:${expected.pid}');
    }
  }

  Future<void> _requireRunnerExited(_RunnerProcessSnapshot expected) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < _runnerExitTimeout) {
      final current = await _readProcessSnapshot(expected.pid);
      if (current == null || current.identity != expected.identity) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('restore_harness_runner_still_alive:${expected.pid}');
  }

  Future<void> _killRunnerIfSame(_RunnerIdentity identity) async {
    final current = await _readProcessSnapshot(identity.pid);
    if (current == null || current.identity != identity) return;
    if (!current.matchesExecutable(restoreHarnessExecutablePath)) {
      throw StateError(
        'restore_harness_cleanup_runner_identity:${identity.pid}',
      );
    }
    if (!Process.killPid(identity.pid, ProcessSignal.sigkill)) {
      throw StateError('restore_harness_cleanup_runner:${identity.pid}');
    }
    await _requireRunnerExited(current);
  }

  Future<List<_RunnerProcessSnapshot>> _readRestoreHarnessProcesses() async {
    final result = await Process.run('/bin/ps', const [
      '-ww',
      '-axo',
      'pid=,lstart=,command=',
    ]).timeout(_processTableTimeout);
    if (result.exitCode != 0) {
      throw StateError('restore_harness_process_table:${result.exitCode}');
    }
    final output = result.stdout;
    if (output is! String ||
        utf8.encode(output).length > _maximumProcessTableBytes) {
      throw StateError('restore_harness_process_table_output');
    }
    return _parseProcessTable(output)
        .where(
          (snapshot) =>
              snapshot.matchesExecutable(restoreHarnessExecutablePath),
        )
        .toList(growable: false);
  }

  Future<_RunnerProcessSnapshot?> _readProcessSnapshot(int processId) async {
    final result = await Process.run('/bin/ps', [
      '-ww',
      '-p',
      '$processId',
      '-o',
      'pid=,lstart=,command=',
    ]).timeout(_processTableTimeout);
    if (result.exitCode != 0) return null;
    final output = result.stdout;
    if (output is! String ||
        utf8.encode(output).length > _maximumProcessTableBytes) {
      throw StateError('restore_harness_process_snapshot_output');
    }
    final snapshots = _parseProcessTable(output);
    if (snapshots.isEmpty) return null;
    if (snapshots.length != 1 || snapshots.single.pid != processId) {
      throw StateError('restore_harness_process_snapshot_identity');
    }
    return snapshots.single;
  }

  Future<List<Object>> cleanOrphanProcesses() async {
    final errors = <Object>[];
    for (final process in _processes) {
      try {
        await process.stopIfRunning(_processCleanupTimeout);
      } catch (error) {
        errors.add(error);
      }
    }

    final candidates = <_RunnerIdentity>{..._activeRunnerIdentities};
    for (final process in _processes) {
      final discovered = process.discoveredRunner;
      if (discovered != null) candidates.add(discovered.identity);
    }
    for (final identity in candidates) {
      try {
        await _killRunnerIfSame(identity);
        _activeRunnerIdentities.remove(identity);
      } catch (error) {
        errors.add(error);
      }
    }
    return errors;
  }

  void writeProcessDiagnostics(IOSink sink) {
    for (final process in _processes) {
      sink.writeln('\n[${process.phase.name}] ${process.command.join(' ')}');
      sink.writeln('outer PID: ${process.process.pid}');
      sink.writeln('runner PID: ${process.runnerProcessId ?? 'unknown'}');
      sink.writeln('exit: ${process.completedExitCode ?? 'running'}');
      sink.writeln('stdout tail:\n${process.stdoutTail}');
      sink.writeln('stderr tail:\n${process.stderrTail}');
    }
  }

  Future<void> _deleteSuccessfulScenario() async {
    final type = await FileSystemEntity.type(
      scenarioRoot.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.directory) {
      throw StateError('restore_harness_cleanup_scenario');
    }
    final canonicalContainer = p.normalize(
      p.absolute(await containerTemporaryDirectory.resolveSymbolicLinks()),
    );
    final canonicalScenario = p.normalize(
      p.absolute(await scenarioRoot.resolveSymbolicLinks()),
    );
    if (!p.equals(canonicalContainer, containerTemporaryDirectory.path) ||
        !p.equals(canonicalScenario, scenarioRoot.path) ||
        !p.isWithin(canonicalContainer, canonicalScenario) ||
        p.basename(canonicalScenario) != 'kelivo_restore_process_$scenarioId') {
      throw StateError('restore_harness_cleanup_boundary');
    }
    await scenarioRoot.delete(recursive: true);
    if (await FileSystemEntity.type(scenarioRoot.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('restore_harness_cleanup_result');
    }
  }
}

typedef _EventValidator =
    void Function(
      _HarnessEvent event,
      RestoreProcessHarnessControl control,
      _ManagedProcess process,
    );

final class _HarnessEvent {
  _HarnessEvent._(this.json, this.pid);

  static const _commonKeys = {
    'format',
    'version',
    'generation',
    'scenario',
    'scenarioId',
    'phase',
    'pid',
    'status',
  };

  final Map<String, dynamic> json;
  final int pid;

  factory _HarnessEvent.fromJson(Map<dynamic, dynamic> source) {
    if (source.keys.any((key) => key is! String)) {
      throw const FormatException('restore_harness_event_keys');
    }
    final json = source.cast<String, dynamic>();
    final rawPid = json['pid'];
    if (rawPid is! int || rawPid <= 1) {
      throw const FormatException('restore_harness_event_pid');
    }
    return _HarnessEvent._(Map.unmodifiable(json), rawPid);
  }

  void requireCommon(
    RestoreProcessHarnessControl control,
    _ManagedProcess process, {
    required String expectedStatus,
    required Set<String> phaseSpecificKeys,
  }) {
    final expectedKeys = {..._commonKeys, ...phaseSpecificKeys};
    if (json.length != expectedKeys.length ||
        !json.keys.toSet().containsAll(expectedKeys)) {
      throw FormatException(
        'restore_harness_event_fields:${control.phase.name}',
      );
    }
    if (json['format'] != restoreHarnessFormat ||
        json['version'] != RestoreProcessHarnessControl.version ||
        json['generation'] != control.generation ||
        json['scenario'] != restoreHarnessScenario ||
        json['scenarioId'] != control.scenarioId ||
        json['phase'] != control.phase.name ||
        json['status'] != expectedStatus) {
      throw FormatException(
        'restore_harness_event_binding:${control.phase.name}',
      );
    }
    if (pid == process.process.pid || pid == _hostProcessId) {
      throw FormatException(
        'restore_harness_event_process:${control.phase.name}',
      );
    }
  }

  String requireString(String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('restore_harness_event_string:$key');
    }
    return value;
  }

  void requireExactString(String key, String expected) {
    if (requireString(key) != expected) {
      throw FormatException('restore_harness_event_value:$key');
    }
  }

  String requireIdentifier(String key) {
    final value = requireString(key);
    if (!_identifierPattern.hasMatch(value)) {
      throw FormatException('restore_harness_event_identifier:$key');
    }
    return value;
  }

  int requireInt(String key) {
    final value = json[key];
    if (value is! int || value < 0) {
      throw FormatException('restore_harness_event_int:$key');
    }
    return value;
  }
}

final class _ManagedProcess {
  _ManagedProcess({
    required this.phase,
    required this.command,
    required this.process,
    required Set<_RunnerIdentity> runnerBaseline,
  }) : _stdout = _TailBuffer(_maximumLogCharacters),
       _stderr = _TailBuffer(_maximumLogCharacters),
       runnerBaseline = Set.unmodifiable(runnerBaseline) {
    _stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .listen(
          _stdout.add,
          onError: _stdout.addError,
          onDone: _completeStdout,
        );
    _stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .listen(
          _stderr.add,
          onError: _stderr.addError,
          onDone: _completeStderr,
        );
    exited = process.exitCode.then((code) {
      completedExitCode = code;
      return code;
    });
  }

  final RestoreProcessHarnessPhase phase;
  final List<String> command;
  final Process process;
  final Set<_RunnerIdentity> runnerBaseline;
  final _TailBuffer _stdout;
  final _TailBuffer _stderr;
  final Completer<void> _stdoutDone = Completer<void>();
  final Completer<void> _stderrDone = Completer<void>();
  late final StreamSubscription<String> _stdoutSubscription;
  late final StreamSubscription<String> _stderrSubscription;
  late final Future<int> exited;
  Future<void>? _closeStreamsFuture;
  int? completedExitCode;
  int? runnerProcessId;
  _RunnerProcessSnapshot? discoveredRunner;

  bool get hasExited => completedExitCode != null;
  String get stdoutTail => _stdout.value;
  String get stderrTail => _stderr.value;

  Future<int> waitForExit(Duration timeout) async {
    final result = await exited.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'restore_harness_outer_timeout:${phase.name}',
        timeout,
      ),
    );
    await _closeStreams();
    return result;
  }

  Future<void> stopIfRunning(Duration timeout) async {
    if (!hasExited && !process.kill(ProcessSignal.sigkill)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!hasExited) {
        throw StateError('restore_harness_outer_kill:${phase.name}');
      }
    }
    await exited.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'restore_harness_outer_cleanup_timeout:${phase.name}',
        timeout,
      ),
    );
    await _closeStreams();
  }

  void _completeStdout() {
    if (!_stdoutDone.isCompleted) _stdoutDone.complete();
  }

  void _completeStderr() {
    if (!_stderrDone.isCompleted) _stderrDone.complete();
  }

  Future<void> _closeStreams() => _closeStreamsFuture ??= _closeStreamsOnce();

  Future<void> _closeStreamsOnce() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    void remember(Object error, StackTrace stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }

    try {
      await process.stdin.close().timeout(_ioCloseTimeout);
    } catch (error, stackTrace) {
      remember(error, stackTrace);
    }
    try {
      await Future.wait<void>([
        _stdoutDone.future,
        _stderrDone.future,
      ]).timeout(_ioCloseTimeout);
    } catch (error, stackTrace) {
      remember(error, stackTrace);
    }
    for (final subscription in [_stdoutSubscription, _stderrSubscription]) {
      try {
        await subscription.cancel().timeout(_ioCloseTimeout);
      } catch (error, stackTrace) {
        remember(error, stackTrace);
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }
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

  void addError(Object error, StackTrace stackTrace) {
    add('\n[stream error: $error]\n$stackTrace\n');
  }
}

Future<RandomAccessFile> _acquireHostLock(
  Directory containerTemporaryDirectory,
) async {
  final lockFile = File(
    p.join(containerTemporaryDirectory.path, _hostLockFileName),
  );
  final initialType = await FileSystemEntity.type(
    lockFile.path,
    followLinks: false,
  );
  if (initialType != FileSystemEntityType.notFound &&
      initialType != FileSystemEntityType.file) {
    throw StateError('restore_harness_host_lock_type');
  }
  final handle = await lockFile.open(mode: FileMode.append);
  try {
    if (await FileSystemEntity.type(lockFile.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('restore_harness_host_lock_type');
    }
    // FileLock.exclusive is intentionally non-blocking. A second harness must
    // fail before creating a scenario or touching Flutter's shared build tree.
    await handle.lock(FileLock.exclusive);
    return handle;
  } catch (error, stackTrace) {
    try {
      await handle.close();
    } catch (closeError) {
      throw StateError(
        'restore_harness_host_lock_and_close:'
        '${error.runtimeType}:${closeError.runtimeType}',
      );
    }
    Error.throwWithStackTrace(
      StateError('restore_harness_host_lock:${error.runtimeType}'),
      stackTrace,
    );
  }
}

Future<void> _releaseHostLockHandle(RandomAccessFile handle) async {
  Object? firstError;
  StackTrace? firstStackTrace;
  try {
    await handle.unlock();
  } catch (error, stackTrace) {
    firstError = error;
    firstStackTrace = stackTrace;
  }
  try {
    await handle.close();
  } catch (error, stackTrace) {
    firstError ??= error;
    firstStackTrace ??= stackTrace;
  }
  if (firstError != null) {
    Error.throwWithStackTrace(firstError, firstStackTrace!);
  }
}

String _newScenarioId() {
  final random = Random.secure();
  return List<int>.generate(
    16,
    (_) => random.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

List<_RunnerProcessSnapshot> _parseProcessTable(String output) {
  final snapshots = <_RunnerProcessSnapshot>[];
  for (final line in const LineSplitter().convert(output)) {
    if (line.trim().isEmpty) continue;
    final match = _processTableLinePattern.firstMatch(line);
    if (match == null) {
      throw const FormatException('restore_harness_process_table_format');
    }
    final processId = int.tryParse(match[1]!);
    if (processId == null || processId < 1) {
      throw const FormatException('restore_harness_process_table_pid');
    }
    snapshots.add(
      _RunnerProcessSnapshot(
        pid: processId,
        startedAt: match[2]!,
        command: match[3]!,
      ),
    );
  }
  return snapshots;
}

final class _RunnerProcessSnapshot {
  const _RunnerProcessSnapshot({
    required this.pid,
    required this.startedAt,
    required this.command,
  });

  final int pid;
  final String startedAt;
  final String command;

  _RunnerIdentity get identity => _RunnerIdentity(pid, startedAt);

  bool matchesExecutable(String expectedPath) {
    final actual = command.toLowerCase();
    final expected = expectedPath.toLowerCase();
    return actual == expected || actual.startsWith('$expected ');
  }
}

final class _RunnerIdentity {
  const _RunnerIdentity(this.pid, this.startedAt);

  final int pid;
  final String startedAt;

  @override
  bool operator ==(Object other) =>
      other is _RunnerIdentity &&
      other.pid == pid &&
      other.startedAt == startedAt;

  @override
  int get hashCode => Object.hash(pid, startedAt);
}
