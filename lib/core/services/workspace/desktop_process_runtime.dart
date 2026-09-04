import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'workspace_runtime.dart';

/// Native host-process [WorkspaceRuntime] for macOS, Linux, and Windows.
///
/// Commands run as a fresh shell process (not a sandbox). Mounts are ignored.
class DesktopProcessRuntime extends WorkspaceRuntime {
  final Map<String, _LiveRun> _live = <String, _LiveRun>{};
  final Set<String> _starting = <String>{};
  final Set<String> _pendingCancel = <String>{};
  final Map<String, String?> _whichCache = <String, String?>{};

  _ShellSpec? _cachedShell;
  bool _resolvedShell = false;

  @override
  bool get supportsPty => false;

  @override
  bool get supportsSystemTerminal => true;

  @override
  Future<RuntimeStatus> status() async {
    final shell = await _shell();
    if (shell == null) {
      return const RuntimeStatus(
        ready: false,
        reason: 'Shell binary not found',
        engine: 'process',
        sandboxed: false,
      );
    }
    return const RuntimeStatus(
      ready: true,
      engine: 'process',
      sandboxed: false,
    );
  }

  @override
  Stream<CommandEvent> run(CommandRequest request) {
    final controller = StreamController<CommandEvent>();
    unawaited(_execute(request, controller));
    return controller.stream;
  }

  @override
  Future<void> cancel(String runId) async {
    final live = _live[runId];
    if (live != null) {
      live.cancelled = true;
      await _killTree(live);
      return;
    }
    if (_starting.contains(runId)) {
      _pendingCancel.add(runId);
    }
  }

  @override
  Future<void> openInSystemTerminal(String hostDir) async {
    if (Platform.isMacOS) {
      final result = await Process.run('open', ['-a', 'Terminal', hostDir]);
      if (result.exitCode != 0) {
        throw ProcessException(
          'open',
          ['-a', 'Terminal', hostDir],
          result.stderr.toString(),
          result.exitCode,
        );
      }
      return;
    }
    if (Platform.isLinux) {
      await _openLinuxTerminal(hostDir);
      return;
    }
    if (Platform.isWindows) {
      await _openWindowsTerminal(hostDir);
      return;
    }
    throw UnsupportedError(
      'System terminal is only supported on macOS, Linux, and Windows',
    );
  }

  /// Reveals [hostPath] in the platform file manager.
  @override
  Future<void> revealInFileManager(String hostPath) async {
    final isDir = FileSystemEntity.isDirectorySync(hostPath);
    if (Platform.isMacOS) {
      final args = isDir ? <String>[hostPath] : <String>['-R', hostPath];
      final result = await Process.run('open', args);
      if (result.exitCode != 0) {
        throw ProcessException(
          'open',
          args,
          result.stderr.toString(),
          result.exitCode,
        );
      }
      return;
    }
    if (Platform.isLinux) {
      final dir = isDir ? hostPath : p.dirname(hostPath);
      final result = await Process.run('xdg-open', [dir]);
      if (result.exitCode != 0) {
        throw ProcessException(
          'xdg-open',
          [dir],
          result.stderr.toString(),
          result.exitCode,
        );
      }
      return;
    }
    if (Platform.isWindows) {
      final args = isDir ? <String>[hostPath] : <String>['/select,$hostPath'];
      final result = await Process.run('explorer', args);
      if (result.exitCode != 0) {
        throw ProcessException(
          'explorer',
          args,
          result.stderr.toString(),
          result.exitCode,
        );
      }
      return;
    }
    throw UnsupportedError(
      'File manager reveal is only supported on macOS, Linux, and Windows',
    );
  }

