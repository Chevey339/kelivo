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

  testWidgets('height estimate includes collapsed inline tool cards', (
    tester,
  ) async {
    final tools = <ToolUIPart>[
      for (var i = 0; i < 12; i++)
        ToolUIPart(
          id: 'tool-$i',
          toolName: 'read_file',
          arguments: {'path': 'lib/foo_$i.dart'},
          content: 'tool result $i',
        ),
    ];
    final message = ChatMessage(
      id: 'tools-only',
      role: 'assistant',
      content: '',
      conversationId: 'conversation-1',
    );

    final empty = await _estimateExtent(tester, message: message);
    final withTools = await _estimateExtent(
      tester,
      message: message,
      toolParts: {'tools-only': tools},
    );
    final hiddenTools = await _estimateExtent(
      tester,
      message: message,
      toolParts: {'tools-only': tools},
      showToolCards: false,
    );
    final withSummary = await _estimateExtent(
      tester,
      message: message,
      toolParts: {
        'tools-only': [
          ToolUIPart(
            id: 'search-1',
            toolName: 'search_web',
            arguments: {'query': 'kelivo'},
            content: List.filled(8, 'summary line that wraps a bit').join('\n'),
          ),
        ],
      },
      showToolResultSummary: true,
    );
    final headerOnly = await _estimateExtent(
      tester,
      message: message,
      toolParts: {
        'tools-only': [
          ToolUIPart(
            id: 'search-1',
            toolName: 'search_web',
            arguments: {'query': 'kelivo'},
            content: List.filled(8, 'summary line that wraps a bit').join('\n'),
          ),
        ],
      },
    );

    expect(empty, 96);
    expect(withTools, closeTo(96 + 12 * 44.0, 0.1));
    expect(hiddenTools, 96);
    expect(withSummary, greaterThan(headerOnly));
  });

  testWidgets('height estimate collapses 30 tools to last 2 plus expand row', (
    tester,
  ) async {
    final tools = <ToolUIPart>[
      for (var i = 0; i < 30; i++)
        ToolUIPart(
          id: 'tool-$i',
          toolName: 'read_file',
          arguments: {'path': 'lib/foo_$i.dart'},
          content: 'ok',
        ),
    ];
    final message = ChatMessage(
      id: 'tools-collapse',
      role: 'assistant',
      content: '',
      conversationId: 'conversation-1',
    );

    final collapsed = await _estimateExtent(
      tester,
      message: message,
      toolParts: {'tools-collapse': tools},
      collapseThinkingSteps: true,
    );
    final expanded = await _estimateExtent(
      tester,
      message: message,
      toolParts: {'tools-collapse': tools},
    );

    expect(collapsed, closeTo(96 + 36 + 2 * 44.0, 0.1));
    expect(expanded, closeTo(96 + 30 * 44.0, 0.1));
    expect(collapsed, lessThan(expanded * 0.25));
  });

  testWidgets('builtin_search-only tools add no timeline height', (
    tester,
  ) async {
    final message = ChatMessage(
      id: 'builtin-only',
      role: 'assistant',
      content: '',
      conversationId: 'conversation-1',
    );
    final empty = await _estimateExtent(tester, message: message);
    final builtin = await _estimateExtent(
      tester,
      message: message,
      toolParts: {
        'builtin-only': const [
          ToolUIPart(
            id: 'builtin_search',
            toolName: 'builtin_search',
            arguments: {},
            content: 'results',
          ),
        ],
      },
    );
    expect(builtin, empty);
    expect(builtin - empty, 0);
  });

  testWidgets('tool image thumbnails add at least 120px', (tester) async {
    final message = ChatMessage(
      id: 'tool-images',
      role: 'assistant',
      content: '',
      conversationId: 'conversation-1',
    );
    final headerOnly = await _estimateExtent(
      tester,
      message: message,
      toolParts: {
        'tool-images': const [
          ToolUIPart(
            id: 'img-1',
            toolName: 'read_file',
            arguments: {},
            content: 'no image here',
          ),
        ],
      },
    );
    final withImages = await _estimateExtent(
      tester,
      message: message,
      toolParts: {
        'tool-images': const [
          ToolUIPart(
            id: 'img-1',
            toolName: 'read_file',
            arguments: {},
            content: 'caption ![shot](https://example.com/a.png)',
          ),
        ],
      },
    );
    final hiddenImages = await _estimateExtent(
      tester,
      message: message,
      hideToolResultImages: true,
      toolParts: {
        'tool-images': const [
          ToolUIPart(
            id: 'img-1',
            toolName: 'read_file',
            arguments: {},
            content: 'caption ![shot](https://example.com/a.png)',
          ),
        ],
      },
    );

    expect(withImages, greaterThanOrEqualTo(headerOnly + 120));
    expect(hiddenImages, headerOnly);
  });

  testWidgets(
    'ask-user, TTS, and Screen Time extras count when summary is off',
    (tester) async {
      final message = ChatMessage(
        id: 'special-tools',
        role: 'assistant',
        content: '',
        conversationId: 'conversation-1',
      );
      final header = await _estimateExtent(
        tester,
        message: message,
        toolParts: {
          'special-tools': const [
            ToolUIPart(
              id: 'plain',
              toolName: 'read_file',
              arguments: {},
              content: 'plain',
            ),
          ],
        },
      );
      final askUser = await _estimateExtent(
        tester,
        message: message,
        toolParts: {
          'special-tools': [
            ToolUIPart(
              id: 'ask',
              toolName: LocalToolNames.askUser,
              arguments: {
                'questions': [
                  {
                    'id': 'scope',
                    'question': 'Choose scope?',
                    'type': 'single',
                    'options': ['Minimal', 'Complete', 'Custom'],
                  },
                ],
              },
            ),
          ],
        },
      );
      final tts = await _estimateExtent(
        tester,
        message: message,
        toolParts: {
          'special-tools': const [
            ToolUIPart(
              id: 'tts',
              toolName: LocalToolNames.textToSpeech,
              arguments: {'text': 'Hello from the assistant'},
            ),
          ],
        },
      );
      final screenTime = await _estimateExtent(
        tester,
        message: message,
        toolParts: {
          'special-tools': [
            ToolUIPart(
              id: 'st',
              toolName: LocalToolNames.screenTime,
              arguments: const {},
              content: jsonEncode({
                'total_minutes': 40,
                'apps': [
                  {'app_name': 'Maps', 'total_minutes': 25},
                  {'app_name': 'Mail', 'total_minutes': 15},
                ],
              }),
            ),
          ],
        },
      );

      expect(askUser, greaterThan(header + 40));
      expect(tts, greaterThan(header + 20));
      expect(screenTime, greaterThan(header + 16));
    },
  );

  testWidgets('height estimate stays within 20% of laid-out tool cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final tools = <ToolUIPart>[
      for (var i = 0; i < 12; i++)
        ToolUIPart(
          id: 'tool-$i',
          toolName: 'read_file',
          arguments: {'path': 'lib/foo_$i.dart'},
          content: 'tool result $i',
        ),
    ];
    final message = ChatMessage(
      id: 'tools-laid-out',
      role: 'assistant',
      content: '好的，我来看看。',
      conversationId: 'conversation-1',
    );
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;

    await tester.pumpWidget(
      _CardVisibilityHarness(
        settings: settings,
        messages: [message],
        toolParts: {'tools-laid-out': tools},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final list = tester.widget<SuperListView>(find.byType(SuperListView));
    final estimate = list.extentEstimation!(0, 400);
    final measured = tester.getSize(find.byType(ChatMessageWidget)).height;
    final error = (estimate - measured).abs() / measured;

    expect(
      error,
      lessThan(0.20),
      reason: 'estimate=$estimate measured=$measured',
    );
  });

  testWidgets(
    'ask-user / TTS / Screen Time estimate stays within 20% of layout',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final tools = <ToolUIPart>[
        ToolUIPart(
          id: 'ask',
          toolName: LocalToolNames.askUser,
          arguments: {
            'questions': [
              {
                'id': 'scope',
                'question': 'Choose scope?',
                'type': 'single',
                'options': ['Minimal', 'Complete'],
              },
            ],
          },
        ),
        const ToolUIPart(
          id: 'tts',
          toolName: LocalToolNames.textToSpeech,
          arguments: {'text': 'Replay this sentence'},
        ),
        ToolUIPart(
          id: 'st',
          toolName: LocalToolNames.screenTime,
          arguments: const {},
          content: jsonEncode({
            'total_minutes': 12,
            'apps': [
              {'app_name': 'Maps', 'total_minutes': 12},
            ],
          }),
        ),
      ];
      final message = ChatMessage(
        id: 'special-laid-out',
        role: 'assistant',
        content: 'Done.',
        conversationId: 'conversation-1',
      );
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;

      await tester.pumpWidget(
        _CardVisibilityHarness(
          settings: settings,
          messages: [message],
          toolParts: {'special-laid-out': tools},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final list = tester.widget<SuperListView>(find.byType(SuperListView));
      final estimate = list.extentEstimation!(0, 400);
      final measured = tester.getSize(find.byType(ChatMessageWidget)).height;
      final error = (estimate - measured).abs() / measured;
      expect(
        error,
        lessThan(0.20),
        reason: 'estimate=$estimate measured=$measured',
      );
    },
  );

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
  bool showToolResultSummary = false,
  bool hideToolResultImages = false,
  bool collapseThinkingSteps = false,
  Map<String, List<ToolUIPart>> toolParts = const {},
}) async {
  final settings = SettingsProvider(createBusinessTestPreferences());
  await settings.loaded;
  await tester.pumpWidget(
    _CardVisibilityHarness(
      settings: settings,
      messages: [message],
      showThinkingCards: showThinkingCards,
      showToolCards: showToolCards,
      showToolResultSummary: showToolResultSummary,
      hideToolResultImages: hideToolResultImages,
      collapseThinkingSteps: collapseThinkingSteps,
      toolParts: toolParts,
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
    this.showToolResultSummary = false,
    this.hideToolResultImages = false,
    this.collapseThinkingSteps = false,
    this.toolParts = const {},
  });

  final SettingsProvider settings;
  final List<ChatMessage> messages;
  final bool showThinkingCards;
  final bool showToolCards;
  final bool showToolResultSummary;
  final bool hideToolResultImages;
  final bool collapseThinkingSteps;
  final Map<String, List<ToolUIPart>> toolParts;

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
            toolParts: widget.toolParts,
            translations: const {},
            selecting: false,
            selectedItems: const {},
            dividerPadding: EdgeInsets.zero,
            isProcessingFiles: isProcessingFiles,
            showThinkingCards: widget.showThinkingCards,
            showToolCards: widget.showToolCards,
            showToolResultSummary: widget.showToolResultSummary,
            hideToolResultImages: widget.hideToolResultImages,
            collapseThinkingSteps: widget.collapseThinkingSteps,
          ),
        ),
      ),
    );
  }
}
