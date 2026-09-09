import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/sandbox/ios_ish_runtime.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

import 'sandbox_channel_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SandboxChannelHarness workspace;
  late IosIshRuntime runtime;

  setUp(() {
    workspace = SandboxChannelHarness();
    workspace.install();
    runtime = IosIshRuntime(channel: workspace.channel);
  });

  tearDown(() => workspace.dispose());

  test(
    'stdio forwards raw input and keeps a persistent command alive',
    () async {
      workspace.handler = (call) {
        if (call.method == 'exec') {
          workspace.emit({'type': 'started', 'runId': 'mcp'});
        }
        if (call.method == 'cancel') {
          workspace.emit({'type': 'exit', 'runId': 'mcp', 'exitCode': -1});
          return true;
        }
        return null;
      };
      final started = Completer<void>();
      final subscription = runtime
          .run(
            const CommandRequest(
              runId: 'mcp',
              command: 'exec server',
              cwd: '/root',
              keepStdinOpen: true,
              timeout: Duration.zero,
            ),
          )
          .listen((event) {
            if (event is CommandStarted) started.complete();
          });
      await started.future;
      await runtime.writeStdin('mcp', Uint8List.fromList([123, 125, 10]));
      expect(workspace.argsOf('exec')!['keepStdinOpen'], isTrue);
      expect(workspace.argsOf('exec')!['timeoutMs'], 0);
      expect(workspace.argsOf('stdinWrite'), {
        'runId': 'mcp',
        'data': [123, 125, 10],
      });
      await subscription.cancel();
      expect(
        workspace.methods,
        containsAllInOrder([
          'beginBackgroundTask',
          'exec',
          'stdinWrite',
          'cancel',
          'endBackgroundTask',
        ]),
      );
    },
  );

  group('status', () {
    test('not ready when probe is unsupported', () async {
      workspace.probeResult = <String, Object?>{
        'supported': false,
        'engine': 'ish',
        'reason': 'missing_plugin',
      };
      final status = await runtime.status();
      expect(status.ready, isFalse);
      expect(status.reason, 'missing_plugin');
      expect(status.engine, 'ish');
      expect(status.sandboxed, isTrue);
    });

    test('not ready when rootfs is missing', () async {
      workspace.probeResult = <String, Object?>{
        'supported': true,
        'engine': 'ish',
        'installed': false,
        'booted': false,
        'needsRestart': false,
        'bundledVersion': '1',
        'reason': 'rootfs not installed',
      };
      final status = await runtime.status();
      expect(status.ready, isFalse);
      expect(status.reason, 'rootfs_not_installed');
    });

    test('not ready when a restart is required', () async {
      workspace.probeResult = <String, Object?>{
        'supported': true,
        'engine': 'ish',
        'installed': true,
        'booted': false,
        'needsRestart': true,
        'rootfsVersion': '2',
        'bundledVersion': '2',
        'reason': 'rootfs was reset or upgraded; restart the app',
      };
      final status = await runtime.status();
      expect(status.ready, isFalse);
      expect(status.reason, 'needs_restart');
      expect(status.engine, 'ish');
    });

    test('ready when supported, installed, and not needing restart', () async {
      workspace.probeResult = <String, Object?>{
        'supported': true,
        'engine': 'ish',
        'installed': true,
        'booted': true,
        'needsRestart': false,
        'rootfsVersion': '2',
        'bundledVersion': '2',
      };
      final status = await runtime.status();
      expect(status.ready, isTrue);
      expect(status.reason, isNull);
      expect(status.engine, 'ish');
      expect(status.sandboxed, isTrue);
    });
  });

  test('run wraps background task and honours interrupted', () async {
    workspace.handler = (call) {
      if (call.method == 'exec') {
        workspace.emit(<String, Object?>{
          'type': 'stdout',
          'runId': 'ios-1',
          'data': Uint8List.fromList(<int>[1]),
        });
        workspace.emit(<String, Object?>{
          'type': 'exit',
          'runId': 'ios-1',
          'exitCode': 137,
          'timedOut': false,
          'interrupted': true,
          'durationMs': 40,
        });
        return <String, Object?>{'started': true};
      }
      return null;
    };

    final events = await runtime
        .run(
          const CommandRequest(
            runId: 'ios-1',
            command: 'uname',
            cwd: '/root',
            timeout: Duration(milliseconds: 2500),
            mounts: [Mount(host: '/tmp/ws', guest: '/mnt/ws')],
          ),
        )
        .toList();

    expect(
      workspace.methods,
      containsAllInOrder(<String>[
        'beginBackgroundTask',
        'exec',
        'endBackgroundTask',
      ]),
    );

    final args = workspace.argsOf('exec')!;
    expect(args.containsKey('rootfsDir'), isFalse);
    expect(args.containsKey('tmpDir'), isFalse);
    expect(args['runId'], 'ios-1');
    expect(args['command'], 'uname');
    expect(args['cwd'], '/root');
    expect(args['timeoutMs'], 2500);
    expect(args['binds'], [
      {'host': '/tmp/ws', 'guest': '/mnt/ws'},
    ]);

    final exit = events.whereType<CommandExited>().single;
    expect(exit.interrupted, isTrue);
    expect(exit.exitCode, 137);
    expect(exit.cancelled, isFalse);
    expect(exit.timedOut, isFalse);
  });

  test('run still ends the background task when exec throws', () async {
    workspace.handler = (call) {
      if (call.method == 'exec') {
        throw PlatformException(
          code: 'exec_failed',
          message: 'could not start',
        );
      }
      return null;
    };
    await expectLater(
      runtime.run(
        const CommandRequest(runId: 'bad', command: 'true', cwd: '/'),
      ),
      emitsInOrder(<Object>[
        emitsError(isA<WorkspaceChannelException>()),
        emitsDone,
      ]),
    );
    expect(
      workspace.methods,
      containsAllInOrder(<String>[
        'beginBackgroundTask',
        'exec',
        'endBackgroundTask',
      ]),
    );
  });

  test('cancel forwards to the channel', () async {
    await runtime.cancel('ios-cancel');
    expect(workspace.argsOf('cancel')!['runId'], 'ios-cancel');
  });

  test('openPty omits rootfs paths and maps session events', () async {
    expect(runtime.supportsPty, isTrue);
    expect(runtime.supportsSystemTerminal, isFalse);

    final session = await runtime.openPty(
      mounts: const [],
      cwd: '/',
      env: const <String, String>{},
      cols: 40,
      rows: 12,
    );
    final open = workspace.argsOf('ptyOpen')!;
    expect(open.containsKey('rootfsDir'), isFalse);
    expect(open.containsKey('tmpDir'), isFalse);
    expect(open['cwd'], '/');
    expect(open['cols'], 40);
    expect(open['rows'], 12);

    final chunks = <Uint8List>[];
    final sub = session.output.listen(chunks.add);
    workspace.emit(<String, Object?>{
      'type': 'pty',
      'sessionId': open['sessionId'],
      'data': Uint8List.fromList(<int>[33]),
    });
    await session.write(Uint8List.fromList(<int>[9]));
    await session.resize(41, 13);
    await session.close();
    workspace.emit(<String, Object?>{
      'type': 'ptyExit',
      'sessionId': open['sessionId'],
      'exitCode': 0,
    });
    expect(await session.exitCode, 0);
    await sub.cancel();
    expect(chunks.single, Uint8List.fromList(<int>[33]));
  });

  test('every openPty asks for an id no other session can hold', () async {
    Future<void> open(IosIshRuntime runtime) => runtime.openPty(
      mounts: const [],
      cwd: '/',
      env: const <String, String>{},
      cols: 80,
      rows: 24,
    );

    await open(runtime);
    await open(runtime);
    // A fresh runtime stands in for a hot restart: the platform side keeps its
    // session map, so a per-instance counter would hand back the first id.
    await open(IosIshRuntime(channel: workspace.channel));

    final ids = <String>{
      for (final call in workspace.calls)
        if (call.method == 'ptyOpen')
          (call.arguments as Map)['sessionId'] as String,
    };
    expect(ids, hasLength(3));
  });
}
