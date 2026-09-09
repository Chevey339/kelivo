import 'dart:io';

import 'package:Kelivo/desktop/workspace_dialog.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/chat/widgets/tools_sheet_row.dart';
import 'package:Kelivo/features/workspace/pages/workspace_files_page.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/features/workspace/widgets/workspace_picker.dart';
import 'package:Kelivo/features/workspace/widgets/workspace_section.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/custom_bottom_sheet.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

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
  final Map<String, Conversation> _conversations = <String, Conversation>{};

  void setConversation(Conversation? next) {
    conversation = next;
    if (next != null) {
      _conversations[next.id] = next;
    }
  }

  @override
  String? get currentConversationId => conversation?.id;

  @override
  Conversation? getConversation(String id) {
    return _conversations[id] ?? (conversation?.id == id ? conversation : null);
  }

  @override
  Future<void> updateConversationExtras(
    String conversationId,
    Map<String, dynamic> Function(Map<String, dynamic> current) update,
  ) async {
    final current = getConversation(conversationId);
    if (current == null) return;
    final next = current.copyWith(
      extras: update(Map<String, dynamic>.from(current.extras)),
    );
    _conversations[conversationId] = next;
    if (conversation?.id == conversationId) {
      conversation = next;
    }
    notifyListeners();
  }

  @override
  Future<Conversation> createDraftConversation({
    String? title,
    String? assistantId,
    bool temporary = false,
  }) async {
    final draft = Conversation(
      title: title ?? 'New Chat',
      assistantId: assistantId,
    );
    setConversation(draft);
    notifyListeners();
    return draft;
  }
}

class _ConversationSwitchHarness extends StatefulWidget {
  const _ConversationSwitchHarness({
    required this.chat,
    required this.firstId,
    required this.secondId,
  });

  final _FakeChatService chat;
  final String firstId;
  final String secondId;

  @override
  State<_ConversationSwitchHarness> createState() =>
      _ConversationSwitchHarnessState();
}

