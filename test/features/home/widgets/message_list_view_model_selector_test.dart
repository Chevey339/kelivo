import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/home/controllers/message_render_model.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream_ctrl;
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

ChatMessage _assistant({
  required String id,
  required String groupId,
  required int version,
  required String providerId,
  required String modelId,
  required String content,
}) {
  return ChatMessage(
    id: id,
    role: 'assistant',
    content: content,
    conversationId: 'conversation-1',
    groupId: groupId,
    version: version,
    providerId: providerId,
    modelId: modelId,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'multi-target group shows horizontal model buttons with real sparse versions and statuses',
    (tester) async {
      final selected = _assistant(
        id: 'answer-v2',
        groupId: 'answer',
        version: 2,
        providerId: 'provider-a',
        modelId: 'shared-model',
        content: 'selected answer',
      );
      final failed = _assistant(
        id: 'answer-v7',
        groupId: 'answer',
        version: 7,
        providerId: 'provider-b',
        modelId: 'shared-model',
        content: 'partial failed answer',
      );
      final cancelled = _assistant(
        id: 'answer-v11',
        groupId: 'answer',
        version: 11,
        providerId: 'provider-c',
        modelId: 'other-model',
        content: 'partial cancelled answer',
      );
      final byGroup = <String, List<ChatMessage>>{
        'answer': [cancelled, selected, failed],
      };
      final renderModels = MessageRenderModelProjector.project(
        messages: [selected],
        byGroup: byGroup,
        versionSelections: const {'answer': 2},
        generationStates: const {
          'answer-v7': GenerationRunState.failed,
          'answer-v11': GenerationRunState.cancelled,
        },
        contextDividerIndex: -1,
      );
      final versionChanges = <(String, int)>[];

      await tester.pumpWidget(
        _MessageListHarness(
          messages: [selected],
          byGroup: byGroup,
          versionSelections: const {'answer': 2},
          renderModels: renderModels,
          onVersionChange: (groupId, version) async {
            versionChanges.add((groupId, version));
          },
        ),
      );
      await tester.pump();

      final selector = find.byKey(
        const ValueKey<String>('model-answer-selector:answer'),
      );
      expect(selector, findsOneWidget);
      expect(
        tester.widget<SingleChildScrollView>(selector).scrollDirection,
        Axis.horizontal,
      );
      expect(
        find.byKey(const ValueKey<String>('model-answer:2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('model-answer:7')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('model-answer:11')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Failed')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Cancelled')), findsOneWidget);
      expect(find.text('1/3'), findsNothing);

      tester
          .widget<InkWell>(find.byKey(const ValueKey<String>('model-answer:7')))
          .onTap
          ?.call();
      await tester.pump();

      expect(versionChanges, [('answer', 7)]);
    },
  );

  testWidgets(
    'same-target revisions keep legacy arrows and omit model selector',
    (tester) async {
      final selected = _assistant(
        id: 'answer-v2',
        groupId: 'answer',
        version: 2,
        providerId: 'provider-a',
        modelId: 'same-model',
        content: 'first answer',
      );
      final next = _assistant(
        id: 'answer-v7',
        groupId: 'answer',
        version: 7,
        providerId: 'provider-a',
        modelId: 'same-model',
        content: 'second answer',
      );
      final byGroup = <String, List<ChatMessage>>{
        'answer': [next, selected],
      };
      final renderModels = MessageRenderModelProjector.project(
        messages: [selected],
        byGroup: byGroup,
        versionSelections: const {'answer': 2},
        contextDividerIndex: -1,
      );
      final versionChanges = <(String, int)>[];

      await tester.pumpWidget(
        _MessageListHarness(
          messages: [selected],
          byGroup: byGroup,
          versionSelections: const {'answer': 2},
          renderModels: renderModels,
          onVersionChange: (groupId, version) async {
            versionChanges.add((groupId, version));
          },
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('model-answer-selector:answer')),
        findsNothing,
      );
      expect(find.text('1/2'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is IosIconButton && widget.icon == Lucide.ChevronLeft,
        ),
        findsOneWidget,
      );
      final nextButton = find.byWidgetPredicate(
        (widget) =>
            widget is IosIconButton && widget.icon == Lucide.ChevronRight,
      );
      expect(nextButton, findsOneWidget);

      tester.widget<IosIconButton>(nextButton).onTap?.call();
      await tester.pump();

      expect(versionChanges, [('answer', 7)]);
    },
  );
}

class _MessageListHarness extends StatefulWidget {
  const _MessageListHarness({
    required this.messages,
    required this.byGroup,
    required this.versionSelections,
    required this.renderModels,
    required this.onVersionChange,
  });

  final List<ChatMessage> messages;
  final Map<String, List<ChatMessage>> byGroup;
  final Map<String, int> versionSelections;
  final List<MessageRenderModel> renderModels;
  final OnVersionChange onVersionChange;

  @override
  State<_MessageListHarness> createState() => _MessageListHarnessState();
}

class _MessageListHarnessState extends State<_MessageListHarness> {
  late final ScrollController scrollController;
  late final ListController listController;
  late final ValueNotifier<bool> isProcessingFiles;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    listController = ListController();
    isProcessingFiles = ValueNotifier<bool>(false);
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
            listController: listController,
            messages: widget.messages,
            renderModels: widget.renderModels,
            byGroup: widget.byGroup,
            versionSelections: widget.versionSelections,
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
            onVersionChange: widget.onVersionChange,
          ),
        ),
      ),
    );
  }
}
