import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/mermaid_image_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHarness({required Widget child}) {
  SharedPreferences.setMockInitialValues(const {});
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ChangeNotifierProvider(create: (_) => TtsProvider()),
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

String _allRichTextPlainText(WidgetTester tester) {
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .map((widget) => widget.text.toPlainText())
      .join('\n');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'ChatMessageWidget keeps a partial streaming table row in table layout',
    (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageWidget(
            message: ChatMessage(
              id: 'streaming-table',
              role: 'assistant',
              content: '''
| 水果 | 颜色 | 价格 |
| - | - | - |
| 葡萄 🍇''',
              conversationId: 'conversation-1',
              isStreaming: true,
            ),
            showModelIcon: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Table), findsOneWidget);
      expect(find.textContaining('葡萄 🍇'), findsOneWidget);
      expect(_allRichTextPlainText(tester), isNot(contains('| 葡萄 🍇')));
    },
  );

  testWidgets(
    'ChatMessageWidget keeps unfinished streaming Mermaid in the Mermaid block',
    (tester) async {
      addTearDown(MermaidImageCache.clear);
      MermaidImageCache.clear();

      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageWidget(
            message: ChatMessage(
              id: 'streaming-mermaid',
              role: 'assistant',
              content: '''
```mermaid
graph TD
A-->B''',
              conversationId: 'conversation-1',
              isStreaming: true,
            ),
            showModelIcon: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('mermaid'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(_allRichTextPlainText(tester), isNot(contains('graph TD')));
    },
  );
}
