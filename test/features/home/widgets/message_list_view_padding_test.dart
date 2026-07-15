import 'dart:ui';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart'
    as scroll_ctrl;
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream_ctrl;
import 'package:Kelivo/features/home/controllers/streaming_content_notifier.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('macOS 消息列表滚动不主动清除文本选区焦点', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final scrollController = ScrollController();
    final listController = ListController();
    final isProcessingFiles = ValueNotifier<bool>(false);

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageListView(
              scrollController: scrollController,
              listController: listController,
              messages: const [],
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
              isProcessingFiles: isProcessingFiles,
            ),
          ),
        ),
      );

      final listView = tester.widget<SuperListView>(find.byType(SuperListView));
      expect(
        listView.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.manual,
      );
      expect(listView.delayPopulatingCacheArea, isFalse);
      expect(listView.clipBehavior, Clip.hardEdge);
      // SuperListView 0.4.1 still forwards this constructor value through the
      // legacy ScrollView property on current Flutter.
      // ignore: deprecated_member_use
      expect(listView.cacheExtent, 600);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      scrollController.dispose();
      listController.dispose();
      isProcessingFiles.dispose();
    }
  });

  testWidgets('Android 消息列表滚动仍然收起键盘', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final scrollController = ScrollController();
    final listController = ListController();
    final isProcessingFiles = ValueNotifier<bool>(false);

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageListView(
              scrollController: scrollController,
              listController: listController,
              messages: const [],
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
              isProcessingFiles: isProcessingFiles,
            ),
          ),
        ),
      );

      final listView = tester.widget<SuperListView>(find.byType(SuperListView));
      expect(
        listView.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      scrollController.dispose();
      listController.dispose();
      isProcessingFiles.dispose();
    }
  });

  testWidgets('消息列表底部留白使用传入的输入框覆盖高度', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final isProcessingFiles = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageListView(
            scrollController: scrollController,
            listController: listController,
            messages: const [],
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
            isProcessingFiles: isProcessingFiles,
            bottomContentPadding: 144,
          ),
        ),
      ),
    );

    final listView = tester.widget<SuperListView>(find.byType(SuperListView));
    expect((listView.padding as EdgeInsets).bottom, 144);

    scrollController.dispose();
    listController.dispose();
    isProcessingFiles.dispose();
  });

  testWidgets('消息列表顶部留白使用传入的导航栏覆盖高度', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final isProcessingFiles = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageListView(
            scrollController: scrollController,
            listController: listController,
            messages: const [],
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
            isProcessingFiles: isProcessingFiles,
            topContentPadding: 88,
            bottomContentPadding: 144,
          ),
        ),
      ),
    );

    final listView = tester.widget<SuperListView>(find.byType(SuperListView));
    expect((listView.padding as EdgeInsets).top, 88);
    expect((listView.padding as EdgeInsets).bottom, 144);

    scrollController.dispose();
    listController.dispose();
    isProcessingFiles.dispose();
  });

  testWidgets('置顶流式指示器激活时保留额外底部空间', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final isProcessingFiles = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageListView(
            scrollController: scrollController,
            listController: listController,
            messages: const [],
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
            isProcessingFiles: isProcessingFiles,
            isPinnedIndicatorActive: true,
            bottomContentPadding: 144,
          ),
        ),
      ),
    );

    final listView = tester.widget<SuperListView>(find.byType(SuperListView));
    expect((listView.padding as EdgeInsets).bottom, 156);

    scrollController.dispose();
    listController.dispose();
    isProcessingFiles.dispose();
  });

  testWidgets('流式思考更新缺少起始时间时保留已有计时起点', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final isProcessingFiles = ValueNotifier<bool>(false);
    final streamingNotifier = StreamingContentNotifier();
    const messageId = 'reasoning-streaming-message';
    final startAt = DateTime.now().subtract(const Duration(seconds: 7));
    final reasoning = <String, stream_ctrl.ReasoningData>{
      messageId: stream_ctrl.ReasoningData()
        ..text = 'initial thinking'
        ..startAt = startAt
        ..expanded = false,
    };
    final messages = <ChatMessage>[
      ChatMessage(
        id: messageId,
        role: 'assistant',
        content: '',
        conversationId: 'conversation-1',
        isStreaming: true,
      ),
    ];
    streamingNotifier.getNotifier(messageId);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: SettingsProvider()),
          ChangeNotifierProvider.value(value: AssistantProvider()),
          ChangeNotifierProvider.value(value: TtsProvider()),
          ChangeNotifierProvider.value(value: AskUserInteractionService()),
          ChangeNotifierProvider.value(value: ToolApprovalService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageListView(
              scrollController: scrollController,
              listController: listController,
              messages: messages,
              byGroup: const {},
              versionSelections: const {},
              reasoning: reasoning,
              reasoningSegments: const {},
              contentSplits: const {},
              toolParts: const {},
              translations: const {},
              selecting: false,
              selectedItems: const {},
              dividerPadding: EdgeInsets.zero,
              isProcessingFiles: isProcessingFiles,
              bottomContentPadding: 16,
              streamingContentNotifier: streamingNotifier,
            ),
          ),
        ),
      ),
    );

    streamingNotifier.updateReasoning(
      messageId,
      reasoningText: 'updated thinking',
    );
    await tester.pump();

    expect(reasoning[messageId]!.startAt, startAt);

    scrollController.dispose();
    listController.dispose();
    isProcessingFiles.dispose();
    streamingNotifier.dispose();
  });

  testWidgets('思考卡内部滚动不暂停流式正文更新', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final isProcessingFiles = ValueNotifier<bool>(false);
    final streamingNotifier = StreamingContentNotifier();
    const messageId = 'nested-reasoning-scroll-message';
    final reasoningText = List.filled(40, 'reasoning line').join('\n');
    final messages = <ChatMessage>[
      ChatMessage(
        id: messageId,
        role: 'assistant',
        content: 'initial nested answer',
        conversationId: 'conversation-1',
        isStreaming: true,
      ),
    ];
    final reasoning = <String, stream_ctrl.ReasoningData>{
      messageId: stream_ctrl.ReasoningData()
        ..text = reasoningText
        ..startAt = DateTime.now().subtract(const Duration(seconds: 3))
        ..expanded = false,
    };
    streamingNotifier.getNotifier(messageId);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: SettingsProvider()),
          ChangeNotifierProvider.value(value: AssistantProvider()),
          ChangeNotifierProvider.value(value: TtsProvider()),
          ChangeNotifierProvider.value(value: AskUserInteractionService()),
          ChangeNotifierProvider.value(value: ToolApprovalService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageListView(
              scrollController: scrollController,
              listController: listController,
              messages: messages,
              byGroup: const {},
              versionSelections: const {},
              reasoning: reasoning,
              reasoningSegments: const {},
              contentSplits: const {},
              toolParts: const {},
              translations: const {},
              selecting: false,
              selectedItems: const {},
              dividerPadding: EdgeInsets.zero,
              isProcessingFiles: isProcessingFiles,
              bottomContentPadding: 16,
              streamingContentNotifier: streamingNotifier,
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 320));

    final innerScroll = find.byType(SingleChildScrollView).first;
    await tester.drag(innerScroll, const Offset(0, 40));
    await tester.pump();

    streamingNotifier.updateContent(
      messageId,
      'updated after nested reasoning scroll',
      3,
    );
    await tester.pump();

    expect(find.text('updated after nested reasoning scroll'), findsOneWidget);

    scrollController.dispose();
    listController.dispose();
    isProcessingFiles.dispose();
    streamingNotifier.dispose();
  });

  testWidgets('用户拖动离开底部时暂停应用流式内容更新', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final isProcessingFiles = ValueNotifier<bool>(false);
    final streamingNotifier = StreamingContentNotifier();
    final messages = <ChatMessage>[
      for (var i = 0; i < 18; i++)
        ChatMessage(
          id: 'message-$i',
          role: 'assistant',
          content: '\n\n\n\n\n\n\n\n',
          conversationId: 'conversation-1',
        ),
      ChatMessage(
        id: 'streaming-message',
        role: 'assistant',
        content: 'initial stream content',
        conversationId: 'conversation-1',
        isStreaming: true,
      ),
    ];
    streamingNotifier.getNotifier('streaming-message');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: SettingsProvider()),
          ChangeNotifierProvider.value(value: AssistantProvider()),
          ChangeNotifierProvider.value(value: TtsProvider()),
          ChangeNotifierProvider.value(value: AskUserInteractionService()),
          ChangeNotifierProvider.value(value: ToolApprovalService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageListView(
              scrollController: scrollController,
              listController: listController,
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
              isProcessingFiles: isProcessingFiles,
              bottomContentPadding: 16,
              streamingContentNotifier: streamingNotifier,
            ),
          ),
        ),
      ),
    );

    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SuperListView)),
    );
    await gesture.moveBy(const Offset(0, 96));
    await tester.pump();

    streamingNotifier.updateContent(
      'streaming-message',
      'updated while dragging',
      3,
    );
    await tester.pump();

    expect(find.text('initial stream content'), findsOneWidget);
    expect(find.text('updated while dragging'), findsNothing);

    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('initial stream content'), findsOneWidget);
    expect(find.text('updated while dragging'), findsNothing);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('updated while dragging'), findsOneWidget);

    scrollController.dispose();
    listController.dispose();
    isProcessingFiles.dispose();
    streamingNotifier.dispose();
  });

  testWidgets('贴近底部时用户滚动不暂停应用流式内容更新', (tester) async {
    var userIntentCalls = 0;
    final scrollController = ScrollController();
    final listController = ListController();
    final isProcessingFiles = ValueNotifier<bool>(false);
    final streamingNotifier = StreamingContentNotifier();
    final messages = <ChatMessage>[
      for (var i = 0; i < 18; i++)
        ChatMessage(
          id: 'bottom-message-$i',
          role: 'assistant',
          content: '\n\n\n\n\n\n\n\n',
          conversationId: 'conversation-1',
        ),
      ChatMessage(
        id: 'bottom-streaming-message',
        role: 'assistant',
        content: 'initial bottom stream content',
        conversationId: 'conversation-1',
        isStreaming: true,
      ),
    ];
    streamingNotifier.getNotifier('bottom-streaming-message');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: SettingsProvider()),
          ChangeNotifierProvider.value(value: AssistantProvider()),
          ChangeNotifierProvider.value(value: TtsProvider()),
          ChangeNotifierProvider.value(value: AskUserInteractionService()),
          ChangeNotifierProvider.value(value: ToolApprovalService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageListView(
              scrollController: scrollController,
              listController: listController,
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
              isProcessingFiles: isProcessingFiles,
              bottomContentPadding: 16,
              streamingContentNotifier: streamingNotifier,
              onUserScrollIntent: () => userIntentCalls++,
            ),
          ),
        ),
      ),
    );

    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SuperListView)),
    );
    await gesture.moveBy(const Offset(0, 8));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -4));
    await tester.pump();

    expect(userIntentCalls, 0);
    expect(
      scrollController.position.maxScrollExtent - scrollController.offset,
      lessThanOrEqualTo(56),
    );

    streamingNotifier.updateContent(
      'bottom-streaming-message',
      'updated while still near bottom',
      3,
    );
    await tester.pump();

    expect(find.text('updated while still near bottom'), findsNothing);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 220));
    expect(userIntentCalls, 0);
    expect(find.text('updated while still near bottom'), findsOneWidget);

    scrollController.dispose();
    listController.dispose();
    isProcessingFiles.dispose();
    streamingNotifier.dispose();
  });

  testWidgets('滚轮滚动时暂停应用流式内容更新', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final isProcessingFiles = ValueNotifier<bool>(false);
    final streamingNotifier = StreamingContentNotifier();
    final messages = <ChatMessage>[
      for (var i = 0; i < 18; i++)
        ChatMessage(
          id: 'wheel-message-$i',
          role: 'assistant',
          content: '\n\n\n\n\n\n\n\n',
          conversationId: 'conversation-1',
        ),
      ChatMessage(
        id: 'wheel-streaming-message',
        role: 'assistant',
        content: 'initial wheel stream content',
        conversationId: 'conversation-1',
        isStreaming: true,
      ),
    ];
    streamingNotifier.getNotifier('wheel-streaming-message');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: SettingsProvider()),
          ChangeNotifierProvider.value(value: AssistantProvider()),
          ChangeNotifierProvider.value(value: TtsProvider()),
          ChangeNotifierProvider.value(value: AskUserInteractionService()),
          ChangeNotifierProvider.value(value: ToolApprovalService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageListView(
              scrollController: scrollController,
              listController: listController,
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
              isProcessingFiles: isProcessingFiles,
              bottomContentPadding: 16,
              streamingContentNotifier: streamingNotifier,
            ),
          ),
        ),
      ),
    );

    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pump();

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(find.byType(SuperListView))),
    );
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -96)));
    await tester.pump();

    streamingNotifier.updateContent(
      'wheel-streaming-message',
      'updated while wheel scrolling',
      3,
    );
    await tester.pump();

    expect(find.text('initial wheel stream content'), findsOneWidget);
    expect(find.text('updated while wheel scrolling'), findsNothing);

    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('updated while wheel scrolling'), findsOneWidget);

    scrollController.dispose();
    listController.dispose();
    isProcessingFiles.dispose();
    streamingNotifier.dispose();
  });

  testWidgets('顶部增量载入变高消息时保持当前可见消息位置', (tester) async {
    final key = GlobalKey<_PrependingMessageListHarnessState>();
    await tester.pumpWidget(_PrependingMessageListHarness(key: key));

    final state = key.currentState!;
    state.listController.jumpToItem(
      index: 15,
      scrollController: state.scrollController,
      alignment: 0.2,
    );
    await tester.pumpAndSettle();

    final target = find.byKey(const ValueKey<String>('window-message-15'));
    expect(target, findsOneWidget);
    final topBeforePrepend = tester.getTopLeft(target).dy;

    state.prependMessages();
    await tester.pumpAndSettle();

    expect(target, findsOneWidget);
    expect(
      tester.getTopLeft(target).dy,
      moreOrLessEquals(topBeforePrepend, epsilon: 1),
    );
  });

  testWidgets('编辑可见窗口内的消息后保持原有阅读锚点', (tester) async {
    final key = GlobalKey<_PrependingMessageListHarnessState>();
    await tester.pumpWidget(_PrependingMessageListHarness(key: key));

    final state = key.currentState!;
    state.listController.jumpToItem(
      index: 15,
      scrollController: state.scrollController,
      alignment: 0.2,
    );
    await tester.pumpAndSettle();

    final target = find.byKey(const ValueKey<String>('window-message-15'));
    expect(target, findsOneWidget);
    final topBeforeEdit = tester.getTopLeft(target).dy;

    state.editMessageAboveAnchor();
    await tester.pumpAndSettle();

    expect(target, findsOneWidget);
    expect(
      tester.getTopLeft(target).dy,
      moreOrLessEquals(topBeforeEdit, epsilon: 1),
    );
  });
}

