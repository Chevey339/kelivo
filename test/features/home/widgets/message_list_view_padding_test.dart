import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/controllers/chat_scroll_position.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/features/home/controllers/streaming_content_notifier.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _harness(Widget child) {
  SharedPreferences.setMockInitialValues({});
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ChangeNotifierProvider(create: (_) => AssistantProvider()),
      ChangeNotifierProvider(create: (_) => UserProvider()),
      ChangeNotifierProvider(create: (_) => TtsProvider()),
      ChangeNotifierProvider(create: (_) => ToolApprovalService()),
      ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
      ChangeNotifierProvider(create: (_) => ChatService()),
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

  testWidgets('消息列表底部留白使用传入的输入框覆盖高度', (tester) async {
    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
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
    );

    final listView = tester.widget<MessageListView>(
      find.byType(MessageListView),
    );
    expect(listView.bottomContentPadding, 144);

    isProcessingFiles.dispose();
  });

  testWidgets('置顶流式指示器激活时保留额外底部空间', (tester) async {
    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
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
    );

    final listView = tester.widget<MessageListView>(
      find.byType(MessageListView),
    );
    expect(listView.bottomContentPadding, 144);
    expect(listView.isPinnedIndicatorActive, isTrue);

    isProcessingFiles.dispose();
  });

  testWidgets('iOS 消息列表使用原生弹性滚动物理', (tester) async {
    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);

    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        _harness(
          MessageListView(
            scrollControllers: scrollControllers,
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
      );

      final list = tester.widget<ScrollablePositionedList>(
        find.byType(ScrollablePositionedList),
      );
      expect(list.physics, isA<BouncingScrollPhysics>());
      expect(
        (list.physics! as BouncingScrollPhysics).parent,
        isA<AlwaysScrollableScrollPhysics>(),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }

    isProcessingFiles.dispose();
  });

  testWidgets('超大对话初始打开只构建底部附近的消息', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);
    final builtIndexes = <int>{};
    final messages = List<ChatMessage>.generate(
      5000,
      (index) => ChatMessage(
        id: 'message-$index',
        role: index.isEven ? 'user' : 'assistant',
        content: 'Message $index',
        conversationId: 'conversation-1',
      ),
    );

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
          itemBuildObserver: builtIndexes.add,
        ),
      ),
    );

    await tester.pump();

    final list = tester.widget<ScrollablePositionedList>(
      find.byType(ScrollablePositionedList),
    );
    expect(list.initialScrollIndex, messages.length);
    expect(list.initialAlignment, closeTo(1 - 144 / 844, 0.001));
    expect(list.minCacheExtent, closeTo(720, 0.001));
    expect(builtIndexes, isNotEmpty);
    expect(builtIndexes.contains(messages.length), isTrue);
    expect(
      builtIndexes.any((index) => index >= 4980 && index < messages.length),
      isTrue,
    );
    expect(builtIndexes.any((index) => index < 4900), isFalse);
    expect(builtIndexes.length, lessThan(120));

    isProcessingFiles.dispose();
  });

  testWidgets('短对话初始打开直接顶对齐避免先显示在底部', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);
    final messages = <ChatMessage>[
      ChatMessage(
        id: 'user-1',
        role: 'user',
        content: 'Short user message',
        conversationId: 'conversation-1',
      ),
      ChatMessage(
        id: 'assistant-1',
        role: 'assistant',
        content: 'Short assistant message',
        conversationId: 'conversation-1',
      ),
    ];

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
    );

    await tester.pump();

    final list = tester.widget<ScrollablePositionedList>(
      find.byType(ScrollablePositionedList),
    );
    expect(list.initialScrollIndex, 0);
    expect(list.initialAlignment, 0);

    isProcessingFiles.dispose();
  });

  testWidgets('消息列表接收滚轮事件时通知用户滚动意图', (tester) async {
    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);
    var userScrollIntentCount = 0;
    ChatUserScrollIntentDirection? lastIntentDirection;
    final messages = List<ChatMessage>.generate(
      80,
      (index) => ChatMessage(
        id: 'message-$index',
        role: index.isEven ? 'user' : 'assistant',
        content: 'Message $index',
        conversationId: 'conversation-1',
      ),
    );

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
          onUserScrollIntent: (direction) {
            userScrollIntentCount++;
            lastIntentDirection = direction;
          },
        ),
      ),
    );

    await tester.pump();
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(200, 300),
        scrollDelta: Offset(0, -120),
      ),
    );
    await tester.pump();

    expect(userScrollIntentCount, 1);
    expect(lastIntentDirection, ChatUserScrollIntentDirection.towardTop);

    isProcessingFiles.dispose();
  });

  testWidgets('消息列表指针按下立即通知控制器暂停程序化滚动', (tester) async {
    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);
    var pointerDownCount = 0;
    var pointerUpCount = 0;
    var userScrollIntentCount = 0;
    final messages = List<ChatMessage>.generate(
      24,
      (index) => ChatMessage(
        id: 'message-$index',
        role: index.isEven ? 'user' : 'assistant',
        content: 'Message $index',
        conversationId: 'conversation-1',
      ),
    );

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
          onUserScrollPointerDown: () {
            pointerDownCount++;
          },
          onUserScrollPointerUp: () {
            pointerUpCount++;
          },
          onUserScrollIntent: (_) {
            userScrollIntentCount++;
          },
        ),
      ),
    );

    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ScrollablePositionedList)),
    );
    await tester.pump();

    expect(pointerDownCount, 1);
    expect(userScrollIntentCount, 0);

    await gesture.up();
    await tester.pump();

    expect(pointerUpCount, 1);

    isProcessingFiles.dispose();
  });

  testWidgets('相同消息列表重建时复用已构建消息子树', (tester) async {
    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);
    var rebuildTick = 0;
    final messages = <ChatMessage>[
      ChatMessage(
        id: 'assistant-mermaid',
        role: 'assistant',
        content: '```dart\nfinal value = 1;\n```',
        conversationId: 'conversation-1',
      ),
    ];

    Widget buildList() {
      return _harness(
        StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    rebuildTick++;
                  }),
                  child: Text('rebuild $rebuildTick'),
                ),
                Expanded(
                  child: MessageListView(
                    scrollControllers: scrollControllers,
                    messages: messages,
                    byGroup: {
                      for (final message in messages) message.id: [message],
                    },
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
                    bottomContentPadding: 120,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    await tester.pumpWidget(buildList());
    await tester.pump();

    final before = tester.widget<ChatMessageWidget>(
      find.byType(ChatMessageWidget).first,
    );

    await tester.tap(find.byType(TextButton));
    await tester.pump();

    final after = tester.widget<ChatMessageWidget>(
      find.byType(ChatMessageWidget).first,
    );

    expect(identical(after, before), isTrue);

    isProcessingFiles.dispose();
  });

  testWidgets('消息内容变化时重建消息子树', (tester) async {
    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);
    var content = '```dart\nfinal value = 1;\n```';

    Widget buildList() {
      return _harness(
        StatefulBuilder(
          builder: (context, setState) {
            final messages = <ChatMessage>[
              ChatMessage(
                id: 'assistant-code',
                role: 'assistant',
                content: content,
                conversationId: 'conversation-1',
              ),
            ];
            return Column(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    content = '```dart\nfinal value = 2;\n```';
                  }),
                  child: const Text('update content'),
                ),
                Expanded(
                  child: MessageListView(
                    scrollControllers: scrollControllers,
                    messages: messages,
                    byGroup: {
                      for (final message in messages) message.id: [message],
                    },
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
                    bottomContentPadding: 120,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    await tester.pumpWidget(buildList());
    await tester.pump();

    final before = tester.widget<ChatMessageWidget>(
      find.byType(ChatMessageWidget).first,
    );

    await tester.tap(find.byType(TextButton));
    await tester.pump();

    final after = tester.widget<ChatMessageWidget>(
      find.byType(ChatMessageWidget).first,
    );

    expect(identical(after, before), isFalse);
    expect(after.message.content, contains('value = 2'));

    isProcessingFiles.dispose();
  });

  testWidgets('消息列表拖动时只通知一次用户滚动意图', (tester) async {
    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);
    var userScrollIntentCount = 0;
    ChatUserScrollIntentDirection? lastIntentDirection;
    final messages = List<ChatMessage>.generate(
      80,
      (index) => ChatMessage(
        id: 'message-$index',
        role: index.isEven ? 'user' : 'assistant',
        content: 'Message $index',
        conversationId: 'conversation-1',
      ),
    );

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
          onUserScrollIntent: (direction) {
            userScrollIntentCount++;
            lastIntentDirection = direction;
          },
        ),
      ),
    );

    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ScrollablePositionedList)),
    );
    await gesture.moveBy(const Offset(0, 24));
    await gesture.moveBy(const Offset(0, 24));
    await gesture.up();
    await tester.pump();

    expect(userScrollIntentCount, 1);
    expect(lastIntentDirection, ChatUserScrollIntentDirection.towardTop);

    isProcessingFiles.dispose();
  });

  testWidgets('消息列表水平滑动不会触发用户滚动意图', (tester) async {
    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);
    var userScrollIntentCount = 0;
    final messages = List<ChatMessage>.generate(
      80,
      (index) => ChatMessage(
        id: 'message-$index',
        role: index.isEven ? 'user' : 'assistant',
        content: 'Message $index',
        conversationId: 'conversation-1',
      ),
    );

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
          onUserScrollIntent: (_) {
            userScrollIntentCount++;
          },
        ),
      ),
    );

    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ScrollablePositionedList)),
    );
    await gesture.moveBy(const Offset(28, 1));
    await gesture.moveBy(const Offset(28, 1));
    await gesture.up();
    await tester.pump();

    expect(userScrollIntentCount, 0);

    isProcessingFiles.dispose();
  });

  testWidgets('代码块交互时消息列表仍保持可滚动', (tester) async {
    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);
    final codeLines = List<String>.generate(40, (index) => 'code-line-$index');
    final messages = <ChatMessage>[
      ChatMessage(
        id: 'assistant-code',
        role: 'assistant',
        content:
            '''
```dart
${codeLines.join('\n')}
```
''',
        conversationId: 'conversation-1',
      ),
    ];

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
          bottomContentPadding: 120,
        ),
      ),
    );

    await tester.pump();

    final codeBlockFinder = find.byType(SelectableText);
    expect(codeBlockFinder, findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(codeBlockFinder),
    );
    await tester.pump();

    final list = tester.widget<ScrollablePositionedList>(
      find.byType(ScrollablePositionedList),
    );
    expect(list.physics, isNot(isA<NeverScrollableScrollPhysics>()));

    await gesture.up();
    await tester.pump();

    isProcessingFiles.dispose();
  });

  testWidgets('真实消息列表拖动会停止控制器后续流式贴底', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);
    var bottomAnchorAlignment = 1.0;
    final messages = List<ChatMessage>.generate(
      24,
      (index) => ChatMessage(
        id: 'message-$index',
        role: index.isEven ? 'user' : 'assistant',
        content: List.filled(20, 'Message $index').join('\n'),
        conversationId: 'conversation-1',
        isStreaming: index == 23,
      ),
    );
    late final ChatScrollController chatScrollController;
    chatScrollController = ChatScrollController(
      indexedControllers: scrollControllers,
      onStateChanged: () {},
      getShouldAutoStickToBottom: () {
        if (chatScrollController.isUserScrolling) return false;
        if (!chatScrollController.hasEnoughContentToScroll(56.0)) return true;
        return chatScrollController.isNearBottom(48);
      },
      getAutoScrollEnabled: () => true,
      getItemCount: () => messages.length,
      getBottomAnchorAlignment: () => bottomAnchorAlignment,
    );

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
          bottomContentPadding: 120,
          onBottomAnchorAlignmentChanged: (value) {
            bottomAnchorAlignment = value;
          },
          onUserScrollIntent: chatScrollController.handleUserScrollIntent,
          onStreamingMessageContentChanged: (_, __) {
            chatScrollController.autoScrollToBottomIfNeeded();
          },
        ),
      ),
    );

    await tester.pump();
    expect(chatScrollController.autoStickToBottom, isTrue);

    await tester.drag(
      find.byType(ScrollablePositionedList),
      const Offset(0, 160),
    );
    await tester.pump(const Duration(milliseconds: 240));
    expect(chatScrollController.autoStickToBottom, isFalse);

    chatScrollController.autoScrollToBottomIfNeeded();
    await tester.pump();
    expect(chatScrollController.autoStickToBottom, isFalse);

    chatScrollController.dispose();
    isProcessingFiles.dispose();
  });

  testWidgets('真实消息列表手动滚回底部后恢复流式贴底', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scrollControllers = ChatIndexedScrollControllers();
    final streamingContentNotifier = StreamingContentNotifier();
    final isProcessingFiles = ValueNotifier<bool>(false);
    var bottomAnchorAlignment = 1.0;
    final messages = List<ChatMessage>.generate(
      24,
      (index) => ChatMessage(
        id: 'message-$index',
        role: index.isEven ? 'user' : 'assistant',
        content: List.filled(16, 'Message $index').join('\n'),
        conversationId: 'conversation-1',
        isStreaming: index == 23,
      ),
    );
    streamingContentNotifier.getNotifier('message-23');
    late final ChatScrollController chatScrollController;
    chatScrollController = ChatScrollController(
      indexedControllers: scrollControllers,
      onStateChanged: () {},
      getShouldAutoStickToBottom: () {
        if (chatScrollController.isUserScrolling) return false;
        if (!chatScrollController.hasEnoughContentToScroll(56.0)) return true;
        return chatScrollController.isNearBottom(48);
      },
      getAutoScrollEnabled: () => true,
      getItemCount: () => messages.length,
      getBottomAnchorAlignment: () => bottomAnchorAlignment,
    );

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
          bottomContentPadding: 120,
          streamingContentNotifier: streamingContentNotifier,
          onBottomAnchorAlignmentChanged: (value) {
            bottomAnchorAlignment = value;
          },
          onUserScrollIntent: chatScrollController.handleUserScrollIntent,
          onStreamingMessageContentChanged: (_, __) {
            chatScrollController.autoScrollToBottomIfNeeded();
          },
        ),
      ),
    );

    await tester.pump();
    expect(chatScrollController.autoStickToBottom, isTrue);

    await tester.drag(
      find.byType(ScrollablePositionedList),
      const Offset(0, 160),
    );
    await tester.pump(const Duration(milliseconds: 240));
    expect(chatScrollController.autoStickToBottom, isFalse);

    for (
      var i = 0;
      i == 0 || (i < 12 && !chatScrollController.isNearBottom());
      i++
    ) {
      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -600),
      );
      await tester.pump(const Duration(milliseconds: 240));
    }

    expect(chatScrollController.isNearBottom(), isTrue);
    expect(chatScrollController.autoStickToBottom, isTrue);

    streamingContentNotifier.updateContent(
      'message-23',
      List.filled(80, 'Long streaming line').join('\n'),
      80,
    );
    chatScrollController.autoScrollToBottomIfNeeded();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();

    final bottomAnchor = _positionFor(scrollControllers, messages.length);
    expect(bottomAnchor.itemTrailingEdge, closeTo(1, 0.03));
    expect(chatScrollController.autoStickToBottom, isTrue);

    chatScrollController.dispose();
    streamingContentNotifier.dispose();
    isProcessingFiles.dispose();
  });

  testWidgets('首条流式内容通过局部 notifier 变高时继续贴底', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scrollControllers = ChatIndexedScrollControllers();
    final streamingContentNotifier = StreamingContentNotifier();
    final isProcessingFiles = ValueNotifier<bool>(false);
    var bottomAnchorAlignment = 1.0;
    final messages = <ChatMessage>[
      ChatMessage(
        id: 'streaming-0',
        role: 'assistant',
        content: 'Short answer',
        conversationId: 'conversation-1',
        isStreaming: true,
      ),
    ];
    streamingContentNotifier.getNotifier('streaming-0');

    late final ChatScrollController chatScrollController;
    chatScrollController = ChatScrollController(
      indexedControllers: scrollControllers,
      onStateChanged: () {},
      getShouldAutoStickToBottom: () {
        if (chatScrollController.isUserScrolling) return false;
        if (!chatScrollController.hasEnoughContentToScroll(56.0)) return true;
        return chatScrollController.isNearBottom(48);
      },
      getAutoScrollEnabled: () => true,
      getItemCount: () => messages.length,
      getBottomAnchorAlignment: () => bottomAnchorAlignment,
    );

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
          bottomContentPadding: 120,
          streamingContentNotifier: streamingContentNotifier,
          onBottomAnchorAlignmentChanged: (value) {
            bottomAnchorAlignment = value;
          },
          onUserScrollIntent: chatScrollController.handleUserScrollIntent,
          onStreamingMessageContentChanged: (_, __) {
            chatScrollController.autoScrollToBottomIfNeeded();
          },
        ),
      ),
    );
    await tester.pump();
    expect(chatScrollController.autoStickToBottom, isTrue);

    streamingContentNotifier.updateContent(
      'streaming-0',
      List.filled(80, 'Streaming line').join('\n'),
      80,
    );
    chatScrollController.autoScrollToBottomIfNeeded();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 160));

    final bottomAnchor = _positionFor(scrollControllers, messages.length);
    expect(bottomAnchor.itemTrailingEdge, closeTo(1, 0.03));
    expect(chatScrollController.autoStickToBottom, isTrue);

    chatScrollController.dispose();
    streamingContentNotifier.dispose();
    isProcessingFiles.dispose();
  });

  testWidgets('首条普通消息重建变高时继续贴底', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);
    var bottomAnchorAlignment = 1.0;
    var firstMessage = ChatMessage(
      id: 'user-0',
      role: 'user',
      content: 'Short prompt',
      conversationId: 'conversation-1',
    );

    late final ChatScrollController chatScrollController;
    chatScrollController = ChatScrollController(
      indexedControllers: scrollControllers,
      onStateChanged: () {},
      getShouldAutoStickToBottom: () {
        if (chatScrollController.isUserScrolling) return false;
        if (!chatScrollController.hasEnoughContentToScroll(56.0)) return true;
        return chatScrollController.isNearBottom(48);
      },
      getAutoScrollEnabled: () => true,
      getItemCount: () => 1,
      getBottomAnchorAlignment: () => bottomAnchorAlignment,
    );

    Widget buildList() {
      final messages = <ChatMessage>[firstMessage];
      return _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
          bottomContentPadding: 120,
          onBottomAnchorAlignmentChanged: (value) {
            bottomAnchorAlignment = value;
          },
          onUserScrollIntent: chatScrollController.handleUserScrollIntent,
        ),
      );
    }

    await tester.pumpWidget(buildList());
    await tester.pump();
    expect(chatScrollController.autoStickToBottom, isTrue);

    firstMessage = firstMessage.copyWith(
      content: List.filled(80, 'Long prompt line').join('\n'),
    );
    chatScrollController.followBottomAfterContentChange();
    await tester.pumpWidget(buildList());
    chatScrollController.autoScrollToBottomIfNeeded();
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }

    final bottomAnchor = _positionFor(scrollControllers, 1);
    expect(bottomAnchor.itemTrailingEdge, closeTo(1, 0.03));
    expect(chatScrollController.autoStickToBottom, isTrue);

    chatScrollController.dispose();
    isProcessingFiles.dispose();
  });

  testWidgets('首个用户消息后的首条流式回复变高时继续贴底', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scrollControllers = ChatIndexedScrollControllers();
    final streamingContentNotifier = StreamingContentNotifier();
    final isProcessingFiles = ValueNotifier<bool>(false);
    var bottomAnchorAlignment = 1.0;
    final messages = <ChatMessage>[
      ChatMessage(
        id: 'user-0',
        role: 'user',
        content: 'First prompt',
        conversationId: 'conversation-1',
      ),
      ChatMessage(
        id: 'assistant-0',
        role: 'assistant',
        content: 'Short answer',
        conversationId: 'conversation-1',
        isStreaming: true,
      ),
    ];
    streamingContentNotifier.getNotifier('assistant-0');

    late final ChatScrollController chatScrollController;
    chatScrollController = ChatScrollController(
      indexedControllers: scrollControllers,
      onStateChanged: () {},
      getShouldAutoStickToBottom: () {
        if (chatScrollController.isUserScrolling) return false;
        if (!chatScrollController.hasEnoughContentToScroll(56.0)) return true;
        return chatScrollController.isNearBottom(48);
      },
      getAutoScrollEnabled: () => true,
      getItemCount: () => messages.length,
      getBottomAnchorAlignment: () => bottomAnchorAlignment,
    );

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
          bottomContentPadding: 120,
          streamingContentNotifier: streamingContentNotifier,
          onBottomAnchorAlignmentChanged: (value) {
            bottomAnchorAlignment = value;
          },
          onUserScrollIntent: chatScrollController.handleUserScrollIntent,
        ),
      ),
    );
    await tester.pump();
    expect(chatScrollController.autoStickToBottom, isTrue);

    for (var step = 0; step < 4; step++) {
      streamingContentNotifier.updateContent(
        'assistant-0',
        List.filled(30 + step * 20, 'Streaming line').join('\n'),
        30 + step * 20,
      );
      chatScrollController.autoScrollToBottomIfNeeded();
      await tester.pump();
      await tester.pump();
    }

    final bottomAnchor = _positionFor(scrollControllers, messages.length);
    expect(bottomAnchor.itemTrailingEdge, closeTo(1, 0.03));
    expect(chatScrollController.autoStickToBottom, isTrue);

    chatScrollController.dispose();
    streamingContentNotifier.dispose();
    isProcessingFiles.dispose();
  });

  testWidgets('用户上滑后流式内容变高不会把阅读位置继续上推', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scrollControllers = ChatIndexedScrollControllers();
    final streamingContentNotifier = StreamingContentNotifier();
    final isProcessingFiles = ValueNotifier<bool>(false);
    var bottomAnchorAlignment = 1.0;
    final messages = List<ChatMessage>.generate(
      8,
      (index) => ChatMessage(
        id: 'message-$index',
        role: index.isEven ? 'user' : 'assistant',
        content: List.filled(8, 'Message $index').join('\n'),
        conversationId: 'conversation-1',
        isStreaming: index == 7,
      ),
    );
    streamingContentNotifier.getNotifier('message-7');

    late final ChatScrollController chatScrollController;
    chatScrollController = ChatScrollController(
      indexedControllers: scrollControllers,
      onStateChanged: () {},
      getShouldAutoStickToBottom: () {
        if (chatScrollController.isUserScrolling) return false;
        if (!chatScrollController.hasEnoughContentToScroll(56.0)) return true;
        return chatScrollController.isNearBottom(48);
      },
      getAutoScrollEnabled: () => true,
      getItemCount: () => messages.length,
      getBottomAnchorAlignment: () => bottomAnchorAlignment,
    );

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
          bottomContentPadding: 120,
          streamingContentNotifier: streamingContentNotifier,
          onBottomAnchorAlignmentChanged: (value) {
            bottomAnchorAlignment = value;
          },
          onUserScrollIntent: chatScrollController.handleUserScrollIntent,
        ),
      ),
    );
    await tester.pump();
    expect(chatScrollController.isNearBottom(), isTrue);

    await tester.drag(
      find.byType(ScrollablePositionedList),
      const Offset(0, 180),
    );
    await tester.pump(const Duration(milliseconds: 240));
    expect(chatScrollController.autoStickToBottom, isFalse);

    final streamingBefore = _positionFor(scrollControllers, 7).itemLeadingEdge;

    streamingContentNotifier.updateContent(
      'message-7',
      List.filled(80, 'Long streaming line').join('\n'),
      80,
    );
    chatScrollController.autoScrollToBottomIfNeeded();
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }

    final streamingAfter = _positionFor(scrollControllers, 7).itemLeadingEdge;
    expect(streamingAfter, closeTo(streamingBefore, 0.05));
    expect(chatScrollController.autoStickToBottom, isFalse);

    chatScrollController.dispose();
    streamingContentNotifier.dispose();
    isProcessingFiles.dispose();
  });

  testWidgets('真实消息列表停手后记录阅读锚点不会无动画改动顶部位置', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);
    final messages = List<ChatMessage>.generate(
      40,
      (index) => ChatMessage(
        id: 'message-$index',
        role: index.isEven ? 'user' : 'assistant',
        content: List.filled(3, 'Message $index').join('\n'),
        conversationId: 'conversation-1',
      ),
    );

    late final ChatScrollController chatScrollController;
    chatScrollController = ChatScrollController(
      indexedControllers: scrollControllers,
      onStateChanged: () {},
      getShouldAutoStickToBottom: () {
        if (chatScrollController.isUserScrolling) return false;
        return chatScrollController.isNearBottom(48);
      },
      getAutoScrollEnabled: () => true,
      getItemCount: () => messages.length,
      getBottomAnchorAlignment: () => 1,
    );

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
          bottomContentPadding: 120,
          onUserScrollIntent: chatScrollController.handleUserScrollIntent,
        ),
      ),
    );
    await tester.pump();

    scrollControllers.itemScrollController.jumpTo(index: 0, alignment: 0.02);
    await tester.pump();
    chatScrollController.handleUserScrollIntent(
      ChatUserScrollIntentDirection.towardTop,
    );
    await tester.pump();
    final before = _positionFor(scrollControllers, 0).itemLeadingEdge;

    await tester.pump(const Duration(milliseconds: 240));
    await tester.pump();

    final after = _positionFor(scrollControllers, 0).itemLeadingEdge;
    expect(after, closeTo(before, 0.02));

    chatScrollController.dispose();
    isProcessingFiles.dispose();
  });

  testWidgets('可见消息状态恢复不会因同一列表重建重复触发', (tester) async {
    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);
    final messages = List<ChatMessage>.generate(
      40,
      (index) => ChatMessage(
        id: 'message-$index',
        role: index.isEven ? 'user' : 'assistant',
        content: 'Message $index',
        conversationId: 'conversation-1',
      ),
    );
    final visibleCalls = <String>[];

    Widget buildList() {
      return _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
          onMessageVisible: (message, index) {
            visibleCalls.add(message.id);
          },
        ),
      );
    }

    await tester.pumpWidget(buildList());
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    final firstCallCount = visibleCalls.length;
    expect(firstCallCount, greaterThan(0));

    await tester.pumpWidget(buildList());
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }

    expect(visibleCalls.length, firstCallCount);

    isProcessingFiles.dispose();
  });

  testWidgets('消息列表保持正向滚动而不是反向列表', (tester) async {
    final scrollControllers = ChatIndexedScrollControllers();
    final isProcessingFiles = ValueNotifier<bool>(false);
    final messages = List<ChatMessage>.generate(
      3,
      (index) => ChatMessage(
        id: 'message-$index',
        role: index.isEven ? 'user' : 'assistant',
        content: 'Message $index',
        conversationId: 'conversation-1',
      ),
    );

    await tester.pumpWidget(
      _harness(
        MessageListView(
          scrollControllers: scrollControllers,
          messages: messages,
          byGroup: {
            for (final message in messages) message.id: [message],
          },
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
    );

    final list = tester.widget<ScrollablePositionedList>(
      find.byType(ScrollablePositionedList),
    );
    expect(list.reverse, isFalse);

    isProcessingFiles.dispose();
  });
}

ItemPosition _positionFor(
  ChatIndexedScrollControllers scrollControllers,
  int index,
) {
  return scrollControllers.itemPositionsListener.itemPositions.value.firstWhere(
    (position) => position.index == index,
  );
}
