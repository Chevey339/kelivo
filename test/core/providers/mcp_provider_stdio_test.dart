import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/models/environment_variable.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/models/tool_permission_mode.dart';
import 'package:Kelivo/core/services/conversation_tool_permissions.dart';
import 'package:Kelivo/core/services/api/tool_call_cancellation.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/core/services/mcp/mcp_config_import.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../support/business_test_harness.dart';
import '../../support/fake_workspace_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    group('workspace stdio on ${platform.name}', () {
      late BusinessTestHarness harness;
      late EnvironmentProvider environment;
      late WorkspaceProvider workspaces;
      late WorkspaceRuntimeProvider runtimeProvider;
      late _McpRuntime runtime;
      late McpProvider provider;
      late Directory files;
      late PathProviderPlatform previousPaths;

      setUp(() async {
        debugDefaultTargetPlatformOverride = platform;
        files = await Directory.systemTemp.createTemp('mcp-workspace-');
        previousPaths = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _Paths(files.path);
        harness = await BusinessTestHarness.create();
        environment = EnvironmentProvider(preferences: harness.preferences);
        await environment.loaded;
        await environment.setState(
          const EnvironmentState(phase: EnvironmentPhase.ready),
        );
        workspaces = WorkspaceProvider(
          store: ExtensionEntityStore(harness.database),
        );
        await workspaces.loaded;
        runtime = _McpRuntime();
        runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
        await runtimeProvider.refresh();
        provider = McpProvider(
          preferences: harness.preferences,
          workspaceRuntime: runtimeProvider,
          environment: environment,
          workspaces: workspaces,
        );
        await provider.loaded;
      });

      tearDown(() async {
        await provider.disconnect('guest');
        provider.dispose();
        runtimeProvider.dispose();
        workspaces.dispose();
        environment.dispose();
        await harness.close();
        PathProviderPlatform.instance = previousPaths;
        debugDefaultTargetPlatformOverride = null;
        await files.delete(recursive: true);
      });

      Future<void> configure(
        String? workspaceId, {
        String? cwd,
        bool follow = false,
      }) async {
        await provider.replaceAllFromJson(
          jsonEncode({
            'mcpServers': {
              'guest': {
                'command': 'python3',
                'args': ['./mcp_server.py'],
                if (workspaceId != null) 'workspaceId': workspaceId,
                if (follow) 'workspaceBinding': 'followConversation',
                if (cwd != null) 'workingDirectory': cwd,
              },
            },
          }),
        );
      }

      Future<(AssistantProvider, String)> selectServers(
        List<String> ids,
      ) async {
        final assistants = AssistantProvider(preferences: harness.preferences);
        addTearDown(assistants.dispose);
        await assistants.loaded;
        final id = await assistants.addAssistant(name: 'Selected');
        await assistants.updateAssistant(
          assistants.getById(id)!.copyWith(mcpServerIds: ids),
        );
        return (assistants, id);
      }

      test(
        'a background list notification invalidates failed discovery without extending idle lifetime',
        () async {
          await configure(null, follow: true);
          const scope = (serverId: 'guest', workspaceId: null);
          runtime.toolsByRoot[''] = [_tool('old')];
          var idleTimers = 0;
          await runZoned(
            () async {
              expect(
                (await provider.discoverWorkspaceTools(scope)).single.name,
                'old',
              );
              final request = runtime.requests.single;
              final prior = idleTimers;
              runtime.failedLists.add(request.command);
              runtime.notifyListChanged(request.runId);
              await _waitFor(
                () =>
                    provider.statusForScope(scope) == McpStatus.error &&
                    provider.cachedWorkspaceTools(scope).isEmpty,
              );
              expect(idleTimers, prior);
              runtime.failedLists.clear();
              runtime.toolsByRoot[''] = [_tool('new')];
              expect(
                (await provider.discoverWorkspaceTools(scope)).single.name,
                'new',
              );
            },
            zoneSpecification: ZoneSpecification(
              createTimer: (self, parent, zone, duration, callback) {
                if (duration == provider.workspaceIdleTimeout) idleTimers++;
                return parent.createTimer(zone, duration, callback);
              },
            ),
          );
        },
      );

      test(
        'a changed server cannot adopt a discovered catalog while another server is still starting',
        () async {
          await provider.replaceAllFromJson(
            jsonEncode({
              'mcpServers': {
                for (final name in ['first', 'delayed'])
                  name: {
                    'command': name,
                    'workspaceBinding': 'followConversation',
                  },
              },
            }),
          );
          final (assistants, id) = await selectServers(['first', 'delayed']);
          final service = McpToolService();
          addTearDown(service.dispose);
          final chat = Conversation(title: 'Chat', assistantId: id);
          runtime.toolsByCommand["exec 'first'"] = [_tool('from_first')];
          runtime.toolsByCommand["exec 'delayed'"] = [_tool('from_delayed')];
          final gate = Completer<void>();
          runtime.listGates["exec 'delayed'"] = gate;
          final pending = service.prepareRoutesForAssistant(
            provider,
            assistants,
            assistantId: id,
            conversation: chat,
          );
          await _waitFor(
            () =>
                provider.getById('first')!.tools.isNotEmpty &&
                runtime.listCount.containsKey("exec 'delayed'"),
          );
          await provider.updateServerMetadata(
            provider.getById('first')!.copyWith(command: 'replacement'),
          );
          gate.complete();
          final routes = await pending;
          expect(routes.containsExposedName('from_delayed'), isTrue);
          expect(routes.containsExposedName('from_first'), isFalse);
        },
      );

      for (final cancel in [true, false]) {
        test(
          'pending dispatch rechecks generation cancellation and full access (cancel=$cancel)',
          () async {
            await configure(null, follow: true);
            final (assistants, id) = await selectServers(['guest']);
            final service = McpToolService();
            addTearDown(service.dispose);
            final chat = Conversation(title: 'Target', assistantId: id);
            runtime.toolsByRoot[''] = [_tool('echo')];
            final routes = await service.prepareRoutesForAssistant(
              provider,
              assistants,
              assistantId: id,
              conversation: chat,
            );
            await provider.setToolNeedsApproval('guest', 'echo', true);
            final gate = Completer<void>();
            final launch = runtime.requests.single;
            runtime.listGates[launch.command] = gate;
            runtime.notifyListChanged(launch.runId);
            await _waitFor(() => runtime.listCount[launch.command] == 2);
            var mode = ToolPermissionMode.fullAccess;
            final permission = ToolCallPermission(
              toolName: 'echo',
              toolCallId: 'id',
              readState: () => ToolPermissionState(mode: mode),
            );
            await permission.authorize(needed: true, arguments: {});
            final entered = Completer<void>();
            final cancelled = Completer<void>();
            final token = ToolCallCancellation(
              isCancelled: () => cancelled.isCompleted,
              cancelled: cancelled.future,
            );
            final call = token.run(
              () => service.callToolForAssistant(
                provider,
                assistants,
                conversation: chat,
                assistantId: id,
                toolName: 'echo',
                routeSnapshot: routes,
                checkPermission: () {
                  permission.checkAuthorized();
                  if (!entered.isCompleted) entered.complete();
                },
              ),
            );
            await entered.future.timeout(const Duration(seconds: 2));
            if (cancel) {
              cancelled.complete();
            } else {
              mode = ToolPermissionMode.requestApproval;
            }
            gate.complete();
            if (cancel) {
              expect((await call).markdown, contains('tool_call_cancelled'));
            } else {
              await expectLater(call, throwsA(isA<ToolPermissionException>()));
            }
            expect(runtime.argumentsByRun, isEmpty);
          },
        );
      }

      test(
        'switching to fixed waits for its own catalog and keeps tool preferences',
        () async {
          final a = await workspaces.create(name: 'A');
          final b = await workspaces.create(name: 'B');
          runtime.toolsByRoot[await workspaces.hostRootFor(a)] = [
            _tool('alpha'),
          ];
          runtime.toolsByRoot[await workspaces.hostRootFor(b)] = [
            _tool('beta'),
          ];
          await configure(null, follow: true);
          for (final workspace in [a, b]) {
            await provider.discoverWorkspaceTools((
              serverId: 'guest',
              workspaceId: workspace.id,
            ));
          }
          await provider.setToolNeedsApproval('guest', 'alpha', true);
          final gate = Completer<void>();
          runtime.listGates[runtime.requests.first.command] = gate;
          await provider.updateServerMetadata(
            provider
                .getById('guest')!
                .copyWith(
                  followConversationWorkspace: false,
                  workspaceId: a.id,
                ),
          );
          await _waitFor(() => runtime.requests.length == 3);
          expect(provider.getEnabledToolsForServers({'guest'}), isEmpty);
          expect(
            McpServerConfig.fromJson(
              provider.getById('guest')!.toJson(),
            ).declaredTools,
            isEmpty,
          );
          gate.complete();
          await _waitFor(
            () => provider.getEnabledToolsForServers({'guest'}).isNotEmpty,
          );
          final only = provider.getEnabledToolsForServers({'guest'}).single;
          expect(only.name, 'alpha');
          expect(only.needsApproval, isTrue);
        },
      );

      test(
        'following routes use the selected chat for discovery, approval and dispatch',
        () async {
          final a = await workspaces.create(name: 'A');
          final b = await workspaces.create(name: 'B');
          final rootA = await workspaces.hostRootFor(a);
          final rootB = await workspaces.hostRootFor(b);
          runtime.toolsByRoot[rootA] = [
            _tool('echo', 'integer'),
            _tool('only_a'),
          ];
          runtime.toolsByRoot[rootB] = [
            _tool('echo', 'string'),
            _tool('only_b'),
          ];
          runtime.toolsByRoot[''] = [_tool('unbound')];
          await configure(a.id, follow: true);
          final server = provider.getById('guest')!;
          expect(server.workspaceId, isNull);
          expect(server.followConversationWorkspace, isTrue);
          expect(provider.canSelectServer(server), isTrue);
          expect(provider.statusFor('guest'), McpStatus.onDemand);
          expect(
            McpServerConfig.fromJson(
              server.toJson(),
            ).followConversationWorkspace,
            isTrue,
          );
          final exported = provider.exportServersAsUiJson();
          expect(
            parseMcpConfigImport(exported).single.followConversationWorkspace,
            isTrue,
          );
          final assistants = AssistantProvider(
            preferences: harness.preferences,
          );
          final service = McpToolService();
          addTearDown(assistants.dispose);
          addTearDown(service.dispose);
          await assistants.loaded;
          final id = await assistants.addAssistant(name: 'Shared server');
          await assistants.updateAssistant(
            assistants
                .getById(id)!
                .copyWith(defaultWorkspaceId: a.id, mcpServerIds: ['guest']),
          );
          Conversation chat(Workspace? ws) => Conversation(
            title: 'Chat',
            assistantId: id,
            extras: WorkspaceBinding(workspaceId: ws?.id).applyTo({}),
          );
          final chatA = chat(a);
          final chatB = chat(b);
          Future<McpToolRouteSnapshot> prepare(Conversation? target) =>
              service.prepareRoutesForAssistant(
                provider,
                assistants,
                assistantId: id,
                conversation: target,
              );
          expect((await prepare(null)).containsExposedName('echo'), isFalse);
          expect(runtime.requests, isEmpty);
          final routes = await Future.wait([
            prepare(chatA),
            prepare(chatB),
            prepare(chatA),
          ]);
          expect(runtime.requests, hasLength(2));
          expect(routes[0].containsExposedName('only_b'), isFalse);
          expect(routes[1].containsExposedName('only_a'), isFalse);
          expect(routes[2].containsExposedName('only_a'), isTrue);
          Future<String> invoke(
            Conversation target,
            McpToolRouteSnapshot snapshot,
          ) => service.callToolTextForAssistant(
            provider,
            assistants,
            assistantId: id,
            conversation: target,
            routeSnapshot: snapshot,
            toolName: 'echo',
            arguments: {'value': '17'},
          );
          final called = await Future.wait([
            invoke(chatA, routes[0]),
            invoke(chatB, routes[1]),
          ]);
          final first = runtime.requests.singleWhere(
            (r) => r.mounts.single.host == rootA,
          );
          final second = runtime.requests.singleWhere(
            (r) => r.mounts.single.host == rootB,
          );
          expect(called, [first.runId, second.runId]);
          expect(runtime.argumentsByRun[first.runId]!.single['value'], 17);
          expect(runtime.argumentsByRun[second.runId]!.single['value'], '17');
          expect(await invoke(chatB, routes[0]), isEmpty);
          expect(runtime.argumentsByRun[second.runId], hasLength(1));
          await provider.setToolNeedsApproval('guest', 'echo', true);
          for (final (target, snapshot) in [
            (chatA, routes[0]),
            (chatB, routes[1]),
          ]) {
            expect(
              service.toolNeedsApprovalForAssistant(
                provider,
                assistants,
                assistantId: id,
                conversation: target,
                routeSnapshot: snapshot,
                toolName: 'echo',
              ),
              isTrue,
            );
          }
          await provider.setToolEnabled('guest', 'echo', false);
          expect(await invoke(chatA, routes[0]), isEmpty);
          expect(runtime.argumentsByRun[first.runId], hasLength(1));
          expect(
            (await prepare(chat(null))).containsExposedName('unbound'),
            isTrue,
          );
          expect(runtime.requests.last.mounts, isEmpty);
          expect(runtime.requests.last.cwd, '/root');
          await workspaces.delete(a.id);
          await _waitFor(() => runtime.cancelledRuns.contains(first.runId));
          expect(runtime.cancelledRuns, isNot(contains(second.runId)));
          expect((await prepare(chatA)).containsExposedName('only_a'), isFalse);
          await expectLater(
            provider.discoverWorkspaceTools((
              serverId: 'guest',
              workspaceId: a.id,
            )),
            throwsStateError,
          );
          final scopeA = (serverId: 'guest', workspaceId: a.id);
          final scopeB = (serverId: 'guest', workspaceId: b.id);
          expect(provider.statusForScope(scopeA), McpStatus.error);
          expect(provider.statusForScope(scopeB), McpStatus.connected);
          expect(provider.statusFor('guest'), McpStatus.error);
          expect(provider.errorForScope(scopeA), contains('not found'));
          expect(provider.errorForScope(scopeB), isNull);
          expect(await provider.retryScope(scopeA), isFalse);
          expect(runtime.cancelledRuns, isNot(contains(second.runId)));
          expect(runtime.requests, hasLength(3));
        },
      );

      test(
        'process cap waits for in-flight calls and only evicts idle instances',
        () async {
          final scopes = <McpWorkspaceScope>[];
          for (var i = 0; i <= McpProvider.workspaceProcessLimit; i++) {
            final ws = await workspaces.create(name: 'Project $i');
            scopes.add((serverId: 'guest', workspaceId: ws.id));
            runtime.toolsByRoot[await workspaces.hostRootFor(ws)] = [
              _tool('echo'),
            ];
          }
          await configure(null, follow: true);
          final active = scopes
              .take(McpProvider.workspaceProcessLimit)
              .toList();
          final catalogs = await Future.wait(
            active.map(provider.discoverWorkspaceTools),
          );
          final gates = <String, Completer<void>>{};
          for (final launch in runtime.requests) {
            runtime.callGates[launch.runId] = gates[launch.runId] =
                Completer<void>();
          }
          final calls = [
            for (var i = 0; i < active.length; i++)
              provider.callWorkspaceTool(
                active[i],
                catalogs[i].single,
                {},
                isAllowed: () => true,
              ),
          ];
          await _waitFor(() => runtime.argumentsByRun.length == active.length);
          final waiting = provider.discoverWorkspaceTools(scopes.last);
          await Future<void>.delayed(Duration.zero);
          expect(runtime.requests, hasLength(active.length));
          expect(runtime.cancelledRuns, isEmpty);
          final released = gates.keys.first;
          gates[released]!.complete();
          expect((await waiting).single.name, 'echo');
          expect(runtime.cancelledRuns, [released]);
          for (final gate in gates.values.where((g) => !g.isCompleted)) {
            gate.complete();
          }
          await Future.wait(calls);
          expect(runtime.requests, hasLength(scopes.length));
          await provider.disconnect('guest');
          expect(runtime.cancelledRuns, hasLength(scopes.length));
          await expectLater(
            provider.discoverWorkspaceTools(scopes.last),
            throwsStateError,
          );
          await provider.reconnect('guest');
          expect(provider.statusFor('guest'), McpStatus.onDemand);
        },
      );

      test(
        'an idle process closes and is rediscovered before a captured call',
        () async {
          provider.dispose();
          provider = McpProvider(
            preferences: harness.preferences,
            workspaces: workspaces,
            workspaceRuntime: runtimeProvider,
            environment: environment,
            workspaceIdleTimeout: const Duration(milliseconds: 40),
          );
          await provider.loaded;
          await configure(null, follow: true);
          const scope = (serverId: 'guest', workspaceId: null);
          runtime.toolsByRoot[''] = [_tool('echo', 'integer')];
          final tool = (await provider.discoverWorkspaceTools(scope)).single;
          final original = runtime.requests.single.runId;
          await _waitFor(() => runtime.cancelledRuns.contains(original));
          runtime.toolsByRoot[''] = [_tool('echo', 'string')];
          final result = await provider.callWorkspaceTool(scope, tool, {
            'value': '17',
          }, isAllowed: () => true);
          expect(result?.isError, isTrue);
          expect(runtime.requests, hasLength(2));
          expect(runtime.argumentsByRun, isEmpty);
        },
      );

      test(
        'probe and server share only the selected workspace mount',
        () async {
          final workspace = await workspaces.create(name: 'MCP scripts');
          final root = await workspaces.hostRootFor(workspace);
          await configure(workspace.id);
          await _waitFor(() => provider.isConnected('guest'));
          final request = runtime.requests.single;
          expect(request.cwd, '/workspace');
          expect(request.command, "exec 'python3' './mcp_server.py'");
          expect(request.mounts, [Mount(host: root, guest: '/workspace')]);
          expect(runtime.probes.single.mounts, request.mounts);
          expect(runtime.probes.single.cwd, request.cwd);
          expect(provider.getById('guest')!.workspaceId, workspace.id);
          final exported = jsonDecode(provider.exportServersAsUiJson());
          expect(exported['mcpServers']['guest']['workspaceId'], workspace.id);
          final persisted =
              jsonDecode(harness.preferences.getString('mcp_servers_v1')!)
                  as List;
          final saved = McpServerConfig.fromJson(
            Map<String, dynamic>.from(
              persisted.firstWhere((s) => s['id'] == 'guest'),
            ),
          );
          expect(saved.workspaceId, workspace.id);
          expect(saved.copyWith(name: 'Renamed').workspaceId, workspace.id);
          expect(saved.copyWith(clearWorkspace: true).workspaceId, isNull);
        },
      );

      test(
        'explicit cwd is preserved while the workspace remains mounted',
        () async {
          final workspace = await workspaces.create(name: 'Scripts');
          await configure(workspace.id, cwd: '/root');
          await _waitFor(() => provider.isConnected('guest'));
          expect(runtime.requests.single.cwd, '/root');
          expect(runtime.requests.single.mounts.single.guest, '/workspace');
          expect(runtime.probes.single.cwd, '/root');
        },
      );

      test('changing and clearing a binding replaces the process', () async {
        final first = await workspaces.create(name: 'First');
        final second = await workspaces.create(name: 'Second');
        await configure(first.id);
        await _waitFor(() => provider.isConnected('guest'));
        final firstRun = runtime.requests.single.runId;
        await provider.updateServerMetadata(
          provider.getById('guest')!.copyWith(workspaceId: second.id),
        );
        await _waitFor(() => provider.isConnected('guest'));
        expect(runtime.cancelledRuns, contains(firstRun));
        expect(runtime.requests, hasLength(2));
        expect(
          runtime.requests.last.mounts.single.host,
          await workspaces.hostRootFor(second),
        );
        await provider.updateServerMetadata(
          provider.getById('guest')!.copyWith(clearWorkspace: true),
        );
        await _waitFor(() => provider.isConnected('guest'));
        expect(runtime.requests, hasLength(3));
        expect(runtime.requests.last.mounts, isEmpty);
        expect(runtime.requests.last.cwd, '/root');
        expect(runtime.probes.last.mounts, isEmpty);
      });

      test(
        'renaming or using a workspace does not restart the server',
        () async {
          final workspace = await workspaces.create(name: 'Scripts');
          await configure(workspace.id);
          await _waitFor(() => provider.isConnected('guest'));
          await workspaces.update(workspace.copyWith(name: 'Renamed'));
          await workspaces.touchLastUsed(workspace.id);
          await workspaces.create(name: 'Unrelated');
          await Future<void>.delayed(Duration.zero);
          expect(runtime.requests, hasLength(1));
          expect(runtime.cancelledRuns, isEmpty);
        },
      );

      test(
        'deleted workspace stops the server and prevents unbound startup',
        () async {
          final workspace = await workspaces.create(name: 'Scripts');
          await configure(workspace.id);
          await _waitFor(() => provider.isConnected('guest'));
          final run = runtime.requests.single.runId;
          await workspaces.delete(workspace.id);
          await _waitFor(() => provider.statusFor('guest') == McpStatus.error);
          expect(runtime.cancelledRuns, contains(run));
          expect(
            provider.errorFor('guest'),
            contains('Bound workspace not found'),
          );
          expect(provider.getById('guest')!.workspaceId, workspace.id);
          await provider.connect('guest');
          expect(runtime.requests, hasLength(1));
          expect(runtime.probes, hasLength(1));
        },
      );

      test(
        'missing imported workspace reports an error before probing',
        () async {
          await configure('missing-workspace');
          await _waitFor(() => provider.statusFor('guest') == McpStatus.error);
          expect(
            provider.errorFor('guest'),
            contains('Bound workspace not found'),
          );
          expect(runtime.requests, isEmpty);
          expect(runtime.probes, isEmpty);
        },
      );

      test('addServer persists and mounts its optional workspace', () async {
        final workspace = await workspaces.create(name: 'Scripts');
        final id = await provider.addServer(
          enabled: true,
          name: 'Workspace server',
          transport: McpTransportType.stdio,
          command: 'python3',
          workspaceId: workspace.id,
        );
        await _waitFor(() => provider.isConnected(id));
        expect(provider.getById(id)!.workspaceId, workspace.id);
        expect(
          runtime.requests.single.mounts.single.host,
          await workspaces.hostRootFor(workspace),
        );
        await provider.disconnect(id);
      });

      test(
        'deleting a workspace cancels blocked initialization immediately',
        () async {
          runtime = _McpRuntime(holdFirstInitialization: true);
          runtimeProvider.register(runtime);
          await runtimeProvider.refresh();
          final workspace = await workspaces.create(name: 'Scripts');
          await configure(workspace.id);
          await runtime.initializationStarted.future;
          final runId = runtime.requests.single.runId;
          try {
            await workspaces.delete(workspace.id);
            await _waitFor(() => runtime.cancelledRuns.contains(runId));
            await _waitFor(
              () => provider.statusFor('guest') == McpStatus.error,
            );
            expect(runtime.releaseInitialization.isCompleted, isFalse);
            expect(
              provider.errorFor('guest'),
              contains('Bound workspace not found'),
            );
            expect(runtime.requests, hasLength(1));
          } finally {
            runtime.releaseInitialization.complete();
          }
        },
      );

      test(
        'changing a binding during initialization discards the old connection',
        () async {
          runtime = _McpRuntime(holdFirstInitialization: true);
          runtimeProvider.register(runtime);
          await runtimeProvider.refresh();
          addTearDown(() {
            if (!runtime.releaseInitialization.isCompleted) {
              runtime.releaseInitialization.complete();
            }
          });
          final first = await workspaces.create(name: 'First');
          final second = await workspaces.create(name: 'Second');
          await configure(first.id);
          await runtime.initializationStarted.future;
          final update = provider.updateServerMetadata(
            provider.getById('guest')!.copyWith(workspaceId: second.id),
          );
          await update.timeout(const Duration(seconds: 2));
          await _waitFor(() => provider.isConnected('guest'));
          expect(runtime.releaseInitialization.isCompleted, isFalse);
          expect(runtime.requests, hasLength(2));
          expect(runtime.cancelledRuns, contains(runtime.requests.first.runId));
          expect(
            runtime.requests.last.mounts.single.host,
            await workspaces.hostRootFor(second),
          );
        },
      );

      test(
        'moving a linked workspace reconnects and missing folders fail',
        () async {
          final first = await Directory('${files.path}/first folder').create();
          final second = await Directory(
            '${files.path}/second folder',
          ).create();
          final workspace = await workspaces.create(
            name: 'Linked scripts',
            kind: WorkspaceKind.linked,
            hostPath: first.path,
          );
          await configure(workspace.id);
          await _waitFor(() => provider.isConnected('guest'));
          await workspaces.update(workspace.copyWith(hostPath: second.path));
          await _waitFor(
            () => provider.isConnected('guest') && runtime.requests.length == 2,
          );
          expect(runtime.requests.last.mounts.single.host, second.path);
          await workspaces.update(
            workspace.copyWith(hostPath: '${files.path}/missing'),
          );
          await _waitFor(() => provider.statusFor('guest') == McpStatus.error);
          expect(
            provider.errorFor('guest'),
            contains('workspace folder is unavailable'),
          );
          expect(runtime.requests, hasLength(2));
          expect(await Directory('${files.path}/missing').exists(), isFalse);
        },
      );

      test(
        'reloading config and workspaces restores the binding before startup',
        () async {
          final workspace = await workspaces.create(name: 'Scripts');
          await configure(workspace.id);
          await _waitFor(() => provider.isConnected('guest'));
          await provider.disconnect('guest');
          provider.dispose();
          workspaces.dispose();
          workspaces = WorkspaceProvider(
            store: ExtensionEntityStore(harness.database),
          );
          provider = McpProvider(
            preferences: harness.preferences,
            workspaceRuntime: runtimeProvider,
            environment: environment,
            workspaces: workspaces,
          );
          await provider.loaded;
          await _waitFor(() => provider.isConnected('guest'));
          expect(runtime.requests, hasLength(2));
          expect(runtime.requests.last.mounts, runtime.requests.first.mounts);
        },
      );
    });
  }

  test(
    'desktop rejects a mobile binding before launching a host process',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final harness = await createBusinessTestHarness();
      final provider = McpProvider(preferences: harness.preferences);
      addTearDown(() {
        provider.dispose();
        debugDefaultTargetPlatformOverride = null;
      });
      await provider.replaceAllFromJson(
        jsonEncode({
          'mcpServers': {
            'guest': {'command': 'python3', 'workspaceId': 'mobile-workspace'},
          },
        }),
      );
      await _waitFor(() => provider.statusFor('guest') == McpStatus.error);
      expect(
        provider.errorFor('guest'),
        contains('requires the mobile Linux environment'),
      );
    },
  );

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

  test(
    'an exited stdio process is recreated on next use, not while idle',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final harness = await BusinessTestHarness.create();
      final environment = EnvironmentProvider(preferences: harness.preferences);
      await environment.loaded;
      await environment.setState(
        const EnvironmentState(phase: EnvironmentPhase.ready),
      );
      final runtime = _McpRuntime(stallToolsList: true);
      final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
      await runtimeProvider.refresh();
      final provider = McpProvider(
        preferences: harness.preferences,
        workspaceRuntime: runtimeProvider,
        environment: environment,
      );
      try {
        await provider.replaceAllFromJson(
          jsonEncode({
            'mcpServers': {
              'guest': {'command': 'server'},
            },
          }),
        );
        await _waitFor(() => provider.isConnected('guest'));
        await runtime.toolsListStarted.future;
        runtime.events[runtime.requests.single.runId]!.add(
          CommandOutput(
            OutputStreamKind.stdout,
            Uint8List.fromList(
              utf8.encode(
                '${jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/tools/list_changed'})}\n',
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        runtime.failProcess(runtime.requests.single.runId);
        await _waitFor(() => provider.statusFor('guest') == McpStatus.error);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(runtime.requests, hasLength(1));
        runtime.stallToolsList = false;
        await Future.wait([
          provider.ensureConnected('guest'),
          provider.ensureConnected('guest'),
        ]);
        expect(provider.isConnected('guest'), isTrue);
        expect(runtime.requests, hasLength(2));
        await provider.disconnect('guest');
        await environment.setState(
          const EnvironmentState(phase: EnvironmentPhase.patching),
        );
        await environment.setState(
          const EnvironmentState(phase: EnvironmentPhase.ready),
        );
        await provider.ensureConnected('guest');
        expect(runtime.requests, hasLength(2));
      } finally {
        provider.dispose();
        runtimeProvider.dispose();
        environment.dispose();
        await harness.close();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  for (final disableBeforeCleanup in [false, true]) {
    test(
      'environment recovery cancels initialization and waits for process cleanup (disabled=$disableBeforeCleanup)',
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
        final cancellationGate = Completer<void>();
        final runtime = _McpRuntime(
          holdFirstInitialization: true,
          cancellationGate: cancellationGate,
        );
        final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
        await runtimeProvider.refresh();
        final provider = McpProvider(
          preferences: harness.preferences,
          workspaceRuntime: runtimeProvider,
          environment: environment,
        );
        addTearDown(() async {
          if (!cancellationGate.isCompleted) cancellationGate.complete();
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
        expect(runtime.cancelledRuns, contains(runtime.requests.first.runId));
        cancellationGate.complete();
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
        expect(runtime.releaseInitialization.isCompleted, isFalse);
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

Map<String, dynamic> _tool(String name, [String type = 'string']) => {
  'name': name,
  'inputSchema': {
    'type': 'object',
    'properties': {
      'value': {'type': type},
    },
  },
};

class _McpRuntime extends FakeWorkspaceRuntime
    implements WorkspaceStdioRuntime {
  _McpRuntime({
    this.holdFirstInitialization = false,
    this.failInitialization = false,
    this.stallToolCalls = false,
    this.stallToolsList = false,
    this.cancellationGate,
  });
  final bool holdFirstInitialization;
  final bool failInitialization;
  final bool stallToolCalls;
  bool stallToolsList;
  final toolsListStarted = Completer<void>();
  final Completer<void>? cancellationGate;
  final initializationStarted = Completer<void>();
  final releaseInitialization = Completer<void>();
  final events = <String, StreamController<CommandEvent>>{};
  final probes = <CommandRequest>[];
  final toolsByRoot = <String, List<Map<String, dynamic>>>{};
  final argumentsByRun = <String, List<Map<String, dynamic>>>{};
  final callGates = <String, Completer<void>>{};
  final listGates = <String, Completer<void>>{};
  final failedLists = <String>{};
  final listCount = <String, int>{};
  final toolsByCommand = <String, List<Map<String, dynamic>>>{};

  void emit(String runId, Map<String, dynamic> message) {
    final line = jsonEncode(message);
    events[runId]!.add(
      CommandOutput(
        OutputStreamKind.stdout,
        Uint8List.fromList(utf8.encode('$line\n')),
      ),
    );
  }

  void notifyListChanged(String runId) => emit(runId, {
    'jsonrpc': '2.0',
    'method': 'notifications/tools/list_changed',
    'params': {},
  });

  final cancelledRuns = <String>[];
  bool cancelled = false;
  @override
  Stream<CommandEvent> run(CommandRequest request) {
    if (!request.keepStdinOpen) {
      probes.add(request);
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
    if (stallToolsList && request['method'] == 'tools/list') {
      if (!toolsListStarted.isCompleted) toolsListStarted.complete();
      return;
    }
    if (stallToolCalls && request['method'] == 'tools/call') return;
    if (request['method'] == 'initialize' && runId == requests.first.runId) {
      if (failInitialization) {
        failProcess(runId);
        return;
      }
      if (!initializationStarted.isCompleted) initializationStarted.complete();
      if (holdFirstInitialization) await releaseInitialization.future;
    }
    final launch = requests.firstWhere((r) => r.runId == runId);
    if (request['method'] == 'tools/list') {
      listCount.update(launch.command, (count) => count + 1, ifAbsent: () => 1);
      await listGates[launch.command]?.future;
      if (failedLists.contains(launch.command)) {
        emit(runId, {
          'jsonrpc': '2.0',
          'id': request['id'],
          'error': {'code': -32603, 'message': 'Discovery failed'},
        });
        return;
      }
    }
    if (request['method'] == 'tools/call') {
      (argumentsByRun[runId] ??= []).add(
        Map.from(request['params']['arguments'] as Map),
      );
      await callGates[runId]?.future;
    }
    final result = request['method'] == 'initialize'
        ? {
            'protocolVersion': '2025-03-26',
            'capabilities': {'tools': {}},
            'serverInfo': {'name': 'guest', 'version': '1'},
          }
        : request['method'] == 'tools/call'
        ? {
            'content': [
              {'type': 'text', 'text': runId},
            ],
          }
        : {
            'tools':
                toolsByCommand[launch.command] ??
                toolsByRoot[launch.mounts.firstOrNull?.host ?? ''] ??
                [],
          };
    emit(runId, {'jsonrpc': '2.0', 'id': request['id'], 'result': result});
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
    cancelledRuns.add(runId);
    await cancellationGate?.future;
  }
}

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => '$root/support';
}
