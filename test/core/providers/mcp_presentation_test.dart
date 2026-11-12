import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/mcp_presentation.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/database/business_restore_service.dart';

import '../../support/business_test_harness.dart';

class _Mcp extends McpProvider {
  _Mcp({required super.preferences});
  final starts = <String>[];
  @override
  Future<bool> connect(String id) async {
    starts.add(id);
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BusinessTestHarness harness;
  late _Mcp mcp;
  setUp(() async {
    harness = await createBusinessTestHarness(
      initial: {
        'mcp_servers_v1': jsonEncode([
          for (final id in ['a', 'b', 'c', 'kelivo_fetch'])
            McpServerConfig(
              id: id,
              enabled: false,
              name: id,
              transport: id == 'kelivo_fetch'
                  ? McpTransportType.inmemory
                  : McpTransportType.http,
              url: id == 'kelivo_fetch' ? '' : 'https://$id.example/mcp',
              tools: [
                McpToolConfig(name: 'one', enabled: true),
                McpToolConfig(name: 'two', enabled: false),
              ],
            ).toJson(),
        ]),
      },
    );
    mcp = _Mcp(preferences: harness.preferences);
    await mcp.loaded;
  });
  tearDown(() => mcp.dispose());

  test(
    'organization and icons survive reload and business backup round trip',
    () async {
      final group = await mcp.createGroup('Search');
      await mcp.moveServersToGroup({'a', 'b'}, group);
      await mcp.setGroupCollapsed(group, true);
      await mcp.setServerIcon(
        'a',
        const McpServerIcon(type: McpIconType.emoji, value: '🔎'),
      );
      final exported = BusinessSettingsRouter.exportSnapshot(
        await harness.repository.readSnapshot(),
      );
      final restored = await createBusinessTestHarness(initial: exported);
      final reloaded = _Mcp(preferences: restored.preferences);
      addTearDown(reloaded.dispose);
      await reloaded.loaded;
      expect(reloaded.groups.single.name, 'Search');
      expect(reloaded.presentationFor('a').groupId, group);
      expect(reloaded.presentationFor('a').icon!.value, '🔎');
      expect(reloaded.groupCollapsed(group), isTrue);
      final config = jsonDecode(reloaded.exportServersAsUiJson()) as Map;
      expect(config.keys, ['mcpServers']);
      expect((config['mcpServers'] as Map)['a'], isNot(contains('icon')));
      expect((config['mcpServers'] as Map)['a'], isNot(contains('groupId')));
    },
  );

  test(
    'backup merge retains new server presentation and local choices',
    () async {
      final group = await mcp.createGroup('Local');
      await mcp.moveServersToGroup({'a'}, group);
      await mcp.setServerIcon(
        'a',
        const McpServerIcon(type: McpIconType.emoji, value: '🌱'),
      );
      await mcp.setServerIcon(
        'b',
        null,
      ); // An explicit reset must win over a backup.
      await mcp.setServerIcon(
        'c',
        const McpServerIcon(type: McpIconType.emoji, value: 'old'),
      );
      await mcp.removeServer(
        'c',
      ); // Leave historical metadata for a removed ID.
      await mcp.setGroupCollapsed('__ungrouped__', true);
      final imported = {
        'mcp_servers_v1': jsonEncode([
          for (final id in ['a', 'b', 'c', 'd'])
            McpServerConfig(
              id: id,
              name: id,
              enabled: false,
              transport: McpTransportType.http,
              url: 'https://$id.example/mcp',
            ).toJson(),
        ]),
        McpProvider.presentationKey: jsonEncode(
          McpPresentation(
            groups: [
              McpGroup(id: group, name: 'Backup rename'),
              const McpGroup(id: 'imported', name: 'Imported'),
            ],
            servers: {
              for (final id in ['a', 'b', 'c', 'd', 'ghost'])
                id: McpServerPresentation(
                  groupId: 'imported',
                  icon: McpServerIcon(
                    type: McpIconType.emoji,
                    value: 'imported-$id',
                  ),
                ),
            },
            collapsed: {group, 'imported'},
          ).toJson(),
        ),
      };
      final restore = BusinessRestoreService(harness.repository);
      await restore.merge(imported);
      final exported = await restore.exportSettings();
      final presentation = McpPresentation.fromJson(
        jsonDecode(exported[McpProvider.presentationKey] as String)
            as Map<String, dynamic>,
      );
      expect(presentation.groups.map((g) => g.name), ['Local', 'Imported']);
      expect(presentation.servers['a']!.groupId, group);
      expect(presentation.servers['a']!.icon!.value, '🌱');
      expect(presentation.servers['b']!.toJson(), isEmpty);
      for (final id in ['c', 'd']) {
        expect(presentation.servers[id]!.groupId, 'imported');
        expect(presentation.servers[id]!.icon!.value, 'imported-$id');
      }
      expect(presentation.servers.containsKey('ghost'), isFalse);
      expect(presentation.collapsed, {'imported', '__ungrouped__'});
      await restore.merge(imported);
      expect(
        (await restore.exportSettings())[McpProvider.presentationKey],
        exported[McpProvider.presentationKey],
      );
    },
  );

  test('first presentation merge retains imported collapse state', () async {
    final restore = BusinessRestoreService(harness.repository);
    await restore.merge({
      McpProvider.presentationKey: jsonEncode(
        McpPresentation(
          groups: [const McpGroup(id: 'imported', name: 'Imported')],
          servers: {'a': const McpServerPresentation(groupId: 'imported')},
          collapsed: {'imported', '__ungrouped__'},
        ).toJson(),
      ),
    });
    final exported = await restore.exportSettings();
    final presentation = McpPresentation.fromJson(
      jsonDecode(exported[McpProvider.presentationKey] as String)
          as Map<String, dynamic>,
    );
    expect(presentation.servers['a']!.groupId, 'imported');
    expect(presentation.collapsed, {'imported', '__ungrouped__'});
  });

  test(
    'serialized presentation edits preserve each other without reconnecting',
    () async {
      final group = await mcp.createGroup('Development');
      await Future.wait([
        mcp.moveServersToGroup({'a'}, group),
        mcp.setServerIcon(
          'a',
          const McpServerIcon(
            type: McpIconType.asset,
            value: 'assets/icons/github.svg',
          ),
        ),
        mcp.renameGroup(group, 'Dev'),
      ]);
      expect(mcp.presentationFor('a').groupId, group);
      expect(mcp.presentationFor('a').icon!.type, McpIconType.asset);
      expect(mcp.groups.single.name, 'Dev');
      expect(mcp.starts, isEmpty);
      await expectLater(mcp.createGroup(' dev '), throwsArgumentError);
    },
  );

  test(
    'deleting a group moves members to Other and preserves servers and icons',
    () async {
      final group = await mcp.createGroup('Search');
      await mcp.moveServersToGroup({'a', 'b'}, group);
      await mcp.setServerIcon(
        'a',
        const McpServerIcon(
          type: McpIconType.url,
          value: 'https://a.example/logo.png',
        ),
      );
      await mcp.deleteGroup(group);
      expect(mcp.groups, isEmpty);
      expect(mcp.servers.length, 4);
      expect(mcp.presentationFor('a').groupId, isNull);
      expect(
        mcp.presentationFor('a').icon!.value,
        'https://a.example/logo.png',
      );
    },
  );

  test(
    'moving and ordering across groups preserves tool configuration',
    () async {
      final first = await mcp.createGroup('First');
      final second = await mcp.createGroup('Second');
      await mcp.moveServersToGroup({'a', 'c'}, first);
      await mcp.moveServersToGroup({'b'}, second);
      await mcp.moveServerBefore('b', first, 'c');
      expect(
        mcp.servers
            .where((s) => mcp.presentationFor(s.id).groupId == first)
            .map((s) => s.id),
        ['a', 'b', 'c'],
      );
      await mcp.reorderGroup(second, 0);
      expect(mcp.groups.map((group) => group.id), [second, first]);
      expect(mcp.getById('b')!.tools.map((tool) => tool.enabled), [
        true,
        false,
      ]);
    },
  );

  test(
    'batch enabling and disabling use the existing server lifecycle',
    () async {
      await mcp.setServersEnabled({'a', 'b'}, true);
      expect(mcp.getById('a')!.enabled, isTrue);
      expect(mcp.getById('b')!.enabled, isTrue);
      expect(mcp.starts, ['a', 'b']);
      await mcp.setServersEnabled({'a', 'b'}, false);
      expect(mcp.getById('a')!.enabled, isFalse);
      expect(mcp.getById('a')!.tools.length, 2);
    },
  );

  test(
    'JSON editor round trip retains independent group and icon metadata',
    () async {
      final group = await mcp.createGroup('Group');
      await mcp.moveServersToGroup({'a'}, group);
      await mcp.setServerIcon(
        'a',
        const McpServerIcon(type: McpIconType.lobehub, value: 'github'),
      );
      await mcp.replaceAllFromJson(mcp.exportServersAsUiJson());
      expect(mcp.presentationFor('a').groupId, group);
      expect(mcp.presentationFor('a').icon!.value, 'github');
    },
  );

  test(
    'delete and undo restore the same server identity and its presentation',
    () async {
      final group = await mcp.createGroup('Group');
      await mcp.moveServersToGroup({'a'}, group);
      await mcp.setServerIcon(
        'a',
        const McpServerIcon(type: McpIconType.emoji, value: '🧰'),
      );
      final server = mcp.getById('a')!;
      final presentation = mcp.presentationFor('a');
      await mcp.removeServers({'a'});
      expect(mcp.getById('a'), isNull);
      expect(mcp.presentationFor('a').icon, isNull);
      await mcp.restoreServer(server, presentation);
      expect(mcp.getById('a')!.toJson(), server.toJson());
      expect(mcp.presentationFor('a').groupId, group);
      expect(mcp.presentationFor('a').icon!.value, '🧰');
    },
  );
}
