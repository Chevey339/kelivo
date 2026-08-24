import "../support/business_test_harness.dart";

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart'
    as scroll_ctrl;
import 'package:Kelivo/features/home/controllers/streaming_content_notifier.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _id = 'streaming-msg';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('streaming tick cost as the tool count grows', (tester) async {
    tester.view.physicalSize = const Size(1170, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey<_HState>();
    await tester.pumpWidget(_H(key: key));
    await tester.pump(const Duration(milliseconds: 100));
    final s = key.currentState!;

    for (var round = 0; round < 30; round++) {
      // A tool call appears, then 10 text ticks stream in.
      final add = Stopwatch()..start();
      s.addTool(round);
      await tester.pump(const Duration(milliseconds: 16));
      add.stop();
      // Frames while the AnimatedSize transitions run.
      final anim = Stopwatch()..start();
      for (var f = 0; f < 18; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      anim.stop();

      final tickSw = Stopwatch()..start();
      for (var i = 0; i < 10; i++) {
        s.tick(i);
        await tester.pump(const Duration(milliseconds: 16));
      }
      tickSw.stop();
      if (round % 5 == 0 || round == 29) {
        // ignore: avoid_print
        print(
          'RESULT tools=${round + 1} '
          'toolAppearMs=${(add.elapsedMicroseconds / 1000).toStringAsFixed(2)} '
          'animFrameMs=${(anim.elapsedMicroseconds / 18 / 1000).toStringAsFixed(2)} '
          'textTickMs=${(tickSw.elapsedMicroseconds / 10 / 1000).toStringAsFixed(2)}',
        );
      }
    }
  });
}

class _H extends StatefulWidget {
  const _H({super.key});
  @override
  State<_H> createState() => _HState();
}

class _HState extends State<_H> {
  final scrollController = scroll_ctrl.ChatAutoFollowScrollController();
  final notifier = StreamingContentNotifier();
  late final scroll_ctrl.ChatScrollController scrollCtrl;
  final isProcessingFiles = ValueNotifier<bool>(false);
  final tools = <ToolUIPart>[];

  late final List<ChatMessage> messages = <ChatMessage>[
    ChatMessage(
      id: _id,
      role: 'assistant',
      content: '',
      conversationId: 'c1',
      isStreaming: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    scrollCtrl = scroll_ctrl.ChatScrollController(
      scrollController: scrollController,
      onStateChanged: () {},
      getAutoScrollEnabled: () => true,
      getAutoScrollIdleSeconds: () => 3,
      isGenerating: () => true,
    );
    notifier.getNotifier(_id);
  }

  void addTool(int i) {
    tools.add(
      ToolUIPart(
        id: 'tool-$i',
        toolName: 'read_file',
        arguments: {'path': 'lib/x_$i.dart'},
        content: '工具结果 $i',
        loading: false,
      ),
    );
    setState(() {});
    notifier.notifyToolPartsUpdated(_id);
  }

  void tick(int i) => notifier.updateContent(_id, '思考中' * (i + 1), 1);

  @override
  void dispose() {
    scrollCtrl.dispose();
    scrollController.dispose();
    notifier.dispose();
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
            listController: scrollCtrl.messageListController,
            messages: messages,
            byGroup: const {},
            versionSelections: const {},
            reasoning: const {},
            reasoningSegments: const {},
            contentSplits: const {},
            toolParts: {_id: List<ToolUIPart>.of(tools)},
            translations: const {},
            selecting: false,
            selectedItems: const {},
            dividerPadding: EdgeInsets.zero,
            isProcessingFiles: isProcessingFiles,
            streamingContentNotifier: notifier,
            onUserScrollIntent: scrollCtrl.handleUserScrollIntent,
          ),
        ),
      ),
    );
  }
}
