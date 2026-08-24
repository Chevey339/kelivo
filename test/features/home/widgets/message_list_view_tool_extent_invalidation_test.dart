import "../../../support/business_test_harness.dart";

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('tool height events coalesce by messageId and bump version', () async {
    final notifier = StreamingContentNotifier();
    addTearDown(notifier.dispose);

    final seen = <ToolHeightEvent>[];
    notifier.toolHeightEvents.addListener(() {
      final event = notifier.toolHeightEvents.value;
      if (event != null) seen.add(event);
    });

    notifier.notifyToolHeightChanged('m1');
    notifier.notifyToolHeightChanged('m1');
    notifier.notifyToolHeightChanged('m2');
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(2));
    expect(seen.map((e) => e.messageId), ['m1', 'm2']);
    expect(seen[1].version, greaterThan(seen[0].version));
  });

  testWidgets('streaming tool event invalidates the cached extent', (
    tester,
  ) async {
    final notifier = StreamingContentNotifier();
    addTearDown(notifier.dispose);
    notifier.getNotifier('stream-1');

    final message = ChatMessage(
      id: 'stream-1',
      role: 'assistant',
      content: '',
      conversationId: 'conversation-1',
      isStreaming: true,
    );
    final toolParts = <String, List<ToolUIPart>>{
      'stream-1': const <ToolUIPart>[],
    };

    await tester.pumpWidget(
      _Harness(notifier: notifier, messages: [message], toolParts: toolParts),
    );
    await tester.pump();

    final list = tester.widget<SuperListView>(find.byType(SuperListView));
    final empty = list.extentEstimation!(0, 400);
    expect(empty, 96);

    toolParts['stream-1'] = [
      for (var i = 0; i < 8; i++)
        ToolUIPart(
          id: 't$i',
          toolName: 'read_file',
          arguments: {'path': '$i.dart'},
          content: 'ok',
        ),
    ];
    notifier.notifyToolPartsUpdated('stream-1');
    await tester.pump();

    final after = list.extentEstimation!(0, 400);
    expect(after, closeTo(96 + 8 * 44.0, 0.1));
    expect(after, isNot(empty));
  });

  testWidgets('recovered tool signature change invalidates without oldWidget', (
    tester,
  ) async {
    final key = GlobalKey<_HarnessState>();
    final message = ChatMessage(
      id: 'hist-1',
      role: 'assistant',
      content: '',
      conversationId: 'conversation-1',
    );

    await tester.pumpWidget(
      _Harness(
        key: key,
        messages: [message],
        toolParts: {
          'hist-1': const [
            ToolUIPart(
              id: 'ask',
              toolName: 'ask_user_input_v0',
              arguments: {},
              loading: true,
            ),
          ],
        },
      ),
    );
    await tester.pump();

    final list = tester.widget<SuperListView>(find.byType(SuperListView));
    final loading = list.extentEstimation!(0, 400);

    key.currentState!.replaceTools({
      'hist-1': const [
        ToolUIPart(
          id: 'ask',
          toolName: 'ask_user_input_v0',
          arguments: {
            'questions': [
              {
                'id': 'q1',
                'question': 'Ready?',
                'type': 'single',
                'options': ['Yes', 'No'],
              },
            ],
          },
          content: '{"answers":{}}',
        ),
      ],
    });
    await tester.pump();

    final answered = tester
        .widget<SuperListView>(find.byType(SuperListView))
        .extentEstimation!(0, 400);
    expect(answered, isNot(loading));
  });
}

class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    required this.messages,
    required this.toolParts,
    this.notifier,
  });

  final List<ChatMessage> messages;
  final Map<String, List<ToolUIPart>> toolParts;
  final StreamingContentNotifier? notifier;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late final ScrollController scrollController;
  late final ListController listController;
  late final ValueNotifier<bool> isProcessingFiles;
  late Map<String, List<ToolUIPart>> toolParts;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    listController = ListController();
    isProcessingFiles = ValueNotifier<bool>(false);
    // Share the same mutable map as production: stream updates replace the
    // list in place instead of rebuilding MessageListView.
    toolParts = widget.toolParts;
  }

  void replaceTools(Map<String, List<ToolUIPart>> next) {
    setState(() => toolParts = next);
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
              UserProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              TtsProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ChangeNotifierProvider(create: (_) => ToolApprovalService()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageListView(
            scrollController: scrollController,
            listController: listController,
            messages: widget.messages,
            byGroup: const {},
            versionSelections: const {},
            reasoning: const <String, stream_ctrl.ReasoningData>{},
            reasoningSegments:
                const <String, List<stream_ctrl.ReasoningSegmentData>>{},
            contentSplits: const <String, stream_ctrl.ContentSplitData>{},
            toolParts: toolParts,
            translations: const {},
            selecting: false,
            selectedItems: const {},
            dividerPadding: EdgeInsets.zero,
            isProcessingFiles: isProcessingFiles,
            streamingContentNotifier: widget.notifier,
          ),
        ),
      ),
    );
  }
}
