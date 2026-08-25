import "../../../support/business_test_harness.dart";
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
import 'package:Kelivo/features/home/utils/chat_layout_constants.dart';
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
    final processingFilesMessageId = ValueNotifier<String?>(null);

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
              processingFilesMessageId: processingFilesMessageId,
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
      processingFilesMessageId.dispose();
    }
  });

  testWidgets('Android 消息列表滚动仍然收起键盘', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final scrollController = ScrollController();
    final listController = ListController();
    final processingFilesMessageId = ValueNotifier<String?>(null);

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
              processingFilesMessageId: processingFilesMessageId,
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
      processingFilesMessageId.dispose();
    }
  });

  testWidgets('消息列表底部留白使用传入的输入框覆盖高度', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final processingFilesMessageId = ValueNotifier<String?>(null);

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
            processingFilesMessageId: processingFilesMessageId,
            bottomContentPadding: 144,
          ),
        ),
      ),
    );

    final listView = tester.widget<SuperListView>(find.byType(SuperListView));
    expect((listView.padding as EdgeInsets).bottom, 144);

    scrollController.dispose();
    listController.dispose();
    processingFilesMessageId.dispose();
  });

  testWidgets('消息列表顶部留白使用传入的导航栏覆盖高度', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final processingFilesMessageId = ValueNotifier<String?>(null);

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
            processingFilesMessageId: processingFilesMessageId,
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
    processingFilesMessageId.dispose();
  });

  testWidgets('置顶流式指示器激活时保留额外底部空间', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final processingFilesMessageId = ValueNotifier<String?>(null);

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
            processingFilesMessageId: processingFilesMessageId,
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
    processingFilesMessageId.dispose();
  });

  testWidgets('流式思考更新缺少起始时间时保留已有计时起点', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final processingFilesMessageId = ValueNotifier<String?>(null);
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
          ChangeNotifierProvider.value(
            value: SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider.value(
            value: AssistantProvider(
              preferences: createBusinessTestPreferences(),
            ),
          ),
          ChangeNotifierProvider.value(
            value: TtsProvider(preferences: createBusinessTestPreferences()),
          ),
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
              processingFilesMessageId: processingFilesMessageId,
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
    processingFilesMessageId.dispose();
    streamingNotifier.dispose();
  });

  testWidgets('思考卡内部滚动不暂停流式正文更新', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final processingFilesMessageId = ValueNotifier<String?>(null);
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
          ChangeNotifierProvider.value(
            value: SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider.value(
            value: AssistantProvider(
              preferences: createBusinessTestPreferences(),
            ),
          ),
          ChangeNotifierProvider.value(
            value: TtsProvider(preferences: createBusinessTestPreferences()),
          ),
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
              processingFilesMessageId: processingFilesMessageId,
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
    processingFilesMessageId.dispose();
    streamingNotifier.dispose();
  });

  testWidgets('用户拖动离开底部时暂停应用流式内容更新', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final processingFilesMessageId = ValueNotifier<String?>(null);
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
          ChangeNotifierProvider.value(
            value: SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider.value(
            value: AssistantProvider(
              preferences: createBusinessTestPreferences(),
            ),
          ),
          ChangeNotifierProvider.value(
            value: TtsProvider(preferences: createBusinessTestPreferences()),
          ),
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
              processingFilesMessageId: processingFilesMessageId,
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
    processingFilesMessageId.dispose();
    streamingNotifier.dispose();
  });

  testWidgets('贴近底部时用户滚动仍登记意图并在松手后恢复流式内容', (tester) async {
    var userIntentCalls = 0;
    final scrollController = ScrollController();
    final listController = ListController();
    final processingFilesMessageId = ValueNotifier<String?>(null);
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
          ChangeNotifierProvider.value(
            value: SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider.value(
            value: AssistantProvider(
              preferences: createBusinessTestPreferences(),
            ),
          ),
          ChangeNotifierProvider.value(
            value: TtsProvider(preferences: createBusinessTestPreferences()),
          ),
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
              processingFilesMessageId: processingFilesMessageId,
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
    expect(userIntentCalls, 1);
    expect(find.text('updated while still near bottom'), findsOneWidget);

    scrollController.dispose();
    listController.dispose();
    processingFilesMessageId.dispose();
    streamingNotifier.dispose();
  });

  testWidgets('滚轮滚动时暂停应用流式内容更新', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final processingFilesMessageId = ValueNotifier<String?>(null);
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
          ChangeNotifierProvider.value(
            value: SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider.value(
            value: AssistantProvider(
              preferences: createBusinessTestPreferences(),
            ),
          ),
          ChangeNotifierProvider.value(
            value: TtsProvider(preferences: createBusinessTestPreferences()),
          ),
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
              processingFilesMessageId: processingFilesMessageId,
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
    processingFilesMessageId.dispose();
    streamingNotifier.dispose();
  });

  testWidgets('未布局的长消息按内容长度估算高度而非默认 100px', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final processingFilesMessageId = ValueNotifier<String?>(null);
    final longBody = List<String>.filled(
      120,
      '这是一段用于撑高消息气泡的长文本，重复出现以便估算高度。',
    ).join('\n');
    final messages = <ChatMessage>[
      for (var i = 0; i < 40; i++)
        ChatMessage(
          id: 'long-message-$i',
          role: i.isEven ? 'user' : 'assistant',
          content: longBody,
          conversationId: 'conversation-1',
        ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(
            value: SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider.value(
            value: AssistantProvider(
              preferences: createBusinessTestPreferences(),
            ),
          ),
          ChangeNotifierProvider.value(
            value: TtsProvider(preferences: createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider.value(
            value: UserProvider(preferences: createBusinessTestPreferences()),
          ),
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
              processingFilesMessageId: processingFilesMessageId,
            ),
          ),
        ),
      ),
    );

    // The tail of the list never entered layout, so its extents are still
    // estimates. A flat default (100px) makes the total extent — and with it a
    // bottom-pinned scroll offset — lurch every time one of them is measured.
    final tail = listController.extentForIndex(messages.length - 1);
    expect(tail.$2, isTrue, reason: 'tail item should still be estimated');
    expect(tail.$1, greaterThan(2000));

    scrollController.dispose();
    listController.dispose();
    processingFilesMessageId.dispose();
  });

  testWidgets('估算高度跟随系统无障碍字体缩放', (tester) async {
    final listController = ListController();
    final body = List<String>.filled(
      120,
      '这是一段用于撑高消息气泡的长文本，重复出现以便估算高度。',
    ).join('\n');
    final messages = <ChatMessage>[
      for (var i = 0; i < 40; i++)
        ChatMessage(
          id: 'scaled-message-$i',
          role: 'assistant',
          content: body,
          conversationId: 'conversation-1',
        ),
    ];

    await _pumpEstimatorHarness(
      tester,
      messages,
      listController,
      textScale: 2.0,
    );
    final tail = listController.extentForIndex(39);

    // Items render at the system scale times the chat scale. Ignoring the
    // system half leaves the estimate at the unscaled ~2900px for this body,
    // while the real bubble is about four times that.
    expect(tail.$2, isTrue);
    expect(tail.$1, greaterThan(6000));

    listController.dispose();
  });

  testWidgets('折叠的内联思考块不计入估算高度', (tester) async {
    final listController = ListController();
    final thinking = List<String>.filled(200, '这是一段很长的思考内容。').join('\n');

    await _pumpEstimatorHarness(
      tester,
      _estimatorMessages('<think>\n$thinking\n</think>\n简短的正文回答。'),
      listController,
    );
    final tail = listController.extentForIndex(39);

    // Only the one visible line plus a collapsed card renders; counting the
    // 200 hidden lines would inflate the scroll range by orders of magnitude.
    expect(tail.$2, isTrue);
    expect(tail.$1, lessThan(400));

    listController.dispose();
  });

  testWidgets('展开思考时估算高度计入思考正文', (tester) async {
    final listController = ListController();
    final thinking = List<String>.filled(200, '这是一段很长的思考内容。').join('\n');

    await _pumpEstimatorHarness(
      tester,
      _estimatorMessages('<think>\n$thinking\n</think>\n简短的正文回答。'),
      listController,
      collapseThinking: false,
    );
    final tail = listController.extentForIndex(39);

    // With auto-collapse off the whole block is on screen, so skipping it
    // would under-estimate by thousands of pixels.
    expect(tail.$2, isTrue);
    expect(tail.$1, greaterThan(4000));

    listController.dispose();
  });

  testWidgets('用户消息里的字面量 think 标签仍计入估算高度', (tester) async {
    final listController = ListController();
    final thinking = List<String>.filled(200, '这是一段很长的思考内容。').join('\n');

    await _pumpEstimatorHarness(
      tester,
      _estimatorMessages(
        '<think>\n$thinking\n</think>\n简短的正文回答。',
        role: 'user',
      ),
      listController,
    );
    final tail = listController.extentForIndex(39);

    // A user message renders its text verbatim — there is no thinking card.
    expect(tail.$2, isTrue);
    expect(tail.$1, greaterThan(4000));

    listController.dispose();
  });

  testWidgets('估算高度忽略 Markdown 链接里的目标地址', (tester) async {
    final listController = ListController();
    final target = 'https://example.com/${'a' * 4000}';

    await _pumpEstimatorHarness(
      tester,
      _estimatorMessages('[x]($target)'),
      listController,
    );
    final tail = listController.extentForIndex(39);

    // The link renders as the single character `x`; counting the hidden target
    // would invent hundreds of lines of scroll range.
    expect(tail.$2, isTrue);
    expect(tail.$1, lessThan(200));

    listController.dispose();
  });

  testWidgets('估算高度不把超长代码行按换行折算', (tester) async {
    final listController = ListController();
    final codeLine = 'x' * 4000;

    await _pumpEstimatorHarness(
      tester,
      _estimatorMessages('```json\n$codeLine\n```'),
      listController,
    );
    final tail = listController.extentForIndex(39);

    // Code blocks scroll horizontally instead of wrapping, so one long line
    // stays one line.
    expect(tail.$2, isTrue);
    expect(tail.$1, lessThan(300));

    listController.dispose();
  });

  testWidgets('代码块换行时估算高度按换行折算', (tester) async {
    final listController = ListController();
    final codeLine = 'x' * 4000;

    await _pumpEstimatorHarness(
      tester,
      _estimatorMessages('```json\n$codeLine\n```'),
      listController,
      wrapCodeBlocks: true,
    );
    final tail = listController.extentForIndex(39);

    // Desktop (and mobile with the wrap setting on) renders the same line as
    // dozens of rows; the horizontal-scroll case above estimates it at under
    // 300px, so treating every renderer as scrolling under-estimates badly.
    expect(tail.$2, isTrue);
    expect(tail.$1, greaterThan(900));

    listController.dispose();
  });

  testWidgets('展开的独立思考内容计入估算高度', (tester) async {
    final listController = ListController();
    final reasoningText = List.filled(200, '这是一段很长的思考内容。').join('\n');

    await _pumpEstimatorHarness(
      tester,
      _estimatorMessages('简短的正文回答。'),
      listController,
      reasoning: {
        for (var i = 0; i < 40; i++)
          'estimator-message-$i': stream_ctrl.ReasoningData()
            ..text = reasoningText
            ..expanded = true,
      },
    );
    final tail = listController.extentForIndex(39);

    // Reasoning lives outside message.content; ignoring it estimates a
    // reasoning-heavy message an order of magnitude too short.
    expect(tail.$2, isTrue);
    expect(tail.$1, greaterThan(3000));

    listController.dispose();
  });

  testWidgets('折叠的独立思考内容只按固定卡片高度估算', (tester) async {
    final listController = ListController();
    final reasoningText = List.filled(200, '这是一段很长的思考内容。').join('\n');

    await _pumpEstimatorHarness(
      tester,
      _estimatorMessages('简短的正文回答。'),
      listController,
      reasoning: {
        for (var i = 0; i < 40; i++)
          'estimator-message-$i': stream_ctrl.ReasoningData()
            ..text = reasoningText
            ..expanded = false,
      },
    );
    final tail = listController.extentForIndex(39);

    expect(tail.$2, isTrue);
    expect(tail.$1, lessThan(400));

    listController.dispose();
  });

  testWidgets('顶部增量载入变高消息时保持当前可见消息位置', (tester) async {
    final key = GlobalKey<_PrependingMessageListHarnessState>();
    await tester.pumpWidget(_PrependingMessageListHarness(key: key));

    final state = key.currentState!;
    final target = find.byKey(const ValueKey<String>('window-message-0'));
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

  testWidgets('等长窗口向前滑动时保持当前可见消息位置', (tester) async {
    final key = GlobalKey<_PrependingMessageListHarnessState>();
    await tester.pumpWidget(_PrependingMessageListHarness(key: key));

    final state = key.currentState!;
    final target = find.byKey(const ValueKey<String>('window-message-0'));
    expect(target, findsOneWidget);
    final topBeforeShift = tester.getTopLeft(target).dy;

    state.shiftWindowEarlier();
    await tester.pumpAndSettle();

    expect(target, findsOneWidget);
    expect(
      tester.getTopLeft(target).dy,
      moreOrLessEquals(topBeforeShift, epsilon: 1),
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

  testWidgets('删除视口上方的消息后保持当前可见消息位置', (tester) async {
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
    final topBeforeDelete = tester.getTopLeft(target).dy;

    // A deletion in the middle of the window is neither a prefix nor a
    // suffix of the old slot list; without an explicit removal diff the list
    // would drop every measured height and drift while re-measuring.
    state.deleteMessage('window-message-5');
    await tester.pumpAndSettle();

    expect(target, findsOneWidget);
    expect(
      tester.getTopLeft(target).dy,
      moreOrLessEquals(topBeforeDelete, epsilon: 1),
    );
  });

  testWidgets('删除视口下方的消息不移动当前可见内容', (tester) async {
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
    final topBeforeDelete = tester.getTopLeft(target).dy;

    state.deleteMessage('window-message-25');
    await tester.pumpAndSettle();

    expect(target, findsOneWidget);
    expect(
      tester.getTopLeft(target).dy,
      moreOrLessEquals(topBeforeDelete, epsilon: 1),
    );
  });

  testWidgets('展开的长思考卡在场时删除消息仍保持可见位置', (tester) async {
    final key = GlobalKey<_PrependingMessageListHarnessState>();
    await tester.pumpWidget(
      _PrependingMessageListHarness(
        key: key,
        initialReasoning: {
          // A tall expanded reasoning card whose height the extent estimator
          // can only approximate; the anchor restore must not inherit that
          // estimation error.
          'window-message-13': stream_ctrl.ReasoningData()
            ..text = List.filled(120, '思考内容行，足够长以撑出很高的思考卡片。').join('\n')
            ..expanded = true
            ..startAt = DateTime(2026, 1, 1)
            ..finishedAt = DateTime(2026, 1, 1, 0, 0, 5),
        },
      ),
    );

    final state = key.currentState!;
    state.listController.jumpToItem(
      index: 15,
      scrollController: state.scrollController,
      alignment: 0.2,
    );
    await tester.pumpAndSettle();

    final target = find.byKey(const ValueKey<String>('window-message-15'));
    expect(target, findsOneWidget);
    final topBeforeDelete = tester.getTopLeft(target).dy;

    state.deleteMessage('window-message-5');
    await tester.pumpAndSettle();

    expect(target, findsOneWidget);
    expect(
      tester.getTopLeft(target).dy,
      moreOrLessEquals(topBeforeDelete, epsilon: 1),
    );
  });

  testWidgets('删除动画将消息淡出收起并拼接相邻消息', (tester) async {
    final key = GlobalKey<_PrependingMessageListHarnessState>();
    await tester.pumpWidget(_PrependingMessageListHarness(key: key));

    final state = key.currentState!;
    state.listController.jumpToItem(
      index: 10,
      scrollController: state.scrollController,
      alignment: 0.2,
    );
    await tester.pumpAndSettle();

    final removing = find.byKey(const ValueKey<String>('window-message-10'));
    final below = find.byKey(const ValueKey<String>('window-message-11'));
    final removingHeight = tester.getSize(removing).height;
    final belowTopBefore = tester.getTopLeft(below).dy;

    state.markRemoving('window-message-10');
    await tester.pump();
    await tester.pump(ChatLayoutConstants.slotRemovalAnimationDuration);

    // The animated slot has collapsed to zero height and the message below
    // has spliced up into its place; the actual data removal afterwards is
    // then invisible.
    expect(tester.getSize(removing).height, lessThan(1));
    expect(
      tester.getTopLeft(below).dy,
      moreOrLessEquals(belowTopBefore - removingHeight, epsilon: 1.5),
    );

    state.deleteMessage('window-message-10');
    await tester.pumpAndSettle();
    expect(removing, findsNothing);
  });
}

class _PrependingMessageListHarness extends StatefulWidget {
  const _PrependingMessageListHarness({
    super.key,
    this.initialReasoning = const <String, stream_ctrl.ReasoningData>{},
  });

  final Map<String, stream_ctrl.ReasoningData> initialReasoning;

  @override
  State<_PrependingMessageListHarness> createState() =>
      _PrependingMessageListHarnessState();
}

class _PrependingMessageListHarnessState
    extends State<_PrependingMessageListHarness> {
  final scrollController = scroll_ctrl.ChatAutoFollowScrollController();
  final listController = ListController();
  final processingFilesMessageId = ValueNotifier<String?>(null);
  final removingSlotIds = <String>{};
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

  void shiftWindowEarlier() {
    setState(() {
      messages = <ChatMessage>[
        for (var index = 0; index < 5; index++)
          ChatMessage(
            id: 'earlier-message-$index',
            role: index.isEven ? 'user' : 'assistant',
            content: 'earlier message $index',
            conversationId: 'conversation-1',
          ),
        ...messages.take(messages.length - 5),
      ];
    });
  }

  void deleteMessage(String id) {
    setState(() {
      messages = [
        for (final message in messages)
          if (message.id != id) message,
      ];
    });
  }

  void markRemoving(String slotId) {
    setState(() => removingSlotIds.add(slotId));
  }

  @override
  void dispose() {
    scrollController.dispose();
    listController.dispose();
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
          appBar: AppBar(),
          body: MessageListView(
            scrollController: scrollController,
            listController: listController,
            messages: messages,
            byGroup: const {},
            versionSelections: const {},
            reasoning: widget.initialReasoning,
            reasoningSegments: const {},
            contentSplits: const {},
            toolParts: const {},
            translations: const {},
            selecting: false,
            selectedItems: const {},
            dividerPadding: EdgeInsets.zero,
            processingFilesMessageId: processingFilesMessageId,
            removingSlotIds: removingSlotIds,
          ),
        ),
      ),
    );
  }
}

Future<void> _pumpEstimatorHarness(
  WidgetTester tester,
  List<ChatMessage> messages,
  ListController listController, {
  double textScale = 1.0,
  bool collapseThinking = true,
  bool wrapCodeBlocks = false,
  Map<String, stream_ctrl.ReasoningData> reasoning =
      const <String, stream_ctrl.ReasoningData>{},
}) async {
  final scrollController = ScrollController();
  final processingFilesMessageId = ValueNotifier<String?>(null);
  addTearDown(scrollController.dispose);
  addTearDown(processingFilesMessageId.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: SettingsProvider(createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider.value(
          value: AssistantProvider(
            preferences: createBusinessTestPreferences(),
          ),
        ),
        ChangeNotifierProvider.value(
          value: TtsProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider.value(
          value: UserProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider.value(value: AskUserInteractionService()),
        ChangeNotifierProvider.value(value: ToolApprovalService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
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
                processingFilesMessageId: processingFilesMessageId,
                collapseThinking: collapseThinking,
                wrapCodeBlocks: wrapCodeBlocks,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

List<ChatMessage> _estimatorMessages(
  String content, {
  String role = 'assistant',
}) {
  return <ChatMessage>[
    for (var i = 0; i < 40; i++)
      ChatMessage(
        id: 'estimator-message-$i',
        role: role,
        content: content,
        conversationId: 'conversation-1',
      ),
  ];
}
