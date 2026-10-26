import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/utils/unicode_sanitizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

Future<SettingsProvider> _settings() async {
  final harness = await createBusinessTestHarness();
  final settings = SettingsProvider(harness.preferences);
  await settings.loaded;
  await settings.setShowToolResultSummary(true);
  addTearDown(settings.dispose);
  return settings;
}

Widget _harness({
  required SettingsProvider settings,
  required Widget child,
  ToolApprovalService? approval,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<SettingsProvider>.value(value: settings),
    ChangeNotifierProvider(
      create: (_) => TtsProvider(preferences: createBusinessTestPreferences()),
    ),
    if (approval == null)
      ChangeNotifierProvider(create: (_) => ToolApprovalService())
    else
      ChangeNotifierProvider<ToolApprovalService>.value(value: approval),
    ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

ChatMessage _message() => ChatMessage(
  id: 'unicode-message',
  role: 'assistant',
  content: '',
  conversationId: 'unicode-conversation',
  isStreaming: true,
);

void _expectSafeText(WidgetTester tester, String expected) {
  expect(find.text(expected), findsOneWidget);
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    expect(UnicodeSanitizer.sanitize(text), text);
  }
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('tool result summaries sanitize cached display text only', (
    tester,
  ) async {
    final settings = await _settings();
    const raw = 'result\uD800 middle\uDC00 😀';
    const storedPayload =
        r'{"id":"unicode-result","name":"get_time_info","arguments":{},"content":"result\uD800 middle\uDC00 😀"}';
    final message = ChatMessage(
      id: 'unicode-message',
      role: 'assistant',
      conversationId: 'unicode-conversation',
      parts: const [ToolCallPart(storedPayload)],
      isStreaming: true,
    );
    const initialPart = ToolUIPart(
      id: 'unicode-result',
      toolName: 'get_time_info',
      arguments: {},
      content: raw,
    );
    final livePart = ValueNotifier(initialPart);
    addTearDown(livePart.dispose);
    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: ValueListenableBuilder<ToolUIPart>(
          valueListenable: livePart,
          builder: (_, part, _) => ChatMessageWidget(
            message: message,
            showModelIcon: false,
            toolParts: [part],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    _expectSafeText(tester, 'result� middle� 😀');
    expect(initialPart.content, raw);
    expect((message.parts.single as ToolCallPart).payloadJson, storedPayload);

    const updatedRaw = 'updated\uDC00 middle\uD800 😀';
    livePart.value = const ToolUIPart(
      id: 'unicode-result',
      toolName: 'get_time_info',
      arguments: {},
      content: updatedRaw,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    _expectSafeText(tester, 'updated� middle� 😀');
    expect(livePart.value.content, updatedRaw);
    expect((message.parts.single as ToolCallPart).payloadJson, storedPayload);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tool argument fallback summaries sanitize display only', (
    tester,
  ) async {
    final settings = await _settings();
    const raw = 'query\uD800 middle\uDC00 😀';
    const part = ToolUIPart(
      id: 'unicode-query',
      toolName: 'get_time_info',
      arguments: {'query': raw},
      loading: true,
    );
    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: ChatMessageWidget(
          message: _message(),
          showModelIcon: false,
          toolParts: const [part],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    _expectSafeText(tester, 'query� middle� 😀');
    expect(part.arguments['query'], raw);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pending tool arguments sanitize approval text only', (
    tester,
  ) async {
    final settings = await _settings();
    final approval = ToolApprovalService();
    addTearDown(approval.dispose);
    const raw = 'approve\uD800 middle\uDC00 😀';
    const arguments = {'query': raw};
    final decision = approval.requestApproval(
      toolCallId: 'unicode-approval',
      toolName: 'get_time_info',
      arguments: arguments,
      conversationId: 'unicode-conversation',
    );
    await tester.pumpWidget(
      _harness(
        settings: settings,
        approval: approval,
        child: ChatMessageWidget(
          message: _message(),
          showModelIcon: false,
          toolParts: const [
            ToolUIPart(
              id: 'unicode-approval',
              toolName: 'get_time_info',
              arguments: arguments,
              loading: true,
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    _expectSafeText(tester, 'query: approve� middle� 😀');
    expect(approval.pendingRequests.single.arguments['query'], raw);
    expect(arguments['query'], raw);
    approval.deny('unicode-approval', conversationId: 'unicode-conversation');
    expect((await decision).approved, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final standalone in [false, true]) {
    testWidgets('speech summary is safe for standalone=$standalone', (
      tester,
    ) async {
      final settings = await _settings();
      const raw = 'speech\uD800 middle\uDC00 😀';
      const payload =
          r'{"tool":"text_to_speech","arguments":{"text":"speech\uD800 middle\uDC00 😀"},"result":"spoken"}';
      const part = ToolUIPart(
        id: 'unicode-speech',
        toolName: 'text_to_speech',
        arguments: {'text': raw},
        content: 'spoken',
      );
      final message = standalone
          ? ChatMessage(
              id: part.id,
              role: 'tool',
              conversationId: 'unicode-conversation',
              content: payload,
            )
          : _message();
      await tester.pumpWidget(
        _harness(
          settings: settings,
          child: ChatMessageWidget(
            message: message,
            showModelIcon: false,
            toolParts: standalone ? null : const [part],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      _expectSafeText(tester, 'speech� middle� 😀');
      expect(part.arguments['text'], raw);
      if (standalone) expect(message.content, payload);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('search tool titles sanitize interpolated query text only', (
    tester,
  ) async {
    final settings = await _settings();
    const raw = 'query\uD800 middle\uDC00 😀';
    const part = ToolUIPart(
      id: 'unicode-search',
      toolName: 'search_web',
      arguments: {'query': raw},
      content: 'Found results',
    );
    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: ChatMessageWidget(
          message: _message(),
          showModelIcon: false,
          toolParts: const [part],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    _expectSafeText(tester, 'Web Search: query� middle� 😀');
    expect(part.arguments['query'], raw);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
