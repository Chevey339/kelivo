import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'restore_settings_transition.dart';

/// Reload-verified access to the legacy SharedPreferences backend.
///
/// SharedPreferences is not a cross-platform filesystem transaction. The
/// startup gate keeps business code closed and this adapter makes each
/// touched key idempotently recoverable across process restarts.
final class RestoreSettingsStore {
  const RestoreSettingsStore(this._preferences);

  static Future<void> _operationTail = Future<void>.value();

  final SharedPreferences _preferences;

  Future<Map<String, dynamic>> readAll() => _serialized(_readAllUnlocked);

  Future<Map<String, dynamic>> _readAllUnlocked() async {
    await _preferences.reload();
    final values = <String, dynamic>{};
    for (final key in (_preferences.getKeys().toList()..sort())) {
      values[key] = _copyPreferenceValue(_preferences.get(key));
    }
    return Map.unmodifiable(values);
  }

  Future<RestoreSettingsTransition> buildTransition({
    required Map<String, dynamic> candidateSettings,
    required bool secretsIncluded,
  }) {
    return _serialized(
      () async => RestoreSettingsTransition.build(
        currentSettings: await _readAllUnlocked(),
        candidateSettings: candidateSettings,
        secretsIncluded: secretsIncluded,
      ),
    );
  }

  Future<void> apply(RestoreSettingsTransition transition) =>
      _serialized(() => _applyUnlocked(transition));

  Future<void> _applyUnlocked(RestoreSettingsTransition transition) async {
    final beforeValues = transition.plan.validateSnapshotBytes(
      transition.snapshotBytes,
    );
    await _preferences.reload();
    final current = _readProjection(transition.plan.touchedKeys);
    _requireRecoverableProjection(
      current: current,
      before: beforeValues,
      target: transition.valuesToSet,
      touchedKeys: transition.plan.touchedKeys,
    );

    for (final key in (transition.keysToRemove.toList()..sort())) {
      if (_preferences.containsKey(key) && !await _preferences.remove(key)) {
        throw StateError('restore_settings_remove:$key');
      }
    }
    for (final key in (transition.valuesToSet.keys.toList()..sort())) {
      await _writeValue(key, transition.valuesToSet[key]);
    }
    await _preferences.reload();
    transition.plan.validateTargetProjection(
      _readProjection(transition.plan.touchedKeys),
    );
  }

  Future<void> rollback(RestoreSettingsTransition transition) =>
      _serialized(() => _rollbackUnlocked(transition));

  Future<void> _rollbackUnlocked(RestoreSettingsTransition transition) async {
    final beforeValues = transition.plan.validateSnapshotBytes(
      transition.snapshotBytes,
    );
    await _preferences.reload();
    final current = _readProjection(transition.plan.touchedKeys);
    _requireRecoverableProjection(
      current: current,
      before: beforeValues,
      target: transition.valuesToSet,
      touchedKeys: transition.plan.touchedKeys,
    );

    for (final key in (transition.plan.touchedKeys.toList()..sort())) {
      if (beforeValues.containsKey(key)) {
        await _writeValue(key, beforeValues[key]);
      } else if (_preferences.containsKey(key) &&
          !await _preferences.remove(key)) {
        throw StateError('restore_settings_remove:$key');
      }
    }
    await _preferences.reload();
    transition.plan.validateBeforeProjection(
      _readProjection(transition.plan.touchedKeys),
    );
  }

  Map<String, dynamic> _readProjection(Set<String> touchedKeys) {
    final values = <String, dynamic>{};
    for (final key in (touchedKeys.toList()..sort())) {
      if (_preferences.containsKey(key)) {
        values[key] = _copyPreferenceValue(_preferences.get(key));
      }
    }
    return values;
  }

  Future<void> _writeValue(String key, dynamic value) async {
    final bool written;
    if (value is bool) {
      written = await _preferences.setBool(key, value);
    } else if (value is int) {
      written = await _preferences.setInt(key, value);
    } else if (value is double) {
      written = await _preferences.setDouble(key, value);
    } else if (value is String) {
      written = await _preferences.setString(key, value);
    } else if (value is List<String>) {
      written = await _preferences.setStringList(key, value);
    } else {
      throw FormatException('restore_settings_value:$key');
    }
    if (!written) throw StateError('restore_settings_write:$key');
  }

  static Future<T> _serialized<T>(Future<T> Function() action) async {
    final previous = _operationTail;
    final release = Completer<void>();
    _operationTail = release.future;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }
}

void _requireRecoverableProjection({
  required Map<String, dynamic> current,
  required Map<String, dynamic> before,
  required Map<String, dynamic> target,
  required Set<String> touchedKeys,
}) {
  for (final key in touchedKeys) {
    if (!_entryMatches(current, before, key) &&
        !_entryMatches(current, target, key)) {
      throw StateError('restore_settings_projection:$key');
    }
  }
}

bool _entryMatches(
  Map<String, dynamic> left,
  Map<String, dynamic> right,
  String key,
) {
  if (left.containsKey(key) != right.containsKey(key)) return false;
  if (!left.containsKey(key)) return true;
  return _preferenceValuesEqual(left[key], right[key]);
}

bool _preferenceValuesEqual(dynamic left, dynamic right) {
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
  return left.runtimeType == right.runtimeType && left == right;
}

dynamic _copyPreferenceValue(dynamic value) {
  if (value is List) return List<String>.of(value.cast<String>());
  return value;
}
