import '../../../support/business_test_harness.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHarness({required Widget child}) {
  SharedPreferences.setMockInitialValues(const {});
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
      ),
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
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('historical contentSplits still render reasoning then text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        child: ChatMessageWidget(
          message: ChatMessage(
            id: 'legacy-splits',
            role: 'assistant',
            content: 'hello',
            conversationId: 'c1',
          ),
          showModelIcon: false,
          reasoningSegments: const [
            ReasoningSegment(text: 'plan', expanded: true, loading: false),
          ],
          contentSplitOffsets: const [0],
          reasoningCountAtSplit: const [1],
          toolCountAtSplit: const [0],
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('plan'), findsWidgets);
    expect(find.textContaining('hello'), findsWidgets);
  });

  testWidgets('structured parts render reasoning, text, and tool in order', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        child: ChatMessageWidget(
          message: ChatMessage(
            id: 'structured-parts',
            role: 'assistant',
            conversationId: 'c1',
            parts: const [
              ReasoningPart('plan'),
              TextPart('hello'),
              ToolCallPart(
                '{"id":"c1","name":"lookup","arguments":{},"content":"ok"}',
              ),
              TextPart('done'),
            ],
          ),
          showModelIcon: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('plan'), findsWidgets);
    expect(find.textContaining('hello'), findsWidgets);
    expect(find.textContaining('lookup'), findsWidgets);
    expect(find.textContaining('done'), findsWidgets);
  });
}
