import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/database/business_migration_engine.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_settings_router.dart';

void main() {
  late AppDatabase database;
  late BusinessRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = BusinessRepository(database);
    await database.customSelect('SELECT 1;').getSingle();
  });

  tearDown(() => database.close());

  test(
    'migrates, verifies and cleans only legacy business preferences',
    () async {
      final legacy = FakeLegacyBusinessPreferences({
        'assistants_v1': jsonEncode([
          {'id': 'assistant-a', 'name': 'A'},
        ]),
        'provider_configs_v1': jsonEncode({
          'provider-a': {'id': 'provider-a', 'apiKey': 'secret'},
        }),
        'providers_order_v1': <String>['provider-a'],
        'theme_mode_v1': 'dark',
        'plugin_future_key_v1': 42,
        'pinned_chat_ids': <String>['discard-me'],
        'flutter_log_enabled_v1': true,
        'display_chat_font_scale_v1': 1.2,
        'restore_internal_marker': 'keep',
      });

      final result = await BusinessMigrationEngine(
        repository: repository,
        legacyPreferences: legacy,
      ).run();

      expect(result, BusinessMigrationResult.migrated);
      expect(await repository.hasMigrationReceipt(), isTrue);
      final exported = BusinessSettingsRouter.exportSnapshot(
        await repository.readSnapshot(),
      );
      expect(exported['theme_mode_v1'], 'dark');
      expect(exported['plugin_future_key_v1'], 42);
      expect(jsonDecode(exported['provider_configs_v1']! as String), {
        'provider-a': {'id': 'provider-a', 'apiKey': 'secret'},
      });
      expect(legacy.values, {
        'flutter_log_enabled_v1': true,
        'display_chat_font_scale_v1': 1.2,
        'restore_internal_marker': 'keep',
      });
    },
  );

  test(
    'receipt makes a retry cleanup-only and never overwrites newer DB data',
    () async {
      final legacy = FakeLegacyBusinessPreferences({'theme_mode_v1': 'dark'});
      final engine = BusinessMigrationEngine(
        repository: repository,
        legacyPreferences: legacy,
      );
      await engine.run();
      await repository.setPreference('theme_mode_v1', 'light');
      legacy.values['theme_mode_v1'] = 'old-value-returned-after-crash';

      final result = await engine.run();

      expect(result, BusinessMigrationResult.cleanedAfterReceipt);
      expect(await repository.getPreference('theme_mode_v1'), 'light');
      expect(legacy.values, isEmpty);
    },
  );

  test(
    'cleanup interruption is retryable without repeating migration',
    () async {
      final legacy = FakeLegacyBusinessPreferences({
        'theme_mode_v1': 'dark',
        'app_locale_v1': 'zh-CN',
      })..failRemovalAfter = 1;
      final engine = BusinessMigrationEngine(
        repository: repository,
        legacyPreferences: legacy,
      );

      await expectLater(engine.run(), throwsA(isA<StateError>()));
      expect(await repository.hasMigrationReceipt(), isTrue);
      await repository.setPreference('theme_mode_v1', 'light');

      legacy.failRemovalAfter = null;
      expect(await engine.run(), BusinessMigrationResult.cleanedAfterReceipt);
      expect(await repository.getPreference('theme_mode_v1'), 'light');
      expect(legacy.values, isEmpty);
    },
  );

  test('invalid source fails closed before writing or cleanup', () async {
    final legacy = FakeLegacyBusinessPreferences({
      'assistants_v1': jsonEncode({'not': 'a list'}),
      'theme_mode_v1': 'dark',
    });

    await expectLater(
      BusinessMigrationEngine(
        repository: repository,
        legacyPreferences: legacy,
      ).run(),
      throwsA(isA<FormatException>()),
    );

    expect(await repository.hasMigrationReceipt(), isFalse);
    expect(legacy.values, containsPair('theme_mode_v1', 'dark'));
    expect((await repository.readSnapshot()).preferences, isEmpty);
  });

  test('domain-invalid entity fields fail closed before cleanup', () async {
    final legacy = FakeLegacyBusinessPreferences({
      'assistants_v1': jsonEncode([
        {'id': 'assistant-a', 'temperature': 'hot'},
      ]),
      'theme_mode_v1': 'dark',
    });

    await expectLater(
      BusinessMigrationEngine(
        repository: repository,
        legacyPreferences: legacy,
      ).run(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'source key',
          'assistants_v1',
        ),
      ),
    );

    expect(await repository.hasMigrationReceipt(), isFalse);
    expect(legacy.values, containsPair('theme_mode_v1', 'dark'));
    expect(legacy.values, contains('assistants_v1'));
    final stored = await repository.readSnapshot();
    expect(stored.preferences, isEmpty);
    expect(stored.entities.values.every((rows) => rows.isEmpty), isTrue);
  });

  test(
    'fresh install records a receipt without seeding provider data',
    () async {
      final legacy = FakeLegacyBusinessPreferences({
        'flutter_log_enabled_v1': false,
      });

      final result = await BusinessMigrationEngine(
        repository: repository,
        legacyPreferences: legacy,
      ).run();

      expect(result, BusinessMigrationResult.freshInstall);
      expect(await repository.hasMigrationReceipt(), isTrue);
      final snapshot = await repository.readSnapshot();
      expect(snapshot.preferences, isEmpty);
      expect(snapshot.entities.values.every((rows) => rows.isEmpty), isTrue);
      expect(legacy.values, {'flutter_log_enabled_v1': false});
    },
  );

  test('routes a complete registered business snapshot without loss', () async {
    final source = <String, Object?>{
      for (final key in BusinessKeyRegistry.preferenceKeys) key: 'value:$key',
      for (final kind in BusinessEntityKind.values)
        kind.sourceKey: kind == BusinessEntityKind.provider
            ? jsonEncode({
                'provider-a': {'id': 'provider-a', 'apiKey': 'secret-a'},
                'provider-b': {'id': 'provider-b', 'apiKey': 'secret-b'},
              })
            : jsonEncode([
                {
                  'id': kind == BusinessEntityKind.assistantMemory
                      ? 1
                      : '${kind.name}-a',
                  if (kind == BusinessEntityKind.assistantMemory)
                    'assistantId': 'assistant-a',
                  if (kind == BusinessEntityKind.searchService)
                    'type': 'bing_local',
                  if (kind == BusinessEntityKind.ttsService) 'kind': 'openai',
                  'opaque': kind.name,
                },
              ]),
      'providers_order_v1': <String>['provider-b', 'provider-a'],
      'pinned_models_v1': <String>['provider-a::model-a'],
      'instruction_injections_active_ids_by_assistant_v1': jsonEncode({
        'assistant-a': <String>['injection-a'],
      }),
      'search_enabled_v1': true,
      'future_string_list_v1': <String>['future-a', 'future-b'],
      'pinned_chat_ids': <String>['discarded'],
      'flutter_log_enabled_v1': true,
    };
    final expected = BusinessSettingsRouter.exportSnapshot(
      BusinessSettingsRouter.normalizeAndRoute(source),
    );
    final legacy = FakeLegacyBusinessPreferences(source);

    await BusinessMigrationEngine(
      repository: repository,
      legacyPreferences: legacy,
    ).run();

    final actual = BusinessSettingsRouter.exportSnapshot(
      await repository.readSnapshot(),
    );
    expect(actual, expected);
    expect(legacy.values, <String, Object?>{'flutter_log_enabled_v1': true});
  });
}

final class FakeLegacyBusinessPreferences implements LegacyBusinessPreferences {
  FakeLegacyBusinessPreferences(Map<String, Object?> initial)
    : values = Map<String, Object?>.from(initial);

  final Map<String, Object?> values;
  int? failRemovalAfter;
  int _removalCount = 0;

  @override
  Future<Map<String, Object?>> snapshot() async =>
      Map<String, Object?>.from(values);

  @override
  Future<void> remove(String key) async {
    final failureThreshold = failRemovalAfter;
    if (failureThreshold != null && _removalCount >= failureThreshold) {
      throw StateError('injected_cleanup_failure');
    }
    _removalCount++;
    values.remove(key);
  }
}
