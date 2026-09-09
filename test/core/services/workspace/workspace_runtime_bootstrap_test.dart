import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/workspace/desktop_process_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime_bootstrap.dart';

import '../../../support/business_test_harness.dart';

void main() {
  final isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  late EnvironmentProvider env;

  setUp(() {
    env = EnvironmentProvider(preferences: createBusinessTestPreferences());
  });

  test(
    'createWorkspaceStack uses DesktopProcessRuntime on desktop',
    () async {
      final stack = await createWorkspaceStack(env: env);
      expect(stack.runtime, isA<DesktopProcessRuntime>());
      expect(stack.environmentManager, isNull);
      expect(stack.mirrors, isNull);
    },
    skip: isDesktop ? false : 'host is not desktop',
  );

  test(
    'applyWorkspaceStack registers runtime',
    () async {
      final stack = await createWorkspaceStack(env: env);
      final provider = WorkspaceRuntimeProvider();
      applyWorkspaceStack(provider, stack);
      expect(provider.runtime, same(stack.runtime));
      expect(provider.runtime, isA<DesktopProcessRuntime>());
    },
    skip: isDesktop ? false : 'host is not desktop',
  );
}
