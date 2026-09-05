import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/environment_installer.dart';
import 'package:Kelivo/core/services/sandbox/mirror_speed_test.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_source.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';

import '../../../support/business_test_harness.dart';

const _officialBase =
    'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory envDir;
  late EnvironmentProvider env;
  late _WorkspaceHarness workspace;
  late List<int> tarball;
  late String digest;

  setUp(() async {
    envDir = await Directory.systemTemp.createTemp('kelivo_env_install_');
    env = EnvironmentProvider(preferences: createBusinessTestPreferences());
    await env.loaded;
    tarball = utf8.encode('tiny-rootfs-archive');
    digest = sha256.convert(tarball).toString();
    workspace = _WorkspaceHarness();
    workspace.install();
  });

  tearDown(() async {
    workspace.dispose();
    if (await envDir.exists()) await envDir.delete(recursive: true);
  });

  EnvironmentInstaller buildInstaller(http.Client client) {
    final source = RootfsSource(
      checksums: {'arm64': digest, 'amd64': digest},
      officialReleaseBase: _officialBase,
      cdimageReleaseBases: const [_officialBase],
    );
    return EnvironmentInstaller(
      channel: workspace.channel,
      env: env,
      source: source,
      speedTest: MirrorSpeedTest(client: client),
      client: client,
      environmentDir: envDir,
    );
  }

  http.Client servingTarball({
    List<int>? bytes,
    bool ignoreRange = false,
    void Function(http.BaseRequest request)? onRequest,
  }) {
    final body = bytes ?? tarball;
    return MockClient((request) async {
      onRequest?.call(request);
      final url = request.url.toString();
      if (url.endsWith('SHA256SUMS')) {
        return http.Response(
          '$digest *ubuntu-base-24.04.3-base-arm64.tar.gz\n',
          200,
        );
      }
      final range = request.headers['range'] ?? request.headers['Range'];
      if (range == 'bytes=0-1023') {
        return http.Response.bytes(body.take(16).toList(), 206);
      }
      if (range != null && range.startsWith('bytes=') && !ignoreRange) {
        final start = int.parse(range.substring(6, range.length - 1));
        final rest = body.sublist(start);
        return http.Response.bytes(
          rest,
          206,
          headers: {
            'content-range': 'bytes $start-${body.length - 1}/${body.length}',
            'content-length': '${rest.length}',
          },
        );
      }
      return http.Response.bytes(
        body,
        200,
        headers: {'content-length': '${body.length}'},
      );
    });
  }

  for (final selected in [
    RootfsDownloadSource.official,
    RootfsDownloadSource.tuna,
    RootfsDownloadSource.huawei,
    RootfsDownloadSource.custom,
  ]) {
    test(
      'explicit $selected bypasses auto probes and official manifest',
      () async {
        await env.setDownloadSource(
          selected,
          customUrl: 'https://custom.test/release/',
        );
        final requests = <http.BaseRequest>[];
        final installer = buildInstaller(
          servingTarball(onRequest: requests.add),
        );
        await installer.install();
        expect(env.state.phase, EnvironmentPhase.ready);
        expect(requests, hasLength(1));
        expect(
          requests.single.url,
          installer.source.selectedUri(selected, env.downloadUrl, 'arm64'),
        );
        expect(requests.single.headers['range'], isNull);
      },
    );
  }

  test('switching source removes the previous partial archive', () async {
    final part = File(
      p.join(
        envDir.path,
        'downloads',
        '${RootfsSource.tarballFileName('arm64')}.part',
      ),
    );
    await part.parent.create(recursive: true);
    await part.writeAsBytes([0, 1, 2]);
    await File(
      '${part.path}.url',
    ).writeAsString('https://old.test/image.tar.gz');
    await env.setDownloadSource(
      RootfsDownloadSource.custom,
      customUrl: 'https://new.test/image.tar.gz',
    );
    final requests = <http.BaseRequest>[];
    await buildInstaller(servingTarball(onRequest: requests.add)).install();
    expect(env.state.phase, EnvironmentPhase.ready);
    expect(requests.single.headers['range'], isNull);
  });

  test(
    'a complete partial archive is verified after a Range 416 response',
    () async {
      final part = File(
        p.join(
          envDir.path,
          'downloads',
          '${RootfsSource.tarballFileName('arm64')}.part',
        ),
      );
      await part.parent.create(recursive: true);
      await part.writeAsBytes(tarball);
      await File('${part.path}.url').writeAsString(
        '$_officialBase/${RootfsSource.tarballFileName('arm64')}',
      );
      await env.setDownloadSource(RootfsDownloadSource.official);
      final installer = buildInstaller(
        MockClient((request) async {
          expect(request.headers['range'], 'bytes=${tarball.length}-');
          return http.Response(
            '',
            416,
            headers: {'content-range': 'bytes */${tarball.length}'},
          );
        }),
      );
      await installer.install();
      expect(env.state.phase, EnvironmentPhase.ready);
    },
  );

  test('custom selection persists across provider recreation', () async {
    await env.setDownloadSource(
      RootfsDownloadSource.custom,
      customUrl: 'https://custom.test/image.tar.gz',
    );
    final reloaded = EnvironmentProvider(preferences: env.preferences);
    await reloaded.loaded;
    expect(reloaded.downloadSource, RootfsDownloadSource.custom);
    expect(reloaded.downloadUrl, 'https://custom.test/image.tar.gz');
    reloaded.dispose();
  });

  test('happy path installs rootfs and writes version file', () async {
    workspace.freeBytes = 8 * 1024 * 1024 * 1024;
    final installer = buildInstaller(servingTarball());
    await installer.install();
    expect(env.state.phase, EnvironmentPhase.ready);
    expect(env.state.version, kUbuntuBaseVersion);
    expect(env.state.arch, 'arm64');
    expect(env.state.distro, kUbuntuDistro);
    expect(env.state.installedAt, isNotNull);
    expect(env.state.rootfsDir, installer.rootfsDir.path);
    expect(
      await File(
        p.join(installer.rootfsDir.path, kKelivoVersionFile),
      ).readAsString(),
      'ubuntu 24.04.3 arm64\n',
    );
    expect(workspace.keepScreenOnCalls, [true, false]);
    expect(workspace.patchArgs?['gids'], kAndroidNetworkGids);
    expect(workspace.patchArgs?['ubuntuCodename'], kUbuntuCodename);
    expect(workspace.patchArgs!.containsKey('aptMirrorBase'), isFalse);
    expect(workspace.patchArgs!.containsKey('aptMirrorBaseUrl'), isFalse);
  });

  test('checksum mismatch deletes part and errors', () async {
    workspace.freeBytes = 8 * 1024 * 1024 * 1024;
    workspace.sha256Override = (_) => '0' * 64;
    final installer = buildInstaller(servingTarball());
    await installer.install();
    expect(env.state.phase, EnvironmentPhase.error);
    expect(env.state.errorMessage, EnvironmentError.checksumMismatch);
    final part = File(
      p.join(
        envDir.path,
        'downloads',
        'ubuntu-base-24.04.3-base-arm64.tar.gz.part',
      ),
    );
    expect(await part.exists(), isFalse);
  });

  test('resumes from an existing .part with HTTP 206', () async {
    workspace.freeBytes = 8 * 1024 * 1024 * 1024;
    final part = File(
      p.join(
        envDir.path,
        'downloads',
        'ubuntu-base-24.04.3-base-arm64.tar.gz.part',
      ),
    );
    await part.create(recursive: true);
    await part.writeAsBytes(tarball.sublist(0, 4));
    await File(
      '${part.path}.url',
    ).writeAsString('$_officialBase/${RootfsSource.tarballFileName('arm64')}');
    String? seenRange;
    final installer = buildInstaller(
      servingTarball(
        onRequest: (request) {
          if (request.url.path.endsWith('.tar.gz')) {
            seenRange = request.headers['range'] ?? request.headers['Range'];
          }
        },
      ),
    );
    await installer.install();
    expect(env.state.phase, EnvironmentPhase.ready);
    expect(seenRange, 'bytes=4-');
    expect(await part.readAsBytes(), tarball);
  });

  test('restarts when the server ignores Range and returns 200', () async {
    workspace.freeBytes = 8 * 1024 * 1024 * 1024;
    final part = File(
      p.join(
        envDir.path,
        'downloads',
        'ubuntu-base-24.04.3-base-arm64.tar.gz.part',
      ),
    );
    await part.create(recursive: true);
    await part.writeAsBytes(const <int>[1, 2, 3, 4]);
    await File(
      '${part.path}.url',
    ).writeAsString('$_officialBase/${RootfsSource.tarballFileName('arm64')}');
    final installer = buildInstaller(servingTarball(ignoreRange: true));
    await installer.install();
    expect(env.state.phase, EnvironmentPhase.ready);
    expect(await part.readAsBytes(), tarball);
  });

  test('insufficient disk', () async {
    workspace.freeBytes = 1024 * 1024;
    final installer = buildInstaller(servingTarball());
    await installer.install();
    expect(env.state.phase, EnvironmentPhase.error);
    expect(env.state.errorMessage, EnvironmentError.insufficientDisk);
  });

  test('cancel mid-download', () async {
    workspace.freeBytes = 8 * 1024 * 1024 * 1024;
    final started = Completer<void>();
    final client = _SlowTarballClient(
      tarball: List<int>.filled(32, 7),
      digest: digest,
      onDownload: started,
    );
    final installer = buildInstaller(client);
    final done = installer.install();
    await started.future;
    await installer.cancel();
    await done;
    expect(env.state.phase, EnvironmentPhase.error);
    expect(env.state.errorMessage, EnvironmentError.cancelled);
  });

  test('unsupported ABI', () async {
    workspace.freeBytes = 8 * 1024 * 1024 * 1024;
    workspace.probeAbi = 'armeabi-v7a';
    final installer = buildInstaller(servingTarball());
    await installer.install();
    expect(env.state.phase, EnvironmentPhase.error);
    expect(env.state.errorMessage, EnvironmentError.unsupportedAbi);
  });

  test('unsupported probe reports proot_missing', () async {
    workspace.probeSupported = false;
    workspace.probeReason = 'proot missing: /lib/libproot.so';
    final installer = buildInstaller(servingTarball());
    await installer.install();
    expect(env.state.errorMessage, EnvironmentError.prootMissing);
  });
}

