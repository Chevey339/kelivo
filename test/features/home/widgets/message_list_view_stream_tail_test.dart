import "../../../support/business_test_harness.dart";

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
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

const _streamingId = 'probe-streaming';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('生成结束时尾部高度变化被布局阶段吸收，不再跳一下再滑回底部', (tester) async {
    tester.view.physicalSize = const Size(1170, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey<_ProbeHarnessState>();
    await tester.pumpWidget(_ProbeHarness(key: key));
    await tester.pump(const Duration(milliseconds: 100));
    final state = key.currentState!;

    final full = List<String>.filled(
      60,
      '这是一段用于撑高消息气泡的长文本，重复出现以便观察滚动跟随行为。',
    ).join('\n');
    var visible = 0;
    while (visible < full.length) {
      visible = (visible + 40).clamp(0, full.length);
      state.pushStreamTick(
        visibleContent: full.substring(0, visible),
        targetContent: full.substring(0, visible),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    final position = state.scrollController.position;
    expect(position.maxScrollExtent - position.pixels, lessThan(1));

    // The terminal widget is taller than the streaming one (action bar, token
    // stats), and it arrives after isGenerating已经变成 false.
    state.finishStreaming(full);
    state.scrollCtrl.stickToBottomAfterGeneration();

    final anchor = find.byKey(
      const ValueKey<String>('timeline-slot:$_streamingId'),
    );
    final trace = <double>[];
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      trace.add(tester.getTopLeft(anchor).dy);
    }

    // Held layout pin: the tail stays at the bottom the whole time, so the
    // timeline never has to catch up afterwards.
    expect(
      state.scrollController.position.maxScrollExtent -
          state.scrollController.position.pixels,
      lessThan(1),
    );
    for (var i = 1; i < trace.length; i++) {
      expect(
        trace[i],
        moreOrLessEquals(trace[i - 1], epsilon: 1),
        reason: 'frame $i moved by ${trace[i] - trace[i - 1]}',
      );
    }
  });
}

class _ProbeHarness extends StatefulWidget {
  const _ProbeHarness({super.key});

  @override
  State<_ProbeHarness> createState() => _ProbeHarnessState();
}

class _ProbeHarnessState extends State<_ProbeHarness> {
  final scrollController = scroll_ctrl.ChatAutoFollowScrollController();
  final streamingNotifier = StreamingContentNotifier();
  late final scroll_ctrl.ChatScrollController scrollCtrl;
  final processingFilesMessageId = ValueNotifier<String?>(null);
  bool generating = true;

  late List<ChatMessage> messages = <ChatMessage>[
    for (var index = 0; index < 6; index++)
      ChatMessage(
        id: 'history-$index',
        role: index.isEven ? 'user' : 'assistant',
        content: List<String>.filled(3, '历史消息内容 $index').join('\n'),
        conversationId: 'conversation-1',
      ),
    ChatMessage(
      id: _streamingId,
      role: 'assistant',
      content: '',
      conversationId: 'conversation-1',
      isStreaming: true,
    ),
  ];

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
    streamingNotifier.getNotifier(_streamingId);
  }

  void pushStreamTick({
    required String visibleContent,
    required String targetContent,
  }) {
    streamingNotifier.updateContent(_streamingId, visibleContent, 10);
    setState(() {
      messages = [
        for (final message in messages)
          if (message.id == _streamingId)
            message.copyWith(content: targetContent)
          else
            message,
      ];
    });
    scrollCtrl.autoScrollToBottomIfNeeded();
  }

  void finishStreaming(String content) {
    streamingNotifier.removeNotifier(_streamingId);
    setState(() {
      generating = false;
      messages = [
        for (final message in messages)
          if (message.id == _streamingId)
            message.copyWith(
              content: content,
              isStreaming: false,
              totalTokens: 1200,
              durationMs: 4200,
            )
          else
            message,
      ];
    });
  }

  @override
  void dispose() {
    scrollCtrl.dispose();
    scrollController.dispose();
    streamingNotifier.dispose();
    processingFilesMessageId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(createBusinessTestPreferences()),
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
            toolParts: const {},
            translations: const {},
            selecting: false,
            selectedItems: const {},
            dividerPadding: EdgeInsets.zero,
            processingFilesMessageId: processingFilesMessageId,
            streamingContentNotifier: streamingNotifier,
            onUserScrollIntent: scrollCtrl.handleUserScrollIntent,
          ),
        ),
      ),
    );
  }
}
