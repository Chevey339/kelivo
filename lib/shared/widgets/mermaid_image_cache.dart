import 'dart:typed_data';

import '../cache/byte_lru_cache.dart';

class MermaidImageCache {
  static int _maxBytes = 24 << 20;
  static ByteLruCache<String, Uint8List> _cache = _newCache();

  static ByteLruCache<String, Uint8List> _newCache() => ByteLruCache(
    maxBytes: _maxBytes,
    sizeOf: (key, value) => key.length * 2 + value.lengthInBytes,
  );

  static String _normalize(String code) {
    return code.replaceAll('\r\n', '\n').trim();
  }

  static void configure({int? maxBytes, int? maxSize}) {
    final requested = maxBytes ?? (maxSize == null ? null : maxSize * 200000);
    if (requested == null || requested <= 0 || requested == _maxBytes) return;
    _maxBytes = requested;
    _cache = _newCache();
  }

  static Uint8List? get(String code) => _cache.get(_normalize(code));

  static void put(String code, Uint8List bytes) {
    final key = _normalize(code);
    _cache.put(key, bytes);
  }

  static int get bytes => _cache.bytes;
  static int get evictions => _cache.evictions;

  static void clear() => _cache.clear();
}
