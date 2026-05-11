import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHarness({
  required SettingsProvider settings,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider(create: (_) => TtsProvider()),
      ChangeNotifierProvider(create: (_) => ToolApprovalService()),
      ChangeNotifierProvider<AskUserInteractionService>.value(
        value: AskUserInteractionService(),
      ),
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

  testWidgets('助手流式正文内容变化时富内容选择区域 key 保持稳定', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();

    ChatMessage message(String content) {
      return ChatMessage(
        id: 'assistant-1',
        role: 'assistant',
        content: content,
        conversationId: 'conversation-1',
        isStreaming: true,
      );
    }

    await tester.pumpWidget(
      _buildHarness(
        settings: settings,
        child: ChatMessageWidget(
          message: message('```dart\nfinal value = 1;\n```'),
          showModelIcon: false,
        ),
      ),
    );
    await tester.pump();

    final beforeSelection = tester.widget<SelectionArea>(
      find.byType(SelectionArea).first,
    );
    expect(find.byType(MarkdownWithCodeHighlight), findsOneWidget);

    await tester.pumpWidget(
      _buildHarness(
        settings: settings,
        child: ChatMessageWidget(
          message: message('```dart\nfinal value = 1;\nfinal next = 2;\n```'),
          showModelIcon: false,
        ),
      ),
    );
    await tester.pump();

    final afterSelection = tester.widget<SelectionArea>(
      find.byType(SelectionArea).first,
    );

    expect(afterSelection.key, beforeSelection.key);
  });
}
