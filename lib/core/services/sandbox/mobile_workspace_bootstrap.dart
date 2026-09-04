import 'package:flutter/foundation.dart';

import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/android_proot_runtime.dart';
import 'package:Kelivo/core/services/sandbox/environment_installer.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/sandbox/guest_script_runner.dart';
import 'package:Kelivo/core/services/sandbox/ios_ish_runtime.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';
import 'package:Kelivo/core/services/sandbox/mirror_speed_test.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_source.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/utils/app_directories.dart';

class MobileWorkspaceStack {
  const MobileWorkspaceStack({
    required this.runtime,
    required this.manager,
    required this.mirrors,
    required this.channel,
  });

  final WorkspaceRuntime runtime;
  final EnvironmentManager manager;
  final MirrorService mirrors;
  final WorkspaceChannel channel;
}

/// Builds the Android / iOS workspace stack. Returns null on other platforms.
Future<MobileWorkspaceStack?> createMobileWorkspaceStack({
  required EnvironmentProvider env,
}) async {
  if (kIsWeb) return null;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return _android(env);
    case TargetPlatform.iOS:
      return _ios(env);
    default:
      return null;
  }
}

Future<MobileWorkspaceStack> _android(EnvironmentProvider env) async {
  final channel = WorkspaceChannel();
  final speedTest = MirrorSpeedTest();
  final installer = EnvironmentInstaller(
    channel: channel,
    env: env,
    source: RootfsSource(),
    speedTest: speedTest,
    environmentDir: await AppDirectories.getEnvironmentDirectory(),
  );
  final runtime = AndroidProotRuntime(
    channel: channel,
    env: env,
    rootfsDir: installer.rootfsDir,
    tmpDir: installer.tmpDir,
  );
  final guest = _MirrorGuestRunner(runtime);
  return MobileWorkspaceStack(
    runtime: runtime,
    manager: installer,
    mirrors: MirrorService(
      env: env,
      speedTest: speedTest,
      runInGuest: guest.run,
      cancelGuest: guest.cancel,
    ),
    channel: channel,
  );
}

Future<MobileWorkspaceStack> _ios(EnvironmentProvider env) async {
  final channel = WorkspaceChannel();
  final runtime = IosIshRuntime(channel: channel);
  final guest = _MirrorGuestRunner(runtime);
  return MobileWorkspaceStack(
    runtime: runtime,
    manager: IosRootfsManager(channel: channel, env: env),
    mirrors: MirrorService(
      env: env,
      speedTest: MirrorSpeedTest(),
      runInGuest: guest.run,
      cancelGuest: guest.cancel,
    ),
    channel: channel,
  );
}

class _MirrorGuestRunner {
  _MirrorGuestRunner(this.runtime);

  final WorkspaceRuntime runtime;
  String? lastRunId;

  Future<int> run(String script) {
    lastRunId = 'mirror-guest-${DateTime.now().microsecondsSinceEpoch}';
    return runGuestScript(
      runtime,
      script,
      runId: lastRunId,
      timeout: MirrorService.guestScriptTimeout,
    );
  }

  Future<void> cancel() async {
    final id = lastRunId;
    if (id == null) return;
    await runtime.cancel(id);
  }
}
