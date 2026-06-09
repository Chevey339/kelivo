import 'dart:ui';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream_ctrl;
import 'package:Kelivo/features/home/controllers/streaming_content_notifier.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scrollview_observer/scrollview_observer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('消息列表底部留白使用传入的输入框覆盖高度', (tester) async {
    final scrollController = ScrollController();
    final observerController = ListObserverController(
      controller: scrollController,
    );
    final isProcessingFiles = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageListView(
            scrollController: scrollController,
            observerController: observerController,
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

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect((listView.padding as EdgeInsets).bottom, 144);

    scrollController.dispose();
    isProcessingFiles.dispose();
  });

  testWidgets('消息列表顶部留白使用传入的导航栏覆盖高度', (tester) async {
    final scrollController = ScrollController();
    final observerController = ListObserverController(
      controller: scrollController,
    );
    final isProcessingFiles = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageListView(
            scrollController: scrollController,
            observerController: observerController,
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

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect((listView.padding as EdgeInsets).top, 88);
    expect((listView.padding as EdgeInsets).bottom, 144);

    scrollController.dispose();
    isProcessingFiles.dispose();
  });

  testWidgets('置顶流式指示器激活时保留额外底部空间', (tester) async {
    final scrollController = ScrollController();
    final observerController = ListObserverController(
      controller: scrollController,
    );
    final isProcessingFiles = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageListView(
            scrollController: scrollController,
            observerController: observerController,
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

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect((listView.padding as EdgeInsets).bottom, 156);

    scrollController.dispose();
    isProcessingFiles.dispose();
  });

  testWidgets('流式思考更新缺少起始时间时保留已有计时起点', (tester) async {
    final scrollController = ScrollController();
    final observerController = ListObserverController(
      controller: scrollController,
    );
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
              observerController: observerController,
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
    isProcessingFiles.dispose();
    streamingNotifier.dispose();
  });

  testWidgets('思考卡内部滚动不暂停流式正文更新', (tester) async {
    final scrollController = ScrollController();
    final observerController = ListObserverController(
      controller: scrollController,
    );
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
              observerController: observerController,
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
    isProcessingFiles.dispose();
    streamingNotifier.dispose();
  });

  testWidgets('用户拖动离开底部时暂停应用流式内容更新', (tester) async {
    final scrollController = ScrollController();
    final observerController = ListObserverController(
      controller: scrollController,
    );
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
              observerController: observerController,
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
      tester.getCenter(find.byType(ListView)),
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

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('updated while dragging'), findsOneWidget);

    scrollController.dispose();
    isProcessingFiles.dispose();
    streamingNotifier.dispose();
  });

  testWidgets('贴近底部时用户滚动不暂停应用流式内容更新', (tester) async {
    final scrollController = ScrollController();
    final observerController = ListObserverController(
      controller: scrollController,
    );
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
              observerController: observerController,
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
      tester.getCenter(find.byType(ListView)),
    );
    await gesture.moveBy(const Offset(0, 8));
    await tester.pump();

    streamingNotifier.updateContent(
      'bottom-streaming-message',
      'updated while still near bottom',
      3,
    );
    await tester.pump();

    expect(find.text('updated while still near bottom'), findsOneWidget);

    await gesture.up();

    scrollController.dispose();
    isProcessingFiles.dispose();
    streamingNotifier.dispose();
  });

  testWidgets('滚轮滚动时暂停应用流式内容更新', (tester) async {
    final scrollController = ScrollController();
    final observerController = ListObserverController(
      controller: scrollController,
    );
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
              observerController: observerController,
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
      pointer.hover(tester.getCenter(find.byType(ListView))),
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
    isProcessingFiles.dispose();
    streamingNotifier.dispose();
  });

  testWidgets('向上懒加载超长消息时保留当前可见锚点', (tester) async {
    final scrollController = ChatAutoFollowScrollController();
    final observerController = ListObserverController(
      controller: scrollController,
    );
    final isProcessingFiles = ValueNotifier<bool>(false);

    ChatMessage longMessage(int index) {
      return ChatMessage(
        id: 'message-$index',
        role: index.isEven ? 'user' : 'assistant',
        content: [
          'debug-message-index: $index',
          for (var block = 0; block < 80; block++)
            '这是一段用于复现超大对话渲染卡顿的长调试文本。index=$index block=$block',
        ].join('\n'),
        conversationId: 'conversation-1',
      );
    }

    var messages = <ChatMessage>[for (var i = 20; i < 60; i++) longMessage(i)];
    var loadCalls = 0;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: SettingsProvider()),
          ChangeNotifierProvider.value(value: AssistantProvider()),
          ChangeNotifierProvider.value(value: TtsProvider()),
          ChangeNotifierProvider.value(value: UserProvider()),
          ChangeNotifierProvider.value(value: AskUserInteractionService()),
          ChangeNotifierProvider.value(value: ToolApprovalService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: MessageListView(
                  scrollController: scrollController,
                  observerController: observerController,
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
                  hasMoreBefore: true,
                  onLoadMoreBefore: ({String? keepMessageId}) {
                    expect(keepMessageId, 'message-20');
                    setState(() {
                      messages = <ChatMessage>[
                        for (var i = 0; i < 20; i++) longMessage(i),
                        ...messages,
                      ];
                    });
                    loadCalls++;
                    return true;
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    scrollController.jumpTo(40);
    await tester.pump();

    ScrollUpdateNotification(
      metrics: scrollController.position,
      context: tester.element(find.byType(ListView)),
      scrollDelta: -80,
      dragDetails: DragUpdateDetails(
        globalPosition: tester.getCenter(find.byType(ListView)),
        delta: const Offset(0, 80),
        primaryDelta: 80,
      ),
    ).dispatch(tester.element(find.byType(ListView)));
    await tester.pump();
    await tester.pump();

    expect(loadCalls, 1);
    expect(scrollController.offset, greaterThan(1200));

    final restoredOffset = scrollController.offset;
    await tester.pump();
    expect(scrollController.offset, restoredOffset);

    scrollController.dispose();
    isProcessingFiles.dispose();
  });

  testWidgets('向上懒加载估算少补偿时不做二次可见跳动', (tester) async {
    final scrollController = ChatAutoFollowScrollController();
    final observerController = ListObserverController(
      controller: scrollController,
    );
    final isProcessingFiles = ValueNotifier<bool>(false);

    ChatMessage message(String id, String content) {
      return ChatMessage(
        id: id,
        role: 'assistant',
        content: content,
        conversationId: 'conversation-1',
      );
    }

    final tallPreviousContent = List<String>.generate(
      120,
      (index) => '短行 $index',
    ).join('\n');
    final compactAnchorContent = List<String>.filled(
      12,
      '这是一行用于作为锚点的长文本。',
    ).join();
    var messages = <ChatMessage>[
      message('anchor', compactAnchorContent),
      for (var i = 0; i < 40; i++) message('after-$i', compactAnchorContent),
    ];
    var loadCalls = 0;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: SettingsProvider()),
          ChangeNotifierProvider.value(value: AssistantProvider()),
          ChangeNotifierProvider.value(value: TtsProvider()),
          ChangeNotifierProvider.value(value: UserProvider()),
          ChangeNotifierProvider.value(value: AskUserInteractionService()),
          ChangeNotifierProvider.value(value: ToolApprovalService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: MessageListView(
                  scrollController: scrollController,
                  observerController: observerController,
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
                  hasMoreBefore: true,
                  onLoadMoreBefore: ({String? keepMessageId}) {
                    expect(keepMessageId, 'anchor');
                    setState(() {
                      messages = <ChatMessage>[
                        message('previous', tallPreviousContent),
                        ...messages,
                      ];
                    });
                    loadCalls++;
                    return true;
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    scrollController.jumpTo(40);
    await tester.pump();
    final anchorFinder = find.byKey(const ValueKey('anchor')).first;
    final originalAnchorTop = tester.getTopLeft(anchorFinder).dy;

    ScrollUpdateNotification(
      metrics: scrollController.position,
      context: tester.element(find.byType(ListView)),
      scrollDelta: -80,
      dragDetails: DragUpdateDetails(
        globalPosition: tester.getCenter(find.byType(ListView)),
        delta: const Offset(0, 80),
        primaryDelta: 80,
      ),
    ).dispatch(tester.element(find.byType(ListView)));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(loadCalls, 1);
    final restoredAnchorTop = tester.getTopLeft(anchorFinder).dy;
    expect((restoredAnchorTop - originalAnchorTop).abs(), lessThan(600));
    final restoredOffset = scrollController.offset;
    await tester.pump();
    expect(scrollController.offset, restoredOffset);

    scrollController.dispose();
    isProcessingFiles.dispose();
  });

  testWidgets('向上懒加载锚点前已有消息时按真实 prepend 前缀补偿', (tester) async {
    final scrollController = ChatAutoFollowScrollController();
    final observerController = ListObserverController(
      controller: scrollController,
    );
    final isProcessingFiles = ValueNotifier<bool>(false);

    ChatMessage message(String id, String content) {
      return ChatMessage(
        id: id,
        role: 'assistant',
        content: content,
        conversationId: 'conversation-1',
      );
    }

    final tallPrependedContent = List<String>.generate(
      120,
      (index) => '新增历史长消息 block=$index 这是一段长调试文本。',
    ).join('\n');
    final shortExistingContent = 'old-before';
    final anchorContent = List<String>.generate(
      90,
      (index) => 'debug-message-index: 1104 block=$index 这是一段长调试文本。',
    ).join('\n');
    var messages = <ChatMessage>[
      message('old-before', shortExistingContent),
      message('anchor', anchorContent),
      for (var i = 0; i < 40; i++) message('after-$i', anchorContent),
    ];
    var loadCalls = 0;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: SettingsProvider()),
          ChangeNotifierProvider.value(value: AssistantProvider()),
          ChangeNotifierProvider.value(value: TtsProvider()),
          ChangeNotifierProvider.value(value: UserProvider()),
          ChangeNotifierProvider.value(value: AskUserInteractionService()),
          ChangeNotifierProvider.value(value: ToolApprovalService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: MessageListView(
                  scrollController: scrollController,
                  observerController: observerController,
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
                  hasMoreBefore: true,
                  onLoadMoreBefore: ({String? keepMessageId}) {
                    expect(keepMessageId, 'old-before');
                    setState(() {
                      messages = <ChatMessage>[
                        message('new-history', tallPrependedContent),
                        ...messages,
                      ];
                    });
                    loadCalls++;
                    return true;
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    scrollController.jumpTo(40);
    await tester.pump();
    final oldBeforeTop = tester
        .getTopLeft(find.byKey(const ValueKey('old-before')).first)
        .dy;

    ScrollUpdateNotification(
      metrics: scrollController.position,
      context: tester.element(find.byType(ListView)),
      scrollDelta: -80,
      dragDetails: DragUpdateDetails(
        globalPosition: tester.getCenter(find.byType(ListView)),
        delta: const Offset(0, 80),
        primaryDelta: 80,
      ),
    ).dispatch(tester.element(find.byType(ListView)));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(loadCalls, 1);
    final restoredOldBeforeTop = tester
        .getTopLeft(find.byKey(const ValueKey('old-before')).first)
        .dy;
    expect((restoredOldBeforeTop - oldBeforeTop).abs(), lessThan(600));

    scrollController.dispose();
    isProcessingFiles.dispose();
  });
  testWidgets('向上懒加载版本组锚点 id 变化时按 group 保持位置', (tester) async {
    final scrollController = ChatAutoFollowScrollController();
    final observerController = ListObserverController(
      controller: scrollController,
    );
    final isProcessingFiles = ValueNotifier<bool>(false);

    ChatMessage versioned(String id, int version, String content) {
      return ChatMessage(
        id: id,
        role: 'assistant',
        content: content,
        conversationId: 'conversation-1',
        groupId: 'anchor-group',
        version: version,
      );
    }

    ChatMessage regular(String id, String content) {
      return ChatMessage(
        id: id,
        role: 'assistant',
        content: content,
        conversationId: 'conversation-1',
      );
    }

    final longContent = List<String>.generate(
      90,
      (index) => 'debug-message-index: 1103 block=$index 这是一段长调试文本。',
    ).join('\n');
    var messages = <ChatMessage>[
      versioned('anchor-v2', 2, longContent),
      regular('after', longContent),
    ];
    var loadCalls = 0;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: SettingsProvider()),
          ChangeNotifierProvider.value(value: AssistantProvider()),
          ChangeNotifierProvider.value(value: TtsProvider()),
          ChangeNotifierProvider.value(value: UserProvider()),
          ChangeNotifierProvider.value(value: AskUserInteractionService()),
          ChangeNotifierProvider.value(value: ToolApprovalService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: MessageListView(
                  scrollController: scrollController,
                  observerController: observerController,
                  messages: messages,
                  byGroup: const {},
                  versionSelections: const {'anchor-group': 2},
                  reasoning: const {},
                  reasoningSegments: const {},
                  contentSplits: const {},
                  toolParts: const {},
                  translations: const {},
                  selecting: false,
                  selectedItems: const {},
                  dividerPadding: EdgeInsets.zero,
                  isProcessingFiles: isProcessingFiles,
                  hasMoreBefore: true,
                  onLoadMoreBefore: ({String? keepMessageId}) {
                    expect(keepMessageId, 'anchor-v2');
                    setState(() {
                      messages = <ChatMessage>[
                        regular('previous', longContent),
                        versioned('anchor-v0', 0, longContent),
                        regular('after', longContent),
                      ];
                    });
                    loadCalls++;
                    return true;
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    scrollController.jumpTo(40);
    await tester.pump();

    ScrollUpdateNotification(
      metrics: scrollController.position,
      context: tester.element(find.byType(ListView)),
      scrollDelta: -80,
      dragDetails: DragUpdateDetails(
        globalPosition: tester.getCenter(find.byType(ListView)),
        delta: const Offset(0, 80),
        primaryDelta: 80,
      ),
    ).dispatch(tester.element(find.byType(ListView)));
    await tester.pump();
    await tester.pump();

    expect(loadCalls, 1);
    expect(scrollController.offset, greaterThan(1000));

    scrollController.dispose();
    isProcessingFiles.dispose();
  });
}
