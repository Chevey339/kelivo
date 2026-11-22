import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/database/business_settings_merger.dart';

void main() {
  test('snapshot merge preserves unrelated local row identities', () {
    final localTag = BusinessEntityValue(
      id: 'generated_original_tag',
      sortOrder: 0,
      payload: jsonEncode({'name': 'Renamed tag'}),
    );
    final existing = BusinessSnapshot(
      entities: {
        BusinessEntityKind.assistantTag: [localTag],
      },
      preferences: {
        'assistant_tag_map_v1': jsonEncode({'assistant-a': localTag.id}),
        'theme_mode_v1': 'light',
      },
    );
    final incoming = BusinessSnapshot(
      entities: const {},
      preferences: const {'theme_mode_v1': 'dark'},
    );

    final merged = BusinessSettingsMerger.mergeSnapshots(
      existing,
      incoming,
      incomingKeys: const {'theme_mode_v1'},
    );

    expect(
      merged.entities[BusinessEntityKind.assistantTag]!.single,
      same(localTag),
    );
    expect(jsonDecode(merged.preferences['assistant_tag_map_v1']! as String), {
      'assistant-a': localTag.id,
    });
    expect(merged.preferences['theme_mode_v1'], 'light');
  });

  test('snapshot merge preserves incoming id-less entity row identity', () {
    final incomingTag = BusinessEntityValue(
      id: 'generated_incoming_tag',
      sortOrder: 0,
      payload: jsonEncode({'name': 'Imported tag'}),
    );
    final incoming = BusinessSnapshot(
      entities: {
        BusinessEntityKind.assistantTag: [incomingTag],
      },
      preferences: const {},
    );

    final merged = BusinessSettingsMerger.mergeSnapshots(
      BusinessSnapshot(entities: const {}, preferences: const {}),
      incoming,
      incomingKeys: const {'assistant_tags_v1'},
    );

    final mergedTag = merged.entities[BusinessEntityKind.assistantTag]!.single;
    expect(mergedTag, same(incomingTag));
    expect(mergedTag.id, incomingTag.id);
    expect(jsonDecode(mergedTag.payload), isNot(contains('id')));
  });

  test('provider order-only merge reorders without replacing configs', () {
    final merged = BusinessSettingsMerger.merge(
      {
        'provider_configs_v1': jsonEncode({
          'local': {'apiKey': 'local-secret'},
          'shared': {'apiKey': 'shared-secret'},
        }),
        'providers_order_v1': <String>['local', 'shared'],
      },
      {
        'providers_order_v1': <String>['shared', 'local'],
      },
    );

    final providers =
        jsonDecode(merged['provider_configs_v1']! as String)
            as Map<String, dynamic>;
    expect(merged['providers_order_v1'], <String>['shared', 'local']);
    expect(providers.keys, <String>['shared', 'local']);
    expect(providers['shared']['apiKey'], 'shared-secret');
    expect(providers['local']['apiKey'], 'local-secret');
  });

  test(
    'snapshot merge preserves selected rows and aligns reassigned memories',
    () {
      final localAssistant = BusinessEntityValue(
        id: 'assistant-a',
        sortOrder: 0,
        payload: jsonEncode({
          'id': 'assistant-a',
          'name': 'Local',
          'avatar': '/local/avatar.png',
          'background': '/local/background.png',
        }),
      );
      final importedAssistant = BusinessEntityValue(
        id: 'assistant-a',
        sortOrder: 0,
        payload: jsonEncode({
          'id': 'assistant-a',
          'name': 'Imported',
          'avatar': '/imported/avatar.png',
          'background': null,
        }),
      );
      final localMemory = BusinessEntityValue(
        id: '1',
        sortOrder: 0,
        payload: jsonEncode({
          'id': 1,
          'assistantId': 'assistant-a',
          'content': 'Local memory',
        }),
        assistantId: 'assistant-a',
      );
      final importedMemory = BusinessEntityValue(
        id: '1',
        sortOrder: 0,
        payload: jsonEncode({
          'id': 1,
          'assistantId': 'assistant-b',
          'content': 'Imported memory',
        }),
        assistantId: 'assistant-b',
      );
      final importedWorldBook = BusinessEntityValue(
        id: 'generated_world_book',
        sortOrder: 0,
        payload: jsonEncode({'name': 'Imported world book'}),
      );

      final merged = BusinessSettingsMerger.mergeSnapshots(
        BusinessSnapshot(
          entities: {
            BusinessEntityKind.assistant: [localAssistant],
            BusinessEntityKind.assistantMemory: [localMemory],
          },
          preferences: const {},
        ),
        BusinessSnapshot(
          entities: {
            BusinessEntityKind.assistant: [importedAssistant],
            BusinessEntityKind.assistantMemory: [importedMemory],
            BusinessEntityKind.worldBook: [importedWorldBook],
          },
          preferences: const {},
        ),
        incomingKeys: const {
          'assistants_v1',
          'assistant_memories_v1',
          'world_books_v1',
        },
      );

      final assistant = merged.entities[BusinessEntityKind.assistant]!.single;
      expect(assistant.id, localAssistant.id);
      expect(jsonDecode(assistant.payload), {
        'id': 'assistant-a',
        'name': 'Imported',
        'avatar': '/local/avatar.png',
        'background': '/local/background.png',
      });
      final memories = merged.entities[BusinessEntityKind.assistantMemory]!;
      expect(memories.first, same(localMemory));
      expect(memories.last.id, '2');
      expect(memories.last.assistantId, importedMemory.assistantId);
      expect(jsonDecode(memories.last.payload)['id'], 2);
      expect(
        merged.entities[BusinessEntityKind.worldBook]!.single,
        same(importedWorldBook),
      );
    },
  );

  test('merges frozen special keys and preserves ordinary local keys', () {
    final existing = <String, Object?>{
      'assistants_v1': jsonEncode([
        {
          'id': 'a',
          'name': 'Local A',
          'avatar': '/local/avatar.png',
          'background': '/local/background.png',
        },
      ]),
      'provider_configs_v1': jsonEncode({
        'local': {'id': 'local', 'apiKey': 'local-secret'},
        'shared': {'id': 'shared', 'apiKey': 'old-secret'},
      }),
      'providers_order_v1': <String>['local', 'shared'],
      'pinned_models_v1': <String>['local/model', 'shared/model'],
      'provider_group_map_v1': jsonEncode({'shared': 'local-group'}),
      'theme_mode_v1': 'light',
      'plugin_future_key_v1': 'old',
    };
    final incoming = <String, Object?>{
      'assistants_v1': jsonEncode([
        {
          'id': 'a',
          'name': 'Imported A',
          'avatar': '/import/avatar.png',
          'background': null,
        },
        {'id': 'b', 'name': 'Imported B'},
      ]),
      'provider_configs_v1': jsonEncode({
        'shared': {'id': 'shared', 'apiKey': 'new-secret'},
        'incoming': {'id': 'incoming', 'apiKey': 'incoming-secret'},
      }),
      'providers_order_v1': <String>['incoming', 'shared'],
      'pinned_models_v1': <String>['shared/model', 'incoming/model'],
      'provider_group_map_v1': jsonEncode({
        'shared': 'incoming-group',
        'incoming': 'incoming-group',
      }),
      'theme_mode_v1': 'dark',
      'plugin_future_key_v1': 'new',
      'new_preference_v1': 'added',
    };

    final merged = BusinessSettingsMerger.merge(existing, incoming);
    final assistants = jsonDecode(merged['assistants_v1']! as String) as List;
    final providers =
        jsonDecode(merged['provider_configs_v1']! as String)
            as Map<String, dynamic>;

    expect(assistants.map((item) => item['id']), <String>['a', 'b']);
    expect(assistants.first['name'], 'Imported A');
    expect(assistants.first['avatar'], '/local/avatar.png');
    expect(assistants.first['background'], '/local/background.png');
    expect(providers.keys, <String>['incoming', 'shared', 'local']);
    expect(providers['shared']['apiKey'], 'new-secret');
    expect(merged['providers_order_v1'], <String>[
      'incoming',
      'shared',
      'local',
    ]);
    expect(merged['pinned_models_v1'], <String>[
      'local/model',
      'shared/model',
      'incoming/model',
    ]);
    expect(jsonDecode(merged['provider_group_map_v1']! as String), {
      'shared': 'local-group',
      'incoming': 'incoming-group',
    });
    expect(merged['theme_mode_v1'], 'light');
    expect(merged['plugin_future_key_v1'], 'old');
    expect(merged['new_preference_v1'], 'added');
  });

  test(
    'keeps list identity rules and resolves assistant memory id conflicts',
    () {
      final merged = BusinessSettingsMerger.merge(
        {
          'assistant_memories_v1': jsonEncode([
            {'id': 1, 'assistantId': 'a', 'content': 'same'},
            {'id': 2, 'assistantId': 'a', 'content': 'local'},
          ]),
          'mcp_servers_v1': jsonEncode([
            {'id': 'mcp-a', 'name': 'Local'},
          ]),
          'assistant_tags_v1': jsonEncode([
            {'id': 'tag-a', 'name': 'Local'},
          ]),
        },
        {
          'assistant_memories_v1': jsonEncode([
            {'id': 9, 'assistantId': 'a', 'content': 'same'},
            {'id': 2, 'assistantId': 'a', 'content': 'incoming'},
          ]),
          'mcp_servers_v1': jsonEncode([
            {'id': 'mcp-a', 'name': 'Imported conflict'},
            {'id': 'mcp-b', 'name': 'Imported new'},
          ]),
          'assistant_tags_v1': jsonEncode([
            {'id': 'tag-a', 'name': 'Imported conflict'},
            {'id': 'tag-b', 'name': 'Imported new'},
          ]),
        },
      );

      final memories =
          jsonDecode(merged['assistant_memories_v1']! as String) as List;
      final servers = jsonDecode(merged['mcp_servers_v1']! as String) as List;
      final tags = jsonDecode(merged['assistant_tags_v1']! as String) as List;

      expect(memories.map((memory) => memory['content']), [
        'same',
        'local',
        'incoming',
      ]);
      expect(memories.last['id'], 3);
      expect(servers.map((server) => server['name']), [
        'Local',
        'Imported new',
      ]);
      expect(tags.map((tag) => tag['name']), ['Local', 'Imported new']);
    },
  );

  test('duplicate memory entry merge preserves migration receipts', () {
    Map<String, Object> memory({
      required String id,
      required String content,
      required List<String> migrationIds,
    }) => <String, Object>{
      'id': id,
      'scope': 'global',
      'type': 'identity',
      'status': 'active',
      'content': content,
      'source': 'extracted',
      'relatedIds': <String>[],
      'migrationIds': migrationIds,
      'createdAt': 1,
      'updatedAt': 1,
    };

    final merged = BusinessSettingsMerger.merge(
      {
        'memory_entries_v1': jsonEncode([
          memory(
            id: 'mem_local001',
            content: 'Same memory',
            migrationIds: const ['local-receipt'],
          ),
        ]),
      },
      {
        'memory_entries_v1': jsonEncode([
          memory(
            id: 'mem_import01',
            content: ' same   MEMORY ',
            migrationIds: const ['local-receipt', 'incoming-receipt'],
          ),
        ]),
      },
    );

    final memories =
        jsonDecode(merged['memory_entries_v1']! as String) as List<dynamic>;
    expect(memories, hasLength(1));
    expect(memories.single['id'], 'mem_local001');
    expect(memories.single['content'], 'Same memory');
    expect(memories.single['migrationIds'], [
      'local-receipt',
      'incoming-receipt',
    ]);
  });

  test(
    'merges id-less entity lists by stable identity without publishing ids',
    () {
      final merged = BusinessSettingsMerger.merge(
        {
          'assistants_v1': jsonEncode([
            {'name': 'Same assistant'},
          ]),
          'mcp_servers_v1': jsonEncode([
            {'name': 'Same MCP'},
          ]),
          'provider_groups_v1': jsonEncode([
            {'name': 'Same group'},
          ]),
          'assistant_tags_v1': jsonEncode([
            {'name': 'Same tag'},
          ]),
        },
        {
          'assistants_v1': jsonEncode([
            {'name': 'Same assistant'},
            {'name': 'Imported assistant'},
          ]),
          'mcp_servers_v1': jsonEncode([
            {'name': 'Same MCP'},
            {'name': 'Imported MCP'},
          ]),
          'provider_groups_v1': jsonEncode([
            {'name': 'Same group'},
            {'name': 'Imported group'},
          ]),
          'assistant_tags_v1': jsonEncode([
            {'name': 'Same tag'},
            {'name': 'Imported tag'},
          ]),
        },
      );

      for (final entry in const <String, List<String>>{
        'assistants_v1': ['Same assistant', 'Imported assistant'],
        'mcp_servers_v1': ['Same MCP', 'Imported MCP'],
        'provider_groups_v1': ['Same group', 'Imported group'],
        'assistant_tags_v1': ['Same tag', 'Imported tag'],
      }.entries) {
        final key = entry.key;
        final items = jsonDecode(merged[key]! as String) as List<dynamic>;
        expect(
          items.map((item) => (item as Map<String, dynamic>)['name']),
          entry.value,
          reason: key,
        );
        expect(
          items.cast<Map<String, dynamic>>(),
          everyElement(isNot(contains('id'))),
          reason: key,
        );
      }
    },
  );

  test('missing imported keys do not erase existing special settings', () {
    final merged = BusinessSettingsMerger.merge(
      {
        'search_services_v1': jsonEncode([
          {'id': 'search-a', 'type': 'bing_local'},
        ]),
        'theme_mode_v1': 'light',
      },
      {'theme_mode_v1': 'dark'},
    );

    expect(jsonDecode(merged['search_services_v1']! as String), [
      {'id': 'search-a', 'type': 'bing_local'},
    ]);
    expect(merged['theme_mode_v1'], 'light');
  });

  test('ASR merge adds cloud providers without changing device providers', () {
    final merged = BusinessSettingsMerger.merge(
      {
        'asr_services_v1': jsonEncode([
          {'id': 'system', 'kind': 'system'},
          {'id': 'local', 'kind': 'sherpa_onnx'},
          {'id': 'shared-cloud', 'kind': 'dashscope', 'name': 'Local name'},
        ]),
        'asr_selected_service_id_v1': 'local',
      },
      {
        'asr_services_v1': jsonEncode([
          {'id': 'shared-cloud', 'kind': 'dashscope', 'name': 'Backup name'},
          {'id': 'incoming-cloud', 'kind': 'step'},
        ]),
        'asr_selected_service_id_v1': 'incoming-cloud',
      },
    );

    final services = jsonDecode(merged['asr_services_v1']! as String) as List;
    expect(services.map((entry) => (entry as Map)['id']), [
      'system',
      'local',
      'shared-cloud',
      'incoming-cloud',
    ]);
    expect((services[2] as Map)['name'], 'Local name');
    expect(merged['asr_selected_service_id_v1'], 'local');
  });

  test('merges pinned models into an empty target snapshot', () {
    final merged = BusinessSettingsMerger.merge(const {}, {
      'pinned_models_v1': <String>['provider/model'],
    });

    expect(merged['pinned_models_v1'], <String>['provider/model']);
  });

  test(
    'merges World Book groups and keeps local assignments on ID conflicts',
    () {
      final existing = {
        'world_books_v1': jsonEncode([
          {'id': 'local-book'},
          {'id': 'ungrouped-book'},
        ]),
        'world_books_grouping_v1': jsonEncode({
          'names': {'local-group': 'Timeline'},
          'memberships': {'local-book': 'local-group'},
        }),
      };
      final incoming = {
        'world_books_v1': jsonEncode([
          {'id': 'local-book'},
          {'id': 'ungrouped-book'},
          {'id': 'imported-book'},
          {'id': 'imported-again'},
        ]),
        'world_books_grouping_v1': jsonEncode({
          'names': {
            'local-group': 'Previous name',
            'imported-group': 'timeline',
            'second-group': 'TIMELINE',
          },
          'memberships': {
            'local-book': 'imported-group',
            'ungrouped-book': 'imported-group',
            'imported-book': 'imported-group',
            'imported-again': 'local-group',
            'deleted-book': 'second-group',
          },
        }),
      };

      final merged = BusinessSettingsMerger.merge(existing, incoming);
      expect(jsonDecode(merged['world_books_grouping_v1']! as String), {
        'names': {
          'local-group': 'Timeline',
          'imported-group': 'timeline (2)',
          'second-group': 'TIMELINE (3)',
        },
        'memberships': {
          'local-book': 'local-group',
          'imported-book': 'imported-group',
          'imported-again': 'local-group',
        },
      });
    },
  );

  test('merge keeps local list entities and adds imported rows', () {
    final entityKeys = <String, String>{
      'world_books_v1': 'world-book',
      'quick_phrases_v1': 'quick-phrase',
      'tts_services_v1': 'tts',
      'instruction_injections_v1': 'injection',
    };
    Map<String, Object?> rowLists(String origin) => {
      for (final entry in entityKeys.entries)
        entry.key: jsonEncode([
          {'id': '$origin-${entry.value}'},
        ]),
    };
    final existing = <String, Object?>{
      ...rowLists('local'),
      'instruction_injections_active_ids_by_assistant_v1': jsonEncode({
        '__global__': <String>['local-injection'],
      }),
    };
    final emptyBackup = BusinessSettingsMerger.merge(existing, {
      for (final key in entityKeys.keys) key: jsonEncode(const <Object>[]),
    });

    for (final entry in entityKeys.entries) {
      final rows = jsonDecode(emptyBackup[entry.key]! as String) as List;
      expect(rows.map((row) => row['id']), [
        'local-${entry.value}',
      ], reason: entry.key);
    }
    expect(
      jsonDecode(
        emptyBackup['instruction_injections_active_ids_by_assistant_v1']!
            as String,
      ),
      {
        '__global__': <String>['local-injection'],
      },
    );

    final merged = BusinessSettingsMerger.merge(existing, rowLists('imported'));

    for (final entry in entityKeys.entries) {
      final rows = jsonDecode(merged[entry.key]! as String) as List;
      expect(rows.map((row) => row['id']), [
        'local-${entry.value}',
        'imported-${entry.value}',
      ], reason: entry.key);
    }
  });

  test('rejects present but invalid pinned model lists', () {
    expect(
      () => BusinessSettingsMerger.merge(
        const {'pinned_models_v1': null},
        const {
          'pinned_models_v1': <String>['provider/model'],
        },
      ),
      throwsFormatException,
    );
    expect(
      () => BusinessSettingsMerger.merge(const {}, const {
        'pinned_models_v1': null,
      }),
      throwsFormatException,
    );
  });

  test('ignores local-only and discarded imported keys', () {
    final merged = BusinessSettingsMerger.merge(
      {'theme_mode_v1': 'light'},
      {
        'flutter_log_enabled_v1': true,
        'display_chat_font_scale_v1': 1.4,
        'pinned_chat_ids': <String>['chat'],
      },
    );

    expect(merged, isNot(contains('flutter_log_enabled_v1')));
    expect(merged, isNot(contains('display_chat_font_scale_v1')));
    expect(merged, isNot(contains('pinned_chat_ids')));
    expect(merged['theme_mode_v1'], 'light');
  });
}
