import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/memory_entry.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/memory_provider.dart';
import 'package:Kelivo/core/providers/memory_provider_v2.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/core/services/memory/memory_prompts.dart';
import 'package:Kelivo/core/services/memory/memory_repository.dart';
import 'package:Kelivo/core/services/memory/memory_tools.dart';
import 'package:Kelivo/core/services/memory/memory_trace.dart';
import 'package:Kelivo/features/home/services/tool_handler_service.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/business_test_harness.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';

  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late BusinessPreferences preferences;
  late ChatDatabaseRepository chatRepository;
  late MemoryRepository memoryRepository;
  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    final businessRepository = BusinessRepository(database);
    preferences = BusinessPreferences(businessRepository);
    chatRepository = ChatDatabaseRepository(database);
    memoryRepository = MemoryRepository(preferences);
    await chatRepository.ensureReady();
    await preferences.load();

    tempDir = await Directory.systemTemp.createTemp('kelivo_memory_tools_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> seedAssistant(String id) async {
    final raw = preferences.getString(BusinessEntityKind.assistant.sourceKey);
    final list = <Map<String, dynamic>>[
      if (raw != null && raw.isNotEmpty)
        for (final item in jsonDecode(raw) as List)
          (item as Map).cast<String, dynamic>(),
    ];
    if (!list.any((item) => item['id'] == id)) {
      list.add({'id': id, 'name': id});
    }
    await preferences.setString(
      BusinessEntityKind.assistant.sourceKey,
      jsonEncode(list),
    );
  }

  Assistant assistant({
    bool enableMemory = true,
    bool allowPastConversationRecall = false,
    MemoryWriteScope memoryWriteScope = MemoryWriteScope.alwaysGlobal,
    String id = 'assistant-a',
  }) {
    return Assistant(
      id: id,
      name: 'Assistant',
      enableMemory: enableMemory,
      allowPastConversationRecall: allowPastConversationRecall,
      memoryWriteScope: memoryWriteScope,
    );
  }

  Future<String?> call(
    String name,
    Map<String, dynamic> args, {
    Assistant? a,
    ChatService? chatService,
    String? conversationId,
  }) {
    return MemoryTools.handle(
      name: name,
      args: args,
      assistant: a ?? assistant(),
      repository: memoryRepository,
      chatRepository: chatRepository,
      chatService: chatService,
      conversationId: conversationId,
    );
  }

  Map<String, dynamic> decode(String raw) =>
      jsonDecode(raw) as Map<String, dynamic>;

  String toolName(Map<String, dynamic> def) =>
      (def['function'] as Map)['name'] as String;

  Map<String, dynamic> propsOf(Map<String, dynamic> def) =>
      ((def['function'] as Map)['parameters'] as Map)['properties']
          as Map<String, dynamic>;

  group('registration (§10.1 / §18.4 item 34)', () {
    test('enableMemory registers six tools; chat_search needs past recall', () {
      final withMemory = MemoryTools.buildDefinitions(
        lang: MemoryPromptLang.en,
        writeScope: MemoryWriteScope.alwaysGlobal,
        enableMemory: true,
        allowPastConversationRecall: false,
      );
      expect(withMemory.map(toolName).toList(), [
        'memory_read',
        'memory_search_profile',
        'memory_update',
        'memory_edit',
        'memory_delete',
        'update_user_profile',
      ]);

      final withRecall = MemoryTools.buildDefinitions(
        lang: MemoryPromptLang.en,
        writeScope: MemoryWriteScope.alwaysGlobal,
        enableMemory: false,
        allowPastConversationRecall: true,
      );
      expect(withRecall.map(toolName).toList(), ['chat_search']);

      final none = MemoryTools.buildDefinitions(
        lang: MemoryPromptLang.en,
        writeScope: MemoryWriteScope.alwaysGlobal,
        enableMemory: false,
        allowPastConversationRecall: false,
      );
      expect(none, isEmpty);
    });

    test('write tools are withheld when writes are not allowed', () {
      final readOnly = MemoryTools.buildDefinitions(
        lang: MemoryPromptLang.en,
        writeScope: MemoryWriteScope.alwaysGlobal,
        enableMemory: true,
        allowPastConversationRecall: true,
        allowMemoryWrites: false,
      );
      expect(readOnly.map(toolName).toList(), [
        'memory_read',
        'memory_search_profile',
        'chat_search',
      ]);
    });

    test('legacy create/edit/delete_memory are gone', () {
      final defs = MemoryTools.buildDefinitions(
        lang: MemoryPromptLang.zh,
        writeScope: MemoryWriteScope.alwaysGlobal,
        enableMemory: true,
        allowPastConversationRecall: true,
      );
      final names = defs.map(toolName).toSet();
      for (final legacy in MemoryTools.legacyToolNames) {
        expect(names.contains(legacy), isFalse);
      }
    });

    testWidgets('ToolHandlerService mirrors registration gates', (
      tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AssistantProvider(
                preferences: createBusinessTestPreferences(),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  McpProvider(preferences: createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider(create: (_) => McpToolService()),
            ChangeNotifierProvider(
              create: (_) => MemoryProviderV2(
                repository: memoryRepository,
                chatRepository: chatRepository,
              ),
            ),
          ],
          child: const SizedBox.shrink(),
        ),
      );
      final context = tester.element(find.byType(SizedBox));
      final service = ToolHandlerService(contextProvider: context);
      final settings = SettingsProvider(createBusinessTestPreferences());

      final off = service.buildToolDefinitions(
        settings,
        assistant(enableMemory: false),
        'openai',
        'gpt',
        false,
        isToolModel: (_, __) => true,
      );
      expect(
        off.any((d) => MemoryTools.enableMemoryToolNames.contains(toolName(d))),
        isFalse,
      );

      final on = service.buildToolDefinitions(
        settings,
        assistant(enableMemory: true),
        'openai',
        'gpt',
        false,
        isToolModel: (_, __) => true,
      );
      final names = on.map(toolName).toSet();
      expect(names.containsAll(MemoryTools.enableMemoryToolNames), isTrue);
      for (final legacy in MemoryTools.legacyToolNames) {
        expect(names.contains(legacy), isFalse);
      }
    });

    test(
      'tool write reloads without narrowing an open global memory list',
      () async {
        // ToolHandlerService wires onMutated to reloadCurrentScope so a write
        // for one assistant cannot collapse an open refreshAll() listing.
        await seedAssistant('assistant-a');
        await seedAssistant('assistant-b');
        final memoryV2 = MemoryProviderV2(
          repository: memoryRepository,
          chatRepository: chatRepository,
        );
        await memoryRepository.create(
          scope: MemoryScope.assistant,
          assistantId: 'assistant-a',
          type: MemoryType.identity,
          content: 'Belongs to assistant-a.',
          source: MemorySource.manual,
        );
        await memoryRepository.create(
          scope: MemoryScope.assistant,
          assistantId: 'assistant-b',
          type: MemoryType.identity,
          content: 'Belongs to assistant-b.',
          source: MemorySource.manual,
        );
        await memoryV2.refreshAll();
        expect(memoryV2.entries, hasLength(2));

        final raw = await MemoryTools.handle(
          name: MemoryTools.memoryUpdate,
          args: {'type': 'identity', 'content': 'User prefers dark mode.'},
          assistant: assistant(id: 'assistant-a'),
          repository: memoryRepository,
          chatRepository: chatRepository,
          onMutated: memoryV2.reloadCurrentScope,
        );
        expect(decode(raw!)['action'], isNotNull);
        expect(
          memoryV2.entries.any((e) => e.assistantId == 'assistant-b'),
          isTrue,
          reason:
              'memory tool onMutated must not collapse refreshAll() to one assistant',
        );
        expect(memoryV2.entries.length, greaterThanOrEqualTo(2));
      },
    );
  });

  group('legacy memory mode (tool handler)', () {
    bool isMemoryRelated(String name) {
      return MemoryTools.legacyToolNames.contains(name) ||
          MemoryTools.allToolNames.contains(name) ||
          name.startsWith('memory_') ||
          name == 'chat_search';
    }

    Future<(ToolHandlerService, SettingsProvider, MemoryProvider)>
    pumpLegacyHandler(WidgetTester tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      final memory = MemoryProvider(
        preferences: createBusinessTestPreferences(),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AssistantProvider(
                preferences: createBusinessTestPreferences(),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  McpProvider(preferences: createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider(create: (_) => McpToolService()),
            ChangeNotifierProvider(
              create: (_) => MemoryProviderV2(
                repository: memoryRepository,
                chatRepository: chatRepository,
              ),
            ),
            ChangeNotifierProvider.value(value: memory),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: const SizedBox.shrink(),
        ),
      );
      final context = tester.element(find.byType(SizedBox));
      return (ToolHandlerService(contextProvider: context), settings, memory);
    }

    testWidgets(
      'legacy ON + enableMemory + supportsTools registers only the trio',
      (tester) async {
        final (service, settings, _) = await pumpLegacyHandler(tester);
        await settings.setLegacyMemoryMode(true);

        final defs = service.buildToolDefinitions(
          settings,
          assistant(enableMemory: true, allowPastConversationRecall: true),
          'openai',
          'gpt',
          false,
          isToolModel: (_, __) => true,
        );
        final names = defs.map(toolName).toList();
        expect(names, MemoryTools.legacyToolNames);
        expect(names.toSet().intersection(MemoryTools.allToolNames), isEmpty);
        expect(names.any((n) => n.startsWith('memory_')), isFalse);
        expect(names, isNot(contains('chat_search')));
      },
    );

    testWidgets('legacy tool descriptions follow the prompt language', (
      tester,
    ) async {
      final (service, settings, _) = await pumpLegacyHandler(tester);
      await settings.setLegacyMemoryMode(true);

      List<String> descriptionsFor(String lang) {
        settings.setMemoryPromptLang(lang);
        return service
            .buildToolDefinitions(
              settings,
              assistant(enableMemory: true),
              'openai',
              'gpt',
              false,
              isToolModel: (_, __) => true,
            )
            .map((d) => (d['function'] as Map)['description'] as String)
            .toList();
      }

      final zh = descriptionsFor('zh');
      final en = descriptionsFor('en');

      expect(zh, everyElement(contains('记忆')));
      expect(en, everyElement(contains('memory record')));
      expect(zh, isNot(equals(en)));
    });

    testWidgets('legacy ON + enableMemory false registers no memory tools', (
      tester,
    ) async {
      final (service, settings, _) = await pumpLegacyHandler(tester);
      await settings.setLegacyMemoryMode(true);

      final defs = service.buildToolDefinitions(
        settings,
        assistant(enableMemory: false, allowPastConversationRecall: true),
        'openai',
        'gpt',
        false,
        isToolModel: (_, __) => true,
      );
      expect(defs.map(toolName).where(isMemoryRelated), isEmpty);
    });

    testWidgets('create_memory writes to MemoryProvider', (tester) async {
      final (service, settings, memory) = await pumpLegacyHandler(tester);
      await settings.setLegacyMemoryMode(true);

      final handler = service.buildToolCallHandler(
        settings,
        assistant(enableMemory: true),
      );
      expect(handler, isNotNull);
      final result = await handler!('create_memory', {
        'content': 'User likes tea',
      });
      expect(result, 'User likes tea');
      expect(memory.getForAssistant('assistant-a'), hasLength(1));
      expect(
        memory.getForAssistant('assistant-a').single.content,
        'User likes tea',
      );
    });
  });

  group('write-scope matrix (§10.2 / §4.3)', () {
    for (final caseData in [
      (MemoryWriteScope.alwaysGlobal, false, null, MemoryScope.global),
      (MemoryWriteScope.alwaysAssistant, false, null, MemoryScope.assistant),
      (MemoryWriteScope.toolDefaultGlobal, true, null, MemoryScope.global),
      (
        MemoryWriteScope.toolDefaultGlobal,
        true,
        'assistant',
        MemoryScope.assistant,
      ),
      (
        MemoryWriteScope.toolDefaultAssistant,
        true,
        null,
        MemoryScope.assistant,
      ),
      (
        MemoryWriteScope.toolDefaultAssistant,
        true,
        'global',
        MemoryScope.global,
      ),
    ]) {
      final policy = caseData.$1;
      final expectScopeInSchema = caseData.$2;
      final scopeArg = caseData.$3;
      final expectedScope = caseData.$4;

      test(
        '${Assistant.memoryWriteScopeToString(policy)} '
        'schema.scope=$expectScopeInSchema → ${MemoryEntry.scopeToString(expectedScope)}',
        () async {
          await seedAssistant('assistant-a');
          final defs = MemoryTools.buildDefinitions(
            lang: MemoryPromptLang.en,
            writeScope: policy,
            enableMemory: true,
            allowPastConversationRecall: false,
          );
          final update = defs.firstWhere(
            (d) => toolName(d) == MemoryTools.memoryUpdate,
          );
          expect(propsOf(update).containsKey('scope'), expectScopeInSchema);

          final raw = await call(MemoryTools.memoryUpdate, {
            'type': 'workflow',
            'content': 'User prefers ${policy.name} writes $scopeArg',
            if (scopeArg != null) 'scope': scopeArg,
          }, a: assistant(memoryWriteScope: policy));
          final payload = decode(raw!);
          expect(payload['action'], 'NEW');
          final stored = await chatRepository.memoriesByIds([
            payload['id'] as String,
          ]);
          expect(stored.single.scope, expectedScope);
          if (expectedScope == MemoryScope.assistant) {
            expect(stored.single.assistantId, 'assistant-a');
          } else {
            expect(stored.single.assistantId, isNull);
          }
        },
      );
    }
  });

  group('memory_read', () {
    Future<List<MemoryEntry>> seedMemories(int count) async {
      final now = DateTime.utc(2026, 9, 8);
      final entries = [
        for (var i = 0; i < count; i++)
          MemoryEntry(
            id: 'mem_${i.toRadixString(16).padLeft(8, '0')}',
            scope: MemoryScope.global,
            type: MemoryType.workflow,
            content: 'Memory entry $i',
            createdAt: now,
            updatedAt: now,
          ),
      ];
      // Equal timestamps exercise the id tie-breaker used across pages.
      await memoryRepository.writeAll(entries.reversed.toList());
      return entries;
    }

    test('reads every entry beyond 100 using next_offset', () async {
      final entries = await seedMemories(205);
      final ids = <String>[];
      var offset = 0;
      for (final expectedCount in [100, 100, 5]) {
        final page = decode(
          (await call(MemoryTools.memoryRead, {
            'limit': 200,
            'offset': offset,
          }))!,
        );
        expect(page['total'], 205);
        expect(page['returned'], expectedCount);
        expect(page['limit'], 100);
        expect(page['offset'], offset);
        final pageEntries = page['entries'] as List;
        expect(pageEntries, hasLength(expectedCount));
        ids.addAll(pageEntries.map((e) => e['id'] as String));
        final hasMore = ids.length < 205;
        expect(page['has_more'], hasMore);
        expect(page['next_offset'], hasMore ? ids.length : null);
        if (hasMore) offset = page['next_offset'] as int;
      }
      expect(ids, entries.map((e) => e.id).toList());
    });

    test(
      'defaults to 50 entries and stops on an exact page boundary',
      () async {
        await seedMemories(100);
        final first = decode((await call(MemoryTools.memoryRead, {}))!);
        expect(first['offset'], 0);
        expect(first['limit'], 50);
        expect(first['returned'], 50);
        expect(first['has_more'], isTrue);
        expect(first['next_offset'], 50);
        final last = decode(
          (await call(MemoryTools.memoryRead, {
            'offset': first['next_offset'],
          }))!,
        );
        expect(last['returned'], 50);
        expect(last['has_more'], isFalse);
        expect(last['next_offset'], isNull);
      },
    );

    test('empty and out-of-range pages have no next offset', () async {
      final empty = decode((await call(MemoryTools.memoryRead, {}))!);
      expect(empty['total'], 0);
      expect(empty['entries'], isEmpty);
      expect(empty['has_more'], isFalse);
      expect(empty['next_offset'], isNull);

      await seedMemories(3);
      for (final offset in [3, 1000]) {
        final page = decode(
          (await call(MemoryTools.memoryRead, {'offset': offset}))!,
        );
        expect(page['total'], 3);
        expect(page['returned'], 0);
        expect(page['offset'], offset);
        expect(page['entries'], isEmpty);
        expect(page['has_more'], isFalse);
        expect(page['next_offset'], isNull);
      }
    });

    test('paginates after type, archive and assistant filtering', () async {
      await seedAssistant('assistant-a');
      await seedAssistant('assistant-b');
      final entries = await seedMemories(6);
      await memoryRepository.writeAll([
        entries[0].copyWith(type: MemoryType.identity),
        entries[1].copyWith(status: MemoryStatus.archived),
        entries[2].copyWith(
          scope: MemoryScope.assistant,
          assistantId: 'assistant-b',
        ),
        entries[3],
        entries[4],
        entries[5].copyWith(
          scope: MemoryScope.assistant,
          assistantId: 'assistant-a',
        ),
      ]);
      for (final includeArchived in [false, true]) {
        final expectedIds = [
          if (includeArchived) entries[1].id,
          entries[3].id,
          entries[4].id,
          entries[5].id,
        ];
        for (var offset = 0; offset < expectedIds.length; offset++) {
          final page = decode(
            (await call(MemoryTools.memoryRead, {
              'type': 'workflow',
              'include_archived': includeArchived,
              'offset': offset,
              'limit': 1,
            }))!,
          );
          expect(page['total'], expectedIds.length);
          expect(page['returned'], 1);
          expect((page['entries'] as List).single['id'], expectedIds[offset]);
          final hasMore = offset + 1 < expectedIds.length;
          expect(page['has_more'], hasMore);
          expect(page['next_offset'], hasMore ? offset + 1 : null);
        }
      }
    });

    test('invalid offset returns tool_error', () async {
      for (final offset in [-1, 1.5, 'invalid', true]) {
        final page = decode(
          (await call(MemoryTools.memoryRead, {'offset': offset}))!,
        );
        expect(page['type'], 'tool_error');
        expect(page['error'], 'invalid_memory_offset');
        expect(page['tool'], MemoryTools.memoryRead);
      }
    });

    test('both language schemas expose pagination and continuation', () {
      for (final lang in MemoryPromptLang.values) {
        final definition = MemoryTools.catalogDefinitions(
          lang,
        ).firstWhere((d) => toolName(d) == MemoryTools.memoryRead);
        expect(propsOf(definition)['offset']['type'], 'integer');
        expect(propsOf(definition)['offset']['minimum'], 0);
        final description = (definition['function'] as Map)['description'];
        expect(description, contains('has_more'));
        expect(description, contains('next_offset'));
      }
    });

    test('happy path returns total/returned/entries', () async {
      await memoryRepository.create(
        scope: MemoryScope.global,
        type: MemoryType.workflow,
        content: 'User cares about Flutter list performance.',
        source: MemorySource.manual,
      );
      await memoryRepository.create(
        scope: MemoryScope.global,
        type: MemoryType.identity,
        content: 'User is a Flutter developer.',
        source: MemorySource.manual,
      );

      final raw = await call(MemoryTools.memoryRead, {'type': 'workflow'});
      final payload = decode(raw!);
      expect(payload['total'], 1);
      expect(payload['returned'], 1);
      final entries = payload['entries'] as List;
      expect(entries, hasLength(1));
      expect(entries.first['type'], 'workflow');
      expect(entries.first['status'], 'active');
      expect(entries.first['id'], startsWith('mem_'));
    });

    test('invalid type returns tool_error', () async {
      final raw = await call(MemoryTools.memoryRead, {'type': 'nope'});
      final payload = decode(raw!);
      expect(payload['type'], 'tool_error');
      expect(payload['error'], 'invalid_memory_type');
      expect(payload['tool'], MemoryTools.memoryRead);
    });
  });

  group('memory_update', () {
    test('NEW on first write', () async {
      final raw = await call(MemoryTools.memoryUpdate, {
        'type': 'voice',
        'content': 'User prefers concise Chinese replies.',
      });
      final payload = decode(raw!);
      expect(payload['action'], 'NEW');
      expect(payload['id'], startsWith('mem_'));
      expect(payload['content'], 'User prefers concise Chinese replies.');
    });

    test('SKIP duplicate via degraded Smart Add', () async {
      await call(MemoryTools.memoryUpdate, {
        'type': 'voice',
        'content': 'User prefers concise Chinese replies.',
      });
      final raw = await call(MemoryTools.memoryUpdate, {
        'type': 'voice',
        'content': '  User   prefers concise Chinese replies. ',
      });
      final payload = decode(raw!);
      expect(payload['action'], 'SKIP');
      expect(payload['reason'], 'duplicate');
      expect(payload['id'], startsWith('mem_'));
    });

    test('empty content returns invalid_memory_content', () async {
      final raw = await call(MemoryTools.memoryUpdate, {
        'type': 'voice',
        'content': '   ',
      });
      final payload = decode(raw!);
      expect(payload['error'], 'invalid_memory_content');
    });

    test('missing type returns invalid_memory_type', () async {
      final raw = await call(MemoryTools.memoryUpdate, {
        'content': 'something',
      });
      final payload = decode(raw!);
      expect(payload['error'], 'invalid_memory_type');
    });
  });

  group('memory_search_profile', () {
    test('happy path matches keywords', () async {
      await memoryRepository.create(
        scope: MemoryScope.global,
        type: MemoryType.workflow,
        content: 'User develops Flutter apps with care for list performance.',
        source: MemorySource.manual,
      );
      final raw = await call(MemoryTools.memorySearchProfile, {
        'query': 'Flutter performance',
      });
      final payload = decode(raw!);
      expect(payload['query'], 'Flutter performance');
      expect(payload['matched'], isNotEmpty);
      expect(payload['related'], isEmpty);
    });

    test('1-hop relatedIds expansion capped at 10 (§18.1 item 15)', () async {
      final hub = await memoryRepository.create(
        scope: MemoryScope.global,
        type: MemoryType.workflow,
        content: 'Hub entry about Flutter performance tuning.',
        source: MemorySource.manual,
      );
      final relatedIds = <String>[];
      for (var i = 0; i < 12; i++) {
        final r = await memoryRepository.create(
          scope: MemoryScope.global,
          type: MemoryType.instruction,
          content: 'Related instruction number $i for Flutter guidance.',
          source: MemorySource.manual,
        );
        relatedIds.add(r.id);
        await memoryRepository.linkBidirectional(hub.id, r.id);
      }

      final raw = await call(MemoryTools.memorySearchProfile, {
        'query': 'Hub Flutter performance',
      });
      final payload = decode(raw!);
      final matched = payload['matched'] as List;
      expect(matched, isNotEmpty);
      expect(matched.first['id'], hub.id);
      final related = payload['related'] as List;
      expect(related, hasLength(10));
      for (final item in related) {
        expect(item['viaId'], hub.id);
        expect(relatedIds.contains(item['id']), isTrue);
      }
    });

    test('LIKE special characters match literally (§5.9)', () async {
      await memoryRepository.create(
        scope: MemoryScope.global,
        type: MemoryType.workflow,
        content: 'Progress is at 100% and uses path_sep\\name.',
        source: MemorySource.manual,
      );
      await memoryRepository.create(
        scope: MemoryScope.global,
        type: MemoryType.workflow,
        content: 'Unrelated memory about lists.',
        source: MemorySource.manual,
      );

      for (final query in ['100%', 'path_sep', r'path_sep\name']) {
        final raw = await call(MemoryTools.memorySearchProfile, {
          'query': query,
        });
        final payload = decode(raw!);
        final matched = payload['matched'] as List;
        expect(matched, isNotEmpty, reason: 'query=$query');
        expect(
          matched.any(
            (e) =>
                (e['content'] as String).contains('100%') ||
                (e['content'] as String).contains(r'path_sep\name'),
          ),
          isTrue,
          reason: 'query=$query should not match everything',
        );
        // A bare `%` token would match every row if unescaped.
        if (query == '100%') {
          expect(matched, hasLength(1));
        }
      }
    });

    test('empty query returns invalid_query', () async {
      final raw = await call(MemoryTools.memorySearchProfile, {'query': '  '});
      final payload = decode(raw!);
      expect(payload['error'], 'invalid_query');
    });
  });

  group('memory_edit', () {
    test('happy path EDIT', () async {
      final created = await memoryRepository.create(
        scope: MemoryScope.global,
        type: MemoryType.identity,
        content: 'Old identity',
        source: MemorySource.manual,
      );
      final raw = await call(MemoryTools.memoryEdit, {
        'id': created.id,
        'content': 'New identity',
      });
      final payload = decode(raw!);
      expect(payload['action'], 'EDIT');
      expect(payload['id'], created.id);
      expect(payload['content'], 'New identity');
    });

    test('memory_not_found for missing/archived/invisible', () async {
      final missing = await call(MemoryTools.memoryEdit, {
        'id': 'mem_deadbeef',
        'content': 'x',
      });
      expect(decode(missing!)['error'], 'memory_not_found');

      final archived = await memoryRepository.create(
        scope: MemoryScope.global,
        type: MemoryType.identity,
        content: 'Will archive',
        source: MemorySource.manual,
      );
      await memoryRepository.archive(archived.id);
      final archivedResult = await call(MemoryTools.memoryEdit, {
        'id': archived.id,
        'content': 'nope',
      });
      expect(decode(archivedResult!)['error'], 'memory_not_found');

      await seedAssistant('assistant-a');
      await seedAssistant('assistant-b');
      final other = await memoryRepository.create(
        scope: MemoryScope.assistant,
        assistantId: 'assistant-b',
        type: MemoryType.identity,
        content: 'Other assistant only',
        source: MemorySource.manual,
      );
      final invisible = await call(MemoryTools.memoryEdit, {
        'id': other.id,
        'content': 'nope',
      }, a: assistant(id: 'assistant-a'));
      expect(decode(invisible!)['error'], 'memory_not_found');
    });
  });

  group('memory_delete', () {
    test('happy path ARCHIVE and strips reverse relatedIds', () async {
      final a = await memoryRepository.create(
        scope: MemoryScope.global,
        type: MemoryType.workflow,
        content: 'Alpha',
        source: MemorySource.manual,
      );
      final b = await memoryRepository.create(
        scope: MemoryScope.global,
        type: MemoryType.workflow,
        content: 'Beta',
        source: MemorySource.manual,
      );
      await memoryRepository.linkBidirectional(a.id, b.id);

      final raw = await call(MemoryTools.memoryDelete, {'id': a.id});
      expect(decode(raw!)['action'], 'ARCHIVE');
      expect(decode(raw)['id'], a.id);

      final remaining = await chatRepository.memoriesByIds([b.id]);
      expect(remaining.single.relatedIds, isNot(contains(a.id)));
    });

    test('memory_not_found for missing id', () async {
      final raw = await call(MemoryTools.memoryDelete, {'id': 'mem_missing1'});
      expect(decode(raw!)['error'], 'memory_not_found');
    });
  });

  group('update_user_profile', () {
    test('happy path updates/clears/rejects', () async {
      final raw = await call(MemoryTools.updateUserProfile, {
        'fields': [
          {'key': 'preferred_name', 'value': 'Alex'},
          {'key': 'location', 'value': 'Shanghai'},
          {'key': 'favourite_color', 'value': 'blue'},
        ],
      });
      final payload = decode(raw!);
      expect(payload['action'], 'PROFILE_UPDATE');
      expect(payload['updated'], containsAll(['preferred_name', 'location']));
      expect(payload['rejected'], [
        {'key': 'favourite_color', 'reason': 'unknown_key'},
      ]);

      final clear = await call(MemoryTools.updateUserProfile, {
        'fields': [
          {'key': 'location', 'value': ''},
        ],
      });
      final cleared = decode(clear!);
      expect(cleared['cleared'], ['location']);
      final fields = await chatRepository.readProfileFields();
      expect(fields.any((f) => f.key == 'location'), isFalse);
      expect(
        fields.any((f) => f.key == 'preferred_name' && f.value == 'Alex'),
        isTrue,
      );
    });

    test('invalid fields shape returns tool_error', () async {
      final raw = await call(MemoryTools.updateUserProfile, {
        'fields': 'not-a-list',
      });
      expect(decode(raw!)['error'], 'invalid_profile_fields');
    });
  });

  group('chat_search', () {
    test(
      'happy path searches past conversations and excludes current',
      () async {
        final chatService = ChatService(existingRepository: chatRepository);
        addTearDown(chatService.close);
        await chatService.init();

        final past = await chatService.createConversation(title: 'Drift talk');
        await chatService.addMessage(
          conversationId: past.id,
          role: 'user',
          content: '我们要不要给 Drift 加一个 v2 的 migration',
        );
        await chatService.updateConversationSummary(
          past.id,
          '讨论了 Drift schema 版本管理与迁移策略。',
          1,
        );

        final current = await chatService.createConversation(title: 'Current');
        await chatService.addMessage(
          conversationId: current.id,
          role: 'user',
          content: 'Drift migration again in current chat',
        );

        final raw = await call(
          MemoryTools.chatSearch,
          {'query': 'Drift migration'},
          a: assistant(enableMemory: false, allowPastConversationRecall: true),
          chatService: chatService,
          conversationId: current.id,
        );
        final payload = decode(raw!);
        expect(payload['query'], 'Drift migration');
        final results = payload['results'] as List;
        expect(results, isNotEmpty);
        expect(results.every((r) => r['conversationId'] != current.id), isTrue);
        expect(results.first['summary'], contains('Drift'));
        expect(results.first['snippet'], isNotEmpty);
      },
    );

    test('empty query returns invalid_query', () async {
      final raw = await call(
        MemoryTools.chatSearch,
        {'query': ''},
        a: assistant(enableMemory: false, allowPastConversationRecall: true),
      );
      expect(decode(raw!)['error'], 'invalid_query');
    });

    test('unavailable without ChatService', () async {
      final raw = await call(
        MemoryTools.chatSearch,
        {'query': 'hello'},
        a: assistant(enableMemory: false, allowPastConversationRecall: true),
      );
      expect(decode(raw!)['error'], 'chat_search_unavailable');
    });

    test('gated off when allowPastConversationRecall is false', () async {
      final raw = await call(
        MemoryTools.chatSearch,
        {'query': 'hello'},
        a: assistant(enableMemory: true, allowPastConversationRecall: false),
      );
      expect(raw, isNull);
    });

    test('conversation_id filter returns the requested conversation', () async {
      final chatService = ChatService(existingRepository: chatRepository);
      addTearDown(chatService.close);
      await chatService.init();

      final wanted = await chatService.createConversation(title: 'Wanted');
      await chatService.addMessage(
        conversationId: wanted.id,
        role: 'user',
        content: 'needle in conversation',
      );
      final other = await chatService.createConversation(title: 'Other');
      await chatService.addMessage(
        conversationId: other.id,
        role: 'user',
        content: 'needle in conversation',
      );

      final raw = await call(
        MemoryTools.chatSearch,
        {'query': 'needle', 'conversation_id': wanted.id, 'limit': 5},
        a: assistant(enableMemory: false, allowPastConversationRecall: true),
        chatService: chatService,
        conversationId: 'some-other-conversation',
      );
      final results = decode(raw!)['results'] as List;
      expect(results, isNotEmpty);
      expect(results.every((r) => r['conversationId'] == wanted.id), isTrue);
    });
  });

  group('temporary conversations', () {
    test('write tools are refused; reads still work', () async {
      final chatService = ChatService(existingRepository: chatRepository);
      addTearDown(chatService.close);
      await chatService.init();
      final temp = await chatService.createDraftConversation(
        title: 'Temp',
        temporary: true,
      );
      expect(chatService.isTemporaryConversation(temp.id), isTrue);

      for (final name in MemoryTools.writeToolNames) {
        final raw = await call(
          name,
          {
            'content': 'User lives in Berlin.',
            'id': 'mem_0001',
            'fields': {'preferred_name': 'Ann'},
          },
          chatService: chatService,
          conversationId: temp.id,
        );
        expect(
          decode(raw!)['error'],
          'temporary_conversation',
          reason: '$name must not persist from a throwaway chat',
        );
      }

      final read = await call(
        MemoryTools.memoryRead,
        {'type': 'identity'},
        chatService: chatService,
        conversationId: temp.id,
      );
      expect(decode(read!).containsKey('error'), isFalse);
    });

    test('read tools do not leave pipeline traces', () async {
      final chatService = ChatService(existingRepository: chatRepository);
      addTearDown(chatService.close);
      await chatService.init();
      final temp = await chatService.createDraftConversation(
        title: 'Temp Trace',
        temporary: true,
      );
      final recorder = MemoryTraceRecorder();

      for (final name in [
        MemoryTools.memoryRead,
        MemoryTools.memorySearchProfile,
      ]) {
        final raw = await MemoryTools.handle(
          name: name,
          args: name == MemoryTools.memorySearchProfile
              ? {'query': 'anything'}
              : {'type': 'identity'},
          assistant: assistant(),
          repository: memoryRepository,
          chatRepository: chatRepository,
          chatService: chatService,
          conversationId: temp.id,
          traceRecorder: recorder,
          conversationTitle: temp.title,
        );
        expect(raw, isNotNull);
      }

      final chatSearch = await MemoryTools.handle(
        name: MemoryTools.chatSearch,
        args: {'query': 'anything'},
        assistant: assistant(
          enableMemory: false,
          allowPastConversationRecall: true,
        ),
        repository: memoryRepository,
        chatRepository: chatRepository,
        chatService: chatService,
        conversationId: temp.id,
        traceRecorder: recorder,
        conversationTitle: temp.title,
      );
      expect(chatSearch, isNotNull);
      expect(
        recorder.traces,
        isEmpty,
        reason: 'temporary chat tools must not linger in the trace viewer',
      );
    });
  });

  group('bilingual descriptions', () {
    test('zh and en descriptions differ for memory_read', () {
      final zh = MemoryTools.buildDefinitions(
        lang: MemoryPromptLang.zh,
        writeScope: MemoryWriteScope.alwaysGlobal,
        enableMemory: true,
        allowPastConversationRecall: false,
      ).first;
      final en = MemoryTools.buildDefinitions(
        lang: MemoryPromptLang.en,
        writeScope: MemoryWriteScope.alwaysGlobal,
        enableMemory: true,
        allowPastConversationRecall: false,
      ).first;
      final zhDesc = (zh['function'] as Map)['description'] as String;
      final enDesc = (en['function'] as Map)['description'] as String;
      expect(zhDesc, contains('长期记忆'));
      expect(enDesc, contains('long-term memory'));
      expect(zhDesc, isNot(equals(enDesc)));
    });
  });
}
