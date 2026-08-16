import 'dart:convert';

import 'package:Kelivo/core/services/api/providers/google/google_decoder.dart';
import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:flutter_test/flutter_test.dart';

SseEvent _event(Map<String, dynamic> data) {
  return SseEvent(data: jsonEncode(data));
}

Map<String, dynamic> _candidate({
  List<Map<String, dynamic>> parts = const <Map<String, dynamic>>[],
  String? finishReason,
  Map<String, dynamic>? grounding,
}) {
  return <String, dynamic>{
    'candidates': [
      <String, dynamic>{
        'content': <String, dynamic>{'parts': parts},
        if (finishReason != null) 'finishReason': finishReason,
        if (grounding != null) 'groundingMetadata': grounding,
      },
    ],
  };
}

void main() {
  test('streams text and reasoning without emitting Finish', () {
    final decoder = GoogleStreamDecoder();
    final first = decoder.accept(
      _event(
        _candidate(
          parts: [
            <String, dynamic>{'text': 'think', 'thought': true},
            <String, dynamic>{'text': 'Hello'},
          ],
        ),
      ),
    );
    final done = decoder.accept(
      _event(
        _candidate(
          parts: [
            <String, dynamic>{'text': ' world'},
          ],
          finishReason: 'STOP',
        ),
      ),
    );

    expect(
      [
        ...first.chunks,
        ...done.chunks,
      ].whereType<ReasoningDelta>().map((c) => c.text).join(),
      'think',
    );
    expect(
      [
        ...first.chunks,
        ...done.chunks,
      ].whereType<TextDelta>().map((c) => c.text).join(),
      'Hello world',
    );
    expect(done.completed, isTrue);
    expect(done.chunks.whereType<Finish>(), isEmpty);
    expect(decoder.onClosed(), isEmpty);
  });

  test('assembles a client function call with google metadata', () {
    final decoder = GoogleStreamDecoder();
    final result = decoder.accept(
      _event(
        _candidate(
          parts: [
            <String, dynamic>{
              'functionCall': <String, dynamic>{
                'id': 'call_1',
                'name': 'lookup',
                'args': <String, dynamic>{'q': 'kelivo'},
              },
              'thoughtSignature': 'sig-1',
            },
          ],
        ),
      ),
    );

    expect(result.chunks.whereType<ToolCallStart>().single.id, 'call_1');
    expect(result.chunks.whereType<ToolCallStart>().single.toolName, 'lookup');
    expect(result.chunks.whereType<ToolCallEnd>().single.id, 'call_1');
    final call = decoder.functionCallById('call_1')!;
    expect(call.name, 'lookup');
    expect(call.args, <String, dynamic>{'q': 'kelivo'});
    expect(call.thoughtSigKey, 'thoughtSignature');
    expect(call.thoughtSigVal, 'sig-1');
    expect(decoder.isClientFunctionCall('call_1'), isTrue);
    expect(
      result.chunks
          .whereType<ToolCallStart>()
          .single
          .metadata!['google']['thoughtSigVal'],
      'sig-1',
    );
    expect(
      result.chunks.whereType<ToolCallDelta>().single.inputDelta,
      '{"q":"kelivo"}',
    );
  });

  test('maps code execution and citations to StreamChunks', () {
    final decoder = GoogleStreamDecoder();
    final result = decoder.accept(
      _event(
        _candidate(
          parts: [
            <String, dynamic>{
              'executableCode': <String, dynamic>{
                'language': 'PYTHON',
                'code': 'print(1)',
              },
            },
            <String, dynamic>{
              'codeExecutionResult': <String, dynamic>{
                'outcome': 'OUTCOME_OK',
                'output': '1',
              },
            },
          ],
          grounding: <String, dynamic>{
            'groundingChunks': [
              <String, dynamic>{
                'web': <String, dynamic>{
                  'uri': 'https://example.com',
                  'title': 'Example',
                },
              },
            ],
          },
        ),
      ),
    );

    expect(
      result.chunks.whereType<ToolCallStart>().single.toolName,
      'code_execution',
    );
    expect(
      result.chunks.whereType<ServerToolEnd>().map((chunk) => chunk.output),
      contains('1'),
    );
    expect(
      result.chunks.whereType<ServerToolStart>().map((chunk) => chunk.toolName),
      containsAll(<String>['code_execution', 'builtin_search']),
    );
  });

  test('replaces a complete preview frame instead of appending', () {
    final decoder = GoogleStreamDecoder();
    final first = decoder.accept(
      _event(
        _candidate(
          parts: [
            <String, dynamic>{
              'inlineData': <String, dynamic>{
                'mimeType': 'image/png',
                'data': 'iVBORw0KGgo=',
              },
            },
          ],
        ),
      ),
    );
    final second = decoder.accept(
      _event(
        _candidate(
          parts: [
            <String, dynamic>{
              'inlineData': <String, dynamic>{
                'mimeType': 'image/png',
                'data': 'iVBORw0KGgoAAA=',
              },
            },
          ],
        ),
      ),
    );

    expect(first.chunks.whereType<ImageStart>().single.mimeType, 'image/png');
    expect(first.chunks.whereType<ImageDelta>().single.data, 'iVBORw0KGgo=');
    expect(
      second.chunks.whereType<ImageSnapshot>().single.data,
      'iVBORw0KGgoAAA=',
    );
    expect(decoder.onClosed().whereType<ImageEnd>(), isNotEmpty);
    final pending = decoder.takeBufferedImage()!;
    expect(pending.data, 'iVBORw0KGgoAAA=');
    expect(decoder.receivedImage, isTrue);
    expect(decoder.takeBufferedImage(), isNull);
  });

  test('holds same-event text after fileData as image trailing text', () {
    final decoder = GoogleStreamDecoder();
    final result = decoder.accept(
      _event(
        _candidate(
          parts: [
            <String, dynamic>{
              'fileData': <String, dynamic>{
                'fileUri': 'https://example.com/a.png',
                'mimeType': 'image/png',
              },
            },
            <String, dynamic>{'text': ' a caption'},
          ],
        ),
      ),
    );

    expect(result.chunks.whereType<TextDelta>(), isEmpty);
    expect(decoder.takePendingRemoteImages(), isNotEmpty);
    decoder.ingestImageData('image/png', 'iVBORw0KGgo=');
    expect(decoder.takeOrphanedTrailingText(), isEmpty);
    expect(decoder.takeBufferedImage()!.trailingText, ' a caption');
  });

  test('promotes held fileData caption when the download never arrives', () {
    final decoder = GoogleStreamDecoder();
    decoder.accept(
      _event(
        _candidate(
          parts: [
            <String, dynamic>{
              'fileData': <String, dynamic>{
                'fileUri': 'https://example.com/a.png',
                'mimeType': 'image/png',
              },
            },
            <String, dynamic>{'text': ' a caption'},
          ],
        ),
      ),
    );
    decoder.takePendingRemoteImages();
    expect(
      decoder.takeOrphanedTrailingText().whereType<TextDelta>().single.text,
      ' a caption',
    );
  });

  test('queues remote fileData for the provider to download', () {
    final decoder = GoogleStreamDecoder(persistThoughtSigs: true);
    decoder.accept(
      _event(
        _candidate(
          parts: [
            <String, dynamic>{
              'fileData': <String, dynamic>{
                'fileUri': 'https://example.com/a.png',
                'mimeType': 'image/png',
              },
              'thoughtSignature': 'img-sig',
            },
          ],
        ),
      ),
    );

    final remote = decoder.takePendingRemoteImages().single;
    expect(remote.uri, 'https://example.com/a.png');
    decoder.ingestImageData(
      remote.mimeType,
      'iVBORw0KGgo=',
      thoughtSigKey: remote.thoughtSigKey,
      thoughtSigVal: remote.thoughtSigVal,
    );
    expect(decoder.imageThoughtSigs.single['v'], 'img-sig');
    expect(decoder.takeBufferedImage()!.data, 'iVBORw0KGgo=');
  });

  test('marks MALFORMED_RESPONSE for retry when there are no tool calls', () {
    final decoder = GoogleStreamDecoder();
    final result = decoder.accept(
      _event(_candidate(finishReason: 'MALFORMED_RESPONSE')),
    );
    expect(decoder.retryMalformedResponse, isTrue);
    expect(result.completed, isFalse);
  });

  test('waits for an expected image before completing', () {
    final decoder = GoogleStreamDecoder(expectImage: true);
    final first = decoder.accept(
      _event(
        _candidate(
          parts: [
            <String, dynamic>{'text': 'hi'},
          ],
          finishReason: 'STOP',
        ),
      ),
    );
    expect(first.completed, isFalse);

    decoder.accept(
      _event(
        _candidate(
          parts: [
            <String, dynamic>{
              'inlineData': <String, dynamic>{
                'mimeType': 'image/png',
                'data': 'iVBORw0KGgo=',
              },
            },
          ],
          finishReason: 'STOP',
        ),
      ),
    );
    expect(decoder.canFinishNow, isTrue);
    expect(decoder.streamComplete, isTrue);
  });

  test('records Gemini 3 model parts and skips malformed JSON', () {
    final decoder = GoogleStreamDecoder(
      isGemini3: true,
      persistThoughtSigs: true,
    );
    decoder.accept(const SseEvent(data: 'not-json'));
    decoder.accept(
      _event(
        _candidate(
          parts: [
            <String, dynamic>{'text': 'hi', 'thoughtSignature': 'text-sig'},
            <String, dynamic>{'text': 'hidden', 'thought': true},
          ],
        ),
      ),
    );

    expect(decoder.roundModelParts, hasLength(1));
    expect(decoder.roundModelParts.single['text'], 'hi');
    expect(decoder.textThoughtSigKey, 'thoughtSignature');
    expect(decoder.textThoughtSigVal, 'text-sig');
  });
}
