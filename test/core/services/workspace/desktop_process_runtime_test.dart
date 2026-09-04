import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/workspace/desktop_process_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

void main() {
  final isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
  final isUnix = Platform.isMacOS || Platform.isLinux;

  late DesktopProcessRuntime runtime;
  late Directory tmp;

  setUp(() async {
    runtime = DesktopProcessRuntime();
    tmp = await Directory.systemTemp.createTemp('kelivo_desktop_runtime_');
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  group('DesktopProcessRuntime', () {
    test('status reports a ready unsandboxed process engine', () async {
      final status = await runtime.status();
      expect(status.ready, isTrue);
      expect(status.engine, 'process');
      expect(status.sandboxed, isFalse);
      expect(status.reason, isNull);
      expect(runtime.supportsPty, isFalse);
      expect(runtime.supportsSystemTerminal, isTrue);
    });

    test('cancel of an unknown run is a no-op', () async {
      await runtime.cancel('does-not-exist');
    });

    test('printf streams stdout bytes and exits 0', () async {
      final events = await _collect(
        runtime,
        _req(runId: 'printf', command: "printf 'a\\nb'", cwd: tmp.path),
      );
      expect(events.first, isA<CommandStarted>());
      expect(_stdout(events), Uint8List.fromList(<int>[0x61, 0x0a, 0x62]));
      final exit = _singleExit(events);
      expect(exit.exitCode, 0);
      expect(exit.timedOut, isFalse);
      expect(exit.cancelled, isFalse);
    }, skip: !isUnix);

    test('exit 3 reports exit code 3', () async {
      final events = await _collect(
        runtime,
        _req(runId: 'exit3', command: 'exit 3', cwd: tmp.path),
      );
      expect(_singleExit(events).exitCode, 3);
    }, skip: !isUnix);

    test('routes stderr separately from stdout', () async {
      final events = await _collect(
        runtime,
        _req(
          runId: 'stderr',
          command: "printf 'err' >&2; printf 'out'",
          cwd: tmp.path,
        ),
      );
      expect(utf8.decode(_stdout(events)), 'out');
      expect(utf8.decode(_stderr(events)), 'err');
      expect(_singleExit(events).exitCode, 0);
    }, skip: !isUnix);

    test('respects cwd via pwd', () async {
      final events = await _collect(
        runtime,
        _req(runId: 'pwd', command: 'pwd', cwd: tmp.path),
      );
      final text = utf8.decode(_stdout(events)).trim();
      expect(
        Directory(text).resolveSymbolicLinksSync(),
        tmp.resolveSymbolicLinksSync(),
      );
      expect(_singleExit(events).exitCode, 0);
    }, skip: !isUnix);

    test('passes request env through to the process', () async {
      final events = await _collect(
        runtime,
        _req(
          runId: 'env',
          command: r'echo $KELIVO_TEST',
          cwd: tmp.path,
          env: const <String, String>{'KELIVO_TEST': 'kelivo-runtime-ok'},
        ),
      );
      expect(utf8.decode(_stdout(events)), contains('kelivo-runtime-ok'));
      expect(_singleExit(events).exitCode, 0);
    }, skip: !isUnix);

    test('preserves UTF-8 emoji bytes', () async {
      final events = await _collect(
        runtime,
        _req(runId: 'emoji', command: "printf 'a🎉b'", cwd: tmp.path),
      );
      expect(_stdout(events), utf8.encode('a🎉b'));
      expect(_singleExit(events).exitCode, 0);
    }, skip: !isUnix);

    test('streams large seq output in full', () async {
      const n = 50000;
      final events = await _collect(
        runtime,
        _req(
          runId: 'seq',
          command: 'seq 1 $n',
          cwd: tmp.path,
          timeout: const Duration(seconds: 8),
        ),
      );
      expect(_stdoutLen(events), _seqStdoutBytes(n));
      expect(_singleExit(events).exitCode, 0);
    }, skip: !isUnix);

    test('timeout kills sleep 30 within ~1.5s and reports timedOut', () async {
      final watch = Stopwatch()..start();
      final events = await _collect(
        runtime,
        _req(
          runId: 'timeout',
          command: 'sleep 30',
          cwd: tmp.path,
          timeout: const Duration(milliseconds: 250),
        ),
      );
      watch.stop();
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 1500)));
      final exit = _singleExit(events);
      expect(exit.timedOut, isTrue);
      expect(exit.cancelled, isFalse);
      expect(exit.exitCode, anyOf(-1, isNonZero));
    }, skip: !isUnix);

    test('cancel kills the process tree including child sleep', () async {
      final request = _req(
        runId: 'cancel-tree',
        command: 'sleep 30 & wait',
        cwd: tmp.path,
        timeout: const Duration(seconds: 8),
      );
      final events = <CommandEvent>[];
      final done = Completer<void>();
      runtime.run(request).listen(events.add, onDone: done.complete);

      final started = await _waitFor<CommandStarted>(events);
      expect(started.pid, isNotNull);
      await _waitUntil(() async {
        final result = await Process.run('pgrep', ['-P', '${started.pid}']);
        return result.exitCode == 0;
      });

      await runtime.cancel(request.runId);
      await done.future.timeout(const Duration(seconds: 4));

      final exit = _singleExit(events);
      expect(exit.cancelled, isTrue);
      expect(exit.timedOut, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      final children = await Process.run('pgrep', ['-P', '${started.pid}']);
      expect(children.exitCode, isNot(0));
      final leftover = await Process.run('pgrep', ['-f', r'[s]leep 30']);
      expect(
        leftover.exitCode,
        isNot(0),
        reason: 'sleep 30 still alive: ${leftover.stdout}',
      );
    }, skip: !isUnix);

    test('emits CommandExited exactly once', () async {
      final events = await _collect(
        runtime,
        _req(runId: 'once', command: "printf 'x'", cwd: tmp.path),
      );
      expect(events.whereType<CommandExited>(), hasLength(1));
      expect(events.last, isA<CommandExited>());
    }, skip: !isUnix);
  }, skip: isDesktop ? false : 'desktop only');
}