class _ConversationSwitchHarnessState
    extends State<_ConversationSwitchHarness> {
  late String _conversationId;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.firstId;
  }

  void _switchConversation() {
    setState(() => _conversationId = widget.secondId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        WorkspaceSection(conversationId: _conversationId),
        TextButton(onPressed: _switchConversation, child: const Text('switch')),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;
  late AppDatabase database;
  late WorkspaceProvider workspaces;
  late EnvironmentProvider environment;
  late SettingsProvider settings;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('kelivo_workspace_section_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1;').getSingle();
    workspaces = WorkspaceProvider(store: ExtensionEntityStore(database));
    await workspaces.loaded;
    settings = SettingsProvider(createBusinessTestPreferences());
    environment = EnvironmentProvider(
      preferences: createBusinessTestPreferences(),
    );
    await environment.loaded;
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<AppLocalizations> pumpSection(
    WidgetTester tester, {
    required _FakeChatService chat,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
          ChangeNotifierProvider<ChatService>.value(value: chat),
          ChangeNotifierProvider<WorkspaceRuntimeProvider>(
            create: (_) => WorkspaceRuntimeProvider(),
          ),
          ChangeNotifierProvider<EnvironmentProvider>.value(value: environment),
          ChangeNotifierProvider(
            create: (_) =>
                AssistantProvider(preferences: createBusinessTestPreferences()),
          ),
          Provider<EnvironmentManager?>.value(value: null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppSnackBarOverlay(
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    WorkspaceSection(conversationId: chat.conversation?.id),
                    const SizedBox(height: 8),
                    ToolsSheetRow(
                      icon: Lucide.Layers,
                      label: 'Instruction injection',
                      trailing: const Icon(Lucide.ChevronRight, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
  }

  testWidgets('desktop workspace launcher can create and bind a workspace', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chat = _FakeChatService(Conversation(title: 'Desktop chat'));
    final anchor = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider(
            create: (_) =>
                AssistantProvider(preferences: createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
          ChangeNotifierProvider<ChatService>.value(value: chat),
          ChangeNotifierProvider(create: (_) => WorkspaceRuntimeProvider()),
          ChangeNotifierProvider<EnvironmentProvider>.value(value: environment),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: TextButton(
                  key: anchor,
                  onPressed: () => showDesktopWorkspaceDialog(
                    context,
                    conversationListenable: chat,
                    conversationId: () => chat.conversation?.id,
                  ),
                  child: const Text('workspace-launcher'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('workspace-launcher'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WorkspaceSection.bindKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WorkspaceSection.createKey));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Desktop project');
    await tester.pump();
    await tester.tap(find.text('Create').last);
    for (var i = 0; i < 80 && workspaces.workspaces.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(workspaces.workspaces.single.name, 'Desktop project');
    expect(
      WorkspaceBinding.fromExtras(chat.conversation!.extras).workspaceId,
      workspaces.workspaces.single.id,
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('not-bound shows Bind row', (tester) async {
    final chat = _FakeChatService(Conversation(title: 'Chat'));
    final l10n = await pumpSection(tester, chat: chat);
    expect(find.byKey(WorkspaceSection.bindKey), findsOneWidget);
    expect(find.text(l10n.workspaceEntryBind), findsOneWidget);
    expect(find.byKey(WorkspaceSection.changeKey), findsNothing);
  });

  testWidgets('bound shows name plus Change and Unbind', (tester) async {
    final workspace = await tester.runAsync(
      () => workspaces.create(name: 'Alpha'),
    );
    if (workspace == null) fail('workspace create failed');
    final chat = _FakeChatService(
      Conversation(
        title: 'Chat',
        extras: WorkspaceBinding(
          workspaceId: workspace.id,
          cwd: 'src',
        ).applyTo({}),
      ),
    );
    final l10n = await pumpSection(tester, chat: chat);
    expect(find.byKey(WorkspaceSection.nameKey), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.byKey(WorkspaceSection.filesKey), findsOneWidget);
    expect(find.byKey(WorkspaceSection.changeKey), findsOneWidget);
    expect(find.byKey(WorkspaceSection.unbindKey), findsOneWidget);
    expect(find.text(l10n.workspaceEntryChange), findsNothing);
    expect(find.text(l10n.workspaceEntryUnbind), findsNothing);
    expect(find.text(l10n.workspaceEntryAllowAll), findsOneWidget);
    expect(find.text(l10n.workspaceEntryAllowAllSubtitle), findsOneWidget);
    // Files rides on the name row as an icon button, and session skills live
    // in the ＋ sheet now.
    expect(find.text(l10n.workspaceEntryFiles), findsNothing);
    expect(find.text(l10n.workspaceEntrySessionSkills), findsNothing);
  });

  testWidgets('long-pressing the bound workspace opens its files page', (
    tester,
  ) async {
    final workspace = await tester.runAsync(
      () => workspaces.create(name: 'Alpha'),
    );
    if (workspace == null) fail('workspace create failed');
    final chat = _FakeChatService(
      Conversation(
        title: 'Chat',
        extras: WorkspaceBinding(workspaceId: workspace.id).applyTo({}),
      ),
    );
    await pumpSection(tester, chat: chat);
    await tester.longPress(find.byKey(WorkspaceSection.nameKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(WorkspaceFilesPage), findsOneWidget);
  });

  testWidgets('toolsUsed still opens the menu and confirms before unbind', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final workspace = await tester.runAsync(
      () => workspaces.create(name: 'Used'),
    );
    if (workspace == null) fail('workspace create failed');
    final chat = _FakeChatService(
      Conversation(
        title: 'Chat',
        extras: WorkspaceBinding(
          workspaceId: workspace.id,
          toolsUsed: true,
        ).applyTo({}),
      ),
    );
    final l10n = await pumpSection(tester, chat: chat);
    await tester.ensureVisible(find.byKey(WorkspaceSection.nameKey));
    await tester.tap(find.byKey(WorkspaceSection.nameKey));
    await tester.pumpAndSettle();
    expect(find.text(l10n.workspaceEntryChange), findsOneWidget);
    expect(find.text(l10n.workspaceEntryUnbind), findsOneWidget);

    await tester.tap(find.text(l10n.workspaceEntryUnbind));
    await tester.pumpAndSettle();
    expect(find.text(l10n.workspaceEntryUnbindConfirmTitle), findsOneWidget);
    expect(find.text(l10n.workspaceEntryChangeConfirmBody), findsOneWidget);

    await tester.tap(find.text(l10n.workspaceFilesCancel));
    await tester.pumpAndSettle();
    expect(
      WorkspaceBinding.fromExtras(chat.conversation!.extras).isBound,
      isTrue,
    );

    await tester.tap(find.byKey(WorkspaceSection.nameKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.workspaceEntryUnbind));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-confirm-accept')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      WorkspaceBinding.fromExtras(chat.conversation!.extras).isBound,
      isFalse,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('allow-all switch writes keyAllowAll', (tester) async {
    final workspace = await tester.runAsync(
      () => workspaces.create(name: 'Tools'),
    );
    if (workspace == null) fail('workspace create failed');
    final chat = _FakeChatService(
      Conversation(
        title: 'Chat',
        extras: WorkspaceBinding(workspaceId: workspace.id).applyTo({}),
      ),
    );
    await pumpSection(tester, chat: chat);
    expect(
      WorkspaceBinding.fromExtras(chat.conversation!.extras).allowAll,
      isFalse,
    );
    await tester.ensureVisible(find.byKey(WorkspaceSection.allowAllKey));
    await tester.tap(find.byKey(WorkspaceSection.allowAllKey));
    await tester.pump();
    expect(
      WorkspaceBinding.fromExtras(chat.conversation!.extras).allowAll,
      isTrue,
    );
  });

  testWidgets('cwd folder picker sets a relative path', (tester) async {
    final workspace = await tester.runAsync(
      () => workspaces.create(name: 'Files'),
    );
    if (workspace == null) fail('workspace create failed');
    await tester.runAsync(() async {
      final root = await workspaces.hostRootFor(workspace);
      Directory(p.join(root, 'src')).createSync(recursive: true);
    });
    final chat = _FakeChatService(
      Conversation(
        title: 'Chat',
        extras: WorkspaceBinding(workspaceId: workspace.id).applyTo({}),
      ),
    );
    await pumpSection(tester, chat: chat);
    await tester.ensureVisible(find.byKey(WorkspaceSection.cwdKey));
    await tester.tap(find.byKey(WorkspaceSection.cwdKey));
    // Wait for the actual filesystem-backed picker, not a single event-loop turn.
    for (
      var i = 0;
      i < 80 && find.byType(FileBrowser).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 350));

    final browser = find.byType(FileBrowser);
    expect(browser, findsOneWidget);
    await tester.runAsync(
      tester.state<FileBrowserState>(browser).refreshEntries,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final srcItem = find.byKey(FileBrowser.itemKey('src'));
    await tester.ensureVisible(srcItem);
    await tester.pump();
    await tester.tap(srcItem);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(
      tester.state<FileBrowserState>(find.byType(FileBrowser)).refreshEntries,
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(FileBrowser.pickDirectoryKey));
    await tester.tap(find.byKey(FileBrowser.pickDirectoryKey));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(WorkspaceBinding.fromExtras(chat.conversation!.extras).cwd, 'src');
  });

  testWidgets('workspace rows match tools-sheet row type and height', (
    tester,
  ) async {
    final chat = _FakeChatService(Conversation(title: 'Chat'));
    await pumpSection(tester, chat: chat);

    final bind = find.byKey(WorkspaceSection.bindKey);
    final injection = find.byWidgetPredicate(
      (widget) =>
          widget is ToolsSheetRow && widget.label == 'Instruction injection',
    );
    expect(tester.widget(bind), isA<ToolsSheetRow>());
    expect(tester.widget(injection), isA<ToolsSheetRow>());
    expect(tester.getSize(bind).height, 48);
    expect(tester.getSize(injection).height, 48);
    expect(
      find.descendant(
        of: find.byType(WorkspaceSection),
        matching: find.byWidgetPredicate(_isTiledIconWell),
      ),
      findsNothing,
    );
  });

  testWidgets('tapping the bound row offers change and destructive unbind', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final workspace = await tester.runAsync(
      () => workspaces.create(name: 'Menu'),
    );
    if (workspace == null) fail('workspace create failed');
    final chat = _FakeChatService(
      Conversation(
        title: 'Chat',
        extras: WorkspaceBinding(workspaceId: workspace.id).applyTo({}),
      ),
    );
    final l10n = await pumpSection(tester, chat: chat);

    await tester.tap(find.byKey(WorkspaceSection.nameKey));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Menu'),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.workspaceUnbindHint), findsNothing);
    expect(find.text(l10n.workspaceEntryChange), findsOneWidget);
    final unbind = tester.widget<Text>(find.text(l10n.workspaceEntryUnbind));
    expect(
      unbind.style?.color,
      Theme.of(
        tester.element(find.text(l10n.workspaceEntryUnbind)),
      ).colorScheme.error,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('unbind shows past-tense hint snackbar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final workspace = await tester.runAsync(
      () => workspaces.create(name: 'Snack'),
    );
    if (workspace == null) fail('workspace create failed');
    final chat = _FakeChatService(
      Conversation(
        title: 'Chat',
        extras: WorkspaceBinding(workspaceId: workspace.id).applyTo({}),
      ),
    );
    final l10n = await pumpSection(tester, chat: chat);

    await tester.tap(find.byKey(WorkspaceSection.nameKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.workspaceEntryUnbind));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(l10n.workspaceUnbindHint), findsOneWidget);
    expect(
      WorkspaceBinding.fromExtras(chat.conversation!.extras).isBound,
      isFalse,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('follows conversation id changes after local draft was created', (
    tester,
  ) async {
    final workspace = await tester.runAsync(
      () => workspaces.create(name: 'Inherited'),
    );
    if (workspace == null) fail('workspace create failed');

    final first = Conversation(title: 'First');
    final second = Conversation(
      title: 'Second',
      extras: WorkspaceBinding(
        workspaceId: workspace.id,
        cwd: 'src',
      ).applyTo({}),
    );
    final chat = _FakeChatService(first)
      ..setConversation(first)
      ..setConversation(second);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
          ChangeNotifierProvider<ChatService>.value(value: chat),
          ChangeNotifierProvider<WorkspaceRuntimeProvider>(
            create: (_) => WorkspaceRuntimeProvider(),
          ),
          ChangeNotifierProvider<EnvironmentProvider>.value(value: environment),
          ChangeNotifierProvider(
            create: (_) =>
                AssistantProvider(preferences: createBusinessTestPreferences()),
          ),
          Provider<EnvironmentManager?>.value(value: null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppSnackBarOverlay(
            child: Scaffold(
              body: _ConversationSwitchHarness(
                chat: chat,
                firstId: first.id,
                secondId: second.id,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(WorkspaceSection.bindKey), findsOneWidget);
    expect(find.text('Inherited'), findsNothing);

    await tester.tap(find.text('switch'));
    await tester.pump();

    expect(find.byKey(WorkspaceSection.bindKey), findsNothing);
    expect(find.text('Inherited'), findsOneWidget);
  });

  testWidgets(
    'closing files opened from a more sheet does not leave a blocking barrier',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final workspace = await tester.runAsync(
        () => workspaces.create(name: 'Files'),
      );
      if (workspace == null) fail('workspace create failed');
      final chat = _FakeChatService(
        Conversation(
          title: 'Chat',
          extras: WorkspaceBinding(workspaceId: workspace.id).applyTo({}),
        ),
      );
      var homeTaps = 0;
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
            ChangeNotifierProvider<ChatService>.value(value: chat),
            ChangeNotifierProvider<WorkspaceRuntimeProvider>(
              create: (_) => WorkspaceRuntimeProvider(),
            ),
            ChangeNotifierProvider<EnvironmentProvider>.value(
              value: environment,
            ),
            ChangeNotifierProvider(
              create: (_) => AssistantProvider(
                preferences: createBusinessTestPreferences(),
              ),
            ),
            Provider<EnvironmentManager?>.value(value: null),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Column(
                    children: [
                      TextButton(
                        onPressed: () => homeTaps++,
                        child: const Text('home-tap'),
                      ),
                      TextButton(
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            builder: (ctx) => WorkspaceSection(
                              conversationId: chat.conversation!.id,
                              onClose: () => Navigator.of(ctx).maybePop(),
                            ),
                          );
                        },
                        child: const Text('open-more'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('open-more'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WorkspaceSection.filesKey));
      // The files panel shows a loading spinner, so pumpAndSettle never ends.
      // Wait until the close control has finished the enter animation and is
      // actually on-screen; the widget is in the tree from the first frame
      // while the panel is still translated below the viewport.
      final viewSize = tester.view.physicalSize / tester.view.devicePixelRatio;
      var closeOnScreen = false;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final close = find.byKey(CustomBottomSheet.closeButtonKey);
        if (close.evaluate().isEmpty) continue;
        final center = tester.getCenter(close);
        if (center.dy >= 0 && center.dy < viewSize.height) {
          closeOnScreen = true;
          break;
        }
      }
      expect(closeOnScreen, isTrue);

      await tester.tap(find.byKey(CustomBottomSheet.closeButtonKey));
      await tester.pump();
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byKey(CustomBottomSheet.closeButtonKey).evaluate().isEmpty) {
          break;
        }
      }
      expect(find.byKey(CustomBottomSheet.closeButtonKey), findsNothing);

      await tester.tap(find.text('home-tap'));
      await tester.pump();
      expect(homeTaps, 1);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('picker returns the chosen workspace id', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final workspace = await tester.runAsync(
      () => workspaces.create(name: 'Picked'),
    );
    if (workspace == null) fail('workspace create failed');
    final chat = _FakeChatService(Conversation(title: 'Chat'));
    await pumpSection(tester, chat: chat);
    final hostContext = tester.element(find.byType(Scaffold));

    final future = pickWorkspaceForConversation(hostContext);
    await tester.pumpAndSettle();
    expect(find.byKey(WorkspaceSection.pickKey(workspace.id)), findsOneWidget);
    await tester.tap(find.byKey(WorkspaceSection.pickKey(workspace.id)));
    await tester.pumpAndSettle();
    expect((await future)?.id, workspace.id);
    debugDefaultTargetPlatformOverride = null;
  });
}

bool _isTiledIconWell(Widget widget) {
  if (widget is! Container) return false;
  final decoration = widget.decoration;
  if (decoration is! BoxDecoration || decoration.color == null) return false;
  final constraints = widget.constraints;
  return constraints != null &&
      constraints.maxWidth == 36 &&
      constraints.maxHeight == 36;
}
