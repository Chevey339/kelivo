import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../utils/windows_explorer.dart';
import 'workspace_runtime.dart';
import 'desktop_shell.dart';
import 'desktop_process.dart';

/// Native host-process [WorkspaceRuntime] for macOS, Linux, and Windows.
///
/// Commands run as a fresh shell process (not a sandbox). Mounts are ignored.
class DesktopProcessRuntime extends WorkspaceRuntime {
  DesktopProcessRuntime({
    this.loadShellPath,
    DesktopShellResolver? shellResolver,
  }) : shellResolver = shellResolver ?? DesktopShellResolver();

  final Future<String> Function()? loadShellPath;
  final DesktopShellResolver shellResolver;
  String? _resolvedPath;

  void refreshShell() {
    _shellFuture = null;
    _whichCache.clear();
  }

  final Map<String, _LiveRun> _live = <String, _LiveRun>{};
  final Set<String> _starting = <String>{};
  final Set<String> _pendingCancel = <String>{};
  final Map<String, String?> _whichCache = <String, String?>{};

  Future<DesktopShell>? _shellFuture;

  @override
  bool get supportsPty => false;

  @override
  bool get supportsSystemTerminal => true;

  @override
  bool get supportsFileManager => true;

  @override
  Future<RuntimeStatus> status() async {
    try {
      final shell = await _shell();
      return RuntimeStatus(
        ready: true,
        engine: 'process',
        sandboxed: false,
        shell: shell,
      );
    } on Exception catch (error) {
      return RuntimeStatus(
        ready: false,
        reason: error.toString(),
        engine: 'process',
        sandboxed: false,
      );
    }
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
      final args = windowsExplorerArguments(hostPath, isDirectory: isDir);
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
      final spec = request.shell ?? await _shell();
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
  _startProcess(DesktopShell spec, CommandRequest request) =>
      startDesktopProcess(
        spec.executable,
        spec.arguments(request.command),
        workingDirectory: request.cwd,
        environment: <String, String>{...Platform.environment, ...request.env},
        includeParentEnvironment: false,
      );

  Future<void> _killTree(_LiveRun live) => live.stopping ??= _stopProcess(live);

  Future<void> _stopProcess(_LiveRun live) async {
    try {
      final group = live.processGroup;
      if (group != null) {
        await stopDesktopProcessGroup(group);
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

  Future<DesktopShell> _shell() async {
    final path = (await loadShellPath?.call() ?? '').trim();
    if (_resolvedPath != path) {
      _resolvedPath = path;
      _shellFuture = null;
    }
    return _shellFuture ??= shellResolver.resolve(path);
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
    final found = await shellResolver.findExecutable(name);
    _whichCache[name] = found;
    return found;
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
