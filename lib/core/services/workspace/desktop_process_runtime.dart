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

  Future<_ShellSpec?>? _shellFuture;

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
    controller.onCancel = () => cancel(request.runId);
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
      // Explorer can return a nonzero exit code after opening the location.
      // Only a failure to start the process should fail this action.
      await Process.start('explorer', args, mode: ProcessStartMode.detached);
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
    StreamSubscription<List<int>>? stdoutSubscription;
    StreamSubscription<List<int>>? stderrSubscription;
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

      final launched = await _startProcess(spec, request);
      final process = launched.process;
      started = true;
      final live = _LiveRun(process, processGroup: launched.processGroup);
      _live[request.runId] = live;

      if (_pendingCancel.remove(request.runId) ||
          request.isCancelled?.call() == true) {
        live.cancelled = true;
        unawaited(_killTree(live));
      }

      controller.add(CommandStarted(pid: live.processGroup ?? process.pid));

      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();
      stdoutSubscription = launched.stdout.listen(
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
      stderrSubscription = process.stderr.listen(
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

      if (live.processGroup != null && !live.cancelled) {
        // The launcher waits until its group is registered before running any
        // user code, so a cancellation during startup cannot lose its children.
        process.stdin.writeln();
        await process.stdin.flush();
      }

      final code = await process.exitCode;
      live.processExited = true;
      await process.stdin.close();
      // Background children can retain these pipes after the shell exits.
      // The process group still owns those children after the shell exits.
      // Keep the deadline active until their output drains or they are stopped.
      await Future.any<void>([
        Future.wait<void>([stdoutDone.future, stderrDone.future]),
        live.stopped.future,
      ]);
      await live.stopping;
      live.finished = true;

      final timedOut = live.timedOut;
      emitExit(exitCode: code, timedOut: timedOut, cancelled: live.cancelled);
    } catch (error, stack) {
      if (!started && !emittedExit && !controller.isClosed) {
        controller.addError(error, stack);
      } else {
        emitExit(exitCode: -1, timedOut: false, cancelled: false);
      }
    } finally {
      timer?.cancel();
      await stdoutSubscription?.cancel();
      await stderrSubscription?.cancel();
      _starting.remove(request.runId);
      _pendingCancel.remove(request.runId);
      _live.remove(request.runId);
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  Future<({Process process, Stream<List<int>> stdout, int? processGroup})>
  _startProcess(_ShellSpec spec, CommandRequest request) async {
    final unix = Platform.isMacOS || Platform.isLinux;
    final process = await Process.start(
      unix ? '/bin/bash' : spec.executable,
      unix
          ? [
              '--noprofile',
              '--norc',
              '-p',
              '-c',
              _unixLauncher,
              'kelivo-shell',
              spec.executable,
              ...spec.arguments(request.command),
            ]
          : spec.arguments(request.command),
      workingDirectory: request.cwd,
      environment: <String, String>{...Platform.environment, ...request.env},
      includeParentEnvironment: false,
    );
    if (!unix) {
      return (process: process, stdout: process.stdout, processGroup: null);
    }

    final output = StreamController<List<int>>();
    final group = Completer<int>();
    final header = <int>[];
    final subscription = process.stdout.listen(
      (chunk) {
        if (group.isCompleted) {
          output.add(chunk);
          return;
        }
        final newline = chunk.indexOf(10);
        header.addAll(newline < 0 ? chunk : chunk.sublist(0, newline));
        if (header.length <= 20 && newline < 0) return;
        final id = int.tryParse(ascii.decode(header, allowInvalid: true));
        if (newline < 0 || id == null || id <= 1) {
          group.completeError(StateError('Shell process group did not start'));
          return;
        }
        group.complete(id);
        if (newline + 1 < chunk.length) {
          output.add(chunk.sublist(newline + 1));
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!group.isCompleted) {
          group.completeError(error, stack);
        } else {
          output.addError(error, stack);
        }
      },
      onDone: () {
        if (!group.isCompleted) {
          group.completeError(StateError('Shell process group did not start'));
        }
        unawaited(output.close());
      },
    );
    output.onCancel = subscription.cancel;
    output.onPause = subscription.pause;
    output.onResume = subscription.resume;
    try {
      return (
        process: process,
        stdout: output.stream,
        processGroup: await group.future,
      );
    } catch (_) {
      // Closing stdin also releases a child still waiting at the startup gate.
      await process.stdin.close();
      process.kill();
      await subscription.cancel();
      unawaited(output.close());
      await process.stderr.drain<void>();
      await process.exitCode;
      rethrow;
    }
  }

  // Bash job control creates a separate process group without detaching the
  // launcher, so dart:io still reports the selected shell's actual exit code.
  // -p keeps BASH_ENV and exported shell options out of this control protocol;
  // the selected user shell is launched with its original arguments and env.
  static const _unixLauncher = r'''
set -m
(
  set +m
  IFS= read -r _ || exit 125
  exec "$@"
) <&0 &
printf '%s\n' "$!"
wait "$!" 2>/dev/null
''';

  Future<void> _killTree(_LiveRun live) => live.stopping ??= _stopProcess(live);

  Future<void> _stopProcess(_LiveRun live) async {
    try {
      final group = live.processGroup;
      if (group != null) {
        await _killUnixGroup(group);
        return;
      }
      // Windows taskkill identifies its tree by the still-live parent PID.
      if (live.processExited) return;
      final pid = live.process.pid;
      if (Platform.isWindows) {
        try {
          await Process.run('taskkill', ['/T', '/F', '/PID', '$pid']);
        } catch (_) {
          live.process.kill();
        }
        return;
      }
    } finally {
      try {
        await live.process.stdin.close();
      } catch (_) {
        // The child can close its input as it is terminated.
      }
      live.stopped.complete();
    }
  }

  Future<void> _killUnixGroup(int group) async {
    if (!Process.killPid(-group, ProcessSignal.sigterm)) return;
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (await _unixGroupAlive(group)) {
      if (!DateTime.now().isBefore(deadline)) {
        Process.killPid(-group, ProcessSignal.sigkill);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<bool> _unixGroupAlive(int group) async {
    // -g selects different things on BSD and GNU ps. Read the PGID column on
    // both platforms, excluding zombies that are already unable to run.
    final result = await Process.run('/bin/ps', ['-axo', 'pgid=,stat=']);
    if (result.exitCode != 0) return true;
    for (final line in result.stdout.toString().split('\n')) {
      final fields = line.trim().split(RegExp(r'\s+'));
      if (fields.length >= 2 &&
          fields[0] == '$group' &&
          !fields[1].startsWith('Z')) {
        return true;
      }
    }
    return false;
  }

  Future<_ShellSpec?> _shell() => _shellFuture ??= _resolveShell();

  Future<_ShellSpec?> _resolveShell() async {
    if (Platform.isWindows) {
      return _resolveWindowsShell();
    }
    if (Platform.isMacOS || Platform.isLinux) {
      if (!File('/bin/bash').existsSync()) return null;
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
        await Process.start(
          wt,
          ['-d', hostDir],
          workingDirectory: hostDir,
          mode: ProcessStartMode.detached,
        );
        return;
      } catch (_) {}
    }
    final cmd = await _which('cmd') ?? 'cmd';
    // Inherit the directory instead of passing a quoted cd command through
    // both Dart's Windows argument escaping and cmd's command parser.
    await Process.start(
      cmd,
      ['/d', '/c', 'start', '', 'cmd', '/d'],
      workingDirectory: hostDir,
      mode: ProcessStartMode.detached,
    );
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
  _LiveRun(this.process, {this.processGroup});

  final Process process;
  final int? processGroup;
  bool cancelled = false;
  bool timedOut = false;
  Future<void>? stopping;
  final stopped = Completer<void>();
  bool processExited = false;
  bool finished = false;
}

class _ShellSpec {
  const _ShellSpec(this.executable, this.arguments);

  final String executable;
  final List<String> Function(String command) arguments;
}
