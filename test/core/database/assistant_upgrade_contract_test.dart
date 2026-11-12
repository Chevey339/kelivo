import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show GeneratedDatabase, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/database/business_migration_engine.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_startup_gate.dart';
import 'package:Kelivo/core/database/schema_migrations.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';

import 'generated_schema/schema.dart';

// These payloads were emitted by historical Assistant.toJson implementations,
// including their historical child models, not by the current serializer.
// Provenance and source hashes live beside each payload in the fixture. To add
// new published writers: python3 tool/generate_assistant_upgrade_fixtures.py.
// Normal test runs intentionally do not require git history or invoke Flutter.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final fixtures =
      (jsonDecode(
                File(
                  'test/fixtures/assistants/historical_writers.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();

  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('assistant-upgrade-');
    file = File('${directory.path}/kelivo.db');
  });
  tearDown(() => directory.delete(recursive: true));

  Future<void> seedHistory(GeneratedDatabase database) async {
    await database.customStatement(
      'INSERT INTO conversation_rows '
      '(id, title, created_at, updated_at, assistant_id) '
      "VALUES ('old-topic', 'Existing topic', 1, 2, 'old-configured')",
    );
    await database.customStatement(
      'INSERT INTO message_rows '
      '(id, conversation_id, role, timestamp, message_order) '
      "VALUES ('old-message', 'old-topic', 'user', 3, 0)",
    );
    await database.customStatement(
      'INSERT INTO message_part_rows '
      '(conversation_id, revision_id, ordinal, kind, payload, created_at, updated_at) '
      "VALUES ('old-topic', 'old-message', 0, 'text', ?, 3, 3)",
      [
        jsonEncode({'text': 'preserved history'}),
      ],
    );
  }

  Future<void> expectHistoryRetained(AppDatabase database) async {
    final conversation = await database
        .customSelect('SELECT id, assistant_id FROM conversation_rows')
        .getSingle();
    expect(conversation.read<String>('id'), 'old-topic');
    expect(conversation.read<String>('assistant_id'), 'old-configured');
    final message = await database
        .customSelect('SELECT id FROM message_rows')
        .getSingle();
    expect(message.read<String>('id'), 'old-message');
    final part = await database
        .customSelect('SELECT payload FROM message_part_rows')
        .getSingle();
    expect(jsonDecode(part.read<String>('payload')), {
      'text': 'preserved history',
    });
  }

  Future<void> exerciseUpgrade(
    List<dynamic> assistants,
    _LegacyPreferences legacy,
  ) async {
    final database = AppDatabase(NativeDatabase(file));
    final repository = BusinessRepository(database);
    AssistantProvider? provider;
    late String addedId;
    try {
      final preferences = await BusinessStartupGate.migrateAndLoad(
        repository: repository,
        legacyPreferences: legacy,
      );
      provider = AssistantProvider(preferences: preferences);
      await provider.loaded;
      // A readable installed assistant list must never reach the default UUID
      // generator (which would also require a localized BuildContext).
      await provider.ensureDefaults(null);
      expect(provider.assistants.map((assistant) => assistant.id), [
        'old-default',
        'old-configured',
      ]);
      expect(provider.currentAssistantId, 'old-configured');
      expect(provider.currentAssistant!.chatModelId, 'model-a');
      expect(provider.currentAssistant!.systemPrompt, '测试系统提示词');
      final rows = await repository.readEntities(BusinessEntityKind.assistant);
      expect(rows.map((row) => jsonDecode(row.payload)), assistants);
      await expectHistoryRetained(database);

      // Reproduce the reported follow-up actions: select a model, add another
      // assistant, return to the original one, and then cold-start again.
      await provider.updateAssistant(
        provider.currentAssistant!.copyWith(
          chatModelId: 'selected-after-upgrade',
        ),
      );
      addedId = await provider.addAssistant(name: 'New assistant');
      await provider.setCurrentAssistant(addedId);
      await provider.setCurrentAssistant('old-configured');
    } finally {
      provider?.dispose();
      await database.close();
    }

    final reopened = AppDatabase(NativeDatabase(file));
    AssistantProvider? reloaded;
    try {
      final preferences = await BusinessStartupGate.migrateAndLoad(
        repository: BusinessRepository(reopened),
        legacyPreferences: _LegacyPreferences({}),
      );
      reloaded = AssistantProvider(preferences: preferences);
      await reloaded.loaded;
      await reloaded.ensureDefaults(null);
      expect(reloaded.assistants.map((assistant) => assistant.id), [
        'old-default',
        'old-configured',
        addedId,
      ]);
      expect(reloaded.currentAssistantId, 'old-configured');
      expect(reloaded.currentAssistant!.chatModelId, 'selected-after-upgrade');
      await expectHistoryRetained(reopened);
    } finally {
      reloaded?.dispose();
      await reopened.close();
    }
  }

  for (final fixture in fixtures) {
    final writer = (fixture['writers'] as List).first as Map;
    final refs = writer['refs'] as List;
    final firstRef = refs.first as String;
    final label = firstRef.startsWith('v')
        ? firstRef
        : firstRef.substring(0, 8);
    final assistants = fixture['assistants'] as List;

    test('$label preferences migrate with original assistant IDs', () async {
      final database = AppDatabase(NativeDatabase(file));
      try {
        await seedHistory(database);
      } finally {
        await database.close();
      }
      final legacy = _LegacyPreferences({
        'assistants_v1': jsonEncode(assistants),
        'current_assistant_id_v1': 'old-configured',
      });
      await exerciseUpgrade(assistants, legacy);
      expect(legacy.values, isEmpty);
    });

    for (final schema in AppDatabase.publishedSchemaVersions) {
      test('$label schema $schema keeps IDs after upgrade and edits', () async {
        // Use the actually published table definitions. Merely changing
        // PRAGMA user_version on a current database would bypass the upgrade.
        final old = GeneratedHelper().databaseForVersion(
          NativeDatabase(file),
          schema,
        );
        try {
          await old.customStatement('PRAGMA user_version = $schema');
          for (var i = 0; i < assistants.length; i++) {
            await old.customStatement(
              'INSERT INTO assistant_rows (id, sort_order, payload, updated_at) '
              'VALUES (?, ?, ?, 1)',
              [(assistants[i] as Map)['id'], i, jsonEncode(assistants[i])],
            );
          }
          await old.customStatement(
            'INSERT INTO chat_storage_meta_rows (key, value) VALUES (?, ?)',
            [BusinessRepository.migrationReceiptKey, 'true'],
          );
          await old.customStatement(
            'INSERT INTO preference_rows (key, value, updated_at) VALUES (?, ?, 1)',
            ['current_assistant_id_v1', jsonEncode('old-configured')],
          );
          await seedHistory(old);
        } finally {
          await old.close();
        }
        await SchemaMigrations.upgradeFileInPlace(file);
        await exerciseUpgrade(assistants, _LegacyPreferences({}));
      });
    }
  }
}

final class _LegacyPreferences implements LegacyBusinessPreferences {
  _LegacyPreferences(this.values);
  final Map<String, Object?> values;

  @override
  Future<Map<String, Object?>> snapshot() async => Map.of(values);

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}