CommandRequest _req({
  required String runId,
  required String command,
  required String cwd,
  Duration timeout = const Duration(seconds: 5),
  Map<String, String> env = const <String, String>{},
}) {
  return CommandRequest(
    runId: runId,
    command: command,
    cwd: cwd,
    timeout: timeout,
    env: env,
  );
}

Future<List<CommandEvent>> _collect(
  DesktopProcessRuntime runtime,
  CommandRequest request,
) {
  return runtime.run(request).toList().timeout(const Duration(seconds: 10));
}

Uint8List _stdout(List<CommandEvent> events) =>
    _concat(events, OutputStreamKind.stdout);

Uint8List _stderr(List<CommandEvent> events) =>
    _concat(events, OutputStreamKind.stderr);

int _stdoutLen(List<CommandEvent> events) {
  var n = 0;
  for (final event in events.whereType<CommandOutput>()) {
    if (event.kind == OutputStreamKind.stdout) n += event.bytes.length;
  }
  return n;
}

Uint8List _concat(List<CommandEvent> events, OutputStreamKind kind) {
  final builder = BytesBuilder(copy: false);
  for (final event in events.whereType<CommandOutput>()) {
    if (event.kind == kind) builder.add(event.bytes);
  }
  return builder.takeBytes();
}

CommandExited _singleExit(List<CommandEvent> events) {
  final exits = events.whereType<CommandExited>().toList();
  expect(exits, hasLength(1), reason: 'expected exactly one CommandExited');
  return exits.single;
}

int _seqStdoutBytes(int n) {
  var bytes = 0;
  for (var i = 1; i <= n; i++) {
    bytes += i.toString().length + 1;
  }
  return bytes;
}

Future<T> _waitFor<T extends CommandEvent>(List<CommandEvent> events) async {
  await _waitUntil(() async => events.whereType<T>().isNotEmpty);
  return events.whereType<T>().first;
}

Future<void> _waitUntil(Future<bool> Function() check) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    if (await check()) return;
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
  fail('condition not met in time');
}
