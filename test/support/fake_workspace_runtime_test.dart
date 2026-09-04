import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

import 'fake_workspace_runtime.dart';

void main() {
  test('records requests and replays scripted events', () async {
    final runtime = FakeWorkspaceRuntime();
    runtime.enqueue('r1', [
      const CommandStarted(pid: 42),
      CommandOutput(
        OutputStreamKind.stdout,
        Uint8List.fromList(utf8.encode('hi\n')),
      ),
      const CommandExited(
        exitCode: 0,
        timedOut: false,
        cancelled: false,
        interrupted: false,
        duration: Duration(milliseconds: 5),
      ),
    ]);

    final events = await runtime
        .run(CommandRequest(runId: 'r1', command: 'echo hi', cwd: '/workspace'))
        .toList();

    expect(runtime.requests.single.command, 'echo hi');
    expect(events[0], isA<CommandStarted>());
    expect((events[0] as CommandStarted).pid, 42);
    expect(events[1], isA<CommandOutput>());
    expect(events.last, isA<CommandExited>());
  });

  test('cancel replaces the remaining script with a cancelled exit', () async {
    final runtime = FakeWorkspaceRuntime();
    runtime.enqueue('r2', [
      const CommandStarted(pid: 1),
      const CommandExited(
        exitCode: 0,
        timedOut: false,
        cancelled: false,
        interrupted: false,
        duration: Duration.zero,
      ),
    ]);
    await runtime.cancel('r2');
    final events = await runtime
        .run(CommandRequest(runId: 'r2', command: 'sleep 1', cwd: '/tmp'))
        .toList();
    final exit = events.single as CommandExited;
    expect(exit.cancelled, isTrue);
    expect(exit.exitCode, 137);
  });

  test('useRealProcess runs echo on macOS/Linux', () async {
    if (!(Platform.isMacOS || Platform.isLinux)) return;
    final runtime = FakeWorkspaceRuntime(useRealProcess: true);
    final events = await runtime
        .run(
          CommandRequest(
            runId: 'echo1',
            command: 'printf hello',
            cwd: Directory.systemTemp.path,
            timeout: const Duration(seconds: 5),
          ),
        )
        .toList();
    expect(events.first, isA<CommandStarted>());
    final chunks = events.whereType<CommandOutput>();
    final text = utf8.decode([for (final chunk in chunks) ...chunk.bytes]);
    expect(text, contains('hello'));
    final exit = events.last as CommandExited;
    expect(exit.exitCode, 0);
    expect(exit.cancelled, isFalse);
  });

  test('status reports the fake engine', () async {
    final status = await FakeWorkspaceRuntime().status();
    expect(status.engine, 'fake');
    expect(status.ready, isTrue);
    expect(FakeWorkspaceRuntime().supportsPty, isFalse);
    expect(
      () => FakeWorkspaceRuntime().openInSystemTerminal('/tmp'),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
