import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/workspace/pages/environment_page.dart';
import 'package:Kelivo/features/workspace/pages/workspace_files_desktop_layout.dart';
import 'package:Kelivo/features/workspace/pages/workspace_files_page.dart';
import 'package:Kelivo/features/workspace/pages/workspace_settings_page.dart';
import 'package:Kelivo/features/workspace/pages/workspaces_page.dart';
import 'package:Kelivo/features/workspace/terminal/terminal_page.dart';
import 'package:Kelivo/features/workspace/terminal/terminal_session_manager.dart';
import 'package:Kelivo/features/workspace/widgets/desktop_workspaces_view.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/features/workspace/widgets/workspace_section.dart';
import 'package:Kelivo/features/workspace/workspace_navigation.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/task_progress_dialog.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';
import 'environment/environment_test_fakes.dart';
import 'terminal/fake_workspace_runtime.dart';

class _FolderPicker extends FilePicker {
  _FolderPicker(this.path);

  final String path;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async => path;
}

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationCachePath() async => '$root/cache';
  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

class _Chat extends ChatService {
  _Chat(this.conversation);
  final Conversation conversation;

  @override
  String? get currentConversationId => conversation.id;
  @override
  Conversation? getConversation(String id) =>
      id == conversation.id ? conversation : null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform previousPaths;
  late AppDatabase database;
  late WorkspaceProvider workspaces;
  late Workspace workspace;
  late EnvironmentProvider env;
  late FakeEnvironmentManager environmentManager;
  late FakeWorkspaceRuntime runtime;
  late WorkspaceRuntimeProvider runtimeProvider;
  late TerminalSessionManager sessions;
  late _Chat chat;

