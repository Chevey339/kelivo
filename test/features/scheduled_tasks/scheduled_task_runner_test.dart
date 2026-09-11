import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/core/services/scheduled_tasks_service.dart';
import 'package:Kelivo/features/home/controllers/chat_actions.dart';
import 'package:Kelivo/features/home/controllers/home_view_model.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/scheduled_tasks/scheduled_task_runner.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_client/mcp_client.dart' as mcp;
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  Future<_RunnerHarness> mount(
    WidgetTester tester, {
    _ToolsReply reply = _ToolsReply.tools,
    bool cachedTools = false,
  }) async {
    final harness = (await tester.runAsync(
      () => _RunnerHarness.create(reply, cachedTools: cachedTools),
    ))!;
    addTearDown(() => tester.runAsync(harness.close));
    await tester.pumpWidget(harness.widget);
    return harness;
  }

  for (final reply in [_ToolsReply.tools, _ToolsReply.empty]) {
    testWidgets('waits for delayed tools/list with ${reply.name} result', (
      tester,
    ) async {
      final harness = await mount(tester, reply: reply);
      await tester.runAsync(() async {
        expect(harness.mcpProvider.isConnected('remote'), isTrue);
        expect(harness.mcpProvider.getById('remote')!.tools, isEmpty);
        final outcome = harness.run();
        await pumpEventQueue();

        // The connection is ready, but discovery has not supplied a snapshot.
        expect(harness.chat.created, isEmpty);
        expect(harness.viewModel.toolSnapshots, isEmpty);
        harness.server.releaseTools.complete();

        expect(await outcome, isA<_RequestCaptured>());
        expect(harness.chat.created, hasLength(1));
        expect(harness.viewModel.toolSnapshots, [
          reply == _ToolsReply.tools ? ['echo'] : <String>[],
        ]);
      });
    });
  }

  for (final reply in [_ToolsReply.error, _ToolsReply.expired]) {
    testWidgets('does not send stale cached tools after ${reply.name}', (
      tester,
    ) async {
      final harness = await mount(tester, reply: reply, cachedTools: true);
      await tester.runAsync(() async {
        final outcome = harness.run();
        await pumpEventQueue();
        harness.server.releaseTools.complete();

        expect(
          await outcome,
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('mcp_unavailable: Remote'),
          ),
        );
        expect(harness.chat.created, isEmpty);
        expect(harness.viewModel.toolSnapshots, isEmpty);
        expect(
          harness.mcpProvider.getById('remote')!.tools.map((tool) => tool.name),
          ['cached'],
        );
      });
    });
  }

  testWidgets('cancelling during discovery never starts a conversation', (
    tester,
  ) async {
    final harness = await mount(tester);
    await tester.runAsync(() async {
      final cancellation = ScheduledRunCancellation();
      final outcome = harness.run(cancellation);
      await pumpEventQueue();
      await cancellation.cancel();
      harness.server.releaseTools.complete();

      expect(
        await outcome,
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'cancelled',
        ),
      );
      expect(harness.chat.created, isEmpty);
      expect(harness.viewModel.toolSnapshots, isEmpty);
    });
  });
}

class _RunnerHarness {
  _RunnerHarness(this.storage, this.server) {
    assistants = AssistantProvider(preferences: storage.preferences);
    settings = SettingsProvider(storage.preferences);
    mcpProvider = McpProvider(preferences: storage.preferences);
    workspaces = WorkspaceProvider(
      store: ExtensionEntityStore(storage.database),
    );
    books = WorldBookProvider(preferences: storage.preferences);
    viewModel = _RecordingViewModel(mcpProvider, assistants);
  }

  final BusinessTestHarness storage;
  final _DelayedMcpServer server;
  late final AssistantProvider assistants;
  late final SettingsProvider settings;
  late final McpProvider mcpProvider;
  late final WorkspaceProvider workspaces;
  late final WorldBookProvider books;
  late final _RecordingViewModel viewModel;
  final chat = _RecordingChatService();
  final approvals = ToolApprovalService();
  final questions = AskUserInteractionService();
  late BuildContext context;

  static Future<_RunnerHarness> create(
    _ToolsReply reply, {
    required bool cachedTools,
  }) async {
    final server = await _DelayedMcpServer.start(reply);
    final storage = await BusinessTestHarness.create(
      initial: {
        'assistants_v1': jsonEncode([
          const Assistant(
            id: 'assistant',
            name: 'Scheduled assistant',
            mcpServerIds: ['remote'],
          ).toJson(),
        ]),
        'mcp_servers_v1': jsonEncode([
          McpServerConfig(
            id: 'remote',
            name: 'Remote',
            enabled: true,
            transport: McpTransportType.http,
            url: server.url,
            tools: cachedTools
                ? [
                    McpToolConfig(
                      name: 'cached',
                      description: 'Stale tool',
                      enabled: true,
                    ),
                  ]
                : [],
          ).toJson(),
          McpServerConfig(
            id: 'kelivo_fetch',
            name: '@kelivo/fetch',
            enabled: false,
            transport: McpTransportType.inmemory,
          ).toJson(),
        ]),
      },
    );
    final harness = _RunnerHarness(storage, server);
    await Future.wait([
      harness.assistants.loaded,
      harness.settings.loaded,
      harness.mcpProvider.loaded,
      harness.workspaces.loaded,
      harness.books.initialize(),
    ]);
    await harness.mcpProvider.connect('remote');
    await server.toolsRequested.future.timeout(const Duration(seconds: 5));
    return harness;
  }

