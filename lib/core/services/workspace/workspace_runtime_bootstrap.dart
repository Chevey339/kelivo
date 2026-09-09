import 'package:Kelivo/core/services/sandbox/environment_dependencies.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';
import 'package:Kelivo/core/services/sandbox/mobile_workspace_bootstrap.dart';

import 'desktop_process_runtime.dart';
import 'workspace_runtime.dart';

class WorkspaceStack {
  const WorkspaceStack({
    this.runtime,
    this.environmentManager,
    this.mirrors,
    this.dependencies,
  });

  final EnvironmentDependencies? dependencies;
  final WorkspaceRuntime? runtime;
  final EnvironmentManager? environmentManager;
  final MirrorService? mirrors;
}

/// Builds the process-wide workspace stack for the current platform.
///
/// Desktop (macOS / Linux / Windows) gets [DesktopProcessRuntime] with no
/// environment manager or mirrors. Android and iOS reuse
/// [createMobileWorkspaceStack]. Everything else is all-null.
Future<WorkspaceStack> createWorkspaceStack({
  required EnvironmentProvider env,
}) async {
  if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
    return WorkspaceStack(runtime: DesktopProcessRuntime());
  }
  final mobile = await createMobileWorkspaceStack(env: env);
  if (mobile == null) {
    return const WorkspaceStack();
  }
  return WorkspaceStack(
    runtime: mobile.runtime,
    environmentManager: mobile.manager,
    mirrors: mobile.mirrors,
    dependencies: mobile.dependencies,
  );
}

/// Registers [stack.runtime] when present and refreshes provider status.
void applyWorkspaceStack(
  WorkspaceRuntimeProvider provider,
  WorkspaceStack stack,
) {
  final runtime = stack.runtime;
  if (runtime != null) {
    provider.register(runtime);
  }
  unawaited(provider.refresh());
}
