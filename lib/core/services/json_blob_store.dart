import 'dart:convert';

import '../database/business_preferences.dart';

/// Base class for stores that persist a whole list as one JSON blob.
///
/// Mutations run through a per-instance serialized queue so concurrent
/// read-modify-write cycles cannot drop each other's records. A blob that
/// fails to decode throws instead of reading as empty, so a truncated
/// snapshot is never persisted over the surviving rows.
abstract class JsonBlobStore<T> {
  JsonBlobStore(this._preferences);

  final BusinessPreferences _preferences;
  Future<void> _writeTail = Future<void>.value();

  /// Exposed for subclasses that manage additional keys beyond the blob.
  BusinessPreferences get preferences => _preferences;

  String get storageKey;

  T decodeItem(Map<String, dynamic> json);

  Map<String, dynamic> encodeItem(T item);

  /// Reads the whole blob. Throws [StateError] when decoding fails.
  Future<List<T>> readAll() async {
    await _preferences.load();
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return <T>[];
    return decodeAll(raw);
  }

  List<T> decodeAll(String raw) {
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return <T>[
        for (final value in values)
          decodeItem((value as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      throw StateError('json_blob_store_corrupt:$storageKey');
    }
  }

  /// Persists a complete list. Callers must pass their full intended
  /// snapshot; partial reads must go through [readAll] first.
  Future<void> writeAll(List<T> items) {
    return _preferences.setString(
      storageKey,
      jsonEncode(items.map(encodeItem).toList()),
    );
  }

  /// Runs [operation] after all previously accepted operations drained.
  Future<R> runExclusive<R>(Future<R> Function() operation) {
    final result = _writeTail.then((_) => operation());
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }
}
