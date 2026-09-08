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
      checksumOverrides: {'armhf': digest, 'arm64': digest, 'amd64': digest},
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
        '${const RootfsSource().tarballFileName('arm64')}.part',
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
          '${const RootfsSource().tarballFileName('arm64')}.part',
        ),
      );
      await part.parent.create(recursive: true);
      await part.writeAsBytes(tarball);
      await File(
        '${part.path}.url',
      ).writeAsString('${const RootfsSource().officialTarballUri('arm64')}');
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
    expect(env.state.version, RootfsCatalog.defaultImage.version);
    expect(env.state.arch, 'arm64');
    expect(env.state.distro, RootfsCatalog.defaultImage.distro);
    expect(env.state.installedAt, isNotNull);
    expect(env.state.rootfsDir, installer.rootfsDir.path);
    expect(
      await File(
        p.join(installer.rootfsDir.path, kKelivoVersionFile),
      ).readAsString(),
      'ubuntu 24.04.3 arm64 noble\n',
    );
    expect(workspace.keepScreenOnCalls, [true, false]);
    expect(workspace.patchArgs?['gids'], kAndroidNetworkGids);
    expect(
      workspace.patchArgs?['ubuntuCodename'],
      RootfsCatalog.defaultImage.codename,
    );
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
      p.join(envDir.path, 'downloads', 'ubuntu-24.04.3-arm64.tar.gz.part'),
    );
    expect(await part.exists(), isFalse);
  });

  test(
    'ARMv7 installation downloads and persists an armhf environment',
    () async {
      workspace.probeAbi = 'armeabi-v7a';
      workspace.rootfsInfo['arch'] = 'armhf';
      await env.setDownloadSource(RootfsDownloadSource.official);
      final requests = <http.BaseRequest>[];
      final installer = buildInstaller(servingTarball(onRequest: requests.add));
      await installer.install();
      expect(env.state.phase, EnvironmentPhase.ready);
      expect(env.state.arch, 'armhf');
      expect(
        requests.single.url.path,
        endsWith('ubuntu-base-24.04.3-base-armhf.tar.gz'),
      );
      expect(workspace.patchArgs?['arch'], 'armhf');
      expect(
        await File(
          p.join(installer.rootfsDir.path, kKelivoVersionFile),
        ).readAsString(),
        'ubuntu 24.04.3 armhf noble\n',
      );
    },
  );

  test('resumes from an existing .part with HTTP 206', () async {
    workspace.freeBytes = 8 * 1024 * 1024 * 1024;
    final part = File(
      p.join(envDir.path, 'downloads', 'ubuntu-24.04.3-arm64.tar.gz.part'),
    );
    await part.create(recursive: true);
    await part.writeAsBytes(tarball.sublist(0, 4));
    await File(
      '${part.path}.url',
    ).writeAsString('${const RootfsSource().officialTarballUri('arm64')}');
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
    expect(workspace.extractedBytes, tarball);
    expect(await part.exists(), isFalse);
  });

  test('restarts when the server ignores Range and returns 200', () async {
    workspace.freeBytes = 8 * 1024 * 1024 * 1024;
    final part = File(
      p.join(envDir.path, 'downloads', 'ubuntu-24.04.3-arm64.tar.gz.part'),
    );
    await part.create(recursive: true);
    await part.writeAsBytes(const <int>[1, 2, 3, 4]);
    await File(
      '${part.path}.url',
    ).writeAsString('${const RootfsSource().officialTarballUri('arm64')}');
    final installer = buildInstaller(servingTarball(ignoreRange: true));
    await installer.install();
    expect(env.state.phase, EnvironmentPhase.ready);
    expect(workspace.extractedBytes, tarball);
    expect(await part.exists(), isFalse);
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
    workspace.probeAbi = 'x86';
    final installer = buildInstaller(servingTarball());
    await installer.install();
    expect(env.state.phase, EnvironmentPhase.error);
    expect(env.state.errorMessage, EnvironmentError.unsupportedAbi);
  });

  for (final phase in [
    EnvironmentPhase.ready,
    EnvironmentPhase.notInstalled,
    EnvironmentPhase.patching,
  ]) {
    for (final action in ['ensure', 'repair', 'recover']) {
      test(
        '$action rejects an incompatible installed rootfs from $phase',
        () async {
          final installer = buildInstaller(
            MockClient((_) => throw StateError('No HTTP expected')),
          );
          await installer.rootfsDir.create();
          final marker = await File(
            p.join(installer.rootfsDir.path, kKelivoVersionFile),
          ).writeAsString('ubuntu 24.04.3 arm64 noble\n');
          final userFile = await File(
            p.join(installer.rootfsDir.path, 'keep.txt'),
          ).writeAsString('user data');
          await env.setState(EnvironmentState(phase: phase));
          workspace.probeAbi = 'armeabi-v7a';

          switch (action) {
            case 'ensure':
              await installer.ensureInstalled();
            case 'repair':
              await installer.repair();
            case 'recover':
              await installer.recoverInterruptedInstall();
          }

          expect(env.state.phase, EnvironmentPhase.error);
          expect(env.state.errorMessage, EnvironmentError.architectureMismatch);
          expect(workspace.patchArgs, isNull);
          expect(workspace.extractedBytes, isNull);
          expect(await userFile.readAsString(), 'user data');
          expect(await marker.readAsString(), 'ubuntu 24.04.3 arm64 noble\n');
        },
      );
    }
  }

  for (final failReplacement in [false, true]) {
    test(
      'explicit reinstall after an ABI switch, failure=$failReplacement',
      () async {
        final installer = buildInstaller(servingTarball());
        await installer.install();
        final userFile = await File(
          p.join(installer.rootfsDir.path, 'keep.txt'),
        ).writeAsString('user data');
        workspace.probeAbi = 'armeabi-v7a';
        workspace.rootfsInfo['arch'] = 'armhf';
        workspace.rejectExtract = failReplacement;
        await installer.install();
        expect(
          env.state.phase,
          failReplacement ? EnvironmentPhase.error : EnvironmentPhase.ready,
        );
        expect(env.state.arch, failReplacement ? 'arm64' : 'armhf');
        if (failReplacement) {
          expect(await userFile.readAsString(), 'user data');
          await installer.ensureInstalled();
          expect(env.state.phase, EnvironmentPhase.error);
          expect(env.state.errorMessage, EnvironmentError.architectureMismatch);
        } else {
          expect(env.state.errorMessage, isNull);
          expect(
            await File(
              p.join(installer.rootfsDir.path, kKelivoVersionFile),
            ).readAsString(),
            'ubuntu 24.04.3 armhf noble\n',
          );
        }
      },
    );
  }

  test(
    'Alpine selects its image, checksum, package manager and smaller disk budget',
    () async {
      workspace.freeBytes = 100 * 1024 * 1024;
      workspace.rootfsInfo = {
        'distro': 'alpine',
        'version': '3.24.1',
        'codename': 'v3.24',
        'arch': 'arm64',
      };
      await env.setRootfsSelection(
        imageId: 'alpine-3.24.1',
        source: RootfsDownloadSource.official,
      );
      final installer = buildInstaller(servingTarball());
      await installer.install();
      expect(env.state.phase, EnvironmentPhase.ready);
      expect(env.state.distro, 'alpine');
      expect(env.state.codename, 'v3.24');
      expect(installer.mirrorCategories, contains(MirrorCategory.apk));
      expect(installer.mirrorCategories, isNot(contains(MirrorCategory.apt)));
      expect(workspace.busyCalls, [true, false]);
    },
  );

  test(
    'local xz import detects Debian without downloading and keeps the original archive',
    () async {
      final archive = await File(
        p.join(envDir.path, 'local.tar.xz'),
      ).writeAsBytes(tarball);
      workspace.rootfsInfo = {
        'distro': 'debian',
        'version': '13',
        'codename': 'trixie',
        'arch': 'arm64',
      };
      await env.setRootfsSelection(
        imageId: 'ubuntu-24.04.3',
        source: RootfsDownloadSource.local,
        localArchivePath: archive.path,
      );
      final installer = buildInstaller(
        MockClient((_) => throw StateError('No HTTP expected')),
      );
      await installer.install();
      expect(env.state.phase, EnvironmentPhase.ready);
      expect(env.state.distro, 'debian');
      expect(env.state.codename, 'trixie');
      expect(env.state.version, '13');
      expect(workspace.extractedFormat, 'tar.xz');
      expect(await archive.readAsBytes(), tarball);
      expect(workspace.patchArgs?['aptMirrorBaseUrl'], isNull);
    },
  );

  for (final extractFailure in [true, false]) {
    test(
      'failed replacement preserves the installed rootfs, extract=$extractFailure',
      () async {
        final installer = buildInstaller(servingTarball());
        await installer.install();
        final original = await File(
          p.join(installer.rootfsDir.path, 'keep.txt'),
        ).writeAsString('user work');
        workspace.rejectExtract = extractFailure;
        workspace.rejectImage = !extractFailure;
        await installer.install();
        expect(env.state.phase, EnvironmentPhase.ready);
        expect(
          env.state.errorMessage,
          extractFailure
              ? EnvironmentError.extractFailed
              : EnvironmentError.invalidRootfs,
        );
        expect(await original.readAsString(), 'user work');
        expect(await installer.stagingRootfsDir.exists(), isFalse);
        expect(workspace.busyCalls.last, false);
      },
    );
  }

  test(
    'startup recovers the previous rootfs if replacement stopped between renames',
    () async {
      final previous = await Directory(
        p.join(envDir.path, 'previous-rootfs'),
      ).create();
      await File(
        p.join(previous.path, kKelivoVersionFile),
      ).writeAsString('debian 13 arm64 trixie\n');
      await File(p.join(previous.path, 'keep.txt')).writeAsString('old work');
      await env.setState(
        const EnvironmentState(phase: EnvironmentPhase.patching),
      );
      final installer = buildInstaller(servingTarball());
      await installer.recoverInterruptedInstall();
      expect(env.state.phase, EnvironmentPhase.ready);
      expect(env.state.distro, 'debian');
      expect(
        await File(p.join(installer.rootfsDir.path, 'keep.txt')).readAsString(),
        'old work',
      );
    },
  );

  for (final dangling in [false, true]) {
    test(
      'local image marker cannot write through a symlink, dangling=$dangling',
      () async {
        final outside = File(p.join(envDir.path, 'outside-marker'));
        if (!dangling) await outside.writeAsString('keep original contents');
        workspace.versionLinkTarget = outside.path;
        final archive = await File(
          p.join(envDir.path, 'local.tar'),
        ).writeAsBytes(tarball);
        await env.setRootfsSelection(
          imageId: RootfsCatalog.defaultImage.id,
          source: RootfsDownloadSource.local,
          localArchivePath: archive.path,
        );
        final installer = buildInstaller(
          MockClient((_) => throw StateError('No HTTP expected')),
        );
        await installer.install();
        expect(env.state.phase, EnvironmentPhase.ready);
        if (dangling) {
          expect(await outside.exists(), isFalse);
        } else {
          expect(await outside.readAsString(), 'keep original contents');
        }
        final marker = File(
          p.join(installer.rootfsDir.path, kKelivoVersionFile),
        );
        expect(
          await FileSystemEntity.type(marker.path, followLinks: false),
          FileSystemEntityType.file,
        );
        expect(await marker.readAsString(), 'ubuntu 24.04.3 arm64 noble\n');
      },
    );
  }

  for (final hasCurrent in [true, false]) {
    test(
      'reset removes recovery rootfs before restart, current=$hasCurrent',
      () async {
        final installer = buildInstaller(servingTarball());
        final previous = await Directory(
          p.join(envDir.path, 'previous-rootfs'),
        ).create();
        await File(
          p.join(previous.path, kKelivoVersionFile),
        ).writeAsString('debian 12 arm64 bookworm\n');
        if (hasCurrent) {
          await installer.rootfsDir.create();
          await File(
            p.join(installer.rootfsDir.path, kKelivoVersionFile),
          ).writeAsString('ubuntu 24.04.3 arm64 noble\n');
        }
        await env.setState(
          EnvironmentState(
            phase: hasCurrent
                ? EnvironmentPhase.ready
                : EnvironmentPhase.patching,
          ),
        );
        await installer.reset();
        expect(await installer.rootfsDir.exists(), isFalse);
        final restarted = buildInstaller(servingTarball());
        await restarted.recoverInterruptedInstall();
        expect(await restarted.rootfsDir.exists(), isFalse);
        expect(await previous.exists(), isFalse);
        expect(env.state.phase, EnvironmentPhase.notInstalled);
      },
    );
  }

  test('local newer releases are not offered a downgrade', () async {
    final installer = buildInstaller(servingTarball());
    await installer.rootfsDir.create();
    await File(
      p.join(installer.rootfsDir.path, kKelivoVersionFile),
    ).writeAsString('alpine 3.25.1 arm64 v3.25\n');
    expect(await installer.checkForUpdate(), isFalse);
    expect(env.state.availableVersion, isNull);
  });

  test('update check does not change the default download selection', () async {
    final installer = buildInstaller(servingTarball());
    await installer.install();
    expect(env.state.version, '24.04.3');
    expect(await installer.checkForUpdate(), isTrue);
    expect(env.state.availableVersion, '24.04.4');
    expect(env.rootfsImage.id, 'ubuntu-24.04.3');
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
  bool rejectImage = false;
  bool rejectExtract = false;
  List<int>? extractedBytes;
  String? extractedFormat;
  String? versionLinkTarget;
  final busyCalls = <bool>[];
  Map<String, String> rootfsInfo = {
    'distro': 'ubuntu',
    'version': '24.04.3',
    'codename': 'noble',
    'arch': 'arm64',
  };
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
        case 'setEnvironmentBusy':
          busyCalls.add((call.arguments as Map)['busy'] == true);
          return null;
        case 'extractRootfs':
          if (rejectExtract) throw PlatformException(code: 'extract_failed');
          extractedBytes = await File(
            (call.arguments as Map)['archivePath'] as String,
          ).readAsBytes();
          extractedFormat = (call.arguments as Map)['format'] as String;
          final dest = (call.arguments as Map)['destDir'] as String;
          await Directory(dest).create(recursive: true);
          if (versionLinkTarget != null) {
            await Link(
              p.join(dest, kKelivoVersionFile),
            ).create(versionLinkTarget!);
          }
          sink?.success(<String, Object?>{
            'type': 'extract',
            'destDir': dest,
            'entries': 1,
            'bytes': 10,
            'currentEntry': '.',
          });
          return <String, Object?>{'ok': true};
        case 'inspectRootfs':
          if (rejectImage) throw PlatformException(code: 'invalid_rootfs');
          return rootfsInfo;
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
