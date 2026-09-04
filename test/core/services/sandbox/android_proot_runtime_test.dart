import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/android_proot_runtime.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

import '../../../support/business_test_harness.dart';
import 'sandbox_channel_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SandboxChannelHarness workspace;
  late EnvironmentProvider env;
  late Directory rootfsDir;
  late Directory tmpDir;
  late AndroidProotRuntime runtime;

  setUp(() async {
    workspace = SandboxChannelHarness();
    workspace.install();
    env = EnvironmentProvider(preferences: createBusinessTestPreferences());
    await env.loaded;
    rootfsDir = await Directory.systemTemp.createTemp('kelivo_proot_rootfs_');
    tmpDir = await Directory.systemTemp.createTemp('kelivo_proot_tmp_');
    runtime = AndroidProotRuntime(
      channel: workspace.channel,
      env: env,
      rootfsDir: rootfsDir,
      tmpDir: tmpDir,
    );
  });

  tearDown(() async {
    workspace.dispose();
    if (await rootfsDir.exists()) await rootfsDir.delete(recursive: true);
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  });

  group('status', () {
    test('not ready when environment phase is not ready', () async {
      final status = await runtime.status();
      expect(status.ready, isFalse);
      expect(status.reason, 'environment_not_installed');
      expect(status.engine, 'proot');
      expect(status.sandboxed, isTrue);
    });

    test('not ready when rootfs is missing', () async {
      await env.setState(const EnvironmentState(phase: EnvironmentPhase.ready));
      final missing = Directory('${rootfsDir.path}-absent');
      runtime = AndroidProotRuntime(
        channel: workspace.channel,
        env: env,
        rootfsDir: missing,
        tmpDir: tmpDir,
      );
      final status = await runtime.status();
      expect(status.ready, isFalse);
      expect(status.reason, 'environment_not_installed');
    });

    test('not ready when probe is unsupported', () async {
      await env.setState(const EnvironmentState(phase: EnvironmentPhase.ready));
      workspace.probeResult = <String, Object?>{
        'supported': false,
        'abi': 'arm64-v8a',
        'reason': 'loader missing: /lib/loader.so',
      };
      final status = await runtime.status();
      expect(status.ready, isFalse);
      expect(status.reason, 'proot_missing: loader missing: /lib/loader.so');
      expect(status.engine, 'proot');
    });

    test('adopts on-disk version file when prefs say not installed', () async {
      File(
        '${rootfsDir.path}/.kelivo-version',
      ).writeAsStringSync('ubuntu 24.04.3 arm64\n');
      workspace.probeResult = <String, Object?>{
        'supported': true,
        'abi': 'arm64-v8a',
      };
      final status = await runtime.status();
      expect(status.ready, isTrue);
      expect(env.state.phase, EnvironmentPhase.ready);
      expect(env.state.version, '24.04.3');
      expect(env.state.arch, 'arm64');
    });

    test('ready when phase, rootfs, and probe all pass', () async {
      await env.setState(const EnvironmentState(phase: EnvironmentPhase.ready));
      workspace.probeResult = <String, Object?>{
        'supported': true,
        'abi': 'arm64-v8a',
      };
      final status = await runtime.status();
      expect(status.ready, isTrue);
      expect(status.reason, isNull);
      expect(status.engine, 'proot');
      expect(status.sandboxed, isTrue);
    });
  });

  test('run maps stdout/stderr/exit and ignores other runIds', () async {
    workspace.handler = (call) {
      if (call.method == 'exec') {
        workspace.emit(<String, Object?>{
          'type': 'stdout',
          'runId': 'other',
          'data': Uint8List.fromList(<int>[9]),
        });
        workspace.emit(<String, Object?>{
          'type': 'stdout',
          'runId': 'run-a',
          'data': Uint8List.fromList(<int>[65]),
        });
        workspace.emit(<String, Object?>{
          'type': 'stderr',
          'runId': 'run-a',
          'data': Uint8List.fromList(<int>[66]),
        });
        workspace.emit(<String, Object?>{
          'type': 'exit',
          'runId': 'run-a',
          'exitCode': 0,
          'timedOut': false,
          'durationMs': 15,
        });
        return <String, Object?>{'started': true};
      }
      return null;
    };

    final events = await runtime
        .run(
          CommandRequest(
            runId: 'run-a',
            command: 'uname',
            cwd: '/',
            timeout: const Duration(seconds: 12),
            env: const {'FOO': 'bar'},
            mounts: const [Mount(host: '/host', guest: '/mnt/host')],
          ),
        )
        .toList();

    expect(events, hasLength(3));
    expect((events[0] as CommandOutput).kind, OutputStreamKind.stdout);
    expect((events[0] as CommandOutput).bytes, Uint8List.fromList(<int>[65]));
    expect((events[1] as CommandOutput).kind, OutputStreamKind.stderr);
    expect((events[2] as CommandExited).exitCode, 0);
    expect((events[2] as CommandExited).timedOut, isFalse);
    expect((events[2] as CommandExited).cancelled, isFalse);
    expect((events[2] as CommandExited).interrupted, isFalse);
    expect(
      (events[2] as CommandExited).duration,
      const Duration(milliseconds: 15),
    );

    final args = workspace.argsOf('exec')!;
    expect(args['runId'], 'run-a');
    expect(args['command'], 'uname');
    expect(args['cwd'], '/');
    expect(args['rootfsDir'], rootfsDir.path);
    expect(args['tmpDir'], tmpDir.path);
    expect(args['timeoutMs'], 12000);
    expect(args['env'], {'FOO': 'bar'});
    expect(args['binds'], [
      {'host': '/host', 'guest': '/mnt/host'},
    ]);
  });

  test('run maps cancelled, timedOut, and closes once', () async {
    var exitEmits = 0;
    workspace.handler = (call) {
      if (call.method == 'exec') {
        workspace.emit(<String, Object?>{
          'type': 'exit',
          'runId': 'run-b',
          'exitCode': -1,
          'timedOut': true,
          'cancelled': true,
          'durationMs': 8,
        });
        exitEmits++;
        workspace.emit(<String, Object?>{
          'type': 'exit',
          'runId': 'run-b',
          'exitCode': 0,
          'timedOut': false,
          'durationMs': 99,
        });
        exitEmits++;
        return <String, Object?>{'started': true};
      }
      return null;
    };

    final events = await runtime
        .run(const CommandRequest(runId: 'run-b', command: 'sleep 1', cwd: '/'))
        .toList();

    expect(events, hasLength(1));
    final exit = events.single as CommandExited;
    expect(exit.timedOut, isTrue);
    expect(exit.cancelled, isTrue);
    expect(exit.interrupted, isFalse);
    expect(exitEmits, 2);
  });

  test('cancel forwards to the channel', () async {
    await runtime.cancel('run-z');
    expect(workspace.methods, contains('cancel'));
    expect(workspace.argsOf('cancel')!['runId'], 'run-z');
  });

  test('run errors when exec throws', () async {
    workspace.handler = (call) {
      if (call.method == 'exec') {
        throw PlatformException(code: 'workspace', message: 'boom');
      }
      return null;
    };
    await expectLater(
      runtime.run(const CommandRequest(runId: 'x', command: 'true', cwd: '/')),
      emitsInOrder(<Object>[
        emitsError(
          isA<WorkspaceChannelException>().having(
            (e) => e.message,
            'message',
            'boom',
          ),
        ),
        emitsDone,
      ]),
    );
  });

  test('openPty writes, resizes, closes, and maps exit', () async {
    expect(runtime.supportsPty, isTrue);
    expect(runtime.supportsSystemTerminal, isFalse);

    final session = await runtime.openPty(
      mounts: const [Mount(host: '/data', guest: '/mnt/data')],
      cwd: '/root',
      env: const {'TERM': 'xterm'},
      cols: 80,
      rows: 24,
    );

    final open = workspace.argsOf('ptyOpen')!;
    expect(open['sessionId'], isNotEmpty);
    expect(open['rootfsDir'], rootfsDir.path);
    expect(open['tmpDir'], tmpDir.path);
    expect(open['cwd'], '/root');
    expect(open['env'], {'TERM': 'xterm'});
    expect(open['cols'], 80);
    expect(open['rows'], 24);
    expect(open['binds'], [
      {'host': '/data', 'guest': '/mnt/data'},
    ]);

    final chunks = <Uint8List>[];
    final sub = session.output.listen(chunks.add);
    workspace.emit(<String, Object?>{
      'type': 'pty',
      'sessionId': 'other',
      'data': Uint8List.fromList(<int>[1]),
    });
    workspace.emit(<String, Object?>{
      'type': 'pty',
      'sessionId': open['sessionId'],
      'data': Uint8List.fromList(<int>[97, 98]),
    });
    await session.write(Uint8List.fromList(<int>[1, 2]));
    await session.resize(100, 30);
    await session.close();
    workspace.emit(<String, Object?>{
      'type': 'ptyExit',
      'sessionId': open['sessionId'],
      'exitCode': 7,
    });
    expect(await session.exitCode, 7);
    await sub.cancel();
    expect(chunks, [
      Uint8List.fromList(<int>[97, 98]),
    ]);

    expect(workspace.argsOf('ptyWrite')!['sessionId'], open['sessionId']);
    expect(
      workspace.argsOf('ptyWrite')!['data'],
      Uint8List.fromList(<int>[1, 2]),
    );
    expect(workspace.argsOf('ptyResize')!['cols'], 100);
    expect(workspace.argsOf('ptyResize')!['rows'], 30);
    expect(workspace.argsOf('ptyClose')!['sessionId'], open['sessionId']);
  });
}
