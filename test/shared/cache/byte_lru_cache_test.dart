import 'dart:typed_data';

import 'package:Kelivo/shared/cache/byte_lru_cache.dart';
import 'package:Kelivo/shared/widgets/mermaid_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('byte LRU promotes reads and evicts by decoded size', () {
    final cache = ByteLruCache<String, String>(
      maxBytes: 10,
      sizeOf: (_, value) => value.length,
    );
    cache.put('a', 'aaaa');
    cache.put('b', 'bbbb');
    expect(cache.get('a'), 'aaaa');

    cache.put('c', 'cccc');

    expect(cache.get('b'), isNull);
    expect(cache.get('a'), 'aaaa');
    expect(cache.get('c'), 'cccc');
    expect(cache.bytes, 8);
    expect(cache.evictions, 1);
  });

  test('oversized values are never retained', () {
    final cache = ByteLruCache<String, String>(
      maxBytes: 4,
      sizeOf: (_, value) => value.length,
    );
    cache.put('large', '12345');
    expect(cache.length, 0);
    expect(cache.bytes, 0);
  });

  test('Mermaid bitmap cache uses bytes rather than entry count', () {
    addTearDown(() {
      MermaidImageCache.configure(maxBytes: 24 << 20);
      MermaidImageCache.clear();
    });
    MermaidImageCache.configure(maxBytes: 20);
    MermaidImageCache.put('a', Uint8List(12));
    MermaidImageCache.put('b', Uint8List(12));

    expect(MermaidImageCache.get('a'), isNull);
    expect(MermaidImageCache.get('b'), isNotNull);
    expect(MermaidImageCache.bytes, lessThanOrEqualTo(20));
  });
}
