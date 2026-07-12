import 'dart:ui';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream_ctrl;
import 'package:Kelivo/features/home/controllers/streaming_content_notifier.dart';
import 'package:Kelivo/features/home/controllers/timeline_coordinator.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scrollview_observer/scrollview_observer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('macOS 消息列表滚动不主动清除文本选区焦点', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final scrollController = ScrollController();
    final observerController = ListObserverController(
      controller: scrollController,
    );
    final isProcessingFiles = ValueNotifier<bool>(false);

    try {
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
            ),
          ),
        ),
      );

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(
        listView.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.manual,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      scrollController.dispose();
      isProcessingFiles.dispose();
    }
  });

  testWidgets('Android 消息列表滚动仍然收起键盘', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final scrollController = ScrollController();
    final observerController = ListObserverController(
      controller: scrollController,
    );
    final isProcessingFiles = ValueNotifier<bool>(false);

    try {
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
            ),
          ),
        ),
      );

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(
        listView.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      scrollController.dispose();
      isProcessingFiles.dispose();
    }
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

  testWidgets('程序定位完成后在生成终态前保持底部定位空间', (tester) async {
    final scrollController = ScrollController();
    final observerController = ListObserverController(
      controller: scrollController,
    );
    final isProcessingFiles = ValueNotifier<bool>(false);
    final streamingNotifier = StreamingContentNotifier();
    final messages = <ChatMessage>[
      ChatMessage(
        id: 'new-user-slot',
        role: 'user',
        content: 'new question',
        conversationId: 'conversation-1',
      ),
      ChatMessage(
        id: 'streaming-assistant-slot',
        role: 'assistant',
        content: '',
        conversationId: 'conversation-1',
        isStreaming: true,
      ),
    ];
    streamingNotifier.getNotifier('streaming-assistant-slot');
    final coordinator = TimelineCoordinator(
      loadPage:
          ({
            required conversationId,
            beforeRevisionId,
            afterRevisionId,
            fromStart,
            required limit,
          }) async => null,
    );
    coordinator.programmaticJump('new-user-slot');
    coordinator.noteContentChanged(isGenerating: true);

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
          home: Scaffold(
            body: ListenableBuilder(
              listenable: coordinator,
              builder: (context, child) => MessageListView(
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
                timelineCoordinator: coordinator,
                streamingContentNotifier: streamingNotifier,
              ),
            ),
          ),
        ),
      ),
    );

    double bottomPadding() {
      final listView = tester.widget<ListView>(find.byType(ListView));
      return (listView.padding as EdgeInsets).bottom;
    }

    final maximumReservedBottom =
        16 + tester.getSize(find.byType(ListView)).height * 0.75;
    expect(bottomPadding(), maximumReservedBottom);

    await tester.pump();
    expect(coordinator.programmaticTargetSlotId, isNull);
    final shortReplyPadding = bottomPadding();
    expect(shortReplyPadding, lessThan(maximumReservedBottom));
    expect(shortReplyPadding, greaterThan(16));
    final userTop = tester.getTopLeft(find.text('new question')).dy;
    expect(
      userTop,
      lessThan(tester.getSize(find.byType(ListView)).height * 0.35),
    );

    streamingNotifier.updateContent(
      'streaming-assistant-slot',
      List.generate(80, (index) => 'reply line $index').join('\n\n'),
      0,
    );
    await tester.pump();
    expect(bottomPadding(), shortReplyPadding);
    await tester.pump();
    expect(bottomPadding(), shortReplyPadding);
    expect(
      tester.getTopLeft(find.text('new question')).dy,
      closeTo(userTop, 1),
    );

    coordinator.noteContentChanged(isGenerating: false);
    await tester.pump();
    expect(bottomPadding(), lessThanOrEqualTo(shortReplyPadding));
    expect(
      tester.getTopLeft(find.text('new question')).dy,
      closeTo(userTop, 1),
    );

    coordinator.followTail();
    await tester.pump();
    scrollController.jumpTo(scrollController.position.maxScrollExtent / 2);
    await tester.pump();
    final listContext = tester.element(find.byType(ListView));
    UserScrollNotification(
      metrics: scrollController.position,
      context: listContext,
      direction: ScrollDirection.reverse,
    ).dispatch(listContext);
    await tester.pump();
    expect(coordinator.viewportMode, TimelineViewportMode.followingTail);

    expect(bottomPadding(), 16);

    await tester.pumpWidget(const SizedBox.shrink());
    coordinator.dispose();
    scrollController.dispose();
    isProcessingFiles.dispose();
    streamingNotifier.dispose();
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
}
