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

enum _MatrixTier {
  smoke,
  core,
  full;

  List<RestoreProcessFailpoint> get failpoints => switch (this) {
    smoke => restoreProcessSmokeFailpoints,
    core => restoreProcessCoreFailpoints,
    full => restoreProcessFullFailpoints,
  };

  static _MatrixTier parse(List<String> arguments) {
    return switch (arguments.single) {
      '--tier=smoke' => _MatrixTier.smoke,
      '--tier=core' => _MatrixTier.core,
      '--tier=full' => _MatrixTier.full,
      _ => throw ArgumentError.value(
        arguments.single,
        'tier',
        'expected --tier=smoke|core|full',
      ),
    };
  }
}

final class _MatrixSelection {
  const _MatrixSelection({
    required this.tier,
    this.singleFailpoint,
    this.startAt,
  });

  final _MatrixTier tier;
  final RestoreProcessFailpoint? singleFailpoint;
  final RestoreProcessFailpoint? startAt;

  List<RestoreProcessFailpoint> get failpoints {
    if (singleFailpoint != null) return [singleFailpoint!];
    final all = tier.failpoints;
    if (startAt == null) return all;
    final index = all.indexOf(startAt!);
    if (index < 0) {
      throw StateError(
        'restore_harness_matrix_start_not_in_tier:${startAt!.name}',
      );
    }
    return List.unmodifiable(all.sublist(index));
  }

  String get label => singleFailpoint != null
      ? 'failpoint=${singleFailpoint!.name}'
      : startAt == null
      ? tier.name
      : '${tier.name}-from=${startAt!.name}';

  static _MatrixSelection parse(List<String> arguments) {
    if (arguments.isEmpty) {
      return const _MatrixSelection(tier: _MatrixTier.core);
    }
    if (arguments.length == 1 && arguments.single.startsWith('--failpoint=')) {
      return _MatrixSelection(
        tier: _MatrixTier.full,
        singleFailpoint: _parseFailpoint(
          arguments.single.substring('--failpoint='.length),
        ),
      );
    }
    if (arguments.length > 2 || arguments.toSet().length != arguments.length) {
      throw ArgumentError(
        'run_restore_process_harness accepts '
        '[--tier=smoke|core|full] [--from=<name>] '
        'or --failpoint=<name>',
      );
    }
    _MatrixTier? tier;
    RestoreProcessFailpoint? startAt;
    for (final argument in arguments) {
      if (argument.startsWith('--tier=')) {
        if (tier != null) throw ArgumentError('duplicate tier');
        tier = _MatrixTier.parse([argument]);
      } else if (argument.startsWith('--from=')) {
        if (startAt != null) throw ArgumentError('duplicate from');
        startAt = _parseFailpoint(argument.substring('--from='.length));
      } else {
        throw ArgumentError.value(argument, 'argument');
      }
    }
    return _MatrixSelection(tier: tier ?? _MatrixTier.core, startAt: startAt);
  }

  static RestoreProcessFailpoint _parseFailpoint(String name) {
    return RestoreProcessFailpoint.values.firstWhere(
      (candidate) => candidate.name == name,
      orElse: () => throw ArgumentError.value(
        name,
        'failpoint',
        'unknown restore process failpoint',
      ),
    );
  }
}

final class _MatrixCaseSummary {
  const _MatrixCaseSummary({
    required this.failpoint,
    required this.scenarioId,
    required this.runnerProcessIds,
    required this.elapsed,
    required this.passed,
  });

  final RestoreProcessFailpoint failpoint;
  final String scenarioId;
  final List<int> runnerProcessIds;
  final Duration elapsed;
  final bool passed;
}

