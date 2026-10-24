import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/tts/tts_text_selection.dart';
import 'package:Kelivo/features/chat/widgets/timeline_projection.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_message_projection.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_presented_fences.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_source_selection.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/text/ui_search_text.dart';
import 'package:Kelivo/features/intelligent_ui/text/ui_text_projection.dart';

import '../../support/genui_projection_fixture.dart';

String _body(int index) =>
    '''ui 1 catalog "kelivo.native/1"
\$a: number = 2
root = Column(children=[input,result])
input = Slider(label="Input$index",bind=\$a,min=0,max=10)
result = Metric(label="Label$index",value=\$a*2,unit="km")
''';

ChatMessage _message({
  bool tool = false,
  bool invalidSplit = false,
  bool singleReasoning = false,
  bool duplicateTool = false,
}) {
  final text = [
    for (var index = 0; index < 4; index++) '```kelivo-ui\n${_body(index)}```',
  ].join('\n\n');
  final message = ChatMessage(
    id: 'revision',
    conversationId: 'conversation',
    role: 'assistant',
    reasoningText: singleReasoning ? 'plan' : null,
    parts: [
      if (duplicateTool)
        ToolCallPart(
          jsonEncode({
            'id': 'tool',
            'name': 'search',
            'arguments': <String, Object?>{},
          }),
        ),
      if (tool)
        ToolCallPart(
          jsonEncode({
            'id': 'tool',
            'name': 'search',
            'arguments': <String, Object?>{},
            'content': 'synthetic result',
          }),
        )
      else
        const ReasoningPart('plan'),
      TextPart(text),
    ],
    reasoningSegmentsJson: jsonEncode({
      'segments': [
        if (!tool && !singleReasoning) {'text': 'plan', 'toolStartIndex': 0},
      ],
      'contentSplits': {
        'offsets': [text.indexOf('root =')],
        'reasoningCounts': [tool ? 0 : (invalidSplit ? 2 : 1)],
        'toolCounts': [tool ? 1 : 0],
      },
    }),
  );
  message.hydrateGenerationState(GenerationRunState.completed);
  return message;
}

