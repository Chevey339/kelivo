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

  setUp(() async {
    workspace = SandboxChannelHarness();
    workspace.install();
    env = EnvironmentProvider(preferences: createBusinessTestPreferences());
    await env.loaded;
    tempDir = Directory.systemTemp.createTempSync('kelivo_ios_rootfs_');
    manager = IosRootfsManager(
      channel: workspace.channel,
      env: env,
      alpineRootfsDir: () async => tempDir,
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

  test('install runs when the bundled version differs', () async {
    workspace.probeResult = <String, Object?>{
      'supported': true,
      'installed': true,
      'needsRestart': false,
      'rootfsVersion': '1',
      'bundledVersion': '2',
    };
    await manager.install();
    expect(workspace.methods, contains('installRootfs'));
    expect(env.state.phase, EnvironmentPhase.ready);
    expect(env.state.version, '2');
    expect(env.state.distro, 'alpine');
  });

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
