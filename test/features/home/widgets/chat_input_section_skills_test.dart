import 'dart:io';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/skills_binding.dart';
import 'package:Kelivo/core/providers/asr_provider.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/quick_phrase_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/desktop/skills_popover.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/features/home/widgets/chat_input_section.dart';
import 'package:Kelivo/features/workspace/widgets/skills/conversation_skills_sheet.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skills_pane.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';
import '../../workspace/skills/skills_test_fakes.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('desktop_skills_input_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<FakeChatService> pumpComposer(
    WidgetTester tester, {
    double width = 800,
    bool empty = false,
  }) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = createBusinessTestPreferences();
    await preferences.setString(
      'assistants_v1',
      Assistant.encodeList([Assistant(id: 'a1', name: 'Assistant')]),
    );
    await preferences.setString('current_assistant_id_v1', 'a1');
    final assistants = AssistantProvider(preferences: preferences);
    await tester.runAsync(() => assistants.loaded);
    final skills = FakeSkillsService(
      skillsDirectory: tempDir,
      skills: empty
          ? []
          : [
              createTempSkill(
                id: 'alpha',
                name: 'Alpha',
                description: 'First',
                parent: tempDir,
              ),
            ],
    );
    final chat = FakeChatService(
      conversation: Conversation(id: 'c1', title: 'Chat'),
    );
    final controller = TextEditingController();
    final focus = FocusNode();
    final inputBarKey = GlobalKey();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider(preferences)),
          ChangeNotifierProvider.value(value: assistants),
          ChangeNotifierProvider(create: (_) => AsrProvider()),
          ChangeNotifierProvider(
            create: (_) => McpProvider(preferences: preferences),
          ),
          ChangeNotifierProvider(
            create: (_) => QuickPhraseProvider(preferences: preferences),
          ),
          ChangeNotifierProvider<SkillsService>.value(value: skills),
          ChangeNotifierProvider<ChatService>.value(value: chat),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: Builder(
                  builder: (context) => ChatInputSection(
                    inputBarKey: inputBarKey,
                    inputFocus: focus,
                    inputController: controller,
                    mediaController: ChatInputBarController(),
                    isTablet: false,
                    isLoading: false,
                    isToolModel: (_, _) => true,
                    isReasoningModel: (_, _) => false,
                    isReasoningEnabled: (_) => false,
                    conversationId: 'c1',
                    onOpenWorkspace: () {},
                    onOpenSkills: () => showDesktopSkillsPopover(
                      context,
                      anchorKey: inputBarKey,
                      conversationId: 'c1',
                      assistant: assistants.currentAssistant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return chat;
  }

  testWidgets(
    'desktop skills entry edits the current chat and updates its active state',
    (tester) async {
      final chat = await pumpComposer(tester);
      expect(
        tester.widget<ChatInputBar>(find.byType(ChatInputBar)).skillsActive,
        isTrue,
      );
      await tester.tap(find.byTooltip('Skills'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      final popover = find.byKey(desktopSkillsPopoverKey);
      final enteringTop = tester.getTopLeft(popover).dy;
      await tester.pumpAndSettle();
      expect(find.text('Skills for this chat'), findsOneWidget);
      expect(find.byType(FormSheet), findsNothing);
      expect(popover, findsOneWidget);
      expect(tester.getTopLeft(popover).dy, lessThan(enteringTop));
      expect(
        ModalRoute.of(tester.element(popover))!.barrierColor,
        Colors.transparent,
      );
      expect(
        tester.getRect(popover).bottom,
        closeTo(tester.getRect(find.byType(ChatInputBar)).top, 1),
      );
      expect(
        tester.getCenter(find.text('Inherit from assistant')).dy,
        closeTo(tester.getCenter(find.text('Manage skills')).dy, 1),
      );
      expect(
        tester.getRect(find.byKey(ConversationSkillsPanel.inheritKey)).top,
        greaterThan(
          tester
              .getRect(find.byKey(ConversationSkillsPanel.skillKey('alpha')))
              .bottom,
        ),
      );

      await tester.tap(find.byKey(ConversationSkillsPanel.inheritKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ConversationSkillsPanel.skillKey('alpha')));
      await tester.pumpAndSettle();
      expect(chat.lastExtras![SkillsBinding.keyIds], isEmpty);

      tester.view.physicalSize = const Size(700, 500);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(popover).bottom,
        closeTo(tester.getRect(find.byType(ChatInputBar)).top, 1),
      );

      final openTop = tester.getTopLeft(popover).dy;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getTopLeft(popover).dy, greaterThan(openTop));
      await tester.pumpAndSettle();
      expect(find.text('Skills for this chat'), findsNothing);
      expect(
        tester.widget<ChatInputBar>(find.byType(ChatInputBar)).skillsActive,
        isFalse,
      );
      await tester.tap(find.byTooltip('Skills'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(popover, findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );

  testWidgets(
    'narrow desktop composer keeps skills in overflow and opens its library',
    (tester) async {
      await pumpComposer(tester, width: 220, empty: true);
      expect(find.byTooltip('Skills'), findsNothing);
      final context = tester.element(find.byType(ChatInputBar));
      final l10n = AppLocalizations.of(context)!;
      await tester.tap(find.byTooltip(l10n.chatInputBarMoreTooltip).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skills'));
      await tester.pumpAndSettle();
      expect(find.text('Skills for this chat'), findsOneWidget);
      await tester.ensureVisible(find.text('Manage skills'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage skills'));
      await tester.pumpAndSettle();
      expect(find.byKey(SkillsPane.emptyKey), findsOneWidget);
      expect(find.byKey(desktopSkillsPopoverKey), findsNothing);
      expect(find.byType(FormSheet), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(SkillsPane.emptyKey), findsNothing);
      expect(find.byKey(desktopSkillsPopoverKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'mobile composer keeps the existing skills entry in the more panel',
    (tester) async {
      await pumpComposer(tester);
      expect(find.byTooltip('Skills'), findsNothing);
      expect(
        tester.widget<ChatInputBar>(find.byType(ChatInputBar)).onOpenSkills,
        isNull,
      );
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}
