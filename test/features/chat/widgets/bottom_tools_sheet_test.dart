import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/conversation_prompt_settings.dart';
import 'package:Kelivo/core/models/instruction_injection.dart';
import 'package:Kelivo/core/models/skills_binding.dart';
import 'package:Kelivo/core/models/world_book.dart';
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
import 'package:Kelivo/features/chat/widgets/tools_sheet_row.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/features/workspace/pages/skills_page.dart';
import 'package:Kelivo/features/workspace/widgets/skills/conversation_skills_sheet.dart';
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

  testWidgets('tapping session skills stacks the picker on the more sheet', (
    tester,
  ) async {
    final l10n = await pumpSheet(
      tester,
      conversation: Conversation(id: 'c1', title: 'Chat'),
    );

    await tester.tap(find.byKey(sessionSkillsKey));
    await tester.pumpAndSettle();

    expect(find.byType(BottomToolsSheet), findsOneWidget);
    expect(find.byType(ConversationSkillsPanel), findsOneWidget);
    expect(find.text(l10n.skillsSessionTitle), findsOneWidget);
  });

  testWidgets('long-pressing session skills opens the skills library', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.longPress(find.byKey(sessionSkillsKey));
    await tester.pumpAndSettle();

    expect(find.byType(SkillsPage), findsOneWidget);
  });

  Future<String> seedSelections(WidgetTester tester) async {
    return (await tester.runAsync(() async {
      await worldBooks.initialize();
      await worldBooks.addBook(const WorldBook(id: 'book1', name: 'Book 1'));
      await worldBooks.addBook(const WorldBook(id: 'book2', name: 'Book 2'));
      await worldBooks.setActiveBookIds(['book1'], assistantId: assistantId);
      await injections.initialize();
      await injections.clear();
      await injections.addMany(const [
        InstructionInjection(id: 'i1', title: 'First', prompt: 'First'),
        InstructionInjection(id: 'i2', title: 'Second', prompt: 'Second'),
      ]);
      await injections.setActiveIds(['i1'], assistantId: assistantId);
      final skill = await skills.importFromText('''
---
name: menu-count-test
description: Test skill selection counts.
---
Use for the menu test.
''');
      await skills.setEnabled(skill.record.id, true);
      await assistants.updateAssistant(
        assistants.getById(assistantId)!.copyWith(skillIds: [skill.record.id]),
      );
      return skill.record.id;
    }))!;
  }

  void expectTrailing(WidgetTester tester, String label, String? count) {
    final row = find.byWidgetPredicate(
      (widget) => widget is ToolsSheetRow && widget.label == label,
    );
    expect(row, findsOneWidget);
    final trailing = tester.widget<ToolsSheetRow>(row).trailing;
    if (count == null) {
      expect(trailing, isA<Icon>());
      expect((trailing! as Icon).icon, Lucide.ChevronRight);
    } else {
      expect(trailing, isA<Text>());
      expect((trailing! as Text).data, count);
      final number = find.descendant(of: row, matching: find.text(count));
      expect(
        tester.getRect(number).right,
        closeTo(tester.getRect(row).right - 12, 1),
      );
    }
  }

  testWidgets(
    'shows active counts in place of chevrons and restores them when cleared',
    (tester) async {
      await seedSelections(tester);
      final l10n = await pumpSheet(tester);
      await tester.pumpAndSettle();
      expectTrailing(
        tester,
        l10n.workspaceEntrySessionSkills,
        '1/${skills.skills.length}',
      );
      expectTrailing(tester, l10n.instructionInjectionTitle, '1/2');
      expectTrailing(tester, l10n.worldBookTitle, '1/2');

      await tester.runAsync(() async {
        await assistants.updateAssistant(
          assistants.getById(assistantId)!.copyWith(skillIds: []),
        );
        await injections.setActiveIds([], assistantId: assistantId);
        await worldBooks.setActiveBookIds([], assistantId: assistantId);
      });
      await tester.pumpAndSettle();
      expectTrailing(tester, l10n.workspaceEntrySessionSkills, null);
      expectTrailing(tester, l10n.instructionInjectionTitle, null);
      expectTrailing(tester, l10n.worldBookTitle, null);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'counts the conversation selections instead of the assistant defaults',
    (tester) async {
      await seedSelections(tester);
      await tester.runAsync(
        () => assistants.updateAssistant(
          assistants
              .getById(assistantId)!
              .copyWith(allowConversationPromptInjection: true),
        ),
      );
      final l10n = await pumpSheet(
        tester,
        conversation: Conversation(
          id: 'scoped',
          title: 'Chat',
          assistantId: assistantId,
          extras: {
            SkillsBinding.keyIds: <String>[],
            ConversationPromptSettings.instructionIdsKey: ['i1', 'i2'],
            ConversationPromptSettings.worldBookIdsKey: ['book2'],
          },
        ),
      );
      await tester.pumpAndSettle();
      expectTrailing(tester, l10n.workspaceEntrySessionSkills, null);
      expectTrailing(tester, l10n.instructionInjectionTitle, '2/2');
      expectTrailing(tester, l10n.worldBookTitle, '1/2');
      expect(tester.takeException(), isNull);
    },
  );
}
