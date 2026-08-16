import 'package:Kelivo/core/services/api/stream/stream_chunk_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scopes kind and sequence to the source id', () {
    final ids = StreamChunkIds('round-1');
    expect(ids.text(), 'round-1:text-1');
    expect(ids.reasoning(), 'round-1:reasoning-2');
    expect(ids.text(), 'round-1:text-1');
    expect(ids.search(), 'round-1:search-3');
    expect(ids.search(), 'round-1:search-4');
    expect(ids.searchSticky(), 'round-1:search-5');
    expect(ids.searchSticky(), 'round-1:search-5');
    expect(ids.indexed('text', 0), 'round-1:text-0');
  });

  test('omits the prefix when sourceId is empty', () {
    final ids = StreamChunkIds('');
    expect(ids.text(), 'text-1');
    expect(ids.indexed('thinking', 2), 'thinking-2');
  });
}
