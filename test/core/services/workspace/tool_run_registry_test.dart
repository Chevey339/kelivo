import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/workspace/tool_run_registry.dart';

void main() {
  test('unobserved pending lines freeze correctly when streams interleave', () {
    final run = ToolRun(toolCallId: 'lazy-tail', toolName: 'shell');
    addTearDown(run.dispose);
    run.appendStdout(utf8.encode('old'));
    run.appendStderr(utf8.encode('warning'));
    run.appendStdout(utf8.encode('\rnew'));
    run.appendStderr(utf8.encode('\nsecond warning'));
    run.appendStdout(utf8.encode(' result\nnext'));
    expect(run.tailLines, ['new result', 'warning', 'second warning', 'next']);
    final snapshot = run.tailLines;
    run.appendStdout(utf8.encode(' line'));
    expect(snapshot.last, 'next');
    expect(run.tailLines.last, 'next line');
    run.complete(status: ToolRunStatus.succeeded, exitCode: 0);
    expect(run.stdoutSoFar, 'new result\nnext line');
    expect(run.stderrSoFar, 'warning\nsecond warning');
  });

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

  test('progress replaces its live tail line independently of stderr', () {
    final run = ToolRun(toolCallId: 'progress', toolName: 'shell');
    addTearDown(run.dispose);

    run.appendStdout(utf8.encode('starting\n10%'));
    expect(run.tailLines, ['starting', '10%']);
    run.appendStderr(utf8.encode('warning\r'));
    run.appendStdout(utf8.encode('\r\x1b[32m100%\x1b[0m'));
    expect(run.stdoutSoFar, 'starting\n100%');
    expect(run.stderrSoFar, 'warning');
    expect(run.tailLines, ['starting', '100%', 'warning']);

    run.appendStderr(utf8.encode('recovered\r'));
    run.appendStderr(utf8.encode('\n'));
    run.complete(status: ToolRunStatus.succeeded, exitCode: 0);
    expect(run.stdoutSoFar, 'starting\n100%');
    expect(run.stderrSoFar, 'recovered\n');
    expect(run.tailLines, ['starting', '100%', 'recovered']);
  });

  for (final progressOnStderr in [false, true]) {
    test(
      'control-only ${progressOnStderr ? 'stderr' : 'stdout'} chunks do not restore evicted progress',
      () {
        final run = ToolRun(toolCallId: 'control-only', toolName: 'shell');
        addTearDown(run.dispose);
        final appendProgress = progressOnStderr
            ? run.appendStderr
            : run.appendStdout;
        final appendLogs = progressOnStderr
            ? run.appendStdout
            : run.appendStderr;
        appendProgress(utf8.encode('10%'));
        for (var i = 0; i < 205; i++) {
          appendLogs(utf8.encode('log$i\n'));
        }
        final before = run.tailLines;
        for (final control in [
          '',
          '\r',
          '\x1b[0m',
          '\x1b[?25h',
          '\x1b',
          '8',
          '\x1b[',
          '0m',
          '\x1b]0;title',
          '\x1b',
          '\\',
        ]) {
          appendProgress(utf8.encode(control));
          expect(run.tailLines, before, reason: jsonEncode(control));
        }
        run.complete(status: ToolRunStatus.succeeded, exitCode: 0);
        expect(run.tailLines, before);
        expect(progressOnStderr ? run.stderrSoFar : run.stdoutSoFar, '10%');
      },
    );

    test(
      'identical new ${progressOnStderr ? 'stderr' : 'stdout'} progress is shown after eviction',
      () {
        final run = ToolRun(toolCallId: 'repeated-progress', toolName: 'shell');
        addTearDown(run.dispose);
        final appendProgress = progressOnStderr
            ? run.appendStderr
            : run.appendStdout;
        final appendLogs = progressOnStderr
            ? run.appendStdout
            : run.appendStderr;
        appendProgress(utf8.encode('10%'));
        for (var i = 0; i < 205; i++) {
          appendLogs(utf8.encode('log$i\n'));
        }
        expect(run.tailLines.last, 'log204');
        appendProgress(utf8.encode('\r\x1b[32m10%\x1b[0m'));
        expect(run.tailLines.length, 200);
        expect(run.tailLines.last, '10%');
        final afterProgress = run.tailLines;
        run.complete(status: ToolRunStatus.succeeded, exitCode: 0);
        expect(run.tailLines, afterProgress);
      },
    );

    test(
      'incomplete ${progressOnStderr ? 'stderr' : 'stdout'} UTF-8 waits for visible text before restoring a tail',
      () {
        final run = ToolRun(toolCallId: 'partial-utf8', toolName: 'shell');
        addTearDown(run.dispose);
        final appendProgress = progressOnStderr
            ? run.appendStderr
            : run.appendStdout;
        final appendLogs = progressOnStderr
            ? run.appendStdout
            : run.appendStderr;
        appendProgress(utf8.encode('10%'));
        for (var i = 0; i < 205; i++) {
          appendLogs(utf8.encode('log$i\n'));
        }
        final before = run.tailLines;
        final replacement = utf8.encode('\r完成 😀');
        for (var i = 0; i < 3; i++) {
          appendProgress(Uint8List.fromList([replacement[i]]));
          expect(run.tailLines, before);
        }
        appendProgress(Uint8List.fromList(replacement.sublist(3)));
        expect(run.tailLines.length, 200);
        expect(run.tailLines.last, '完成 😀');
        run.complete(status: ToolRunStatus.succeeded, exitCode: 0);
        expect(run.tailLines.last, '完成 😀');
      },
    );

    test(
      'complete does not restore evicted ${progressOnStderr ? 'stderr' : 'stdout'} progress',
      () {
        final run = ToolRun(toolCallId: 'evicted-progress', toolName: 'shell');
        addTearDown(run.dispose);
        final appendProgress = progressOnStderr
            ? run.appendStderr
            : run.appendStdout;
        final appendLogs = progressOnStderr
            ? run.appendStdout
            : run.appendStderr;
        appendProgress(utf8.encode('10%'));
        for (var i = 0; i < 205; i++) {
          appendLogs(utf8.encode('log$i\n'));
        }
        final beforeComplete = run.tailLines;
        expect(beforeComplete.length, 200);
        expect(beforeComplete.first, 'log5');
        expect(beforeComplete.last, 'log204');
        expect(beforeComplete, isNot(contains('10%')));

        run.complete(status: ToolRunStatus.succeeded, exitCode: 0);
        expect(run.tailLines, beforeComplete);
        expect(progressOnStderr ? run.stderrSoFar : run.stdoutSoFar, '10%');
      },
    );

    test(
      'complete still adds ${progressOnStderr ? 'stderr' : 'stdout'} text emitted by UTF-8 finalization',
      () {
        final run = ToolRun(toolCallId: 'utf8-finalization', toolName: 'shell');
        addTearDown(run.dispose);
        final appendProgress = progressOnStderr
            ? run.appendStderr
            : run.appendStdout;
        final appendLogs = progressOnStderr
            ? run.appendStdout
            : run.appendStderr;
        appendProgress(utf8.encode('partial '));
        appendProgress(Uint8List.fromList([0xe4]));
        for (var i = 0; i < 205; i++) {
          appendLogs(utf8.encode('log$i\n'));
        }
        expect(run.tailLines.last, 'log204');

        run.complete(status: ToolRunStatus.cancelled);
        expect(run.tailLines.length, 200);
        expect(run.tailLines.first, 'log6');
        expect(run.tailLines.last, 'partial \uFFFD');
        expect(
          progressOnStderr ? run.stderrSoFar : run.stdoutSoFar,
          'partial \uFFFD',
        );
      },
    );
  }

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
