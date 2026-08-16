import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SseEvent keeps framing fields and leaves payload untouched', () {
    const event = SseEvent(
      id: '42',
      event: 'message_delta',
      data: '{"type":"content_block_delta"}',
      retryMillis: 1500,
    );

    expect(event.id, '42');
    expect(event.event, 'message_delta');
    expect(event.data, '{"type":"content_block_delta"}');
    expect(event.retryMillis, 1500);
  });

  test('SseEvent data may contain concatenated multiline payloads', () {
    const event = SseEvent(data: 'hello\nworld');
    expect(event.data, 'hello\nworld');
    expect(event.id, isNull);
    expect(event.event, isNull);
    expect(event.retryMillis, isNull);
  });
}
