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
final _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');
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

enum _MatrixScenario { forward, terminal, rollback, rolledBackTerminal }

final class _MatrixFailpoint {
  const _MatrixFailpoint.forward(RestoreProcessFailpoint value)
    : forward = value,
      terminal = null,
      rollback = null,
      scenario = _MatrixScenario.forward;

  const _MatrixFailpoint.terminal(RestoreTerminalProcessFailpoint value)
    : forward = null,
      terminal = value,
      rollback = null,
      scenario = _MatrixScenario.terminal;

  const _MatrixFailpoint.rollback(RestoreRollbackProcessFailpoint value)
    : forward = null,
      terminal = null,
      rollback = value,
      scenario = _MatrixScenario.rollback;

  const _MatrixFailpoint.rolledBackTerminal(
    RestoreTerminalProcessFailpoint value,
  ) : forward = null,
      terminal = value,
      rollback = null,
      scenario = _MatrixScenario.rolledBackTerminal;

  final _MatrixScenario scenario;
  final RestoreProcessFailpoint? forward;
  final RestoreTerminalProcessFailpoint? terminal;
  final RestoreRollbackProcessFailpoint? rollback;

  String get name => switch (scenario) {
    _MatrixScenario.forward => forward!.name,
    _MatrixScenario.terminal => terminal!.name,
    _MatrixScenario.rollback => rollback!.name,
    _MatrixScenario.rolledBackTerminal => terminal!.name,
  };

  String get scenarioName => switch (scenario) {
    _MatrixScenario.forward => restoreHarnessScenario,
    _MatrixScenario.terminal => restoreTerminalHarnessScenario,
    _MatrixScenario.rollback => restoreRollbackHarnessScenario,
    _MatrixScenario.rolledBackTerminal =>
      restoreRolledBackTerminalHarnessScenario,
  };
}

final class _MatrixSelection {
  const _MatrixSelection.forward({
    required this.tier,
    this.singleFailpoint,
    this.forwardStartAt,
  }) : scenario = _MatrixScenario.forward,
       rollbackStartAt = null,
       rolledBackTerminalStartAt = null;

  const _MatrixSelection.terminal({this.singleFailpoint})
    : scenario = _MatrixScenario.terminal,
      tier = _MatrixTier.full,
      forwardStartAt = null,
      rollbackStartAt = null,
      rolledBackTerminalStartAt = null;

  const _MatrixSelection.rollback({this.singleFailpoint, this.rollbackStartAt})
    : scenario = _MatrixScenario.rollback,
      tier = _MatrixTier.full,
      forwardStartAt = null,
      rolledBackTerminalStartAt = null;

  const _MatrixSelection.rolledBackTerminal({
    this.singleFailpoint,
    this.rolledBackTerminalStartAt,
  }) : scenario = _MatrixScenario.rolledBackTerminal,
       tier = _MatrixTier.full,
       forwardStartAt = null,
       rollbackStartAt = null;

  final _MatrixScenario scenario;
  final _MatrixTier tier;
  final _MatrixFailpoint? singleFailpoint;
  final RestoreProcessFailpoint? forwardStartAt;
  final RestoreRollbackProcessFailpoint? rollbackStartAt;
  final RestoreTerminalProcessFailpoint? rolledBackTerminalStartAt;

  List<_MatrixFailpoint> get failpoints {
    if (singleFailpoint != null) return [singleFailpoint!];
    switch (scenario) {
      case _MatrixScenario.terminal:
        return [
          for (final failpoint in RestoreTerminalProcessFailpoint.values)
            _MatrixFailpoint.terminal(failpoint),
        ];
      case _MatrixScenario.rollback:
        final all = RestoreRollbackProcessFailpoint.values;
        final start = rollbackStartAt;
        final index = start == null ? 0 : all.indexOf(start);
        if (index < 0) {
          throw StateError(
            'restore_rollback_harness_matrix_start:${start!.name}',
          );
        }
        return List.unmodifiable([
          for (final failpoint in all.sublist(index))
            _MatrixFailpoint.rollback(failpoint),
        ]);
      case _MatrixScenario.rolledBackTerminal:
        final all = RestoreTerminalProcessFailpoint.values;
        final start = rolledBackTerminalStartAt;
        final index = start == null ? 0 : all.indexOf(start);
        if (index < 0) {
          throw StateError(
            'restore_rolled_back_terminal_harness_matrix_start:'
            '${start!.name}',
          );
        }
        return List.unmodifiable([
          for (final failpoint in all.sublist(index))
            _MatrixFailpoint.rolledBackTerminal(failpoint),
        ]);
      case _MatrixScenario.forward:
        break;
    }
    final all = tier.failpoints;
    if (forwardStartAt == null) {
      return [for (final failpoint in all) _MatrixFailpoint.forward(failpoint)];
    }
    final index = all.indexOf(forwardStartAt!);
    if (index < 0) {
      throw StateError(
        'restore_harness_matrix_start_not_in_tier:${forwardStartAt!.name}',
      );
    }
    return List.unmodifiable([
      for (final failpoint in all.sublist(index))
        _MatrixFailpoint.forward(failpoint),
    ]);
  }

  String get label => singleFailpoint != null
      ? 'failpoint=${singleFailpoint!.name}'
      : scenario == _MatrixScenario.terminal
      ? 'terminal'
      : scenario == _MatrixScenario.rollback
      ? rollbackStartAt == null
            ? 'rollback'
            : 'rollback-from=${rollbackStartAt!.name}'
      : scenario == _MatrixScenario.rolledBackTerminal
      ? rolledBackTerminalStartAt == null
            ? 'rolledback-terminal'
            : 'rolledback-terminal-from='
                  '${rolledBackTerminalStartAt!.name}'
      : forwardStartAt == null
      ? tier.name
      : '${tier.name}-from=${forwardStartAt!.name}';

  String get scenarioName => switch (scenario) {
    _MatrixScenario.forward => restoreHarnessScenario,
    _MatrixScenario.terminal => restoreTerminalHarnessScenario,
    _MatrixScenario.rollback => restoreRollbackHarnessScenario,
    _MatrixScenario.rolledBackTerminal =>
      restoreRolledBackTerminalHarnessScenario,
  };

  static _MatrixSelection parse(List<String> arguments) {
    if (arguments.isEmpty) {
      return const _MatrixSelection.forward(tier: _MatrixTier.core);
    }
    if (arguments.length == 1 && arguments.single == '--scenario=terminal') {
      return const _MatrixSelection.terminal();
    }
    if (arguments.length == 1 && arguments.single == '--scenario=rollback') {
      return const _MatrixSelection.rollback();
    }
    if (arguments.length == 1 &&
        arguments.single == '--scenario=rolledback-terminal') {
      return const _MatrixSelection.rolledBackTerminal();
    }
    if (arguments.length == 2 && arguments.contains('--scenario=rollback')) {
      final fromArguments = arguments
          .where((argument) => argument.startsWith('--from='))
          .toList(growable: false);
      if (fromArguments.length != 1) {
        throw ArgumentError(
          'rollback scenario accepts exactly one --from=<name>',
        );
      }
      return _MatrixSelection.rollback(
        rollbackStartAt: _parseRollbackFailpoint(
          fromArguments.single.substring('--from='.length),
        ),
      );
    }
    if (arguments.length == 2 &&
        arguments.contains('--scenario=rolledback-terminal')) {
      final options = arguments
          .where((argument) => argument != '--scenario=rolledback-terminal')
          .toList(growable: false);
      if (options.length != 1) {
        throw ArgumentError(
          'rolledback-terminal scenario accepts one --failpoint or --from',
        );
      }
      final option = options.single;
      if (option.startsWith('--failpoint=')) {
        return _MatrixSelection.rolledBackTerminal(
          singleFailpoint: _MatrixFailpoint.rolledBackTerminal(
            _parseTerminalFailpoint(option.substring('--failpoint='.length)),
          ),
        );
      }
      if (option.startsWith('--from=')) {
        return _MatrixSelection.rolledBackTerminal(
          rolledBackTerminalStartAt: _parseTerminalFailpoint(
            option.substring('--from='.length),
          ),
        );
      }
      throw ArgumentError.value(option, 'argument');
    }
    if (arguments.length == 1 && arguments.single.startsWith('--failpoint=')) {
      final name = arguments.single.substring('--failpoint='.length);
      final forward = _tryParseForwardFailpoint(name);
      final terminal = _tryParseTerminalFailpoint(name);
      final rollback = _tryParseRollbackFailpoint(name);
      final matches = <_MatrixFailpoint>[
        if (forward != null) _MatrixFailpoint.forward(forward),
        if (terminal != null) _MatrixFailpoint.terminal(terminal),
        if (rollback != null) _MatrixFailpoint.rollback(rollback),
      ];
      if (matches.length != 1) {
        throw ArgumentError.value(
          name,
          'failpoint',
          'unknown or ambiguous restore process failpoint',
        );
      }
      return switch (matches.single.scenario) {
        _MatrixScenario.forward => _MatrixSelection.forward(
          tier: _MatrixTier.full,
          singleFailpoint: matches.single,
        ),
        _MatrixScenario.terminal => _MatrixSelection.terminal(
          singleFailpoint: matches.single,
        ),
        _MatrixScenario.rollback => _MatrixSelection.rollback(
          singleFailpoint: matches.single,
        ),
        _MatrixScenario.rolledBackTerminal => throw StateError(
          'restore_harness_global_failpoint_scenario',
        ),
      };
    }
    if (arguments.length > 2 || arguments.toSet().length != arguments.length) {
      throw ArgumentError(
        'run_restore_process_harness accepts '
        '[--tier=smoke|core|full] [--from=<name>] '
        'or --scenario=terminal '
        'or --scenario=rollback [--from=<rollback-name>] '
        'or --scenario=rolledback-terminal '
        '[--failpoint=<terminal-name>|--from=<terminal-name>] '
        'or --failpoint=<unique-name>',
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
        startAt = _parseForwardFailpoint(argument.substring('--from='.length));
      } else {
        throw ArgumentError.value(argument, 'argument');
      }
    }
    return _MatrixSelection.forward(
      tier: tier ?? _MatrixTier.core,
      forwardStartAt: startAt,
    );
  }

