import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannel methodChannel;
  late EventChannel eventChannel;
  late WorkspaceChannel channel;
  late TestDefaultBinaryMessenger messenger;
  MockStreamHandlerEventSink? eventSink;

  setUp(() {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    methodChannel = const MethodChannel(kWorkspaceMethodChannel);
    eventChannel = const EventChannel(kWorkspaceEventChannel);
    channel = WorkspaceChannel(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );
    eventSink = null;
    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (args, sink) {
          eventSink = sink;
        },
        onCancel: (args) {
          eventSink = null;
        },
      ),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(eventChannel, null);
  });

  test('probe parses result including optional uid', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      expect(call.method, 'probe');
      return <String, Object?>{
        'supported': true,
        'abi': 'arm64-v8a',
        'prootPath': '/lib/libproot.so',
        'loaderPath': '/lib/loader.so',
        'nativeLibDir': '/lib',
        'reason': null,
        'uid': 10123,
      };
    });

    final result = await channel.probe();
    expect(result.supported, isTrue);
    expect(result.abi, 'arm64-v8a');
    expect(result.prootPath, '/lib/libproot.so');
    expect(result.loaderPath, '/lib/loader.so');
    expect(result.nativeLibDir, '/lib');
    expect(result.uid, 10123);
    expect(result.reason, isNull);
  });

  test('probe maps MissingPluginException to unsupported', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      throw MissingPluginException('no plugin');
    });
    final result = await channel.probe();
    expect(result.supported, isFalse);
    expect(result.reason, 'missing_plugin');
  });

  test('exec routes events by runId', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      expect(call.method, 'exec');
      final args = Map<String, Object?>.from(call.arguments as Map);
      expect(args['runId'], 'run-a');
      expect(args['command'], 'uname');
      eventSink?.success(<String, Object?>{
        'type': 'stdout',
        'runId': 'run-a',
        'data': Uint8List.fromList(<int>[65, 66]),
      });
      eventSink?.success(<String, Object?>{
        'type': 'stderr',
        'runId': 'run-b',
        'data': Uint8List.fromList(<int>[88]),
      });
      eventSink?.success(<String, Object?>{
        'type': 'exit',
        'runId': 'run-a',
        'exitCode': 0,
        'timedOut': false,
        'cancelled': false,
        'durationMs': 12,
      });
      return <String, Object?>{'started': true};
    });

    final events = <Map<String, Object?>>[];
    final sub = channel.events.listen(events.add);
    await channel.exec(
      const ExecArgs(
        runId: 'run-a',
        rootfsDir: '/env/rootfs',
        tmpDir: '/env/tmp',
        cwd: '/',
        command: 'uname',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    final mine = events.where((e) => e['runId'] == 'run-a').toList();
    expect(mine, hasLength(2));
    expect(mine.first['type'], 'stdout');
    expect(mine.first['data'], Uint8List.fromList(<int>[65, 66]));
    expect(mine.last['type'], 'exit');
    expect(mine.last['exitCode'], 0);
    expect(events.where((e) => e['runId'] == 'run-b'), hasLength(1));
  });

  test('PlatformException is mapped to WorkspaceChannelException', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      throw PlatformException(code: 'invalid_args', message: 'missing runId');
    });
    expect(
      () => channel.cancel(''),
      throwsA(
        isA<WorkspaceChannelException>()
            .having((e) => e.code, 'code', 'invalid_args')
            .having((e) => e.message, 'message', 'missing runId'),
      ),
    );
  });

  test('MissingPluginException on methods is mapped', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      throw MissingPluginException('absent');
    });
    expect(
      () => channel.keepScreenOn(true),
      throwsA(
        isA<WorkspaceChannelException>().having(
          (e) => e.code,
          'code',
          'missing_plugin',
        ),
      ),
    );
  });

  test('freeSpace and sha256File parse native results', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'freeSpace') {
        return <String, Object?>{'freeBytes': 100, 'totalBytes': 200};
      }
      if (call.method == 'sha256File') {
        return 'abcDEF';
      }
      return null;
    });
    final space = await channel.freeSpace('/data');
    expect(space.freeBytes, 100);
    expect(space.totalBytes, 200);
    expect(await channel.sha256File('/data/a'), 'abcDEF');
  });

  test('probe parses iOS fields', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      return <String, Object?>{
        'supported': true,
        'engine': 'ish',
        'installed': true,
        'booted': false,
        'needsRestart': true,
        'rootfsVersion': '1',
        'bundledVersion': '2',
        'reason': 'restart',
      };
    });
    final result = await channel.probe();
    expect(result.supported, isTrue);
    expect(result.engine, 'ish');
    expect(result.installed, isTrue);
    expect(result.booted, isFalse);
    expect(result.needsRestart, isTrue);
    expect(result.rootfsVersion, '1');
    expect(result.bundledVersion, '2');
    expect(result.reason, 'restart');
  });

  test('exec omits null rootfsDir and tmpDir', () async {
    Map<String, Object?>? args;
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      args = Map<String, Object?>.from(call.arguments as Map);
      return <String, Object?>{'started': true};
    });
    await channel.exec(const ExecArgs(runId: 'ios', cwd: '/', command: 'true'));
    expect(args!.containsKey('rootfsDir'), isFalse);
    expect(args!.containsKey('tmpDir'), isFalse);
    expect(args!['runId'], 'ios');
    expect(args!['command'], 'true');
  });

  test('patchRootfs sends aptMirrorBaseUrl only', () async {
    Map<String, Object?>? args;
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      expect(call.method, 'patchRootfs');
      args = Map<String, Object?>.from(call.arguments as Map);
      return <String, Object?>{'ok': true};
    });
    await channel.patchRootfs(
      rootfsDir: '/env/rootfs',
      aptMirrorBaseUrl: 'https://mirrors.example/ubuntu',
      arch: 'arm64',
      gids: const <int>[3003],
      ubuntuCodename: 'noble',
    );
    expect(args!['rootfsDir'], '/env/rootfs');
    expect(args!['aptMirrorBaseUrl'], 'https://mirrors.example/ubuntu');
    expect(args!.containsKey('aptMirrorBase'), isFalse);
    expect(args!['arch'], 'arm64');
    expect(args!['gids'], const <int>[3003]);
    expect(args!['ubuntuCodename'], 'noble');
  });

  test('pty methods send the documented argument maps', () async {
    final seen = <String, Map<String, Object?>>{};
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      seen[call.method] = Map<String, Object?>.from(call.arguments as Map);
      if (call.method == 'ptyOpen') return <String, Object?>{'pid': 9};
      return null;
    });
    expect(
      await channel.ptyOpen(sessionId: 's1', cwd: '/', cols: 80, rows: 24),
      9,
    );
    await channel.ptyWrite(sessionId: 's1', data: Uint8List.fromList(<int>[1]));
    await channel.ptyResize(sessionId: 's1', cols: 81, rows: 25);
    await channel.ptyClose('s1');
    expect(seen['ptyOpen']!['sessionId'], 's1');
    expect(seen['ptyOpen']!.containsKey('rootfsDir'), isFalse);
    expect(seen['ptyWrite']!['data'], Uint8List.fromList(<int>[1]));
    expect(seen['ptyResize']!['cols'], 81);
    expect(seen['ptyClose']!['sessionId'], 's1');
  });

  test('events stream is shared across listeners', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async => null);
    final a = <Object?>[];
    final b = <Object?>[];
    final subA = channel.events.listen(a.add);
    final subB = channel.events.listen(b.add);
    eventSink?.success(<String, Object?>{'type': 'extract', 'entries': 1});
    await Future<void>.delayed(Duration.zero);
    await subA.cancel();
    await subB.cancel();
    expect(a, hasLength(1));
    expect(b, hasLength(1));
  });
}
