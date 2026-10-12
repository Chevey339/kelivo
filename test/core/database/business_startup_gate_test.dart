import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/database/business_migration_engine.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_startup_gate.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';

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

  for (final mismatch in ['count', 'export']) {
    test('migration $mismatch failure never exposes default settings', () async {
      final legacy = _LegacyPreferences({
        'assistants_v1': jsonEncode([
          {'id': 'assistant-a', 'name': 'Assistant A'},
        ]),
        'theme_mode_v1': 'dark',
      });

      final source = Map<String, Object?>.of(legacy.values);
      await database.customStatement(
        'CREATE TRIGGER break_migration AFTER INSERT ON assistant_rows '
        'WHEN NEW.id = \'assistant-a\' BEGIN '
        '${mismatch == 'count' ? 'DELETE FROM assistant_rows WHERE id = NEW.id;' : 'UPDATE assistant_rows SET payload = \'{}\' WHERE id = NEW.id;'} '
        'END;',
      );

      await expectLater(
        BusinessStartupGate.migrateAndLoad(
          repository: repository,
          legacyPreferences: legacy,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'migration failure',
            mismatch == 'count'
                ? 'business_migration_count:assistants_v1'
                : 'business_migration_export_mismatch',
          ),
        ),
      );
      expect(legacy.values, source);
      expect(await repository.hasMigrationReceipt(), isFalse);
      expect(
        await repository.readEntities(BusinessEntityKind.assistant),
        isEmpty,
      );

      await database.customStatement('DROP TRIGGER break_migration');
      final preferences = await BusinessStartupGate.migrateAndLoad(
        repository: repository,
        legacyPreferences: legacy,
      );
      final assistants = AssistantProvider(preferences: preferences);
      await assistants.loaded;
      expect(assistants.assistants.single.id, 'assistant-a');
      expect(legacy.values, isEmpty);
      assistants.dispose();
    });
  }

  test(
    'invalid persisted assistant blocks startup without deleting any ID',
    () async {
      final original = [
        BusinessEntityValue(
          id: 'assistant-a',
          sortOrder: 0,
          payload: jsonEncode({
            'id': 'assistant-a',
            'name': 'A',
            'useGradientBackground': 'true',
          }),
        ),
        BusinessEntityValue(
          id: 'assistant-b',
          sortOrder: 1,
          payload: jsonEncode({'id': 'assistant-b', 'name': 'B'}),
        ),
      ];
      await repository.replaceEntities(BusinessEntityKind.assistant, original);
      await repository.writeMigrationReceipt();
      await expectLater(
        BusinessStartupGate.migrateAndLoad(
          repository: repository,
          legacyPreferences: _LegacyPreferences({}),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'source',
            'assistants_v1',
          ),
        ),
      );
      final stored = await repository.readEntities(
        BusinessEntityKind.assistant,
      );
      expect(stored.map((row) => row.id), ['assistant-a', 'assistant-b']);
      expect(
        stored.map((row) => row.payload),
        original.map((row) => row.payload),
      );
      expect(await repository.hasMigrationReceipt(), isTrue);
    },
  );

  test(
    'workspace, skill, gradient and unknown fields preserve assistant IDs',
    () async {
      final source = {
        'id': 'original-id',
        'name': 'Existing assistant',
        'thinkingBudget': 8192,
        'defaultWorkspaceId': 'workspace-a',
        'defaultWorkspaceSetup': 'completed',
        'skillIds': ['skill-a'],
        'useGradientBackground': true,
        'gradientBackgroundAnimated': false,
        'gradientBackgroundPhase': 7.0,
        'gradientBackgroundOffsetX': 0.2,
        'gradientBackgroundOffsetY': -0.3,
        'futureField': {'kept': true},
      };
      final preferences = await BusinessStartupGate.migrateAndLoad(
        repository: repository,
        legacyPreferences: _LegacyPreferences({
          'assistants_v1': jsonEncode([source]),
        }),
      );
      final assistants = AssistantProvider(preferences: preferences);
      await assistants.loaded;
      expect(assistants.assistants.single.id, 'original-id');
      expect(assistants.assistants.single.useGradientBackground, isTrue);
      expect(assistants.assistants.single.skillIds, ['skill-a']);
      expect(jsonDecode(preferences.getString('assistants_v1')!), [source]);
      expect(await repository.hasMigrationReceipt(), isTrue);
      assistants.dispose();
    },
  );

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
