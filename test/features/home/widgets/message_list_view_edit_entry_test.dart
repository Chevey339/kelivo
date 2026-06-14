import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream_ctrl;
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scrollview_observer/scrollview_observer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('all user messages expose edit from long press menu', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final editedMessages = <String>[];
      final messages = <ChatMessage>[
        ChatMessage(
          id: 'user-old',
          role: 'user',
          content: 'old question',
          conversationId: 'conversation-1',
        ),
        ChatMessage(
          id: 'assistant-answer',
          role: 'assistant',
          content: 'answer',
          conversationId: 'conversation-1',
        ),
        ChatMessage(
          id: 'user-latest',
          role: 'user',
          content: 'latest question',
          conversationId: 'conversation-1',
        ),
      ];

      await tester.pumpWidget(
        _MessageListHarness(
          messages: messages,
          onEditMessage: (message) => editedMessages.add(message.id),
        ),
      );

      await tester.longPress(find.text('old question'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('latest question'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(editedMessages, <String>['user-old', 'user-latest']);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _MessageListHarness extends StatefulWidget {
  const _MessageListHarness({
    required this.messages,
    required this.onEditMessage,
  });

  final List<ChatMessage> messages;
  final ValueChanged<ChatMessage> onEditMessage;

  @override
  State<_MessageListHarness> createState() => _MessageListHarnessState();
}

class _MessageListHarnessState extends State<_MessageListHarness> {
  late final ScrollController scrollController;
  late final ListObserverController observerController;
  late final ValueNotifier<bool> isProcessingFiles;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    observerController = ListObserverController(controller: scrollController);
    isProcessingFiles = ValueNotifier<bool>(false);
  }

  @override
  void dispose() {
    scrollController.dispose();
    isProcessingFiles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AssistantProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => TtsProvider()),
        ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ChangeNotifierProvider(create: (_) => ToolApprovalService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageListView(
            scrollController: scrollController,
            observerController: observerController,
            messages: widget.messages,
            byGroup: const {},
            versionSelections: const {},
            reasoning: const <String, stream_ctrl.ReasoningData>{},
            reasoningSegments:
                const <String, List<stream_ctrl.ReasoningSegmentData>>{},
            contentSplits: const <String, stream_ctrl.ContentSplitData>{},
            toolParts: const {},
            translations: const {},
            selecting: false,
            selectedItems: const {},
            dividerPadding: EdgeInsets.zero,
            isProcessingFiles: isProcessingFiles,
            onEditMessage: widget.onEditMessage,
          ),
        ),
      ),
    );
  }
}
