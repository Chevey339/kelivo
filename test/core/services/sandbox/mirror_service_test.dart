import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/guest_scripts.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';
import 'package:Kelivo/core/services/sandbox/mirror_speed_test.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EnvironmentProvider env;

  setUp(() async {
    env = EnvironmentProvider(preferences: createBusinessTestPreferences());
    await env.loaded;
    await env.setState(const EnvironmentState(arch: 'arm64'));
  });

  MirrorService service({
    http.Client? client,
    Duration timeout = const Duration(seconds: 8),
    Duration guestTimeout = const Duration(seconds: 30),
    Future<int> Function(String script)? runInGuest,
    Future<void> Function()? cancelGuest,
    List<String>? scripts,
  }) {
    return MirrorService(
      env: env,
      speedTest: MirrorSpeedTest(
        client: client ?? MockClient((_) async => http.Response('', 200)),
      ),
      runInGuest:
          runInGuest ??
          (script) async {
            scripts?.add(script);
            return 0;
          },
      cancelGuest: cancelGuest,
      client: client,
      probeTimeout: timeout,
      guestTimeout: guestTimeout,
    );
  }

  test(
    'amd64 APT selections use Ubuntu archives instead of ARM ports',
    () async {
      await env.setState(
        const EnvironmentState(phase: EnvironmentPhase.ready, arch: 'amd64'),
      );
      final scripts = <String>[];
      final mirrors = service(scripts: scripts);
      await mirrors.restoreOfficial(MirrorCategory.apt);
      expect(scripts.single, contains('http://archive.ubuntu.com/ubuntu'));
      expect(scripts.single, isNot(contains('ubuntu-ports')));
      final tuna = MirrorService.findEntry(
        MirrorCategory.apt,
        id: 'apt.tuna',
        arch: 'amd64',
      )!;
      expect(tuna.baseUrl, 'https://mirrors.tuna.tsinghua.edu.cn/ubuntu/');
    },
  );

  test('named tables cover official plus regional mirrors', () {
    expect(MirrorService.entriesFor(MirrorCategory.apk).length, 10);
    expect(MirrorService.entriesFor(MirrorCategory.apt).length, 7);
    expect(MirrorService.entriesFor(MirrorCategory.pip).length, 6);
    expect(MirrorService.entriesFor(MirrorCategory.npm).length, 4);
    expect(
      MirrorService.officialEntry(MirrorCategory.apk).id,
      'alpine.official',
    );
    expect(
      MirrorService.officialEntry(MirrorCategory.apt).baseUrl,
      'http://ports.ubuntu.com/ubuntu-ports/',
    );
    expect(
      MirrorService.findEntry(MirrorCategory.apk, id: 'alpine.tuna')?.baseUrl,
      'https://mirrors.tuna.tsinghua.edu.cn/alpine/',
    );
    expect(
      MirrorService.entriesFor(
        MirrorCategory.apk,
      ).first.probeUri(MirrorCategory.apk).path,
      contains('v3.21/main/aarch64/APKINDEX.tar.gz'),
    );
  });

  test(
    'Debian sources and Alpine probes follow the installed system and version',
    () async {
      final scripts = <String>[];
      final urls = <Uri>[];
      final mirrors = service(
        scripts: scripts,
        client: MockClient((request) async {
          urls.add(request.url);
          return http.Response('', 200);
        }),
      );
      await env.setState(
        const EnvironmentState(
          distro: 'debian',
          version: '13',
          codename: 'trixie',
          arch: 'arm64',
        ),
      );
      await mirrors.restoreOfficial(MirrorCategory.apt);
      expect(scripts.last, contains('https://deb.debian.org/debian'));
      expect(scripts.last, contains('trixie-security'));
      expect(scripts.last, isNot(contains('ubuntu')));
      await mirrors.detect(MirrorCategory.apt);
      expect(
        urls.every((uri) => uri.path.endsWith('/dists/trixie/Release')),
        isTrue,
      );
      urls.clear();
      await env.setState(
        const EnvironmentState(
          distro: 'alpine',
          version: '3.24.1',
          arch: 'amd64',
        ),
      );
      await mirrors.detect(MirrorCategory.apk);
      expect(
        urls.every(
          (uri) => uri.path.endsWith('/v3.24/main/x86_64/APKINDEX.tar.gz'),
        ),
        isTrue,
      );
      await mirrors.restoreOfficial(MirrorCategory.apk);
      expect(scripts.last, contains('/v3.24/main'));
    },
  );

  test(
    'ARMv7 Alpine probes its own package index and Ubuntu uses ports',
    () async {
      final urls = <Uri>[];
      final scripts = <String>[];
      final mirrors = service(
        scripts: scripts,
        client: MockClient((request) async {
          urls.add(request.url);
          return http.Response('', 200);
        }),
      );
      await env.setState(
        const EnvironmentState(
          distro: 'alpine',
          version: '3.24.1',
          arch: 'armhf',
        ),
      );
      await mirrors.detect(MirrorCategory.apk);
      expect(urls, isNotEmpty);
      expect(
        urls.every(
          (uri) => uri.path.endsWith('/v3.24/main/armv7/APKINDEX.tar.gz'),
        ),
        isTrue,
      );
      await env.setState(
        const EnvironmentState(
          distro: 'ubuntu',
          version: '24.04.3',
          codename: 'noble',
          arch: 'armhf',
        ),
      );
      await mirrors.restoreOfficial(MirrorCategory.apt);
      expect(scripts.single, contains('http://ports.ubuntu.com/ubuntu-ports'));
    },
  );

  test('detect then apply persists id, name, and guest script', () async {
    final scripts = <String>[];
    final client = MockClient((request) async {
      if (request.url.host.contains('tuna')) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        return http.Response.bytes(const <int>[1], 206);
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return http.Response.bytes(const <int>[1], 206);
    });
    final mirrors = service(client: client, scripts: scripts);

    final probes = await mirrors.detect(MirrorCategory.pip);
    expect(probes, isNotEmpty);
    expect(probes.any((p) => p.ok), isTrue);

    final tuna = MirrorService.findEntry(MirrorCategory.pip, id: 'pip.tuna')!;
    await mirrors.apply(MirrorCategory.pip, tuna.baseUri);

    expect(scripts, [GuestScripts.applyPipMirror(tuna.baseUri.toString())]);
    final selection = env.mirrors[MirrorCategory.pip];
    expect(selection?.selectedBaseUrl, tuna.baseUrl);
    expect(selection?.useMirror, isTrue);
    expect(selection?.mirrorId, 'pip.tuna');
    expect(selection?.displayName, 'Tsinghua TUNA');
    expect(selection?.manual, isTrue);
  });

  test('restoreOfficial writes official source and clears useMirror', () async {
    final scripts = <String>[];
    final mirrors = service(scripts: scripts);
    await mirrors.restoreOfficial(MirrorCategory.npm);
    expect(scripts, [
      GuestScripts.applyNpmMirror('https://registry.npmjs.org'),
    ]);
    expect(env.mirrors[MirrorCategory.npm]?.useMirror, isFalse);
    expect(
      env.mirrors[MirrorCategory.npm]?.selectedBaseUrl,
      MirrorService.officialEntry(MirrorCategory.npm).baseUrl,
    );
    expect(env.mirrors[MirrorCategory.npm]?.mirrorId, 'npm.official');
  });

  test('probe stream emits incrementally as mirrors complete', () async {
    final client = MockClient((request) async {
      if (request.url.host.contains('pypi.org')) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      return http.Response.bytes(const <int>[1], 200);
    });
    final emitted = <String>[];
    await for (final result in service(
      client: client,
    ).probeCategory(MirrorCategory.pip)) {
      emitted.add(result.entry.id);
    }
    expect(
      emitted,
      hasLength(MirrorService.entriesFor(MirrorCategory.pip).length),
    );
    expect(emitted.first, isNot('pip.official'));
    expect(emitted.contains('pip.official'), isTrue);
  });

  test('probe times out a hung candidate', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(seconds: 2));
      return http.Response.bytes(const <int>[1], 200);
    });
    final results = await service(
      client: client,
      timeout: const Duration(milliseconds: 20),
    ).probeCategory(MirrorCategory.npm).toList();
    expect(results, isNotEmpty);
    expect(results.every((item) => item.timedOut || !item.ok), isTrue);
  });

  test('probe falls back from failed HEAD to ranged GET', () async {
    final methods = <String>[];
    final client = MockClient((request) async {
      methods.add(request.method);
      if (request.method == 'HEAD') {
        return http.Response('', 405);
      }
      expect(request.headers['range'] ?? request.headers['Range'], 'bytes=0-0');
      return http.Response.bytes(const <int>[1], 206);
    });
    final results = await service(
      client: client,
    ).probeCategory(MirrorCategory.npm).toList();
    expect(results.any((item) => item.ok), isTrue);
    expect(methods.contains('HEAD'), isTrue);
    expect(methods.contains('GET'), isTrue);
  });

  test('apply then restore official apk updates provider', () async {
    final scripts = <String>[];
    final mirrors = service(scripts: scripts);
    final aliyun = MirrorService.findEntry(
      MirrorCategory.apk,
      id: 'alpine.aliyun',
    )!;
    final official = MirrorService.officialEntry(MirrorCategory.apk);

    await mirrors.applyEntry(MirrorCategory.apk, aliyun);
    expect(env.mirrors[MirrorCategory.apk]?.useMirror, isTrue);
    expect(env.mirrors[MirrorCategory.apk]?.mirrorId, 'alpine.aliyun');
    expect(scripts, [
      GuestScripts.applyApkMirror(aliyun.baseUri.toString(), 'v3.21'),
    ]);

    await mirrors.applyEntry(MirrorCategory.apk, official);
    expect(
      scripts.last,
      GuestScripts.applyApkMirror(
        'https://dl-cdn.alpinelinux.org/alpine',
        'v3.21',
      ),
    );
    expect(env.mirrors[MirrorCategory.apk]?.useMirror, isFalse);
    expect(env.mirrors[MirrorCategory.apk]?.mirrorId, 'alpine.official');
    expect(env.mirrors[MirrorCategory.apk]?.selectedBaseUrl, official.baseUrl);
    expect(env.mirrors[MirrorCategory.apk]?.manual, isTrue);
  });

  test('failed restore keeps the last applied mirror selection', () async {
    final scripts = <String>[];
    final aliyun = MirrorService.findEntry(
      MirrorCategory.apk,
      id: 'alpine.aliyun',
    )!;
    final mirrors = service(
      scripts: scripts,
      runInGuest: (script) async {
        scripts.add(script);
        if (script.contains('mirrors.aliyun.com')) return 0;
        return 1;
      },
    );
    await mirrors.applyEntry(MirrorCategory.apk, aliyun);
    await expectLater(
      mirrors.restoreOfficial(MirrorCategory.apk),
      throwsA(isA<StateError>()),
    );
    expect(env.mirrors[MirrorCategory.apk]?.useMirror, isTrue);
    expect(env.mirrors[MirrorCategory.apk]?.mirrorId, 'alpine.aliyun');
  });

  test('autoDetect skips a manual pick', () async {
    final scripts = <String>[];
    await env.setMirror(
      MirrorCategory.pip,
      const MirrorSelection(
        selectedBaseUrl: 'https://mirrors.aliyun.com/pypi/simple/',
        useMirror: true,
        mirrorId: 'pip.aliyun',
        displayName: 'Alibaba',
        manual: true,
      ),
    );
    final client = MockClient(
      (_) async => http.Response.bytes(const <int>[1], 200),
    );
    await service(
      client: client,
      scripts: scripts,
    ).autoDetectAndApplyAll(categories: {MirrorCategory.pip});
    expect(scripts, isEmpty);
    expect(env.mirrors[MirrorCategory.pip]?.mirrorId, 'pip.aliyun');
  });

  test('autoDetect reports apply-phase progress after probes', () async {
    final client = MockClient(
      (_) async => http.Response.bytes(const <int>[1], 200),
    );
    final progress = <MirrorDetectProgress>[];
    await service(client: client).autoDetectAndApplyAll(
      categories: {MirrorCategory.npm},
      onProgress: progress.add,
    );
    expect(progress, isNotEmpty);
    expect(
      progress.where((item) => item.phase == MirrorDetectPhase.probing),
      isNotEmpty,
    );
    expect(
      progress.where((item) => item.phase == MirrorDetectPhase.applying),
      isNotEmpty,
    );
    expect(
      progress
          .where((item) => item.phase == MirrorDetectPhase.probing)
          .last
          .fraction,
      closeTo(0.8, 0.0001),
    );
    expect(progress.last.phase, MirrorDetectPhase.applying);
    expect(progress.last.fraction, closeTo(1.0, 0.0001));
  });

  test('cancel during probe stops before applying', () async {
    final scripts = <String>[];
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return http.Response.bytes(const <int>[1], 200);
    });
    final token = MirrorCancelToken();
    await expectLater(
      service(client: client, scripts: scripts).autoDetectAndApplyAll(
        categories: {MirrorCategory.pip},
        cancelToken: token,
        onProgress: (progress) {
          if (progress.phase == MirrorDetectPhase.probing) {
            token.cancel();
          }
        },
      ),
      throwsA(isA<MirrorCancelledException>()),
    );
    expect(scripts, isEmpty);
  });

  test('hanging guest script times out and cancels the runtime', () async {
    var cancelCalls = 0;
    final tuna = MirrorService.findEntry(MirrorCategory.pip, id: 'pip.tuna')!;
    await expectLater(
      service(
        runInGuest: (_) => Completer<int>().future,
        cancelGuest: () async {
          cancelCalls += 1;
        },
        guestTimeout: const Duration(milliseconds: 20),
      ).applyEntry(MirrorCategory.pip, tuna),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
    expect(cancelCalls, 1);
  });
}
