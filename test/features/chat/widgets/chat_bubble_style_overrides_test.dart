import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/chat_bubble_style.dart';
import 'package:Kelivo/features/chat/widgets/frosted/frosted_surface.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('frosted overrides apply radius, blur and text color', (
    tester,
  ) async {
    final harness = await createBusinessTestHarness(
      initial: {'display_chat_message_background_style_v1': 'frosted'},
    );
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    await settings.setEnableAssistantMarkdown(false);
    await settings.setChatBubbleStyleOverrides(
      const ChatBubbleStyleOverrides(
        cornerRadius: 4,
        blurSigma: 3,
        textArgbLight: 0xFF224466,
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider(
            create: (_) =>
                TtsProvider(preferences: createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider(create: (_) => ToolApprovalService()),
          ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatMessageWidget(
              message: ChatMessage(
                role: 'assistant',
                content: 'Plain override text',
                conversationId: 'conversation-overrides',
              ),
              showModelIcon: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final surface = tester.widget<FrostedSurface>(find.byType(FrostedSurface));
    expect(surface.style.radius, 4);
    expect(surface.style.blurSigma, 3);
    expect(
      tester.widget<Text>(find.text('Plain override text')).style?.color,
      const Color(0xFF224466),
    );
  });

  testWidgets('plain translation text uses the override color', (tester) async {
    final harness = await createBusinessTestHarness(
      initial: {'display_chat_message_background_style_v1': 'solid'},
    );
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    await settings.setEnableAssistantMarkdown(false);
    await settings.setChatBubbleStyleOverrides(
      const ChatBubbleStyleOverrides(textArgbLight: 0xFF224466),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider(
            create: (_) =>
                TtsProvider(preferences: createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider(create: (_) => ToolApprovalService()),
          ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatMessageWidget(
              message: ChatMessage(
                role: 'assistant',
                content: 'Answer',
                translation: 'Translated answer',
                conversationId: 'conversation-translation-overrides',
              ),
              showModelIcon: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('Translated answer')).style?.color,
      const Color(0xFF224466),
    );
  });

  testWidgets('markdown headings use the override text color', (tester) async {
    final harness = await createBusinessTestHarness(
      initial: {'display_chat_message_background_style_v1': 'solid'},
    );
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    await settings.setChatBubbleStyleOverrides(
      const ChatBubbleStyleOverrides(textArgbLight: 0xFF224466),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider(
            create: (_) =>
                TtsProvider(preferences: createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider(create: (_) => ToolApprovalService()),
          ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatMessageWidget(
              message: ChatMessage(
                role: 'assistant',
                content: '# Custom heading\n\nBody copy.',
                conversationId: 'conversation-heading-overrides',
              ),
              showModelIcon: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final heading = find
        .byType(RichText)
        .evaluate()
        .map((element) => element.renderObject)
        .whereType<RenderParagraph>()
        .firstWhere(
          (paragraph) =>
              paragraph.text.toPlainText().contains('Custom heading'),
        );
    expect(heading.text.style?.color, const Color(0xFF224466));
  });

  testWidgets(
    'user and assistant frosted overrides can differ in radius and text color',
    (tester) async {
      final harness = await createBusinessTestHarness(
        initial: {'display_chat_message_background_style_v1': 'frosted'},
      );
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      await settings.setEnableAssistantMarkdown(false);
      await settings.setEnableUserMarkdown(false);
      await settings.setChatBubbleStyleOverridesForRole(
        isUser: false,
        value: const ChatBubbleStyleOverrides(
          cornerRadius: 4,
          textArgbLight: 0xFF224466,
        ),
      );
      await settings.setChatBubbleStyleOverridesForRole(
        isUser: true,
        value: const ChatBubbleStyleOverrides(
          cornerRadius: 20,
          textArgbLight: 0xFFAA2200,
        ),
      );

      const userId = 'user-role-overrides';
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider(
              create: (_) =>
                  TtsProvider(preferences: createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  UserProvider(preferences: createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider(create: (_) => ToolApprovalService()),
            ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  ChatMessageWidget(
                    message: ChatMessage(
                      id: userId,
                      role: 'user',
                      content: 'User override text',
                      conversationId: 'conversation-role-overrides',
                    ),
                    showUserAvatar: false,
                    showModelIcon: false,
                  ),
                  ChatMessageWidget(
                    message: ChatMessage(
                      role: 'assistant',
                      content: 'Assistant override text',
                      conversationId: 'conversation-role-overrides',
                    ),
                    showModelIcon: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final userSurface = tester.widget<FrostedSurface>(
        find.descendant(
          of: find.byKey(const ValueKey('user-message-text-bubble:$userId')),
          matching: find.byType(FrostedSurface),
        ),
      );
      final assistantSurface = tester.widget<FrostedSurface>(
        find
            .ancestor(
              of: find.text('Assistant override text'),
              matching: find.byType(FrostedSurface),
            )
            .first,
      );

      expect(userSurface.isUser, isTrue);
      expect(assistantSurface.isUser, isFalse);
      expect(userSurface.style.radius, 20);
      expect(assistantSurface.style.radius, 4);
      expect(
        tester.widget<Text>(find.text('User override text')).style?.color,
        const Color(0xFFAA2200),
      );
      expect(
        tester.widget<Text>(find.text('Assistant override text')).style?.color,
        const Color(0xFF224466),
      );
    },
  );
}
