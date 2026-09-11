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

    test(
      'commands past eight seconds retain exit codes and requested timeouts',
      () async {
        final results = await Future.wait([
          runtime
              .run(
                _req(
                  runId: 'long-success',
                  command: 'sleep 9; exit 3',
                  cwd: tmp.path,
                  timeout: const Duration(seconds: 20),
                ),
              )
              .toList(),
          runtime
              .run(
                _req(
                  runId: 'long-timeout',
                  command: 'sleep 30',
                  cwd: tmp.path,
                  timeout: const Duration(seconds: 9),
                ),
              )
              .toList(),
        ]).timeout(const Duration(seconds: 18));
        expect(_singleExit(results[0]).exitCode, 3);
        expect(_singleExit(results[0]).timedOut, isFalse);
        expect(_singleExit(results[1]).timedOut, isTrue);
      },
      skip: !isUnix,
    );

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
      var childPids = <int>[];
      await _waitUntil(() async {
        final result = await Process.run('pgrep', ['-P', '${started.pid}']);
        if (result.exitCode == 0) {
          childPids = (result.stdout as String)
              .trim()
              .split(RegExp(r'\s+'))
              .map(int.parse)
              .toList();
        }
        return result.exitCode == 0;
      });
      expect(childPids, isNotEmpty);

      await runtime.cancel(request.runId);
      await done.future.timeout(const Duration(seconds: 4));

      final exit = _singleExit(events);
      expect(exit.cancelled, isTrue);
      expect(exit.timedOut, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      final children = await Process.run('pgrep', ['-P', '${started.pid}']);
      expect(children.exitCode, isNot(0));
      // Check the captured PIDs even if cancellation reparented them. A global
      // command-name search also matches unrelated tasks running on the host.
      for (final childPid in childPids) {
        final leftover = await Process.run('ps', [
          '-p',
          '$childPid',
          '-o',
          'pid=',
        ]);
        expect(
          leftover.exitCode,
          isNot(0),
          reason: 'child $childPid still alive after cancellation',
        );
      }
    }, skip: !isUnix);

    test('cancel kills SIGTERM-ignoring children after reparenting', () async {
      final childPids = <int>[];
      addTearDown(() {
        for (final pid in childPids) {
          Process.killPid(pid, ProcessSignal.sigkill);
        }
      });
      final ready = Completer<void>();
      final events = runtime
          .run(
            _req(
              runId: 'stubborn-tree',
              command:
                  r'''/bin/sh -c 'trap "" TERM; sleep 30 & printf "%s %s" "$$" "$!" > stubborn.pids; printf READY; wait; printf changed > after-stop.txt'; printf parentdone''',
              cwd: tmp.path,
              timeout: const Duration(seconds: 20),
            ),
          )
          .map((event) {
            if (event is CommandOutput &&
                utf8.decode(event.bytes).contains('READY') &&
                !ready.isCompleted) {
              ready.complete();
            }
            return event;
          })
          .toList();
      await ready.future.timeout(const Duration(seconds: 5));
      childPids.addAll(
        (await File(
          '${tmp.path}/stubborn.pids',
        ).readAsString()).split(' ').map(int.parse),
      );
      await Future.wait([
        runtime.cancel('stubborn-tree'),
        runtime.cancel('stubborn-tree'),
      ]).timeout(const Duration(seconds: 5));
      final exit = _singleExit(
        await events.timeout(const Duration(seconds: 3)),
      );
      expect(exit.cancelled, isTrue);
      expect(await File('${tmp.path}/after-stop.txt').exists(), isFalse);
      for (final pid in childPids) {
        final state = await Process.run('ps', ['-p', '$pid', '-o', 'stat=']);
        final value = state.stdout.toString().trim();
        expect(
          value.isEmpty || value.startsWith('Z'),
          isTrue,
          reason: 'Child $pid survived cancellation: $value',
        );
      }
    }, skip: !isUnix);

    for (final cancel in [false, true]) {
      test(
        'background children stop after the shell exits (cancel=$cancel)',
        () async {
          int? childPid;
          addTearDown(() {
            if (childPid != null) {
              Process.killPid(childPid, ProcessSignal.sigkill);
            }
          });
          final ready = Completer<void>();
          final events = <CommandEvent>[];
          final runId = 'inherited-pipe-$cancel';
          final watch = Stopwatch()..start();
          final done = runtime
              .run(
                _req(
                  runId: runId,
                  command:
                      r'''(sleep 1; printf changed > after-stop.txt) & printf "%s" "$!"''',
                  cwd: tmp.path,
                  timeout: Duration(milliseconds: cancel ? 10000 : 300),
                ),
              )
              .map((event) {
                events.add(event);
                if (event is CommandOutput && !ready.isCompleted) {
                  ready.complete();
                }
                return event;
              })
              .toList();
          await ready.future.timeout(const Duration(seconds: 5));
          childPid = int.parse(utf8.decode(_stdout(events)));
          if (cancel) {
            // Let the parent exit while its child retains stdout and stderr.
            await Future<void>.delayed(const Duration(milliseconds: 150));
            await runtime.cancel(runId);
          }
          await done.timeout(const Duration(seconds: 2));
          expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
          final exit = _singleExit(events);
          expect(exit.timedOut, !cancel);
          expect(exit.cancelled, cancel);
          final state = await Process.run('ps', [
            '-p',
            '$childPid',
            '-o',
            'stat=',
          ]);
          final value = state.stdout.toString().trim();
          expect(
            value.isEmpty || value.startsWith('Z'),
            isTrue,
            reason: 'Background child survived stopping the run: $value',
          );
          childPid = null;
          await Future<void>.delayed(const Duration(milliseconds: 1100));
          expect(await File('${tmp.path}/after-stop.txt').exists(), isFalse);
        },
        skip: !isUnix,
      );
    }

    test('stopping a background group preserves another active run', () async {
      final ready = Completer<void>();
      final stopped = runtime
          .run(
            _req(
              runId: 'stop-background',
              command: '(sleep 2; printf changed > stopped.txt) & printf READY',
              cwd: tmp.path,
            ),
          )
          .map((event) {
            if (event is CommandOutput &&
                utf8.decode(event.bytes).contains('READY') &&
                !ready.isCompleted) {
              ready.complete();
            }
            return event;
          })
          .toList();
      final preserved = _collect(
        runtime,
        _req(
          runId: 'keep-background',
          command: '(sleep 1; printf preserved > kept.txt) & wait; exit 3',
          cwd: tmp.path,
        ),
      );
      addTearDown(() async {
        await runtime.cancel('stop-background');
        await runtime.cancel('keep-background');
      });
      await ready.future.timeout(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await runtime.cancel('stop-background');
      expect(_singleExit(await stopped).cancelled, isTrue);
      expect(_singleExit(await preserved).exitCode, 3);
      expect(await File('${tmp.path}/kept.txt').readAsString(), 'preserved');
      expect(await File('${tmp.path}/stopped.txt').exists(), isFalse);
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
