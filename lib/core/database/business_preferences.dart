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
  Future<void>? _mutationTail;
  bool _isLoaded = false;
  bool _writesBlockedForRestore = false;
  bool _closed = false;
  Future<void>? _closeFuture;

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
  Future<T> runWithRestoreWriteFence<T>(
    Future<T> Function() operation, {
    bool Function()? canResumeOnError,
  }) async {
    if (_writesBlockedForRestore) {
      throw StateError('business_preferences_restore_fence');
    }
    _writesBlockedForRestore = true;
    await _writeTail;
    try {
      return await operation();
    } catch (_) {
      // A receipt may already be durable when publication reports a late IO
      // error. Accept writes again only when the caller proves no cutover is due.
      if (canResumeOnError?.call() ?? true) _writesBlockedForRestore = false;
      rethrow;
    }
  }

  /// Awaits every write accepted so far. Desktop exit hooks flush through this
  /// so the serialized queue reaches SQLite before the process exits.
  Future<void> flushPendingWrites() async {
    await _mutationTail;
    await _writeTail;
  }

  /// Drain accepted mutations before closing the shared database. Late timers
  /// and callbacks may still run while the desktop engine is terminating.
  Future<void> close() => _closeFuture ??= Future<void>.microtask(() async {
    await _mutationTail;
    _closed = true;
    await _writeTail;
  });

  /// Shared by assistant-related stores and assistant duplication. Lock the
  /// whole read-modify-write operation, not just its final SQLite write.
  Future<T> runExclusiveMutation<T>(Future<T> Function() operation) async {
    if (_closeFuture != null) throw StateError('business_preferences_closed');
    final result = (_mutationTail ?? Future<void>.value()).then(
      (_) => operation(),
    );
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _mutationTail = tail;
    try {
      return await result;
    } finally {
      if (identical(_mutationTail, tail)) _mutationTail = null;
    }
  }

  Object? get(String key) => _copyForRead(_values[key]);

  bool containsKey(String key) => _values.containsKey(key);

  Set<String> getKeys() => Set<String>.unmodifiable(_values.keys);

  bool? getBool(String key) => _values[key] as bool?;

  int? getInt(String key) => _values[key] as int?;

  double? getDouble(String key) => (_values[key] as num?)?.toDouble();

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

  Future<bool> _setValue(String key, Object value) => setMany({key: value});

  /// Publishes the cache only after every write has committed successfully.
  Future<bool> setMany(Map<String, Object> values) async {
    final updates = values.map(
      (key, value) => MapEntry(key, _copyForStorage(value)),
    );
    await load();
    return _serialize(() async {
      final kinds = <BusinessEntityKind>{};
      final preferenceUpdates = <String, Object>{};
      for (final entry in updates.entries) {
        final kind = _entityKindForKey(entry.key);
        if (kind == null) {
          _validatePreferenceKey(entry.key);
          preferenceUpdates[entry.key] = entry.value;
        } else {
          kinds.add(kind);
        }
      }
      final next = {..._values, ...updates};
      final normalized = kinds.isEmpty
          ? null
          : BusinessSettingsRouter.normalizeAndRoute(next);
      final entities = <BusinessEntityKind, List<BusinessEntityValue>>{
        for (final kind in kinds)
          kind: kind == BusinessEntityKind.provider
              ? normalized!.entities[kind]!
              : _restoreSyntheticIdentities(
                  kind,
                  next[kind.sourceKey]!,
                  normalized!.entities[kind]!,
                ),
      };
      await _repository.writeBatch(
        entities: entities,
        preferences: preferenceUpdates,
      );
      if (normalized != null) {
        final routed = BusinessSnapshot(
          entities: {...normalized.entities, ...entities},
          preferences: normalized.preferences,
        );
        for (final kind in kinds) {
          _applyRuntimeEntity(kind, routed);
        }
      }
      _values.addAll(preferenceUpdates);
      return true;
    });
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    if (_closed) {
      return Future<T>.error(StateError('business_preferences_closed'));
    }
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