Future<void> main(List<String> arguments) async {
  _RestoreProcessHarnessHost? host;
  try {
    final selection = _MatrixSelection.parse(arguments);
    host = await _RestoreProcessHarnessHost.create(selection);
    await host.run();
  } catch (error, stackTrace) {
    stderr.writeln('Restore process harness failed: $error');
    stderr.writeln(stackTrace);
    if (host != null) {
      final cleanupErrors = await host.cleanOrphanProcesses();
      for (final cleanupError in cleanupErrors) {
        stderr.writeln('Cleanup failure: $cleanupError');
      }
      final retainedScenario = host.activeScenarioRoot;
      if (retainedScenario != null) {
        stderr.writeln(
          'Scenario retained for diagnosis: ${retainedScenario.path}',
        );
      }
      host.writeMatrixSummary(stderr);
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
    required this.restoreHarnessExecutablePath,
    required this.selection,
    required this.matrixRunId,
    required this._hostLock,
  });

  static Future<_RestoreProcessHarnessHost> create(
    _MatrixSelection selection,
  ) async {
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
        restoreHarnessExecutablePath: restoreHarnessExecutablePath,
        selection: selection,
        matrixRunId: _newIdentifier(),
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
  final String restoreHarnessExecutablePath;
  final _MatrixSelection selection;
  final String matrixRunId;
  RandomAccessFile? _hostLock;
  final List<_ManagedProcess> _processes = [];
  final Set<_RunnerIdentity> _activeRunnerIdentities = {};
  final Set<int> _observedRunnerProcessIds = {};
  final List<_MatrixCaseSummary> _caseSummaries = [];
  final Stopwatch _matrixStopwatch = Stopwatch();
  String? _scenarioId;
  Directory? _scenarioRoot;
  RestoreProcessFailpoint? _failpoint;
  Stopwatch? _caseStopwatch;

  String get scenarioId =>
      _scenarioId ?? (throw StateError('restore_harness_case_scenario'));
  Directory get scenarioRoot =>
      _scenarioRoot ?? (throw StateError('restore_harness_case_root'));
  RestoreProcessFailpoint get failpoint =>
      _failpoint ?? (throw StateError('restore_harness_case_failpoint'));
  Directory? get activeScenarioRoot => _scenarioRoot;
  String get _preferencesPrefix => restoreProcessPreferencesPrefix(
    matrixRunId: matrixRunId,
    scenarioId: scenarioId,
    failpoint: failpoint,
  );

  Future<void> releaseHostLock() async {
    final hostLock = _hostLock;
    if (hostLock == null) return;
    _hostLock = null;
    await _releaseHostLockHandle(hostLock);
  }

  Future<void> _beginCase(RestoreProcessFailpoint selectedFailpoint) async {
    if (_scenarioId != null ||
        _scenarioRoot != null ||
        _failpoint != null ||
        _processes.isNotEmpty ||
        _activeRunnerIdentities.isNotEmpty ||
        _observedRunnerProcessIds.isNotEmpty ||
        _caseStopwatch != null) {
      throw StateError('restore_harness_case_state_not_clear');
    }
    final nextScenarioId = _newIdentifier();
    final candidate = Directory(
      p.join(
        containerTemporaryDirectory.path,
        'kelivo_restore_process_$nextScenarioId',
      ),
    );
    if (await FileSystemEntity.type(candidate.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('restore_harness_scenario_collision');
    }
    await candidate.create();
    _scenarioId = nextScenarioId;
    _scenarioRoot = candidate;
    _failpoint = selectedFailpoint;
    final canonical = Directory(
      p.normalize(p.absolute(await candidate.resolveSymbolicLinks())),
    );
    if (!p.equals(canonical.path, candidate.path) ||
        !p.isWithin(containerTemporaryDirectory.path, canonical.path) ||
        p.basename(canonical.path) !=
            'kelivo_restore_process_$nextScenarioId') {
      throw StateError('restore_harness_scenario_boundary');
    }
    _scenarioRoot = canonical;
  }

  void _clearSuccessfulCase() {
    if (_scenarioRoot == null ||
        _processes.any((process) => !process.hasExited) ||
        _activeRunnerIdentities.isNotEmpty) {
      throw StateError('restore_harness_case_cleanup_incomplete');
    }
    _processes.clear();
    _observedRunnerProcessIds.clear();
    _scenarioId = null;
    _scenarioRoot = null;
    _failpoint = null;
    _caseStopwatch = null;
  }

  void writeMatrixSummary(IOSink sink) {
    sink.writeln(
      'Restore process matrix summary: selection=${selection.label} '
      'matrixRunId=$matrixRunId cases=${_caseSummaries.length}/'
      '${selection.failpoints.length} elapsed='
      '${_formatDuration(_matrixStopwatch.elapsed)}',
    );
    for (final summary in _caseSummaries) {
      sink.writeln(
        '${summary.passed ? 'PASS' : 'FAIL'} '
        '${summary.failpoint.name} scenario=${summary.scenarioId} '
        'elapsed=${_formatDuration(summary.elapsed)} '
        'runnerPids=${summary.runnerProcessIds.join(',')}',
      );
    }
  }

  Future<void> run() async {
    final failpoints = selection.failpoints;
    if (failpoints.isEmpty || failpoints.toSet().length != failpoints.length) {
      throw StateError('restore_harness_matrix_failpoints');
    }
    stdout.writeln(
      'Restore process matrix ${selection.label}: $matrixRunId '
      '(${failpoints.length} cases)',
    );
    _matrixStopwatch.start();
    try {
      for (var index = 0; index < failpoints.length; index++) {
        final selectedFailpoint = failpoints[index];
        await _beginCase(selectedFailpoint);
        stdout.writeln(
          '[${index + 1}/${failpoints.length}] ${selectedFailpoint.name}: '
          '${scenarioRoot.path}',
        );
        _caseStopwatch = Stopwatch()..start();
        try {
          await _runCasePhases();
          final cleanupErrors = await cleanOrphanProcesses();
          if (cleanupErrors.isNotEmpty) {
            throw StateError(
              'restore_harness_process_cleanup:${cleanupErrors.join('|')}',
            );
          }
          await _deleteSuccessfulScenario();
          _caseStopwatch!.stop();
          final runnerProcessIds = _currentCaseRunnerProcessIds();
          _caseSummaries.add(
            _MatrixCaseSummary(
              failpoint: selectedFailpoint,
              scenarioId: scenarioId,
              runnerProcessIds: runnerProcessIds,
              elapsed: _caseStopwatch!.elapsed,
              passed: true,
            ),
          );
          stdout.writeln(
            '${selectedFailpoint.name} passed in '
            '${_formatDuration(_caseStopwatch!.elapsed)}; Runner PIDs: '
            '${runnerProcessIds.join(', ')}',
          );
          _clearSuccessfulCase();
        } catch (error, stackTrace) {
          _caseStopwatch!.stop();
          _caseSummaries.add(
            _MatrixCaseSummary(
              failpoint: selectedFailpoint,
              scenarioId: scenarioId,
              runnerProcessIds: _currentCaseRunnerProcessIds(),
              elapsed: _caseStopwatch!.elapsed,
              passed: false,
            ),
          );
          Error.throwWithStackTrace(error, stackTrace);
        }
      }
    } finally {
      _matrixStopwatch.stop();
    }
    writeMatrixSummary(stdout);
  }

  List<int> _currentCaseRunnerProcessIds() {
    final processIds = <int>{
      ..._observedRunnerProcessIds,
      for (final process in _processes)
        if (process.runnerProcessId != null) process.runnerProcessId!,
    };
    return List.unmodifiable(processIds);
  }

  Future<void> _runCasePhases() async {
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
  }

  Future<_HarnessEvent> _runNormalPhase(
    RestoreProcessHarnessPhase phase,
    _EventValidator validate,
  ) async {
    final control = await _writeControl(phase);
    final process = await _startFlutter(control);
    final event = await _waitForEvent(control, process);
    final runner = await _recordRunnerProcess(event, process);
    validate(event, control, process);

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
    final runner = await _recordRunnerProcess(event, process);
    _validateCutoverEvent(event, control, process, runId: runId);

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
      matrixRunId: matrixRunId,
      scenarioId: scenarioId,
      phase: phase,
      failpoint: failpoint,
      scenarioRoot: scenarioRoot.path,
      preferencesPrefix: _preferencesPrefix,
    );
    final controlFile = _controlFile(control);
    await writeDurableHarnessJson(controlFile, control.toJson());
    final persisted = RestoreProcessHarnessControl.fromJson(
      await readHarnessJson(controlFile),
    );
    if (persisted.generation != control.generation ||
        persisted.matrixRunId != control.matrixRunId ||
        persisted.scenarioId != control.scenarioId ||
        persisted.phase != control.phase ||
        persisted.failpoint != control.failpoint ||
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
        await _observePhaseRunner(process);
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
          await _observePhaseRunner(process);
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
    final observationKeys = switch (control.failpoint) {
      RestoreProcessFailpoint.cutoverClaimPublished ||
      RestoreProcessFailpoint.previousSettingsPublished ||
      RestoreProcessFailpoint.previousManifestPublished ||
      RestoreProcessFailpoint.previousUploadMoved ||
      RestoreProcessFailpoint.previousImagesMoved ||
      RestoreProcessFailpoint.previousAvatarsMoved ||
      RestoreProcessFailpoint.previousFontsMoved ||
      RestoreProcessFailpoint.previousDatabaseMoved ||
      RestoreProcessFailpoint.previousPromoted ||
      RestoreProcessFailpoint.candidateDatabaseMoved ||
      RestoreProcessFailpoint.candidateUploadMoved ||
      RestoreProcessFailpoint.candidateImagesMoved ||
      RestoreProcessFailpoint.candidateAvatarsMoved ||
      RestoreProcessFailpoint.candidateFontsMoved => const {
        'operationKind',
        'sourcePath',
        'targetPath',
        'sourceKind',
      },
      RestoreProcessFailpoint.liveDatabaseNormalized => const {
        'operationKind',
        'path',
        'fullBarrier',
      },
      RestoreProcessFailpoint.oldRenamedReceiptTempDurable ||
      RestoreProcessFailpoint.oldRenamedReceiptPublished ||
      RestoreProcessFailpoint.newInstalledReceiptTempDurable ||
      RestoreProcessFailpoint.newInstalledReceiptPublished ||
      RestoreProcessFailpoint.verifiedReceiptTempDurable ||
      RestoreProcessFailpoint.verifiedReceiptPublished ||
      RestoreProcessFailpoint.committedReceiptTempDurable ||
      RestoreProcessFailpoint.committedReceiptPublished => const {
        'operationKind',
        'receiptSequence',
        'receiptState',
        'temporaryPath',
        'targetPath',
      },
      RestoreProcessFailpoint.settingsSecretRemoved ||
      RestoreProcessFailpoint.settingsFirstSet => const {
        'operationKind',
        'preferenceKey',
        'valueType',
      },
    };
    event.requireCommon(
      control,
      process,
      expectedStatus: 'readyForKill',
      phaseSpecificKeys: {
        'marker',
        'runId',
        'leaseInstanceId',
        'observedReceiptState',
        ...observationKeys,
      },
    );
    event.requireExactString('marker', control.failpoint.name);
    event.requireExactString('runId', runId);
    event.requireIdentifier('leaseInstanceId');
    event.requireExactString(
      'observedReceiptState',
      _expectedObservedReceiptState(control.failpoint),
    );
    _validateCutoverObservation(event, control, runId: runId);
  }

  String _expectedObservedReceiptState(RestoreProcessFailpoint failpoint) {
    return switch (failpoint) {
      RestoreProcessFailpoint.cutoverClaimPublished ||
      RestoreProcessFailpoint.liveDatabaseNormalized ||
      RestoreProcessFailpoint.previousSettingsPublished ||
      RestoreProcessFailpoint.previousManifestPublished ||
      RestoreProcessFailpoint.previousUploadMoved ||
      RestoreProcessFailpoint.previousImagesMoved ||
      RestoreProcessFailpoint.previousAvatarsMoved ||
      RestoreProcessFailpoint.previousFontsMoved ||
      RestoreProcessFailpoint.previousDatabaseMoved ||
      RestoreProcessFailpoint.previousPromoted ||
      RestoreProcessFailpoint.oldRenamedReceiptTempDurable => 'prepared',
      RestoreProcessFailpoint.oldRenamedReceiptPublished ||
      RestoreProcessFailpoint.settingsSecretRemoved ||
      RestoreProcessFailpoint.settingsFirstSet ||
      RestoreProcessFailpoint.candidateDatabaseMoved ||
      RestoreProcessFailpoint.candidateUploadMoved ||
      RestoreProcessFailpoint.candidateImagesMoved ||
      RestoreProcessFailpoint.candidateAvatarsMoved ||
      RestoreProcessFailpoint.candidateFontsMoved ||
      RestoreProcessFailpoint.newInstalledReceiptTempDurable => 'oldRenamed',
      RestoreProcessFailpoint.newInstalledReceiptPublished ||
      RestoreProcessFailpoint.verifiedReceiptTempDurable => 'newInstalled',
      RestoreProcessFailpoint.verifiedReceiptPublished ||
      RestoreProcessFailpoint.committedReceiptTempDurable => 'verified',
      RestoreProcessFailpoint.committedReceiptPublished => 'committed',
    };
  }

  void _validateCutoverObservation(
    _HarnessEvent event,
    RestoreProcessHarnessControl control, {
    required String runId,
  }) {
    final appData = p.normalize(p.absolute(control.appDataDirectory.path));
    final workspace = p.join(appData, '.kelivo_restore');
    final runDirectory = p.join(workspace, 'run_$runId');
    final previousPending = p.join(runDirectory, 'previous.pending');
    final previous = p.join(runDirectory, 'previous');
    final candidate = p.join(runDirectory, 'candidate');
    final receipts = p.join(runDirectory, 'receipts');

    switch (control.failpoint) {
      case RestoreProcessFailpoint.cutoverClaimPublished:
        event.requireRenameObservation(
          sourcePath: p.join(workspace, '.active_run'),
          targetPath: p.join(workspace, '.active_run.publishing'),
          sourceKind: 'file',
        );
      case RestoreProcessFailpoint.liveDatabaseNormalized:
        event.requireSyncObservation(
          operationKind: 'directorySyncAfter',
          path: appData,
          fullBarrier: true,
        );
      case RestoreProcessFailpoint.previousSettingsPublished:
        event.requireRenameObservation(
          sourcePath: p.join(previousPending, 'settings.json.tmp'),
          targetPath: p.join(previousPending, 'settings.json'),
          sourceKind: 'file',
        );
      case RestoreProcessFailpoint.previousManifestPublished:
        event.requireRenameObservation(
          sourcePath: p.join(previousPending, 'manifest.json.tmp'),
          targetPath: p.join(previousPending, 'manifest.json'),
          sourceKind: 'file',
        );
      case RestoreProcessFailpoint.previousUploadMoved:
        event.requireRenameObservation(
          sourcePath: p.join(appData, 'upload'),
          targetPath: p.join(previousPending, 'upload'),
          sourceKind: 'directory',
        );
      case RestoreProcessFailpoint.previousImagesMoved:
        event.requireRenameObservation(
          sourcePath: p.join(appData, 'images'),
          targetPath: p.join(previousPending, 'images'),
          sourceKind: 'directory',
        );
      case RestoreProcessFailpoint.previousAvatarsMoved:
        event.requireRenameObservation(
          sourcePath: p.join(appData, 'avatars'),
          targetPath: p.join(previousPending, 'avatars'),
          sourceKind: 'directory',
        );
      case RestoreProcessFailpoint.previousFontsMoved:
        event.requireRenameObservation(
          sourcePath: p.join(appData, 'fonts'),
          targetPath: p.join(previousPending, 'fonts'),
          sourceKind: 'directory',
        );
      case RestoreProcessFailpoint.previousDatabaseMoved:
        event.requireRenameObservation(
          sourcePath: p.join(appData, 'kelivo.sqlite'),
          targetPath: p.join(previousPending, 'database', 'kelivo.sqlite'),
          sourceKind: 'file',
        );
      case RestoreProcessFailpoint.previousPromoted:
        event.requireRenameObservation(
          sourcePath: previousPending,
          targetPath: previous,
          sourceKind: 'directory',
        );
      case RestoreProcessFailpoint.oldRenamedReceiptTempDurable:
        event.requireReceiptObservation(
          receiptDirectory: receipts,
          sequence: 2,
          state: 'oldRenamed',
          published: false,
        );
      case RestoreProcessFailpoint.oldRenamedReceiptPublished:
        event.requireReceiptObservation(
          receiptDirectory: receipts,
          sequence: 2,
          state: 'oldRenamed',
          published: true,
        );
      case RestoreProcessFailpoint.settingsSecretRemoved:
        event.requirePreferenceObservation(
          operationKind: 'preferenceRemoveAfter',
          preferenceKey: 'restore_harness_${control.scenarioId}_secret_api_key',
          valueType: '',
        );
      case RestoreProcessFailpoint.settingsFirstSet:
        event.requirePreferenceObservation(
          operationKind: 'preferenceSetAfter',
          preferenceKey: 'restore_harness_${control.scenarioId}_primary',
          valueType: 'String',
        );
      case RestoreProcessFailpoint.candidateDatabaseMoved:
        event.requireRenameObservation(
          sourcePath: p.join(candidate, 'database', 'kelivo.sqlite'),
          targetPath: p.join(appData, 'kelivo.sqlite'),
          sourceKind: 'file',
        );
      case RestoreProcessFailpoint.candidateUploadMoved:
        event.requireRenameObservation(
          sourcePath: p.join(candidate, 'upload'),
          targetPath: p.join(appData, 'upload'),
          sourceKind: 'directory',
        );
      case RestoreProcessFailpoint.candidateImagesMoved:
        event.requireRenameObservation(
          sourcePath: p.join(candidate, 'images'),
          targetPath: p.join(appData, 'images'),
          sourceKind: 'directory',
        );
      case RestoreProcessFailpoint.candidateAvatarsMoved:
        event.requireRenameObservation(
          sourcePath: p.join(candidate, 'avatars'),
          targetPath: p.join(appData, 'avatars'),
          sourceKind: 'directory',
        );
      case RestoreProcessFailpoint.candidateFontsMoved:
        event.requireRenameObservation(
          sourcePath: p.join(candidate, 'fonts'),
          targetPath: p.join(appData, 'fonts'),
          sourceKind: 'directory',
        );
      case RestoreProcessFailpoint.newInstalledReceiptTempDurable:
        event.requireReceiptObservation(
          receiptDirectory: receipts,
          sequence: 3,
          state: 'newInstalled',
          published: false,
        );
      case RestoreProcessFailpoint.newInstalledReceiptPublished:
        event.requireReceiptObservation(
          receiptDirectory: receipts,
          sequence: 3,
          state: 'newInstalled',
          published: true,
        );
      case RestoreProcessFailpoint.verifiedReceiptTempDurable:
        event.requireReceiptObservation(
          receiptDirectory: receipts,
          sequence: 4,
          state: 'verified',
          published: false,
        );
      case RestoreProcessFailpoint.verifiedReceiptPublished:
        event.requireReceiptObservation(
          receiptDirectory: receipts,
          sequence: 4,
          state: 'verified',
          published: true,
        );
      case RestoreProcessFailpoint.committedReceiptTempDurable:
        event.requireReceiptObservation(
          receiptDirectory: receipts,
          sequence: 5,
          state: 'committed',
          published: false,
        );
      case RestoreProcessFailpoint.committedReceiptPublished:
        event.requireReceiptObservation(
          receiptDirectory: receipts,
          sequence: 5,
          state: 'committed',
          published: true,
        );
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
    if (_scenarioRoot != null && _failpoint != null) {
      sink.writeln(
        'Active matrix case: ${_failpoint!.name} '
        'scenario=$scenarioId root=${scenarioRoot.path}',
      );
    }
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
    'matrixRunId',
    'scenario',
    'scenarioId',
    'phase',
    'failpoint',
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
        json['matrixRunId'] != control.matrixRunId ||
        json['scenario'] != restoreHarnessScenario ||
        json['scenarioId'] != control.scenarioId ||
        json['phase'] != control.phase.name ||
        json['failpoint'] != control.failpoint.name ||
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

  bool requireBool(String key) {
    final value = json[key];
    if (value is! bool) {
      throw FormatException('restore_harness_event_bool:$key');
    }
    return value;
  }

  String requirePath(String key, {String? expected}) {
    final value = requireString(key);
    if (!p.isAbsolute(value) || p.normalize(p.absolute(value)) != value) {
      throw FormatException('restore_harness_event_path:$key');
    }
    if (expected != null && !p.equals(value, expected)) {
      throw FormatException('restore_harness_event_path_value:$key');
    }
    return value;
  }

  void requireRenameObservation({
    required String sourcePath,
    required String targetPath,
    required String sourceKind,
  }) {
    requireExactString('operationKind', 'renameAfter');
    requirePath('sourcePath', expected: sourcePath);
    requirePath('targetPath', expected: targetPath);
    requireExactString('sourceKind', sourceKind);
  }

  void requireSyncObservation({
    required String operationKind,
    required String path,
    required bool fullBarrier,
  }) {
    requireExactString('operationKind', operationKind);
    requirePath('path', expected: path);
    if (requireBool('fullBarrier') != fullBarrier) {
      throw const FormatException('restore_harness_event_full_barrier');
    }
  }

  void requireReceiptObservation({
    required String receiptDirectory,
    required int sequence,
    required String state,
    required bool published,
  }) {
    requireExactString(
      'operationKind',
      published ? 'receiptPublished' : 'receiptTempDurable',
    );
    if (requireInt('receiptSequence') != sequence) {
      throw const FormatException('restore_harness_event_receipt_sequence');
    }
    requireExactString('receiptState', state);
    final receiptName = 'receipt_${sequence.toString().padLeft(16, '0')}.json';
    requirePath('targetPath', expected: p.join(receiptDirectory, receiptName));
    final temporaryPath = requirePath('temporaryPath');
    final temporaryName = p.basename(temporaryPath);
    final temporaryPattern = RegExp(
      '^${RegExp.escape(receiptName)}\\.([1-9][0-9]*)_$pid\\.tmp\$',
    );
    if (!p.equals(p.dirname(temporaryPath), receiptDirectory) ||
        temporaryPattern.firstMatch(temporaryName) == null) {
      throw const FormatException('restore_harness_event_receipt_temporary');
    }
  }

  void requirePreferenceObservation({
    required String operationKind,
    required String preferenceKey,
    required String valueType,
  }) {
    requireExactString('operationKind', operationKind);
    requireExactString('preferenceKey', preferenceKey);
    final actualValueType = json['valueType'];
    if (actualValueType is! String || actualValueType != valueType) {
      throw const FormatException('restore_harness_event_value_type');
    }
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

String _newIdentifier() {
  final random = Random.secure();
  return List<int>.generate(
    16,
    (_) => random.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

String _formatDuration(Duration duration) =>
    '${(duration.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(3)}s';

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
