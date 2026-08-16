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

  /// Flush remaining open series when the SSE connection closes.
  ///
  /// Idempotent: a second call returns an empty list. Do not emit [Finish]
  /// here — the provider emits [Finish] after [onClosed]. A second call
  /// after an explicit terminal event must also be empty.
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
