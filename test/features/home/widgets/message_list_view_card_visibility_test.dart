import "../../../support/business_test_harness.dart";

import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/assistant_regex.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/chat/widgets/timeline_projection.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream_ctrl;
import 'package:Kelivo/features/home/controllers/streaming_content_notifier.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';
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

  testWidgets('height estimate strips hidden <think> content', (tester) async {
    final thinking = List.filled(120, 'long hidden reasoning line').join('\n');
    final tagged = '<think>$thinking</think>Short answer.';

    final hidden = await _estimateExtent(
      tester,
      message: ChatMessage(
        id: 'think-hidden',
        role: 'assistant',
        content: tagged,
        conversationId: 'conversation-1',
      ),
      showThinkingCards: false,
    );
    final shown = await _estimateExtent(
      tester,
      message: ChatMessage(
        id: 'think-shown',
        role: 'assistant',
        content: tagged,
        conversationId: 'conversation-1',
      ),
      showThinkingCards: true,
    );
    final rawThinking = await _estimateExtent(
      tester,
      message: ChatMessage(
        id: 'think-raw',
        role: 'assistant',
        content: thinking,
        conversationId: 'conversation-1',
      ),
      showThinkingCards: false,
    );

    expect(hidden, lessThan(shown));
    expect(hidden, lessThan(rawThinking * 0.25));
    expect(hidden, lessThan(400));
  });

  testWidgets('height estimate excludes hidden standalone tool messages', (
    tester,
  ) async {
    final toolContent = jsonEncode({
      'tool': 'search_web',
      'arguments': <String, dynamic>{},
      'result': List.filled(80, 'huge standalone tool result line').join('\n'),
    });
    final askUserContent = jsonEncode({
      'tool': LocalToolNames.askUser,
      'arguments': {
        'questions': [
          {
            'id': 'scope',
            'question': 'Choose scope?',
            'type': 'single',
            'options': ['Minimal', 'Complete'],
          },
        ],
      },
      'result': '',
    });

    final hidden = await _estimateExtent(
      tester,
      message: ChatMessage(
        id: 'tool-hidden',
        role: 'tool',
        content: toolContent,
        conversationId: 'conversation-1',
      ),
      showToolCards: false,
    );
    final shown = await _estimateExtent(
      tester,
      message: ChatMessage(
        id: 'tool-shown',
        role: 'tool',
        content: toolContent,
        conversationId: 'conversation-1',
      ),
      showToolCards: true,
    );
    final askUserHidden = await _estimateExtent(
      tester,
      message: ChatMessage(
        id: 'tool-ask-user',
        role: 'tool',
        content: askUserContent,
        conversationId: 'conversation-1',
      ),
      showToolCards: false,
    );

    expect(hidden, 0);
    expect(shown, greaterThan(400));
    expect(askUserHidden, greaterThan(0));
  });

  testWidgets('height estimate includes collapsed inline tool cards', (
    tester,
  ) async {
    final tools = <ToolUIPart>[
      for (var i = 0; i < 12; i++)
        ToolUIPart(
          id: 'tool-$i',
          toolName: 'read_file',
          arguments: {'path': 'lib/foo_$i.dart'},
          content: 'tool result $i',
        ),
    ];
    final message = ChatMessage(
      id: 'tools-only',
      role: 'assistant',
      content: '',
      conversationId: 'conversation-1',
    );

    final empty = await _estimateExtent(tester, message: message);
    final withTools = await _estimateExtent(
      tester,
      message: message,
      toolParts: {'tools-only': tools},
    );
    final hiddenTools = await _estimateExtent(
      tester,
      message: message,
      toolParts: {'tools-only': tools},
      showToolCards: false,
    );
    final withSummary = await _estimateExtent(
      tester,
      message: message,
      toolParts: {
        'tools-only': [
          ToolUIPart(
            id: 'search-1',
            toolName: 'search_web',
            arguments: {'query': 'kelivo'},
            content: List.filled(8, 'summary line that wraps a bit').join('\n'),
          ),
        ],
      },
      showToolResultSummary: true,
    );
    final headerOnly = await _estimateExtent(
      tester,
      message: message,
      toolParts: {
        'tools-only': [
          ToolUIPart(
            id: 'search-1',
            toolName: 'search_web',
            arguments: {'query': 'kelivo'},
            content: List.filled(8, 'summary line that wraps a bit').join('\n'),
          ),
        ],
      },
    );

    expect(empty, 96);
    expect(withTools, closeTo(96 + 12 * 44.0, 0.1));
    expect(hiddenTools, 96);
    expect(withSummary, greaterThan(headerOnly));
  });

  testWidgets('height estimate collapses 30 tools to last 2 plus expand row', (
    tester,
  ) async {
    final tools = <ToolUIPart>[
      for (var i = 0; i < 30; i++)
        ToolUIPart(
          id: 'tool-$i',
          toolName: 'read_file',
          arguments: {'path': 'lib/foo_$i.dart'},
          content: 'ok',
        ),
    ];
    final message = ChatMessage(
      id: 'tools-collapse',
      role: 'assistant',
      content: '',
      conversationId: 'conversation-1',
    );

    final collapsed = await _estimateExtent(
      tester,
      message: message,
      toolParts: {'tools-collapse': tools},
      collapseThinkingSteps: true,
    );
    final expanded = await _estimateExtent(
      tester,
      message: message,
      toolParts: {'tools-collapse': tools},
    );

    expect(collapsed, closeTo(96 + 36 + 2 * 44.0, 0.1));
    expect(expanded, closeTo(96 + 30 * 44.0, 0.1));
    expect(collapsed, lessThan(expanded * 0.25));
  });

  testWidgets('builtin_search-only tools add no timeline height', (
    tester,
  ) async {
    final message = ChatMessage(
      id: 'builtin-only',
      role: 'assistant',
      content: '',
      conversationId: 'conversation-1',
    );
    final empty = await _estimateExtent(tester, message: message);
    final builtin = await _estimateExtent(
      tester,
      message: message,
      toolParts: {
        'builtin-only': const [
          ToolUIPart(
            id: 'builtin_search',
            toolName: 'builtin_search',
            arguments: {},
            content: 'results',
          ),
        ],
      },
    );
    expect(builtin, empty);
    expect(builtin - empty, 0);
  });

  testWidgets('tool image thumbnails add at least 120px', (tester) async {
    final message = ChatMessage(
      id: 'tool-images',
      role: 'assistant',
      content: '',
      conversationId: 'conversation-1',
    );
    final headerOnly = await _estimateExtent(
      tester,
      message: message,
      toolParts: {
        'tool-images': const [
          ToolUIPart(
            id: 'img-1',
            toolName: 'read_file',
            arguments: {},
            content: 'no image here',
          ),
        ],
      },
    );
    final withImages = await _estimateExtent(
      tester,
      message: message,
      toolParts: {
        'tool-images': const [
          ToolUIPart(
            id: 'img-1',
            toolName: 'read_file',
            arguments: {},
            content: 'caption ![shot](https://example.com/a.png)',
          ),
        ],
      },
    );
    final hiddenImages = await _estimateExtent(
      tester,
      message: message,
      hideToolResultImages: true,
      toolParts: {
        'tool-images': const [
          ToolUIPart(
            id: 'img-1',
            toolName: 'read_file',
            arguments: {},
            content: 'caption ![shot](https://example.com/a.png)',
          ),
        ],
      },
    );

    expect(withImages, greaterThanOrEqualTo(headerOnly + 120));
    expect(hiddenImages, headerOnly);
  });

  testWidgets(
    'ask-user, TTS, and Screen Time extras count when summary is off',
    (tester) async {
      final message = ChatMessage(
        id: 'special-tools',
        role: 'assistant',
        content: '',
        conversationId: 'conversation-1',
      );
      final header = await _estimateExtent(
        tester,
        message: message,
        toolParts: {
          'special-tools': const [
            ToolUIPart(
              id: 'plain',
              toolName: 'read_file',
              arguments: {},
              content: 'plain',
            ),
          ],
        },
      );
      final askUser = await _estimateExtent(
        tester,
        message: message,
        toolParts: {
          'special-tools': [
            ToolUIPart(
              id: 'ask',
              toolName: LocalToolNames.askUser,
              arguments: {
                'questions': [
                  {
                    'id': 'scope',
                    'question': 'Choose scope?',
                    'type': 'single',
                    'options': ['Minimal', 'Complete', 'Custom'],
                  },
                ],
              },
            ),
          ],
        },
      );
      final tts = await _estimateExtent(
        tester,
        message: message,
        toolParts: {
          'special-tools': const [
            ToolUIPart(
              id: 'tts',
              toolName: LocalToolNames.textToSpeech,
              arguments: {'text': 'Hello from the assistant'},
            ),
          ],
        },
      );
      final screenTime = await _estimateExtent(
        tester,
        message: message,
        toolParts: {
          'special-tools': [
            ToolUIPart(
              id: 'st',
              toolName: LocalToolNames.screenTime,
              arguments: const {},
              content: jsonEncode({
                'total_minutes': 40,
                'apps': [
                  {'app_name': 'Maps', 'total_minutes': 25},
                  {'app_name': 'Mail', 'total_minutes': 15},
                ],
              }),
            ),
          ],
        },
      );

      expect(askUser, greaterThan(header + 40));
      expect(tts, greaterThan(header + 20));
      expect(screenTime, greaterThan(header + 16));
    },
  );

  testWidgets('height estimate stays within 20% of laid-out tool cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final tools = <ToolUIPart>[
      for (var i = 0; i < 12; i++)
        ToolUIPart(
          id: 'tool-$i',
          toolName: 'read_file',
          arguments: {'path': 'lib/foo_$i.dart'},
          content: 'tool result $i',
        ),
    ];
    final message = ChatMessage(
      id: 'tools-laid-out',
      role: 'assistant',
      content: '好的，我来看看。',
      conversationId: 'conversation-1',
    );
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;

    await tester.pumpWidget(
      _CardVisibilityHarness(
        settings: settings,
        messages: [message],
        toolParts: {'tools-laid-out': tools},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final list = tester.widget<SuperListView>(find.byType(SuperListView));
    final estimate = list.extentEstimation!(0, 400);
    final measured = tester.getSize(find.byType(ChatMessageWidget)).height;
    final error = (estimate - measured).abs() / measured;

    expect(
      error,
      lessThan(0.20),
      reason: 'estimate=$estimate measured=$measured',
    );
  });

  testWidgets(
    'ask-user / TTS / Screen Time estimate stays within 20% of layout',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final tools = <ToolUIPart>[
        ToolUIPart(
          id: 'ask',
          toolName: LocalToolNames.askUser,
          arguments: {
            'questions': [
              {
                'id': 'scope',
                'question': 'Choose scope?',
                'type': 'single',
                'options': ['Minimal', 'Complete'],
              },
            ],
          },
        ),
        const ToolUIPart(
          id: 'tts',
          toolName: LocalToolNames.textToSpeech,
          arguments: {'text': 'Replay this sentence'},
        ),
        ToolUIPart(
          id: 'st',
          toolName: LocalToolNames.screenTime,
          arguments: const {},
          content: jsonEncode({
            'total_minutes': 12,
            'apps': [
              {'app_name': 'Maps', 'total_minutes': 12},
            ],
          }),
        ),
      ];
      final message = ChatMessage(
        id: 'special-laid-out',
        role: 'assistant',
        content: 'Done.',
        conversationId: 'conversation-1',
      );
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;

      await tester.pumpWidget(
        _CardVisibilityHarness(
          settings: settings,
          messages: [message],
          toolParts: {'special-laid-out': tools},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final list = tester.widget<SuperListView>(find.byType(SuperListView));
      final estimate = list.extentEstimation!(0, 400);
      final measured = tester.getSize(find.byType(ChatMessageWidget)).height;
      final error = (estimate - measured).abs() / measured;
      expect(
        error,
        lessThan(0.20),
        reason: 'estimate=$estimate measured=$measured',
      );
    },
  );

  testWidgets(
    'structured mixed reasoning+tool parts collapse like the renderer',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final parts = <MessagePart>[
        for (var i = 0; i < 15; i++) ...[
          ReasoningPart('plan $i'),
          ToolCallPart(
            '{"id":"t$i","name":"read_file","arguments":{"path":"$i.dart"},"content":"ok"}',
          ),
        ],
      ];
      final message = ChatMessage(
        id: 'mixed-parts',
        role: 'assistant',
        conversationId: 'conversation-1',
        parts: parts,
      );
      final projected = projectAssistantTimeline(
        parts: parts,
        liveTools: const [],
        reasoningSegments: const [],
        visualContent: '',
      );
      final collapsed = collapseProjectedTimeline(
        projected.blocks,
        showThinkingCards: true,
        showToolCards: true,
        collapseThinkingSteps: true,
        isPendingApproval: (_) => false,
      );
      expect(visibleTimelineStepCount(collapsed), 2);
      expect(collapsed.single.hasExpandRow, isTrue);
      expect(collapsed.single.visibleSteps.length, isNot(30));

      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      await settings.setCollapseThinkingSteps(true);

      await tester.pumpWidget(
        _CardVisibilityHarness(
          settings: settings,
          messages: [message],
          collapseThinkingSteps: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final renderedKeys = _timelineStepKeys(tester);
      expect(renderedKeys, hasLength(2));
      expect(
        renderedKeys.length,
        visibleTimelineStepCount(collapsed),
        reason: 'renderer and projector visible counts must match',
      );

      final list = tester.widget<SuperListView>(find.byType(SuperListView));
      final estimate = list.extentEstimation!(0, 400);
      final measured = tester.getSize(find.byType(ChatMessageWidget)).height;
      final error = (estimate - measured).abs() / measured;
      expect(
        estimate,
        lessThan(96 + 30 * 44.0),
        reason: 'must not bill 30 headers',
      );
      expect(
        error,
        lessThan(0.20),
        reason: 'estimate=$estimate measured=$measured',
      );
    },
  );

  testWidgets('ask-user answered vs unanswered estimate stays within 20%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final questions = {
      'questions': [
        {
          'id': 'scope',
          'question': 'Choose scope?',
          'type': 'single',
          'options': ['Minimal', 'Complete', 'Custom'],
        },
      ],
    };
    final unanswered = ChatMessage(
      id: 'ask-unanswered',
      role: 'assistant',
      content: 'Need a choice.',
      conversationId: 'conversation-1',
    );
    final answered = ChatMessage(
      id: 'ask-answered',
      role: 'assistant',
      content: 'Thanks.',
      conversationId: 'conversation-1',
    );
    final unansweredTools = {
      'ask-unanswered': [
        ToolUIPart(
          id: 'ask',
          toolName: LocalToolNames.askUser,
          arguments: questions,
        ),
      ],
    };
    final answeredTools = {
      'ask-answered': [
        ToolUIPart(
          id: 'ask',
          toolName: LocalToolNames.askUser,
          arguments: questions,
          content: jsonEncode({
            'answers': {
              'scope': {'value': 'Minimal'},
            },
          }),
        ),
      ],
    };

    Future<(double, double)> measure(
      ChatMessage message,
      Map<String, List<ToolUIPart>> tools,
    ) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      await tester.pumpWidget(
        _CardVisibilityHarness(
          settings: settings,
          messages: [message],
          toolParts: tools,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final list = tester.widget<SuperListView>(find.byType(SuperListView));
      final estimate = list.extentEstimation!(0, 400);
      final measured = tester.getSize(find.byType(ChatMessageWidget)).height;
      return (estimate, measured);
    }

    final (unansweredEstimate, unansweredMeasured) = await measure(
      unanswered,
      unansweredTools,
    );
    final unansweredError =
        (unansweredEstimate - unansweredMeasured).abs() / unansweredMeasured;
    expect(
      unansweredError,
      lessThan(0.20),
      reason:
          'unanswered estimate=$unansweredEstimate measured=$unansweredMeasured',
    );

    final (answeredEstimate, answeredMeasured) = await measure(
      answered,
      answeredTools,
    );
    final answeredError =
        (answeredEstimate - answeredMeasured).abs() / answeredMeasured;
    expect(
      answeredError,
      lessThan(0.20),
      reason: 'answered estimate=$answeredEstimate measured=$answeredMeasured',
    );
    expect(answeredEstimate, lessThan(unansweredEstimate));
  });

  testWidgets('long ask-user question, option, and Other answer stay within 20%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final longQuestion = List.filled(
      18,
      'How should we handle this unusually long clarification request?',
    ).join(' ');
    final longOption = List.filled(
      12,
      'Keep the current rollout plan and document every exception',
    ).join(' ');
    final longOther = List.filled(
      16,
      'Please use a custom rollout with extra review gates.',
    ).join(' ');

    Future<(double, double)> measure(List<ToolUIPart> tools) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      await tester.pumpWidget(
        _CardVisibilityHarness(
          settings: settings,
          messages: [
            ChatMessage(
              id: 'ask-long',
              role: 'assistant',
              content: 'Need a choice.',
              conversationId: 'conversation-1',
            ),
          ],
          toolParts: {'ask-long': tools},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final list = tester.widget<SuperListView>(find.byType(SuperListView));
      final measuredSize = tester.getSize(find.byType(ChatMessageWidget));
      final estimate = list.extentEstimation!(0, measuredSize.width);
      return (estimate, measuredSize.height);
    }

    final (questionEstimate, questionMeasured) = await measure([
      ToolUIPart(
        id: 'ask-q',
        toolName: LocalToolNames.askUser,
        arguments: {
          'questions': [
            {
              'id': 'scope',
              'question': longQuestion,
              'type': 'single',
              'options': ['Minimal', 'Complete'],
            },
          ],
        },
      ),
    ]);
    final questionError =
        (questionEstimate - questionMeasured).abs() / questionMeasured;
    expect(
      questionError,
      lessThan(0.20),
      reason:
          'long question estimate=$questionEstimate measured=$questionMeasured',
    );

    final (optionEstimate, optionMeasured) = await measure([
      ToolUIPart(
        id: 'ask-opt',
        toolName: LocalToolNames.askUser,
        arguments: {
          'questions': [
            {
              'id': 'scope',
              'question': 'Choose scope?',
              'type': 'single',
              'options': [longOption, 'Complete'],
            },
          ],
        },
      ),
    ]);
    final optionError =
        (optionEstimate - optionMeasured).abs() / optionMeasured;
    expect(
      optionError,
      lessThan(0.20),
      reason: 'long option estimate=$optionEstimate measured=$optionMeasured',
    );

    final (answerEstimate, answerMeasured) = await measure([
      ToolUIPart(
        id: 'ask-ans',
        toolName: LocalToolNames.askUser,
        arguments: {
          'questions': [
            {
              'id': 'scope',
              'question': 'Choose scope?',
              'type': 'single',
              'options': ['Minimal', 'Complete'],
            },
          ],
        },
        content: jsonEncode({
          'answers': {
            'scope': {'value': longOther},
          },
        }),
      ),
    ]);
    final answerError =
        (answerEstimate - answerMeasured).abs() / answerMeasured;
    expect(
      answerError,
      lessThan(0.20),
      reason:
          'long Other answer estimate=$answerEstimate measured=$answerMeasured',
    );
  });

  testWidgets(
    'parked streaming parts estimate stays aligned with sequential blocks',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final notifier = StreamingContentNotifier();
      addTearDown(notifier.dispose);
      notifier.getNotifier('stream-live');

      final history = <ChatMessage>[
        for (var i = 0; i < 16; i++)
          ChatMessage(
            id: 'hist-$i',
            role: i.isEven ? 'user' : 'assistant',
            content: 'History line $i',
            conversationId: 'conversation-1',
          ),
      ];
      final streaming = ChatMessage(
        id: 'stream-live',
        role: 'assistant',
        content: '',
        conversationId: 'conversation-1',
        isStreaming: true,
      );
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      await settings.setCollapseThinkingSteps(true);

      await tester.pumpWidget(
        _CardVisibilityHarness(
          settings: settings,
          messages: [...history, streaming],
          collapseThinkingSteps: true,
          streamingContentNotifier: notifier,
        ),
      );
      await tester.pump();

      final parts = <MessagePart>[];
      final tools = <ToolUIPart>[];
      void addCycle(int i) {
        parts.add(ReasoningPart('plan block $i with enough text to wrap'));
        parts.add(
          ToolCallPart(
            '{"id":"t$i","name":"read_file","arguments":{"path":"$i.dart"},"content":"ok"}',
          ),
        );
        parts.add(TextPart('visible answer block $i'));
        tools.add(
          ToolUIPart(
            id: 't$i',
            toolName: 'read_file',
            arguments: {'path': '$i.dart'},
            content: 'ok',
          ),
        );
      }

      addCycle(0);
      addCycle(1);
      addCycle(2);
      notifier.updateContent(
        'stream-live',
        'visible answer block 0visible answer block 1visible answer block 2',
        0,
        parts: List<MessagePart>.of(parts),
      );
      await tester.pump();
      await tester.pump();

      final list = tester.widget<SuperListView>(find.byType(SuperListView));
      final parkedWidth = tester.getSize(find.byType(SuperListView)).width;
      final estimate = list.extentEstimation!(history.length, parkedWidth);
      final oneCollapsed = 96 + 2 * 44.0 + 36;
      expect(
        estimate,
        greaterThan(oneCollapsed + 80),
        reason: 'must not treat three live blocks as one collapsed block',
      );

      final isolatedSettings = SettingsProvider(
        createBusinessTestPreferences(),
      );
      await isolatedSettings.loaded;
      await isolatedSettings.setCollapseThinkingSteps(true);
      await tester.pumpWidget(
        _CardVisibilityHarness(
          settings: isolatedSettings,
          messages: [
            ChatMessage(
              id: 'stream-live',
              role: 'assistant',
              conversationId: 'conversation-1',
              parts: List<MessagePart>.of(parts),
            ),
          ],
          collapseThinkingSteps: true,
          toolParts: {'stream-live': List<ToolUIPart>.of(tools)},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final measured = tester.getSize(find.byType(ChatMessageWidget)).height;
      final isolatedList = tester.widget<SuperListView>(
        find.byType(SuperListView),
      );
      final isolatedWidth = tester.getSize(find.byType(SuperListView)).width;
      final isolatedEstimate = isolatedList.extentEstimation!(0, isolatedWidth);
      final layoutError = (isolatedEstimate - measured).abs() / measured;
      final parkedError =
          (estimate - isolatedEstimate).abs() / isolatedEstimate;
      expect(
        layoutError,
        lessThan(0.20),
        reason: 'isolated estimate=$isolatedEstimate measured=$measured',
      );
      expect(
        parkedError,
        lessThan(0.20),
        reason: 'parked estimate=$estimate isolated estimate=$isolatedEstimate',
      );
    },
  );

  testWidgets(
    'pending approval is conversation-scoped and adds no extra 36px',
    (tester) async {
      final approval = ToolApprovalService();
      addTearDown(approval.dispose);
      unawaited(
        approval.requestApproval(
          toolCallId: 'shared-tool',
          toolName: 'read_file',
          arguments: {'path': 'lib/a.dart'},
          conversationId: 'conversation-a',
        ),
      );

      final local = ChatMessage(
        id: 'local-pending',
        role: 'assistant',
        content: '',
        conversationId: 'conversation-a',
      );
      final other = ChatMessage(
        id: 'other-conv',
        role: 'assistant',
        content: '',
        conversationId: 'conversation-b',
      );
      final tools = const [
        ToolUIPart(
          id: 'shared-tool',
          toolName: 'read_file',
          arguments: {'path': 'lib/a.dart'},
          loading: true,
        ),
      ];

      final pendingHere = await _estimateExtent(
        tester,
        message: local,
        toolParts: {'local-pending': tools},
        approval: approval,
        showToolResultSummary: true,
      );
      final pendingThere = await _estimateExtent(
        tester,
        message: other,
        toolParts: {'other-conv': tools},
        approval: approval,
        showToolResultSummary: true,
      );
      final idle = await _estimateExtent(
        tester,
        message: ChatMessage(
          id: 'idle',
          role: 'assistant',
          content: '',
          conversationId: 'conversation-a',
        ),
        showToolResultSummary: true,
        toolParts: {
          'idle': const [
            ToolUIPart(
              id: 'shared-tool',
              toolName: 'read_file',
              arguments: {'path': 'lib/a.dart'},
            ),
          ],
        },
      );
      final pendingNoSummary = await _estimateExtent(
        tester,
        message: local,
        toolParts: {'local-pending': tools},
        approval: approval,
      );

      expect(pendingThere, idle);
      expect(pendingHere, greaterThan(idle));
      expect(pendingHere - idle, lessThan(36));
      expect(pendingNoSummary, closeTo(idle, 0.1));
    },
  );

  testWidgets('ChatMessageWidget receives MessageListView card flags', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    expect(settings.showThinkingCards, isTrue);
    expect(settings.showToolCards, isTrue);

    final message = ChatMessage(
      id: 'flag-message',
      role: 'assistant',
      content: '<think>legacy reasoning</think>Final answer',
      conversationId: 'conversation-1',
    );

    await tester.pumpWidget(
      _CardVisibilityHarness(
        settings: settings,
        messages: [message],
        showThinkingCards: false,
        showToolCards: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final rendered = tester.widget<ChatMessageWidget>(
      find.byType(ChatMessageWidget),
    );
    expect(rendered.showThinkingCards, isFalse);
    expect(rendered.showToolCards, isFalse);
    expect(find.text('Deep Thinking'), findsNothing);
    expect(find.textContaining('legacy reasoning'), findsNothing);
    expect(find.textContaining('Final answer'), findsOneWidget);
  });

  testWidgets('grown snapshot.content misses the streaming height cache', (
    tester,
  ) async {
    final notifier = StreamingContentNotifier();
    addTearDown(notifier.dispose);
    notifier.getNotifier('stream-grow');

    final streaming = ChatMessage(
      id: 'stream-grow',
      role: 'assistant',
      content: '',
      conversationId: 'conversation-1',
      isStreaming: true,
    );
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await tester.pumpWidget(
      _CardVisibilityHarness(
        settings: settings,
        messages: [streaming],
        streamingContentNotifier: notifier,
      ),
    );
    await tester.pump();

    notifier.updateContent('stream-grow', 'Hi.', 1);
    await tester.pump();
    final list = tester.widget<SuperListView>(find.byType(SuperListView));
    final short = list.extentEstimation!(0, 400);

    notifier.updateContent(
      'stream-grow',
      List.filled(40, 'This reply grew into many wrapped lines.').join('\n'),
      1,
    );
    await tester.pump();
    final grown = list.extentEstimation!(0, 400);
    expect(grown, greaterThan(short + 200));
  });

  testWidgets('ImagePart estimate uses the shared image height, not markdown', (
    tester,
  ) async {
    final hugeUri = 'data:image/png;base64,${'A' * 8000}';
    final shortUri = 'https://example.com/pic.png';
    final huge = await _estimateExtent(
      tester,
      message: ChatMessage(
        id: 'image-huge',
        role: 'assistant',
        conversationId: 'conversation-1',
        parts: [
          ImagePart(uri: hugeUri),
          const TextPart('caption'),
        ],
      ),
    );
    final short = await _estimateExtent(
      tester,
      message: ChatMessage(
        id: 'image-short',
        role: 'assistant',
        conversationId: 'conversation-1',
        parts: [
          ImagePart(uri: shortUri),
          const TextPart('caption'),
        ],
      ),
    );
    // Markdown link targets are already skipped, so URI length must not
    // drive ImagePart height — both URIs bill the shared image cap.
    expect(huge, closeTo(short, 1));
    expect(huge, greaterThan(96 + kTimelineImageBlockHeight));
    expect(huge, lessThan(96 + kTimelineImageBlockHeight + 200));

    final markdownLabel = await _estimateExtent(
      tester,
      message: ChatMessage(
        id: 'image-md',
        role: 'assistant',
        content: '\n\n![image]($hugeUri)',
        conversationId: 'conversation-1',
      ),
    );
    expect(markdownLabel, lessThan(96 + kTimelineImageBlockHeight));
  });

  testWidgets(
    'fromParts estimate applies visual regex, wrap/collapse, and visible gaps',
    (tester) async {
      final fence = [
        '```dart',
        for (var i = 0; i < 20; i++)
          'print("line $i of wrapped code that is long enough to wrap at estimate width");',
        '```',
      ].join('\n');
      final filler = List.filled(
        12,
        'VISIBLE_KEEP extra estimate filler line',
      ).join('\n');
      final message = ChatMessage(
        id: 'from-parts-estimate',
        role: 'assistant',
        conversationId: 'conversation-1',
        parts: [
          const ReasoningPart('hidden plan'),
          TextPart('$filler\n$fence'),
        ],
      );

      final raw = await _estimateExtent(
        tester,
        message: message,
        wrapCodeBlocks: true,
      );
      final collapsed = await _estimateExtent(
        tester,
        message: message,
        wrapCodeBlocks: true,
        collapsedCodeLines: 3,
      );
      expect(collapsed, lessThan(raw));

      final wrapped = await _estimateExtent(
        tester,
        message: message,
        wrapCodeBlocks: true,
      );
      final scrolled = await _estimateExtent(
        tester,
        message: message,
        wrapCodeBlocks: false,
      );
      expect(wrapped, greaterThan(scrolled));

      final assistant = Assistant(
        id: 'a1',
        name: 'A',
        regexRules: const [
          AssistantRegex(
            id: 'strip',
            name: 'strip',
            pattern: r'VISIBLE_KEEP extra estimate filler line\n?',
            replacement: '',
            scopes: [AssistantRegexScope.assistant],
            visualOnly: true,
          ),
        ],
      );
      final stripped = await _estimateExtent(
        tester,
        message: message,
        wrapCodeBlocks: true,
        assistant: assistant,
      );
      expect(stripped, lessThan(raw));

      final withHiddenThinking = await _estimateExtent(
        tester,
        message: ChatMessage(
          id: 'gap-hidden',
          role: 'assistant',
          conversationId: 'conversation-1',
          parts: const [
            TextPart('before'),
            ReasoningPart('hidden plan'),
            TextPart('after'),
          ],
        ),
        showThinkingCards: false,
      );
      final twoTextOnly = await _estimateExtent(
        tester,
        message: ChatMessage(
          id: 'gap-text',
          role: 'assistant',
          conversationId: 'conversation-1',
          // Empty reasoning forces the fromParts walk (two TextParts alone
          // concatenate into one body) without adding a visible block.
          parts: const [
            TextPart('before'),
            ReasoningPart(''),
            TextPart('after'),
          ],
        ),
        showThinkingCards: false,
      );
      expect(withHiddenThinking, closeTo(twoTextOnly, 1));
      final withShownThinking = await _estimateExtent(
        tester,
        message: ChatMessage(
          id: 'gap-shown',
          role: 'assistant',
          conversationId: 'conversation-1',
          parts: const [
            TextPart('before'),
            ReasoningPart('hidden plan'),
            TextPart('after'),
          ],
        ),
      );
      expect(withShownThinking, greaterThan(withHiddenThinking + 20));
    },
  );
}

List<String> _timelineStepKeys(WidgetTester tester) {
  final keys = <String>[];
  void visit(Element element) {
    final key = element.widget.key;
    if (key is ValueKey<String> &&
        (key.value.startsWith('tool-') || key.value.startsWith('reasoning-'))) {
      keys.add(key.value);
    }
    element.visitChildren(visit);
  }

  tester.element(find.byType(ChatMessageWidget)).visitChildren(visit);
  return keys;
}

Future<double> _estimateExtent(
  WidgetTester tester, {
  required ChatMessage message,
  bool showThinkingCards = true,
  bool showToolCards = true,
  bool showToolResultSummary = false,
  bool hideToolResultImages = false,
  bool collapseThinkingSteps = false,
  bool wrapCodeBlocks = false,
  int? collapsedCodeLines,
  Assistant? assistant,
  Map<String, List<ToolUIPart>> toolParts = const {},
  ToolApprovalService? approval,
}) async {
  final settings = SettingsProvider(createBusinessTestPreferences());
  await settings.loaded;
  await tester.pumpWidget(
    _CardVisibilityHarness(
      settings: settings,
      messages: [message],
      showThinkingCards: showThinkingCards,
      showToolCards: showToolCards,
      showToolResultSummary: showToolResultSummary,
      hideToolResultImages: hideToolResultImages,
      collapseThinkingSteps: collapseThinkingSteps,
      wrapCodeBlocks: wrapCodeBlocks,
      collapsedCodeLines: collapsedCodeLines,
      assistant: assistant,
      toolParts: toolParts,
      approval: approval,
    ),
  );
  await tester.pump();
  final list = tester.widget<SuperListView>(find.byType(SuperListView));
  return list.extentEstimation!(0, 400);
}

class _CardVisibilityHarness extends StatefulWidget {
  const _CardVisibilityHarness({
    required this.settings,
    required this.messages,
    this.showThinkingCards = true,
    this.showToolCards = true,
    this.showToolResultSummary = false,
    this.hideToolResultImages = false,
    this.collapseThinkingSteps = false,
    this.wrapCodeBlocks = false,
    this.collapsedCodeLines,
    this.assistant,
    this.toolParts = const {},
    this.approval,
    this.streamingContentNotifier,
  });

  final SettingsProvider settings;
  final List<ChatMessage> messages;
  final bool showThinkingCards;
  final bool showToolCards;
  final bool showToolResultSummary;
  final bool hideToolResultImages;
  final bool collapseThinkingSteps;
  final bool wrapCodeBlocks;
  final int? collapsedCodeLines;
  final Assistant? assistant;
  final Map<String, List<ToolUIPart>> toolParts;
  final ToolApprovalService? approval;
  final StreamingContentNotifier? streamingContentNotifier;

  @override
  State<_CardVisibilityHarness> createState() => _CardVisibilityHarnessState();
}

class _CardVisibilityHarnessState extends State<_CardVisibilityHarness> {
  late final ScrollController scrollController;
  late final ListController listController;
  late final ValueNotifier<bool> isProcessingFiles;
  late final ToolApprovalService _ownedApproval;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    listController = ListController();
    isProcessingFiles = ValueNotifier<bool>(false);
    _ownedApproval = ToolApprovalService();
  }

  @override
  void dispose() {
    scrollController.dispose();
    listController.dispose();
    isProcessingFiles.dispose();
    _ownedApproval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: widget.settings),
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
        ChangeNotifierProvider<ToolApprovalService>.value(
          value: widget.approval ?? _ownedApproval,
        ),
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
            toolParts: widget.toolParts,
            translations: const {},
            selecting: false,
            selectedItems: const {},
            dividerPadding: EdgeInsets.zero,
            isProcessingFiles: isProcessingFiles,
            showThinkingCards: widget.showThinkingCards,
            showToolCards: widget.showToolCards,
            showToolResultSummary: widget.showToolResultSummary,
            hideToolResultImages: widget.hideToolResultImages,
            collapseThinkingSteps: widget.collapseThinkingSteps,
            wrapCodeBlocks: widget.wrapCodeBlocks,
            collapsedCodeLines: widget.collapsedCodeLines,
            assistant: widget.assistant,
            streamingContentNotifier: widget.streamingContentNotifier,
          ),
        ),
      ),
    );
  }
}
