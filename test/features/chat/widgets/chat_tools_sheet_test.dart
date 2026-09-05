import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/chat/widgets/chat_tools_sheet.dart';
import 'package:Kelivo/features/home/services/local_tool_labels.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';
import 'package:Kelivo/features/workspace/widgets/workspace_section.dart';
import 'package:Kelivo/features/workspace/pages/workspace_settings_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => p.join(path, 'cache');

  @override
  Future<String?> getTemporaryPath() async => p.join(path, 'tmp');
}

class _FakeChatService extends ChatService {
  _FakeChatService(this.conversation);

  Conversation? conversation;

  @override
  String? get currentConversationId => conversation?.id;

  @override
  Conversation? getConversation(String id) =>
      conversation?.id == id ? conversation : null;

  @override
  Future<void> updateConversationExtras(
    String conversationId,
    Map<String, dynamic> Function(Map<String, dynamic> current) update,
  ) async {
    final current = getConversation(conversationId);
    if (current == null) return;
    conversation = current.copyWith(
      extras: update(Map<String, dynamic>.from(current.extras)),
    );
    notifyListeners();
  }
}

class _FakeMcpProvider extends McpProvider {
  _FakeMcpProvider({required super.preferences});

  List<McpServerConfig> fakeServers = const <McpServerConfig>[];

  @override
  List<McpServerConfig> get servers => fakeServers;

  @override
  McpStatus statusFor(String id) => McpStatus.connected;

  @override
  List<McpServerConfig> get connectedServers => fakeServers;

  @override
  bool get hasAnyEnabled => fakeServers.isNotEmpty;
}

