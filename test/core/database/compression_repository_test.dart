import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/compression_config.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/models/image_context.dart';
import 'package:Kelivo/core/services/chat/compression_templates.dart';
import 'package:Kelivo/core/services/chat/compression_prompt.dart';

void main() {
  late Directory directory;
  late ChatDatabaseRepository repo;
  const custom = CompressionTemplate(
    id: 'custom',
    name: 'My RP',
    prompt: 'Keep secrets separate {content}',
    scene: 'roleplay',
    outputLanguage: 'zh',
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('compression_library_');
    repo = ChatDatabaseRepository.open(
      file: File('${directory.path}/source.sqlite'),
    );
    await repo.ensureReady();
    await repo.appendLinearMessageToConversation(
      conversation: Conversation(id: 'chat', title: 'source'),
      message: ChatMessage(
        id: 'u',
        conversationId: 'chat',
        role: 'user',
        content: 'hello',
      ),
    );
  });
  tearDown(() async {
    await repo.close();
    await directory.delete(recursive: true);
  });

  test(
    'native settings survive snapshots without enabling automation',
    () async {
      const config = CompressionConfig(
        mode: AutoCompressionMode.auto,
        nativeEnabled: true,
        nativeKeepRecentUserTurns: 2,
        nativeTriggerInputRatio: .5,
        keepRecentUserTurns: 6,
      );
      await repo.compression.saveOverrides('chat', config.toJson());
      final stored = CompressionConfig.fromJson(
        await repo.compression.overrides('chat'),
      );
      final restored = CompressionConfig.fromJson(
        stored.toJson(includeMode: false),
      );
      expect(restored.mode, AutoCompressionMode.off);
      expect(restored.nativeEnabled, isTrue);
      expect(restored.nativeKeepRecentUserTurns, 2);
      expect(restored.nativeTriggerInputRatio, .5);
      expect(restored.triggerInputRatio, .8);
      expect(restored.targetInputRatio, .6);
      expect(restored.keepRecentUserTurns, 6);
      const budget = CompressionInputBudget(window: 10000, output: 1500);
      expect(budget.shouldTrigger(4000, restored), isTrue);
      expect(
        budget.shouldTrigger(
          4000,
          restored.withOverrides({'nativeEnabled': false}),
        ),
        isFalse,
      );
    },
  );

  test(
    'locale changes localize defaults without replacing edits or recipe snapshots',
    () async {
      final zh = await repo.compression.template('code', locale: 'zh-CN');
      final en = await repo.compression.template('code', locale: 'en-US');
      expect(en.prompt, isNot(zh.prompt));
      expect(
        (await repo.compression.templates(locale: 'en-US')).first.prompt,
        builtInCompressionTemplatesForLocale('en-US').first.prompt,
      );
      await repo.compression.saveRecipe(
        CompressionRecipe(
          id: 'zh-snapshot',
          name: 'Saved Chinese instructions',
          template: zh,
          settings: const CompressionConfig(),
        ),
      );
      final edited = CompressionTemplate.fromJson({
        ...en.toJson(),
        'prompt': '${en.prompt}\nPreserve my custom requirement.',
      });
      await repo.compression.saveTemplate(edited, locale: 'en-US');
      expect(
        (await repo.compression.template('code', locale: 'zh-CN')).prompt,
        edited.prompt,
      );
      await repo.compression.saveTemplate(en, locale: 'en-US');
      expect(
        (await repo.compression.template('code', locale: 'zh-CN')).prompt,
        zh.prompt,
      );
      expect(
        (await repo.compression.recipes()).single.template.prompt,
        zh.prompt,
      );
    },
  );

  test(
    'built-in edits persist under the same ID without changing snapshots',
    () async {
      final original = await repo.compression.template('general');
      await repo.compression.saveRecipe(
        CompressionRecipe(
          id: 'original-recipe',
          name: 'Original instructions',
          template: original,
          settings: const CompressionConfig(),
        ),
      );
      await repo.compression.saveTemplate(
        const CompressionTemplate(
          id: 'general',
          name: 'Project handoff',
          prompt: 'Keep verified changes. {content}',
          outputLanguage: 'en',
        ),
      );
      await repo.close();
      repo = ChatDatabaseRepository.open(
        file: File('${directory.path}/source.sqlite'),
      );
      await repo.ensureReady();
      final edited = await repo.compression.template('general');
      expect(edited.builtIn, isTrue);
      expect(edited.name, 'Project handoff');
      expect(edited.outputLanguage, 'en');
      expect(
        renderCompressionPrompt(
          template: edited,
          content: 'Source history',
          targetTokens: 4096,
        ),
        contains('Keep verified changes.'),
      );
      final library = await repo.compression.templates();
      expect(library.length, builtInCompressionTemplates.length);
      expect(
        library.where((template) => template.id == 'general').single.prompt,
        edited.prompt,
      );
      expect(library.every((template) => template.builtIn), isTrue);
      expect(
        (await repo.compression.recipes()).single.template.prompt,
        original.prompt,
      );
      final importedId = await repo.compression.importJson(
        repo.compression.exportTemplate(edited),
      );
      expect(importedId, isNot('general'));
      expect((await repo.compression.template(importedId)).builtIn, isFalse);
      await repo.compression.saveTemplate(original);
      expect(
        (await repo.compression.template('general')).toJson(),
        original.toJson(),
      );
      expect(
        (await repo.compression.template(importedId)).prompt,
        edited.prompt,
      );
    },
  );

  test(
    'original prompt migration runs once, including after deletion',
    () async {
      await repo.compression.importOriginalPrompt(
        'ORIGINAL {locale} {content}',
      );
      expect(
        (await repo.compression.template('original')).outputLanguage,
        'legacy',
      );
      await repo.compression.deleteTemplate(
        'original',
        replacementId: 'general',
      );
      await repo.compression.importOriginalPrompt(
        'ORIGINAL {locale} {content}',
      );
      await expectLater(
        repo.compression.template('original'),
        throwsStateError,
      );
    },
  );

  test(
    'source handles and manifests remap together without changing unrelated prose',
    () {
      const source = 'd9204612-b994-4588-8ffb-ef16e1cf15a8';
      const target = 'ff8481fa-b994-4588-8ffb-ef16e1cf15a8';
      final image = ContextImageIdentity(source, 'part:0').handle;
      final tool = contextTextReference(source, 1, 'call');
      final op = ContextOperation(
        id: 'op',
        kind: ContextOperationKind.compress,
        anchorGroupId: 'group',
        appliedAfterGroupId: 'group',
        sourceGroups: ['group'],
        dependencies: [],
        createdAt: DateTime(2026),
        summary: 'Fact from $source $image $tool, unchanged.',
        originalSummary: '$image $tool',
        compressionDetails: {
          'sourceRevisionIds': [source],
          'imageSources': {
            image: {'messageId': source, 'slot': 'part:0', 'imageIndex': 0},
          },
          'toolSources': {
            tool: {'messageId': source, 'ordinal': 1, 'callId': 'call'},
          },
        },
      );
      final remapped = op.remap(
        groups: {'group': 'new-group'},
        operations: {'op': 'new-op'},
        messages: {source: target},
      );
      final newImage = ContextImageIdentity(target, 'part:0').handle;
      final newTool = contextTextReference(target, 1, 'call');
      expect(
        remapped.summary,
        'Fact from $target $newImage $newTool, unchanged.',
      );
      expect(remapped.originalSummary, '$newImage $newTool');
      expect(remapped.compressionDetails['sourceRevisionIds'], [target]);
      expect(remapped.compressionDetails['imageSources'], contains(newImage));
      expect(remapped.compressionDetails['toolSources'], contains(newTool));
    },
  );

  test('defaults and explicit off override have distinct inheritance', () {
    const defaults = CompressionConfig(
      mode: AutoCompressionMode.auto,
      keepRecentUserTurns: 9,
    );
    expect(const CompressionConfig().mode, AutoCompressionMode.off);
    expect(defaults.withOverrides({}).mode, AutoCompressionMode.auto);
    final overridden = defaults.withOverrides({'mode': 'off'});
    expect(overridden.mode, AutoCompressionMode.off);
    expect(overridden.keepRecentUserTurns, 9);
  });
  test(
    'template and recipe imports allocate local IDs and never enable automation',
    () async {
      await repo.compression.saveTemplate(custom);
      final imported = await repo.compression.importJson(
        repo.compression.exportTemplate(custom),
      );
      expect(imported, isNot(custom.id));
      expect((await repo.compression.template(imported)).prompt, custom.prompt);
      final recipe = CompressionRecipe(
        id: 'recipe',
        name: 'RP',
        template: custom,
        settings: const CompressionConfig(
          mode: AutoCompressionMode.auto,
          templateId: 'custom',
        ),
        focus: 'identity',
      );
      final json = repo.compression.exportRecipe(recipe);
      expect((jsonDecode(json) as Map)['settings'], isNot(contains('mode')));
      await repo.compression.importJson(json);
      final saved = (await repo.compression.recipes()).single;
      expect(saved.settings.mode, AutoCompressionMode.off);
      expect(saved.template.id, isNot(custom.id));
      expect(saved.settings.templateId, saved.template.id);
      expect(await repo.compression.overrides('chat'), isEmpty);
    },
  );
  test(
    'deleting a template replaces conversation references and preserves recipe snapshot',
    () async {
      await repo.compression.saveTemplate(custom);
      await repo.compression.saveOverrides('chat', {
        'templateId': custom.id,
        'mode': 'off',
      });
      await repo.compression.saveRecipe(
        CompressionRecipe(
          id: 'r',
          name: 'recipe',
          template: custom,
          settings: const CompressionConfig(templateId: 'custom'),
        ),
      );
      await repo.compression.deleteTemplate(
        custom.id,
        replacementId: 'general',
      );
      expect(await repo.compression.overrides('chat'), {
        'templateId': 'general',
        'mode': 'off',
      });
      expect(
        (await repo.compression.recipes()).single.template.prompt,
        custom.prompt,
      );
      await expectLater(repo.compression.template('custom'), throwsStateError);
    },
  );
  test(
    'fork copies overrides; deleting chat leaves global library intact',
    () async {
      await repo.compression.saveTemplate(custom);
      await repo.compression.saveOverrides('chat', {
        'mode': 'auto',
        'templateId': 'custom',
      });
      final fork = await repo.forkConversationWithVersions(
        sourceId: 'chat',
        targetRevisionId: 'u',
        assistantId: null,
        preserveVersions: false,
      );
      expect(await repo.compression.overrides(fork!.id), {
        'mode': 'auto',
        'templateId': 'custom',
      });
      await repo.deleteConversation('chat');
      expect(await repo.compression.overrides('chat'), isEmpty);
      expect((await repo.compression.template('custom')).prompt, custom.prompt);
    },
  );
  test(
    'backup merge includes templates, remaps references and imports consent as off',
    () async {
      await repo.compression.saveTemplate(custom);
      await repo.compression.saveOverrides('chat', {
        'mode': 'auto',
        'templateId': 'custom',
        'keepRecentUserTurns': 2,
      });
      final snapshot = File('${directory.path}/backup.sqlite');
      await ChatDatabaseRepository.createConsistentSnapshot(
        sourceFile: File('${directory.path}/source.sqlite'),
        destinationFile: snapshot,
      );
      final target = ChatDatabaseRepository.open(
        file: File('${directory.path}/target.sqlite'),
      );
      await target.ensureReady();
      try {
        await target.compression.saveTemplate(
          const CompressionTemplate(
            id: 'custom',
            name: 'My RP',
            prompt: 'unrelated local template',
          ),
        );
        final report = await target.mergeBackupSnapshot(snapshot);
        expect(report.importedConversations, 1);
        final settings = await target.compression.overrides('chat');
        expect(settings['mode'], 'off');
        expect(settings['templateId'], isNot('custom'));
        expect(
          (await target.compression.template(
            settings['templateId'] as String,
          )).prompt,
          custom.prompt,
        );
        expect(
          (await target.compression.template('custom')).prompt,
          'unrelated local template',
        );
        expect(
          (await target.mergeBackupSnapshot(
            snapshot,
          )).deduplicatedConversations,
          1,
        );
      } finally {
        await target.close();
      }
    },
  );
}
