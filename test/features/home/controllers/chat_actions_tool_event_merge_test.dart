import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/home/controllers/streaming_tool_events.dart';

void main() {
  Map<String, dynamic> event(String id, String name, [String? content]) => {
    'id': id,
    'name': name,
    'arguments': <String, dynamic>{},
    'content': content,
  };

  test(
    'concurrent calls complete out of order without changing previous checkpoints',
    () {
      final events = StreamingToolEvents()
        ..start(event('a', 'calculate'))
        ..start(event('b', 'calculate'));
      final pending = events.snapshot;
      expect(events.snapshot, same(pending));
      events
        ..complete(event('b', 'calculate', 'second'))
        ..start(event('b', 'calculate'))
        ..complete(event('a', 'calculate', 'first'));
      expect(events.snapshot.map((e) => e['content']), ['first', 'second']);
      expect(pending.map((e) => e['content']), [null, null]);
    },
  );

  test('anonymous and padded IDs retain the persisted deduplication rules', () {
    final events = StreamingToolEvents()
      ..complete(event('', 'calculate', '12'))
      ..complete(event('', 'calculate', '12'))
      ..start(event(' x ', 'lookup'))
      ..complete(event('x', 'other name', 'found'))
      ..start(event('next', 'calculate'));
    expect(events.snapshot.map((e) => e['id']), ['', 'x', 'next']);
    expect(events.snapshot.map((e) => e['content']), ['12', 'found', null]);
  });

  test(
    'mergeStreamingToolEventRecord keeps non-empty args and server flag',
    () {
      final events = StreamingToolEvents([
        {
          'id': 'code_1',
          'name': 'code_execution',
          'arguments': {'language': 'python', 'code': 'print(1)'},
          'content': 'ok',
          'server': true,
          'metadata': {'round': 1},
        },
      ]);
      events.complete({
        'id': 'code_1',
        'name': 'code_execution',
        'arguments': <String, dynamic>{},
        'content': null,
        'metadata': {'source': 'server'},
      });
      final merged = events.snapshot.single;

      expect(merged['arguments'], {'language': 'python', 'code': 'print(1)'});
      expect(merged['content'], 'ok');
      expect(merged['server'], isTrue);
      expect(merged['metadata'], {'round': 1, 'source': 'server'});
    },
  );

  test(
    'resuming a stored call with raw JSON arguments preserves the record',
    () {
      final stored = {
        ...event('prior', 'calculate', '12'),
        'arguments': '{"expression":"3*4"}',
      };
      final events = StreamingToolEvents([stored])
        ..start(event('new', 'calculate'));
      expect(events.snapshot.first, stored);
      expect(events.snapshot.last['id'], 'new');
    },
  );
}