McpServerConfig _server(String id, String name, {int tools = 2}) {
  return McpServerConfig(
    id: id,
    enabled: true,
    name: name,
    transport: McpTransportType.sse,
    tools: [
      for (var i = 0; i < tools; i++)
        McpToolConfig(enabled: i == 0, name: '$id-tool-$i'),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;
  late AppDatabase database;
  late WorkspaceProvider workspaces;
  late EnvironmentProvider environment;
  late SettingsProvider settings;
  late AssistantProvider assistants;
  late _FakeMcpProvider mcp;
  late BusinessPreferences uiPreferences;
  late String assistantId;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('kelivo_chat_tools_sheet_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1;').getSingle();
    workspaces = WorkspaceProvider(store: ExtensionEntityStore(database));
    await workspaces.loaded;
    // Every createBusinessTestPreferences() call resets the SharedPreferences
    // mock store, so build them all up front: doing it while a provider load
    // is in flight swaps the store out from under it.
    final settingsPreferences = createBusinessTestPreferences();
    final environmentPreferences = createBusinessTestPreferences();
    final assistantPreferences = createBusinessTestPreferences();
    final mcpPreferences = createBusinessTestPreferences();
    uiPreferences = createBusinessTestPreferences();
    await uiPreferences.load();
    settings = SettingsProvider(settingsPreferences);
    environment = EnvironmentProvider(preferences: environmentPreferences);
    await environment.loaded;
    mcp = _FakeMcpProvider(preferences: mcpPreferences);
    await assistantPreferences.load();
    assistantId = 'assistant-under-test';
    await assistantPreferences.setString(
      'assistants_v1',
      jsonEncode([Assistant(id: assistantId, name: 'Tester').toJson()]),
    );
    await assistantPreferences.setString(
      'current_assistant_id_v1',
      assistantId,
    );
    assistants = AssistantProvider(preferences: assistantPreferences);
    await assistants.loaded;
    await settings.loaded;
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<AppLocalizations> pumpSheet(
    WidgetTester tester, {
    List<McpServerConfig> servers = const [],
    Conversation? conversation,
  }) async {
    mcp.fakeServers = servers;
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
          ChangeNotifierProvider<ChatService>.value(
            value: _FakeChatService(conversation),
          ),
          ChangeNotifierProvider<WorkspaceRuntimeProvider>(
            create: (_) => WorkspaceRuntimeProvider(),
          ),
          ChangeNotifierProvider<EnvironmentProvider>.value(value: environment),
          ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
          ChangeNotifierProvider<McpProvider>.value(value: mcp),
          Provider<BusinessPreferences>.value(value: uiPreferences),
          Provider<EnvironmentManager?>.value(value: null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppSnackBarOverlay(
            child: Scaffold(
              body: ChatToolsSheet(
                assistantId: assistantId,
                conversationId: conversation?.id,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'workspace row settings opens the existing workspace and environment page on $platform',
      (tester) async {
        final workspace = await tester.runAsync(
          () => workspaces.create(name: 'Test workspace'),
        );
        final l10n = await pumpSheet(
          tester,
          conversation: Conversation(
            title: 'Chat',
            extras: WorkspaceBinding(workspaceId: workspace!.id).applyTo({}),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.byKey(WorkspaceSection.manageKey);
        final files = find.byKey(WorkspaceSection.filesKey);
        expect(
          find.descendant(
            of: find.byKey(WorkspaceSection.nameKey),
            matching: action,
          ),
          findsOneWidget,
        );
        expect(
          tester.getCenter(action).dx,
          lessThan(tester.getCenter(files).dx),
        );
        expect(tester.getCenter(action).dy, tester.getCenter(files).dy);
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.byType(WorkspaceSettingsPage), findsOneWidget);
        expect(find.text(l10n.settingsPageWorkspace), findsOneWidget);
        expect(find.text(l10n.workspaceEnvTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets('shows the local tools group folded with an enabled count', (
    tester,
  ) async {
    final l10n = await pumpSheet(tester);

    expect(find.byKey(ChatToolsSheet.localGroupKey), findsOneWidget);
    expect(
      find.text('0/${availableLocalToolIds().length}'),
      findsOneWidget,
      reason: 'the folded header still reports how many tools are on',
    );
    expect(
      find.byKey(ChatToolsSheet.localToolKey(LocalToolNames.timeInfo)),
      findsNothing,
      reason: 'local tools start folded',
    );
    expect(find.text(l10n.assistantEditPageLocalToolsTab), findsOneWidget);
  });

  testWidgets('unfolding a group swaps its summary for the rows', (
    tester,
  ) async {
    final l10n = await pumpSheet(tester);
    final count = '0/${availableLocalToolIds().length}';
    expect(find.text(count), findsOneWidget);

    await tester.tap(find.text(l10n.assistantEditPageLocalToolsTab));
    await tester.pumpAndSettle();

    expect(
      find.text(count),
      findsNothing,
      reason: 'an open group shows its rows instead of a summary',
    );
    expect(
      find.byKey(ChatToolsSheet.localToolKey(LocalToolNames.timeInfo)),
      findsOneWidget,
    );
  });

  testWidgets('reopening the sheet restores the last fold state', (
    tester,
  ) async {
    final l10n = await pumpSheet(tester);
    final timeInfo = find.byKey(
      ChatToolsSheet.localToolKey(LocalToolNames.timeInfo),
    );
    expect(timeInfo, findsNothing);

    await tester.tap(find.text(l10n.assistantEditPageLocalToolsTab));
    await tester.pumpAndSettle();
    expect(timeInfo, findsOneWidget);
    // The write goes through SQLite, which the fake clock does not advance.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );

    // Tear the sheet down and open a fresh one, as reopening it would.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpSheet(tester);

    expect(
      timeInfo,
      findsOneWidget,
      reason: 'the group the user opened stays open next time',
    );
  });

  testWidgets('unfolding local tools and tapping one enables it', (
    tester,
  ) async {
    final l10n = await pumpSheet(tester);

    await tester.tap(find.text(l10n.assistantEditPageLocalToolsTab));
    await tester.pumpAndSettle();

    final row = find.byKey(
      ChatToolsSheet.localToolKey(LocalToolNames.timeInfo),
    );
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(
      assistants.getById(assistantId)!.localToolIds,
      contains(LocalToolNames.timeInfo),
    );
    // AssistantProvider notifies only after persisting, which needs real async
    // time the fake clock does not advance.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    // The count is the folded header's summary, so fold the group to read it.
    await tester.tap(find.text(l10n.assistantEditPageLocalToolsTab));
    await tester.pumpAndSettle();
    expect(find.text('1/${availableLocalToolIds().length}'), findsOneWidget);
  });

  testWidgets('hides the MCP group when nothing is connected', (tester) async {
    await pumpSheet(tester);
    expect(find.byKey(ChatToolsSheet.mcpGroupKey), findsNothing);
  });

  testWidgets('MCP servers toggle the assistant selection', (tester) async {
    await pumpSheet(tester, servers: [_server('s1', 'Alpha')]);

    expect(find.byKey(ChatToolsSheet.mcpGroupKey), findsOneWidget);
    final row = find.byKey(ChatToolsSheet.mcpServerKey('s1'));
    expect(row, findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);

    await tester.tap(
      find.descendant(of: row, matching: find.byType(IosSwitch)),
    );
    await tester.pumpAndSettle();
    expect(assistants.getById(assistantId)!.mcpServerIds, ['s1']);

    // AssistantProvider notifies only after persisting, so the row would still
    // be reading the pre-toggle selection without real async time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(assistants.getById(assistantId)!.mcpServerIds, isEmpty);
  });

  testWidgets('workspace group hosts the workspace section', (tester) async {
    await pumpSheet(tester);

    expect(find.byKey(ChatToolsSheet.workspaceGroupKey), findsOneWidget);
    expect(find.byType(WorkspaceSection), findsOneWidget);
    expect(find.byKey(WorkspaceSection.bindKey), findsOneWidget);
  });

  testWidgets('folding the workspace group hides its rows', (tester) async {
    final l10n = await pumpSheet(tester);

    await tester.tap(find.text(l10n.workspacesTitle));
    await tester.pumpAndSettle();

    expect(find.byKey(WorkspaceSection.bindKey), findsNothing);
  });
}
