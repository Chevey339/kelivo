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

      expect(find.byKey(MessageListView.windowSkeletonKey), findsOneWidget);
      expect(find.byType(SuperListView), findsOneWidget);

      // The skeleton pulses; it must survive further frames.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(MessageListView.windowSkeletonKey), findsOneWidget);
    } finally {
      scrollController.dispose();
      listController.dispose();
      isProcessingFiles.dispose();
    }
  });

  testWidgets('空窗口非加载态保持空白（无占位）', (tester) async {
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

    state.finishLoad();
    await tester.pump();

    expect(find.byKey(MessageListView.windowSkeletonKey), findsNothing);
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
    }
    expect(find.text('loaded message content'), findsOneWidget);
  });
}

class _PlaceholderHarness extends StatefulWidget {
  const _PlaceholderHarness({
    super.key,
    this.initialLoading = true,
    this.withMessages = false,
  });

  final bool initialLoading;
  final bool withMessages;

  @override
  State<_PlaceholderHarness> createState() => _PlaceholderHarnessState();
}

class _PlaceholderHarnessState extends State<_PlaceholderHarness> {
  final scrollController = scroll_ctrl.ChatAutoFollowScrollController();
  final listController = ListController();
  final isProcessingFiles = ValueNotifier<bool>(false);

  late bool isLoading = widget.initialLoading;
  late List<ChatMessage> messages = widget.withMessages
      ? _buildMessages()
      : const <ChatMessage>[];

  static List<ChatMessage> _buildMessages() {
    return <ChatMessage>[
      ChatMessage(
        id: 'history-message-0',
        role: 'assistant',
        content: 'loaded message content',
        conversationId: 'conversation-1',
      ),
    ];
  }

  void finishLoad() {
    setState(() {
      isLoading = false;
      messages = _buildMessages();
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
          ),
        ),
      ),
    );
  }
}
