import "../../../support/business_test_harness.dart";

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart'
    as scroll_ctrl;
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/file_processing_indicator.dart';
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

  testWidgets('解析文件条只出现在正在解析的那条助手消息上', (tester) async {
    final scrollController = scroll_ctrl.ChatAutoFollowScrollController();
    final listController = ListController();
    final processingFilesMessageId = ValueNotifier<String?>(null);
    addTearDown(scrollController.dispose);
    addTearDown(listController.dispose);
    addTearDown(processingFilesMessageId.dispose);

    await tester.pumpWidget(
      _harness(
        scrollController: scrollController,
        listController: listController,
        processingFilesMessageId: processingFilesMessageId,
      ),
    );
    await tester.pump();

    expect(find.byType(FileProcessingIndicator), findsNothing);

    processingFilesMessageId.value = 'assistant-2';
    await tester.pump();

    expect(find.byType(FileProcessingIndicator), findsOneWidget);
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is ChatMessageWidget && widget.message.id == 'assistant-2',
        ),
        matching: find.byType(FileProcessingIndicator),
      ),
      findsOneWidget,
    );

    processingFilesMessageId.value = null;
    await tester.pump();

    expect(find.byType(FileProcessingIndicator), findsNothing);
  });
}

Widget _harness({
  required scroll_ctrl.ChatAutoFollowScrollController scrollController,
  required ListController listController,
  required ValueNotifier<String?> processingFilesMessageId,
}) {
  final messages = <ChatMessage>[
    ChatMessage(
      id: 'user-1',
      role: 'user',
      content: 'first question',
      conversationId: 'conversation-1',
    ),
    ChatMessage(
      id: 'assistant-1',
      role: 'assistant',
      content: 'first answer',
      conversationId: 'conversation-1',
    ),
    ChatMessage(
      id: 'user-2',
      role: 'user',
      content: 'second question',
      conversationId: 'conversation-1',
    ),
    ChatMessage(
      id: 'assistant-2',
      role: 'assistant',
      content: 'second answer',
      conversationId: 'conversation-1',
    ),
  ];

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
          processingFilesMessageId: processingFilesMessageId,
        ),
      ),
    ),
  );
}
