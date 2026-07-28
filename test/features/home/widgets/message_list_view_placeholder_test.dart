import "../../../support/business_test_harness.dart";

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart'
    as scroll_ctrl;
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
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

  testWidgets('冷加载空窗口显示气泡骨架占位', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final isProcessingFiles = ValueNotifier<bool>(false);

    try {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
              isLoadingWindow: true,
            ),
          ),
        ),
      );

      expect(
        find.byKey(MessageListView.windowSkeletonKey),
        findsOneWidget,
      );
      expect(
        find.byKey(MessageListView.emptyConversationKey),
        findsNothing,
      );
      expect(find.byType(SuperListView), findsOneWidget);

      // The skeleton pulses; it must survive further frames without
      // transitioning to the empty state.
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(MessageListView.windowSkeletonKey),
        findsOneWidget,
      );
      expect(
        find.byKey(MessageListView.emptyConversationKey),
        findsNothing,
      );
    } finally {
      scrollController.dispose();
      listController.dispose();
      isProcessingFiles.dispose();
    }
  });

  testWidgets('空会话显示空状态占位而非骨架', (tester) async {
    final scrollController = ScrollController();
    final listController = ListController();
    final isProcessingFiles = ValueNotifier<bool>(false);

    try {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

      expect(
        find.byKey(MessageListView.emptyConversationKey),
        findsOneWidget,
      );
      expect(find.byKey(MessageListView.windowSkeletonKey), findsNothing);
      expect(find.byType(SuperListView), findsOneWidget);
    } finally {
      scrollController.dispose();
      listController.dispose();
      isProcessingFiles.dispose();
    }
  });

  testWidgets('窗口载入完成后骨架切换为消息内容', (tester) async {
    final key = GlobalKey<_PlaceholderHarnessState>();
    await tester.pumpWidget(_PlaceholderHarness(key: key));
    final state = key.currentState!;

    expect(find.byKey(MessageListView.windowSkeletonKey), findsOneWidget);
    expect(find.byKey(MessageListView.emptyConversationKey), findsNothing);

    state.finishLoad();
    await tester.pump();

    expect(find.byKey(MessageListView.windowSkeletonKey), findsNothing);
    expect(find.byKey(MessageListView.emptyConversationKey), findsNothing);
    expect(find.text('loaded message content'), findsOneWidget);
  });

  testWidgets('快路径命中已有消息时不显示骨架', (tester) async {
    final key = GlobalKey<_PlaceholderHarnessState>();
    await tester.pumpWidget(
      _PlaceholderHarness(key: key, initialLoading: false, withMessages: true),
    );

    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(MessageListView.windowSkeletonKey), findsNothing);
      expect(find.byKey(MessageListView.emptyConversationKey), findsNothing);
    }
    expect(find.text('loaded message content'), findsOneWidget);
  });

  testWidgets('hasMoreBefore 时列表顶部显示固定高度 loading 行', (tester) async {
    final key = GlobalKey<_PlaceholderHarnessState>();
    await tester.pumpWidget(
      _PlaceholderHarness(
        key: key,
        initialLoading: false,
        withMessages: true,
        hasMoreBefore: true,
      ),
    );
    await tester.pump();

    final loadingRow = find.byKey(
      const ValueKey<String>(MessageListView.loadingBeforeSlotKey),
    );
    expect(loadingRow, findsOneWidget);
    expect(tester.getSize(loadingRow).height, 56);
    // The row sits above the first message slot.
    final firstMessage = find.byKey(const ValueKey<String>('history-message-0'));
    expect(firstMessage, findsOneWidget);
    expect(
      tester.getTopLeft(loadingRow).dy,
      lessThan(tester.getTopLeft(firstMessage).dy),
    );
  });

  testWidgets('翻页保留 loading 行时前置插入保持滚动位置稳定', (tester) async {
    final key = GlobalKey<_PlaceholderHarnessState>();
    await tester.pumpWidget(
      _PlaceholderHarness(
        key: key,
        initialLoading: false,
        withMessages: true,
        hasMoreBefore: true,
        messageCount: 30,
      ),
    );
    final state = key.currentState!;

    state.listController.jumpToItem(
      index: 16,
      scrollController: state.scrollController,
      alignment: 0.2,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final target = find.byKey(const ValueKey<String>('history-message-15'));
    expect(target, findsOneWidget);
    final topBeforePrepend = tester.getTopLeft(target).dy;

    state.prependMessages(keepHasMoreBefore: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(target, findsOneWidget);
    expect(
      tester.getTopLeft(target).dy,
      moreOrLessEquals(topBeforePrepend, epsilon: 1),
    );

    // The loading row survives the prepend at the top of the list.
    state.scrollController.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey<String>(MessageListView.loadingBeforeSlotKey)),
      findsOneWidget,
    );
  });

  testWidgets('最后一页载入后移除 loading 行且滚动位置稳定', (tester) async {
    final key = GlobalKey<_PlaceholderHarnessState>();
    await tester.pumpWidget(
      _PlaceholderHarness(
        key: key,
        initialLoading: false,
        withMessages: true,
        hasMoreBefore: true,
        messageCount: 30,
      ),
    );
    final state = key.currentState!;

    state.listController.jumpToItem(
      index: 16,
      scrollController: state.scrollController,
      alignment: 0.2,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final target = find.byKey(const ValueKey<String>('history-message-15'));
    expect(target, findsOneWidget);
    final topBeforeFinalPage = tester.getTopLeft(target).dy;

    state.prependMessages(keepHasMoreBefore: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(target, findsOneWidget);
    expect(
      tester.getTopLeft(target).dy,
      moreOrLessEquals(topBeforeFinalPage, epsilon: 1),
    );

    // The loading row is gone once the final page has been prepended.
    state.scrollController.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey<String>(MessageListView.loadingBeforeSlotKey)),
      findsNothing,
    );
  });
}

