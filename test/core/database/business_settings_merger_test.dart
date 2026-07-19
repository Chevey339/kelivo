import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/business_settings_merger.dart';

void main() {
  test('merges frozen special keys and overwrites ordinary keys', () {
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
    expect(merged['theme_mode_v1'], 'dark');
    expect(merged['plugin_future_key_v1'], 'new');
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
    expect(merged['theme_mode_v1'], 'dark');
  });

  test('merges pinned models into an empty target snapshot', () {
    final merged = BusinessSettingsMerger.merge(const {}, {
      'pinned_models_v1': <String>['provider/model'],
    });

    expect(merged['pinned_models_v1'], <String>['provider/model']);
  });

  test('merge preserves an explicitly empty instruction list', () {
    final merged = BusinessSettingsMerger.merge(
      {
        'instruction_injections_active_ids_by_assistant_v1': jsonEncode({
          '__global__': <String>['old-id'],
        }),
      },
      {'instruction_injections_v1': jsonEncode(const <Object>[])},
      preserveExplicitEmptyInstructionList: true,
    );

    expect(jsonDecode(merged['instruction_injections_v1']! as String), isEmpty);
    expect(
      jsonDecode(
        merged['instruction_injections_active_ids_by_assistant_v1']! as String,
      ),
      {'__global__': <Object>[]},
    );
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
