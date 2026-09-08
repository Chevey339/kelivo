import '../../../support/business_test_harness.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart';
import 'package:Kelivo/features/home/controllers/streaming_content_notifier.dart';
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

RetryStatus _pendingRetry() => RetryStatus(
  attempt: 2,
  maxRetries: 3,
  retryAt: DateTime.now().add(const Duration(seconds: 5)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an empty streaming bubble shows the retry countdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        child: ChatMessageWidget(
          message: ChatMessage(
            id: 'retry-empty',
            role: 'assistant',
            content: '',
            conversationId: 'c1',
            isStreaming: true,
          ),
          showModelIcon: false,
          retryStatus: _pendingRetry(),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('until retry (2/3)'), findsOneWidget);
  });

  testWidgets('a retry after the first round keeps the countdown visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        child: ChatMessageWidget(
          message: ChatMessage(
            id: 'retry-after-content',
            role: 'assistant',
            content: 'partial answer',
            conversationId: 'c1',
            isStreaming: true,
          ),
          showModelIcon: false,
          retryStatus: _pendingRetry(),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('partial answer'), findsOneWidget);
    expect(find.textContaining('until retry (2/3)'), findsOneWidget);
  });

  testWidgets('a retry between tool rounds keeps the countdown visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        child: ChatMessageWidget(
          message: ChatMessage(
            id: 'retry-between-rounds',
            role: 'assistant',
            content: 'partial answer',
            conversationId: 'c1',
            isStreaming: true,
          ),
          showModelIcon: false,
          reasoningSegments: const [
            ReasoningSegment(text: 'plan', expanded: true, loading: false),
          ],
          contentSplitOffsets: const [0],
          reasoningCountAtSplit: const [1],
          toolCountAtSplit: const [0],
          retryStatus: _pendingRetry(),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('partial answer'), findsOneWidget);
    expect(find.textContaining('until retry (2/3)'), findsOneWidget);
  });

  testWidgets('a tool-only round still shows the retry countdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        child: ChatMessageWidget(
          message: ChatMessage(
            id: 'retry-tool-only',
            role: 'assistant',
            content: '',
            conversationId: 'c1',
            isStreaming: true,
            parts: const [
              ToolCallPart(
                '{"id":"c1","name":"lookup","arguments":{},"content":"ok"}',
              ),
            ],
          ),
          showModelIcon: false,
          retryStatus: _pendingRetry(),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('lookup'), findsWidgets);
    expect(find.textContaining('until retry (2/3)'), findsOneWidget);
  });

  testWidgets('no countdown renders while the stream is healthy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        child: ChatMessageWidget(
          message: ChatMessage(
            id: 'no-retry',
            role: 'assistant',
            content: 'partial answer',
            conversationId: 'c1',
            isStreaming: true,
          ),
          showModelIcon: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('until retry'), findsNothing);
  });
}
