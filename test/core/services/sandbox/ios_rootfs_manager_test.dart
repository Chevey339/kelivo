import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';

import '../../../support/business_test_harness.dart';
import 'sandbox_channel_harness.dart';

class _DelayedPatchingEnvironment extends EnvironmentProvider {
  _DelayedPatchingEnvironment({required super.preferences});

  final patching = Completer<void>();
  final persisted = Completer<void>();

  @override
  Future<void> setState(EnvironmentState state) async {
    final write = super.setState(state);
    if (state.phase == EnvironmentPhase.patching) {
      patching.complete();
      await persisted.future;
    }
    await write;
  }
}

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

  test(
    'startup recovers a persisted repair without touching user data',
    () async {
      final userFile = File('${tempDir.path}/data/root/keep.txt');
      await userFile.parent.create(recursive: true);
      await userFile.writeAsString('user data');
      await env.setState(
        EnvironmentState(
          phase: EnvironmentPhase.patching,
          distro: 'alpine',
          version: '1',
          availableVersion: '2',
          rootfsDir: tempDir.path,
          progress: 0.8,
        ),
      );
      final reloaded = EnvironmentProvider(preferences: env.preferences);
      final restarted = IosRootfsManager(
        channel: workspace.channel,
        env: reloaded,
      );
      await restarted.recoverInterruptedInstall();
      expect(reloaded.state.phase, EnvironmentPhase.error);
      expect(reloaded.state.errorMessage, 'patch_interrupted');
      expect(reloaded.state.version, '1');
      expect(reloaded.state.availableVersion, '2');
      expect(reloaded.state.rootfsDir, tempDir.path);
      expect(reloaded.state.progress, isNull);
      expect(workspace.methods, isEmpty);
      expect(await userFile.readAsString(), 'user data');
      reloaded.dispose();
    },
  );

  test(
    'interrupted repair of the current version is retried in place',
    () async {
      workspace.probeResult = {
        'supported': true,
        'installed': true,
        'rootfsVersion': '2',
        'bundledVersion': '2',
      };
      await env.setState(
        const EnvironmentState(phase: EnvironmentPhase.patching, version: '2'),
      );
      await manager.recoverInterruptedInstall();
      await manager.install();
      expect(repairScripts, hasLength(1));
      expect(workspace.methods, isNot(contains('installRootfs')));
      expect(workspace.methods, isNot(contains('resetRootfs')));
      expect(env.state.phase, EnvironmentPhase.ready);
      expect(env.state.errorMessage, isNull);
    },
  );

  test(
    'repair never replaces an existing rootfs after a failed probe',
    () async {
      workspace.probeResult = {
        'supported': true,
        'installed': false,
        'bundledVersion': '2',
      };
      final userFile = File('${tempDir.path}/keep.txt');
      await userFile.writeAsString('user data');
      await env.setState(
        const EnvironmentState(phase: EnvironmentPhase.patching),
      );
      await manager.recoverInterruptedInstall();
      await manager.install();
      await manager.repair();
      expect(env.state.phase, EnvironmentPhase.error);
      expect(workspace.methods, isNot(contains('installRootfs')));
      expect(workspace.methods, isNot(contains('resetRootfs')));
      expect(repairScripts, isEmpty);
      expect(await userFile.readAsString(), 'user data');
    },
  );

  for (final phase in [
    EnvironmentPhase.extracting,
    EnvironmentPhase.needsRestart,
  ]) {
    test('startup reconciles $phase with the installed image', () async {
      workspace.probeResult = {
        'supported': true,
        'installed': true,
        'rootfsVersion': '1',
        'bundledVersion': '2',
        'rootfsDir': tempDir.path,
      };
      await env.setState(EnvironmentState(phase: phase));
      await manager.recoverInterruptedInstall();
      expect(env.state.phase, EnvironmentPhase.ready);
      expect(env.state.version, '1');
      expect(workspace.methods, ['probe']);
      expect(repairScripts, isEmpty);
    });
  }

  test('startup clears an incomplete first installation', () async {
    workspace.probeResult = {'supported': true, 'installed': false};
    await env.setState(
      const EnvironmentState(phase: EnvironmentPhase.extracting),
    );
    await manager.recoverInterruptedInstall();
    expect(env.state.phase, EnvironmentPhase.notInstalled);
    expect(workspace.methods, ['probe']);
  });

  test(
    'startup surfaces a native restart requirement instead of stale progress',
    () async {
      workspace.probeResult = {
        'supported': true,
        'installed': true,
        'needsRestart': true,
      };
      await env.setState(
        const EnvironmentState(
          phase: EnvironmentPhase.extracting,
          progress: 0.5,
        ),
      );
      await manager.recoverInterruptedInstall();
      expect(env.state.phase, EnvironmentPhase.needsRestart);
      expect(env.state.progress, isNull);
      expect(workspace.methods, ['probe']);
    },
  );

  test('cancelling during background setup prevents delayed exec', () async {
    workspace.probeResult = {
      'supported': true,
      'installed': true,
      'rootfsVersion': '1',
      'bundledVersion': '2',
    };
    final entered = Completer<void>();
    final setup = Completer<Object?>();
    final released = Completer<void>();
    manager = IosRootfsManager(
      channel: workspace.channel,
      env: env,
      alpineRootfsDir: () async => tempDir,
      repairCancelTimeout: const Duration(milliseconds: 30),
    );
    workspace.handler = (call) {
      if (call.method == 'probe') return workspace.probeResult;
      if (call.method == 'beginBackgroundTask') {
        entered.complete();
        return setup.future;
      }
      if (call.method == 'cancel') return false;
      if (call.method == 'endBackgroundTask') released.complete();
      return null;
    };
    final repair = manager.repair();
    await entered.future;
    await manager.cancel().timeout(const Duration(seconds: 3));
    await repair;
    expect(env.state.phase, EnvironmentPhase.needsRestart);
    expect(env.state.errorMessage, 'patch_interrupted');
    setup.complete(null);
    await released.future.timeout(const Duration(seconds: 3));
    expect(workspace.methods, isNot(contains('exec')));
    expect(File('${tempDir.path}/.version').existsSync(), isFalse);
  });

  test(
    'cancel during patching persistence prevents the repair from starting',
    () async {
      workspace.probeResult = {
        'supported': true,
        'installed': true,
        'rootfsVersion': '1',
        'bundledVersion': '2',
      };
      final delayed = _DelayedPatchingEnvironment(preferences: env.preferences);
      await delayed.loaded;
      manager = IosRootfsManager(
        channel: workspace.channel,
        env: delayed,
        alpineRootfsDir: () async => tempDir,
        runInGuest: (script) async {
          repairScripts.add(script);
          return 0;
        },
      );
      final repair = manager.repair();
      await delayed.patching.future;
      final cancellation = manager.cancel();
      delayed.persisted.complete();
      await Future.wait([repair, cancellation]);
      expect(repairScripts, isEmpty);
      expect(delayed.state.phase, EnvironmentPhase.error);
      expect(delayed.state.errorMessage, 'patch_interrupted');
      expect(File('${tempDir.path}/.version').existsSync(), isFalse);
      delayed.dispose();
    },
  );

  for (final cancel in [false, true]) {
    test(
      'unconfirmed native termination requires restart (cancel=$cancel)',
      () async {
        workspace.probeResult = {
          'supported': true,
          'installed': true,
          'rootfsVersion': '1',
          'bundledVersion': '2',
        };
        manager = IosRootfsManager(
          channel: workspace.channel,
          env: env,
          alpineRootfsDir: () async => tempDir,
        );
        final entered = Completer<void>();
        workspace.handler = (call) {
          if (call.method == 'probe') return workspace.probeResult;
          if (call.method == 'exec') entered.complete();
          if ((call.method == 'exec' && !cancel) || call.method == 'cancel') {
            workspace.emit({
              'type': 'exit',
              'runId': (call.arguments as Map)['runId'],
              'exitCode': -1,
              'timedOut': !cancel,
              'cancelled': cancel,
              'terminationConfirmed': false,
            });
          }
          return call.method == 'cancel' ? true : null;
        };
        final repair = manager.repair();
        await entered.future;
        if (cancel) await manager.cancel();
        await repair;
        expect(env.state.phase, EnvironmentPhase.needsRestart);
        expect(File('${tempDir.path}/.version').existsSync(), isFalse);
        await manager.install();
        expect(
          workspace.methods.where((method) => method == 'exec'),
          hasLength(1),
        );
      },
    );
  }

  test(
    'cancel waits for the native repair to stop before allowing retry',
    () async {
      workspace.probeResult = {
        'supported': true,
        'installed': true,
        'rootfsVersion': '1',
        'bundledVersion': '2',
      };
      final versionFile = File('${tempDir.path}/.version');
      await versionFile.writeAsString('1\n');
      manager = IosRootfsManager(
        channel: workspace.channel,
        env: env,
        alpineRootfsDir: () async => tempDir,
      );
      final entered = Completer<void>();
      var succeed = false;
      workspace.handler = (call) {
        if (call.method == 'probe') return workspace.probeResult;
        if (call.method == 'exec') {
          final runId = (call.arguments as Map)['runId'];
          if (succeed) {
            workspace.emit({
              'type': 'exit',
              'runId': runId,
              'exitCode': 0,
              'terminationConfirmed': true,
            });
          } else {
            entered.complete();
          }
        }
        if (call.method == 'cancel') {
          workspace.emit({
            'type': 'exit',
            'runId': (call.arguments as Map)['runId'],
            'exitCode': -1,
            'cancelled': true,
            'terminationConfirmed': true,
          });
          return true;
        }
        return null;
      };
      final repair = manager.repair();
      await entered.future;
      await manager.cancel();
      await repair;
      expect(env.state.phase, EnvironmentPhase.error);
      expect(env.state.errorMessage, 'patch_interrupted');
      expect(await versionFile.readAsString(), '1\n');
      expect(workspace.methods, contains('endBackgroundTask'));

      succeed = true;
      await manager.install();
      expect(env.state.phase, EnvironmentPhase.ready);
      expect(await versionFile.readAsString(), '2\n');
      expect(workspace.methods, isNot(contains('installRootfs')));
    },
  );

  test('repair deadline cancels a command that never sends its exit', () async {
    workspace.probeResult = {
      'supported': true,
      'installed': true,
      'rootfsVersion': '1',
      'bundledVersion': '2',
    };
    manager = IosRootfsManager(
      channel: workspace.channel,
      env: env,
      alpineRootfsDir: () async => tempDir,
      repairTimeout: const Duration(milliseconds: 30),
    );
    workspace.handler = (call) {
      if (call.method == 'probe') return workspace.probeResult;
      if (call.method == 'cancel') {
        workspace.emit({
          'type': 'exit',
          'runId': (call.arguments as Map)['runId'],
          'exitCode': -1,
          'cancelled': true,
          'terminationConfirmed': true,
        });
        return true;
      }
      return null;
    };
    await manager.repair().timeout(const Duration(seconds: 3));
    expect(env.state.phase, EnvironmentPhase.error);
    expect(env.state.errorMessage, 'patch_timeout');
    expect(workspace.methods, contains('cancel'));
    expect(workspace.methods, contains('endBackgroundTask'));
    expect(File('${tempDir.path}/.version').existsSync(), isFalse);
  });

  test(
    'stalled startup requires restart and late success cannot publish a version',
    () async {
      workspace.probeResult = {
        'supported': true,
        'installed': true,
        'rootfsVersion': '1',
        'bundledVersion': '2',
      };
      final versionFile = File('${tempDir.path}/.version');
      await versionFile.writeAsString('1\n');
      final registered = Completer<Object?>();
      final released = Completer<void>();
      manager = IosRootfsManager(
        channel: workspace.channel,
        env: env,
        alpineRootfsDir: () async => tempDir,
        repairTimeout: const Duration(milliseconds: 30),
        repairCancelTimeout: const Duration(milliseconds: 30),
      );
      workspace.handler = (call) {
        if (call.method == 'probe') return workspace.probeResult;
        if (call.method == 'exec') {
          workspace.emit({
            'type': 'exit',
            'runId': (call.arguments as Map)['runId'],
            'exitCode': 0,
            'terminationConfirmed': true,
          });
          return registered.future;
        }
        if (call.method == 'cancel') return true;
        if (call.method == 'endBackgroundTask') released.complete();
        return null;
      };
      await manager.repair().timeout(const Duration(seconds: 3));
      expect(env.state.phase, EnvironmentPhase.needsRestart);
      expect(env.state.errorMessage, 'patch_timeout');
      await manager.install();
      expect(workspace.methods.where((m) => m == 'exec'), hasLength(1));

      registered.complete(null);
      await released.future.timeout(const Duration(seconds: 3));
      expect(await versionFile.readAsString(), '1\n');
      expect(env.state.phase, EnvironmentPhase.needsRestart);
      final restarted = IosRootfsManager(channel: workspace.channel, env: env);
      await restarted.recoverInterruptedInstall();
      expect(env.state.phase, EnvironmentPhase.error);
      expect(env.state.errorMessage, 'patch_interrupted');
    },
  );

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
