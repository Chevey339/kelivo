import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/models/environment_variable.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/business_test_harness.dart';
import '../../support/fake_workspace_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'package startup can outlast tool timeout, which is restored after connect',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final harness = await BusinessTestHarness.create();
      final environment = EnvironmentProvider(preferences: harness.preferences);
      await environment.loaded;
      await environment.setState(
        const EnvironmentState(phase: EnvironmentPhase.ready),
      );
      final runtime = _McpRuntime(
        holdFirstInitialization: true,
        stallToolCalls: true,
      );
      final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
      await runtimeProvider.refresh();
      final provider = McpProvider(
        preferences: harness.preferences,
        workspaceRuntime: runtimeProvider,
        environment: environment,
      );
      addTearDown(() async {
        provider.dispose();
        runtimeProvider.dispose();
        environment.dispose();
        await harness.close();
        debugDefaultTargetPlatformOverride = null;
      });
      await provider.updateRequestTimeout(const Duration(milliseconds: 20));
      await provider.replaceAllFromJson(
        jsonEncode({
          'mcpServers': {
            'guest': {'command': 'server'},
          },
        }),
      );
      await runtime.initializationStarted.future;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(provider.statusFor('guest'), McpStatus.connecting);
      runtime.releaseInitialization.complete();
      await _waitFor(() => provider.isConnected('guest'));
      final result = await provider
          .callTool('guest', 'slow', {})
          .timeout(const Duration(seconds: 1));
      expect(
        result!.content.single.toJson()['text'],
        contains('Request timed out: tools/call'),
      );
      expect(provider.requestTimeout, const Duration(milliseconds: 20));
    },
  );

  for (final duringInitialization in [true, false]) {
    test(
      'stdio exit keeps diagnostics (initializing=$duringInitialization)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final harness = await BusinessTestHarness.create();
        final environment = EnvironmentProvider(
          preferences: harness.preferences,
        );
        await environment.loaded;
        await environment.setState(
          const EnvironmentState(phase: EnvironmentPhase.ready),
        );
        final runtime = _McpRuntime(failInitialization: duringInitialization);
        final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
        await runtimeProvider.refresh();
        final provider = McpProvider(
          preferences: harness.preferences,
          workspaceRuntime: runtimeProvider,
          environment: environment,
        );
        addTearDown(() async {
          provider.dispose();
          runtimeProvider.dispose();
          environment.dispose();
          await harness.close();
          debugDefaultTargetPlatformOverride = null;
        });
        await provider.replaceAllFromJson(
          jsonEncode({
            'mcpServers': {
              'guest': {'command': 'server'},
            },
          }),
        );
        if (!duringInitialization) {
          await _waitFor(() => provider.isConnected('guest'));
          runtime.failProcess(runtime.requests.single.runId);
        }
        await _waitFor(() => provider.statusFor('guest') == McpStatus.error);
        expect(provider.errorFor('guest'), contains('code 1'));
        expect(provider.errorFor('guest'), contains('Package not found'));
      },
    );
  }

  for (final disableBeforeCleanup in [false, true]) {
    test(
      'environment recovery waits for initializing stdio (disabled=$disableBeforeCleanup)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final harness = await BusinessTestHarness.create();
        final environment = EnvironmentProvider(
          preferences: harness.preferences,
        );
        await environment.loaded;
        await environment.setState(
          const EnvironmentState(phase: EnvironmentPhase.ready),
        );
        final runtime = _McpRuntime(holdFirstInitialization: true);
        final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
        await runtimeProvider.refresh();
        final provider = McpProvider(
          preferences: harness.preferences,
          workspaceRuntime: runtimeProvider,
          environment: environment,
        );
        addTearDown(() async {
          if (!runtime.releaseInitialization.isCompleted) {
            runtime.releaseInitialization.complete();
          }
          provider.dispose();
          runtimeProvider.dispose();
          environment.dispose();
          await harness.close();
          debugDefaultTargetPlatformOverride = null;
        });
        await provider.replaceAllFromJson(
          jsonEncode({
            'mcpServers': {
              'guest': {'command': 'server'},
            },
          }),
        );
        await runtime.initializationStarted.future;
        for (var i = 0; i < 2; i++) {
          await environment.setState(
            const EnvironmentState(phase: EnvironmentPhase.patching),
          );
          await environment.setState(
            const EnvironmentState(phase: EnvironmentPhase.ready),
          );
        }
        expect(runtime.requests, hasLength(1));
        if (disableBeforeCleanup) {
          await environment.setState(const EnvironmentState());
        }
        runtime.releaseInitialization.complete();
        if (disableBeforeCleanup) {
          await _waitFor(() => runtime.cancelled);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(runtime.requests, hasLength(1));
          expect(provider.isConnected('guest'), isFalse);
        } else {
          await _waitFor(() => provider.isConnected('guest'));
          expect(runtime.requests, hasLength(2));
          expect(runtime.cancelled, isTrue);
        }
      },
    );
  }

  test(
    'mobile keeps imported stdio config hidden until environment is ready, then disconnects on removal',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final harness = await BusinessTestHarness.create();
      final environment = EnvironmentProvider(preferences: harness.preferences);
      await environment.loaded;
      final runtime = _McpRuntime();
      final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
      await runtimeProvider.refresh();
      final provider = McpProvider(
        preferences: harness.preferences,
        workspaceRuntime: runtimeProvider,
        environment: environment,
      );
      addTearDown(() async {
        provider.dispose();
        runtimeProvider.dispose();
        environment.dispose();
        await harness.close();
        debugDefaultTargetPlatformOverride = null;
      });
      await provider.replaceAllFromJson(
        jsonEncode({
          'mcpServers': {
            'guest': {
              'command': 'npx',
              'args': ['-y', 'server', 'a b'],
              'env': {'TOKEN': 'server-value'},
              'workingDirectory': '/root/project',
            },
          },
        }),
      );
      expect(provider.supportsStdio, isFalse);
      expect(provider.servers.any((s) => s.id == 'guest'), isFalse);
      expect(runtime.requests, isEmpty);
      final exported = jsonDecode(provider.exportServersAsUiJson());
      expect(exported['mcpServers']['guest']['args'], ['-y', 'server', 'a b']);
      await environment.saveVariable(
        const EnvironmentVariable(name: 'GLOBAL', value: 'global-value'),
      );
      await environment.saveVariable(
        const EnvironmentVariable(name: 'TOKEN', value: 'global-token'),
      );
      await environment.setState(
        const EnvironmentState(phase: EnvironmentPhase.ready),
      );
      await _waitFor(() => provider.statusFor('guest') == McpStatus.connected);
      expect(provider.supportsStdio, isTrue);
      expect(provider.servers.any((s) => s.id == 'guest'), isTrue);
      expect(runtime.requests.single.cwd, '/root/project');
      expect(runtime.requests.single.env, {
        'GLOBAL': 'global-value',
        'TOKEN': 'server-value',
      });
      await environment.setState(const EnvironmentState());
      await _waitFor(() => runtime.cancelled);
      expect(provider.supportsStdio, isFalse);
      expect(provider.servers.any((s) => s.id == 'guest'), isFalse);
      expect(provider.isConnected('guest'), isFalse);
      expect(provider.getById('guest')?.command, 'npx');
    },
  );
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var i = 0; i < 200; i++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('MCP state did not settle');
}

