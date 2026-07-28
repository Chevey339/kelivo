import "../../../support/business_test_harness.dart";
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/chat/utils/thinking_tag_parser.dart';
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

  testWidgets(
    'ChatMessageWidget memoizes inline think parsing across rebuilds',
    (tester) async {
      ThinkingTagParser.debugParseCount = 0;
      addTearDown(() => ThinkingTagParser.debugParseCount = 0);

      var content = '<think>cached reasoning</think>visible think answer';
      late StateSetter rebuild;

      await tester.pumpWidget(
        _buildHarness(
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return ChatMessageWidget(
                message: ChatMessage(
                  id: 'think-memo',
                  role: 'assistant',
                  content: content,
                  conversationId: 'conversation-1',
                ),
                showModelIcon: false,
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('visible think answer'), findsOneWidget);
      expect(find.textContaining('<think>'), findsNothing);

      // Reset after the initial builds; identical rebuilds must not reparse.
      ThinkingTagParser.debugParseCount = 0;

      rebuild(() {});
      await tester.pump();
      expect(ThinkingTagParser.debugParseCount, 0);

      rebuild(
        () => content = '<think>new reasoning</think>updated think answer',
      );
      await tester.pump();
      expect(ThinkingTagParser.debugParseCount, greaterThan(0));
      expect(find.textContaining('updated think answer'), findsOneWidget);

      // The memoized result must match a fresh parse of the same source.
      final fresh = ThinkingTagParser.parseLegacyInlineBlocks(content);
      expect(find.textContaining(fresh.visibleContent), findsOneWidget);
    },
  );
}
