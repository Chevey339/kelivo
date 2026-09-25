import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';

import '../../../support/business_test_harness.dart';
import 'sandbox_channel_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SandboxChannelHarness workspace;
  late EnvironmentProvider env;
  late IosRootfsManager manager;
  late Directory tempDir;
  late List<String> repairScripts;
  late int repairExitCode;

  setUp(() async {
    workspace = SandboxChannelHarness();
    workspace.install();
    env = EnvironmentProvider(preferences: createBusinessTestPreferences());
    await env.loaded;
    tempDir = Directory.systemTemp.createTempSync('kelivo_ios_rootfs_');
    repairScripts = [];
    repairExitCode = 0;
    manager = IosRootfsManager(
      channel: workspace.channel,
      env: env,
      alpineRootfsDir: () async => tempDir,
      runInGuest: (script) async {
        repairScripts.add(script);
        return repairExitCode;
      },
    );
  });

  tearDown(() {
    workspace.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('mirrorCategories are apk, pip, npm', () {
    expect(manager.mirrorCategories, {
      MirrorCategory.apk,
      MirrorCategory.pip,
      MirrorCategory.npm,
    });
  });

  test('install skips when installed and versions match', () async {
    workspace.probeResult = <String, Object?>{
      'supported': true,
      'installed': true,
      'needsRestart': false,
      'rootfsVersion': '3',
      'bundledVersion': '3',
    };
    await manager.install();
    expect(workspace.methods, isNot(contains('installRootfs')));
    expect(env.state.phase, EnvironmentPhase.ready);
    expect(env.state.distro, 'alpine');
    expect(env.state.version, '3');
    expect(env.state.arch, 'arm64');
  });

  test(
    'update repairs in place and publishes the version after success',
    () async {
      workspace.probeResult = <String, Object?>{
        'supported': true,
        'installed': true,
        'needsRestart': false,
        'rootfsVersion': '1',
        'bundledVersion': '2',
      };
      await File('${tempDir.path}/.version').writeAsString('1\n');
      final userFile = File('${tempDir.path}/data/root/keep.txt');
      await userFile.parent.create(recursive: true);
      await userFile.writeAsString('user data');
      await manager.install();
      expect(workspace.methods, isNot(contains('installRootfs')));
      expect(repairScripts, ['/bin/sh /usr/local/bin/kelivo-repair-rootfs']);
      expect(await File('${tempDir.path}/.version').readAsString(), '2\n');
      expect(await userFile.readAsString(), 'user data');
      expect(env.state.phase, EnvironmentPhase.ready);
      expect(env.state.version, '2');
      expect(env.state.distro, 'alpine');
    },
  );

  test('repair also runs when the installed version is current', () async {
    workspace.probeResult = {
      'supported': true,
      'installed': true,
      'rootfsVersion': '2',
      'bundledVersion': '2',
    };
    await manager.repair();
    expect(repairScripts, hasLength(1));
    expect(workspace.methods, isNot(contains('installRootfs')));
    expect(env.state.phase, EnvironmentPhase.ready);
  });

  test('failed repair keeps the old version and can be retried', () async {
    workspace.probeResult = {
      'supported': true,
      'installed': true,
      'rootfsVersion': '1',
      'bundledVersion': '2',
    };
    final versionFile = File('${tempDir.path}/.version');
    await versionFile.writeAsString('1\n');
    repairExitCode = 1;
    await manager.install();
    expect(await versionFile.readAsString(), '1\n');
    expect(env.state.phase, EnvironmentPhase.error);
    expect(env.state.errorMessage, 'patch_failed');
    expect(env.state.version, '1');
    expect(env.state.availableVersion, '2');
    expect(workspace.methods, isNot(contains('installRootfs')));

    repairExitCode = 0;
    await manager.install();
    expect(await versionFile.readAsString(), '2\n');
    expect(env.state.phase, EnvironmentPhase.ready);
    expect(env.state.errorMessage, isNull);
    expect(env.state.availableVersion, isNull);
  });

  test('concurrent update and repair share one package transaction', () async {
    workspace.probeResult = {
      'supported': true,
      'installed': true,
      'rootfsVersion': '1',
      'bundledVersion': '2',
    };
    final started = Completer<void>();
    final finished = Completer<int>();
    manager = IosRootfsManager(
      channel: workspace.channel,
      env: env,
      alpineRootfsDir: () async => tempDir,
      runInGuest: (script) {
        repairScripts.add(script);
        started.complete();
        return finished.future;
      },
    );
    final update = manager.install();
    await started.future;
    final repair = manager.repair();
    expect(repairScripts, hasLength(1));
    expect(File('${tempDir.path}/.version').existsSync(), isFalse);
    finished.complete(0);
    await Future.wait([update, repair]);
    expect(env.state.phase, EnvironmentPhase.ready);
  });

  test('retry does not skip a failed repair of the current version', () async {
    workspace.probeResult = {
      'supported': true,
      'installed': true,
      'rootfsVersion': '2',
      'bundledVersion': '2',
    };
    repairExitCode = 1;
    await manager.repair();
    expect(env.state.phase, EnvironmentPhase.error);
    repairExitCode = 0;
    await manager.install();
    expect(repairScripts, hasLength(2));
    expect(env.state.phase, EnvironmentPhase.ready);
  });

  test(
    'repair waits for a required restart without changing the image',
    () async {
      workspace.probeResult = {
        'supported': true,
        'installed': true,
        'needsRestart': true,
        'rootfsVersion': '1',
        'bundledVersion': '2',
      };
      await manager.repair();
      expect(repairScripts, isEmpty);
      expect(workspace.methods, isNot(contains('installRootfs')));
      expect(env.state.phase, EnvironmentPhase.needsRestart);
    },
  );

  test('install runs when rootfs is missing', () async {
    workspace.probeResult = <String, Object?>{
      'supported': true,
      'installed': false,
      'needsRestart': false,
      'bundledVersion': '4',
    };
    await manager.install();
    expect(workspace.methods, contains('installRootfs'));
    expect(env.state.phase, EnvironmentPhase.ready);
    expect(env.state.version, '4');
  });

  test('install maps needsRestart from installRootfs', () async {
    workspace.probeResult = <String, Object?>{
      'supported': true,
      'installed': false,
      'bundledVersion': '5',
    };
    workspace.handler = (call) {
      if (call.method == 'probe') return workspace.probeResult;
      if (call.method == 'installRootfs') {
        return <String, Object?>{'ok': false, 'needsRestart': true};
      }
      return null;
    };
    await manager.install();
    expect(env.state.phase, EnvironmentPhase.needsRestart);
    expect(env.state.version, '5');
  });

  test('install drives progress from install events', () async {
    workspace.probeResult = <String, Object?>{
      'supported': true,
      'installed': false,
      'bundledVersion': '6',
    };
    final seen = <EnvironmentState>[];
    workspace.handler = (call) {
      if (call.method == 'probe') return workspace.probeResult;
      if (call.method == 'installRootfs') {
        workspace.emit(<String, Object?>{
          'type': 'install',
          'phase': 'extract',
          'progress': 0.4,
        });
        return <String, Object?>{'ok': true};
      }
      return null;
    };
    await manager.install(onProgress: seen.add);
    expect(
      seen.any(
        (s) => s.phase == EnvironmentPhase.extracting && s.progress == 0.4,
      ),
      isTrue,
    );
    expect(env.state.phase, EnvironmentPhase.ready);
    expect(env.state.progress, isNull);
  });

  test('reset reports needsRestart when native says so', () async {
    workspace.handler = (call) {
      if (call.method == 'resetRootfs') {
        return <String, Object?>{'ok': true, 'needsRestart': true};
      }
      return null;
    };
    await manager.reset();
    expect(env.state.phase, EnvironmentPhase.needsRestart);
  });

  test('reset becomes notInstalled when restart is not required', () async {
    await manager.reset();
    expect(env.state.phase, EnvironmentPhase.notInstalled);
  });

  test('checkForUpdate sets availableVersion when versions differ', () async {
    workspace.probeResult = <String, Object?>{
      'supported': true,
      'installed': true,
      'rootfsVersion': '1',
      'bundledVersion': '2',
    };
    expect(await manager.checkForUpdate(), isTrue);
    expect(env.state.availableVersion, '2');
  });

  test('ensureInstalled is a no-op when already ready', () async {
    await env.setState(const EnvironmentState(phase: EnvironmentPhase.ready));
    await manager.ensureInstalled();
    expect(workspace.methods, isEmpty);
  });
}
