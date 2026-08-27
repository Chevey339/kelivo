import '../../../support/business_test_harness.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/chat/widgets/timeline_projection.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHarness({required Widget child}) {
  SharedPreferences.setMockInitialValues(const {});
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            TtsProvider(preferences: createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider(create: (_) => ToolApprovalService()),
      ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void expectAbove(WidgetTester tester, Finder upper, Finder lower) {
  expect(upper, findsWidgets);
  expect(lower, findsWidgets);
  expect(
    tester.getTopLeft(upper.first).dy,
    lessThan(tester.getTopLeft(lower.first).dy),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('historical contentSplits still render reasoning then text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        child: ChatMessageWidget(
          message: ChatMessage(
            id: 'legacy-splits',
            role: 'assistant',
            content: 'hello',
            conversationId: 'c1',
          ),
          showModelIcon: false,
          reasoningSegments: const [
            ReasoningSegment(text: 'plan', expanded: true, loading: false),
          ],
          contentSplitOffsets: const [0],
          reasoningCountAtSplit: const [1],
          toolCountAtSplit: const [0],
        ),
      ),
    );
    await tester.pump();

    expectAbove(
      tester,
      find.textContaining('plan'),
      find.textContaining('hello'),
    );
  });

  testWidgets('historical interleaved splits keep text around thinking', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        child: ChatMessageWidget(
          message: ChatMessage(
            id: 'legacy-interleave',
            role: 'assistant',
            content: 'beforeAFTER',
            conversationId: 'c1',
          ),
          showModelIcon: false,
          reasoningSegments: const [
            ReasoningSegment(text: 'plan', expanded: true, loading: false),
          ],
          contentSplitOffsets: const [6],
          reasoningCountAtSplit: const [1],
          toolCountAtSplit: const [0],
        ),
      ),
    );
    await tester.pump();

    expectAbove(
      tester,
      find.textContaining('before'),
      find.textContaining('plan'),
    );
    expectAbove(
      tester,
      find.textContaining('plan'),
      find.textContaining('AFTER'),
    );
  });

  testWidgets(
    'empty timeline with ToolCallPart falls back to parts when splits exist',
    (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageWidget(
            message: ChatMessage(
              id: 'empty-timeline-tools',
              role: 'assistant',
              conversationId: 'c1',
              parts: const [
                ToolCallPart(
                  '{"id":"c1","name":"lookup","arguments":{},"content":"ok"}',
                ),
                TextPart('BODY_HELLO'),
              ],
            ),
            showModelIcon: false,
            contentSplitOffsets: const [0],
            reasoningCountAtSplit: const [1],
            toolCountAtSplit: const [0],
          ),
        ),
      );
      await tester.pump();

      expectAbove(
        tester,
        find.textContaining('lookup'),
        find.textContaining('BODY_HELLO'),
      );
    },
  );

  testWidgets(
    'empty timeline with ImagePart keeps image ordinal above the body',
    (tester) async {
      const imageUrl = 'https://example.com/empty-timeline.png';
      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageWidget(
            message: ChatMessage(
              id: 'empty-timeline-image',
              role: 'assistant',
              conversationId: 'c1',
              parts: const [
                ImagePart(uri: imageUrl),
                TextPart('BODY_HELLO'),
              ],
            ),
            showModelIcon: false,
            contentSplitOffsets: const [0],
            reasoningCountAtSplit: const [1],
            toolCountAtSplit: const [0],
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey('assistant-message-attachments:empty-timeline-image'),
        ),
        findsNothing,
      );
      expectAbove(
        tester,
        find.byType(Image),
        find.textContaining('BODY_HELLO'),
      );
    },
  );

  testWidgets('structured parts render reasoning, text, and tool in order', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        child: ChatMessageWidget(
          message: ChatMessage(
            id: 'structured-parts',
            role: 'assistant',
            conversationId: 'c1',
            parts: const [
              ReasoningPart('plan'),
              TextPart('hello'),
              ToolCallPart(
                '{"id":"c1","name":"lookup","arguments":{},"content":"ok"}',
              ),
              TextPart('done'),
            ],
          ),
          showModelIcon: false,
        ),
      ),
    );
    await tester.pump();

    expectAbove(
      tester,
      find.textContaining('plan'),
      find.textContaining('hello'),
    );
    expectAbove(
      tester,
      find.textContaining('hello'),
      find.textContaining('lookup'),
    );
    expectAbove(
      tester,
      find.textContaining('lookup'),
      find.textContaining('done'),
    );
  });

  testWidgets(
    'empty contentSplits without structured parts keep thinking above body',
    (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageWidget(
            message: ChatMessage(
              id: 'legacy-empty-splits',
              role: 'assistant',
              content: 'BODY_HELLO',
              conversationId: 'c1',
            ),
            showModelIcon: false,
            reasoningSegments: const [
              ReasoningSegment(
                text: 'THINK_PLAN',
                expanded: true,
                loading: false,
              ),
            ],
            contentSplitOffsets: const [],
            reasoningCountAtSplit: const [],
            toolCountAtSplit: const [],
          ),
        ),
      );
      await tester.pump();

      expectAbove(
        tester,
        find.textContaining('THINK_PLAN'),
        find.textContaining('BODY_HELLO'),
      );
    },
  );

  testWidgets('empty contentSplits keep reasoning above body', (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        child: ChatMessageWidget(
          message: ChatMessage(
            id: 'empty-splits',
            role: 'assistant',
            content: 'BODY_HELLO',
            conversationId: 'c1',
            parts: const [ReasoningPart('THINK_PLAN'), TextPart('BODY_HELLO')],
          ),
          showModelIcon: false,
          contentSplitOffsets: const [],
          reasoningCountAtSplit: const [],
          toolCountAtSplit: const [],
        ),
      ),
    );
    await tester.pump();

    expectAbove(
      tester,
      find.textContaining('THINK_PLAN'),
      find.textContaining('BODY_HELLO'),
    );
  });

  String toolNameAt(int index, int count) {
    if (index == 1) return 'alpha_search';
    if (index == count) return 'omega_search';
    return 'mid_search_$index';
  }

  List<ToolUIPart> tools(int count) => [
    for (var i = 1; i <= count; i++)
      ToolUIPart(
        id: 'tool-$i',
        toolName: toolNameAt(i, count),
        arguments: const {},
        content: 'ok',
      ),
  ];

  List<MessagePart> toolPartsThenBody(int count) => [
    const ReasoningPart('THINK_PLAN'),
    for (var i = 1; i <= count; i++)
      ToolCallPart(
        '{"id":"tool-$i","name":"${toolNameAt(i, count)}","arguments":{},"content":"ok"}',
      ),
    const TextPart('BODY_HELLO'),
  ];

  testWidgets('incomplete 17-tool splits keep leftover cards above the body', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        child: SingleChildScrollView(
          child: ChatMessageWidget(
            message: ChatMessage(
              id: 'incomplete-splits-17',
              role: 'assistant',
              content: 'BODY_HELLO',
              conversationId: 'c1',
            ),
            showModelIcon: false,
            reasoningSegments: const [
              ReasoningSegment(
                text: 'THINK_PLAN',
                expanded: true,
                loading: false,
              ),
            ],
            toolParts: tools(17),
            contentSplitOffsets: const [0],
            reasoningCountAtSplit: const [1],
            toolCountAtSplit: const [7],
          ),
        ),
      ),
    );
    await tester.pump();
    expectAbove(
      tester,
      find.textContaining('omega_search'),
      find.textContaining('BODY_HELLO'),
    );
  });

  testWidgets('incomplete 24-tool splits keep leftover cards above the body', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        child: SingleChildScrollView(
          child: ChatMessageWidget(
            message: ChatMessage(
              id: 'incomplete-splits-24',
              role: 'assistant',
              content: 'BODY_HELLO',
              conversationId: 'c1',
            ),
            showModelIcon: false,
            reasoningSegments: const [
              ReasoningSegment(
                text: 'THINK_PLAN',
                expanded: true,
                loading: false,
              ),
            ],
            toolParts: tools(24),
            contentSplitOffsets: const [0],
            reasoningCountAtSplit: const [1],
            toolCountAtSplit: const [18],
          ),
        ),
      ),
    );
    await tester.pump();
    expectAbove(
      tester,
      find.textContaining('omega_search'),
      find.textContaining('BODY_HELLO'),
    );
  });

  testWidgets(
    'incomplete splits with structured parts keep leftover cards above the body',
    (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          child: SingleChildScrollView(
            child: ChatMessageWidget(
              message: ChatMessage(
                id: 'incomplete-splits-parts',
                role: 'assistant',
                conversationId: 'c1',
                parts: toolPartsThenBody(17),
              ),
              showModelIcon: false,
              reasoningSegments: const [
                ReasoningSegment(
                  text: 'THINK_PLAN',
                  expanded: true,
                  loading: false,
                ),
              ],
              toolParts: tools(17),
              contentSplitOffsets: const [0],
              reasoningCountAtSplit: const [1],
              toolCountAtSplit: const [7],
            ),
          ),
        ),
      );
      await tester.pump();
      expectAbove(
        tester,
        find.textContaining('omega_search'),
        find.textContaining('BODY_HELLO'),
      );
    },
  );

  testWidgets('overflowing split offsets fall back to thinking above body', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        child: ChatMessageWidget(
          message: ChatMessage(
            id: 'overflow-offset',
            role: 'assistant',
            content: 'hello',
            conversationId: 'c1',
          ),
          showModelIcon: false,
          reasoningSegments: const [
            ReasoningSegment(text: 'plan', expanded: true, loading: false),
          ],
          contentSplitOffsets: const [11],
          reasoningCountAtSplit: const [1],
          toolCountAtSplit: const [0],
        ),
      ),
    );
    await tester.pump();
    expectAbove(
      tester,
      find.textContaining('plan'),
      find.textContaining('hello'),
    );
  });

  testWidgets(
    'complete historical tool splits keep leftover cards interleaved',
    (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageWidget(
            message: ChatMessage(
              id: 'complete-tools',
              role: 'assistant',
              content: 'beforeAFTER',
              conversationId: 'c1',
            ),
            showModelIcon: false,
            reasoningSegments: const [
              ReasoningSegment(text: 'plan', expanded: true, loading: false),
            ],
            toolParts: tools(2),
            contentSplitOffsets: const [6],
            reasoningCountAtSplit: const [1],
            toolCountAtSplit: const [2],
          ),
        ),
      );
      await tester.pump();
      expectAbove(
        tester,
        find.textContaining('before'),
        find.textContaining('plan'),
      );
      expectAbove(
        tester,
        find.textContaining('omega_search'),
        find.textContaining('AFTER'),
      );
    },
  );

  testWidgets('illegal contentSplits fall back to parts order', (tester) async {
    Future<void> pumpIllegal({
      required List<int> offsets,
      required List<int> reasoning,
      required List<int> tools,
    }) async {
      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageWidget(
            message: ChatMessage(
              id: 'illegal-splits',
              role: 'assistant',
              content: 'BODY_HELLO',
              conversationId: 'c1',
              parts: const [
                ReasoningPart('THINK_PLAN'),
                TextPart('BODY_HELLO'),
              ],
            ),
            showModelIcon: false,
            contentSplitOffsets: offsets,
            reasoningCountAtSplit: reasoning,
            toolCountAtSplit: tools,
          ),
        ),
      );
      await tester.pump();
      expectAbove(
        tester,
        find.textContaining('THINK_PLAN'),
        find.textContaining('BODY_HELLO'),
      );
    }

    await pumpIllegal(
      offsets: const [0],
      reasoning: const [1, 2],
      tools: const [0],
    );
    await pumpIllegal(
      offsets: const [-1],
      reasoning: const [1],
      tools: const [0],
    );
    await pumpIllegal(
      offsets: const [0, 3],
      reasoning: const [2, 1],
      tools: const [0, 0],
    );
  });

  testWidgets('OpenRouter Claude persist-reload keeps thinking above the body', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    final writer = StreamController(
      chatService: ChatService(),
      onStateChanged: () {},
      getSettingsProvider: () => settings,
      getCurrentConversationId: () => 'c1',
    );
    final segment = ReasoningSegmentData()
      ..text = 'THINK_PLAN'
      ..expanded = true
      ..toolStartIndex = 0;
    final persisted = writer.serializeReasoningSegmentsWithSplits(
      [segment],
      reasoningDetails: const [
        {
          'id': 'rd_1',
          'type': 'reasoning.encrypted',
          'data': 'sig',
          'format': 'anthropic-claude-v1',
        },
      ],
    );

    const staleEmptySplits =
        '{"v":2,"segments":[{"text":"THINK_PLAN","expanded":true,"toolStartIndex":0}],"contentSplits":{"offsets":[],"reasoningCounts":[],"toolCounts":[]},"reasoningDetails":[{"id":"rd_1","type":"reasoning.encrypted","data":"sig","format":"anthropic-claude-v1"}]}';

    for (final json in [persisted, staleEmptySplits]) {
      final reader = StreamController(
        chatService: ChatService(),
        onStateChanged: () {},
        getSettingsProvider: () => settings,
        getCurrentConversationId: () => 'c1',
      );
      final message = ChatMessage(
        id: 'or-claude',
        role: 'assistant',
        content: 'BODY_HELLO',
        conversationId: 'c1',
        reasoningSegmentsJson: json,
        parts: const [ReasoningPart('THINK_PLAN'), TextPart('BODY_HELLO')],
      );
      reader.restoreMessageUiState(
        message,
        getToolEventsFromDb: (_) => const [],
      );
      expect(reader.getContentSplitData(message.id), isNull);

      final splits = reader.getContentSplitData(message.id);
      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageWidget(
            message: message,
            showModelIcon: false,
            reasoningSegments: reader
                .getReasoningSegments(message.id)
                ?.map(
                  (s) => ReasoningSegment(
                    text: s.text,
                    expanded: true,
                    loading: false,
                  ),
                )
                .toList(),
            contentSplitOffsets: splits?.offsets,
            reasoningCountAtSplit: splits?.reasoningCounts,
            toolCountAtSplit: splits?.toolCounts,
          ),
        ),
      );
      await tester.pump();
      expectAbove(
        tester,
        find.textContaining('THINK_PLAN'),
        find.textContaining('BODY_HELLO'),
      );
      reader.dispose();
    }
    writer.dispose();
  });

  testWidgets('ChatBox imported reasoning-then-text parts render both blocks', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        child: ChatMessageWidget(
          message: ChatMessage(
            id: 'chatbox-reasoning',
            role: 'assistant',
            conversationId: 'c1',
            parts: const [
              ReasoningPart('first thought\nsecond thought'),
              TextPart('Because.'),
            ],
          ),
          showModelIcon: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('first thought'), findsWidgets);
    expect(find.textContaining('second thought'), findsWidgets);
    expect(find.textContaining('Because.'), findsWidgets);
  });

  testWidgets(
    'ChatBox imported text-reasoning-text loads as thinking then body',
    (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageWidget(
            message: ChatMessage(
              id: 'chatbox-split',
              role: 'assistant',
              conversationId: 'c1',
              parts: const [
                ReasoningPart('think'),
                TextPart('before'),
                TextPart('\nafter'),
              ],
            ),
            showModelIcon: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('think'), findsWidgets);
      expect(find.textContaining('before'), findsWidgets);
      expect(find.textContaining('after'), findsWidgets);
    },
  );

  testWidgets(
    'structured image restores viewer, aspect, bubble, and ResizeImage',
    (tester) async {
      const png =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD5N/qhAAAAEklEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageWidget(
            message: ChatMessage(
              id: 'structured-image',
              role: 'assistant',
              conversationId: 'c1',
              parts: const [
                ReasoningPart('plan'),
                ImagePart(uri: png),
                TextPart('caption'),
              ],
            ),
            showModelIcon: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byKey(
          const ValueKey('assistant-message-attachments:structured-image'),
        ),
        findsNothing,
      );
      final image = tester.widget<Image>(find.byType(Image).first);
      expect(image.height, isNot(kTimelineImageBlockHeight));
      expect(image.image, isA<ResizeImage>());
      expect(find.byType(ImageViewerPage), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('assistant-inline-image:image-ordinal:0')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ImageViewerPage), findsOneWidget);
    },
  );

  testWidgets('structured image plus valid splits keeps arrival order', (
    tester,
  ) async {
    const imageUrl = 'https://example.com/inline.png';
    await tester.pumpWidget(
      _buildHarness(
        child: ChatMessageWidget(
          message: ChatMessage(
            id: 'structured-image-splits',
            role: 'assistant',
            content: 'caption',
            conversationId: 'c1',
            parts: const [
              ReasoningPart('plan'),
              ImagePart(uri: imageUrl),
              TextPart('caption'),
            ],
          ),
          showModelIcon: false,
          reasoningSegments: const [
            ReasoningSegment(text: 'plan', expanded: true, loading: false),
          ],
          contentSplitOffsets: const [0],
          reasoningCountAtSplit: const [1],
          toolCountAtSplit: const [0],
        ),
      ),
    );
    await tester.pump();

    final attachmentsFinder = find.byKey(
      const ValueKey('assistant-message-attachments:structured-image-splits'),
    );
    expect(attachmentsFinder, findsOneWidget);
    expect(
      find.descendant(of: attachmentsFinder, matching: find.byType(Image)),
      findsOneWidget,
    );
    expectAbove(
      tester,
      find.textContaining('plan'),
      find.textContaining('caption'),
    );
  });

  testWidgets('standalone builtin_search historical message stays visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        child: ChatMessageWidget(
          message: ChatMessage(
            id: 'chatbox-search',
            role: 'tool',
            conversationId: 'c1',
            content: '{"tool":"builtin_search","arguments":{},"result":"hits"}',
          ),
          showToolCards: true,
          showModelIcon: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Built-in Search'), findsOneWidget);
    expect(
      tester.getSize(find.byType(ChatMessageWidget)).height,
      greaterThan(20),
    );
  });
}
