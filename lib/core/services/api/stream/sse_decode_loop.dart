import '../chat_api_helpers.dart';
import 'sse_event.dart';
import 'stream_chunk.dart';
import 'stream_chunk_decoder.dart';

/// Feed [events] through [decoder], including `[DONE]`, then [onClosed].
///
/// OpenAI follow-up loops must yield the `[DONE]` chunks — that is how
/// [StreamChunkDecoder.accept] closes open tool / image / search series.
/// Call [onClosed] afterwards so a stream that ends without `[DONE]` still
/// flushes those ends. The two are idempotent.
Stream<StreamChunk> decodeSseEvents(
  Stream<SseEvent> events,
  StreamChunkDecoder decoder,
) async* {
  await for (final event in events) {
    final data = event.data;
    if (data.isNotEmpty && data != '[DONE]') {
      throwIfInBandStreamError(data);
    }
    final decoded = decoder.accept(event);
    for (final chunk in decoded.chunks) {
      yield chunk;
    }
    if (data == '[DONE]' || decoded.completed) break;
  }
  for (final chunk in decoder.onClosed()) {
    yield chunk;
  }
}
