import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/assistant_copy_options.dart';
import 'package:Kelivo/core/models/assistant_regex.dart';
import 'package:Kelivo/core/models/memory_entry.dart';
import 'package:Kelivo/core/models/preset_message.dart';
import 'package:Kelivo/core/models/quick_phrase.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/services/assistant_copy_service.dart';
import 'package:Kelivo/core/services/instruction_injection_store.dart';
import 'package:Kelivo/core/services/memory/memory_repository.dart';
import 'package:Kelivo/core/services/memory/memory_tools.dart';
import 'package:Kelivo/core/services/memory_store.dart';
import 'package:Kelivo/core/services/quick_phrase_store.dart';
import 'package:Kelivo/core/services/world_book_store.dart';

import '../../support/business_test_harness.dart';

final _source = Assistant(
  id: 'source',
  name: 'Role',
  avatar: 'https://example.com/avatar.png',
  systemPrompt: 'Be helpful',
  chatModelProvider: 'provider',
  chatModelId: 'model',
  temperature: 0.4,
  enableMemory: true,
  memoryFullInjectionTypes: {MemoryType.voice, MemoryType.instruction},
  searchEnabled: true,
  mcpServerIds: ['mcp'],
  allowConversationMcp: true,
  localToolIds: ['fetch'],
  defaultWorkspaceId: 'workspace',
  defaultWorkspaceSetup: DefaultWorkspaceSetup.completed,
  skillIds: ['skill'],
  healthDataTypeIds: ['steps'],
  customHeaders: [
    {'name': 'header', 'value': 'value'},
  ],
  presetMessages: [PresetMessage(role: 'user', content: 'Hello')],
  regexRules: [
    AssistantRegex(
      id: 'regex',
      name: 'rule',
      pattern: 'a',
      replacement: 'b',
      scopes: [AssistantRegexScope.assistant],
    ),
  ],
);

