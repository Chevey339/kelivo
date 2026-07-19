import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/models/assistant_memory.dart';

Map<String, Object?> _completeEntityRowIds({
  String? sourceKey,
  List<String> rowIds = const <String>[],
}) {
  final result = <String, Object?>{
    for (final kind in BusinessEntityKind.values)
      if (kind != BusinessEntityKind.provider) kind.sourceKey: const <String>[],
  };
  if (sourceKey != null) result[sourceKey] = rowIds;
  return result;
}

void main() {
  group('BusinessSettingsRouter', () {
    test(
      'registry distinguishes entity, preference, local and discarded keys',
      () {
        expect(
          BusinessKeyRegistry.classify('assistants_v1'),
          BusinessKeyDisposition.entity,
        );
        expect(
          BusinessKeyRegistry.classify('theme_mode_v1'),
          BusinessKeyDisposition.preference,
        );
        expect(
          BusinessKeyRegistry.classify('providers_order_v1'),
          BusinessKeyDisposition.providerOrder,
        );
        expect(
          BusinessKeyRegistry.classify('mobile_assistant_edit_tab_order_v1'),
          BusinessKeyDisposition.preference,
        );
        expect(
          BusinessKeyRegistry.classify('flutter_log_enabled_v1'),
          BusinessKeyDisposition.localOnly,
        );
        expect(
          BusinessKeyRegistry.classify('pinned_chat_ids'),
          BusinessKeyDisposition.discarded,
        );
        expect(
          BusinessKeyRegistry.classify('plugin_future_key_v1'),
          BusinessKeyDisposition.unknownPreference,
        );
      },
    );

    test(
      'routes and exports canonical settings without losing credentials',
      () {
        final source = <String, Object?>{
          'assistants_v1': jsonEncode([
            {'id': 'assistant-2', 'name': 'Second', 'searchEnabled': false},
            {'id': 'assistant-1', 'name': 'First', 'searchEnabled': true},
          ]),
          'provider_configs_v1': jsonEncode({
            'late': {'id': 'late', 'apiKey': 'late-secret'},
            'first': {
              'id': 'first',
              'apiKey': 'first-secret',
              'proxyPassword': 'proxy-secret',
            },
          }),
          // The order-only entry is retained; the configured provider omitted
          // from the order is appended using the source map's insertion order.
          'providers_order_v1': <String>['first', 'orphan'],
          'theme_mode_v1': 'dark',
          'use_dynamic_color_v1': false,
          'thinking_budget_v1': 4096,
          'tts_speech_rate_v1': 0.75,
          'pinned_models_v1': jsonEncode(['first/model-a']),
          'plugin_future_key_v1': <String>['one', 'two'],
          'flutter_log_enabled_v1': true,
          'pinned_chat_ids': <String>['chat-1'],
        };

        final snapshot = BusinessSettingsRouter.normalizeAndRoute(source);
        final exported = BusinessSettingsRouter.exportSnapshot(snapshot);

        expect(exported['providers_order_v1'], <String>[
          'first',
          'orphan',
          'late',
        ]);
        expect(
          (jsonDecode(exported['provider_configs_v1']! as String) as Map).keys,
          <String>['first', 'late'],
        );
        expect(exported['pinned_models_v1'], <String>['first/model-a']);
        expect(exported['plugin_future_key_v1'], <String>['one', 'two']);
        expect(exported['flutter_log_enabled_v1'], isNull);
        expect(exported['pinned_chat_ids'], isNull);

        final providers = snapshot.entities[BusinessEntityKind.provider]!;
        expect(providers.map((row) => row.id), <String>[
          'first',
          'orphan',
          'late',
        ]);
        expect(jsonDecode(providers.first.payload)['apiKey'], 'first-secret');
        expect(
          jsonDecode(providers.first.payload)['proxyPassword'],
          'proxy-secret',
        );
      },
    );

    test('preserves provider order when configs were never persisted', () {
      final snapshot = BusinessSettingsRouter.normalizeAndRoute({
        'providers_order_v1': <String>['Gemini', 'OpenAI'],
      });

      final exported = BusinessSettingsRouter.exportSnapshot(snapshot);

      expect(exported['providers_order_v1'], <String>['Gemini', 'OpenAI']);
      expect(jsonDecode(exported['provider_configs_v1']! as String), isEmpty);
    });

    test('round-trips order-only entries beside persisted configs', () {
      final first = BusinessSettingsRouter.exportSnapshot(
        BusinessSettingsRouter.normalizeAndRoute({
          'provider_configs_v1': jsonEncode({
            'OpenAI': {'apiKey': 'secret'},
          }),
          'providers_order_v1': <String>['Gemini', 'OpenAI'],
        }),
      );

      final second = BusinessSettingsRouter.exportSnapshot(
        BusinessSettingsRouter.normalizeAndRoute(first),
      );

      expect(first['providers_order_v1'], <String>['Gemini', 'OpenAI']);
      expect(second['providers_order_v1'], <String>['Gemini', 'OpenAI']);
      expect(jsonDecode(second['provider_configs_v1']! as String), {
        'OpenAI': {'apiKey': 'secret'},
      });
    });

    test('generates deterministic row ids without mutating payloads', () {
      final source = <String, Object?>{
        'quick_phrases_v1': jsonEncode([
          {'content': 'hello'},
          {'content': 'hello'},
        ]),
      };

      final first = BusinessSettingsRouter.normalizeAndRoute(source);
      final second = BusinessSettingsRouter.normalizeAndRoute(source);
      final firstRows = first.entities[BusinessEntityKind.quickPhrase]!;
      final secondRows = second.entities[BusinessEntityKind.quickPhrase]!;

      expect(firstRows.map((row) => row.id), secondRows.map((row) => row.id));
      expect(firstRows[0].id, isNot(firstRows[1].id));
      expect(jsonDecode(firstRows.first.payload), {'content': 'hello'});
      expect(
        jsonDecode(firstRows.first.payload) as Map<String, dynamic>,
        isNot(contains('id')),
      );

      final published = BusinessSettingsRouter.exportSnapshot(first);
      expect(jsonDecode(published['quick_phrases_v1']! as String), <Object?>[
        {'content': 'hello'},
        {'content': 'hello'},
      ]);
      final runtime = BusinessSettingsRouter.exportRuntimeSnapshot(first);
      final runtimeRows =
          jsonDecode(runtime['quick_phrases_v1']! as String) as List<dynamic>;
      expect(runtimeRows[0], {'content': 'hello', 'id': firstRows[0].id});
      expect(runtimeRows[1], {'content': 'hello', 'id': firstRows[1].id});
    });

    test(
      'portable row identities survive id-less tag edits and reordering',
      () {
        final seeded = BusinessSettingsRouter.normalizeAndRoute({
          'assistant_tags_v1': jsonEncode([
            {'name': 'First'},
            {'name': 'Second'},
          ]),
        });
        final seededRows = seeded.entities[BusinessEntityKind.assistantTag]!;
        final firstId = seededRows[0].id;
        final secondId = seededRows[1].id;
        final edited = BusinessSnapshot(
          entities: {
            ...seeded.entities,
            BusinessEntityKind.assistantTag: [
              seededRows[1].copyWith(
                sortOrder: 0,
                payload: jsonEncode({'name': 'Second renamed'}),
              ),
              seededRows[0].copyWith(sortOrder: 1),
            ],
          },
          preferences: {
            ...seeded.preferences,
            'assistant_tag_map_v1': jsonEncode({'assistant-1': firstId}),
          },
        );

        final portable = BusinessSettingsRouter.exportSnapshotWithRowIds(
          edited,
        );
        final publishedTags =
            jsonDecode(portable.settings['assistant_tags_v1']! as String)
                as List<dynamic>;

        expect(publishedTags, [
          {'name': 'Second renamed'},
          {'name': 'First'},
        ]);
        expect(
          publishedTags.cast<Map<String, dynamic>>(),
          everyElement(isNot(contains('id'))),
        );
        expect(portable.entityRowIds['assistant_tags_v1'], [secondId, firstId]);

        final restored = BusinessSettingsRouter.normalizeAndRoute(
          portable.settings,
          entityRowIds: portable.entityRowIds,
        );
        final restoredIds = restored.entities[BusinessEntityKind.assistantTag]!
            .map((row) => row.id)
            .toList();
        final restoredTagMap =
            jsonDecode(restored.preferences['assistant_tag_map_v1']! as String)
                as Map<String, dynamic>;

        expect(restoredIds, [secondId, firstId]);
        expect(restoredTagMap['assistant-1'], firstId);
        expect(restoredIds, contains(restoredTagMap['assistant-1']));
      },
    );

    test('rejects unknown portable row identity keys', () {
      final entityRowIds = _completeEntityRowIds()
        ..['unknown_entities_v1'] = const <String>[];
      expect(
        () => BusinessSettingsRouter.normalizeAndRoute({
          'assistant_tags_v1': jsonEncode(const <Object>[]),
        }, entityRowIds: entityRowIds),
        throwsFormatException,
      );
    });

    test('rejects incomplete portable row identity maps', () {
      final portable = BusinessSettingsRouter.exportSnapshotWithRowIds(
        BusinessSettingsRouter.normalizeAndRoute(const {}),
      );
      final incomplete = Map<String, Object?>.from(portable.entityRowIds)
        ..remove('assistant_tags_v1');

      expect(
        () => BusinessSettingsRouter.normalizeAndRoute(
          portable.settings,
          entityRowIds: incomplete,
        ),
        throwsFormatException,
      );
    });

    test('row identity maps only require entity keys present in settings', () {
      final snapshot = BusinessSettingsRouter.normalizeAndRoute(
        {
          'assistant_tags_v1': jsonEncode([
            {'name': 'Tag'},
          ]),
        },
        entityRowIds: const {
          'assistant_tags_v1': <String>['portable-tag-row'],
        },
      );

      expect(
        snapshot.entities[BusinessEntityKind.assistantTag]!.single.id,
        'portable-tag-row',
      );
    });

    test('rejects non-string portable row identities', () {
      final entityRowIds = _completeEntityRowIds()
        ..['assistant_tags_v1'] = <Object>[1];

      expect(
        () => BusinessSettingsRouter.normalizeAndRoute({
          'assistant_tags_v1': jsonEncode([
            {'name': 'Tag'},
          ]),
        }, entityRowIds: entityRowIds),
        throwsFormatException,
      );
    });

    test('rejects portable row identity length mismatches', () {
      expect(
        () => BusinessSettingsRouter.normalizeAndRoute(
          {
            'assistant_tags_v1': jsonEncode([
              {'name': 'Only'},
            ]),
          },
          entityRowIds: _completeEntityRowIds(
            sourceKey: 'assistant_tags_v1',
            rowIds: const <String>['row-1', 'row-2'],
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects empty portable row identities', () {
      expect(
        () => BusinessSettingsRouter.normalizeAndRoute(
          {
            'assistant_tags_v1': jsonEncode([
              {'name': 'Tag'},
            ]),
          },
          entityRowIds: _completeEntityRowIds(
            sourceKey: 'assistant_tags_v1',
            rowIds: const <String>['   '],
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects duplicate portable row identities', () {
      expect(
        () => BusinessSettingsRouter.normalizeAndRoute(
          {
            'assistant_tags_v1': jsonEncode([
              {'name': 'First'},
              {'name': 'Second'},
            ]),
          },
          entityRowIds: _completeEntityRowIds(
            sourceKey: 'assistant_tags_v1',
            rowIds: const <String>['same-row', 'same-row'],
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects row identities that disagree with explicit payload ids', () {
      expect(
        () => BusinessSettingsRouter.normalizeAndRoute(
          {
            'assistant_tags_v1': jsonEncode([
              {'id': 'payload-id', 'name': 'Tag'},
            ]),
          },
          entityRowIds: _completeEntityRowIds(
            sourceKey: 'assistant_tags_v1',
            rowIds: const <String>['different-row-id'],
          ),
        ),
        throwsFormatException,
      );
    });

    test('projects distinct numeric ids for id-less memories at runtime', () {
      final snapshot = BusinessSettingsRouter.normalizeAndRoute({
        'assistant_memories_v1': jsonEncode([
          {'assistantId': 'assistant-1', 'content': 'Remember this'},
          {'assistantId': 'assistant-1', 'content': 'Remember that'},
        ]),
      });
      final rows = snapshot.entities[BusinessEntityKind.assistantMemory]!;

      expect(rows, hasLength(2));
      expect(
        rows.map((row) => jsonDecode(row.payload)),
        everyElement(isNot(contains('id'))),
      );
      final published = BusinessSettingsRouter.exportSnapshot(snapshot);
      expect(
        jsonDecode(published['assistant_memories_v1']! as String) as List,
        everyElement(isNot(contains('id'))),
      );

      final runtime = BusinessSettingsRouter.exportRuntimeSnapshot(snapshot);
      final runtimePayloads =
          (jsonDecode(runtime['assistant_memories_v1']! as String) as List)
              .cast<Map>()
              .map((payload) => payload.cast<String, dynamic>())
              .toList();
      final ids = runtimePayloads
          .map((payload) => AssistantMemory.fromJson(payload).id)
          .toList();
      expect(ids, everyElement(lessThan(0)));
      expect(ids.toSet(), hasLength(2));
    });

    test('normalizes legacy embedding overrides before discarding version', () {
      final snapshot = BusinessSettingsRouter.normalizeAndRoute({
        'provider_configs_v1': jsonEncode({
          'legacy': {
            'name': 'Legacy',
            'modelOverrides': {
              'embedding-a': {
                'type': 'embedding',
                'input': ['text'],
                'abilities': ['tool'],
                'output': ['text'],
                'builtInTools': ['search'],
                'built_in_tools': ['search'],
                'tools': ['search'],
                'dimensions': 1536,
              },
              'embedding-b': {
                't': 'embeddings',
                'output': ['text'],
                'name': 'Embedding B',
              },
              'chat-a': {
                'type': 'chat',
                'abilities': ['tool'],
                'output': ['text'],
                'tools': ['search'],
              },
            },
          },
        }),
        'migrations_version_v1': 1,
        'provider_configs_backup_v1': 'legacy backup',
      });

      final exported = BusinessSettingsRouter.exportSnapshot(snapshot);
      final providers =
          jsonDecode(exported['provider_configs_v1']! as String)
              as Map<String, dynamic>;
      final overrides =
          (providers['legacy'] as Map<String, dynamic>)['modelOverrides']
              as Map<String, dynamic>;

      expect(overrides['embedding-a'], {
        'type': 'embedding',
        'input': ['text'],
        'dimensions': 1536,
      });
      expect(overrides['embedding-b'], {
        't': 'embeddings',
        'name': 'Embedding B',
      });
      expect(overrides['chat-a'], {
        'type': 'chat',
        'abilities': ['tool'],
        'output': ['text'],
        'tools': ['search'],
      });
      expect(exported, isNot(contains('migrations_version_v1')));
      expect(exported, isNot(contains('provider_configs_backup_v1')));
    });

    test('embedding cleanup is limited to the one-time pre-v3 migration', () {
      final dirtyOverride = <String, Object?>{
        'type': 'embedding',
        'input': <String>['text'],
        'abilities': <String>['tool'],
        'output': <String>['text'],
        'builtInTools': <String>['search'],
        'built_in_tools': <String>['search'],
        'tools': <String>['search'],
      };
      Map<String, Object?> source({int? version}) => {
        'provider_configs_v1': jsonEncode({
          'provider-a': {
            'modelOverrides': {'embedding-model': dirtyOverride},
          },
        }),
        if (version != null) 'migrations_version_v1': version,
      };
      Map<String, dynamic> embeddingOverride(BusinessSnapshot snapshot) {
        final providers =
            jsonDecode(
                  BusinessSettingsRouter.exportSnapshot(
                        snapshot,
                      )['provider_configs_v1']!
                      as String,
                )
                as Map<String, dynamic>;
        return ((providers['provider-a']
                    as Map<String, dynamic>)['modelOverrides']
                as Map<String, dynamic>)['embedding-model']
            as Map<String, dynamic>;
      }

      expect(
        embeddingOverride(
          BusinessSettingsRouter.normalizeAndRoute(source(version: 3)),
        ),
        dirtyOverride,
      );
      expect(
        embeddingOverride(BusinessSettingsRouter.normalizeAndRoute(source())),
        dirtyOverride,
      );
      expect(
        embeddingOverride(
          BusinessSettingsRouter.normalizeAndRoute(
            source(),
            assumePreV3EmbeddingMigrationWhenVersionMissing: true,
          ),
        ),
        {
          'type': 'embedding',
          'input': ['text'],
        },
      );
    });

    test('normalizes legacy activation and assistant search exactly once', () {
      final snapshot = BusinessSettingsRouter.normalizeAndRoute({
        'assistants_v1': jsonEncode([
          {'id': 'a', 'name': 'A'},
          {'id': 'b', 'name': 'B', 'searchEnabled': false},
        ]),
        'search_enabled_v1': true,
        'instruction_injections_active_ids_v1': jsonEncode([
          'one',
          'one',
          'two',
        ]),
      });
      final exported = BusinessSettingsRouter.exportSnapshot(snapshot);
      final assistants =
          jsonDecode(exported['assistants_v1']! as String) as List;
      final active =
          jsonDecode(
                exported['instruction_injections_active_ids_by_assistant_v1']!
                    as String,
              )
              as Map<String, dynamic>;

      expect(assistants[0]['searchEnabled'], isTrue);
      expect(assistants[1]['searchEnabled'], isFalse);
      expect(active, {
        '__global__': ['one', 'two'],
      });
      expect(exported, isNot(contains('instruction_injections_active_ids_v1')));
      expect(exported, isNot(contains('instruction_injections_active_id_v1')));
    });

    test('exports every entity key using the published external shape', () {
      final exported = BusinessSettingsRouter.exportSnapshot(
        BusinessSettingsRouter.normalizeAndRoute(const {}),
      );

      for (final kind in BusinessEntityKind.values) {
        expect(exported, contains(kind.sourceKey));
        final decoded = jsonDecode(exported[kind.sourceKey]! as String);
        expect(
          decoded,
          kind == BusinessEntityKind.provider ? isA<Map>() : isA<List>(),
        );
      }
      expect(exported['providers_order_v1'], isEmpty);
    });

    test('accepts representative runtime payloads for every entity kind', () {
      final snapshot = BusinessSettingsRouter.normalizeAndRoute({
        'assistants_v1': jsonEncode([
          {
            'id': 'assistant-1',
            'name': 'Assistant',
            'temperature': 0.7,
            'mcpServerIds': ['mcp-1'],
          },
        ]),
        'provider_configs_v1': jsonEncode({
          'provider-1': {
            'id': 'provider-1',
            'enabled': true,
            'apiKey': 'secret',
            'models': ['model-1'],
          },
        }),
        'provider_groups_v1': jsonEncode([
          {'id': 'group-1', 'name': 'Group', 'createdAt': 1},
        ]),
        'mcp_servers_v1': jsonEncode([
          {
            'id': 'mcp-1',
            'enabled': false,
            'transport': 'sse',
            'tools': <Object?>[],
          },
        ]),
        'world_books_v1': jsonEncode([
          {
            'id': 'book-1',
            'enabled': true,
            'entries': [
              {'id': 'entry-1', 'content': 'World'},
            ],
          },
        ]),
        'assistant_memories_v1': jsonEncode([
          {'id': 1, 'assistantId': 'assistant-1', 'content': 'Memory'},
        ]),
        'quick_phrases_v1': jsonEncode([
          {
            'id': 'phrase-1',
            'title': 'Hello',
            'content': 'Hello!',
            'isGlobal': true,
          },
        ]),
        'search_services_v1': jsonEncode([
          {'id': 'search-1', 'type': 'bing_local', 'acceptLanguage': 'en-US'},
        ]),
        'tts_services_v1': jsonEncode([
          {
            'id': 'tts-1',
            'kind': 'openai',
            'enabled': true,
            'apiKey': 'tts-secret',
          },
        ]),
        'instruction_injections_v1': jsonEncode([
          {'id': 'injection-1', 'title': 'Learn', 'prompt': 'Explain'},
        ]),
        'assistant_tags_v1': jsonEncode([
          {'id': 'tag-1', 'name': 'Work'},
        ]),
      });

      for (final kind in BusinessEntityKind.values) {
        expect(snapshot.entities[kind], hasLength(1), reason: kind.sourceKey);
      }
    });

    test('rejects malformed entities and unsupported unknown values', () {
      expect(
        () => BusinessSettingsRouter.normalizeAndRoute({
          'assistants_v1': jsonEncode({'id': 'not-a-list'}),
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BusinessSettingsRouter.normalizeAndRoute({
          'assistant_memories_v1': jsonEncode([
            {'id': 1, 'content': 'missing assistant id'},
          ]),
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BusinessSettingsRouter.normalizeAndRoute({
          'plugin_future_key_v1': {'nested': true},
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects entity fields that runtime models cannot decode', () {
      final invalidBySourceKey = <String, Object>{
        'assistants_v1': [
          {'id': 'assistant-1', 'temperature': 'hot'},
        ],
        'provider_configs_v1': {
          'provider-1': {'enabled': 'yes'},
        },
        'mcp_servers_v1': [
          {'id': 'mcp-1', 'tools': <String, Object?>{}},
        ],
        'world_books_v1': [
          {'id': 'book-1', 'entries': <String, Object?>{}},
        ],
        'assistant_memories_v1': [
          {'id': 'one', 'assistantId': 'assistant-1', 'content': 'memory'},
        ],
        'quick_phrases_v1': [
          {'id': 'phrase-1', 'isGlobal': 'yes'},
        ],
        'search_services_v1': [
          {'id': 'search-1', 'type': 1},
        ],
        'instruction_injections_v1': [
          {'id': 'injection-1', 'prompt': 1},
        ],
      };

      for (final entry in invalidBySourceKey.entries) {
        expect(
          () => BusinessSettingsRouter.normalizeAndRoute({
            entry.key: jsonEncode(entry.value),
          }),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'source key',
              entry.key,
            ),
          ),
          reason: entry.key,
        );
      }
    });

    test('rejects a search service without its required type', () {
      expect(
        () => BusinessSettingsRouter.normalizeAndRoute({
          'search_services_v1': jsonEncode([
            {'id': 'search-1'},
          ]),
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'source key',
            'search_services_v1',
          ),
        ),
      );
    });

    test('preserves payload shapes tolerated by published decoders', () {
      final source = <String, Object?>{
        'provider_configs_v1': jsonEncode({
          'provider-1': {
            'id': 'provider-1',
            'models': [1],
          },
        }),
        'provider_groups_v1': jsonEncode([
          {'id': 1, 'name': <Object?>[], 'createdAt': <Object?>[]},
        ]),
        'mcp_servers_v1': jsonEncode([
          {
            'id': 'mcp-1',
            'transport': 'stdio',
            'tools': <Object?>[],
            'args': [1],
            'env': {'PORT': 8080},
          },
        ]),
        'world_books_v1': jsonEncode([
          {
            'id': 'book-1',
            'entries': [
              {
                'id': 'entry-1',
                'keywords': [1],
              },
            ],
          },
        ]),
        'assistant_memories_v1': jsonEncode([
          {'id': 1, 'assistantId': 'assistant-1', 'content': 42},
        ]),
        'tts_services_v1': jsonEncode([
          {'id': 1, 'enabled': 'yes', 'speed': 'fast'},
        ]),
        'assistant_tags_v1': jsonEncode([
          {'id': 1, 'name': <Object?>[]},
        ]),
      };

      final exported = BusinessSettingsRouter.exportSnapshot(
        BusinessSettingsRouter.normalizeAndRoute(source),
      );

      for (final key in source.keys) {
        expect(
          jsonDecode(exported[key]! as String),
          jsonDecode(source[key]! as String),
          reason: key,
        );
      }
    });
  });
}
