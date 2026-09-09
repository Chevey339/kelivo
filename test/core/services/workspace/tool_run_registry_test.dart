import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/workspace/tool_run_registry.dart';

void main() {
  test('coalesces notifications to once per 50 ms and flushes on complete', () {
    fakeAsync((async) {
      final run = ToolRun(toolCallId: 'c1', toolName: 'shell', command: 'echo');
      var notifications = 0;
      run.addListener(() => notifications++);

      run.appendStdout(Uint8List.fromList(utf8.encode('a\n')));
      run.appendStdout(Uint8List.fromList(utf8.encode('b\n')));
      expect(notifications, 0);

      async.elapse(const Duration(milliseconds: 49));
      expect(notifications, 0);
      async.elapse(const Duration(milliseconds: 1));
      expect(notifications, 1);

      run.appendStderr(Uint8List.fromList(utf8.encode('e\n')));
      expect(notifications, 1);
      async.elapse(const Duration(milliseconds: 50));
      expect(notifications, 2);

      run.complete(status: ToolRunStatus.succeeded, exitCode: 0);
      expect(notifications, 3);
      expect(run.status, ToolRunStatus.succeeded);
      expect(run.exitCode, 0);
    });
  });

  test('complete notifies immediately even before the 50 ms window', () {
    fakeAsync((async) {
      final run = ToolRun(toolCallId: 'c2', toolName: 'shell');
      var notifications = 0;
      run.addListener(() => notifications++);
      run.appendStdout(Uint8List.fromList(utf8.encode('x\n')));
      expect(notifications, 0);
      run.complete(status: ToolRunStatus.failed, exitCode: 1);
      expect(notifications, 1);
      async.elapse(const Duration(milliseconds: 50));
      expect(notifications, 1);
    });
  });

  test('keeps the last 200 tail lines from both streams', () {
    final run = ToolRun(toolCallId: 'c3', toolName: 'shell');
    for (var i = 0; i < 150; i++) {
      run.appendStdout(Uint8List.fromList(utf8.encode('out$i\n')));
    }
    for (var i = 0; i < 60; i++) {
      run.appendStderr(Uint8List.fromList(utf8.encode('err$i\n')));
    }
    expect(run.tailLines.length, 200);
    expect(run.tailLines.first, 'out10');
    expect(run.tailLines.last, 'err59');
    expect(run.stdoutSoFar, contains('out0'));
    expect(run.stderrSoFar, contains('err59'));
  });

  test(
    'identical provider tool IDs remain independent across conversations',
    () {
      final registry = ToolRunRegistry();
      final a = registry.start(
        'call-0',
        'shell',
        conversationId: 'a',
        runtimeRunId: 'process-a',
      );
      final b = registry.start(
        'call-0',
        'shell',
        conversationId: 'b',
        runtimeRunId: 'process-b',
      );
      expect(registry.of('call-0', conversationId: 'a'), same(a));
      expect(registry.of('call-0', conversationId: 'b'), same(b));
      registry.evict('call-0', conversationId: 'a');
      expect(registry.of('call-0', conversationId: 'b'), same(b));
    },
  );

  test('evicts the least-recently-used finished run at 200 entries', () {
    final registry = ToolRunRegistry();
    for (var i = 0; i < 200; i++) {
      registry
          .start('$i', 'shell', command: 'cmd$i')
          .complete(status: ToolRunStatus.succeeded, exitCode: 0);
    }
    registry.start('200', 'shell');
    expect(registry.of('0'), isNull);
    expect(registry.of('1'), isNotNull);
    expect(registry.of('200'), isNotNull);
    expect(registry.running.length, 1);

    registry.evict('200');
    expect(registry.of('200'), isNull);
    expect(registry.running, isEmpty);
  });
}
