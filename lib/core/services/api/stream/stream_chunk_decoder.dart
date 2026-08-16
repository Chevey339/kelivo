import 'sse_event.dart';
import 'stream_chunk.dart';

/// Stateful, transport-agnostic decoder for one provider response stream.
///
/// Create a fresh instance per response stream. Do not reuse across streams.
abstract class StreamChunkDecoder {
  /// Convert a single raw SSE event into generic stream events.
  ///
  /// Implementations should throw when the payload cannot be parsed.
  DecodeResult accept(SseEvent event);

  /// Flush remaining state when the SSE connection closes normally.
  ///
  /// Must be idempotent with an explicit terminal event: if [accept] already
  /// emitted [Finish], this returns an empty list. If the stream ended
  /// without a terminal event, this emits a single [Finish].
  List<StreamChunk> onClosed();
}

class DecodeResult {
  const DecodeResult({
    this.chunks = const <StreamChunk>[],
    this.completed = false,
  });

  final List<StreamChunk> chunks;

  /// The provider protocol has ended; the transport may close the connection.
  final bool completed;
}
