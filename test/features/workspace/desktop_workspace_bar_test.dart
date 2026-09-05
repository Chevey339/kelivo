import 'dart:io';

import 'package:Kelivo/features/workspace/widgets/files/conversation_files_panel.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/workspace/widgets/desktop_workspace_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/segmented_tabs.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';
import '../../support/fake_workspace_runtime.dart';

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

  final Conversation? conversation;

  @override
  String? get currentConversationId => conversation?.id;

  @override
  Conversation? getConversation(String id) {
    if (conversation == null) return null;
    return conversation!.id == id ? conversation : null;
  }
}

class _TerminalRuntime extends FakeWorkspaceRuntime {
  _TerminalRuntime({required this.systemTerminal});

  final bool systemTerminal;

  @override
  bool get supportsSystemTerminal => systemTerminal;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;
  late AppDatabase database;
  late WorkspaceProvider workspaces;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('kelivo_desk_ws_bar_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1;').getSingle();
    workspaces = WorkspaceProvider(store: ExtensionEntityStore(database));
    await workspaces.loaded;
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget harness({
    required Conversation? conversation,
    WorkspaceRuntime? runtime,
  }) {
    final runtimeProvider = WorkspaceRuntimeProvider();
    if (runtime != null) {
      runtimeProvider.register(runtime);
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider<ChatService>.value(
          value: _FakeChatService(conversation),
        ),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
        ChangeNotifierProvider<WorkspaceRuntimeProvider>.value(
          value: runtimeProvider,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: DesktopWorkspaceBar.width,
            height: 640,
            child: DesktopWorkspaceBar(conversationId: conversation?.id),
          ),
        ),
      ),
    );
  }

  testWidgets('unbound conversation can bind directly from the workspace tab', (
    tester,
  ) async {
    const conversationId = 'conv-unbound';
    final conversation = Conversation(id: conversationId, title: 'Chat');

    await tester.pumpWidget(harness(conversation: conversation));
    for (
      var i = 0;
      i < 80 &&
          find.byKey(ConversationFilesPanel.bindCtaKey).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }

    expect(find.byKey(DesktopWorkspaceBar.emptyStateKey), findsNothing);
    expect(find.text('No workspace'), findsOneWidget);
    expect(find.byKey(ConversationFilesPanel.bindCtaKey), findsOneWidget);
    expect(find.byType(SegmentedTabs), findsOneWidget);
    expect(find.byKey(DesktopWorkspaceBar.openTerminalKey), findsNothing);
  });

  testWidgets('shows workspace name and file tabs when bound', (tester) async {
    const conversationId = 'conv-bound';
    late String workspaceId;
    await tester.runAsync(() async {
      final workspace = await workspaces.create(name: 'Desk WS');
      workspaceId = workspace.id;
    });

    final conversation = Conversation(
      id: conversationId,
      title: 'Chat',
      extras: {WorkspaceBinding.keyId: workspaceId},
    );

    await tester.pumpWidget(
      harness(
        conversation: conversation,
        runtime: _TerminalRuntime(systemTerminal: true),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.byKey(DesktopWorkspaceBar.emptyStateKey), findsNothing);
    expect(find.text('Desk WS'), findsWidgets);
    final tabs = tester.widget<SegmentedTabs>(find.byType(SegmentedTabs));
    expect(tabs.tabs, hasLength(3));
    expect(find.text('Attachments'), findsWidgets);
    expect(find.text('Outputs'), findsWidgets);
    expect(find.text('Workspace'), findsWidgets);
    expect(find.byKey(DesktopWorkspaceBar.openTerminalKey), findsOneWidget);
    expect(find.byKey(DesktopWorkspaceBar.revealKey), findsOneWidget);
  });

  testWidgets('hides system-terminal action when runtime lacks support', (
    tester,
  ) async {
    const conversationId = 'conv-no-term';
    late String workspaceId;
    await tester.runAsync(() async {
      final workspace = await workspaces.create(name: 'No Term WS');
      workspaceId = workspace.id;
    });

    final conversation = Conversation(
      id: conversationId,
      title: 'Chat',
      extras: {WorkspaceBinding.keyId: workspaceId},
    );

    await tester.pumpWidget(
      harness(
        conversation: conversation,
        runtime: _TerminalRuntime(systemTerminal: false),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.text('No Term WS'), findsOneWidget);
    expect(find.byKey(DesktopWorkspaceBar.openTerminalKey), findsNothing);
    expect(find.byKey(DesktopWorkspaceBar.revealKey), findsNothing);
  });
}
