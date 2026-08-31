import "../../../support/business_test_harness.dart";

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

const String _content = 'first paragraph\n\nsecond paragraph';

Future<int> _bubbleCount(WidgetTester tester, {required bool split}) async {
  final harness = await createBusinessTestHarness(
    initial: {
      'display_chat_message_background_style_v1': 'solid',
      if (split) 'display_assistant_bubble_split_paragraphs_v1': true,
    },
  );
  final settings = SettingsProvider(harness.preferences);
  await settings.loaded;
  final message = ChatMessage(
    role: 'assistant',
    content: _content,
    conversationId: 'conversation-split-paragraphs',
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider(
          create: (_) =>
              TtsProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider<ToolApprovalService>.value(
          value: ToolApprovalService(),
        ),
        ChangeNotifierProvider<AskUserInteractionService>.value(
          value: AskUserInteractionService(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatMessageWidget(message: message, showModelIcon: false),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return find.byType(SelectionArea).evaluate().length;
}

void main() {
  testWidgets('option off keeps the whole reply in one bubble', (tester) async {
    expect(await _bubbleCount(tester, split: false), 1);
  });

  testWidgets('option on renders one bubble per paragraph', (tester) async {
    expect(await _bubbleCount(tester, split: true), 2);
  });
}
