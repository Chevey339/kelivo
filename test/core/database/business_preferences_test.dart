import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/services/memory_store.dart';

void main() {
  late AppDatabase database;
  late BusinessRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = BusinessRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'loads published settings shapes with SharedPreferences-style types',
    () async {
      await repository.replaceSnapshot(
        BusinessSettingsRouter.normalizeAndRoute({
          'provider_configs_v1': jsonEncode({
            'second': {'name': 'Second', 'apiKey': 'secret-2'},
            'first': {'name': 'First', 'apiKey': 'secret-1'},
          }),
          'providers_order_v1': <String>['first', 'second'],
          'theme_mode_v1': 'dark',
          'use_dynamic_color_v1': false,
          'thinking_budget_v1': 4096,
          'tts_speech_rate_v1': 0.75,
          'pinned_models_v1': <String>['first::model-a'],
        }),
      );

      final preferences = BusinessPreferences(repository);
      await preferences.load();

      expect(preferences.getString('theme_mode_v1'), 'dark');
      expect(preferences.getBool('use_dynamic_color_v1'), isFalse);
      expect(preferences.getInt('thinking_budget_v1'), 4096);
      expect(preferences.getDouble('tts_speech_rate_v1'), 0.75);
      expect(preferences.getStringList('pinned_models_v1'), <String>[
        'first::model-a',
      ]);
      expect(preferences.getStringList('providers_order_v1'), <String>[
        'first',
        'second',
      ]);
      expect(
        (jsonDecode(preferences.getString('provider_configs_v1')!) as Map).keys,
        <String>['first', 'second'],
      );
    },
  );

  test(
    'persists preference writes and removals across a cold reload',
    () async {
      final preferences = BusinessPreferences(repository);
      await preferences.load();

      await preferences.setBool('search_enabled_v1', true);
      await preferences.setInt('search_selected_v1', 2);
      await preferences.setDouble('tts_speech_rate_v1', 1.25);
      await preferences.setString('theme_palette_v1', 'sunset');
      await preferences.setStringList('pinned_models_v1', <String>[
        'OpenAI::gpt-test',
      ]);
      await preferences.remove('search_selected_v1');

      final reloaded = BusinessPreferences(repository);
      await reloaded.load();

      expect(reloaded.getBool('search_enabled_v1'), isTrue);
      expect(reloaded.getInt('search_selected_v1'), isNull);
      expect(reloaded.getDouble('tts_speech_rate_v1'), 1.25);
      expect(reloaded.getString('theme_palette_v1'), 'sunset');
      expect(reloaded.getStringList('pinned_models_v1'), <String>[
        'OpenAI::gpt-test',
      ]);
    },
  );

  test(
    'synchronizes entity values and provider order across a cold reload',
    () async {
      final preferences = BusinessPreferences(repository);
      await preferences.load();

      await preferences.setString(
        'provider_configs_v1',
        jsonEncode({
          'late': {'name': 'Late', 'apiKey': 'late-secret'},
          'first': {'name': 'First', 'apiKey': 'first-secret'},
          'new': {'name': 'New', 'apiKey': 'new-secret'},
        }),
      );
      await preferences.setStringList('providers_order_v1', <String>[
        'new',
        'first',
      ]);
      await preferences.setString(
        'search_services_v1',
        jsonEncode([
          {'id': 'search-2', 'type': 'bing_local', 'name': 'Second'},
          {'id': 'search-1', 'type': 'bing_local', 'name': 'First'},
        ]),
      );

      final reloaded = BusinessPreferences(repository);
      await reloaded.load();

      expect(reloaded.getStringList('providers_order_v1'), <String>[
        'new',
        'first',
        'late',
      ]);
      final providers =
          jsonDecode(reloaded.getString('provider_configs_v1')!) as Map;
      expect(providers.keys, <String>['new', 'first', 'late']);
      expect((providers['new'] as Map)['apiKey'], 'new-secret');
      expect(jsonDecode(reloaded.getString('search_services_v1')!), <Object?>[
        {'id': 'search-2', 'type': 'bing_local', 'name': 'Second'},
        {'id': 'search-1', 'type': 'bing_local', 'name': 'First'},
      ]);
    },
  );

  test('runtime ids preserve row identity without entering payloads', () async {
    await repository.replaceSnapshot(
      BusinessSettingsRouter.normalizeAndRoute({
        'quick_phrases_v1': jsonEncode([
          {'title': 'First', 'content': 'one'},
          {'title': 'Second', 'content': 'two'},
        ]),
      }),
    );
    final originalRows = await repository.readEntities(
      BusinessEntityKind.quickPhrase,
    );
    final originalIdByContent = {
      for (final row in originalRows)
        (jsonDecode(row.payload) as Map)['content']: row.id,
    };
    final preferences = BusinessPreferences(repository);
    await preferences.load();
    final runtime =
        (jsonDecode(preferences.getString('quick_phrases_v1')!) as List)
            .cast<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList();
    expect(runtime.map((item) => item['id']), everyElement(isA<String>()));

    runtime[1]['content'] = 'two updated';
    await preferences.setString(
      'quick_phrases_v1',
      jsonEncode([
        runtime[1],
        runtime[0],
        {'id': 'new-phrase', 'title': 'New', 'content': 'three'},
      ]),
    );

    final persisted = await repository.readEntities(
      BusinessEntityKind.quickPhrase,
    );
    expect(persisted.map((row) => row.id), [
      originalIdByContent['two'],
      originalIdByContent['one'],
      'new-phrase',
    ]);
    final payloads = persisted
        .map((row) => jsonDecode(row.payload) as Map<String, dynamic>)
        .toList();
    expect(payloads[0], isNot(contains('id')));
    expect(payloads[1], isNot(contains('id')));
    expect(payloads[2]['id'], 'new-phrase');

    final reloaded = BusinessPreferences(repository);
    await reloaded.load();
    final reloadedItems =
        jsonDecode(reloaded.getString('quick_phrases_v1')!) as List<dynamic>;
    expect(reloadedItems[0]['id'], originalIdByContent['two']);
    expect(reloadedItems[1]['id'], originalIdByContent['one']);
  });

  test(
    'id-less memories keep unique CRUD identities without payload ids',
    () async {
      await repository.replaceSnapshot(
        BusinessSettingsRouter.normalizeAndRoute({
          'assistant_memories_v1': jsonEncode([
            {'assistantId': 'assistant-1', 'content': 'first'},
            {'assistantId': 'assistant-1', 'content': 'second'},
          ]),
        }),
      );
      final originalFirstRowId = (await repository.readEntities(
        BusinessEntityKind.assistantMemory,
      )).first.id;
      final preferences = BusinessPreferences(repository);
      final store = MemoryStore(preferences);
      final initial = await store.getAll();
      expect(initial.map((memory) => memory.id), everyElement(lessThan(0)));
      expect(initial.map((memory) => memory.id).toSet(), hasLength(2));

      expect(
        await store.update(id: initial.first.id, content: 'first updated'),
        isNotNull,
      );
      expect(await store.delete(id: initial.last.id), isTrue);
      final added = await store.add(
        assistantId: 'assistant-1',
        content: 'third',
      );
      expect(added.id, greaterThan(0));

      final persisted = await repository.readEntities(
        BusinessEntityKind.assistantMemory,
      );
      expect(persisted, hasLength(2));
      expect(persisted.first.id, originalFirstRowId);
      final payloads = persisted
          .map((row) => jsonDecode(row.payload) as Map<String, dynamic>)
          .toList();
      expect(payloads.first, {
        'assistantId': 'assistant-1',
        'content': 'first updated',
      });
      expect(payloads.last['id'], added.id);
      expect(payloads.last['content'], 'third');
    },
  );
}