  static RestoreProcessFailpoint _parseForwardFailpoint(String name) {
    final failpoint = _tryParseForwardFailpoint(name);
    if (failpoint == null) {
      throw ArgumentError.value(
        name,
        'failpoint',
        'unknown forward restore process failpoint',
      );
    }
    return failpoint;
  }

  static RestoreProcessFailpoint? _tryParseForwardFailpoint(String name) {
    for (final candidate in RestoreProcessFailpoint.values) {
      if (candidate.name == name) return candidate;
    }
    return null;
  }

  static RestoreTerminalProcessFailpoint? _tryParseTerminalFailpoint(
    String name,
  ) {
    for (final candidate in RestoreTerminalProcessFailpoint.values) {
      if (candidate.name == name) return candidate;
    }
    return null;
  }

  static RestoreTerminalProcessFailpoint _parseTerminalFailpoint(String name) {
    final failpoint = _tryParseTerminalFailpoint(name);
    if (failpoint == null) {
      throw ArgumentError.value(
        name,
        'failpoint',
        'unknown terminal restore process failpoint',
      );
    }
    return failpoint;
  }

  static RestoreRollbackProcessFailpoint _parseRollbackFailpoint(String name) {
    final failpoint = _tryParseRollbackFailpoint(name);
    if (failpoint == null) {
      throw ArgumentError.value(
        name,
        'failpoint',
        'unknown rollback restore process failpoint',
      );
    }
    return failpoint;
  }

  static RestoreRollbackProcessFailpoint? _tryParseRollbackFailpoint(
    String name,
  ) {
    for (final candidate in RestoreRollbackProcessFailpoint.values) {
      if (candidate.name == name) return candidate;
    }
    return null;
  }
}

final class _MatrixCaseSummary {
  const _MatrixCaseSummary({
    required this.scenario,
    required this.failpointName,
    required this.scenarioId,
    required this.runnerProcessIds,
    required this.elapsed,
    required this.passed,
  });

  final String scenario;
  final String failpointName;
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
  _MatrixFailpoint? _failpoint;
  Stopwatch? _caseStopwatch;

  String get scenarioId =>
      _scenarioId ?? (throw StateError('restore_harness_case_scenario'));
  Directory get scenarioRoot =>
      _scenarioRoot ?? (throw StateError('restore_harness_case_root'));
  _MatrixFailpoint get failpoint =>
      _failpoint ?? (throw StateError('restore_harness_case_failpoint'));
  Directory? get activeScenarioRoot => _scenarioRoot;
  String get _preferencesPrefix => switch (failpoint.scenario) {
    _MatrixScenario.forward => restoreProcessPreferencesPrefix(
      matrixRunId: matrixRunId,
      scenarioId: scenarioId,
      failpoint: failpoint.forward!,
    ),
    _MatrixScenario.terminal => restoreTerminalProcessPreferencesPrefix(
      matrixRunId: matrixRunId,
      scenarioId: scenarioId,
      failpoint: failpoint.terminal!,
    ),
    _MatrixScenario.rollback => restoreRollbackProcessPreferencesPrefix(
      matrixRunId: matrixRunId,
      scenarioId: scenarioId,
      failpoint: failpoint.rollback!,
    ),
    _MatrixScenario.rolledBackTerminal =>
      restoreRolledBackTerminalProcessPreferencesPrefix(
        matrixRunId: matrixRunId,
        scenarioId: scenarioId,
        failpoint: failpoint.terminal!,
      ),
  };

  Future<void> releaseHostLock() async {
    final hostLock = _hostLock;
    if (hostLock == null) return;
    _hostLock = null;
    await _releaseHostLockHandle(hostLock);
  }