class _PrependingMessageListHarness extends StatefulWidget {
  const _PrependingMessageListHarness({super.key});

  @override
  State<_PrependingMessageListHarness> createState() =>
      _PrependingMessageListHarnessState();
}

class _PrependingMessageListHarnessState
    extends State<_PrependingMessageListHarness> {
  final scrollController = scroll_ctrl.ChatAutoFollowScrollController();
  final listController = ListController();
  final isProcessingFiles = ValueNotifier<bool>(false);
  late List<ChatMessage> messages = <ChatMessage>[
    for (var index = 0; index < 30; index++)
      ChatMessage(
        id: 'window-message-$index',
        role: index.isEven ? 'user' : 'assistant',
        content: List<String>.filled(
          1 + index % 5,
          'variable height line $index',
        ).join('\n'),
        conversationId: 'conversation-1',
      ),
  ];

  void prependMessages() {
    setState(() {
      messages = <ChatMessage>[
        for (var index = 0; index < 5; index++)
          ChatMessage(
            id: 'prepended-message-$index',
            role: index.isEven ? 'user' : 'assistant',
            content: List<String>.filled(
              6 - index,
              'prepended variable height line $index',
            ).join('\n'),
            conversationId: 'conversation-1',
          ),
        ...messages,
      ];
    });
  }

  void editMessageAboveAnchor() {
    setState(() {
      messages = [
        for (final message in messages)
          if (message.id == 'window-message-12')
            ChatMessage(
              id: 'window-message-12-v2',
              role: message.role,
              content: List<String>.filled(
                30,
                'edited message became substantially taller',
              ).join('\n'),
              conversationId: message.conversationId,
              groupId: 'window-message-12',
              version: 1,
            )
          else
            message,
      ];
    });
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
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AssistantProvider()),
        ChangeNotifierProvider(create: (_) => TtsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ChangeNotifierProvider(create: (_) => ToolApprovalService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageListView(
            scrollController: scrollController,
            listController: listController,
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
            isProcessingFiles: isProcessingFiles,
          ),
        ),
      ),
    );
  }
}
