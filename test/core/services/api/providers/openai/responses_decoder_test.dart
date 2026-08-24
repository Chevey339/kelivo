import 'dart:convert';

import 'package:Kelivo/core/services/api/providers/openai/openai_tool_transcript.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_api.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_decoder.dart';
import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:flutter_test/flutter_test.dart';

SseEvent _event(Map<String, dynamic> data) => SseEvent(data: jsonEncode(data));

void main() {
  test('streams text and reasoning and completes without Finish', () {
    final decoder = ResponsesStreamDecoder();
    final reasoning = decoder.accept(
      _event({'type': 'response.reasoning_text.delta', 'delta': 'think'}),
    );
    final text = decoder.accept(
      _event({'type': 'response.output_text.delta', 'delta': 'Hello'}),
    );
    final done = decoder.accept(
      _event({
        'type': 'response.completed',
        'response': {
          'usage': {
            'input_tokens': 10,
            'output_tokens': 4,
            'input_tokens_details': {'cached_tokens': 2},
          },
          'output': const [],
        },
      }),
    );

    expect(reasoning.chunks.whereType<ReasoningDelta>().single.text, 'think');
    expect(text.chunks.whereType<TextDelta>().single.text, 'Hello');
    expect(done.completed, isTrue);
    expect(done.chunks.whereType<Finish>(), isEmpty);
    expect(decoder.usage!.promptTokens, 10);
    expect(decoder.usage!.completionTokens, 4);
    expect(decoder.usage!.cachedTokens, 2);
    expect(decoder.onClosed(), isEmpty);
  });

  test('assembles indexed function calls and citations', () {
    final decoder = ResponsesStreamDecoder();
    decoder.accept(
      _event({
        'type': 'response.output_item.added',
        'output_index': 0,
        'item': {
          'type': 'function_call',
          'call_id': 'call_1',
          'name': 'lookup',
        },
      }),
    );
    decoder.accept(
      _event({
        'type': 'response.function_call_arguments.delta',
        'output_index': 0,
        'delta': '{"q":',
      }),
    );
    decoder.accept(
      _event({
        'type': 'response.output_item.done',
        'output_index': 0,
        'item': {
          'type': 'function_call',
          'call_id': 'call_1',
          'name': 'lookup',
          'arguments': '{"q":"kelivo"}',
        },
      }),
    );
    decoder.accept(
      _event({
        'type': 'response.completed',
        'response': {
          'output': [
            {
              'type': 'message',
              'content': [
                {
                  'type': 'output_text',
                  'annotations': [
                    {
                      'type': 'url_citation',
                      'url': 'https://example.com',
                      'title': 'Example',
                    },
                  ],
                },
              ],
            },
          ],
        },
      }),
    );

    final call = decoder.takeFunctionCalls().single;
    expect(call.callId, 'call_1');
    expect(call.name, 'lookup');
    expect(call.decodedArguments['q'], 'kelivo');
    expect(decoder.citations.single['url'], 'https://example.com');
    expect(decoder.outputItems, isNotEmpty);
  });

  test('emits ToolCall and citation events from parsed side-channels', () {
    final decoder = ResponsesStreamDecoder();
    final start = decoder.accept(
      _event({
        'type': 'response.output_item.added',
        'output_index': 0,
        'item': {
          'type': 'function_call',
          'call_id': 'call_1',
          'name': 'lookup',
        },
      }),
    );
    final delta = decoder.accept(
      _event({
        'type': 'response.function_call_arguments.delta',
        'output_index': 0,
        'delta': '{"q":',
      }),
    );
    final end = decoder.accept(
      _event({
        'type': 'response.output_item.done',
        'output_index': 0,
        'item': {
          'type': 'function_call',
          'call_id': 'call_1',
          'name': 'lookup',
          'arguments': '{"q":"kelivo"}',
        },
      }),
    );
    final done = decoder.accept(
      _event({
        'type': 'response.completed',
        'response': {
          'output': [
            {
              'type': 'message',
              'content': [
                {
                  'type': 'output_text',
                  'annotations': [
                    {
                      'type': 'url_citation',
                      'url': 'https://example.com',
                      'title': 'Example',
                    },
                  ],
                },
              ],
            },
          ],
        },
      }),
    );

    expect(start.chunks.whereType<ToolCallStart>().single.id, 'call_1');
    expect(start.chunks.whereType<ToolCallStart>().single.toolName, 'lookup');
    expect(delta.chunks.whereType<ToolCallDelta>().single.inputDelta, '{"q":');
    expect(end.chunks.whereType<ToolCallEnd>().single.id, 'call_1');
    expect(done.chunks.whereType<Annotations>().single.id, 'stream:search-1');
    expect(
      done.chunks.whereType<Annotations>().single.annotations.single,
      isA<UrlCitationAnnotation>(),
    );
    expect(
      (done.chunks.whereType<Annotations>().single.annotations.single
              as UrlCitationAnnotation)
          .url,
      'https://example.com',
    );
  });

  test('emits ServerTool events for hosted search items', () {
    final decoder = ResponsesStreamDecoder();
    final start = decoder.accept(
      _event({
        'type': 'response.output_item.added',
        'item': {
          'id': 'st_1',
          'type': 'openrouter:web_search',
          'status': 'in_progress',
        },
      }),
    );
    final end = decoder.accept(
      _event({
        'type': 'response.output_item.done',
        'item': {
          'id': 'st_1',
          'type': 'openrouter:web_search',
          'status': 'completed',
          'action': {'query': 'kotlin'},
        },
      }),
    );
    expect(start.chunks.whereType<ServerToolStart>().single.id, 'st_1');
    expect(
      start.chunks.whereType<ServerToolStart>().single.toolName,
      'search_web',
    );
    expect(
      end.chunks.whereType<ServerToolEnd>().single.status,
      ServerToolStatus.completed,
    );
    expect(
      (end.chunks.whereType<ServerToolEnd>().single.output as Map)['query'],
      'kotlin',
    );
  });

  test('maps response.incomplete to failed ServerToolEnd status', () {
    final decoder = ResponsesStreamDecoder();
    decoder.accept(
      _event({
        'type': 'response.output_item.added',
        'item': {
          'id': 'st_1',
          'type': 'web_search_call',
          'status': 'in_progress',
        },
      }),
    );
    final done = decoder.accept(
      _event({
        'type': 'response.incomplete',
        'response': {'status': 'incomplete', 'output': const <dynamic>[]},
      }),
    );
    expect(done.completed, isTrue);
    expect(
      done.chunks.whereType<ServerToolEnd>().single.status,
      ServerToolStatus.failed,
    );
    expect(done.chunks.whereType<Finish>(), isEmpty);
  });

  test('keeps the latest image generation snapshot per index', () {
    final decoder = ResponsesStreamDecoder();
    decoder.accept(
      _event({
        'type': 'response.image_generation_call.partial_image',
        'output_index': 2,
        'partial_image_b64': 'aaa',
        'output_format': 'png',
      }),
    );
    decoder.accept(
      _event({
        'type': 'response.completed',
        'response': {
          'output': [
            {'type': 'message', 'content': const []},
            {'type': 'message', 'content': const []},
            {
              'type': 'image_generation_call',
              'result': 'final-bytes',
              'output_format': 'jpeg',
            },
          ],
        },
      }),
    );

    final image = decoder.takeImages().single;
    expect(image.index, 2);
    expect(image.base64, 'final-bytes');
    expect(image.outputFormat, 'jpeg');
    expect(decoder.emittedImageEvents, isTrue);
  });

  test('emits ImageStart Snapshot End for partial then final frames', () {
    final decoder = ResponsesStreamDecoder();
    final partial = decoder.accept(
      _event({
        'type': 'response.image_generation_call.partial_image',
        'output_index': 2,
        'item_id': 'ig_1',
        'partial_image_b64': 'aaa',
        'output_format': 'png',
      }),
    );
    final done = decoder.accept(
      _event({
        'type': 'response.completed',
        'response': {
          'output': [
            {'type': 'message', 'content': const []},
            {'type': 'message', 'content': const []},
            {
              'id': 'ig_1',
              'type': 'image_generation_call',
              'result': 'final-bytes',
              'output_format': 'jpeg',
            },
          ],
        },
      }),
    );

    expect(partial.chunks.whereType<ImageStart>().single.id, 'ig_1');
    expect(partial.chunks.whereType<ImageSnapshot>().single.data, 'aaa');
    expect(done.chunks.whereType<ImageSnapshot>().single.data, 'final-bytes');
    expect(done.chunks.whereType<ImageEnd>().single.id, 'ig_1');
  });

  test('completes even when a message content block is not a list', () {
    final decoder = ResponsesStreamDecoder();
    final done = decoder.accept(
      _event({
        'type': 'response.completed',
        'response': {
          'usage': {'input_tokens': 3, 'output_tokens': 1},
          'output': [
            {'type': 'message', 'content': 'plain-string'},
            {
              'type': 'function_call',
              'call_id': 'call_x',
              'name': 'lookup',
              'arguments': '{}',
            },
          ],
        },
      }),
    );

    expect(done.completed, isTrue);
    expect(decoder.usage!.promptTokens, 3);
    expect(decoder.outputItems, hasLength(2));
  });

  test('skips malformed JSON and emits citations as Annotations', () {
    final decoder = ResponsesStreamDecoder();
    decoder.accept(const SseEvent(data: 'not-json'));
    final done = decoder.accept(
      _event({
        'type': 'response.completed',
        'response': {
          'output': [
            {
              'type': 'message',
              'content': [
                {
                  'annotations': [
                    {
                      'type': 'url_citation',
                      'url': 'https://a.example',
                      'title': 'A',
                    },
                  ],
                },
              ],
            },
          ],
        },
      }),
    );

    expect(decoder.citations, isNotEmpty);
    final annotation =
        done.chunks.whereType<Annotations>().single.annotations.single
            as UrlCitationAnnotation;
    expect(annotation.url, 'https://a.example');
    expect(annotation.title, 'A');
  });

  test('malformed frame keeps parsed chunks and later text still decodes', () {
    final decoder = ResponsesStreamDecoder();
    final first = decoder.accept(
      _event({'type': 'response.output_text.delta', 'delta': 'Hello'}),
    );
    final textId = first.chunks.whereType<TextDelta>().single.id;

    final started = decoder.accept(
      _event({
        'type': 'response.output_item.added',
        'output_index': 0,
        'item': {
          'type': 'function_call',
          'call_id': 'call_1',
          'name': 'lookup',
        },
      }),
    );
    expect(started.chunks.whereType<ToolCallStart>().single.id, 'call_1');

    final malformed = decoder.accept(
      _event({
        'type': 'response.function_call_arguments.delta',
        'output_index': 'bad',
        'delta': '{"q":',
      }),
    );
    expect(malformed.completed, isFalse);
    expect(malformed.chunks, isEmpty);

    final later = decoder.accept(
      _event({'type': 'response.output_text.delta', 'delta': ' world'}),
    );
    expect(later.chunks.whereType<TextDelta>().single.text, ' world');
    expect(later.chunks.whereType<TextDelta>().single.id, textId);

    final delta = decoder.accept(
      _event({
        'type': 'response.function_call_arguments.delta',
        'output_index': 0,
        'delta': '{"q":"kelivo"}',
      }),
    );
    expect(delta.chunks.whereType<ToolCallDelta>().single.id, 'call_1');
  });

  test(
    'late call_id keeps first-seen series id for emit, approval, and transcript',
    () async {
      final decoder = ResponsesStreamDecoder(sourceId: 'round-0');
      final start = decoder.accept(
        _event({
          'type': 'response.output_item.added',
          'output_index': 0,
          'item': {'type': 'function_call', 'id': 'fc_1', 'name': 'lookup'},
        }),
      );
      decoder.accept(
        _event({
          'type': 'response.function_call_arguments.delta',
          'output_index': 0,
          'delta': '{"q":"kelivo"}',
        }),
      );
      decoder.accept(
        _event({
          'type': 'response.output_item.done',
          'output_index': 0,
          'item': {
            'type': 'function_call',
            'id': 'fc_1',
            'call_id': 'call_late',
            'name': 'lookup',
            'arguments': '{"q":"kelivo"}',
          },
        }),
      );

      final uiId = start.chunks.whereType<ToolCallStart>().single.id;
      expect(uiId, 'fc_1');
      expect(decoder.toolCallsByIndex[0]!.seriesId, 'fc_1');
      expect(decoder.toolCallsByIndex[0]!.callId, 'call_late');

      final decoded = decoder.takeFunctionCalls().single;
      expect(decoded.seriesId, 'fc_1');
      expect(decoded.callId, 'call_late');

      final emitCall = responsesCallsFromIndexMap({
        decoded.index: decoded.toIndexFields(),
      }).single;
      expect(emitCall.id, uiId);
      expect(emitCall.providerCallId, 'call_late');
      expect(openaiTranscriptCallId(emitCall), 'call_late');
      expect(
        withResponsesFunctionCallItems(const [], [emitCall]).single['call_id'],
        'call_late',
      );

      final approval = ToolApprovalService();
      addTearDown(approval.dispose);
      final approvalFuture = approval.requestApproval(
        toolCallId: emitCall.id,
        toolName: emitCall.name,
        arguments: emitCall.arguments,
        conversationId: 'conversation-responses-late-id',
      );
      expect(
        approval.pendingFor(
          toolCallId: uiId,
          conversationId: 'conversation-responses-late-id',
        ),
        isNotNull,
      );
      approval.approve(uiId, conversationId: 'conversation-responses-late-id');
      expect((await approvalFuture).approved, isTrue);
    },
  );

  test('follow-up decoder usage is the cumulative snapshot', () {
    final first = ResponsesStreamDecoder();
    final firstDone = first.accept(
      _event({
        'type': 'response.completed',
        'response': {
          'usage': {'input_tokens': 100, 'output_tokens': 20},
          'output': const [],
        },
      }),
    );
    expect(first.usage!.promptTokens, 100);
    expect(first.usage!.completionTokens, 20);
    expect(first.usage!.totalTokens, 120);
    expect(firstDone.chunks.whereType<Usage>().single.usage.promptTokens, 100);

    final second = ResponsesStreamDecoder(initialUsage: first.usage);
    final follow = second.accept(
      _event({
        'type': 'response.completed',
        'response': {
          'usage': {'input_tokens': 300, 'output_tokens': 40},
          'output': const [],
        },
      }),
    );

    expect(second.usage!.promptTokens, 400);
    expect(second.usage!.completionTokens, 60);
    expect(second.usage!.totalTokens, 460);
    final streamed = follow.chunks.whereType<Usage>().single.usage;
    expect(streamed.promptTokens, 400);
    expect(streamed.completionTokens, 60);
    expect(streamed.totalTokens, 460);
  });

  test('a follow-up round without usage keeps the prior snapshot', () {
    final first = ResponsesStreamDecoder();
    first.accept(
      _event({
        'type': 'response.completed',
        'response': {
          'usage': {'input_tokens': 100, 'output_tokens': 20},
          'output': const [],
        },
      }),
    );
    final second = ResponsesStreamDecoder(initialUsage: first.usage);
    final silent = second.accept(
      _event({'type': 'response.output_text.delta', 'delta': 'ok'}),
    );

    expect(second.usage!.promptTokens, 100);
    expect(second.usage!.completionTokens, 20);
    expect(second.usage!.totalTokens, 120);
    expect(silent.chunks.whereType<Usage>(), isEmpty);
  });
}