class _McpRuntime extends FakeWorkspaceRuntime
    implements WorkspaceStdioRuntime {
  _McpRuntime({
    this.holdFirstInitialization = false,
    this.failInitialization = false,
    this.stallToolCalls = false,
  });
  final bool holdFirstInitialization;
  final bool failInitialization;
  final bool stallToolCalls;
  final initializationStarted = Completer<void>();
  final releaseInitialization = Completer<void>();
  final events = <String, StreamController<CommandEvent>>{};
  bool cancelled = false;
  @override
  Stream<CommandEvent> run(CommandRequest request) {
    if (!request.keepStdinOpen) {
      return Stream.value(
        const CommandExited(
          exitCode: 0,
          timedOut: false,
          cancelled: false,
          interrupted: false,
          duration: Duration.zero,
        ),
      );
    }
    requests.add(request);
    final stream = StreamController<CommandEvent>();
    events[request.runId] = stream;
    stream.add(const CommandStarted());
    return stream.stream;
  }

  @override
  Future<void> writeStdin(String runId, Uint8List data) async {
    final request = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
    if (!request.containsKey('id')) return;
    if (stallToolCalls && request['method'] == 'tools/call') return;
    if (request['method'] == 'initialize' && runId == requests.first.runId) {
      if (failInitialization) {
        failProcess(runId);
        return;
      }
      if (!initializationStarted.isCompleted) initializationStarted.complete();
      if (holdFirstInitialization) await releaseInitialization.future;
    }
    final result = request['method'] == 'initialize'
        ? {
            'protocolVersion': '2025-03-26',
            'capabilities': {'tools': {}},
            'serverInfo': {'name': 'guest', 'version': '1'},
          }
        : {'tools': []};
    events[runId]!.add(
      CommandOutput(
        OutputStreamKind.stdout,
        Uint8List.fromList(
          utf8.encode(
            '${jsonEncode({'jsonrpc': '2.0', 'id': request['id'], 'result': result})}\n',
          ),
        ),
      ),
    );
  }

  void failProcess(String runId) {
    events[runId]!.add(
      CommandOutput(
        OutputStreamKind.stderr,
        Uint8List.fromList(utf8.encode('Package not found\n')),
      ),
    );
    events[runId]!.add(
      const CommandExited(
        exitCode: 1,
        timedOut: false,
        cancelled: false,
        interrupted: false,
        duration: Duration.zero,
      ),
    );
  }

  @override
  Future<void> cancel(String runId) async {
    cancelled = true;
  }
}
