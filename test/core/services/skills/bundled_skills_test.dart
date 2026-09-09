import 'dart:io';

import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../support/business_test_harness.dart';

class _MissingAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw StateError('asset missing');
}

class _FailingSkillStore extends ExtensionEntityStore {
  _FailingSkillStore(super.database);

  @override
  Future<void> upsert(
    String kind,
    String id,
    Map<String, dynamic> payload, {
    int? sortOrder,
    String? ownerId,
  }) async => throw StateError('store unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BusinessTestHarness harness;
  late Directory root;
  late ExtensionEntityStore store;

  setUp(() async {
    harness = await createBusinessTestHarness();
    store = ExtensionEntityStore(harness.database);
    root = await Directory.systemTemp.createTemp('kelivo_bundled_skills_');
    addTearDown(() => root.delete(recursive: true));
  });

  SkillsService createService({
    AssetBundle? assets,
    ExtensionEntityStore? entityStore,
  }) {
    final service = SkillsService(
      store: entityStore ?? store,
      skillsDirectory: root,
      bundledAssets: assets ?? rootBundle,
    );
    addTearDown(service.dispose);
    return service;
  }

  test(
    'bundled creator is enabled, discoverable and readable without a workspace',
    () async {
      final service = createService();
      await service.loaded;
      final skill = service.skills.single;
      expect(skill.record.id, 'skill-creator');
      expect(skill.record.source, SkillSource.bundled);
      expect(skill.record.enabled, isTrue);
      final markdown = await File(skill.skillMdPath).readAsString();
      final parsed = SkillFrontmatter.parse(markdown);
      expect(parsed.validate(), isEmpty);
      expect(parsed.name, skill.record.id);
      expect(parsed.description.length, lessThanOrEqualTo(200));
      expect(parsed.body.trim(), isNotEmpty);
      expect(
        buildAvailableSkillsFragment(
          service.resolveForAssistant(null),
          skillsModelRoot: '/skills',
        ),
        contains('/skills/skill-creator/SKILL.md'),
      );
      final result = ClientToolResult.fromHandler(
        await WorkspaceToolsService().handle(
          WorkspaceToolContext.skillsOnly(skillsHostDir: root.path),
          'read_file',
          {'path': '/skills/skill-creator/SKILL.md'},
          toolCallId: 'read-creator',
        ),
      );
      expect(result.content, contains('# Skill Creator'));
    },
  );

  test(
    'restart preserves edits, disabled state and usage without duplicating',
    () async {
      final service = createService();
      await service.loaded;
      const updated =
          '---\nname: skill-creator\ndescription: My workflow\n---\n'
          '# My edited creator\n';
      await service.updateBody('skill-creator', updated);
      await service.setEnabled('skill-creator', false);
      await service.incrementUseCount('skill-creator');

      final restarted = createService();
      await restarted.loaded;
      await restarted.rescan();
      final skill = restarted.skills.single;
      expect(await File(skill.skillMdPath).readAsString(), updated);
      expect(skill.record.source, SkillSource.bundled);
      expect(skill.record.enabled, isFalse);
      expect(skill.record.useCount, 1);
      expect(restarted.resolveForAssistant(null), isEmpty);
    },
  );

  test(
    'deleted bundled skill stays deleted after rescanning and restarting',
    () async {
      final service = createService();
      await service.loaded;
      await service.delete('skill-creator');
      await service.rescan();
      expect(service.skills, isEmpty);

      final restarted = createService();
      await restarted.loaded;
      expect(restarted.skills, isEmpty);
      expect(await store.listByKind(ExtensionEntityStore.kindSkill), isEmpty);
    },
  );

  for (final keepDirectory in [false, true]) {
    test(
      'restores missing bundled markdown from metadata (directory: $keepDirectory)',
      () async {
        final installedAt = DateTime.utc(2026, 1, 1);
        await store.upsert(
          ExtensionEntityStore.kindSkill,
          'skill-creator',
          SkillRecord(
            id: 'skill-creator',
            source: SkillSource.bundled,
            enabled: false,
            useCount: 7,
            installedAt: installedAt,
            updatedAt: installedAt,
          ).toJson(),
        );
        final reference = File(p.join(root.path, 'skill-creator', 'notes.txt'));
        if (keepDirectory) {
          await reference.parent.create();
          await reference.writeAsString('User notes');
        }

        final service = createService();
        await service.loaded;
        final skill = service.skills.single;
        expect(await File(skill.skillMdPath).exists(), isTrue);
        expect(skill.record.source, SkillSource.bundled);
        expect(skill.record.enabled, isFalse);
        expect(skill.record.useCount, 7);
        expect(skill.record.installedAt, installedAt);
        if (keepDirectory) {
          expect(await reference.readAsString(), 'User notes');
        }

        final restarted = createService();
        await restarted.loaded;
        expect(restarted.skills.single.record.toJson(), skill.record.toJson());
      },
    );
  }

  test(
    'upgrade keeps existing skills and does not overwrite a same-name import',
    () async {
      final previous = SkillsService(store: store, skillsDirectory: root);
      addTearDown(previous.dispose);
      await previous.importFromText(
        '---\nname: skill-creator\ndescription: User creator\n---\n# Custom\n',
      );
      await previous.setEnabled('skill-creator', false);
      await previous.importFromText(
        '---\nname: my-skill\ndescription: User skill\n---\n# Mine\n',
      );
      final upgraded = createService();
      await upgraded.loaded;
      expect(upgraded.skills, hasLength(2));
      final creator = upgraded.skills.singleWhere(
        (s) => s.name == 'skill-creator',
      );
      expect(creator.description, 'User creator');
      expect(creator.record.source, SkillSource.paste);
      expect(creator.record.enabled, isFalse);
    },
  );

  test('upgrade seeds creator alongside other user skills', () async {
    final existing = Directory(p.join(root.path, 'my-skill'));
    await existing.create();
    await File(p.join(existing.path, 'SKILL.md')).writeAsString(
      '---\nname: my-skill\ndescription: User skill\n---\n# Mine\n',
    );
    final service = createService();
    await service.loaded;
    expect(service.skills.map((s) => s.record.id), [
      'my-skill',
      'skill-creator',
    ]);
    expect(service.skills.first.record.source, SkillSource.file);
  });

  test('asset failure can retry on the next startup', () async {
    final failed = createService(assets: _MissingAssets());
    await expectLater(failed.loaded, throwsStateError);
    expect(await root.list().toList(), isEmpty);

    final retried = createService();
    await retried.loaded;
    expect(retried.skills.single.record.source, SkillSource.bundled);
  });

  test('failed repair preserves the existing directory and metadata', () async {
    final now = DateTime.utc(2026, 1, 1);
    final record = SkillRecord(
      id: 'skill-creator',
      source: SkillSource.bundled,
      enabled: false,
      useCount: 2,
      installedAt: now,
      updatedAt: now,
    );
    await store.upsert(
      ExtensionEntityStore.kindSkill,
      record.id,
      record.toJson(),
    );
    final reference = File(p.join(root.path, record.id, 'notes.txt'));
    await reference.parent.create();
    await reference.writeAsString('User notes');

    final failed = createService(
      entityStore: _FailingSkillStore(harness.database),
    );
    await expectLater(failed.loaded, throwsStateError);
    expect(await reference.readAsString(), 'User notes');
    expect(
      await File(p.join(reference.parent.path, 'SKILL.md')).exists(),
      isFalse,
    );
    expect(
      await File(p.join(root.path, '.bundled-skill-creator')).exists(),
      isFalse,
    );
    expect(
      (await store.get(ExtensionEntityStore.kindSkill, record.id))!.payload,
      record.toJson(),
    );

    final retried = createService();
    await retried.loaded;
    expect(retried.skills.single.record.enabled, isFalse);
    expect(retried.skills.single.record.useCount, 2);
  });

  test(
    'failed registration leaves no partial installation or completion receipt',
    () async {
      final failed = createService(
        entityStore: _FailingSkillStore(harness.database),
      );
      await expectLater(failed.loaded, throwsStateError);
      expect(await root.list().toList(), isEmpty);

      final retried = createService();
      await retried.loaded;
      expect(retried.skills.single.record.source, SkillSource.bundled);
    },
  );
}
