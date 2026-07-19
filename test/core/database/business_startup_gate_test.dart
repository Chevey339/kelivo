import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_migration_engine.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_startup_gate.dart';

void main() {
  late AppDatabase database;
  late BusinessRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = BusinessRepository(database);
    await database.customSelect('SELECT 1;').getSingle();
  });

  tearDown(() => database.close());

  test('migrates before returning a loaded business facade', () async {
    final legacy = _LegacyPreferences({
      'assistants_v1': jsonEncode([
        {'id': 'assistant-a', 'name': 'Assistant A'},
      ]),
      'theme_mode_v1': 'dark',
    });

    final preferences = await BusinessStartupGate.migrateAndLoad(
      repository: repository,
      legacyPreferences: legacy,
    );

    expect(preferences.isLoaded, isTrue);
    expect(preferences.getString('theme_mode_v1'), 'dark');
    expect(await repository.hasMigrationReceipt(), isTrue);
    expect(legacy.values, isEmpty);
  });

  test('invalid legacy data fails before exposing an empty facade', () async {
    final legacy = _LegacyPreferences({
      'assistants_v1': '{broken',
      'theme_mode_v1': 'dark',
    });

    await expectLater(
      BusinessStartupGate.migrateAndLoad(
        repository: repository,
        legacyPreferences: legacy,
      ),
      throwsA(isA<FormatException>()),
    );

    expect(await repository.hasMigrationReceipt(), isFalse);
    expect((await repository.preferenceSnapshot()), isEmpty);
    expect(legacy.values, containsPair('theme_mode_v1', 'dark'));

    legacy.values['assistants_v1'] = '[]';
    final preferences = await BusinessStartupGate.migrateAndLoad(
      repository: repository,
      legacyPreferences: legacy,
    );
    expect(preferences.getString('theme_mode_v1'), 'dark');
  });

  test('fresh installs return a loaded empty facade with a receipt', () async {
    final legacy = _LegacyPreferences({'flutter_log_enabled_v1': true});

    final preferences = await BusinessStartupGate.migrateAndLoad(
      repository: repository,
      legacyPreferences: legacy,
    );

    expect(preferences.isLoaded, isTrue);
    expect(preferences.getString('assistants_v1'), '[]');
    expect(preferences.getString('provider_configs_v1'), '{}');
    expect(preferences.getStringList('providers_order_v1'), isEmpty);
    expect(preferences.getKeys(), isNot(contains('theme_mode_v1')));
    expect(await repository.hasMigrationReceipt(), isTrue);
    expect(legacy.values, {'flutter_log_enabled_v1': true});
  });
}

final class _LegacyPreferences implements LegacyBusinessPreferences {
  _LegacyPreferences(Map<String, Object?> values)
    : values = Map<String, Object?>.from(values);

  final Map<String, Object?> values;

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<Map<String, Object?>> snapshot() async =>
      Map<String, Object?>.from(values);
}