  Future<void> _beginCase(_MatrixFailpoint selectedFailpoint) async {
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
      'scenario=${selection.scenarioName} '
      'matrixRunId=$matrixRunId cases=${_caseSummaries.length}/'
      '${selection.failpoints.length} elapsed='
      '${_formatDuration(_matrixStopwatch.elapsed)}',
    );
    for (final summary in _caseSummaries) {
      sink.writeln(
        '${summary.passed ? 'PASS' : 'FAIL'} '
        '${summary.failpointName} scenario=${summary.scenario} '
        'scenarioId=${summary.scenarioId} '
        'elapsed=${_formatDuration(summary.elapsed)} '
        'runnerPids=${summary.runnerProcessIds.join(',')}',
      );
    }
  }

  Future<void> run() async {
    final failpoints = selection.failpoints;
    if (failpoints.isEmpty ||
        failpoints.map((value) => value.name).toSet().length !=
            failpoints.length ||
        failpoints.any((value) => value.scenario != selection.scenario)) {
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
              scenario: selectedFailpoint.scenarioName,
              failpointName: selectedFailpoint.name,
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
              scenario: selectedFailpoint.scenarioName,
              failpointName: selectedFailpoint.name,
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
    switch (failpoint.scenario) {
      case _MatrixScenario.forward:
        await _runForwardCasePhases();
      case _MatrixScenario.terminal:
        await _runTerminalCasePhases();
      case _MatrixScenario.rollback:
        await _runRollbackCasePhases();
      case _MatrixScenario.rolledBackTerminal:
        await _runRolledBackTerminalCasePhases();
    }
  }

  Future<void> _runForwardCasePhases() async {
    final setup = await _runNormalPhase(
      await _writeForwardControl(RestoreProcessHarnessPhase.setup),
      _validateSetupEvent,
    );
    final runId = setup.requireString('runId');

    final cutover = await _runKillPhase(
      await _writeForwardControl(RestoreProcessHarnessPhase.cutoverKill),
      (event, control, process) => _validateCutoverEvent(
        event,
        control as RestoreProcessHarnessControl,
        process,
        runId: runId,
      ),
    );
    final cutoverLeaseInstanceId = cutover.requireIdentifier('leaseInstanceId');

    final resume = await _runNormalPhase(
      await _writeForwardControl(RestoreProcessHarnessPhase.resumeToColdAck),
      (event, control, process) => _validateResumeEvent(
        event,
        control as RestoreProcessHarnessControl,
        process,
        runId: runId,
        cutoverLeaseInstanceId: cutoverLeaseInstanceId,
      ),
    );
    final resumeProcessId = resume.pid;
    final resumeLeaseInstanceId = resume.requireIdentifier('leaseInstanceId');

    await _runNormalPhase(
      await _writeForwardControl(RestoreProcessHarnessPhase.coldFinalize),
      (event, control, process) => _validateFinalizeEvent(
        event,
        control as RestoreProcessHarnessControl,
        process,
        runId: runId,
        resumeProcessId: resumeProcessId,
        resumeLeaseInstanceId: resumeLeaseInstanceId,
        cutoverLeaseInstanceId: cutoverLeaseInstanceId,
      ),
    );
  }

  Future<void> _runTerminalCasePhases() async {
    final terminalFailpoint = failpoint.terminal!;
    final setup = await _runNormalPhase(
      await _writeTerminalControl(RestoreTerminalProcessHarnessPhase.setup),
      _validateSetupEvent,
    );
    final runId = setup.requireString('runId');

    if (_isColdAckFailpoint(terminalFailpoint)) {
      final killed = await _runKillPhase(
        await _writeTerminalControl(
          RestoreTerminalProcessHarnessPhase.commitToColdAck,
        ),
        (event, control, process) => _validateTerminalColdAckKillEvent(
          event,
          control as RestoreTerminalProcessHarnessControl,
          process,
          runId: runId,
        ),
      );
      final killedLease = killed.requireIdentifier('leaseInstanceId');
      final terminalReceiptChecksum = killed.requireSha256(
        'terminalReceiptChecksum',
      );
      final recovery = await _runNormalPhase(
        await _writeTerminalControl(
          RestoreTerminalProcessHarnessPhase.recoverTerminal,
        ),
        (event, control, process) => _validateTerminalColdAckRecoveryEvent(
          event,
          control as RestoreTerminalProcessHarnessControl,
          process,
          runId: runId,
          killedProcessId: killed.pid,
          killedLeaseInstanceId: killedLease,
          terminalReceiptChecksum: terminalReceiptChecksum,
        ),
      );
      final recoveryLease = recovery.requireIdentifier('leaseInstanceId');
      final expectedAckProcessId = recovery.requireProcessId('ackProcessId');
      final expectedAckLease = recovery.requireIdentifier('ackLeaseInstanceId');
      final recoveryOutcome = recovery.requireString('outcome');
      await _runNormalPhase(
        await _writeTerminalControl(
          RestoreTerminalProcessHarnessPhase.verifyBusinessReady,
        ),
        (event, control, process) => _validateTerminalVerifyEvent(
          event,
          control as RestoreTerminalProcessHarnessControl,
          process,
          runId: runId,
          expectedGateResult: recoveryOutcome == 'archived'
              ? 'none'
              : 'committed',
          expectedAckProcessId: expectedAckProcessId,
          expectedAckLeaseInstanceId: expectedAckLease,
          priorLeaseInstanceIds: {killedLease, recoveryLease},
        ),
      );
      return;
    }

    final arm = await _runNormalPhase(
      await _writeTerminalControl(
        RestoreTerminalProcessHarnessPhase.commitToColdAck,
      ),
      (event, control, process) => _validateTerminalArmEvent(
        event,
        control as RestoreTerminalProcessHarnessControl,
        process,
        runId: runId,
      ),
    );
    final armLease = arm.requireIdentifier('leaseInstanceId');
    final ackProcessId = arm.requireProcessId('coldAckProcessId');
    final ackLease = arm.requireIdentifier('coldAckLeaseInstanceId');
    final terminalReceiptChecksum = arm.requireSha256(
      'terminalReceiptChecksum',
    );
    final archiveKill = await _runKillPhase(
      await _writeTerminalControl(
        RestoreTerminalProcessHarnessPhase.recoverTerminal,
      ),
      (event, control, process) => _validateTerminalArchiveKillEvent(
        event,
        control as RestoreTerminalProcessHarnessControl,
        process,
        runId: runId,
        armProcessId: arm.pid,
        armLeaseInstanceId: armLease,
        terminalReceiptChecksum: terminalReceiptChecksum,
      ),
    );
    final archiveKillLease = archiveKill.requireIdentifier('leaseInstanceId');
    await _runNormalPhase(
      await _writeTerminalControl(
        RestoreTerminalProcessHarnessPhase.verifyBusinessReady,
      ),
      (event, control, process) => _validateTerminalVerifyEvent(
        event,
        control as RestoreTerminalProcessHarnessControl,
        process,
        runId: runId,
        expectedGateResult:
            terminalFailpoint ==
                RestoreTerminalProcessFailpoint.archivingMarkerRemovedDurable
            ? 'none'
            : 'committed',
        expectedAckProcessId: ackProcessId,
        expectedAckLeaseInstanceId: ackLease,
        priorLeaseInstanceIds: {armLease, archiveKillLease},
      ),
    );
  }

  Future<void> _runRollbackCasePhases() async {
    final setup = await _runNormalPhase(
      await _writeRollbackControl(RestoreRollbackProcessHarnessPhase.setup),
      _validateSetupEvent,
    );
    final runId = setup.requireIdentifier('runId');

    final rollbackKill = await _runKillPhase(
      await _writeRollbackControl(
        RestoreRollbackProcessHarnessPhase.triggerRollbackKill,
      ),
      (event, control, process) => _validateRollbackKillEvent(
        event,
        control as RestoreRollbackProcessHarnessControl,
        process,
        runId: runId,
      ),
    );
    final rollbackKillLease = rollbackKill.requireIdentifier('leaseInstanceId');

    final recovery = await _runNormalPhase(
      await _writeRollbackControl(
        RestoreRollbackProcessHarnessPhase.recoverToColdAck,
      ),
      (event, control, process) => _validateRollbackRecoveryEvent(
        event,
        control as RestoreRollbackProcessHarnessControl,
        process,
        runId: runId,
        rollbackKillLeaseInstanceId: rollbackKillLease,
      ),
    );
    final recoveryLease = recovery.requireIdentifier('leaseInstanceId');
    final ackProcessId = recovery.requireProcessId('ackProcessId');
    final ackLeaseInstanceId = recovery.requireIdentifier('ackLeaseInstanceId');
    final coldAckChecksum = recovery.requireSha256('coldAckChecksum');

    await _runNormalPhase(
      await _writeRollbackControl(
        RestoreRollbackProcessHarnessPhase.verifyBusinessReady,
      ),
      (event, control, process) => _validateRollbackVerifyEvent(
        event,
        control as RestoreRollbackProcessHarnessControl,
        process,
        runId: runId,
        expectedAckProcessId: ackProcessId,
        expectedAckLeaseInstanceId: ackLeaseInstanceId,
        expectedAckChecksum: coldAckChecksum,
        priorLeaseInstanceIds: {rollbackKillLease, recoveryLease},
      ),
    );
  }

  Future<void> _runRolledBackTerminalCasePhases() async {
    final terminalFailpoint = failpoint.terminal!;
    final setup = await _runNormalPhase(
      await _writeRolledBackTerminalControl(
        RestoreRolledBackTerminalProcessHarnessPhase.setup,
      ),
      _validateSetupEvent,
    );
    final runId = setup.requireIdentifier('runId');

    if (_isColdAckFailpoint(terminalFailpoint)) {
      final killed = await _runKillPhase(
        await _writeRolledBackTerminalControl(
          RestoreRolledBackTerminalProcessHarnessPhase.rollbackToColdAck,
        ),
        (event, control, process) =>
            _validateRolledBackTerminalColdAckKillEvent(
              event,
              control as RestoreRolledBackTerminalProcessHarnessControl,
              process,
              runId: runId,
            ),
      );
      final killedLease = killed.requireIdentifier('leaseInstanceId');
      final terminalReceiptChecksum = killed.requireSha256(
        'terminalReceiptChecksum',
      );
      final killedAckChecksum = killed.requireSha256('ackChecksum');
      final recovery = await _runNormalPhase(
        await _writeRolledBackTerminalControl(
          RestoreRolledBackTerminalProcessHarnessPhase.recoverTerminal,
        ),
        (event, control, process) =>
            _validateRolledBackTerminalColdAckRecoveryEvent(
              event,
              control as RestoreRolledBackTerminalProcessHarnessControl,
              process,
              runId: runId,
              killedProcessId: killed.pid,
              killedLeaseInstanceId: killedLease,
              killedAckChecksum: killedAckChecksum,
              terminalReceiptChecksum: terminalReceiptChecksum,
            ),
      );
      final recoveryLease = recovery.requireIdentifier('leaseInstanceId');
      final ackProcessId = recovery.requireProcessId('ackProcessId');
      final ackLease = recovery.requireIdentifier('ackLeaseInstanceId');
      final ackChecksum = recovery.requireSha256('coldAckChecksum');
      final outcome = recovery.requireString('outcome');
      await _runNormalPhase(
        await _writeRolledBackTerminalControl(
          RestoreRolledBackTerminalProcessHarnessPhase.verifyBusinessReady,
        ),
        (event, control, process) => _validateRolledBackTerminalVerifyEvent(
          event,
          control as RestoreRolledBackTerminalProcessHarnessControl,
          process,
          runId: runId,
          expectedGateResult: outcome == 'archived' ? 'none' : 'rolledBack',
          expectedAckProcessId: ackProcessId,
          expectedAckLeaseInstanceId: ackLease,
          expectedAckChecksum: ackChecksum,
          priorLeaseInstanceIds: {killedLease, recoveryLease},
        ),
      );
      return;
    }

    final arm = await _runNormalPhase(
      await _writeRolledBackTerminalControl(
        RestoreRolledBackTerminalProcessHarnessPhase.rollbackToColdAck,
      ),
      (event, control, process) => _validateRolledBackTerminalArmEvent(
        event,
        control as RestoreRolledBackTerminalProcessHarnessControl,
        process,
        runId: runId,
      ),
    );
    final armLease = arm.requireIdentifier('leaseInstanceId');
    final ackProcessId = arm.requireProcessId('coldAckProcessId');
    final ackLease = arm.requireIdentifier('coldAckLeaseInstanceId');
    final ackChecksum = arm.requireSha256('coldAckChecksum');
    final terminalReceiptChecksum = arm.requireSha256(
      'terminalReceiptChecksum',
    );
    final archiveKill = await _runKillPhase(
      await _writeRolledBackTerminalControl(
        RestoreRolledBackTerminalProcessHarnessPhase.recoverTerminal,
      ),
      (event, control, process) => _validateRolledBackTerminalArchiveKillEvent(
        event,
        control as RestoreRolledBackTerminalProcessHarnessControl,
        process,
        runId: runId,
        armProcessId: arm.pid,
        armLeaseInstanceId: armLease,
        ackChecksum: ackChecksum,
        terminalReceiptChecksum: terminalReceiptChecksum,
      ),
    );
    final archiveKillLease = archiveKill.requireIdentifier('leaseInstanceId');
    await _runNormalPhase(
      await _writeRolledBackTerminalControl(
        RestoreRolledBackTerminalProcessHarnessPhase.verifyBusinessReady,
      ),
      (event, control, process) => _validateRolledBackTerminalVerifyEvent(
        event,
        control as RestoreRolledBackTerminalProcessHarnessControl,
        process,
        runId: runId,
        expectedGateResult:
            terminalFailpoint ==
                RestoreTerminalProcessFailpoint.archivingMarkerRemovedDurable
            ? 'none'
            : 'rolledBack',
        expectedAckProcessId: ackProcessId,
        expectedAckLeaseInstanceId: ackLease,
        expectedAckChecksum: ackChecksum,
        priorLeaseInstanceIds: {armLease, archiveKillLease},
      ),
    );
  }

  bool _isColdAckFailpoint(RestoreTerminalProcessFailpoint value) =>
      value == RestoreTerminalProcessFailpoint.coldAckTempDurable ||
      value == RestoreTerminalProcessFailpoint.coldAckPublished;

  Future<_HarnessEvent> _runNormalPhase(
    RestoreHarnessControl control,
    _EventValidator validate,
  ) async {
    final process = await _startFlutter(control);
    final event = await _waitForEvent(control, process);
    final runner = await _recordRunnerProcess(event, process);
    validate(event, control, process);

    final outerExitCode = await process.waitForExit(_phaseTimeout);
    if (outerExitCode != 0) {
      throw StateError(
        'restore_harness_outer_exit:${control.phaseName}:$outerExitCode',
      );
    }
    await _requireRunnerExited(runner);
    _activeRunnerIdentities.remove(runner.identity);
    return event;
  }

  Future<_HarnessEvent> _runKillPhase(
    RestoreHarnessControl control,
    _EventValidator validate,
  ) async {
    final process = await _startFlutter(control);
    final event = await _waitForEvent(control, process);
    final runner = await _recordRunnerProcess(event, process);
    validate(event, control, process);

    await _requireSameRunner(runner);
    if (!Process.killPid(event.pid, ProcessSignal.sigkill)) {
      throw StateError('restore_harness_runner_kill_failed:${event.pid}');
    }
    await _requireRunnerExited(runner);
    _activeRunnerIdentities.remove(runner.identity);

    final outerExitCode = await process.waitForExit(_killExitTimeout);
    if (outerExitCode == 0) {
      switch (control) {
        case RestoreProcessHarnessControl():
          throw StateError('restore_harness_cutover_outer_succeeded');
        case RestoreTerminalProcessHarnessControl():
          throw StateError(
            'restore_terminal_harness_kill_outer_succeeded:'
            '${control.phaseName}',
          );
        case RestoreRollbackProcessHarnessControl():
          throw StateError(
            'restore_rollback_harness_kill_outer_succeeded:'
            '${control.phaseName}',
          );
        case RestoreRolledBackTerminalProcessHarnessControl():
          throw StateError(
            'restore_rolled_back_terminal_harness_kill_outer_succeeded:'
            '${control.phaseName}',
          );
        default:
          throw StateError('restore_harness_kill_control_runtime_type');
      }
    }
    return event;
  }

  Future<RestoreProcessHarnessControl> _writeForwardControl(
    RestoreProcessHarnessPhase phase,
  ) async {
    final control = RestoreProcessHarnessControl(
      generation: phase.index + 1,
      matrixRunId: matrixRunId,
      scenarioId: scenarioId,
      phase: phase,
      failpoint: failpoint.forward!,
      scenarioRoot: scenarioRoot.path,
      preferencesPrefix: _preferencesPrefix,
    );
    return _persistControl(control);
  }

  Future<RestoreTerminalProcessHarnessControl> _writeTerminalControl(
    RestoreTerminalProcessHarnessPhase phase,
  ) async {
    final control = RestoreTerminalProcessHarnessControl(
      generation: phase.index + 1,
      matrixRunId: matrixRunId,
      scenarioId: scenarioId,
      phase: phase,
      failpoint: failpoint.terminal!,
      scenarioRoot: scenarioRoot.path,
      preferencesPrefix: _preferencesPrefix,
    );
    return _persistControl(control);
  }

  Future<RestoreRollbackProcessHarnessControl> _writeRollbackControl(
    RestoreRollbackProcessHarnessPhase phase,
  ) async {
    final control = RestoreRollbackProcessHarnessControl(
      generation: phase.index + 1,
      matrixRunId: matrixRunId,
      scenarioId: scenarioId,
      phase: phase,
      failpoint: failpoint.rollback!,
      scenarioRoot: scenarioRoot.path,
      preferencesPrefix: _preferencesPrefix,
    );
    return _persistControl(control);
  }

  Future<RestoreRolledBackTerminalProcessHarnessControl>
  _writeRolledBackTerminalControl(
    RestoreRolledBackTerminalProcessHarnessPhase phase,
  ) async {
    final control = RestoreRolledBackTerminalProcessHarnessControl(
      generation: phase.index + 1,
      matrixRunId: matrixRunId,
      scenarioId: scenarioId,
      phase: phase,
      failpoint: failpoint.terminal!,
      scenarioRoot: scenarioRoot.path,
      preferencesPrefix: _preferencesPrefix,
    );
    return _persistControl(control);
  }

  Future<T> _persistControl<T extends RestoreHarnessControl>(T control) async {
    final controlFile = _controlFile(control);
    await writeDurableHarnessJson(controlFile, control.toJson());
    final persisted = RestoreHarnessControl.fromJson(
      await readHarnessJson(controlFile),
    );
    if (persisted is! T ||
        jsonEncode(persisted.toJson()) != jsonEncode(control.toJson())) {
      throw StateError('restore_harness_control_readback');
    }
    return persisted;
  }

  File _controlFile(RestoreHarnessControl control) => File(
    p.join(
      scenarioRoot.path,
      'control',
      '${control.generation.toString().padLeft(2, '0')}_'
          '${control.phaseName}.json',
    ),
  );

  Future<_ManagedProcess> _startFlutter(RestoreHarnessControl control) async {
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
      phaseName: control.phaseName,
      command: ['flutter', ...arguments],
      process: process,
      runnerBaseline: runnerBaseline,
    );
    _processes.add(managed);
    stdout.writeln('Started ${control.phaseName}: outer PID ${process.pid}');
    return managed;
  }

  Future<_HarnessEvent> _waitForEvent(
    RestoreHarnessControl control,
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
        throw StateError('restore_harness_event_type:${control.phaseName}');
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
          'restore_harness_event_missing:${control.phaseName}:'
          '${process.completedExitCode}',
        );
      }
      await Future.any<void>([
        Future<void>.delayed(const Duration(milliseconds: 100)),
        process.exited.then<void>((_) {}),
      ]);
    }
    throw TimeoutException(
      'restore_harness_event_timeout:${control.phaseName}',
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
        '${process.phaseName}:${candidates.length}',
      );
    }
    final observed = candidates.single;
    final existing = process.discoveredRunner;
    if (existing != null && existing.identity != observed.identity) {
      throw StateError(
        'restore_harness_phase_runner_changed:${process.phaseName}',
      );
    }
    process.discoveredRunner = observed;
    process.runnerProcessId = observed.pid;
  }

  void _validateSetupEvent(
    _HarnessEvent event,
    RestoreHarnessControl control,
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

  void _validateTerminalArmEvent(
    _HarnessEvent event,
    RestoreTerminalProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
  }) {
    if (_isColdAckFailpoint(control.failpoint)) {
      throw StateError('restore_terminal_harness_arm_failpoint');
    }
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
        'coldAckChecksum',
        'terminalReceiptChecksum',
      },
    );
    event.requireExactString('runId', runId);
    event.requireExactString('receiptState', 'committed');
    final leaseInstanceId = event.requireIdentifier('leaseInstanceId');
    if (event.requireProcessId('coldAckProcessId') != event.pid) {
      throw StateError('restore_terminal_harness_arm_ack_pid');
    }
    if (event.requireIdentifier('coldAckLeaseInstanceId') != leaseInstanceId) {
      throw StateError('restore_terminal_harness_arm_ack_lease');
    }
    event.requireSha256('coldAckChecksum');
    event.requireSha256('terminalReceiptChecksum');
  }

  void _validateTerminalColdAckKillEvent(
    _HarnessEvent event,
    RestoreTerminalProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
  }) {
    if (!_isColdAckFailpoint(control.failpoint)) {
      throw StateError('restore_terminal_harness_cold_ack_failpoint');
    }
    event.requireCommon(
      control,
      process,
      expectedStatus: 'readyForKill',
      phaseSpecificKeys: const {
        'marker',
        'runId',
        'leaseInstanceId',
        'observedReceiptState',
        'operationKind',
        'terminalReceiptChecksum',
        'expected',
        'ackProcessId',
        'ackLeaseInstanceId',
        'ackChecksum',
        'temporaryPath',
        'targetPath',
      },
    );
    event.requireExactString('marker', control.failpoint.name);
    event.requireExactString('runId', runId);
    event.requireExactString('observedReceiptState', 'committed');
    final leaseInstanceId = event.requireIdentifier('leaseInstanceId');
    _validateTerminalColdAckObservation(
      event,
      control,
      runId: runId,
      leaseInstanceId: leaseInstanceId,
    );
  }

  void _validateTerminalColdAckObservation(
    _HarnessEvent event,
    RestoreTerminalProcessHarnessControl control, {
    required String runId,
    required String leaseInstanceId,
  }) {
    event.requireExactString('operationKind', control.failpoint.name);
    event.requireExactString('runId', runId);
    event.requireSha256('terminalReceiptChecksum');
    event.requireExactString('expected', 'target');
    if (event.requireProcessId('ackProcessId') != event.pid) {
      throw StateError('restore_terminal_harness_cold_ack_pid');
    }
    if (event.requireIdentifier('ackLeaseInstanceId') != leaseInstanceId) {
      throw StateError('restore_terminal_harness_cold_ack_lease');
    }
    event.requireSha256('ackChecksum');

    final runDirectory = p.join(
      p.normalize(p.absolute(control.appDataDirectory.path)),
      '.kelivo_restore',
      'run_$runId',
    );
    const ackFileName = 'settings_cold_ack.json';
    final temporaryPath = event.requirePath('temporaryPath');
    final temporaryPattern = RegExp(
      '^${RegExp.escape(ackFileName)}\\.'
      '([1-9][0-9]*)_${event.pid}_([0-9]+)\\.tmp\$',
    );
    if (!p.equals(p.dirname(temporaryPath), runDirectory) ||
        temporaryPattern.firstMatch(p.basename(temporaryPath)) == null) {
      throw const FormatException('restore_terminal_harness_cold_ack_temp');
    }
    event.requirePath(
      'targetPath',
      expected: p.join(runDirectory, ackFileName),
    );
  }

  void _validateTerminalColdAckRecoveryEvent(
    _HarnessEvent event,
    RestoreTerminalProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
    required int killedProcessId,
    required String killedLeaseInstanceId,
    required String terminalReceiptChecksum,
  }) {
    if (!_isColdAckFailpoint(control.failpoint)) {
      throw StateError('restore_terminal_harness_recovery_failpoint');
    }
    event.requireCommon(
      control,
      process,
      expectedStatus: 'completed',
      phaseSpecificKeys: const {
        'runId',
        'receiptState',
        'outcome',
        'leaseInstanceId',
        'ackProcessId',
        'ackLeaseInstanceId',
        'terminalReceiptChecksum',
        'settingsMutationAttempts',
      },
    );
    event.requireExactString('runId', runId);
    event.requireExactString('receiptState', 'committed');
    event.requireExactString(
      'terminalReceiptChecksum',
      terminalReceiptChecksum,
    );
    final leaseInstanceId = event.requireIdentifier('leaseInstanceId');
    if (leaseInstanceId == killedLeaseInstanceId) {
      throw StateError('restore_terminal_harness_recovery_lease_reused');
    }
    final outcome = event.requireString('outcome');
    final expectsColdRestart =
        control.failpoint == RestoreTerminalProcessFailpoint.coldAckTempDurable;
    if (outcome != (expectsColdRestart ? 'coldRestartRequired' : 'archived')) {
      throw StateError('restore_terminal_harness_recovery_outcome');
    }
    final coldRestartRequired = outcome == 'coldRestartRequired';
    final expectedAckProcessId = coldRestartRequired
        ? event.pid
        : killedProcessId;
    final expectedAckLease = coldRestartRequired
        ? leaseInstanceId
        : killedLeaseInstanceId;
    if (event.requireProcessId('ackProcessId') != expectedAckProcessId) {
      throw StateError('restore_terminal_harness_recovery_ack_pid');
    }
    if (event.requireIdentifier('ackLeaseInstanceId') != expectedAckLease) {
      throw StateError('restore_terminal_harness_recovery_ack_lease');
    }
    final mutationAttempts = event.requireInt('settingsMutationAttempts');
    if (coldRestartRequired ? mutationAttempts < 1 : mutationAttempts != 0) {
      throw StateError('restore_terminal_harness_recovery_settings_mutation');
    }
  }

  void _validateTerminalArchiveKillEvent(
    _HarnessEvent event,
    RestoreTerminalProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
    required int armProcessId,
    required String armLeaseInstanceId,
    required String terminalReceiptChecksum,
  }) {
    if (_isColdAckFailpoint(control.failpoint)) {
      throw StateError('restore_terminal_harness_archive_failpoint');
    }
    final observationKeys = switch (control.failpoint) {
      RestoreTerminalProcessFailpoint.completedRunsRootDurable ||
      RestoreTerminalProcessFailpoint.archivingMarkerRemovedDurable => const {
        'operationKind',
        'boundary',
        'path',
        'fullBarrier',
      },
      RestoreTerminalProcessFailpoint.archivingMarkerPublished ||
      RestoreTerminalProcessFailpoint.terminalRunArchived => const {
        'operationKind',
        'sourcePath',
        'targetPath',
        'sourceKind',
      },
      RestoreTerminalProcessFailpoint.coldAckTempDurable ||
      RestoreTerminalProcessFailpoint.coldAckPublished => throw StateError(
        'restore_terminal_harness_archive_failpoint',
      ),
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
        'coldAckProcessId',
        'coldAckLeaseInstanceId',
        'ackProcessId',
        'ackLeaseInstanceId',
        'terminalReceiptChecksum',
        'settingsMutationAttempts',
        ...observationKeys,
      },
    );
    event.requireExactString('marker', control.failpoint.name);
    event.requireExactString('runId', runId);
    event.requireExactString('observedReceiptState', 'committed');
    event.requireExactString(
      'terminalReceiptChecksum',
      terminalReceiptChecksum,
    );
    final leaseInstanceId = event.requireIdentifier('leaseInstanceId');
    if (leaseInstanceId == armLeaseInstanceId) {
      throw StateError('restore_terminal_harness_archive_lease_reused');
    }
    for (final key in const ['coldAckProcessId', 'ackProcessId']) {
      if (event.requireProcessId(key) != armProcessId) {
        throw StateError('restore_terminal_harness_archive_ack_pid:$key');
      }
    }
    for (final key in const ['coldAckLeaseInstanceId', 'ackLeaseInstanceId']) {
      if (event.requireIdentifier(key) != armLeaseInstanceId) {
        throw StateError('restore_terminal_harness_archive_ack_lease:$key');
      }
    }
    if (event.requireInt('settingsMutationAttempts') != 0) {
      throw StateError('restore_terminal_harness_archive_settings_mutation');
    }
    _validateTerminalArchiveObservation(event, control, runId: runId);
  }

  void _validateTerminalArchiveObservation(
    _HarnessEvent event,
    RestoreTerminalProcessHarnessControl control, {
    required String runId,
  }) {
    final workspace = p.join(
      p.normalize(p.absolute(control.appDataDirectory.path)),
      '.kelivo_restore',
    );
    switch (control.failpoint) {
      case RestoreTerminalProcessFailpoint.completedRunsRootDurable ||
          RestoreTerminalProcessFailpoint.archivingMarkerRemovedDurable:
        event.requireExactString('operationKind', 'terminalWorkspaceSyncAfter');
        event.requireExactString('boundary', control.failpoint.name);
        event.requirePath('path', expected: workspace);
        if (!event.requireBool('fullBarrier')) {
          throw const FormatException(
            'restore_terminal_harness_workspace_barrier',
          );
        }
      case RestoreTerminalProcessFailpoint.archivingMarkerPublished:
        event.requireRenameObservation(
          sourcePath: p.join(workspace, '.active_run.publishing'),
          targetPath: p.join(workspace, '.active_run.archiving'),
          sourceKind: 'file',
        );
      case RestoreTerminalProcessFailpoint.terminalRunArchived:
        event.requireRenameObservation(
          sourcePath: p.join(workspace, 'run_$runId'),
          targetPath: p.join(workspace, 'completed', 'run_$runId'),
          sourceKind: 'directory',
        );
      case RestoreTerminalProcessFailpoint.coldAckTempDurable ||
          RestoreTerminalProcessFailpoint.coldAckPublished:
        throw StateError('restore_terminal_harness_archive_observation');
    }
  }

  void _validateTerminalVerifyEvent(
    _HarnessEvent event,
    RestoreTerminalProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
    required String expectedGateResult,
    required int expectedAckProcessId,
    required String expectedAckLeaseInstanceId,
    required Set<String> priorLeaseInstanceIds,
  }) {
    event.requireCommon(
      control,
      process,
      expectedStatus: 'completed',
      phaseSpecificKeys: const {
        'runId',
        'receiptState',
        'gateResult',
        'observedAckProcessId',
        'observedAckLeaseInstanceId',
        'leaseInstanceId',
        'settingsMutationAttempts',
      },
    );
    event.requireExactString('runId', runId);
    event.requireExactString('receiptState', 'committed');
    event.requireExactString('gateResult', expectedGateResult);
    if (event.requireProcessId('observedAckProcessId') !=
        expectedAckProcessId) {
      throw StateError('restore_terminal_harness_verify_ack_pid');
    }
    if (event.requireIdentifier('observedAckLeaseInstanceId') !=
        expectedAckLeaseInstanceId) {
      throw StateError('restore_terminal_harness_verify_ack_lease');
    }
    final leaseInstanceId = event.requireIdentifier('leaseInstanceId');
    if (priorLeaseInstanceIds.length != 2 ||
        priorLeaseInstanceIds.contains(leaseInstanceId) ||
        leaseInstanceId == expectedAckLeaseInstanceId) {
      throw StateError('restore_terminal_harness_verify_lease_reused');
    }
    if (event.requireInt('settingsMutationAttempts') != 0) {
      throw StateError('restore_terminal_harness_verify_settings_mutation');
    }
  }

  void _validateRolledBackTerminalArmEvent(
    _HarnessEvent event,
    RestoreRolledBackTerminalProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
  }) {
    if (_isColdAckFailpoint(control.failpoint)) {
      throw StateError('restore_rolled_back_terminal_arm_failpoint');
    }
    event.requireCommon(
      control,
      process,
      expectedStatus: 'completed',
      phaseSpecificKeys: const {
        'runId',
        'receiptState',
        'leaseInstanceId',
        'rollbackOriginReceiptState',
        'triggerKind',
        'triggerPreferenceKey',
        'triggerFailureCount',
        'ackExpected',
        'coldAckProcessId',
        'coldAckLeaseInstanceId',
        'coldAckChecksum',
        'terminalReceiptChecksum',
        'settingsMutationAttempts',
      },
    );
    event.requireExactString('runId', runId);
    event.requireExactString('receiptState', 'rolledBack');
    event.requireExactString('rollbackOriginReceiptState', 'verified');
    event.requireExactString('triggerKind', 'repeatedTargetSetRejected');
    event.requireExactString(
      'triggerPreferenceKey',
      'restore_harness_${control.scenarioId}_primary',
    );
    if (event.requireInt('triggerFailureCount') != 1) {
      throw StateError('restore_rolled_back_terminal_arm_trigger');
    }
    event.requireExactString('ackExpected', 'before');
    final leaseInstanceId = event.requireIdentifier('leaseInstanceId');
    if (event.requireProcessId('coldAckProcessId') != event.pid) {
      throw StateError('restore_rolled_back_terminal_arm_ack_pid');
    }
    if (event.requireIdentifier('coldAckLeaseInstanceId') != leaseInstanceId) {
      throw StateError('restore_rolled_back_terminal_arm_ack_lease');
    }
    event.requireSha256('coldAckChecksum');
    event.requireSha256('terminalReceiptChecksum');
    if (event.requireInt('settingsMutationAttempts') < 1) {
      throw StateError('restore_rolled_back_terminal_arm_settings_mutation');
    }
  }

  void _validateRolledBackTerminalColdAckKillEvent(
    _HarnessEvent event,
    RestoreRolledBackTerminalProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
  }) {
    if (!_isColdAckFailpoint(control.failpoint)) {
      throw StateError('restore_rolled_back_terminal_cold_ack_failpoint');
    }
    event.requireCommon(
      control,
      process,
      expectedStatus: 'readyForKill',
      phaseSpecificKeys: const {
        'marker',
        'runId',
        'leaseInstanceId',
        'rollbackOriginReceiptState',
        'triggerKind',
        'triggerPreferenceKey',
        'triggerFailureCount',
        'observedReceiptState',
        'settingsMutationAttempts',
        'operationKind',
        'terminalReceiptChecksum',
        'expected',
        'ackProcessId',
        'ackLeaseInstanceId',
        'ackChecksum',
        'temporaryPath',
        'targetPath',
      },
    );
    event.requireExactString('marker', control.failpoint.name);
    event.requireExactString('runId', runId);
    event.requireExactString('rollbackOriginReceiptState', 'verified');
    event.requireExactString('triggerKind', 'repeatedTargetSetRejected');
    event.requireExactString(
      'triggerPreferenceKey',
      'restore_harness_${control.scenarioId}_primary',
    );
    if (event.requireInt('triggerFailureCount') != 1 ||
        event.requireInt('settingsMutationAttempts') < 1) {
      throw StateError('restore_rolled_back_terminal_cold_ack_trigger');
    }
    event.requireExactString('observedReceiptState', 'rolledBack');
    final leaseInstanceId = event.requireIdentifier('leaseInstanceId');
    _validateRolledBackTerminalColdAckObservation(
      event,
      control,
      runId: runId,
      leaseInstanceId: leaseInstanceId,
    );
  }

  void _validateRolledBackTerminalColdAckObservation(
    _HarnessEvent event,
    RestoreRolledBackTerminalProcessHarnessControl control, {
    required String runId,
    required String leaseInstanceId,
  }) {
    final expectedOperation =
        control.failpoint == RestoreTerminalProcessFailpoint.coldAckTempDurable
        ? 'coldAckTempDurable'
        : 'coldAckPublished';
    event.requireExactString('operationKind', expectedOperation);
    event.requireSha256('terminalReceiptChecksum');
    event.requireExactString('expected', 'before');
    if (event.requireProcessId('ackProcessId') != event.pid) {
      throw StateError('restore_rolled_back_terminal_cold_ack_pid');
    }
    if (event.requireIdentifier('ackLeaseInstanceId') != leaseInstanceId) {
      throw StateError('restore_rolled_back_terminal_cold_ack_lease');
    }
    event.requireSha256('ackChecksum');
    final runDirectory = p.join(
      p.normalize(p.absolute(control.appDataDirectory.path)),
      '.kelivo_restore',
      'run_$runId',
    );
    const ackFileName = 'settings_cold_ack.json';
    final temporaryPath = event.requirePath('temporaryPath');
    final temporaryPattern = RegExp(
      '^${RegExp.escape(ackFileName)}\\.'
      '([1-9][0-9]*)_${event.pid}_([0-9]+)\\.tmp\$',
    );
    if (!p.equals(p.dirname(temporaryPath), runDirectory) ||
        temporaryPattern.firstMatch(p.basename(temporaryPath)) == null) {
      throw const FormatException('restore_rolled_back_terminal_cold_ack_temp');
    }
    event.requirePath(
      'targetPath',
      expected: p.join(runDirectory, ackFileName),
    );
  }

  void _validateRolledBackTerminalColdAckRecoveryEvent(
    _HarnessEvent event,
    RestoreRolledBackTerminalProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
    required int killedProcessId,
    required String killedLeaseInstanceId,
    required String killedAckChecksum,
    required String terminalReceiptChecksum,
  }) {
    if (!_isColdAckFailpoint(control.failpoint)) {
      throw StateError('restore_rolled_back_terminal_recovery_failpoint');
    }
    event.requireCommon(
      control,
      process,
      expectedStatus: 'completed',
      phaseSpecificKeys: const {
        'runId',
        'receiptState',
        'outcome',
        'leaseInstanceId',
        'ackExpected',
        'ackProcessId',
        'ackLeaseInstanceId',
        'coldAckChecksum',
        'terminalReceiptChecksum',
        'settingsMutationAttempts',
      },
    );
    event.requireExactString('runId', runId);
    event.requireExactString('receiptState', 'rolledBack');
    event.requireExactString('ackExpected', 'before');
    event.requireExactString(
      'terminalReceiptChecksum',
      terminalReceiptChecksum,
    );
    final leaseInstanceId = event.requireIdentifier('leaseInstanceId');
    if (leaseInstanceId == killedLeaseInstanceId) {
      throw StateError('restore_rolled_back_terminal_recovery_lease_reused');
    }
    final tempFailpoint =
        control.failpoint == RestoreTerminalProcessFailpoint.coldAckTempDurable;
    final outcome = event.requireString('outcome');
    if (outcome != (tempFailpoint ? 'coldRestartRequired' : 'archived')) {
      throw StateError('restore_rolled_back_terminal_recovery_outcome');
    }
    final expectedAckProcessId = tempFailpoint ? event.pid : killedProcessId;
    final expectedAckLease = tempFailpoint
        ? leaseInstanceId
        : killedLeaseInstanceId;
    if (event.requireProcessId('ackProcessId') != expectedAckProcessId ||
        event.requireIdentifier('ackLeaseInstanceId') != expectedAckLease) {
      throw StateError('restore_rolled_back_terminal_recovery_ack_identity');
    }
    final ackChecksum = event.requireSha256('coldAckChecksum');
    if (tempFailpoint
        ? ackChecksum == killedAckChecksum
        : ackChecksum != killedAckChecksum) {
      throw StateError('restore_rolled_back_terminal_recovery_ack_checksum');
    }
    final mutationAttempts = event.requireInt('settingsMutationAttempts');
    if (tempFailpoint ? mutationAttempts < 1 : mutationAttempts != 0) {
      throw StateError(
        'restore_rolled_back_terminal_recovery_settings_mutation',
      );
    }
  }

  void _validateRolledBackTerminalArchiveKillEvent(
    _HarnessEvent event,
    RestoreRolledBackTerminalProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
    required int armProcessId,
    required String armLeaseInstanceId,
    required String ackChecksum,
    required String terminalReceiptChecksum,
  }) {
    if (_isColdAckFailpoint(control.failpoint)) {
      throw StateError('restore_rolled_back_terminal_archive_failpoint');
    }
    final observationKeys = switch (control.failpoint) {
      RestoreTerminalProcessFailpoint.completedRunsRootDurable ||
      RestoreTerminalProcessFailpoint.archivingMarkerRemovedDurable => const {
        'operationKind',
        'boundary',
        'path',
        'fullBarrier',
      },
      RestoreTerminalProcessFailpoint.archivingMarkerPublished ||
      RestoreTerminalProcessFailpoint.terminalRunArchived => const {
        'operationKind',
        'sourcePath',
        'targetPath',
        'sourceKind',
      },
      _ => throw StateError('restore_rolled_back_terminal_archive_failpoint'),
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
        'coldAckProcessId',
        'coldAckLeaseInstanceId',
        'ackExpected',
        'ackProcessId',
        'ackLeaseInstanceId',
        'coldAckChecksum',
        'terminalReceiptChecksum',
        'settingsMutationAttempts',
        ...observationKeys,
      },
    );
    event.requireExactString('marker', control.failpoint.name);
    event.requireExactString('runId', runId);
    event.requireExactString('observedReceiptState', 'rolledBack');
    event.requireExactString('ackExpected', 'before');
    event.requireExactString(
      'terminalReceiptChecksum',
      terminalReceiptChecksum,
    );
    event.requireExactString('coldAckChecksum', ackChecksum);
    final leaseInstanceId = event.requireIdentifier('leaseInstanceId');
    if (leaseInstanceId == armLeaseInstanceId) {
      throw StateError('restore_rolled_back_terminal_archive_lease_reused');
    }
    for (final key in const ['coldAckProcessId', 'ackProcessId']) {
      if (event.requireProcessId(key) != armProcessId) {
        throw StateError('restore_rolled_back_terminal_archive_ack_pid:$key');
      }
    }
    for (final key in const ['coldAckLeaseInstanceId', 'ackLeaseInstanceId']) {
      if (event.requireIdentifier(key) != armLeaseInstanceId) {
        throw StateError('restore_rolled_back_terminal_archive_ack_lease:$key');
      }
    }
    if (event.requireInt('settingsMutationAttempts') != 0) {
      throw StateError(
        'restore_rolled_back_terminal_archive_settings_mutation',
      );
    }
    _validateRolledBackTerminalArchiveObservation(event, control, runId: runId);
  }

  void _validateRolledBackTerminalArchiveObservation(
    _HarnessEvent event,
    RestoreRolledBackTerminalProcessHarnessControl control, {
    required String runId,
  }) {
    final workspace = p.join(
      p.normalize(p.absolute(control.appDataDirectory.path)),
      '.kelivo_restore',
    );
    switch (control.failpoint) {
      case RestoreTerminalProcessFailpoint.completedRunsRootDurable:
      case RestoreTerminalProcessFailpoint.archivingMarkerRemovedDurable:
        event.requireExactString('operationKind', 'terminalWorkspaceSyncAfter');
        event.requireExactString('boundary', control.failpoint.name);
        event.requirePath('path', expected: workspace);
        if (!event.requireBool('fullBarrier')) {
          throw const FormatException(
            'restore_rolled_back_terminal_workspace_barrier',
          );
        }
      case RestoreTerminalProcessFailpoint.archivingMarkerPublished:
        event.requireRenameObservation(
          sourcePath: p.join(workspace, '.active_run.publishing'),
          targetPath: p.join(workspace, '.active_run.archiving'),
          sourceKind: 'file',
        );
      case RestoreTerminalProcessFailpoint.terminalRunArchived:
        event.requireRenameObservation(
          sourcePath: p.join(workspace, 'run_$runId'),
          targetPath: p.join(workspace, 'completed', 'run_$runId'),
          sourceKind: 'directory',
        );
      case RestoreTerminalProcessFailpoint.coldAckTempDurable:
      case RestoreTerminalProcessFailpoint.coldAckPublished:
        throw StateError('restore_rolled_back_terminal_archive_observation');
    }
  }

  void _validateRolledBackTerminalVerifyEvent(
    _HarnessEvent event,
    RestoreRolledBackTerminalProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
    required String expectedGateResult,
    required int expectedAckProcessId,
    required String expectedAckLeaseInstanceId,
    required String expectedAckChecksum,
    required Set<String> priorLeaseInstanceIds,
  }) {
    event.requireCommon(
      control,
      process,
      expectedStatus: 'completed',
      phaseSpecificKeys: const {
        'runId',
        'receiptState',
        'gateResult',
        'archiveState',
        'observedAckExpected',
        'observedAckProcessId',
        'observedAckLeaseInstanceId',
        'observedAckChecksum',
        'leaseInstanceId',
        'settingsMutationAttempts',
      },
    );
    event.requireExactString('runId', runId);
    event.requireExactString('receiptState', 'rolledBack');
    event.requireExactString('gateResult', expectedGateResult);
    event.requireExactString('archiveState', 'archived');
    event.requireExactString('observedAckExpected', 'before');
    if (event.requireProcessId('observedAckProcessId') !=
        expectedAckProcessId) {
      throw StateError('restore_rolled_back_terminal_verify_ack_pid');
    }
    if (event.requireIdentifier('observedAckLeaseInstanceId') !=
        expectedAckLeaseInstanceId) {
      throw StateError('restore_rolled_back_terminal_verify_ack_lease');
    }
    event.requireExactString('observedAckChecksum', expectedAckChecksum);
    final leaseInstanceId = event.requireIdentifier('leaseInstanceId');
    if (priorLeaseInstanceIds.length != 2 ||
        priorLeaseInstanceIds.contains(leaseInstanceId) ||
        leaseInstanceId == expectedAckLeaseInstanceId) {
      throw StateError('restore_rolled_back_terminal_verify_lease_reused');
    }
    if (event.requireInt('settingsMutationAttempts') != 0) {
      throw StateError('restore_rolled_back_terminal_verify_settings_mutation');
    }
  }

  void _validateRollbackKillEvent(
    _HarnessEvent event,
    RestoreRollbackProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
  }) {
    final observationKeys = switch (control.failpoint) {
      RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable ||
      RestoreRollbackProcessFailpoint.rollingBackReceiptPublished ||
      RestoreRollbackProcessFailpoint.rolledBackReceiptTempDurable ||
      RestoreRollbackProcessFailpoint.rolledBackReceiptPublished => const {
        'operationKind',
        'receiptSequence',
        'receiptState',
        'temporaryPath',
        'targetPath',
      },
      RestoreRollbackProcessFailpoint.newDatabaseReturnedToCandidate ||
      RestoreRollbackProcessFailpoint.previousDatabaseRestoredToLive ||
      RestoreRollbackProcessFailpoint.newUploadReturnedToCandidate ||
      RestoreRollbackProcessFailpoint.previousUploadRestoredToLive ||
      RestoreRollbackProcessFailpoint.newImagesReturnedToCandidate ||
      RestoreRollbackProcessFailpoint.previousImagesRestoredToLive ||
      RestoreRollbackProcessFailpoint.newAvatarsReturnedToCandidate ||
      RestoreRollbackProcessFailpoint.previousAvatarsRestoredToLive ||
      RestoreRollbackProcessFailpoint.newFontsReturnedToCandidate ||
      RestoreRollbackProcessFailpoint.previousFontsRestoredToLive => const {
        'operationKind',
        'sourcePath',
        'targetPath',
        'sourceKind',
      },
      RestoreRollbackProcessFailpoint.previousDatabaseParentRemovedDurable =>
        const {'operationKind', 'path', 'fullBarrier'},
      RestoreRollbackProcessFailpoint.settingsFirstRestored ||
      RestoreRollbackProcessFailpoint.settingsSecretRestored ||
      RestoreRollbackProcessFailpoint.settingsTargetOnlyRemoved => const {
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
        'rollbackOriginReceiptState',
        'triggerKind',
        'triggerPreferenceKey',
        'triggerFailureCount',
        'observedReceiptState',
        ...observationKeys,
      },
    );
    event.requireExactString('marker', control.failpoint.name);
    event.requireExactString('runId', runId);
    event.requireIdentifier('leaseInstanceId');
    event.requireExactString('rollbackOriginReceiptState', 'verified');
    event.requireExactString('triggerKind', 'repeatedTargetSetRejected');
    event.requireExactString(
      'triggerPreferenceKey',
      'restore_harness_${control.scenarioId}_primary',
    );
    if (event.requireInt('triggerFailureCount') != 1) {
      throw StateError('restore_rollback_harness_trigger_failure_count');
    }
    event.requireExactString(
      'observedReceiptState',
      _expectedRollbackObservedReceiptState(control.failpoint),
    );
    _validateRollbackObservation(event, control, runId: runId);
  }

  String _expectedRollbackObservedReceiptState(
    RestoreRollbackProcessFailpoint failpoint,
  ) {
    return switch (failpoint) {
      RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable =>
        'verified',
      RestoreRollbackProcessFailpoint.rollingBackReceiptPublished ||
      RestoreRollbackProcessFailpoint.newDatabaseReturnedToCandidate ||
      RestoreRollbackProcessFailpoint.previousDatabaseRestoredToLive ||
      RestoreRollbackProcessFailpoint.previousDatabaseParentRemovedDurable ||
      RestoreRollbackProcessFailpoint.newUploadReturnedToCandidate ||
      RestoreRollbackProcessFailpoint.previousUploadRestoredToLive ||
      RestoreRollbackProcessFailpoint.newImagesReturnedToCandidate ||
      RestoreRollbackProcessFailpoint.previousImagesRestoredToLive ||
      RestoreRollbackProcessFailpoint.newAvatarsReturnedToCandidate ||
      RestoreRollbackProcessFailpoint.previousAvatarsRestoredToLive ||
      RestoreRollbackProcessFailpoint.newFontsReturnedToCandidate ||
      RestoreRollbackProcessFailpoint.previousFontsRestoredToLive ||
      RestoreRollbackProcessFailpoint.settingsFirstRestored ||
      RestoreRollbackProcessFailpoint.settingsSecretRestored ||
      RestoreRollbackProcessFailpoint.settingsTargetOnlyRemoved ||
      RestoreRollbackProcessFailpoint.rolledBackReceiptTempDurable =>
        'rollingBack',
      RestoreRollbackProcessFailpoint.rolledBackReceiptPublished =>
        'rolledBack',
    };
  }

  void _validateRollbackObservation(
    _HarnessEvent event,
    RestoreRollbackProcessHarnessControl control, {
    required String runId,
  }) {
    final appData = p.normalize(p.absolute(control.appDataDirectory.path));
    final runDirectory = p.join(appData, '.kelivo_restore', 'run_$runId');
    final candidate = p.join(runDirectory, 'candidate');
    final previous = p.join(runDirectory, 'previous');
    final receipts = p.join(runDirectory, 'receipts');
    const databaseFileName = 'kelivo.sqlite';

    switch (control.failpoint) {
      case RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable:
        event.requireReceiptObservation(
          receiptDirectory: receipts,
          sequence: 5,
          state: 'rollingBack',
          published: false,
        );
      case RestoreRollbackProcessFailpoint.rollingBackReceiptPublished:
        event.requireReceiptObservation(
          receiptDirectory: receipts,
          sequence: 5,
          state: 'rollingBack',
          published: true,
        );
      case RestoreRollbackProcessFailpoint.newDatabaseReturnedToCandidate:
        event.requireRenameObservation(
          sourcePath: p.join(appData, databaseFileName),
          targetPath: p.join(candidate, 'database', databaseFileName),
          sourceKind: 'file',
        );
      case RestoreRollbackProcessFailpoint.previousDatabaseRestoredToLive:
        event.requireRenameObservation(
          sourcePath: p.join(previous, 'database', databaseFileName),
          targetPath: p.join(appData, databaseFileName),
          sourceKind: 'file',
        );
      case RestoreRollbackProcessFailpoint.previousDatabaseParentRemovedDurable:
        event.requireSyncObservation(
          operationKind: 'directorySyncAfter',
          path: previous,
          fullBarrier: true,
        );
      case RestoreRollbackProcessFailpoint.newUploadReturnedToCandidate ||
          RestoreRollbackProcessFailpoint.newImagesReturnedToCandidate ||
          RestoreRollbackProcessFailpoint.newAvatarsReturnedToCandidate ||
          RestoreRollbackProcessFailpoint.newFontsReturnedToCandidate:
        final root = _rollbackAssetRoot(control.failpoint);
        event.requireRenameObservation(
          sourcePath: p.join(appData, root),
          targetPath: p.join(candidate, root),
          sourceKind: 'directory',
        );
      case RestoreRollbackProcessFailpoint.previousUploadRestoredToLive ||
          RestoreRollbackProcessFailpoint.previousImagesRestoredToLive ||
          RestoreRollbackProcessFailpoint.previousAvatarsRestoredToLive ||
          RestoreRollbackProcessFailpoint.previousFontsRestoredToLive:
        final root = _rollbackAssetRoot(control.failpoint);
        event.requireRenameObservation(
          sourcePath: p.join(previous, root),
          targetPath: p.join(appData, root),
          sourceKind: 'directory',
        );
      case RestoreRollbackProcessFailpoint.settingsFirstRestored:
        event.requirePreferenceObservation(
          operationKind: 'preferenceSetAfter',
          preferenceKey: 'restore_harness_${control.scenarioId}_primary',
          valueType: 'String',
        );
      case RestoreRollbackProcessFailpoint.settingsSecretRestored:
        event.requirePreferenceObservation(
          operationKind: 'preferenceSetAfter',
          preferenceKey: 'restore_harness_${control.scenarioId}_secret_api_key',
          valueType: 'String',
        );
      case RestoreRollbackProcessFailpoint.settingsTargetOnlyRemoved:
        event.requirePreferenceObservation(
          operationKind: 'preferenceRemoveAfter',
          preferenceKey: 'restore_harness_${control.scenarioId}_target_only',
          valueType: '',
        );
      case RestoreRollbackProcessFailpoint.rolledBackReceiptTempDurable:
        event.requireReceiptObservation(
          receiptDirectory: receipts,
          sequence: 6,
          state: 'rolledBack',
          published: false,
        );
      case RestoreRollbackProcessFailpoint.rolledBackReceiptPublished:
        event.requireReceiptObservation(
          receiptDirectory: receipts,
          sequence: 6,
          state: 'rolledBack',
          published: true,
        );
    }
  }

  String _rollbackAssetRoot(RestoreRollbackProcessFailpoint failpoint) {
    return switch (failpoint) {
      RestoreRollbackProcessFailpoint.newUploadReturnedToCandidate ||
      RestoreRollbackProcessFailpoint.previousUploadRestoredToLive => 'upload',
      RestoreRollbackProcessFailpoint.newImagesReturnedToCandidate ||
      RestoreRollbackProcessFailpoint.previousImagesRestoredToLive => 'images',
      RestoreRollbackProcessFailpoint.newAvatarsReturnedToCandidate ||
      RestoreRollbackProcessFailpoint.previousAvatarsRestoredToLive =>
        'avatars',
      RestoreRollbackProcessFailpoint.newFontsReturnedToCandidate ||
      RestoreRollbackProcessFailpoint.previousFontsRestoredToLive => 'fonts',
      _ => throw StateError(
        'restore_rollback_harness_asset_failpoint:${failpoint.name}',
      ),
    };
  }

  void _validateRollbackRecoveryEvent(
    _HarnessEvent event,
    RestoreRollbackProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
    required String rollbackKillLeaseInstanceId,
  }) {
    event.requireCommon(
      control,
      process,
      expectedStatus: 'completed',
      phaseSpecificKeys: const {
        'runId',
        'receiptState',
        'outcome',
        'leaseInstanceId',
        'ackProcessId',
        'ackLeaseInstanceId',
        'ackExpected',
        'terminalReceiptChecksum',
        'coldAckChecksum',
        'settingsMutationAttempts',
        'triggerFailureCount',
      },
    );
    event.requireExactString('runId', runId);
    event.requireExactString('receiptState', 'rolledBack');
    event.requireExactString('outcome', 'coldRestartRequired');
    final leaseInstanceId = event.requireIdentifier('leaseInstanceId');
    if (leaseInstanceId == rollbackKillLeaseInstanceId) {
      throw StateError('restore_rollback_harness_recovery_lease_reused');
    }
    if (event.requireProcessId('ackProcessId') != event.pid) {
      throw StateError('restore_rollback_harness_recovery_ack_pid');
    }
    if (event.requireIdentifier('ackLeaseInstanceId') != leaseInstanceId) {
      throw StateError('restore_rollback_harness_recovery_ack_lease');
    }
    event.requireExactString('ackExpected', 'before');
    event.requireSha256('terminalReceiptChecksum');
    event.requireSha256('coldAckChecksum');
    if (event.requireInt('settingsMutationAttempts') < 1) {
      throw StateError('restore_rollback_harness_recovery_settings_mutation');
    }
    final expectedTriggerFailures =
        control.failpoint ==
            RestoreRollbackProcessFailpoint.rollingBackReceiptTempDurable
        ? 1
        : 0;
    if (event.requireInt('triggerFailureCount') != expectedTriggerFailures) {
      throw StateError('restore_rollback_harness_recovery_trigger_count');
    }
  }

  void _validateRollbackVerifyEvent(
    _HarnessEvent event,
    RestoreRollbackProcessHarnessControl control,
    _ManagedProcess process, {
    required String runId,
    required int expectedAckProcessId,
    required String expectedAckLeaseInstanceId,
    required String expectedAckChecksum,
    required Set<String> priorLeaseInstanceIds,
  }) {
    event.requireCommon(
      control,
      process,
      expectedStatus: 'completed',
      phaseSpecificKeys: const {
        'runId',
        'receiptState',
        'gateResult',
        'archiveState',
        'observedAckProcessId',
        'observedAckLeaseInstanceId',
        'observedAckChecksum',
        'leaseInstanceId',
        'settingsMutationAttempts',
      },
    );
    event.requireExactString('runId', runId);
    event.requireExactString('receiptState', 'rolledBack');
    event.requireExactString('gateResult', 'rolledBack');
    event.requireExactString('archiveState', 'archived');
    if (event.requireProcessId('observedAckProcessId') !=
        expectedAckProcessId) {
      throw StateError('restore_rollback_harness_verify_ack_pid');
    }
    if (event.requireIdentifier('observedAckLeaseInstanceId') !=
        expectedAckLeaseInstanceId) {
      throw StateError('restore_rollback_harness_verify_ack_lease');
    }
    if (event.requireSha256('observedAckChecksum') != expectedAckChecksum) {
      throw StateError('restore_rollback_harness_verify_ack_checksum');
    }
    final leaseInstanceId = event.requireIdentifier('leaseInstanceId');
    if (priorLeaseInstanceIds.length != 2 ||
        priorLeaseInstanceIds.contains(leaseInstanceId) ||
        leaseInstanceId == expectedAckLeaseInstanceId) {
      throw StateError('restore_rollback_harness_verify_lease_reused');
    }
    if (event.requireInt('settingsMutationAttempts') != 0) {
      throw StateError('restore_rollback_harness_verify_settings_mutation');
    }
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
      sink.writeln('\n[${process.phaseName}] ${process.command.join(' ')}');
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
      RestoreHarnessControl control,
      _ManagedProcess process,
    );