  const haptics = MethodChannel('haptic_feedback');
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(haptics, (_) async => true);
    root = Directory.systemTemp.createTempSync('kelivo_tablet_workspace_');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1;').getSingle();
    workspaces = WorkspaceProvider(store: ExtensionEntityStore(database));
    await workspaces.loaded;
    workspace = await workspaces.create(name: 'Tablet workspace');
    env = EnvironmentProvider(preferences: createBusinessTestPreferences());
    await env.loaded;
    environmentManager = FakeEnvironmentManager(env);
    runtime = FakeWorkspaceRuntime();
    runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
    sessions = TerminalSessionManager(setWakelock: (_) async {});
    chat = _Chat(
      Conversation(
        title: 'Tablet chat',
        extras: WorkspaceBinding(workspaceId: workspace.id).applyTo({}),
      ),
    );
    EnvironmentPane.debugDiskUsage = () async => 0;
    WorkspaceNavigation.onOpenEnvironmentPage = openEnvironmentPage;
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(haptics, null);
    WorkspaceNavigation.onOpenEnvironmentPage = null;
    EnvironmentPane.debugDiskUsage = null;
    await sessions.closeAll();
    sessions.dispose();
    workspaces.dispose();
    env.dispose();
    runtimeProvider.dispose();
    chat.dispose();
    await database.close();
    PathProviderPlatform.instance = previousPaths;
    root.deleteSync(recursive: true);
  });

  Widget harness(Widget page) => MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
      ChangeNotifierProvider<EnvironmentProvider>.value(value: env),
      ChangeNotifierProvider<WorkspaceRuntimeProvider>.value(
        value: runtimeProvider,
      ),
      ChangeNotifierProvider<TerminalSessionManager>.value(value: sessions),
      ChangeNotifierProvider<ChatService>.value(value: chat),
      Provider<EnvironmentManager?>.value(value: environmentManager),
    ],
    child: MaterialApp(
      theme: buildLightTheme(null),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: page,
    ),
  );

  void size(WidgetTester tester, Size value) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = value;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> flushIo(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 100 && !ready(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    expect(ready(), isTrue);
  }

  Future<void> confirmCreation(WidgetTester tester) async {
    final confirm = find
        .descendant(
          of: find.byKey(const ValueKey('workspaces-create-confirm')),
          matching: find.byType(GestureDetector),
        )
        .last;
    await tester.tap(confirm);
    await tester.pump();
  }

  final mobilePlatforms = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.android,
  });

  testWidgets('rotating the settings hub preserves sandbox installation', (
    tester,
  ) async {
    runtime.ready = false;
    environmentManager.installResult = const EnvironmentState(
      phase: EnvironmentPhase.ready,
    );
    size(tester, const Size(1024, 1366));
    await tester.pumpWidget(harness(const WorkspaceSettingsPage()));
    await flushIo(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(WorkspaceSettingsPage)),
    )!;
    expect(find.text(l10n.workspaceEnvTitle), findsOneWidget);
    expect(find.byType(DesktopWorkspacesView), findsNothing);

    tester.view.physicalSize = const Size(1366, 1024);
    await flushIo(tester);
    expect(find.byType(DesktopWorkspacesView), findsOneWidget);
    expect(find.text(l10n.workspaceEnvTitle), findsOneWidget);
    expect(find.text(l10n.workspaceDesktopHostHint), findsNothing);
    await tester.tap(find.byType(IosNavRow).first);
    await flushIo(tester);
    expect(find.byType(EnvironmentPane), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(EnvironmentPane.nativeExplanationKey), findsNothing);
    await tester.tap(find.byKey(EnvironmentPane.installKey));
    await flushIo(tester);
    expect(environmentManager.installCalls, 1);
    expect(env.state.phase, EnvironmentPhase.ready);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: mobilePlatforms);

  testWidgets('workspace creation survives rotation with the form open', (
    tester,
  ) async {
    size(tester, const Size(1366, 1024));
    await tester.pumpWidget(harness(const WorkspaceSettingsPage()));
    await flushIo(tester);
    final originalPane = tester.state<WorkspacesPaneState>(
      find.byType(WorkspacesPane),
    );
    await tester.tap(find.byKey(WorkspacesPane.createKey));
    await flushIo(tester);
    await tester.enterText(
      find.byType(TextField).last,
      'Created after rotation',
    );

    tester.view.physicalSize = const Size(1024, 1366);
    await flushIo(tester);
    expect(originalPane.mounted, isFalse);
    await confirmCreation(tester);
    await waitFor(tester, () => workspaces.workspaces.length == 2);
    expect(
      workspaces.workspaces.any((w) => w.name == 'Created after rotation'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: mobilePlatforms);

  testWidgets('workspace import closes its progress dialog after rotation', (
    tester,
  ) async {
    final source = Directory('${root.path}/source')..createSync();
    final original = File('${source.path}/note.txt')
      ..writeAsStringSync('source');
    FilePicker.platform = _FolderPicker(source.path);
    size(tester, const Size(1366, 1024));
    await tester.pumpWidget(harness(const WorkspaceSettingsPage()));
    await flushIo(tester);
    final originalPane = tester.state<WorkspacesPaneState>(
      find.byType(WorkspacesPane),
    );
    final l10n = AppLocalizations.of(originalPane.context)!;
    await tester.tap(find.byKey(WorkspacesPane.createKey));
    await flushIo(tester);
    await tester.enterText(
      find.byType(TextField).last,
      'Imported while rotating',
    );
    await tester.tap(find.text(l10n.workspaceMgmtImportFromFolder));
    await tester.pump();
    await confirmCreation(tester);
    await waitFor(tester, () {
      final cards = tester.widgetList<TaskProgressDialogCard>(
        find.byType(TaskProgressDialogCard),
      );
      return cards.any((card) => card.outcome == TaskProgressOutcome.success);
    });

    tester.view.physicalSize = const Size(1024, 1366);
    await tester.pump();
    expect(originalPane.mounted, isFalse);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TaskProgressDialogCard), findsNothing);
    final imported = workspaces.workspaces.singleWhere(
      (w) => w.name == 'Imported while rotating',
    );
    final destination = await tester.runAsync(
      () => workspaces.hostRootFor(imported),
    );
    expect(imported.kind, WorkspaceKind.managed);
    expect(File('$destination/note.txt').readAsStringSync(), 'source');
    expect(original.readAsStringSync(), 'source');
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: mobilePlatforms);

  testWidgets('wide chat workspace keeps the environment and PTY actions', (
    tester,
  ) async {
    size(tester, const Size(1366, 1024));
    await tester.pumpWidget(
      harness(
        Scaffold(body: WorkspaceSection(conversationId: chat.conversation.id)),
      ),
    );
    await tester.pump();
    expect(find.byKey(WorkspaceSection.environmentKey), findsOneWidget);
    expect(find.byKey(WorkspaceSection.terminalKey), findsOneWidget);
    expect(find.byKey(WorkspaceSection.revealKey), findsNothing);
    await tester.tap(find.byKey(WorkspaceSection.environmentKey));
    await tester.pump();
    await flushIo(tester);
    expect(find.byType(EnvironmentPane), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: mobilePlatforms);

  testWidgets('wide workspace files open an in-app terminal session', (
    tester,
  ) async {
    size(tester, const Size(1366, 1024));
    await tester.pumpWidget(
      harness(WorkspaceFilesPage(workspaceId: workspace.id)),
    );
    await flushIo(tester);
    expect(find.byType(DesktopWorkspaceFiles), findsOneWidget);
    await tester.runAsync(
      tester.state<FileBrowserState>(find.byType(FileBrowser)).refreshEntries,
    );
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(WorkspaceFilesPage)),
    )!;
    expect(find.text(l10n.workspaceDeskReveal), findsNothing);
    expect(find.text(l10n.workspaceDeskOpenSystemTerminal), findsNothing);
    await tester.tap(find.text(l10n.workspaceEntryTerminal));
    for (var i = 0; i < 80 && sessions.sessions.isEmpty; i++) {
      await flushIo(tester);
    }
    await flushIo(tester);
    expect(find.byType(TerminalPage), findsOneWidget);
    expect(sessions.sessions, hasLength(1));
    expect(runtime.lastPty, isNotNull);
    expect(runtime.lastCwd, '/workspace');
    expect(runtime.lastSystemDir, isNull);
    expect(sessions.sessions.single.workspaceId, workspace.id);

    tester.view.physicalSize = const Size(1024, 1366);
    await tester.pump();
    expect(find.byType(TerminalPage), findsOneWidget);
    expect(sessions.sessions, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: mobilePlatforms);
}
