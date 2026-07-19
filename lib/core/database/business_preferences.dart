import 'dart:async';
import 'dart:convert';

import 'business_data.dart';
import 'business_repository.dart';
import 'business_settings_router.dart';

typedef _SyntheticEntityIdentity = ({
  String rowId,
  bool hadPayloadId,
  Object? payloadId,
});

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
  final Map<BusinessEntityKind, Map<String, _SyntheticEntityIdentity>>
  _syntheticIdentities = {};
  Future<void>? _loadFuture;
  Future<void> _writeTail = Future<void>.value();
  bool _isLoaded = false;
  bool _writesBlockedForRestore = false;

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
      _applyRuntimeSnapshot(snapshot);
      _isLoaded = true;
    } finally {
      _loadFuture = null;
    }
  }

  /// Drains accepted writes, runs one live restore, and keeps this process
  /// read-only after a successful commit. Restore callers already require a
  /// cold restart, so late background writes must not overwrite restored data.
  Future<T> runWithRestoreWriteFence<T>(Future<T> Function() operation) async {
    if (_writesBlockedForRestore) {
      throw StateError('business_preferences_restore_fence');
    }
    _writesBlockedForRestore = true;
    await _writeTail;
    try {
      return await operation();
    } catch (_) {
      _writesBlockedForRestore = false;
      rethrow;
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
        _applyRuntimeEntity(kind, routed);
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
        var routed = BusinessSettingsRouter.normalizeAndRoute(next);
        if (kind != BusinessEntityKind.provider && key == kind.sourceKey) {
          final rows = _restoreSyntheticIdentities(
            kind,
            value,
            routed.entities[kind]!,
          );
          routed = BusinessSnapshot(
            entities: <BusinessEntityKind, List<BusinessEntityValue>>{
              ...routed.entities,
              kind: rows,
            },
            preferences: routed.preferences,
          );
        }
        await _repository.synchronizeEntities(kind, routed.entities[kind]!);
        _applyRuntimeEntity(kind, routed);
      } else {
        _validatePreferenceKey(key);
        await _repository.setPreference(key, value);
        _values[key] = _copyForStorage(value);
      }
      return true;
    });
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    if (_writesBlockedForRestore) {
      return Future<T>.error(StateError('business_preferences_restore_fence'));
    }
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

  void _applyRuntimeSnapshot(BusinessSnapshot snapshot) {
    final runtime = BusinessSettingsRouter.exportRuntimeSnapshot(snapshot);
    _values = Map<String, Object>.from(runtime);
    _syntheticIdentities.clear();
    for (final kind in BusinessEntityKind.values) {
      _rememberSyntheticIdentities(kind, snapshot, runtime[kind.sourceKey]);
    }
  }

  void _applyRuntimeEntity(BusinessEntityKind kind, BusinessSnapshot routed) {
    final runtime = BusinessSettingsRouter.exportRuntimeSnapshot(routed);
    _values[kind.sourceKey] = runtime[kind.sourceKey]!;
    if (kind == BusinessEntityKind.provider) {
      _values[_providersOrderKey] = runtime[_providersOrderKey]!;
    }
    _rememberSyntheticIdentities(kind, routed, runtime[kind.sourceKey]);
  }

  List<BusinessEntityValue> _restoreSyntheticIdentities(
    BusinessEntityKind kind,
    Object value,
    List<BusinessEntityValue> rows,
  ) {
    final identities = _syntheticIdentities[kind];
    if (identities == null || identities.isEmpty || value is! String) {
      return rows;
    }
    final decoded = jsonDecode(value);
    if (decoded is! List || decoded.length != rows.length) return rows;
    return <BusinessEntityValue>[
      for (var index = 0; index < rows.length; index++)
        () {
          final item = decoded[index];
          if (item is! Map || !item.containsKey('id')) return rows[index];
          final identity = identities[_identityToken(item['id'])];
          if (identity == null) return rows[index];
          final payload = (jsonDecode(rows[index].payload) as Map).map(
            (key, fieldValue) => MapEntry(key.toString(), fieldValue),
          );
          if (identity.hadPayloadId) {
            payload['id'] = identity.payloadId;
          } else {
            payload.remove('id');
          }
          return rows[index].copyWith(
            id: identity.rowId,
            payload: jsonEncode(payload),
          );
        }(),
    ];
  }

  void _rememberSyntheticIdentities(
    BusinessEntityKind kind,
    BusinessSnapshot snapshot,
    Object? runtimeValue,
  ) {
    if (kind == BusinessEntityKind.provider || runtimeValue is! String) {
      _syntheticIdentities.remove(kind);
      return;
    }
    final rows = List<BusinessEntityValue>.of(snapshot.entities[kind]!)
      ..sort(_compareRows);
    final runtimeItems = jsonDecode(runtimeValue);
    if (runtimeItems is! List || runtimeItems.length != rows.length) {
      _syntheticIdentities.remove(kind);
      return;
    }
    final identities = <String, _SyntheticEntityIdentity>{};
    for (var index = 0; index < rows.length; index++) {
      final payload = (jsonDecode(rows[index].payload) as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final rawId = payload['id'];
      if (rawId != null && rawId.toString().trim().isNotEmpty) continue;
      final runtimeItem = runtimeItems[index];
      if (runtimeItem is! Map || !runtimeItem.containsKey('id')) continue;
      identities[_identityToken(runtimeItem['id'])] = (
        rowId: rows[index].id,
        hadPayloadId: payload.containsKey('id'),
        payloadId: rawId,
      );
    }
    if (identities.isEmpty) {
      _syntheticIdentities.remove(kind);
    } else {
      _syntheticIdentities[kind] = identities;
    }
  }

  static String _identityToken(Object? value) => jsonEncode(value);

  static int _compareRows(BusinessEntityValue left, BusinessEntityValue right) {
    final byOrder = left.sortOrder.compareTo(right.sortOrder);
    return byOrder != 0 ? byOrder : left.id.compareTo(right.id);
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
