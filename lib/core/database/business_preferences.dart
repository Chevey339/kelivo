import 'dart:async';

import 'business_data.dart';
import 'business_repository.dart';
import 'business_settings_router.dart';

/// An in-memory key-value view over business data in SQLite.
///
/// Callers share and inject one instance so synchronous reads observe the same
/// snapshot. Writes are serialized and update the in-memory view only after the
/// repository operation succeeds.
final class BusinessPreferences {
  BusinessPreferences(this._repository);

  static const _providersOrderKey = 'providers_order_v1';

  final BusinessRepository _repository;
  Map<String, Object> _values = <String, Object>{};
  Future<void>? _loadFuture;
  Future<void> _writeTail = Future<void>.value();
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> load() {
    if (_isLoaded) return Future<void>.value();
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;

    final future = _loadFromRepository();
    _loadFuture = future;
    return future;
  }

  Future<void> _loadFromRepository() async {
    try {
      final snapshot = await _repository.readSnapshot();
      _values = Map<String, Object>.from(
        BusinessSettingsRouter.exportRuntimeSnapshot(snapshot),
      );
      _isLoaded = true;
    } finally {
      _loadFuture = null;
    }
  }

  Object? get(String key) => _copyForRead(_values[key]);

  bool containsKey(String key) => _values.containsKey(key);

  Set<String> getKeys() => Set<String>.unmodifiable(_values.keys);

  bool? getBool(String key) => _values[key] as bool?;

  int? getInt(String key) => _values[key] as int?;

  double? getDouble(String key) => _values[key] as double?;

  String? getString(String key) => _values[key] as String?;

  List<String>? getStringList(String key) {
    final value = _values[key];
    if (value == null) return null;
    return List<String>.of((value as List).cast<String>());
  }

  Future<bool> setBool(String key, bool value) => _setValue(key, value);

  Future<bool> setInt(String key, int value) => _setValue(key, value);

  Future<bool> setDouble(String key, double value) => _setValue(key, value);

  Future<bool> setString(String key, String value) => _setValue(key, value);

  Future<bool> setStringList(String key, List<String> value) =>
      _setValue(key, List<String>.unmodifiable(value));

  Future<bool> remove(String key) async {
    await load();
    return _serialize(() async {
      final kind = _entityKindForKey(key);
      if (kind != null) {
        final next = Map<String, Object>.from(_values)..remove(key);
        final routed = BusinessSettingsRouter.normalizeAndRoute(next);
        await _repository.synchronizeEntities(kind, routed.entities[kind]!);
        _applyCanonicalEntity(kind, routed);
      } else {
        _validatePreferenceKey(key);
        await _repository.removePreference(key);
        _values.remove(key);
      }
      return true;
    });
  }

  Future<bool> _setValue(String key, Object value) async {
    await load();
    return _serialize(() async {
      final kind = _entityKindForKey(key);
      if (kind != null) {
        final next = Map<String, Object>.from(_values)..[key] = value;
        final routed = BusinessSettingsRouter.normalizeAndRoute(next);
        await _repository.synchronizeEntities(kind, routed.entities[kind]!);
        _applyCanonicalEntity(kind, routed);
      } else {
        _validatePreferenceKey(key);
        await _repository.setPreference(key, value);
        _values[key] = _copyForStorage(value);
      }
      return true;
    });
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _writeTail.then((_) => operation());
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  BusinessEntityKind? _entityKindForKey(String key) {
    if (key == _providersOrderKey) return BusinessEntityKind.provider;
    for (final kind in BusinessEntityKind.values) {
      if (kind.sourceKey == key) return kind;
    }
    return null;
  }

  void _applyCanonicalEntity(BusinessEntityKind kind, BusinessSnapshot routed) {
    final canonical = BusinessSettingsRouter.exportSnapshot(routed);
    _values[kind.sourceKey] = canonical[kind.sourceKey]!;
    if (kind == BusinessEntityKind.provider) {
      _values[_providersOrderKey] = canonical[_providersOrderKey]!;
    }
  }

  static void _validatePreferenceKey(String key) {
    final disposition = BusinessKeyRegistry.classify(key);
    if (disposition == BusinessKeyDisposition.localOnly ||
        disposition == BusinessKeyDisposition.discarded) {
      throw ArgumentError.value(key, 'key', 'Not a business preference');
    }
  }

  static Object _copyForStorage(Object value) {
    if (value is List) {
      return List<String>.unmodifiable(value.cast<String>());
    }
    return value;
  }

  static Object? _copyForRead(Object? value) {
    if (value is List) return List<String>.of(value.cast<String>());
    return value;
  }
}
