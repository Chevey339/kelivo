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

Future<SettingsProvider> _settings({required bool fitContent}) async {
  final harness = await createBusinessTestHarness(
    initial: {
      'display_chat_message_background_style_v1': 'solid',
      if (fitContent) 'display_assistant_bubble_fit_content_v1': true,
    },
  );
  final settings = SettingsProvider(harness.preferences);
  await settings.loaded;
  return settings;
}

Future<double> _bubbleWidth(
  WidgetTester tester, {
  required bool fitContent,
  bool waiting = false,
}) async {
  final settings = await _settings(fitContent: fitContent);
  final message = ChatMessage(
    role: 'assistant',
    content: waiting ? '' : 'OK',
    conversationId: 'conversation-fit-content',
    isStreaming: waiting,
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
  if (waiting) {
    await tester.pump();
    return tester
        .getSize(
          find
              .ancestor(
                of: find.byType(LoadingIndicator),
                matching: find.byType(DecoratedBox),
              )
              .first,
        )
        .width;
  }
  await tester.pumpAndSettle();
  return tester
      .getSize(find.byKey(ValueKey('assistant_${message.id}')))
      .width;
}

void main() {
  testWidgets('fit-content option shrinks the assistant bubble to its text', (
    tester,
  ) async {
    final spanning = await _bubbleWidth(tester, fitContent: false);
    final hugging = await _bubbleWidth(tester, fitContent: true);
    expect(hugging, lessThan(spanning));
  });

  testWidgets('waiting bubble hugs the indicator too', (tester) async {
    final spanning = await _bubbleWidth(
      tester,
      fitContent: false,
      waiting: true,
    );
    final hugging = await _bubbleWidth(
      tester,
      fitContent: true,
      waiting: true,
    );
    expect(hugging, lessThan(spanning));
  });
}
