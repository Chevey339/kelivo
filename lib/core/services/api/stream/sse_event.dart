/// HTTP-client-agnostic Server-Sent Event.
///
/// [event] is the SSE `event:` field. A vendor JSON `type` inside the payload
/// stays in [data]. Trace fixtures record this layer so decoders can be
/// replayed without any HTTP client.
class SseEvent {
  const SseEvent({required this.data, this.id, this.event, this.retryMillis});

  final String? id;
  final String? event;
  final String data;
  final int? retryMillis;
}
