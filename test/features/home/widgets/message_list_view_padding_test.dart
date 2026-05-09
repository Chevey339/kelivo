import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/controllers/chat_scroll_position.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
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
