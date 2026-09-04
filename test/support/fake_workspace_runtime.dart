import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

/// Test double that records [CommandRequest]s and either replays scripted
/// [CommandEvent]s or runs a real `/bin/sh -c` process on macOS/Linux.
class FakeWorkspaceRuntime extends WorkspaceRuntime {
  FakeWorkspaceRuntime({this.useRealProcess = false});

  /// When true (macOS/Linux only), [run] executes [CommandRequest.command]
  /// via `Process.start`. Other platforms fall back to scripted events.
  bool useRealProcess;

  final List<CommandRequest> requests = <CommandRequest>[];

  final Map<String, List<CommandEvent>> _scripted =
      <String, List<CommandEvent>>{};
  final Set<String> _cancelled = <String>{};
  final Map<String, Process> _live = <String, Process>{};

  void enqueue(String runId, Iterable<CommandEvent> events) {
    _scripted[runId] = List<CommandEvent>.from(events);
  }

  @override
  Future<RuntimeStatus> status() async {
    return const RuntimeStatus(ready: true, engine: 'fake', sandboxed: false);
  }

  @override
  Stream<CommandEvent> run(CommandRequest request) {
    requests.add(request);
    if (useRealProcess && (Platform.isMacOS || Platform.isLinux)) {
      return _runReal(request);
    }
    return _runScripted(request);
  }

  Stream<CommandEvent> _runScripted(CommandRequest request) async* {
    final events =
        _scripted.remove(request.runId) ??
        <CommandEvent>[
          const CommandStarted(pid: 0),
          const CommandExited(
            exitCode: 0,
            timedOut: false,
            cancelled: false,
            interrupted: false,
            duration: Duration.zero,
          ),
        ];
    final watch = Stopwatch()..start();
    for (final event in events) {
      if (_cancelled.contains(request.runId)) {
        yield CommandExited(
          exitCode: 137,
          timedOut: false,
          cancelled: true,
          interrupted: false,
          duration: watch.elapsed,
        );
        return;
      }
      yield event;
    }
  }

  Stream<CommandEvent> _runReal(CommandRequest request) {
    final controller = StreamController<CommandEvent>();
    unawaited(() async {
      try {
        final watch = Stopwatch()..start();
        final process = await Process.start(
          '/bin/sh',
          ['-c', request.command],
          workingDirectory: request.cwd,
          environment: request.env.isEmpty ? null : request.env,
        );
        _live[request.runId] = process;
        controller.add(CommandStarted(pid: process.pid));

        var timedOut = false;
        final timer = Timer(request.timeout, () {
          timedOut = true;
          process.kill(ProcessSignal.sigterm);
        });

        var pending = 2;
        final closed = Completer<void>();
        void onDone() {
          pending--;
          if (pending == 0 && !closed.isCompleted) closed.complete();
        }

        process.stdout.listen((data) {
          controller.add(
            CommandOutput(OutputStreamKind.stdout, Uint8List.fromList(data)),
          );
        }, onDone: onDone);
        process.stderr.listen((data) {
          controller.add(
            CommandOutput(OutputStreamKind.stderr, Uint8List.fromList(data)),
          );
        }, onDone: onDone);

        if (_cancelled.contains(request.runId)) {
          process.kill(ProcessSignal.sigterm);
        }

        final code = await process.exitCode;
        await closed.future;
        timer.cancel();
        _live.remove(request.runId);
        final cancelled = _cancelled.contains(request.runId) && !timedOut;
        controller.add(
          CommandExited(
            exitCode: code,
            timedOut: timedOut,
            cancelled: cancelled,
            interrupted: false,
            duration: watch.elapsed,
          ),
        );
        await controller.close();
      } catch (error, stack) {
        if (!controller.isClosed) {
          controller.addError(error, stack);
          await controller.close();
        }
      }
    }());
    return controller.stream;
  }

  @override
  Future<void> cancel(String runId) async {
    _cancelled.add(runId);
    _live[runId]?.kill(ProcessSignal.sigterm);
  }
}
