import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/services/api/providers/claude/claude_decoder.dart';
import 'package:Kelivo/core/services/api/providers/google/google_decoder.dart';
import 'package:Kelivo/core/services/api/providers/openai/chat_completions_decoder.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_decoder.dart';
import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_decoder.dart';
import 'package:Kelivo/core/services/api/stream/stream_trace.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _updateEnv = 'UPDATE_STREAM_TRACES';

void main() {
  test('replay Claude thinking + parallel tools + web_search', () {
    final decoder = ClaudeStreamDecoder();
    final replayed = _replay('claude/thinking-tools-search', decoder);
    _assertCommon(replayed);
    expect(replayed.chunks.whereType<ReasoningDelta>(), isNotEmpty);
    expect(
      replayed.chunks.whereType<ToolCallStart>().map((c) => c.toolName),
      containsAll(<String>['get_weather', 'lookup', 'search_web']),
    );
    expect(
      replayed.chunks.whereType<ToolCallEnd>().map((c) => c.id).toSet().length,
      greaterThanOrEqualTo(2),
    );
    expect(
      replayed.chunks.whereType<ServerToolStart>().map((c) => c.toolName),
      contains('search_web'),
    );
    expect(replayed.chunks.whereType<ServerToolEnd>(), isNotEmpty);
    final items =
        (replayed.chunks.whereType<ServerToolEnd>().first.output
                as Map)['items']
            as List;
    expect(items, isNotEmpty);
    expect(items.first['url'].toString(), startsWith('http'));
    expect(
      decoder.assistantBlocks.any((block) => block['type'] == 'thinking'),
      isTrue,
    );
    expect(decoder.lastStopReason, isNotEmpty);
  });

  test('replay Gemini thinking + image snapshot replace', () {
    final decoder = GoogleStreamDecoder(persistThoughtSigs: true);
    final replayed = _replay(
      'google/thinking-image',
      decoder,
      extras: (events) {
        final image = decoder.takeBufferedImage();
        return <String, dynamic>{
          if (image != null)
            'bufferedImage': <String, dynamic>{
              'mimeType': image.mimeType,
              'byteCount': _bytes(image.data).length,
              'sha256': sha256.convert(_bytes(image.data)).toString(),
            },
          'receivedImage': decoder.receivedImage,
          'imageThoughtSigs': [
            for (final sig in decoder.imageThoughtSigs)
              <String, dynamic>{
                'k': sig['k'],
                'sha256': sha256.convert(utf8.encode('${sig['v']}')).toString(),
              },
          ],
        };
      },
    );
    _assertCommon(replayed);
    expect(replayed.chunks.whereType<ReasoningDelta>(), isNotEmpty);
    expect(replayed.chunks.whereType<ImageStart>(), isNotEmpty);
    expect(
      replayed.chunks.where((c) => c is ImageDelta || c is ImageSnapshot),
      isNotEmpty,
    );
    expect(replayed.chunks.whereType<ImageEnd>(), isNotEmpty);
    expect(decoder.receivedImage, isTrue);
    expect(decoder.imageThoughtSigs, isNotEmpty);
    expect(decoder.imageThoughtSigs.first['v'].toString(), isNotEmpty);
    expect(_googleThoughtSignatures(replayed.events), isNotEmpty);
    expect(
      replayed.snapshot['extras']?['bufferedImage']?['sha256'],
      isNotEmpty,
    );
  });

  test('replay Chat Completions reasoning_details + parallel tools', () {
    final decoder = ChatCompletionsStreamDecoder(
      needsReasoningEcho: true,
      allowReasoningSnapshots: false,
    );
    final replayed = _replay(
      'openai-chat/reasoning-parallel-tools',
      decoder,
      extras: (_) => <String, dynamic>{
        'finishReason': decoder.finishReason,
        'toolCalls': [
          for (final key in (decoder.toolCalls.keys.toList()..sort()))
            <String, dynamic>{'index': key, ...decoder.toolCalls[key]!},
        ],
        if (decoder.reasoningDetails != null)
          'reasoningDetails': _hashReasoningDetails(decoder.reasoningDetails),
      },
    );
    _assertCommon(replayed);
    expect(decoder.reasoningEcho, isNotEmpty);
    expect(decoder.reasoningDetails, isNotEmpty);
    expect(
      replayed.chunks.whereType<ToolCallStart>().map((c) => c.toolName),
      everyElement('search_web'),
    );
    expect(
      replayed.chunks.whereType<ToolCallEnd>().map((c) => c.id).toSet().length,
      greaterThanOrEqualTo(2),
    );
    expect(decoder.finishReason, 'tool_calls');
  });

  test('replay Responses incomplete + server-search citation', () {
    final decoder = ResponsesStreamDecoder();
    final replayed = _replay(
      'openai-responses/server-tool-incomplete',
      decoder,
      extras: (_) => <String, dynamic>{
        'citations': decoder.citations,
        'functionCallCount': decoder.takeFunctionCalls().length,
        'outputItemTypes': [
          for (final item in decoder.outputItems) item['type'],
        ],
      },
    );
    _assertCommon(replayed);
    expect(decoder.completed, isTrue);
    expect(
      replayed.chunks.whereType<ServerToolStart>().map((c) => c.toolName),
      contains('search_web'),
    );
    expect(replayed.chunks.whereType<ServerToolEnd>(), isNotEmpty);
    expect(
      replayed.chunks
          .whereType<Annotations>()
          .expand((c) => c.annotations)
          .whereType<UrlCitationAnnotation>()
          .map((a) => a.url),
      everyElement(startsWith('http')),
    );
    expect(
      decoder.outputItems.map((item) => item['type']?.toString() ?? ''),
      anyElement(contains('search')),
    );
    expect(replayed.chunks.whereType<TextDelta>(), isNotEmpty);
  });
}

