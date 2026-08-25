import "../support/business_test_harness.dart";

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart'
    as scroll_ctrl;
import 'package:Kelivo/features/home/controllers/streaming_content_notifier.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _streamingId = 'streaming-msg';

String _searchPayload(int items) {
  final buf = StringBuffer('{"items":[');
  for (var i = 0; i < items; i++) {
    if (i > 0) buf.write(',');
    buf.write(
      '{"id":"$i","index":"${i + 1}","title":"结果标题 $i 这是一个比较长的标题用于模拟真实搜索结果",'
      '"url":"https://example.com/a/very/long/path/$i","text":"这是搜索结果的摘要文本，'
      '通常会有一两百个字符，用来在卡片里显示预览内容。重复文本重复文本重复文本。$i"}',
    );
  }
  buf.write(']}');
  return buf.toString();
}

List<ToolUIPart> _tools(int n, {bool search = true, int searchItems = 8}) =>
    <ToolUIPart>[
      for (var i = 0; i < n; i++)
        ToolUIPart(
          id: 'tool-$i',
          toolName: search ? 'search_web' : 'read_file',
          arguments: {'query': '查询词 $i', 'url': 'https://example.com/$i'},
          content: search ? _searchPayload(searchItems) : '工具返回的普通文本结果 $i',
          loading: false,
        ),
    ];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final variants =
      <String, ({int tools, bool search, int items, bool collapse})>{
        'baseline-0': (tools: 0, search: false, items: 0, collapse: false),
        '30-plain': (tools: 30, search: false, items: 0, collapse: false),
        '30-search-8': (tools: 30, search: true, items: 8, collapse: false),
        '30-search-20': (tools: 30, search: true, items: 20, collapse: false),
        '30-plain-collapsed': (
          tools: 30,
          search: false,
          items: 0,
          collapse: true,
        ),
        '30-search8-collapsed': (
          tools: 30,
          search: true,
          items: 8,
          collapse: true,
        ),
      };
  for (final entry in variants.entries) {
    final v = entry.value;
    final toolCount = entry.key;
    testWidgets('bench $toolCount', (tester) async {
      tester.view.physicalSize = const Size(1170, 2100);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final key = GlobalKey<_BenchHarnessState>();
      await tester.pumpWidget(
        _BenchHarness(
          key: key,
          toolCount: v.tools,
          search: v.search,
          items: v.items,
          collapse: v.collapse,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final state = key.currentState!;

      // Warm-up
      for (var i = 0; i < 3; i++) {
        state.pushStreamTick(i);
        await tester.pump(const Duration(milliseconds: 16));
      }

      final sw = Stopwatch()..start();
      const ticks = 30;
      for (var i = 0; i < ticks; i++) {
        state.pushStreamTick(i + 10);
        await tester.pump(const Duration(milliseconds: 16));
      }
      sw.stop();
      final perTick = sw.elapsedMicroseconds / ticks / 1000.0;

      // Scroll cost over the finished history.
      state.finishStreaming();
      await tester.pump(const Duration(milliseconds: 32));
      final scrollSw = Stopwatch()..start();
      for (var i = 0; i < 30; i++) {
        await tester.drag(
          find.byType(MessageListView),
          const Offset(0, 120),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      scrollSw.stop();

      // ignore: avoid_print
      print(
        'RESULT tools=$toolCount streamTickMs=${perTick.toStringAsFixed(2)} '
        'scroll30Ms=${scrollSw.elapsedMilliseconds}',
      );
    });
  }

  testWidgets('bench structured-30-parts', (tester) async {
    tester.view.physicalSize = const Size(1170, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey<_BenchHarnessState>();
    await tester.pumpWidget(
      _BenchHarness(
        key: key,
        toolCount: 30,
        search: false,
        items: 0,
        collapse: false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final state = key.currentState!;

    for (var i = 0; i < 3; i++) {
      state.pushStructuredTick(i);
      await tester.pump(const Duration(milliseconds: 16));
    }

    final sw = Stopwatch()..start();
    const ticks = 30;
    for (var i = 0; i < ticks; i++) {
      state.pushStructuredTick(i + 10);
      await tester.pump(const Duration(milliseconds: 16));
    }
    sw.stop();
    final perTick = sw.elapsedMicroseconds / ticks / 1000.0;
    // ignore: avoid_print
    print(
      'RESULT tools=structured-30-parts '
      'streamTickMs=${perTick.toStringAsFixed(2)}',
    );
  });
}

class _BenchHarness extends StatefulWidget {
  const _BenchHarness({
    super.key,
    required this.toolCount,
    required this.search,
    required this.items,
    required this.collapse,
  });
  final int toolCount;
  final bool search;
  final int items;
  final bool collapse;

  @override
  State<_BenchHarness> createState() => _BenchHarnessState();
}

class _BenchHarnessState extends State<_BenchHarness> {
  final scrollController = scroll_ctrl.ChatAutoFollowScrollController();
  final streamingNotifier = StreamingContentNotifier();
  late final scroll_ctrl.ChatScrollController scrollCtrl;
  final isProcessingFiles = ValueNotifier<bool>(false);
  bool generating = true;

  late Map<String, List<ToolUIPart>> toolParts;
  late List<ChatMessage> messages;

  @override
  void initState() {
    super.initState();
    scrollCtrl = scroll_ctrl.ChatScrollController(
      scrollController: scrollController,
      onStateChanged: () {},
      getAutoScrollEnabled: () => true,
      getAutoScrollIdleSeconds: () => 3,
      isGenerating: () => generating,
    );
    final tools = _tools(
      widget.toolCount,
      search: widget.search,
      searchItems: widget.items,
    );
    toolParts = <String, List<ToolUIPart>>{
      _streamingId: tools,
      for (var index = 1; index < 12; index += 2) 'history-$index': tools,
    };
    messages = <ChatMessage>[
      for (var index = 0; index < 12; index++)
        ChatMessage(
          id: 'history-$index',
          role: index.isEven ? 'user' : 'assistant',
          content: index.isEven ? '用户提问 $index' : '好的',
          conversationId: 'c1',
        ),
      ChatMessage(
        id: _streamingId,
        role: 'assistant',
        content: '',
        conversationId: 'c1',
        isStreaming: true,
      ),
    ];
    streamingNotifier.getNotifier(_streamingId);
  }

  void pushStreamTick(int i) {
    streamingNotifier.updateContent(_streamingId, '正在回答' * (i % 5 + 1), 10);
  }

  void pushStructuredTick(int i) {
    final body = '正在回答' * (i % 5 + 1);
    streamingNotifier.updateContent(
      _streamingId,
      body,
      10,
      parts: [
        const ReasoningPart('plan text for structured streaming bench'),
        TextPart(body),
        for (var t = 0; t < 30; t++)
          ToolCallPart(
            '{"id":"t$t","name":"read_file","arguments":{"path":"$t.dart"},'
            '"content":"ok"}',
          ),
      ],
    );
  }

  void finishStreaming() {
    streamingNotifier.removeNotifier(_streamingId);
    setState(() {
      generating = false;
      messages = [
        for (final m in messages)
          if (m.id == _streamingId)
            m.copyWith(content: '完成', isStreaming: false, totalTokens: 100)
          else
            m,
      ];
    });
  }

  @override
  void dispose() {
    scrollCtrl.dispose();
    scrollController.dispose();
    streamingNotifier.dispose();
    isProcessingFiles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final sp = SettingsProvider(createBusinessTestPreferences());
            sp.setCollapseThinkingSteps(widget.collapse);
            return sp;
          },
        ),
        ChangeNotifierProvider(
          create: (_) =>
              AssistantProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              TtsProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              UserProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ChangeNotifierProvider(create: (_) => ToolApprovalService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageListView(
            scrollController: scrollController,
            listController: scrollCtrl.messageListController,
            messages: messages,
            byGroup: const {},
            versionSelections: const {},
            reasoning: const {},
            reasoningSegments: const {},
            contentSplits: const {},
            toolParts: toolParts,
            translations: const {},
            selecting: false,
            selectedItems: const {},
            dividerPadding: EdgeInsets.zero,
            isProcessingFiles: isProcessingFiles,
            streamingContentNotifier: streamingNotifier,
            onUserScrollIntent: scrollCtrl.handleUserScrollIntent,
          ),
        ),
      ),
    );
  }
}
