import 'dart:convert';

import 'package:Kelivo/core/services/api/providers/claude/claude_decoder.dart';
import 'package:Kelivo/core/services/api/providers/google/google_decoder.dart';
import 'package:Kelivo/core/services/api/providers/openai/chat_completions_decoder.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_decoder.dart';
import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/features/home/controllers/legacy_content_bookkeeping.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/stream_chunk_shadow_harness.dart';

SseEvent _chatEvent(Map<String, dynamic> delta) {
  return SseEvent(
    data: jsonEncode({
      'choices': [
        {'delta': delta},
      ],
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('records a split triple when thinking is followed by text', () {
    final bookkeeping = LegacyContentBookkeeping()..markThinking();
    expect(
      bookkeeping.addContent('hello', reasoningCount: 1, toolCount: 0),
      isTrue,
    );
    expect(bookkeeping.offsets, const [0]);
    expect(bookkeeping.reasoningCounts, const [1]);
    expect(bookkeeping.toolCounts, const [0]);
    expect(bookkeeping.fullContentRaw, 'hello');
    expect(bookkeeping.hadThinkingBlock, isFalse);
  });

  test(
    'shadow-compares Claude thinking + parallel tools + web_search',
    () async {
      final diff = await compareChatFromChunks(
        replayTraceChunks(
          'claude/thinking-tools-search',
          ClaudeStreamDecoder(),
        ),
      );
      expectShadowMatched(diff, because: 'claude/thinking-tools-search');
    },
  );

  test('shadow-compares Gemini thinking + image', () async {
    final diff = await compareChatFromChunks(
      replayTraceChunks(
        'google/thinking-image',
        GoogleStreamDecoder(persistThoughtSigs: true),
      ),
    );
    expectShadowMatched(diff, because: 'google/thinking-image');
  });

  test('shadow-compares Chat Completions reasoning + parallel tools', () async {
    final diff = await compareChatFromChunks(
      replayTraceChunks(
        'openai-chat/reasoning-parallel-tools',
        ChatCompletionsStreamDecoder(
          needsReasoningEcho: true,
          allowReasoningSnapshots: false,
        ),
      ),
    );
    expectShadowMatched(diff, because: 'openai-chat/reasoning-parallel-tools');
  });

  test('shadow-compares Responses server-search + text', () async {
    final diff = await compareChatFromChunks(
      replayTraceChunks(
        'openai-responses/server-tool-incomplete',
        ResponsesStreamDecoder(),
      ),
      responsesImageDuplicates: true,
    );
    expectShadowMatched(
      diff,
      because: 'openai-responses/server-tool-incomplete',
    );
  });

  test('shadow-compares two decoder rounds with scoped ids', () async {
    final round0 = ChatCompletionsStreamDecoder(sourceId: 'round-0');
    final round1 = ChatCompletionsStreamDecoder(sourceId: 'round-1');
    final chunks = <StreamChunk>[
      ...round0.accept(_chatEvent({'content': 'before'})).chunks,
      const ToolCallStart(id: 'call_1', toolName: 'lookup'),
      const ToolCallEnd('call_1'),
      ...round1.accept(_chatEvent({'content': 'after'})).chunks,
    ];

    final diff = await compareChatFromChunks(chunks);
    expectShadowMatched(diff, because: 'round-0/round-1 tool follow-up');
    expect(diff.handlerText, 'beforeafter');
    expect(diff.handlerToolIds, {'call_1'});
  });

  test('shadow-compares thinking, text, tool, then text', () async {
    const chunks = <StreamChunk>[
      ReasoningDelta(id: 'r', text: 'plan'),
      TextDelta(id: 't0', text: 'hello'),
      ToolCallStart(id: 'c1', toolName: 'lookup'),
      ToolCallEnd('c1'),
      TextDelta(id: 't1', text: 'done'),
    ];

    final diff = await compareChatFromChunks(chunks);
    expectShadowMatched(diff, because: 'thinking → text → tool → text');
    expect(diff.handlerKinds.map((item) => item.kind).toList(), [
      'reasoning',
      'text',
      'tool_call',
      'text',
    ]);
  });

  test('shadow-compares stream:false bags path', () {
    const chunks = <StreamChunk>[
      ReasoningDelta(id: 'r', text: 'think'),
      ToolCallStart(id: 'a', toolName: 'lookup'),
      ToolCallEnd('a'),
      TextDelta(id: 't', text: 'hi'),
    ];

    final diff = compareLegacyFromChunks(chunks);
    expectShadowMatched(diff, because: 'stream:false bags');
  });

  test('shadow-compares Images API url output', () async {
    const chunks = <StreamChunk>[
      ImageStart(id: 'img', mimeType: 'image/png'),
      ImageSnapshot(id: 'img', data: 'https://example.com/generated.png'),
      ImageEnd('img'),
    ];

    final diff = await compareChatFromChunks(chunks);
    expectShadowMatched(diff, because: 'Images API');
    expect(diff.handlerImages, 1);
    expect(diff.legacyImages, 1);
  });

  test('shadow-compares non-stream Responses image output', () async {
    const chunks = <StreamChunk>[
      ImageStart(id: 'img', mimeType: 'image/png'),
      ImageSnapshot(id: 'img', data: 'kelivo-file:///images/cat.png'),
      ImageEnd('img'),
      TextDelta(id: 't', text: 'Done'),
    ];

    final diff = await compareChatFromChunks(
      chunks,
      responsesImageDuplicates: true,
    );
    expectShadowMatched(diff, because: 'non-stream Responses image');
    expect(diff.handlerImages, 1);
    expect(diff.legacyImages, 1);
    expect(diff.handlerText, 'Done');
  });
}