  Future<void> _execute(
    CommandRequest request,
    StreamController<CommandEvent> controller,
  ) async {
    final watch = Stopwatch()..start();
    Timer? timer;
    var emittedExit = false;
    var started = false;

    void emitExit({
      required int exitCode,
      required bool timedOut,
      required bool cancelled,
    }) {
      if (emittedExit || controller.isClosed) return;
      emittedExit = true;
      controller.add(
        CommandExited(
          exitCode: exitCode,
          timedOut: timedOut,
          cancelled: cancelled && !timedOut,
          interrupted: false,
          duration: watch.elapsed,
        ),
      );
    }

    _starting.add(request.runId);
    try {
      final spec = await _shell();
      if (spec == null) {
        throw StateError('Shell binary not found');
      }
      if (_pendingCancel.remove(request.runId)) {
        emitExit(exitCode: -1, timedOut: false, cancelled: true);
        return;
      }

      final process = await Process.start(
        spec.executable,
        spec.arguments(request.command),
        workingDirectory: request.cwd,
        environment: <String, String>{...Platform.environment, ...request.env},
        includeParentEnvironment: false,
      );
      started = true;
      final live = _LiveRun(process);
      _live[request.runId] = live;

      if (_pendingCancel.remove(request.runId)) {
        live.cancelled = true;
        unawaited(_killTree(live));
      }

      controller.add(CommandStarted(pid: process.pid));

      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();
      process.stdout.listen(
        (data) {
          if (controller.isClosed) return;
          controller.add(
            CommandOutput(OutputStreamKind.stdout, Uint8List.fromList(data)),
          );
        },
        onDone: () {
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
        onError: (_) {
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
        cancelOnError: false,
      );
      process.stderr.listen(
        (data) {
          if (controller.isClosed) return;
          controller.add(
            CommandOutput(OutputStreamKind.stderr, Uint8List.fromList(data)),
          );
        },
        onDone: () {
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
        onError: (_) {
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
        cancelOnError: false,
      );

      timer = Timer(request.timeout, () {
        if (live.finished) return;
        live.timedOut = true;
        unawaited(_killTree(live));
      });

      final code = await _waitForExitCode(process);
      live.finished = true;
      await Future.wait<void>([stdoutDone.future, stderrDone.future]);

      final timedOut = live.timedOut;
      emitExit(
        exitCode: code ?? -1,
        timedOut: timedOut,
        cancelled: live.cancelled,
      );
    } catch (error, stack) {
      if (!started && !emittedExit && !controller.isClosed) {
        controller.addError(error, stack);
      } else {
        emitExit(exitCode: -1, timedOut: false, cancelled: false);
      }
    } finally {
      timer?.cancel();
      _starting.remove(request.runId);
      _pendingCancel.remove(request.runId);
      _live.remove(request.runId);
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  Future<int?> _waitForExitCode(Process process) async {
    try {
      return await process.exitCode.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      return null;
    }
  }

  Future<void> _killTree(_LiveRun live) async {
    if (live.killing) return;
    live.killing = true;
    final pid = live.process.pid;
    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/T', '/F', '/PID', '$pid']);
      } catch (_) {
        live.process.kill();
      }
      return;
    }
    await _killUnixTree(pid);
  }

  Future<void> _killUnixTree(int rootPid) async {
    final pids = await _collectUnixTree(rootPid);
    for (final pid in pids) {
      Process.killPid(pid, ProcessSignal.sigterm);
    }
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      var anyAlive = false;
      for (final pid in pids) {
        if (await _unixAlive(pid)) {
          anyAlive = true;
          break;
        }
      }
      if (!anyAlive) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final survivors = await _collectUnixTree(rootPid);
    for (final pid in survivors) {
      Process.killPid(pid, ProcessSignal.sigkill);
    }
  }

  Future<List<int>> _collectUnixTree(int rootPid) async {
    final found = <int>[];
    final seen = <int>{rootPid};
    final queue = <int>[rootPid];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      var children = const <int>[];
      try {
        final result = await Process.run('pgrep', ['-P', '$current']);
        if (result.exitCode == 0) {
          children = _parsePids(result.stdout.toString());
        }
      } catch (_) {}
      for (final child in children) {
        if (seen.add(child)) {
          found.add(child);
          queue.add(child);
        }
      }
    }
    found.add(rootPid);
    return found;
  }

  List<int> _parsePids(String stdout) {
    final pids = <int>[];
    for (final line in stdout.split(RegExp(r'\s+'))) {
      final pid = int.tryParse(line.trim());
      if (pid != null) pids.add(pid);
    }
    return pids;
  }

  Future<bool> _unixAlive(int pid) async {
    try {
      final result = await Process.run('kill', ['-0', '$pid']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<_ShellSpec?> _shell() async {
    if (_resolvedShell) return _cachedShell;
    _resolvedShell = true;
    _cachedShell = await _resolveShell();
    return _cachedShell;
  }

  Future<_ShellSpec?> _resolveShell() async {
    if (Platform.isWindows) {
      return _resolveWindowsShell();
    }
    if (Platform.isMacOS || Platform.isLinux) {
      final fromEnv = Platform.environment['SHELL'];
      if (fromEnv != null && fromEnv.isNotEmpty && File(fromEnv).existsSync()) {
        return _ShellSpec(fromEnv, _unixArgs);
      }
      if (File('/bin/sh').existsSync()) {
        return _ShellSpec('/bin/sh', _unixArgs);
      }
      return null;
    }
    return null;
  }

  List<String> _unixArgs(String command) => <String>['-lc', command];

  Future<_ShellSpec?> _resolveWindowsShell() async {
    final pwsh = await _which('pwsh');
    if (pwsh != null) {
      return _ShellSpec(pwsh, _powerShellArgs);
    }
    final powershell = await _which('powershell');
    if (powershell != null) {
      return _ShellSpec(powershell, _powerShellArgs);
    }
    final cmd = await _which('cmd');
    if (cmd != null) {
      return _ShellSpec(cmd, _cmdArgs);
    }
    return null;
  }

  List<String> _powerShellArgs(String command) {
    return <String>[
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-EncodedCommand',
      _powerShellEncodedCommand(command),
    ];
  }

  List<String> _cmdArgs(String command) {
    return <String>['/d', '/s', '/c', 'chcp 65001>nul && $command'];
  }

  String _powerShellEncodedCommand(String command) {
    const preamble =
        '[Console]::OutputEncoding=[Text.Encoding]::UTF8; \$OutputEncoding=[Text.Encoding]::UTF8; ';
    final script = '$preamble$command';
    final units = script.codeUnits;
    final bytes = Uint8List(units.length * 2);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < units.length; i++) {
      data.setUint16(i * 2, units[i], Endian.little);
    }
    return base64Encode(bytes);
  }

  Future<void> _openLinuxTerminal(String hostDir) async {
    final candidates = <({String name, List<String> args})>[
      (name: 'x-terminal-emulator', args: const <String>[]),
      (name: 'gnome-terminal', args: <String>['--working-directory=$hostDir']),
      (name: 'konsole', args: <String>['--workdir', hostDir]),
      (name: 'xfce4-terminal', args: <String>['--working-directory=$hostDir']),
      (name: 'alacritty', args: <String>['--working-directory', hostDir]),
      (name: 'kitty', args: <String>['-d', hostDir]),
      (
        name: 'xterm',
        args: <String>[
          '-e',
          'sh',
          '-c',
          'cd ${_shSingleQuote(hostDir)} && exec ${_shSingleQuote(Platform.environment['SHELL'] ?? '/bin/sh')}',
        ],
      ),
    ];
    for (final candidate in candidates) {
      final exe = await _which(candidate.name);
      if (exe == null) continue;
      try {
        await Process.start(
          exe,
          candidate.args,
          workingDirectory: hostDir,
          mode: ProcessStartMode.detached,
        );
        return;
      } catch (_) {
        continue;
      }
    }
    throw UnsupportedError(
      'No supported terminal emulator found. Install x-terminal-emulator, '
      'gnome-terminal, konsole, xfce4-terminal, alacritty, kitty, or xterm.',
    );
  }

  Future<void> _openWindowsTerminal(String hostDir) async {
    final wt = await _which('wt');
    if (wt != null) {
      try {
        await Process.start(wt, [
          '-d',
          hostDir,
        ], mode: ProcessStartMode.detached);
        return;
      } catch (_) {}
    }
    final cmd = await _which('cmd') ?? 'cmd';
    await Process.start(cmd, [
      '/c',
      'start',
      '',
      'cmd',
      '/K',
      'cd /d "$hostDir"',
    ], mode: ProcessStartMode.detached);
  }

  Future<String?> _which(String name) async {
    if (_whichCache.containsKey(name)) return _whichCache[name];
    final found = await _lookupExecutable(name);
    _whichCache[name] = found;
    return found;
  }

  Future<String?> _lookupExecutable(String name) async {
    if (Platform.isWindows) {
      try {
        final result = await Process.run('where', [name]);
        if (result.exitCode == 0) {
          for (final line in result.stdout.toString().split(RegExp(r'\r?\n'))) {
            final path = line.trim();
            if (path.isNotEmpty && File(path).existsSync()) return path;
          }
        }
      } catch (_) {}
    } else {
      try {
        final result = await Process.run('which', [name]);
        if (result.exitCode == 0) {
          final path = result.stdout.toString().trim().split('\n').first.trim();
          if (path.isNotEmpty && File(path).existsSync()) return path;
        }
      } catch (_) {}
    }
    return _scanPath(name);
  }

  String? _scanPath(String name) {
    final dirs = (Platform.environment['PATH'] ?? '').split(
      Platform.isWindows ? ';' : ':',
    );
    final names = <String>[name];
    if (Platform.isWindows) {
      final exts = (Platform.environment['PATHEXT'] ?? '.EXE;.CMD;.BAT;.COM')
          .split(';')
          .where((e) => e.isNotEmpty);
      if (!name.contains('.')) {
        for (final ext in exts) {
          names.add('$name$ext');
        }
      }
    }
    for (final dir in dirs) {
      if (dir.isEmpty) continue;
      for (final candidateName in names) {
        final candidate = p.join(dir, candidateName);
        if (File(candidate).existsSync()) return candidate;
      }
    }
    if (Platform.isWindows && name.toLowerCase() == 'cmd') {
      final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';
      final cmd = p.join(root, 'System32', 'cmd.exe');
      if (File(cmd).existsSync()) return cmd;
    }
    return null;
  }

  String _shSingleQuote(String value) {
    return "'${value.replaceAll("'", "'\\''")}'";
  }
}

class _LiveRun {
  _LiveRun(this.process);

  final Process process;
  bool cancelled = false;
  bool timedOut = false;
  bool killing = false;
  bool finished = false;
}

class _ShellSpec {
  const _ShellSpec(this.executable, this.arguments);

  final String executable;
  final List<String> Function(String command) arguments;
}
