import 'dart:io';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/skills_binding.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/workspace/widgets/skills/conversation_skills_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';
import 'skills_test_fakes.dart';

const _assistantId = 'a1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kelivo_skills_convo_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<AssistantProvider> loadAssistant(
    WidgetTester tester, {
    List<String>? skillIds,
  }) async {
    final harness = await createBusinessTestHarness(
      initial: {
        'assistants_v1': Assistant.encodeList([
          Assistant(id: _assistantId, name: 'A', skillIds: skillIds),
        ]),
      },
    );
    final ap = AssistantProvider(preferences: harness.preferences);
    await tester.runAsync(() => ap.loaded);
    return ap;
  }

  Future<void> pumpPanel(
    WidgetTester tester, {
    required FakeSkillsService skills,
    required FakeChatService chat,
    required AssistantProvider assistants,
    Assistant? assistant,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider.value(value: assistants),
          ChangeNotifierProvider<SkillsService>.value(value: skills),
          ChangeNotifierProvider<ChatService>.value(value: chat),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ConversationSkillsPanel(
              conversationId: 'c1',
              assistant: assistant ?? Assistant(id: _assistantId, name: 'A'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('writes skills.ids through a fake ChatService', (tester) async {
    final enabled = createTempSkill(
      id: 'alpha',
      name: 'Alpha',
      description: 'First',
      parent: tempDir,
    );
    final extra = createTempSkill(
      id: 'beta',
      name: 'Beta',
      description: 'Second',
      parent: tempDir,
    );
    final skills = FakeSkillsService(
      skills: [enabled, extra],
      skillsDirectory: tempDir,
    );
    final chat = FakeChatService(
      conversation: Conversation(id: 'c1', title: 'Chat'),
    );
    final assistants = await loadAssistant(tester);

    await pumpPanel(tester, skills: skills, chat: chat, assistants: assistants);

    expect(
      chat.getConversation('c1')!.extras.containsKey(SkillsBinding.keyIds),
      isFalse,
    );

    await tester.tap(find.byKey(ConversationSkillsPanel.inheritKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(chat.lastExtras, isNotNull);
    expect(chat.lastExtras![SkillsBinding.keyIds], ['alpha', 'beta']);

    await tester.tap(find.byKey(ConversationSkillsPanel.skillKey('beta')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(chat.lastExtras![SkillsBinding.keyIds], ['alpha']);
    expect(assistants.getById(_assistantId)!.skillIds, isNull);
  });

  testWidgets('follow-assistant skill toggle writes assistant.skillIds', (
    tester,
  ) async {
    final enabled = createTempSkill(
      id: 'alpha',
      name: 'Alpha',
      description: 'First',
      parent: tempDir,
    );
    final extra = createTempSkill(
      id: 'beta',
      name: 'Beta',
      description: 'Second',
      parent: tempDir,
    );
    final skills = FakeSkillsService(
      skills: [enabled, extra],
      skillsDirectory: tempDir,
    );
    final chat = FakeChatService(
      conversation: Conversation(id: 'c1', title: 'Chat'),
    );
    final assistants = await loadAssistant(tester);
    expect(assistants.getById(_assistantId)!.skillIds, isNull);

    await pumpPanel(tester, skills: skills, chat: chat, assistants: assistants);

    await tester.tap(find.byKey(ConversationSkillsPanel.skillKey('beta')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(assistants.getById(_assistantId)!.skillIds, ['alpha']);
    expect(
      chat.getConversation('c1')!.extras.containsKey(SkillsBinding.keyIds),
      isFalse,
    );
  });
}