int _controlVersion(RestoreHarnessControl control) => switch (control) {
  RestoreProcessHarnessControl() => RestoreProcessHarnessControl.version,
  RestoreTerminalProcessHarnessControl() =>
    RestoreTerminalProcessHarnessControl.version,
  RestoreRollbackProcessHarnessControl() =>
    RestoreRollbackProcessHarnessControl.version,
  RestoreRolledBackTerminalProcessHarnessControl() =>
    RestoreRolledBackTerminalProcessHarnessControl.version,
  _ => throw StateError('restore_harness_control_runtime_type'),
};

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
    RestoreHarnessControl control,
    _ManagedProcess process, {
    required String expectedStatus,
    required Set<String> phaseSpecificKeys,
  }) {
    final expectedKeys = {..._commonKeys, ...phaseSpecificKeys};
    if (json.length != expectedKeys.length ||
        !json.keys.toSet().containsAll(expectedKeys)) {
      throw FormatException(
        'restore_harness_event_fields:${control.phaseName}',
      );
    }
    if (json['format'] != restoreHarnessFormat ||
        json['version'] != _controlVersion(control) ||
        json['generation'] != control.generation ||
        json['matrixRunId'] != control.matrixRunId ||
        json['scenario'] != control.scenario ||
        json['scenarioId'] != control.scenarioId ||
        json['phase'] != control.phaseName ||
        json['failpoint'] != control.failpointName ||
        json['status'] != expectedStatus) {
      throw FormatException(
        'restore_harness_event_binding:${control.phaseName}',
      );
    }
    if (pid == process.process.pid || pid == _hostProcessId) {
      throw FormatException(
        'restore_harness_event_process:${control.phaseName}',
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

  int requireProcessId(String key) {
    final value = requireInt(key);
    if (value <= 1) {
      throw FormatException('restore_harness_event_process_id:$key');
    }
    return value;
  }

  String requireSha256(String key) {
    final value = requireString(key);
    if (!_sha256Pattern.hasMatch(value)) {
      throw FormatException('restore_harness_event_sha256:$key');
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
    required this.phaseName,
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

  final String phaseName;
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
        'restore_harness_outer_timeout:$phaseName',
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
        throw StateError('restore_harness_outer_kill:$phaseName');
      }
    }
    await exited.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'restore_harness_outer_cleanup_timeout:$phaseName',
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