class _Replay {
  const _Replay({
    required this.path,
    required this.events,
    required this.chunks,
    required this.snapshot,
  });

  final String path;
  final List<SseEvent> events;
  final List<StreamChunk> chunks;
  final Map<String, dynamic> snapshot;
}

_Replay _replay(
  String path,
  StreamChunkDecoder decoder, {
  Map<String, dynamic> Function(List<SseEvent> events)? extras,
}) {
  final fixtureDir = Directory('test/fixtures/stream-traces/$path');
  final events = loadSseEventsJsonl(
    File('${fixtureDir.path}/events.jsonl').readAsStringSync(),
  );
  final chunks = <StreamChunk>[];
  var completed = false;
  for (final event in events) {
    final decoded = decoder.accept(event);
    chunks.addAll(decoded.chunks);
    completed = decoded.completed || completed;
  }
  chunks.addAll(decoder.onClosed());
  expect(
    decoder.onClosed(),
    isEmpty,
    reason: '$path onClosed must be idempotent',
  );

  final snapshot = streamTraceSnapshot(
    chunks: chunks,
    completed: completed,
    extras: extras?.call(events),
  );
  final expectedFile = File('${fixtureDir.path}/expected.json');
  if (Platform.environment[_updateEnv] == 'true') {
    expectedFile.writeAsStringSync('${encodeTraceSnapshot(snapshot)}\n');
  }
  expect(
    expectedFile.existsSync(),
    isTrue,
    reason: 'Missing $path/expected.json; rerun with $_updateEnv=true',
  );
  expect(
    jsonDecode(expectedFile.readAsStringSync()),
    snapshot,
    reason: '$path snapshot mismatch',
  );
  return _Replay(
    path: path,
    events: events,
    chunks: chunks,
    snapshot: snapshot,
  );
}

void _assertCommon(_Replay replayed) {
  expect(
    replayed.chunks.whereType<Finish>(),
    isEmpty,
    reason: '${replayed.path} decoder must leave Finish to the provider',
  );
  final toolIds = replayed.chunks.whereType<ToolCallEnd>().map((c) => c.id);
  expect(toolIds.toSet().length, toolIds.length);
}

List<String> _googleThoughtSignatures(List<SseEvent> events) {
  final signatures = <String>[];
  for (final event in events) {
    if (event.data.isEmpty || event.data == '[DONE]') continue;
    final decoded = jsonDecode(event.data);
    if (decoded is! Map) continue;
    final candidates = decoded['candidates'];
    if (candidates is! List) continue;
    for (final candidate in candidates) {
      if (candidate is! Map) continue;
      final parts = candidate['content'] is Map
          ? candidate['content']['parts']
          : null;
      if (parts is! List) continue;
      for (final part in parts) {
        if (part is! Map) continue;
        final sig = part['thoughtSignature'] ?? part['thought_signature'];
        if (sig is String && sig.isNotEmpty) signatures.add(sig);
      }
    }
  }
  return signatures;
}

dynamic _hashReasoningDetails(dynamic details) {
  if (details is List) {
    return [for (final item in details) _hashReasoningDetails(item)];
  }
  if (details is Map) {
    return <String, dynamic>{
      for (final entry in details.entries)
        entry.key.toString(): entry.key == 'signature' || entry.key == 'data'
            ? sha256.convert(utf8.encode('${entry.value}')).toString()
            : _hashReasoningDetails(entry.value),
    };
  }
  return details;
}

List<int> _bytes(String data) {
  try {
    return base64Decode(data);
  } catch (_) {
    return utf8.encode(data);
  }
}