void main() {
  for (final tool in [false, true]) {
    test(
      'historical ${tool ? 'tool' : 'reasoning'} split shares renderer budget',
      () async {
        final message = _message(tool: tool);
        final projection = projectAssistantTimeline(
          parts: message.parts,
          liveTools: [
            if (tool)
              parseTimelineToolPart(message.parts.first as ToolCallPart)!,
          ],
          reasoningSegments: [
            if (!tool) const TimelineReasoningRef(text: 'plan'),
          ],
          visualContent: message.content,
          contentSplitOffsets: [message.content.indexOf('root =')],
          reasoningCountAtSplit: [tool ? 0 : 1],
          toolCountAtSplit: [tool ? 1 : 0],
        );
        final rendered = <String>[];
        for (final block in projection.blocks.where((b) => b.isText)) {
          final document = const MarkdownParser().parse(block.text!);
          for (final node in document.children.whereType<CodeBlockNode>()) {
            final fence = block.uiSource?.resolve(document, node);
            if (fence != null && block.uiSource!.messageOrdinalOf(fence)! < 3) {
              rendered.add(fence.surfaceKey);
            }
          }
        }
        expect(rendered, contains('1:3'));
        expect(rendered, isNot(contains('1:0')));
        expect(
          uiPresentedNativeFences(message)
              .where((item) => item.ordinal < 3)
              .map((item) => item.fence.surfaceKey),
          rendered,
        );

        final last = uiEligibleFences(message).last;
        final controller = UiSurfaceController(
          owner: UiSurfaceOwner(
            revisionId: message.id,
            surfaceKey: last.surfaceKey,
          ),
        );
        addTearDown(controller.dispose);
        controller.updateSource(
          last.body,
          closed: true,
          generation: UiGenerationStatus.complete,
        );
        controller.setInputs({'a': 7}, token: controller.token);
        final snapshot = controller.captureSnapshot();
        for (final mode in [UiTextMode.copy, UiTextMode.export]) {
          final captured = await projectUiMessageText(
            message,
            projection: testUiProjection,
            snapshots: [snapshot],
            blockLimit: 'Too many blocks',
            mode: mode,
          );
          expect(captured.surfaces.map((s) => s.owner.surfaceKey), rendered);
          expect(captured.copyText, contains('Label3: 14 km'));
          expect(
            captured.speech(TtsTextSelectionMode.fullText),
            contains('Label3: 14 km'),
          );
          expect(captured.surfaces.last.snapshot!.state.inputs['a'], 7);
        }
        final initial = initialUiSearchText(message);
        expect(initial.keys, rendered);
        expect(initial['1:3']!.text, contains('Label3: 4 km'));
        final searchable = uiSearchableText(message, initial);
        expect(searchable.text, contains('Label3: 4 km'));
        expect(searchable.matchedSurface(['label3']), '1:3');
      },
    );
  }

  test('single persisted reasoning text supplies the historical step', () {
    final message = _message(singleReasoning: true);
    final initial = initialUiSearchText(message);
    expect(initial.keys, contains('1:3'));
    expect(initial.keys, isNot(contains('1:0')));
    expect(
      uiSearchableText(message, initial).matchedSurface(['label3']),
      '1:3',
    );
  });

  test('duplicate pending and completed tool events count as one step', () {
    final message = _message(tool: true, duplicateTool: true);
    final initial = initialUiSearchText(message);
    expect(initial.keys, contains('2:3'));
    expect(initial.keys, isNot(contains('2:0')));
    expect(
      uiSearchableText(message, initial).matchedSurface(['label3']),
      '2:3',
    );
  });

  test(
    'invalid persisted tool field rejects the batch before split validation',
    () {
      final message = _message(tool: true);
      final broken = message.copyWith(
        parts: [
          const ToolCallPart(
            '{"id":"tool","name":"search","arguments":"oops","content":"done"}',
          ),
          message.parts.last,
        ],
      );
      expect(initialUiSearchText(broken).keys, ['1:0', '1:1', '1:2']);
    },
  );

  for (final id in ['tool', '']) {
    test('large JSON tool number retains the host behavior with id="$id"', () {
      final message = _message(tool: true);
      final withLargeNumber = message.copyWith(
        parts: [
          ToolCallPart(
            '{"id":"$id","name":"search","arguments":{"n":1e999},"content":"done"}',
          ),
          message.parts.last,
        ],
      );
      final initial = initialUiSearchText(withLargeNumber);
      expect(initial.keys, id.isEmpty ? ['1:0', '1:1', '1:2'] : ['1:2', '1:3']);
    });
  }

  test(
    'streaming parts take precedence over persisted historical splits',
    () async {
      final message = _message().copyWith(isStreaming: true);
      final captured = await projectUiMessageText(
        message,
        projection: testUiProjection,
        blockLimit: 'Too many blocks',
      );
      expect(captured.surfaces.map((s) => s.owner.surfaceKey), [
        '1:0',
        '1:1',
        '1:2',
      ]);
      expect(captured.copyText, contains('Too many blocks'));
    },
  );

  test(
    'mismatched historical counts preserve the ordinary three-card budget',
    () {
      final message = _message(invalidSplit: true);
      final initial = initialUiSearchText(message);
      expect(initial.keys, ['1:0', '1:1', '1:2']);
      final searchable = uiSearchableText(message, initial);
      expect(searchable.text, isNot(contains('Label3')));
      expect(
        searchable.text,
        contains('Additional interface shown as source.'),
      );
    },
  );

  test('persisted split card defaults enter the real search index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = ChatDatabaseRepository(db);
    addTearDown(repo.close);
    await repo.ensureReady();
    await repo.putConversation(
      Conversation(id: 'conversation', title: 'Synthetic'),
    );
    final message = _message();
    await repo.putMessage(message);
    var run = await repo.createGenerationRun(
      id: 'run',
      conversationId: message.conversationId,
      targetRevisionId: message.id,
      createdAt: DateTime.now(),
    );
    for (final state in [
      GenerationRunState.requesting,
      GenerationRunState.streaming,
      GenerationRunState.completed,
    ]) {
      run = await repo.transitionGenerationRun(
        id: run.id,
        expectedState: run.state,
        expectedStateRevision: run.stateRevision,
        nextState: state,
        updatedAt: DateTime.now(),
      );
    }
    final matches = await repo.searchConversationMatches(tokens: ['label3']);
    expect(matches, hasLength(1));
    expect(matches.single.matchedSurfaceKey, '1:3');
    expect(matches.single.searchableText, contains('Label3: 4 km'));
  });
}
