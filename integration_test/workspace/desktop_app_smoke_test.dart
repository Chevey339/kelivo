import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/core/services/workspace/desktop_process_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/desktop/workspace_popover.dart';
import 'package:Kelivo/features/workspace/pages/workspaces_page.dart';
import 'package:Kelivo/features/workspace/widgets/desktop_workspace_bar.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_pane.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skills_pane.dart';
import 'package:Kelivo/shared/widgets/segmented_tabs.dart';
import 'package:Kelivo/features/workspace/widgets/workspace_section.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import '../../test/support/business_test_harness.dart';

/// Isolated desktop smoke. `package:Kelivo/main.dart` `main()` has no
/// test-friendly entry: it opens the real app-data DB, increments launch
/// count, and initializes window/hotkey services. Existing integration tests
/// also pump focused trees. This file uses real providers + the real desktop
/// settings / workspace widgets against a temp path_provider root.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('macos desktop workspace / skills smoke', (tester) async {
    if (!Platform.isMacOS && !Platform.isLinux) {
      markTestSkipped('desktop workspace smoke is macOS/Linux only');
      return;
    }

    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tempDir = Directory.systemTemp.createTempSync(
      'kelivo_macos_ws_smoke_',
    );
    final previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    addTearDown(() async {
      PathProviderPlatform.instance = previousPathProvider;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.runAsync(() => database.customSelect('SELECT 1;').getSingle());
    final store = ExtensionEntityStore(database);
    final workspaces = WorkspaceProvider(store: store);
    await tester.runAsync(() => workspaces.loaded);
    final settings = SettingsProvider(createBusinessTestPreferences());
    await tester.runAsync(() => settings.loaded);
    final environment = EnvironmentProvider(
      preferences: createBusinessTestPreferences(),
    );
    await tester.runAsync(() => environment.loaded);
    final skills = SkillsService(
      store: store,
      skillsDirectory: Directory(p.join(tempDir.path, 'skills'))
        ..createSync(recursive: true),
    );
    await tester.runAsync(() => skills.loaded);
    final runtimeProvider = WorkspaceRuntimeProvider()
      ..register(DesktopProcessRuntime());
    await tester.runAsync(runtimeProvider.refresh);
    final conversation = Conversation(id: 'conv-smoke', title: 'Smoke');
    final chat = _FakeChatService(conversation);

    var page = _SmokePage.settings;
    final folderKey = GlobalKey();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
          ChangeNotifierProvider<ChatService>.value(value: chat),
          ChangeNotifierProvider<WorkspaceRuntimeProvider>.value(
            value: runtimeProvider,
          ),
          ChangeNotifierProvider<EnvironmentProvider>.value(value: environment),
          ChangeNotifierProvider<SkillsService>.value(value: skills),
          Provider<EnvironmentManager?>.value(value: null),
          Provider<MirrorService?>.value(value: null),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppSnackBarOverlay(
            child: StatefulBuilder(
              builder: (context, setLocal) {
                return _SmokeShell(
                  page: page,
                  folderKey: folderKey,
                  conversationId: conversation.id,
                  onOpenSettings: () =>
                      setLocal(() => page = _SmokePage.settings),
                  onOpenChat: () => setLocal(() => page = _SmokePage.chat),
                  onToggleBar: () {
                    setLocal(() {});
                    final open = context
                        .read<SettingsProvider>()
                        .desktopWorkspaceBarOpen;
                    unawaited(
                      context
                          .read<SettingsProvider>()
                          .setDesktopWorkspaceBarOpen(!open),
                    );
                  },
                  onOpenPopover: () {
                    final conversationListenable = ValueNotifier<String?>(
                      conversation.id,
                    );
                    showDesktopWorkspacePopover(
                      context,
                      anchorKey: folderKey,
                      conversationListenable: conversationListenable,
                      conversationId: () => conversationListenable.value,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    await _pumpUi(tester);
    expect(tester.takeException(), isNull);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(DesktopSettingsPage)),
    )!;
    expect(find.text(l10n.workspaceDeskMenuWorkspace), findsWidgets);
    expect(find.text(l10n.workspaceDeskMenuSkills), findsWidgets);

    await _tapMenu(tester, l10n.workspaceDeskMenuWorkspace);
    await _pumpUi(tester);
    expect(find.byType(WorkspacesPane), findsOneWidget);
    expect(find.byKey(EnvironmentPane.nativeExplanationKey), findsOneWidget);
    expect(find.text(l10n.workspaceEnvNativeExplanation), findsOneWidget);

    await tester.tap(find.byKey(WorkspacesPane.createKey));
    await _pumpUi(tester);
    await tester.enterText(find.byType(TextField), 'verify-macos');
    final confirm = find.byKey(
      const ValueKey<String>('workspaces-create-confirm'),
    );
    if (confirm.evaluate().isNotEmpty) {
      await tester.tap(confirm);
      await _pumpUi(tester);
    }
    // FLUTTER_TEST makes WorkspacesPane skip persistence; use the test hook.
    final paneState = tester.state<WorkspacesPaneState>(
      find.byType(WorkspacesPane),
    );
    late Workspace created;
    await tester.runAsync(() async {
      created = await paneState.createManaged('verify-macos');
    });
    await tester.pump();
    expect(workspaces.workspaces.any((w) => w.name == 'verify-macos'), isTrue);
    expect(find.text('verify-macos'), findsWidgets);
    late String hostDir;
    await tester.runAsync(() async {
      hostDir = await workspaces.hostRootFor(created);
    });
    expect(Directory(hostDir).existsSync(), isTrue);

    await _tapMenu(tester, l10n.workspaceDeskMenuSkills);
    await _pumpUi(tester);
    expect(find.byType(SkillsPane), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('smoke-open-chat')));
    await _pumpUi(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(WorkspaceSection), findsOneWidget);

    await tester.ensureVisible(find.byKey(folderKey));
    await tester.tap(find.byKey(folderKey));
    await _pumpUi(tester);
    expect(find.byType(WorkspaceSection), findsWidgets);

    final bind = find.byKey(WorkspaceSection.bindKey);
    if (bind.evaluate().isNotEmpty) {
      await tester.ensureVisible(bind.first);
      await tester.tap(bind.first);
      await _pumpUi(tester);
    }
    final pick = find.byKey(WorkspaceSection.pickKey(created.id));
    if (pick.evaluate().isNotEmpty) {
      await tester.tap(pick.first);
      await _pumpUi(tester);
    }
    if (find.byKey(WorkspaceSection.changeKey).evaluate().isEmpty) {
      await tester.runAsync(() async {
        await chat.updateConversationExtras(
          conversation.id,
          (extras) => WorkspaceBinding(
            workspaceId: created.id,
            cwd: created.defaultCwd,
          ).applyTo(extras),
        );
      });
      await _pumpUi(tester);
    }
    expect(find.text('verify-macos'), findsWidgets);
    expect(find.byKey(WorkspaceSection.changeKey), findsWidgets);
    expect(find.byKey(WorkspaceSection.unbindKey), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('smoke-toggle-bar')));
    await tester.runAsync(() async {
      await settings.setDesktopWorkspaceBarOpen(true);
    });
    await _pumpUi(tester);
    expect(find.byType(DesktopWorkspaceBar), findsOneWidget);
    expect(find.byKey(DesktopWorkspaceBar.headerTitleKey), findsOneWidget);
    expect(find.text('verify-macos'), findsWidgets);
    final tabs = tester.widget<SegmentedTabs>(find.byType(SegmentedTabs));
    expect(tabs.tabs, hasLength(3));

    try {
      await binding.takeScreenshot('macos_workspace_bar');
    } catch (_) {
      // Screenshots are optional on the macOS integration runner.
    }

    await tester.runAsync(() async {
      await workspaces.delete(created.id, deleteFiles: true);
    });
    expect(workspaces.byId(created.id), isNull);
    expect(tester.takeException(), isNull);
  });
}

enum _SmokePage { settings, chat }

class _SmokeShell extends StatelessWidget {
  const _SmokeShell({
    required this.page,
    required this.folderKey,
    required this.conversationId,
    required this.onOpenSettings,
    required this.onOpenChat,
    required this.onToggleBar,
    required this.onOpenPopover,
  });

  final _SmokePage page;
  final GlobalKey folderKey;
  final String conversationId;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenChat;
  final VoidCallback onToggleBar;
  final VoidCallback onOpenPopover;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final open = context.watch<SettingsProvider>().desktopWorkspaceBarOpen;
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                TextButton(
                  key: const ValueKey<String>('smoke-open-settings'),
                  onPressed: onOpenSettings,
                  child: Text(l10n.settingsPageTitle),
                ),
                TextButton(
                  key: const ValueKey<String>('smoke-open-chat'),
                  onPressed: onOpenChat,
                  child: const Text('Chat'),
                ),
                IosIconButton(
                  key: const ValueKey<String>('smoke-toggle-bar'),
                  icon: Lucide.panelRight,
                  semanticLabel: l10n.workspaceDeskBarToggle,
                  onTap: onToggleBar,
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: page == _SmokePage.settings
                      ? const DesktopSettingsPage()
                      : Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: WorkspaceSection(
                                  conversationId: conversationId,
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IosIconButton(
                                key: folderKey,
                                icon: Lucide.FolderCode,
                                semanticLabel: l10n.workspaceEntryTooltip,
                                onTap: onOpenPopover,
                              ),
                            ),
                          ],
                        ),
                ),
                if (open)
                  SizedBox(
                    width: DesktopWorkspaceBar.width,
                    child: DesktopWorkspaceBar(conversationId: conversationId),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tapMenu(WidgetTester tester, String label) async {
  final target = find.text(label);
  expect(target, findsWidgets);
  await tester.ensureVisible(target.first);
  await tester.tap(target.first);
}

class _FakeChatService extends ChatService {
  _FakeChatService(this.conversation);

  Conversation? conversation;

  @override
  String? get currentConversationId => conversation?.id;

  @override
  Conversation? getConversation(String id) {
    if (conversation == null) return null;
    return conversation!.id == id ? conversation : null;
  }

  @override
  Future<void> updateConversationExtras(
    String conversationId,
    Map<String, dynamic> Function(Map<String, dynamic> current) update,
  ) async {
    final current = conversation;
    if (current == null || current.id != conversationId) return;
    conversation = current.copyWith(
      extras: update(Map<String, dynamic>.from(current.extras)),
    );
    notifyListeners();
  }

  @override
  Future<Conversation> createDraftConversation({
    String? title,
    String? assistantId,
    bool temporary = false,
  }) async {
    conversation = Conversation(
      title: title ?? 'New Chat',
      assistantId: assistantId,
    );
    notifyListeners();
    return conversation!;
  }
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);

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
