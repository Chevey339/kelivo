import 'dart:collection';

typedef CacheByteSize<K, V> = int Function(K key, V value);

/// Least-recently-used cache bounded by decoded memory, not entry count.
final class ByteLruCache<K, V> {
  ByteLruCache({required this.maxBytes, required this.sizeOf})
    : assert(maxBytes > 0);

  final int maxBytes;
  final CacheByteSize<K, V> sizeOf;
  final LinkedHashMap<K, _ByteLruEntry<V>> _entries = LinkedHashMap();
  int _bytes = 0;
  int _evictions = 0;

  int get bytes => _bytes;
  int get length => _entries.length;
  int get evictions => _evictions;

  V? get(K key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    _entries[key] = entry;
    return entry.value;
  }

  void put(K key, V value) {
    final previous = _entries.remove(key);
    if (previous != null) _bytes -= previous.bytes;
    final bytes = sizeOf(key, value).clamp(0, maxBytes + 1).toInt();
    if (bytes > maxBytes) {
      _evictions += previous == null ? 0 : 1;
      return;
    }
    _entries[key] = _ByteLruEntry(value, bytes);
    _bytes += bytes;
    while (_bytes > maxBytes && _entries.isNotEmpty) {
      final oldestKey = _entries.keys.first;
      final removed = _entries.remove(oldestKey)!;
      _bytes -= removed.bytes;
      _evictions++;
    }
  }

  void clear() {
    _entries.clear();
    _bytes = 0;
  }
}

final class _ByteLruEntry<V> {
  const _ByteLruEntry(this.value, this.bytes);

  final V value;
  final int bytes;
}
