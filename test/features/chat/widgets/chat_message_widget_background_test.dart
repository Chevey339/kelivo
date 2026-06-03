import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';

SettingsProvider _createSettings(ChatMessageBackgroundStyle style) {
  final rawStyle = switch (style) {
    ChatMessageBackgroundStyle.frosted => 'frosted',
    ChatMessageBackgroundStyle.solid => 'solid',
    ChatMessageBackgroundStyle.defaultStyle => 'default',
  };
  SharedPreferences.setMockInitialValues({
    'display_chat_message_background_style_v1': rawStyle,
  });
  return SettingsProvider();
}

Widget _buildHarness({
  required SettingsProvider settings,
  required Widget child,
  AskUserInteractionService? askUserService,
  TtsProvider? ttsProvider,
  Locale? locale,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      if (ttsProvider != null)
        ChangeNotifierProvider<TtsProvider>.value(value: ttsProvider)
      else
        ChangeNotifierProvider(create: (_) => TtsProvider()),
      ChangeNotifierProvider(create: (_) => ToolApprovalService()),
      ChangeNotifierProvider<AskUserInteractionService>.value(
        value: askUserService ?? AskUserInteractionService(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

Color _expectedNeutralStrong() =>
    ThemeData.light().colorScheme.onSurface.withValues(alpha: 0.78);

Finder _findNetworkImage(String url) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is NetworkImage &&
        (widget.image as NetworkImage).url == url,
  );
}

class _RecordingTtsProvider extends TtsProvider {
  final spokenTexts = <String>[];

  @override
  bool get isAvailable => true;

  @override
  Future<void> speak(String text, {bool flush = true}) async {
    spokenTexts.add(text);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatMessageWidget card background style', () {
    testWidgets('search citations render source capsule with favicon stack', (
      tester,
    ) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.defaultStyle);

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          locale: const Locale('zh'),
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'assistant',
              content: 'Answer with search citations.',
              conversationId: 'conversation-search-capsule',
            ),
            showModelIcon: false,
            toolParts: const [
              ToolUIPart(
                id: 'builtin-search-result',
                toolName: 'builtin_search',
                arguments: {},
                content:
                    '{"items":[{"title":"One","url":"https://one.example.com/a","text":"A"},{"title":"Two","url":"https://two.example.com/b","text":"B"},{"title":"Three","url":"https://three.example.com/c","text":"C"},{"title":"Four","url":"https://four.example.com/d","text":"D"}]}',
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('4个引用'), findsOneWidget);
      expect(find.byIcon(Lucide.BookOpen), findsNothing);

      final capsule = tester.widget<IosCardPress>(
        find.ancestor(
          of: find.text('4个引用'),
          matching: find.byType(IosCardPress),
        ),
      );
      expect(capsule.borderRadius, BorderRadius.circular(20));
      expect(capsule.baseColor, Colors.transparent);
      expect(
        capsule.border,
        Border.all(color: Colors.black.withValues(alpha: 0.10), width: 0.8),
      );
      expect(
        capsule.padding,
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      );

      expect(
        _findNetworkImage('https://favicone.com/one.example.com'),
        findsOneWidget,
      );
      expect(
        _findNetworkImage('https://favicone.com/two.example.com'),
        findsOneWidget,
      );
      expect(
        _findNetworkImage('https://favicone.com/three.example.com'),
        findsOneWidget,
      );
      expect(
        _findNetworkImage('https://favicone.com/four.example.com'),
        findsNothing,
      );

      await tester.tap(find.text('4个引用'));
      await tester.pumpAndSettle();

      expect(find.text('搜索结果'), findsOneWidget);
      expect(find.text('Four'), findsOneWidget);
    });

    testWidgets('search citations summarize all search results in one reply', (
      tester,
    ) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.defaultStyle);

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          locale: const Locale('zh'),
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'assistant',
              content: 'Answer with multiple search calls.',
              conversationId: 'conversation-search-capsule-multiple',
            ),
            showModelIcon: false,
            toolParts: const [
              ToolUIPart(
                id: 'builtin-search-first',
                toolName: 'builtin_search',
                arguments: {},
                content:
                    '{"items":[{"title":"First source","url":"https://one.example.com/a","text":"A"},{"title":"Second source","url":"https://two.example.com/b","text":"B"}]}',
              ),
              ToolUIPart(
                id: 'search-web-second',
                toolName: 'search_web',
                arguments: {'query': 'Kelivo release'},
                content:
                    '{"items":[{"title":"Third source","url":"https://three.example.com/c","text":"C"}]}',
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('3个引用'), findsOneWidget);

      await tester.tap(find.text('3个引用'));
      await tester.pumpAndSettle();

      expect(find.text('搜索结果'), findsOneWidget);
      expect(find.text('First source'), findsOneWidget);
      expect(find.text('Second source'), findsOneWidget);
      expect(find.text('Third source'), findsOneWidget);
    });

    testWidgets('search citation capsule falls back when source url is invalid', (
      tester,
    ) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.defaultStyle);

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          locale: const Locale('zh'),
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'assistant',
              content: 'Answer with one broken citation.',
              conversationId: 'conversation-search-capsule-invalid-url',
            ),
            showModelIcon: false,
            toolParts: const [
              ToolUIPart(
                id: 'builtin-search-invalid-url',
                toolName: 'builtin_search',
                arguments: {},
                content:
                    '{"items":[{"title":"Broken","url":"","text":"No usable source"}]}',
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('1个引用'), findsOneWidget);
      expect(find.byIcon(Lucide.Globe), findsOneWidget);
    });

    testWidgets('thinking/tool timeline card uses blur in frosted mode', (
      tester,
    ) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.frosted);
      await settings.setCollapseThinkingSteps(true);

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'assistant',
              content: '',
              conversationId: 'conversation-1',
              isStreaming: true,
            ),
            showModelIcon: false,
            reasoningSegments: const [
              ReasoningSegment(text: '第 1 步', expanded: true, loading: false),
              ReasoningSegment(text: '第 2 步', expanded: true, loading: false),
              ReasoningSegment(text: '先分析问题', expanded: true, loading: false),
            ],
            toolParts: const [
              ToolUIPart(
                id: 'tool-1',
                toolName: 'search_web',
                arguments: {'query': 'Kelivo'},
                content: '搜索结果',
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Deep Thinking')).style?.color,
        _expectedNeutralStrong(),
      );
      expect(
        tester.widget<Text>(find.text('Web Search: Kelivo')).style?.color,
        _expectedNeutralStrong(),
      );
      expect(
        tester.widget<Text>(find.text('Show 2 more steps')).style?.color,
        _expectedNeutralStrong(),
      );
    });

    testWidgets('thinking/tool timeline card does not use blur in solid mode', (
      tester,
    ) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.solid);

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'assistant',
              content: '',
              conversationId: 'conversation-2',
              isStreaming: true,
            ),
            showModelIcon: false,
            reasoningSegments: const [
              ReasoningSegment(text: '先分析问题', expanded: true, loading: false),
            ],
            toolParts: const [
              ToolUIPart(
                id: 'tool-2',
                toolName: 'search_web',
                arguments: {'query': 'Kelivo'},
                content: '搜索结果',
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        tester.widget<Text>(find.text('Deep Thinking')).style?.color,
        _expectedNeutralStrong(),
      );
      expect(
        tester.widget<Text>(find.text('Web Search: Kelivo')).style?.color,
        _expectedNeutralStrong(),
      );
    });

    testWidgets('tool message card uses blur in frosted mode', (tester) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.frosted);

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'tool',
              content: jsonEncode({
                'tool': 'search_web',
                'arguments': {'query': 'Kelivo'},
                'result': '搜索结果',
              }),
              conversationId: 'conversation-3',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Web Search: Kelivo')).style?.color,
        _expectedNeutralStrong(),
      );
    });

    testWidgets('tool message card does not use blur in solid mode', (
      tester,
    ) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.solid);

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'tool',
              content: jsonEncode({
                'tool': 'search_web',
                'arguments': {'query': 'Kelivo'},
                'result': '搜索结果',
              }),
              conversationId: 'conversation-4',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        tester.widget<Text>(find.text('Web Search: Kelivo')).style?.color,
        _expectedNeutralStrong(),
      );
    });

    testWidgets(
      'translation card uses blur and neutral header in frosted mode',
      (tester) async {
        final settings = _createSettings(ChatMessageBackgroundStyle.frosted);

        await tester.pumpWidget(
          _buildHarness(
            settings: settings,
            child: ChatMessageWidget(
              message: ChatMessage(
                role: 'assistant',
                content: 'Answer',
                translation: 'Translated answer',
                conversationId: 'conversation-5',
                isStreaming: true,
              ),
              showModelIcon: false,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(BackdropFilter), findsNWidgets(2));
        expect(
          tester.widget<Text>(find.text('Translation')).style?.color,
          _expectedNeutralStrong(),
        );
      },
    );

    testWidgets('translation card removes blur in solid mode', (tester) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.solid);

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'assistant',
              content: 'Answer',
              translation: 'Translated answer',
              conversationId: 'conversation-6',
              isStreaming: true,
            ),
            showModelIcon: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        tester.widget<Text>(find.text('Translation')).style?.color,
        _expectedNeutralStrong(),
      );
    });

    testWidgets('local tool cards use local tool names and icons', (
      tester,
    ) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.defaultStyle);

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'assistant',
              content: '',
              conversationId: 'conversation-local-tools',
              isStreaming: true,
            ),
            showModelIcon: false,
            reasoningSegments: const [
              ReasoningSegment(text: '需要本地信息', expanded: true, loading: false),
            ],
            toolParts: const [
              ToolUIPart(
                id: 'time-info',
                toolName: 'get_time_info',
                arguments: {},
                content: '{"date":"2026-05-06"}',
              ),
              ToolUIPart(
                id: 'clipboard-read',
                toolName: 'clipboard_tool',
                arguments: {'action': 'read'},
                content: '{"text":"hello"}',
              ),
              ToolUIPart(
                id: 'clipboard-write',
                toolName: 'clipboard_tool',
                arguments: {'action': 'write', 'text': 'hello'},
                content: '{"success":true,"text":"hello"}',
              ),
              ToolUIPart(
                id: 'tts',
                toolName: 'text_to_speech',
                arguments: {'text': 'Replay this line'},
                content: '{"success":true}',
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Time Info'), findsOneWidget);
      expect(find.text('Read Clipboard'), findsOneWidget);
      expect(find.text('Write Clipboard'), findsOneWidget);
      expect(find.text('Speaking: Replay this line'), findsOneWidget);
      expect(find.text('Replay this line'), findsOneWidget);
      expect(find.byTooltip('Replay'), findsOneWidget);
      final replayButton = tester.widget<IosIconButton>(
        find.descendant(
          of: find.byTooltip('Replay'),
          matching: find.byType(IosIconButton),
        ),
      );
      expect(replayButton.minSize, 30);
      expect(replayButton.padding, const EdgeInsets.all(6));
      expect(find.text('Clipboard'), findsNothing);
      expect(find.text('Tool Result: get_time_info'), findsNothing);
      expect(find.text('Tool Result: clipboard_tool'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.icon == Lucide.clock,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.icon == Lucide.ClipboardCheck,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.icon == Lucide.ClipboardPen,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.icon == Lucide.Volume2,
        ),
        findsOneWidget,
      );
    });

    testWidgets('text to speech replay button speaks the tool text', (
      tester,
    ) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.defaultStyle);
      final ttsProvider = _RecordingTtsProvider();
      addTearDown(ttsProvider.dispose);

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          ttsProvider: ttsProvider,
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'assistant',
              content: '',
              conversationId: 'conversation-local-tts-replay',
              isStreaming: true,
            ),
            showModelIcon: false,
            toolParts: const [
              ToolUIPart(
                id: 'tts',
                toolName: 'text_to_speech',
                arguments: {'text': 'Replay this line'},
                content: '{"success":true}',
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byTooltip('Replay'));
      await tester.pump();

      expect(ttsProvider.spokenTexts, ['Replay this line']);
      expect(find.byTooltip('Replay'), findsOneWidget);
    });

    testWidgets('text to speech tool card opens details for long text', (
      tester,
    ) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.defaultStyle);

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'assistant',
              content: '',
              conversationId: 'conversation-local-tts-toggle',
              isStreaming: true,
            ),
            showModelIcon: false,
            toolParts: const [
              ToolUIPart(
                id: 'tts',
                toolName: 'text_to_speech',
                arguments: {'text': 'Replay this line'},
                content: '{"success":true}',
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Replay'), findsOneWidget);

      await tester.tap(find.text('Speaking: Replay this line'));
      await tester.pumpAndSettle();

      expect(find.text('Arguments'), findsOneWidget);
      expect(find.text('Replay this line'), findsWidgets);
      expect(find.byTooltip('Replay'), findsOneWidget);
    });

    testWidgets('unclosed think tag remains visible as assistant content', (
      tester,
    ) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.defaultStyle);

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'assistant',
              content: '<think>literal answer',
              conversationId: 'conversation-unclosed-think',
            ),
            showModelIcon: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('<think>literal answer'), findsOneWidget);
      expect(find.text('Deep Thinking'), findsNothing);
    });

    testWidgets(
      'structured reasoning keeps literal think block in assistant content',
      (tester) async {
        final settings = _createSettings(
          ChatMessageBackgroundStyle.defaultStyle,
        );

        await tester.pumpWidget(
          _buildHarness(
            settings: settings,
            child: ChatMessageWidget(
              message: ChatMessage(
                role: 'assistant',
                content: '正文 <think>literal</think> 继续显示',
                conversationId: 'conversation-structured-think',
              ),
              showModelIcon: false,
              reasoningSegments: const [
                ReasoningSegment(text: '结构化思考', expanded: true, loading: false),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Deep Thinking'), findsOneWidget);
        expect(find.textContaining('结构化思考'), findsOneWidget);
        expect(
          find.textContaining('正文 <think>literal</think> 继续显示'),
          findsOneWidget,
        );
      },
    );

    testWidgets('closed legacy think block renders as thinking card', (
      tester,
    ) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.defaultStyle);

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'assistant',
              content: '<think>legacy reasoning</think>Final answer',
              conversationId: 'conversation-legacy-think',
            ),
            showModelIcon: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Deep Thinking'), findsOneWidget);
      expect(find.textContaining('Final answer'), findsOneWidget);
      expect(
        find.textContaining('<think>legacy reasoning</think>'),
        findsNothing,
      );
    });

    testWidgets('ask user card submits selected answer', (tester) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.defaultStyle);
      final askUserService = AskUserInteractionService();
      final answerFuture = askUserService.requestAnswer(
        toolCallId: 'ask-1',
        arguments: const {
          'questions': [
            {
              'id': 'scope',
              'question': 'Choose scope?',
              'type': 'single',
              'options': ['Minimal', 'Complete'],
            },
          ],
        },
      );

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          askUserService: askUserService,
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'assistant',
              content: 'Let me ask first.',
              conversationId: 'conversation-ask-user',
              isStreaming: true,
            ),
            showModelIcon: false,
            toolParts: const [
              ToolUIPart(
                id: 'ask-1',
                toolName: 'ask_user_input_v0',
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
                loading: true,
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Choose scope?'), findsNWidgets(2));
      expect(find.text('Ask User'), findsNothing);
      expect(find.text('Needs your answer'), findsNothing);
      expect(find.text('Minimal'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('Type your answer'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      final minimalOptionContainer = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.text('Minimal'),
              matching: find.byType(Container),
            ),
          )
          .where((container) => container.constraints?.minHeight == 40)
          .single;
      final minimalOptionDecoration =
          minimalOptionContainer.decoration! as BoxDecoration;
      expect(minimalOptionDecoration.color, Colors.transparent);

      await tester.tap(find.text('Complete'));
      await tester.pump();
      await tester.tap(find.text('Submit answer'));
      await tester.pump();

      final result = await answerFuture;
      final payload = jsonDecode(result.toJsonString()) as Map<String, dynamic>;
      expect(payload['answers']['scope']['value'], 'Complete');
      expect(payload['answers']['scope']['custom'], isFalse);
    });

    testWidgets('answered ask user card stays expanded and can collapse', (
      tester,
    ) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.defaultStyle);

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'assistant',
              content: 'Answered.',
              conversationId: 'conversation-ask-user-answered',
              isStreaming: true,
            ),
            showModelIcon: false,
            toolParts: const [
              ToolUIPart(
                id: 'ask-answered',
                toolName: 'ask_user_input_v0',
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
                content:
                    '{"type":"ask_user_answer","answers":{"scope":{"type":"single","value":"Complete","custom":false,"skipped":false}}}',
                loading: false,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Choose scope?'), findsNWidgets(2));
      expect(find.text('Complete'), findsOneWidget);

      await tester.tap(find.byIcon(Lucide.ChevronUp).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Choose scope?'), findsOneWidget);
      expect(find.text('Complete'), findsNothing);
    });

    testWidgets('ask user card can submit skipped answer', (tester) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.defaultStyle);
      final askUserService = AskUserInteractionService();
      final answerFuture = askUserService.requestAnswer(
        toolCallId: 'ask-skip',
        arguments: const {
          'questions': [
            {
              'id': 'scope',
              'question': 'Choose scope?',
              'type': 'single',
              'options': ['Minimal', 'Complete'],
            },
          ],
        },
      );

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          askUserService: askUserService,
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'assistant',
              content: 'Let me ask first.',
              conversationId: 'conversation-ask-user-skip',
              isStreaming: true,
            ),
            showModelIcon: false,
            toolParts: const [
              ToolUIPart(
                id: 'ask-skip',
                toolName: 'ask_user_input_v0',
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
                loading: true,
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Skip'));
      await tester.pump();
      await tester.tap(find.text('Submit answer'));
      await tester.pump();

      final result = await answerFuture;
      final payload = jsonDecode(result.toJsonString()) as Map<String, dynamic>;
      expect(payload['answers']['scope']['skipped'], isTrue);
    });

    testWidgets('restored pending ask user card submits recovered answer', (
      tester,
    ) async {
      final settings = _createSettings(ChatMessageBackgroundStyle.defaultStyle);
      ToolUIPart? submittedPart;
      AskUserResult? submittedResult;

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          child: ChatMessageWidget(
            message: ChatMessage(
              role: 'assistant',
              content: 'Let me ask first.',
              conversationId: 'conversation-ask-user-recovered',
              isStreaming: true,
            ),
            showModelIcon: false,
            onRecoveredAskUserAnswer: (part, result) async {
              submittedPart = part;
              submittedResult = result;
            },
            toolParts: const [
              ToolUIPart(
                id: 'ask-recovered',
                toolName: 'ask_user_input_v0',
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
                loading: true,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'This question is no longer active. Regenerate or continue the conversation.',
        ),
        findsNothing,
      );
      expect(find.text('Complete'), findsOneWidget);

      await tester.tap(find.text('Complete'));
      await tester.pump();
      await tester.tap(find.text('Submit answer'));
      await tester.pump();

      expect(submittedPart?.id, 'ask-recovered');
      final payload =
          jsonDecode(submittedResult!.toJsonString()) as Map<String, dynamic>;
      expect(payload['answers']['scope']['value'], 'Complete');
    });
  });
}
