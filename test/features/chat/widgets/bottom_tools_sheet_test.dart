import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/chat/widgets/bottom_tools_sheet.dart';
import 'package:Kelivo/features/workspace/pages/skills_page.dart';
import 'package:Kelivo/features/workspace/widgets/workspace_section.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
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
  Future<Conversation> createDraftConversation({
    String? title,
    String? assistantId,
    bool temporary = false,
  }) async {
    final draft = Conversation(
      title: title ?? 'New Chat',
      assistantId: assistantId,
    );
    conversation = draft;
    notifyListeners();
    return draft;
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
  late AssistantProvider assistants;
  late WorldBookProvider worldBooks;
  late InstructionInjectionProvider injections;
  late SkillsService skills;
  late String assistantId;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('kelivo_bottom_tools_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1;').getSingle();
    workspaces = WorkspaceProvider(store: ExtensionEntityStore(database));
    await workspaces.loaded;
    // Build every preference facade before constructing providers: each call
    // resets the SharedPreferences mock store.
    final settingsPreferences = createBusinessTestPreferences();
    final environmentPreferences = createBusinessTestPreferences();
    final assistantPreferences = createBusinessTestPreferences();
    final worldBookPreferences = createBusinessTestPreferences();
    final injectionPreferences = createBusinessTestPreferences();
    settings = SettingsProvider(settingsPreferences);
    environment = EnvironmentProvider(preferences: environmentPreferences);
    await environment.loaded;
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
    worldBooks = WorldBookProvider(preferences: worldBookPreferences);
    injections = InstructionInjectionProvider(
      preferences: injectionPreferences,
    );
    skills = SkillsService(
      store: ExtensionEntityStore(database),
      skillsDirectory: Directory(p.join(tempDir.path, 'skills'))
        ..createSync(recursive: true),
    );
    await skills.loaded;
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
    Conversation? conversation,
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
          ChangeNotifierProvider<ChatService>.value(
            value: _FakeChatService(conversation),
          ),
          ChangeNotifierProvider<WorkspaceRuntimeProvider>(
            create: (_) => WorkspaceRuntimeProvider(),
          ),
          ChangeNotifierProvider<EnvironmentProvider>.value(value: environment),
          ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
          ChangeNotifierProvider<WorldBookProvider>.value(value: worldBooks),
          ChangeNotifierProvider<InstructionInjectionProvider>.value(
            value: injections,
          ),
          ChangeNotifierProvider<SkillsService>.value(value: skills),
          Provider<EnvironmentManager?>.value(value: null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppSnackBarOverlay(
            child: Scaffold(
              body: BottomToolsSheet(
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

  testWidgets('keeps session skills and drops the workspace block', (
    tester,
  ) async {
    final l10n = await pumpSheet(tester);

    expect(find.byKey(sessionSkillsKey), findsOneWidget);
    expect(find.text(l10n.workspaceEntrySessionSkills), findsOneWidget);
    expect(
      find.byType(WorkspaceSection),
      findsNothing,
      reason: 'workspace rows moved to the composer tools sheet',
    );
    expect(find.text(l10n.instructionInjectionTitle), findsOneWidget);
    expect(find.text(l10n.contextManagement), findsOneWidget);
  });

  testWidgets('long-pressing session skills opens the skills library', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.longPress(find.byKey(sessionSkillsKey));
    await tester.pumpAndSettle();

    expect(find.byType(SkillsPage), findsOneWidget);
  });
}