MemoryEntry _memory(
  String id, {
  String? assistantId = 'source',
  MemoryStatus status = MemoryStatus.active,
  List<String> relatedIds = const [],
}) => MemoryEntry(
  id: id,
  scope: assistantId == null ? MemoryScope.global : MemoryScope.assistant,
  assistantId: assistantId,
  type: MemoryType.identity,
  status: status,
  content: id,
  source: MemorySource.extracted,
  relatedIds: relatedIds,
  migrationIds: ['receipt-$id'],
  createdAt: DateTime.utc(2025),
  updatedAt: DateTime.utc(2026),
);

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BusinessTestHarness harness;
  late AssistantProvider provider;
  late MemoryRepository memories;
  late MemoryStore legacy;
  late QuickPhraseStore phrases;

  setUp(() async {
    harness = await createBusinessTestHarness(
      initial: {
        'assistants_v1': Assistant.encodeList([
          _source,
          const Assistant(id: 'other', name: 'Other'),
        ]),
        'current_assistant_id_v1': 'source',
        'memory_entries_v1': jsonEncode(
          [
            _memory(
              'mem_a',
              relatedIds: ['mem_b', 'mem_global', 'mem_other', 'mem_missing'],
            ),
            _memory(
              'mem_b',
              status: MemoryStatus.archived,
              relatedIds: ['mem_a'],
            ),
            _memory('mem_global', assistantId: null),
            _memory('mem_other', assistantId: 'other'),
          ].map((e) => e.toPayload()).toList(),
        ),
        'assistant_memories_v1': jsonEncode([
          {'id': 1, 'assistantId': 'source', 'content': 'Legacy A'},
          {'id': 2, 'assistantId': 'other', 'content': 'Legacy Other'},
        ]),
        'quick_phrases_v1': jsonEncode(
          [
            const QuickPhrase(
              id: 'p1',
              title: 'A',
              content: 'First',
              isGlobal: false,
              assistantId: 'source',
            ),
            const QuickPhrase(
              id: 'p2',
              title: 'B',
              content: 'Second',
              isGlobal: false,
              assistantId: 'source',
            ),
            const QuickPhrase(id: 'global', title: 'Global', content: 'Shared'),
            const QuickPhrase(
              id: 'other',
              title: 'Other',
              content: 'Other',
              isGlobal: false,
              assistantId: 'other',
            ),
          ].map((e) => e.toJson()).toList(),
        ),
        'world_books_active_ids_by_assistant_v1': jsonEncode({
          'source': ['book'],
          '__global__': ['global-book'],
        }),
        'instruction_injections_active_ids_by_assistant_v1': jsonEncode({
          'source': [],
          '__global__': ['global-injection'],
        }),
        'theme_mode_v1': 'dark',
      },
    );
    provider = AssistantProvider(preferences: harness.preferences);
    await provider.loaded;
    memories = MemoryRepository(harness.preferences);
    legacy = MemoryStore(harness.preferences);
    phrases = QuickPhraseStore(harness.preferences);
    addTearDown(provider.dispose);
  });

  Map<String, Object?> snapshot(BusinessPreferences preferences) => {
    for (final key in preferences.getKeys()) key: preferences.get(key),
  };

  test(
    'default copy preserves existing configuration and leaves related data untouched',
    () async {
      final before = snapshot(harness.preferences);
      final id = (await provider.duplicateAssistant('source'))!;
      final copy = provider.getById(id)!;
      expect(copy.name, 'Role Copy');
      final expected = _source.toJson()
        ..['id'] = id
        ..['name'] = 'Role Copy';
      expected['regexRules'] = copy.regexRules.map((e) => e.toJson()).toList();
      expected['presetMessages'] = copy.presetMessages
          .map((e) => e.toJson())
          .toList();
      expect(copy.toJson(), expected);
      expect(
        copy.presetMessages.single.id,
        isNot(_source.presetMessages.single.id),
      );
      expect(copy.presetMessages.single.content, 'Hello');
      expect(copy.regexRules.single.id, isNot('regex'));
      expect(copy.regexRules.single.pattern, 'a');
      expect(
        identical(
          copy.regexRules.single.scopes,
          _source.regexRules.single.scopes,
        ),
        isFalse,
      );
      expect(identical(copy.mcpServerIds, _source.mcpServerIds), isFalse);
      expect(
        identical(copy.customHeaders.single, _source.customHeaders.single),
        isFalse,
      );
      expect(provider.currentAssistantId, 'source');
      expect(provider.assistants.map((e) => e.id), ['source', id, 'other']);
      final after = snapshot(harness.preferences)..remove('assistants_v1');
      expect(after, before..remove('assistants_v1'));
      final reloaded = BusinessPreferences(harness.repository);
      await reloaded.load();
      expect(snapshot(reloaded), snapshot(harness.preferences));
    },
  );

  test(
    'full copy creates independent private records and snapshots bindings',
    () async {
      final originals = (await memories.readAll())
          .map((e) => e.toPayload())
          .toList();
      final id = (await provider.duplicateAssistant(
        'source',
        options: const AssistantCopyOptions.all(),
      ))!;
      final copied = (await memories.readAll())
          .where((e) => e.assistantId == id)
          .toList();
      expect(copied, hasLength(2));
      expect(
        copied.map((e) => e.id).toSet().intersection({'mem_a', 'mem_b'}),
        isEmpty,
      );
      expect(copied[0].relatedIds, [copied[1].id, 'mem_global']);
      expect(copied[1].relatedIds, [copied[0].id]);
      expect(copied[1].status, MemoryStatus.archived);
      expect(copied[0].source, MemorySource.extracted);
      expect(copied[0].createdAt.toUtc(), DateTime.utc(2025));
      expect(copied.expand((e) => e.migrationIds), isEmpty);
      expect(
        (await memories.readAll())
            .where((e) => e.assistantId != id)
            .map((e) => e.toPayload())
            .toList(),
        originals,
      );
      final legacyCopy = (await legacy.getForAssistant(id)).single;
      expect(legacyCopy.id, 3);
      expect(legacyCopy.content, 'Legacy A');
      final phraseCopies = await phrases.getForAssistant(id);
      expect(phraseCopies.map((e) => e.content), ['First', 'Second']);
      expect(
        phraseCopies.map((e) => e.id).toSet().intersection({'p1', 'p2'}),
        isEmpty,
      );
      expect(
        await WorldBookStore(harness.preferences).getActiveIds(assistantId: id),
        ['book'],
      );
      expect(
        await InstructionInjectionStore(
          harness.preferences,
        ).getActiveIds(assistantId: id),
        isEmpty,
      );
      await memories.updateContent(copied[0].id, 'Changed');
      await legacy.delete(id: legacyCopy.id);
      await phrases.update(phraseCopies[0].copyWith(content: 'Changed'));
      expect(
        (await memories.readAll()).firstWhere((e) => e.id == 'mem_a').content,
        'mem_a',
      );
      expect(
        (await legacy.getForAssistant('source')).single.content,
        'Legacy A',
      );
      expect((await phrases.getForAssistant('source')).first.content, 'First');
      final reloaded = BusinessPreferences(harness.repository);
      await reloaded.load();
      expect(snapshot(reloaded), snapshot(harness.preferences));
    },
  );

  test(
    'copied memories still retrieve related global context through memory search',
    () async {
      final chatRepository = ChatDatabaseRepository(harness.database);
      await chatRepository.ensureReady();
      await memories.updateContent('mem_a', 'projectalpha');
      await memories.updateContent('mem_global', 'shared deployment command');
      final globalBefore = (await memories.readAll())
          .singleWhere((entry) => entry.id == 'mem_global')
          .toPayload();

      Future<Map<String, dynamic>> search(Assistant assistant) async {
        final result = await MemoryTools.handle(
          name: MemoryTools.memorySearchProfile,
          args: {'query': 'projectalpha'},
          assistant: assistant,
          repository: memories,
          chatRepository: chatRepository,
        );
        return jsonDecode(result!) as Map<String, dynamic>;
      }

      final originalResult = await search(provider.getById('source')!);
      final originalRelated = (originalResult['related'] as List).single as Map;
      expect(originalRelated['id'], 'mem_global');
      expect(originalRelated['viaId'], 'mem_a');

      final id = (await provider.duplicateAssistant(
        'source',
        options: const AssistantCopyOptions.all(),
      ))!;
      final copiedResult = await search(provider.getById(id)!);
      final copiedMatch = (copiedResult['matched'] as List).single as Map;
      final copiedRelated = (copiedResult['related'] as List).single as Map;
      expect(copiedMatch['id'], isNot('mem_a'));
      expect(copiedMatch['content'], 'projectalpha');
      expect(copiedRelated['id'], 'mem_global');
      expect(copiedRelated['viaId'], copiedMatch['id']);
      expect(copiedRelated['content'], 'shared deployment command');
      expect(
        (await memories.readAll())
            .singleWhere((entry) => entry.id == 'mem_global')
            .toPayload(),
        globalBefore,
      );
    },
  );

  test(
    'partial copy filters by owner and IDs and disables unchecked settings',
    () async {
      final id = (await provider.duplicateAssistant(
        'source',
        options: const AssistantCopyOptions(
          memories: true,
          memoryIds: {'mem_a', 'mem_global', 'mem_other', 'missing'},
          legacyMemoryIds: {},
          regexRules: false,
          skills: false,
          mcp: false,
          tools: false,
          workspace: false,
        ),
      ))!;
      final copy = provider.getById(id)!;
      expect(copy.regexRules, isEmpty);
      expect(
        copy.skillIds,
        isEmpty,
      ); // null would enable every installed skill.
      expect(copy.mcpServerIds, isEmpty);
      expect(copy.allowConversationMcp, isFalse);
      expect(copy.localToolIds, isEmpty);
      expect(copy.searchEnabled, isFalse);
      expect(copy.healthDataTypeIds, isEmpty);
      expect(copy.defaultWorkspaceId, isNull);
      expect(copy.defaultWorkspaceSetup, DefaultWorkspaceSetup.automatic);
      expect(copy.systemPrompt, _source.systemPrompt);
      expect(copy.enableMemory, isTrue);
      final copied = (await memories.readAll())
          .where((e) => e.assistantId == id)
          .single;
      expect(copied.content, 'mem_a');
      expect(copied.relatedIds, ['mem_global']);
      expect(await legacy.getForAssistant(id), isEmpty);
      expect(await phrases.getForAssistant(id), isEmpty);
      expect(
        await WorldBookStore(harness.preferences).getActiveIds(assistantId: id),
        ['global-book'],
      );
      expect(provider.getById('source')!.toJson(), _source.toJson());
    },
  );

  test(
    'full copy snapshots effective global bindings and keeps all-skills semantics',
    () async {
      await provider.updateAssistant(
        provider.getById('other')!.copyWith(clearSkillIds: true),
      );
      final id = (await provider.duplicateAssistant(
        'other',
        options: const AssistantCopyOptions.all(),
      ))!;
      expect(provider.getById(id)!.skillIds, isNull);
      expect(
        await WorldBookStore(harness.preferences).getActiveIds(assistantId: id),
        ['global-book'],
      );
      expect(
        await InstructionInjectionStore(
          harness.preferences,
        ).getActiveIds(assistantId: id),
        ['global-injection'],
      );
      await WorldBookStore(harness.preferences).setActiveIds(['new-default']);
      expect(
        await WorldBookStore(harness.preferences).getActiveIds(assistantId: id),
        ['global-book'],
      );
    },
  );

  test(
    'memory picker only loads source-owned entries including archived and legacy records',
    () async {
      final data = await AssistantCopyService(
        harness.preferences,
      ).loadMemories('source');
      expect(data.entries.map((e) => e.id), ['mem_a', 'mem_b']);
      expect(data.legacy.map((e) => e.id), [1]);
    },
  );

  test(
    'concurrent copies, edits, and memory writers keep every record',
    () async {
      final copies = [
        for (var i = 0; i < 4; i++)
          provider.duplicateAssistant(
            'source',
            options: const AssistantCopyOptions(
              memories: true,
              memoryIds: {'mem_a'},
              legacyMemoryIds: {},
            ),
          ),
      ];
      final writes = [
        for (var i = 0; i < 12; i++)
          MemoryRepository(harness.preferences).create(
            scope: MemoryScope.assistant,
            assistantId: 'source',
            type: MemoryType.workflow,
            content: 'new-$i',
            source: MemorySource.tool,
          ),
      ];
      final edit = provider.updateAssistant(
        provider.getById('other')!.copyWith(name: 'Edited'),
      );
      final ids = await Future.wait(copies);
      await Future.wait(writes);
      await edit;
      expect(ids.toSet(), hasLength(4));
      expect(
        provider.assistants.map((e) => e.name),
        containsAll([
          'Role Copy',
          'Role Copy 2',
          'Role Copy 3',
          'Role Copy 4',
          'Edited',
        ]),
      );
      final all = await memories.readAll();
      expect(all, hasLength(20));
      for (final id in ids) {
        expect(all.where((e) => e.assistantId == id).single.content, 'mem_a');
      }
      final reloaded = BusinessPreferences(harness.repository);
      await reloaded.load();
      expect(snapshot(reloaded), snapshot(harness.preferences));
    },
  );

  test(
    'late binding failure rolls back all data and copied assets, then allows retry',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kelivo_copy_test_',
      );
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      addTearDown(() async {
        PathProviderPlatform.instance = previousPaths;
        await directory.delete(recursive: true);
      });
      final avatar = File('${directory.path}/avatar.png');
      await avatar.writeAsBytes([1, 2, 3]);
      await provider.updateAssistant(
        provider
            .getById('source')!
            .copyWith(avatar: avatar.path, background: avatar.path),
      );
      final before = snapshot(harness.preferences);
      final beforeFiles = (await directory.list(recursive: true).toList())
          .whereType<File>()
          .map((e) => e.path)
          .toSet();
      await harness.database.customStatement('''
      CREATE TRIGGER fail_copy BEFORE INSERT ON preference_rows
      WHEN NEW.key = 'instruction_injections_active_ids_by_assistant_v1'
      BEGIN SELECT RAISE(ABORT, 'simulated binding write failure'); END;
    ''');
      await expectLater(
        provider.duplicateAssistant(
          'source',
          options: const AssistantCopyOptions.all(),
        ),
        throwsA(anything),
      );
      expect(snapshot(harness.preferences), before);
      expect(provider.assistants, hasLength(2));
      final reloaded = BusinessPreferences(harness.repository);
      await reloaded.load();
      expect(snapshot(reloaded), before);
      final afterFiles = (await directory.list(recursive: true).toList())
          .whereType<File>()
          .map((e) => e.path)
          .toSet();
      expect(afterFiles, beforeFiles);
      await harness.database.customStatement('DROP TRIGGER fail_copy;');
      final id = (await provider.duplicateAssistant(
        'source',
        options: const AssistantCopyOptions.all(),
      ))!;
      expect(provider.getById(id)!.name, 'Role Copy');
      expect(
        provider.getById(id)!.avatar,
        isNot(provider.getById('source')!.avatar),
      );
      expect(await File(provider.getById(id)!.avatar!).readAsBytes(), [
        1,
        2,
        3,
      ]);
    },
  );

  test('missing source creates no data', () async {
    final before = snapshot(harness.preferences);
    expect(
      await provider.duplicateAssistant(
        'missing',
        options: const AssistantCopyOptions.all(),
      ),
      isNull,
    );
    expect(snapshot(harness.preferences), before);
  });

  test('default copy retains the existing workspace setup semantics', () async {
    await provider.updateAssistant(
      provider
          .getById('source')!
          .copyWith(defaultWorkspaceSetup: DefaultWorkspaceSetup.automatic),
    );
    final id = (await provider.duplicateAssistant('source'))!;
    expect(provider.getById(id)!.defaultWorkspaceId, 'workspace');
    expect(
      provider.getById(id)!.defaultWorkspaceSetup,
      DefaultWorkspaceSetup.completed,
    );
  });
}