  Widget get widget => MultiProvider(
    providers: [
      ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<McpProvider>.value(value: mcpProvider),
      ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
      ChangeNotifierProvider<WorldBookProvider>.value(value: books),
      ChangeNotifierProvider<ChatService>.value(value: chat),
      ChangeNotifierProvider<ToolApprovalService>.value(value: approvals),
      ChangeNotifierProvider<AskUserInteractionService>.value(value: questions),
    ],
    child: Builder(
      builder: (value) {
        context = value;
        return const SizedBox.shrink();
      },
    ),
  );

  Future<Object> run([ScheduledRunCancellation? cancellation]) async {
    try {
      return await runScheduledTask(
        context,
        viewModel,
        const ScheduledTask(
          id: 'task',
          name: 'Daily task',
          prompt: 'Use my tools',
          assistantId: 'assistant',
          hour: 8,
          minute: 0,
        ),
        cancellation ?? ScheduledRunCancellation(),
        (_) async {},
      );
    } catch (error) {
      return error;
    }
  }

  Future<void> close() async {
    if (!server.releaseTools.isCompleted) server.releaseTools.complete();
    await mcpProvider.refreshTools('remote');
    await mcpProvider.disconnect('remote');
    mcpProvider.dispose();
    assistants.dispose();
    settings.dispose();
    workspaces.dispose();
    books.dispose();
    chat.dispose();
    approvals.dispose();
    questions.dispose();
    await storage.close();
    await server.close();
  }
}

class _RecordingChatService extends ChatService {
  final created = <Conversation>[];

  @override
  Future<void> init() async {}

  @override
  Future<Conversation> createConversation({
    String? title,
    String? assistantId,
    bool activate = true,
  }) async {
    final conversation = Conversation(title: title!, assistantId: assistantId);
    created.add(conversation);
    return conversation;
  }
}

class _RequestCaptured implements Exception {}

class _RecordingViewModel extends Fake implements HomeViewModel {
  _RecordingViewModel(this.mcpProvider, this.assistants);

  final McpProvider mcpProvider;
  final AssistantProvider assistants;
  final toolSnapshots = <List<String>>[];

  @override
  Future<ChatActionResult> sendScheduledMessage({
    required ChatInputData input,
    required Conversation conversation,
    required Assistant assistant,
  }) async {
    final tools = McpToolService();
    toolSnapshots.add(
      tools
          .listAvailableToolsForAssistant(mcpProvider, assistants, assistant.id)
          .map((tool) => tool.name)
          .toList(),
    );
    tools.dispose();
    // Stop at the model boundary after capturing the real MCP tool snapshot.
    throw _RequestCaptured();
  }
}

enum _ToolsReply { tools, empty, error, expired }

class _DelayedMcpServer {
  _DelayedMcpServer(this.server, this.reply) {
    subscription = server.listen((request) async {
      if (request.method != 'POST') {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        await request.response.close();
        return;
      }
      final message =
          jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      Object? result;
      switch (message['method']) {
        case 'initialize':
          request.response.headers.set('MCP-Session-Id', 'test-session');
          result = {
            'protocolVersion': mcp.McpProtocol.defaultVersion,
            'serverInfo': {'name': 'Delayed tools', 'version': '1.0.0'},
            'capabilities': {'tools': <String, dynamic>{}},
          };
        case 'tools/list':
          if (!toolsRequested.isCompleted) toolsRequested.complete();
          await releaseTools.future;
          if (reply == _ToolsReply.expired) {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            return;
          }
          result = {
            'tools': [
              if (reply == _ToolsReply.tools)
                {
                  'name': 'echo',
                  'description': 'Echo',
                  'inputSchema': {'type': 'object'},
                },
            ],
          };
        default:
          request.response.statusCode = HttpStatus.accepted;
          await request.response.close();
          return;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': message['id'],
          if (message['method'] == 'tools/list' && reply == _ToolsReply.error)
            'error': {'code': -32603, 'message': 'Tool discovery failed'}
          else
            'result': result,
        }),
      );
      await request.response.close();
    });
  }

  final HttpServer server;
  final _ToolsReply reply;
  late final StreamSubscription<HttpRequest> subscription;
  final toolsRequested = Completer<void>();
  final releaseTools = Completer<void>();

  String get url => 'http://${server.address.address}:${server.port}/mcp';

  static Future<_DelayedMcpServer> start(_ToolsReply reply) async =>
      _DelayedMcpServer(
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
        reply,
      );

  Future<void> close() async {
    await server.close(force: true);
    await subscription.cancel();
  }
}
