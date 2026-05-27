import 'package:test/test.dart';
import 'package:mcp_client/src/transport/event_source.dart';

void main() {
  group('EventSource Web Platform', () {
    test('EventSource can be instantiated', () {
      // This test will only pass on web platform
      // On native platforms, it will use EventSource from event_source_io.dart
      final eventSource = EventSource();
      expect(eventSource, isNotNull);
      expect(eventSource.isConnected, isFalse);
    });
  });
}
