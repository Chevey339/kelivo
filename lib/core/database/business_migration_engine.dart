import 'package:shared_preferences/shared_preferences.dart';

import 'business_data.dart';
import 'business_repository.dart';
import 'business_settings_router.dart';

abstract interface class LegacyBusinessPreferences {
  Future<Map<String, Object?>> snapshot();

  Future<void> remove(String key);
}

final class SharedPreferencesLegacyBusinessPreferences
    implements LegacyBusinessPreferences {
  SharedPreferencesLegacyBusinessPreferences(this._preferences);

  final SharedPreferences _preferences;

  static Future<SharedPreferencesLegacyBusinessPreferences> open() async =>
      SharedPreferencesLegacyBusinessPreferences(
        await SharedPreferences.getInstance(),
      );

  @override
  Future<Map<String, Object?>> snapshot() async => {
    for (final key in _preferences.getKeys()) key: _preferences.get(key),
  };

  @override
  Future<void> remove(String key) async {
    if (_preferences.containsKey(key) && !await _preferences.remove(key)) {
      throw StateError('business_migration_cleanup:$key');
    }
  }
}

enum BusinessMigrationResult {
  migrated,
  freshInstall,
  alreadyComplete,
  cleanedAfterReceipt,
}

final class BusinessMigrationEngine {
  BusinessMigrationEngine({
    required this.repository,
    required this.legacyPreferences,
  });

  final BusinessRepository repository;
  final LegacyBusinessPreferences legacyPreferences;

  Future<BusinessMigrationResult> run() async {
    final legacy = await legacyPreferences.snapshot();
    final cleanupKeys = _cleanupKeys(legacy.keys);
    if (await repository.hasMigrationReceipt()) {
      if (cleanupKeys.isEmpty) {
        return BusinessMigrationResult.alreadyComplete;
      }
      await _cleanup(cleanupKeys);
      return BusinessMigrationResult.cleanedAfterReceipt;
    }

    final hasBusinessData = cleanupKeys.isNotEmpty;
    final routed = BusinessSettingsRouter.normalizeAndRoute(
      legacy,
      preserveExplicitEmptyInstructionList: true,
    );
    await repository.replaceSnapshotForMigration(
      routed,
      validatePersisted: (stored) {
        _validateEntityCounts(routed, stored);
        final expected = BusinessSettingsRouter.exportSnapshot(routed);
        final actual = BusinessSettingsRouter.exportSnapshot(stored);
        if (!_deepEquals(expected, actual)) {
          throw StateError('business_migration_export_mismatch');
        }
      },
    );

    await _cleanup(cleanupKeys);
    return hasBusinessData
        ? BusinessMigrationResult.migrated
        : BusinessMigrationResult.freshInstall;
  }

  static Set<String> _cleanupKeys(Iterable<String> keys) => {
    for (final key in keys)
      if (BusinessKeyRegistry.classify(key) != BusinessKeyDisposition.localOnly)
        key,
  };

  Future<void> _cleanup(Set<String> keys) async {
    final ordered = keys.toList()..sort();
    for (final key in ordered) {
      await legacyPreferences.remove(key);
    }
  }

  static void _validateEntityCounts(
    BusinessSnapshot expected,
    BusinessSnapshot actual,
  ) {
    for (final kind in BusinessEntityKind.values) {
      if (expected.entityCount(kind) != actual.entityCount(kind)) {
        throw StateError('business_migration_count:${kind.sourceKey}');
      }
    }
  }
}

bool _deepEquals(Object? left, Object? right) {
  if (identical(left, right) || left == right) return true;
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_deepEquals(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return false;
}
