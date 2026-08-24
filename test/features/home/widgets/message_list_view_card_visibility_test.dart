import "../../../support/business_test_harness.dart";

import 'dart:convert';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream_ctrl;
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('height estimate strips hidden <think> content', (tester) async {
    final thinking = List.filled(120, 'long hidden reasoning line').join('\n');
    final tagged = '<think>$thinking</think>Short answer.';

    final hidden = await _estimateExtent(
      tester,
      message: ChatMessage(
        id: 'think-hidden',
        role: 'assistant',
        content: tagged,
        conversationId: 'conversation-1',
      ),
      showThinkingCards: false,
    );
    final shown = await _estimateExtent(
      tester,
      message: ChatMessage(
        id: 'think-shown',
        role: 'assistant',
        content: tagged,
        conversationId: 'conversation-1',
      ),
      showThinkingCards: true,
    );
    final rawThinking = await _estimateExtent(
      tester,
      message: ChatMessage(
        id: 'think-raw',
        role: 'assistant',
        content: thinking,
        conversationId: 'conversation-1',
      ),
      showThinkingCards: false,
    );

    expect(hidden, lessThan(shown));
    expect(hidden, lessThan(rawThinking * 0.25));
    expect(hidden, lessThan(400));
  });

  testWidgets('height estimate excludes hidden standalone tool messages', (
    tester,
  ) async {
    final toolContent = jsonEncode({
      'tool': 'search_web',
      'arguments': <String, dynamic>{},
      'result': List.filled(80, 'huge standalone tool result line').join('\n'),
    });
    final askUserContent = jsonEncode({
      'tool': LocalToolNames.askUser,
      'arguments': {
        'questions': [
          {
            'id': 'scope',
            'question': 'Choose scope?',
            'type': 'single',
            'options': ['Minimal', 'Complete'],
          },
        ],
      },
      'result': '',
    });

    final hidden = await _estimateExtent(
      tester,
      message: ChatMessage(
        id: 'tool-hidden',
        role: 'tool',
        content: toolContent,
        conversationId: 'conversation-1',
      ),
      showToolCards: false,
    );
    final shown = await _estimateExtent(
      tester,
      message: ChatMessage(
        id: 'tool-shown',
        role: 'tool',
        content: toolContent,
        conversationId: 'conversation-1',
      ),
      showToolCards: true,
    );
    final askUserHidden = await _estimateExtent(
      tester,
      message: ChatMessage(
        id: 'tool-ask-user',
        role: 'tool',
        content: askUserContent,
        conversationId: 'conversation-1',
      ),
      showToolCards: false,
    );

    expect(hidden, 0);
    expect(shown, greaterThan(400));
    expect(askUserHidden, greaterThan(0));
  });

  testWidgets('ChatMessageWidget receives MessageListView card flags', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    expect(settings.showThinkingCards, isTrue);
    expect(settings.showToolCards, isTrue);

    final message = ChatMessage(
      id: 'flag-message',
      role: 'assistant',
      content: '<think>legacy reasoning</think>Final answer',
      conversationId: 'conversation-1',
    );

    await tester.pumpWidget(
      _CardVisibilityHarness(
        settings: settings,
        messages: [message],
        showThinkingCards: false,
        showToolCards: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final rendered = tester.widget<ChatMessageWidget>(
      find.byType(ChatMessageWidget),
    );
    expect(rendered.showThinkingCards, isFalse);
    expect(rendered.showToolCards, isFalse);
    expect(find.text('Deep Thinking'), findsNothing);
    expect(find.textContaining('legacy reasoning'), findsNothing);
    expect(find.textContaining('Final answer'), findsOneWidget);
  });
}

Future<double> _estimateExtent(
  WidgetTester tester, {
  required ChatMessage message,
  bool showThinkingCards = true,
  bool showToolCards = true,
}) async {
  final settings = SettingsProvider(createBusinessTestPreferences());
  await settings.loaded;
  await tester.pumpWidget(
    _CardVisibilityHarness(
      settings: settings,
      messages: [message],
      showThinkingCards: showThinkingCards,
      showToolCards: showToolCards,
    ),
  );
  await tester.pump();
  final list = tester.widget<SuperListView>(find.byType(SuperListView));
  return list.extentEstimation!(0, 400);
}

class _CardVisibilityHarness extends StatefulWidget {
  const _CardVisibilityHarness({
    required this.settings,
    required this.messages,
    this.showThinkingCards = true,
    this.showToolCards = true,
  });

  final SettingsProvider settings;
  final List<ChatMessage> messages;
  final bool showThinkingCards;
  final bool showToolCards;

  @override
  State<_CardVisibilityHarness> createState() => _CardVisibilityHarnessState();
}

class _CardVisibilityHarnessState extends State<_CardVisibilityHarness> {
  late final ScrollController scrollController;
  late final ListController listController;
  late final ValueNotifier<bool> isProcessingFiles;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    listController = ListController();
    isProcessingFiles = ValueNotifier<bool>(false);
  }

  @override
  void dispose() {
    scrollController.dispose();
    listController.dispose();
    isProcessingFiles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: widget.settings),
        ChangeNotifierProvider(
          create: (_) =>
              AssistantProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              UserProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              TtsProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ChangeNotifierProvider(create: (_) => ToolApprovalService()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageListView(
            scrollController: scrollController,
            listController: listController,
            messages: widget.messages,
            byGroup: const {},
            versionSelections: const {},
            reasoning: const <String, stream_ctrl.ReasoningData>{},
            reasoningSegments:
                const <String, List<stream_ctrl.ReasoningSegmentData>>{},
            contentSplits: const <String, stream_ctrl.ContentSplitData>{},
            toolParts: const {},
            translations: const {},
            selecting: false,
            selectedItems: const {},
            dividerPadding: EdgeInsets.zero,
            isProcessingFiles: isProcessingFiles,
            showThinkingCards: widget.showThinkingCards,
            showToolCards: widget.showToolCards,
          ),
        ),
      ),
    );
  }
}