class _WorkspaceHarness {
  final methodChannel = const MethodChannel(kWorkspaceMethodChannel);
  final eventChannel = const EventChannel(kWorkspaceEventChannel);
  late final WorkspaceChannel channel = WorkspaceChannel(
    methodChannel: methodChannel,
    eventChannel: eventChannel,
  );

  MockStreamHandlerEventSink? sink;
  int freeBytes = 8 * 1024 * 1024 * 1024;
  String probeAbi = 'arm64-v8a';
  bool probeSupported = true;
  String? probeReason;
  String Function(String path)? sha256Override;
  final List<bool> keepScreenOnCalls = <bool>[];
  Map<String, Object?>? patchArgs;

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (args, eventSink) {
          sink = eventSink;
        },
        onCancel: (args) {
          sink = null;
        },
      ),
    );
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      switch (call.method) {
        case 'probe':
          return <String, Object?>{
            'supported': probeSupported,
            'abi': probeAbi,
            'prootPath': '/lib/libproot.so',
            'loaderPath': '/lib/loader.so',
            'nativeLibDir': '/lib',
            'reason': probeReason,
          };
        case 'freeSpace':
          return <String, Object?>{
            'freeBytes': freeBytes,
            'totalBytes': freeBytes * 2,
          };
        case 'sha256File':
          final path = (call.arguments as Map)['path'] as String;
          if (sha256Override != null) return sha256Override!(path);
          return sha256.convert(await File(path).readAsBytes()).toString();
        case 'extractRootfs':
          final dest = (call.arguments as Map)['destDir'] as String;
          await Directory(dest).create(recursive: true);
          sink?.success(<String, Object?>{
            'type': 'extract',
            'destDir': dest,
            'entries': 1,
            'bytes': 10,
            'currentEntry': '.',
          });
          return <String, Object?>{'ok': true};
        case 'patchRootfs':
          patchArgs = Map<String, Object?>.from(call.arguments as Map);
          return <String, Object?>{'ok': true};
        case 'keepScreenOn':
          keepScreenOnCalls.add((call.arguments as Map)['enabled'] == true);
          return null;
        default:
          return null;
      }
    });
  }

  void dispose() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(eventChannel, null);
  }
}

class _SlowTarballClient extends http.BaseClient {
  _SlowTarballClient({
    required this.tarball,
    required this.digest,
    required this.onDownload,
  });

  final List<int> tarball;
  final String digest;
  final Completer<void> onDownload;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    if (url.endsWith('SHA256SUMS')) {
      final bytes = utf8.encode(
        '$digest *ubuntu-base-24.04.3-base-arm64.tar.gz\n',
      );
      return http.StreamedResponse(
        Stream<List<int>>.value(bytes),
        200,
        contentLength: bytes.length,
      );
    }
    final range = request.headers['range'] ?? request.headers['Range'];
    if (range == 'bytes=0-1023') {
      return http.StreamedResponse(
        Stream<List<int>>.value(tarball.take(8).toList()),
        206,
        contentLength: 8,
      );
    }
    if (!onDownload.isCompleted) onDownload.complete();
    final controller = StreamController<List<int>>();
    Future<void>(() async {
      for (final byte in tarball) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        if (controller.isClosed) return;
        controller.add(<int>[byte]);
      }
      if (!controller.isClosed) await controller.close();
    });
    return http.StreamedResponse(
      controller.stream,
      200,
      contentLength: tarball.length,
    );
  }
}
