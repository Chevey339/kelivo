import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/workspace/widgets/files/conversation_files_panel.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/segmented_tabs.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import '../../../../support/business_test_harness.dart';

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

Future<void> _awaitPanel(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
  final state = tester.state<ConversationFilesPanelState>(
    find.byType(ConversationFilesPanel),
  );
  await tester.runAsync(state.load);
  await tester.pump();
  final browsers = find.byType(FileBrowser);
  final count = browsers.evaluate().length;
  for (var i = 0; i < count; i++) {
    await tester.runAsync(
      tester.state<FileBrowserState>(browsers.at(i)).refreshEntries,
    );
  }
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;
  late AppDatabase database;
  late WorkspaceProvider workspaces;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('kelivo_conv_files_');
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
    required String conversationId,
    ConversationFilesTab initialTab = ConversationFilesTab.attachments,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider<ChatService>.value(
          value: _FakeChatService(conversation),
        ),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ConversationFilesPanel(
            conversationId: conversationId,
            initialTab: initialTab,
          ),
        ),
      ),
    );
  }

  testWidgets('shows attachments outputs and unbound workspace hint', (
    tester,
  ) async {
    const conversationId = 'conv-unbound';
    await tester.runAsync(() async {
      final session = await AppDirectories.sessionDir(conversationId);
      File(
        p.join(session.path, 'attachments', 'photo.png'),
      ).writeAsBytesSync(const [1, 2, 3]);
      File(
        p.join(session.path, 'outputs', 'result.txt'),
      ).writeAsStringSync('out');
    });

    final conversation = Conversation(id: conversationId, title: 'Chat');
    await tester.pumpWidget(
      harness(conversation: conversation, conversationId: conversationId),
    );
    await _awaitPanel(tester);

    expect(find.text('Attachments'), findsWidgets);
    expect(find.text('Outputs'), findsWidgets);
    expect(find.text('Workspace'), findsWidgets);
    expect(find.byKey(FileBrowser.itemKey('photo.png')), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedTabs),
        matching: find.text('Outputs'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await _awaitPanel(tester);
    expect(find.byKey(FileBrowser.itemKey('result.txt')), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedTabs),
        matching: find.text('Workspace'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(ConversationFilesPanel.unboundHintKey), findsOneWidget);
    expect(find.text('No workspace bound'), findsOneWidget);
  });

  testWidgets('workspace tab shows bound workspace files', (tester) async {
    const conversationId = 'conv-bound';
    late String workspaceId;
    await tester.runAsync(() async {
      final workspace = await workspaces.create(name: 'Bound WS');
      workspaceId = workspace.id;
      final root = await workspaces.hostRootFor(workspace);
      File(p.join(root, 'readme.md')).writeAsStringSync('hello');
      await AppDirectories.sessionDir(conversationId);
    });

    final conversation = Conversation(
      id: conversationId,
      title: 'Chat',
      extras: {WorkspaceBinding.keyId: workspaceId},
    );

    await tester.pumpWidget(
      harness(conversation: conversation, conversationId: conversationId),
    );
    await _awaitPanel(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedTabs),
        matching: find.text('Workspace'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await _awaitPanel(tester);

    expect(find.byKey(ConversationFilesPanel.unboundHintKey), findsNothing);
    expect(find.byKey(FileBrowser.itemKey('readme.md')), findsOneWidget);
  });

  testWidgets('initialTab opens the workspace tab', (tester) async {
    const conversationId = 'conv-initial-tab';
    await tester.runAsync(() async {
      await AppDirectories.sessionDir(conversationId);
    });

    final conversation = Conversation(id: conversationId, title: 'Chat');
    await tester.pumpWidget(
      harness(
        conversation: conversation,
        conversationId: conversationId,
        initialTab: ConversationFilesTab.workspace,
      ),
    );
    await _awaitPanel(tester);

    final tabs = tester.widget<SegmentedTabs>(find.byType(SegmentedTabs));
    expect(tabs.index, ConversationFilesTab.workspace.index);
    expect(find.byKey(ConversationFilesPanel.unboundHintKey), findsOneWidget);
    expect(find.text('No workspace bound'), findsOneWidget);
  });
}
