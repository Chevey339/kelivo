import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_guidance.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import '../../../support/business_test_harness.dart';

class _MissingReference extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == 'assets/skills/visualize/references/data.md') {
      throw StateError('Missing reference');
    }
    return rootBundle.load(key);
  }
}

class _FailingVisualizeStore extends ExtensionEntityStore {
  _FailingVisualizeStore(super.database);
  @override
  Future<void> upsert(
    String kind,
    String id,
    Map<String, dynamic> payload, {
    int? sortOrder,
    String? ownerId,
  }) {
    if (id == 'visualize') throw StateError('Unavailable record store');
    return super.upsert(
      kind,
      id,
      payload,
      sortOrder: sortOrder,
      ownerId: ownerId,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BusinessTestHarness harness;
  late Directory root;
  late ExtensionEntityStore store;
  setUp(() async {
    harness = await createBusinessTestHarness();
    root = await Directory.systemTemp.createTemp('kelivo-visualize-');
    store = ExtensionEntityStore(harness.database);
    addTearDown(() => root.delete(recursive: true));
  });
  SkillsService service({AssetBundle? assets, ExtensionEntityStore? records}) {
    final value = SkillsService(
      store: records ?? store,
      skillsDirectory: root,
      bundledAssets: assets ?? rootBundle,
    );
    addTearDown(value.dispose);
    return value;
  }

  File file(String path) => File(p.join(root.path, 'visualize', path));

  test(
    'bundles exact generated references and reads them through existing skill tools',
    () async {
      final skills = service();
      await skills.loaded;
      expect(skills.skills.map((s) => s.record.id), [
        'skill-creator',
        'visualize',
      ]);
      final visualize = skills.skills.singleWhere(
        (s) => s.record.id == 'visualize',
      );
      expect(visualize.record.source, SkillSource.bundled);
      expect(visualize.record.enabled, isTrue);
      final assets = UiGuidance.generateAssets();
      final actual = Directory(p.join(root.path, 'visualize'))
          .listSync(recursive: true)
          .whereType<File>()
          .map(
            (f) => p
                .split(p.relative(f.path, from: p.join(root.path, 'visualize')))
                .join('/'),
          )
          .toSet();
      expect(actual, assets.keys.toSet());
      for (final entry in assets.entries) {
        expect(await file(entry.key).readAsString(), entry.value);
        final result = ClientToolResult.fromHandler(
          await WorkspaceToolsService().handle(
            WorkspaceToolContext.skillsOnly(skillsHostDir: root.path),
            'read_file',
            {'path': '/skills/visualize/${entry.key}'},
            toolCallId: 'read-guidance',
          ),
        );
        expect(result.content, contains(entry.value.split('\n').first));
      }
      final prompt = buildAvailableSkillsFragment([
        visualize,
      ], skillsModelRoot: '/skills');
      expect(prompt, contains(UiGuidance.capabilitySummary));
      expect(prompt, contains('/skills/visualize/SKILL.md'));
      expect(prompt.length, lessThanOrEqualTo(1536));
    },
  );

  test(
    'enabled and assistant/conversation filters control guidance visibility',
    () async {
      final skills = service();
      await skills.loaded;
      String prompt(Assistant? assistant, {List<String>? override}) =>
          buildAvailableSkillsFragment(
            skills.resolveForAssistant(
              assistant,
              conversationOverride: override,
            ),
            skillsModelRoot: '/skills',
            selectedSkillIds: override ?? assistant?.skillIds ?? const [],
          );
      expect(prompt(null), contains(UiGuidance.capabilitySummary));
      expect(
        prompt(
          const Assistant(id: 'a', name: 'A', skillIds: ['skill-creator']),
        ),
        isNot(contains(UiGuidance.capabilitySummary)),
      );
      expect(prompt(null, override: []), isNot(contains('/visualize/')));
      await skills.setEnabled('visualize', false);
      expect(
        prompt(null, override: ['visualize']),
        isNot(contains(UiGuidance.capabilitySummary)),
      );
    },
  );

  test('edits, disabled state, usage and deletion survive restart', () async {
    final skills = service();
    await skills.loaded;
    const edited =
        '---\nname: visualize\ndescription: My edited guide\n---\n# My workflow\n';
    await skills.updateBody('visualize', edited);
    await file('references/protocol.md').writeAsString('User protocol notes');
    await skills.setEnabled('visualize', false);
    await skills.incrementUseCount('visualize');
    final restarted = service();
    await restarted.loaded;
    final saved = restarted.skills.singleWhere(
      (s) => s.record.id == 'visualize',
    );
    expect(saved.record.enabled, isFalse);
    expect(saved.record.useCount, 1);
    expect(await file('SKILL.md').readAsString(), edited);
    expect(
      await file('references/protocol.md').readAsString(),
      'User protocol notes',
    );
    await restarted.delete('visualize');
    final deleted = service();
    await deleted.loaded;
    expect(deleted.skills.map((s) => s.record.id), ['skill-creator']);
    expect(
      await File(p.join(root.path, '.bundled-visualize')).exists(),
      isTrue,
    );
  });

  test(
    'same-name user import remains user-owned and gains no built-in summary',
    () async {
      final previous = SkillsService(store: store, skillsDirectory: root);
      addTearDown(previous.dispose);
      await previous.importFromText(
        '---\nname: visualize\ndescription: User workflow\n---\n# Custom\n',
      );
      final upgraded = service();
      await upgraded.loaded;
      final custom = upgraded.skills.singleWhere(
        (s) => s.record.id == 'visualize',
      );
      expect(custom.record.source, SkillSource.paste);
      expect(custom.description, 'User workflow');
      expect(await file('references/protocol.md').exists(), isFalse);
      expect(
        buildAvailableSkillsFragment(
          upgraded.resolveForAssistant(null),
          skillsModelRoot: '/skills',
        ),
        isNot(contains(UiGuidance.capabilitySummary)),
      );
    },
  );

  test(
    'missing reference leaves no partial visualize bundle and can retry',
    () async {
      final failed = service(assets: _MissingReference());
      await expectLater(failed.loaded, throwsStateError);
      expect(await Directory(p.join(root.path, 'visualize')).exists(), isFalse);
      expect(
        await File(p.join(root.path, '.bundled-visualize')).exists(),
        isFalse,
      );
      expect(
        await Directory(p.join(root.path, 'skill-creator')).exists(),
        isTrue,
      );
      final retried = service();
      await retried.loaded;
      for (final path in UiGuidance.generateAssets().keys) {
        expect(await file(path).exists(), isTrue, reason: path);
      }
    },
  );

  test(
    'metadata-only repair rolls back only new files on registration failure',
    () async {
      final now = DateTime.utc(2026, 1, 1);
      final record = SkillRecord(
        id: 'visualize',
        source: SkillSource.bundled,
        enabled: false,
        useCount: 7,
        installedAt: now,
        updatedAt: now,
      );
      await store.upsert(
        ExtensionEntityStore.kindSkill,
        record.id,
        record.toJson(),
      );
      await file('references/content.md').parent.create(recursive: true);
      await file('references/content.md').writeAsString('Edited reference');
      await file('notes.txt').writeAsString('User notes');
      final failed = service(records: _FailingVisualizeStore(harness.database));
      await expectLater(failed.loaded, throwsStateError);
      expect(await file('SKILL.md').exists(), isFalse);
      expect(await file('references/protocol.md').exists(), isFalse);
      expect(
        await file('references/content.md').readAsString(),
        'Edited reference',
      );
      expect(await file('notes.txt').readAsString(), 'User notes');
      expect(
        (await store.get(ExtensionEntityStore.kindSkill, 'visualize'))!.payload,
        record.toJson(),
      );
      final retried = service();
      await retried.loaded;
      final saved = retried.skills.singleWhere(
        (s) => s.record.id == 'visualize',
      );
      expect(saved.record.enabled, isFalse);
      expect(saved.record.useCount, 7);
      expect(
        await file('references/content.md').readAsString(),
        'Edited reference',
      );
      expect(await file('SKILL.md').readAsString(), UiGuidance.main);
    },
  );

  test(
    'reference installation never follows an existing parent symlink',
    () async {
      final outside = await Directory.systemTemp.createTemp(
        'genui-reference-canary-',
      );
      addTearDown(() => outside.delete(recursive: true));
      await Directory(p.join(root.path, 'visualize')).create();
      await Link(
        p.join(root.path, 'visualize', 'references'),
      ).create(outside.path);
      final failed = service();
      await expectLater(failed.loaded, throwsFormatException);
      expect(await outside.list().toList(), isEmpty);
      expect(await file('SKILL.md').exists(), isFalse);
      expect(
        await File(p.join(root.path, '.bundled-visualize')).exists(),
        isFalse,
      );
    },
    skip: Platform.isWindows
        ? 'Symlink creation needs host-specific privileges'
        : false,
  );
  test('partial reference merge completes missing files on restart', () async {
    final assets = UiGuidance.generateAssets();
    await file('references/content.md').parent.create(recursive: true);
    await file(
      'references/content.md',
    ).writeAsString(assets['references/content.md']!);
    final resumed = service();
    await resumed.loaded;
    for (final entry in assets.entries) {
      expect(await file(entry.key).readAsString(), entry.value);
    }
    expect(
      resumed.skills
          .singleWhere((s) => s.record.id == 'visualize')
          .record
          .source,
      SkillSource.bundled,
    );
  });

  test(
    'dangling completion receipt cannot create a file outside the skill root',
    () async {
      final outside = await Directory.systemTemp.createTemp(
        'genui-receipt-canary-',
      );
      addTearDown(() => outside.delete(recursive: true));
      final canary = File(p.join(outside.path, 'must-not-exist'));
      await Link(p.join(root.path, '.bundled-visualize')).create(canary.path);
      final failed = service();
      await expectLater(failed.loaded, throwsFormatException);
      expect(await canary.exists(), isFalse);
      expect(await Directory(p.join(root.path, 'visualize')).exists(), isFalse);
    },
    skip: Platform.isWindows
        ? 'Symlink creation needs host-specific privileges'
        : false,
  );
  test(
    'published files with an installing receipt recover bundled identity',
    () async {
      for (final entry in UiGuidance.generateAssets().entries) {
        await file(entry.key).parent.create(recursive: true);
        await file(entry.key).writeAsString(entry.value);
      }
      await File(
        p.join(root.path, '.bundled-visualize'),
      ).writeAsString('installing\n');
      expect(
        await store.get(ExtensionEntityStore.kindSkill, 'visualize'),
        isNull,
      );
      final resumed = service();
      await resumed.loaded;
      final visualize = resumed.skills.singleWhere(
        (s) => s.record.id == 'visualize',
      );
      expect(visualize.record.source, SkillSource.bundled);
      expect(
        buildAvailableSkillsFragment([visualize], skillsModelRoot: '/skills'),
        contains(UiGuidance.capabilitySummary),
      );
      expect(
        await File(p.join(root.path, '.bundled-visualize')).readAsString(),
        '1\n',
      );
    },
  );
}