class _PlaceholderHarness extends StatefulWidget {
  const _PlaceholderHarness({
    super.key,
    this.initialLoading = true,
    this.withMessages = false,
    this.hasMoreBefore = false,
    this.messageCount = 1,
  });

  final bool initialLoading;
  final bool withMessages;
  final bool hasMoreBefore;
  final int messageCount;

  @override
  State<_PlaceholderHarness> createState() => _PlaceholderHarnessState();
}

class _PlaceholderHarnessState extends State<_PlaceholderHarness> {
  final scrollController = scroll_ctrl.ChatAutoFollowScrollController();
  final listController = ListController();
  final isProcessingFiles = ValueNotifier<bool>(false);

  late bool isLoading = widget.initialLoading;
  late bool hasMoreBefore = widget.hasMoreBefore;
  late List<ChatMessage> messages = widget.withMessages
      ? _buildMessages(widget.messageCount)
      : const <ChatMessage>[];

  static List<ChatMessage> _buildMessages(int count) {
    if (count == 1) {
      return <ChatMessage>[
        ChatMessage(
          id: 'history-message-0',
          role: 'assistant',
          content: 'loaded message content',
          conversationId: 'conversation-1',
        ),
      ];
    }
    return <ChatMessage>[
      for (var index = 0; index < count; index++)
        ChatMessage(
          id: 'history-message-$index',
          role: index.isEven ? 'user' : 'assistant',
          content: List<String>.filled(
            1 + index % 5,
            'variable height line $index',
          ).join('\n'),
          conversationId: 'conversation-1',
        ),
    ];
  }

  void finishLoad() {
    setState(() {
      isLoading = false;
      messages = _buildMessages(1);
    });
  }

  void prependMessages({required bool keepHasMoreBefore}) {
    setState(() {
      hasMoreBefore = keepHasMoreBefore;
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
            isLoadingWindow: isLoading,
            hasMoreBefore: hasMoreBefore,
          ),
        ),
      ),
    );
  }
}
