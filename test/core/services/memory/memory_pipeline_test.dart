import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/memory_entry.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/memory_provider_v2.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/memory/memory_gatekeeper.dart';
import 'package:Kelivo/core/services/memory/memory_pipeline.dart';
import 'package:Kelivo/core/services/memory/memory_prompts.dart';
import 'package:Kelivo/core/services/memory/memory_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingTextRepository extends ChatDatabaseRepository {
  _CountingTextRepository(super.db);

  final textReads = <int>[];

  @override
  Future<List<ChatMessageText>> getMessageTexts(
    List<String> ids, {
    int? trimmedPrefixLength,
  }) {
    textReads.add(ids.length);
    return super.getMessageTexts(ids, trimmedPrefixLength: trimmedPrefixLength);
  }
}

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
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late BusinessPreferences preferences;
  late ChatDatabaseRepository chatRepository;
  late MemoryRepository memoryRepository;
  late ChatService chatService;
  late SettingsProvider settings;
  late AssistantProvider assistants;
  late List<String> modelPrompts;
  late MemoryPipelineService pipeline;
  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('kelivo_memory_pipeline_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);

    database = AppDatabase.open(file: File('${tempDir.path}/chat.sqlite'));
    final businessRepository = BusinessRepository(database);
    preferences = BusinessPreferences(businessRepository);
    chatRepository = ChatDatabaseRepository(database);
    memoryRepository = MemoryRepository(preferences);
    await chatRepository.ensureReady();
    await preferences.load();

    chatService = ChatService(existingRepository: chatRepository);
    await chatService.init();

    settings = SettingsProvider(preferences);
    await settings.loaded;
    await settings.setMemoryModel('openai', 'gpt-test');
    await settings.setMemoryPromptLang('zh');

    // Seed a listed model so existence check passes.
    final cfg = settings.getProviderConfig('openai');
    await settings.setProviderConfig(
      'openai',
      cfg.copyWith(models: ['gpt-test']),
    );

    assistants = AssistantProvider(
      preferences: preferences,
      chatService: chatService,
    );
    await assistants.loaded;

    final memoryV2 = MemoryProviderV2(
      repository: memoryRepository,
      chatRepository: chatRepository,
    );

    modelPrompts = [];
    pipeline = MemoryPipelineService(
      chatService: chatService,
      repository: memoryRepository,
      chatRepository: chatRepository,
      settings: () => settings,
      assistants: () => assistants,
      memoryV2: () => memoryV2,
      generateText:
          ({
            required ProviderConfig config,
            required String modelId,
            required String prompt,
            String? conversationId,
            ReasoningRequest reasoning = ReasoningRequest.auto,
          }) async {
            modelPrompts.add(prompt);
            return '<gate><user_memory>false</user_memory></gate>';
          },
    );
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    await chatService.close();
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
      list.add({
        'id': id,
        'name': id,
        'enableMemory': true,
        'autoOrganizeMemory': true,
      });
    }
    await preferences.setString(
      BusinessEntityKind.assistant.sourceKey,
      jsonEncode(list),
    );
  }

  Assistant assistant({
    MemorySmartAddMode mode = MemorySmartAddMode.batched,
    MemoryWriteScope scope = MemoryWriteScope.alwaysGlobal,
  }) {
    return Assistant(
      id: 'a1',
      name: 'A1',
      enableMemory: true,
      autoOrganizeMemory: true,
      memorySmartAddMode: mode,
      memoryWriteScope: scope,
    );
  }

  List<({ChatMessage message, int order})> sampleWindow({
    required String conversationId,
    int endOrder = 3,
  }) {
    return [
      (
        message: ChatMessage(
          role: 'user',
          content: '我是大学生，学软件工程。',
          conversationId: conversationId,
        ),
        order: endOrder - 1,
      ),
      (
        message: ChatMessage(
          role: 'assistant',
          content: '了解了。',
          conversationId: conversationId,
        ),
        order: endOrder,
      ),
    ];
  }

  group('§12.10 conversation summary double gate', () {
    test('requires both switches', () {
      expect(
        MemoryPipelineService.shouldGenerateConversationSummary(
          allowPastConversationRecall: true,
          generateConversationSummary: true,
        ),
        isTrue,
      );
      expect(
        MemoryPipelineService.shouldGenerateConversationSummary(
          allowPastConversationRecall: true,
          generateConversationSummary: false,
        ),
        isFalse,
      );
      expect(
        MemoryPipelineService.shouldGenerateConversationSummary(
          allowPastConversationRecall: false,
          generateConversationSummary: true,
        ),
        isFalse,
      );
    });
  });

  group('buildConversationText', () {
    test('retains the same suffix after applying both text limits', () {
      final messages = List.generate(
        30,
        (i) => ChatMessage(
          role: 'user',
          conversationId: 'c',
          content: '$i-${'x' * 2100}',
        ),
      );
      final full = messages
          .map((m) => 'User: ${m.content.substring(0, 2000)}…')
          .join('\n\n');
      expect(
        MemoryPipelineService.buildConversationText(
          messages,
          MemoryPromptLang.en,
        ),
        '…${full.substring(full.length - 12000)}',
      );
    });
    test('uses zh/en prefixes and TextPart text only', () {
      final msgs = [
        ChatMessage(
          role: 'user',
          conversationId: 'c',
          parts: const [
            TextPart('hello  world'),
            ImagePart(uri: '/tmp/a.png'),
          ],
        ),
        ChatMessage(role: 'assistant', content: 'hi', conversationId: 'c'),
        ChatMessage(role: 'tool', content: 'ignored', conversationId: 'c'),
      ];
      final zh = MemoryPipelineService.buildConversationText(
        msgs,
        MemoryPromptLang.zh,
      );
      expect(zh, contains('用户：'));
      expect(zh, contains('助手：'));
      expect(zh, contains('hello  world'));
      expect(zh, isNot(contains('/tmp/a.png')));
      expect(zh, isNot(contains('[image:')));
      expect(zh, isNot(contains('ignored')));

      final en = MemoryPipelineService.buildConversationText(
        msgs,
        MemoryPromptLang.en,
      );
      expect(en, contains('User: '));
      expect(en, contains('Assistant: '));
    });
  });

  group('memory organize window', () {
    test(
      'worker bounds trimmed text and keeps Unicode intact at the prompt limit',
      () async {
        final convo = await chatService.createConversation(title: 'long text');
        final prefix = 'a' * 1999;
        final message = await chatService.addMessage(
          conversationId: convo.id,
          role: 'user',
          parts: [
            TextPart('\u2003$prefix'),
            const ReasoningPart('private'),
            TextPart('😀 \u0000${'b' * 100000}  '),
          ],
        );
        final rows = await chatRepository.getMessageTexts([
          message.id,
        ], trimmedPrefixLength: 2000);
        expect(rows.single.text, '$prefix😀');
        final prompt = MemoryPipelineService.buildConversationText([
          message,
        ], MemoryPromptLang.en);
        expect(prompt, 'User: $prefix…');
        expect(
          await chatService.generateSummarySource(convo.id, start: 0, end: 1),
          prefix,
        );
      },
    );

    test(
      'manual organize advances the saved watermark and excludes prior text on the next run',
      () async {
        final id = await assistants.addAssistant(name: 'Memory');
        await assistants.updateAssistant(
          assistants.getById(id)!.copyWith(enableMemory: true),
        );
        final convo = await chatService.createConversation(
          title: 'manual',
          assistantId: id,
        );
        await chatService.addMessage(
          conversationId: convo.id,
          role: 'user',
          content: 'first question',
        );
        await chatService.addMessage(
          conversationId: convo.id,
          role: 'assistant',
          parts: const [
            ReasoningPart('hidden payload'),
            TextPart('first answer'),
          ],
        );
        final first = await pipeline.runNow(
          conversationId: convo.id,
          assistantId: id,
        );
        expect(first.advanced, isTrue);
        expect(first.windowSize, 2);
        expect(
          (await chatRepository.getConversation(
            convo.id,
          ))!.lastMemoryExtractedOrder,
          1,
        );
        expect(
          modelPrompts.single,
          contains('用户：first question\n\n助手：first answer'),
        );
        expect(modelPrompts.single, isNot(contains('hidden payload')));
        await chatService.addMessage(
          conversationId: convo.id,
          role: 'user',
          content: 'new question',
        );
        final next = await pipeline.runNow(
          conversationId: convo.id,
          assistantId: id,
        );
        expect(next.windowSize, 1);
        expect(
          (await chatRepository.getConversation(
            convo.id,
          ))!.lastMemoryExtractedOrder,
          2,
        );
        expect(modelPrompts.last, contains('用户：new question'));
        expect(modelPrompts.last, isNot(contains('first question')));
      },
    );

    test(
      '8,000 revisions read only eligible text and keep full window bounds',
      () async {
        final convo = await chatService.createConversation(
          title: 'long history',
        );
        await database.customStatement(
          '''
WITH RECURSIVE history(n) AS (
 SELECT 0 UNION ALL SELECT n + 1 FROM history WHERE n < 7999
)
INSERT INTO message_rows (id, conversation_id, role, timestamp, message_order)
SELECT 'm' || n, ?, CASE n % 2 WHEN 0 THEN 'user' ELSE 'assistant' END, n, n FROM history
''',
          [convo.id],
        );
        await database.customStatement(
          '''
INSERT INTO message_part_rows (conversation_id, revision_id, ordinal, kind, payload, created_at, updated_at)
SELECT conversation_id, id, 0, 'text', id, 0, 0 FROM message_rows WHERE conversation_id = ?
''',
          [convo.id],
        );
        final reader = _CountingTextRepository(database);
        final visited = <String>[];
        Future<({int startOrder, int endOrder, int length})?> read(
          int watermark,
          int turns, {
          int limit = 20,
        }) {
          visited.clear();
          return reader.readMemoryOrganizeWindow(
            convo.id,
            watermark: watermark,
            minAssistantTurns: turns,
            firstWindowLimit: 20,
            textPrefixLength: 2001,
            addText: (role, text) {
              visited.add(text);
              return visited.length < limit;
            },
          );
        }

        expect((await read(7998, 2))!.length, 0);
        expect(visited, isEmpty);
        expect(reader.textReads, isEmpty);
        expect(await read(7998, 1), (
          startOrder: 7999,
          endOrder: 7999,
          length: 1,
        ));
        expect(visited, ['m7999']);
        expect(reader.textReads, [1]);
        expect(await read(-1, 20), (
          startOrder: 7980,
          endOrder: 7999,
          length: 20,
        ));
        expect(visited, List.generate(20, (i) => 'm${7999 - i}'));
        expect(await read(9, 20, limit: 3), (
          startOrder: 10,
          endOrder: 7999,
          length: 7990,
        ));
        expect(visited, ['m7999', 'm7998', 'm7997']);
        expect(reader.textReads, [1, 20, 20]);
      },
    );

    test(
      'uses raw positions across gaps and only counts the selected revisions',
      () async {
        final convo = await chatService.createConversation(title: 'versions');
        Future<void> put(
          String id,
          String role,
          int order, {
          String? group,
          int version = 0,
          bool live = false,
          List<MessagePart>? parts,
        }) => chatRepository.putMessage(
          ChatMessage(
            id: id,
            conversationId: convo.id,
            role: role,
            content: id,
            parts: parts,
            groupId: group,
            version: version,
            isStreaming: live,
          ),
          messageOrder: order,
        );
        Future<List<String>?> window(
          int watermark,
          int minTurns, {
          int cap = 20,
        }) async {
          final contents = <String>[];
          final bounds = await chatRepository.readMemoryOrganizeWindow(
            convo.id,
            watermark: watermark,
            minAssistantTurns: minTurns,
            firstWindowLimit: cap,
            textPrefixLength: 2001,
            addText: (role, text) {
              contents.add(text);
              return true;
            },
          );
          return bounds == null ? null : contents.reversed.toList();
        }

        await put('u', 'user', 10);
        await put('a', 'assistant', 20);
        await put('b', 'assistant', 35);
        await put(
          'a1',
          'assistant',
          90,
          group: 'a',
          version: 1,
          parts: const [
            TextPart('a'),
            ReasoningPart('private reasoning'),
            ImagePart(uri: 'photo.png'),
            TextPart('1'),
          ],
        );
        await put('u2', 'user', 100);
        expect(await window(-1, 3), isEmpty);
        expect(await window(-1, 2, cap: 1), ['u2']);
        expect(await window(2, 1), ['a1', 'u2']);
        await chatService.setSelectedVersion(convo.id, 'a', 0);
        expect(await window(2, 1), isEmpty);
        expect(await window(0, 2), ['a', 'b', 'u2']);
        expect(await window(2, 0), ['u2']);
        await put('pending', 'assistant', 200, live: true);
        expect(await window(0, 0), isNull);
      },
    );
  });

  group('temporary conversations', () {
    test('are never organized into long-term memory', () async {
      // A temporary chat is discarded when the user leaves it, so distilling
      // it would outlive the conversation they asked to be throwaway.
      await seedAssistant('a1');
      final temp = await chatService.createDraftConversation(
        title: 'temp',
        assistantId: 'a1',
        temporary: true,
      );
      expect(chatService.isTemporaryConversation(temp.id), isTrue);

      final result = await pipeline.runNow(
        conversationId: temp.id,
        assistantId: 'a1',
      );
      expect(result.advanced, isFalse);
      expect(result.error, 'temporary_conversation');

      // The auto path must be just as silent.
      pipeline.scheduleIfNeeded(conversationId: temp.id, assistantId: 'a1');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        await chatRepository.queryVisibleMemories(assistantId: 'a1'),
        isEmpty,
      );
    });
  });

  group('background refresh does not narrow the UI', () {
    test('reloadCurrentScope keeps a global listing intact', () async {
      // The global memory page loads every assistant. A background run knows
      // only the assistant it ran for, and passing that id would drop every
      // other assistant's entries from the open list.
      final memoryV2 = MemoryProviderV2(
        repository: memoryRepository,
        chatRepository: chatRepository,
      );
      await memoryRepository.create(
        scope: MemoryScope.assistant,
        assistantId: 'a1',
        type: MemoryType.identity,
        content: 'Belongs to a1.',
        source: MemorySource.manual,
      );
      await memoryRepository.create(
        scope: MemoryScope.assistant,
        assistantId: 'a2',
        type: MemoryType.identity,
        content: 'Belongs to a2.',
        source: MemorySource.manual,
      );

      await memoryV2.refreshAll();
      expect(memoryV2.entries, hasLength(2));

      await memoryV2.reloadCurrentScope();
      expect(
        memoryV2.entries,
        hasLength(2),
        reason: 'a background reload must not change the visible scope',
      );

      // Same contract as ToolHandlerService.onMutated: a write for one
      // assistant must not collapse an open global listing.
      await memoryRepository.create(
        scope: MemoryScope.assistant,
        assistantId: 'a1',
        type: MemoryType.identity,
        content: 'Another a1 fact.',
        source: MemorySource.tool,
      );
      await memoryV2.reloadCurrentScope();
      expect(memoryV2.entries, hasLength(3));
      expect(
        memoryV2.entries.any((e) => e.assistantId == 'a2'),
        isTrue,
        reason: 'a1 tool writes must leave a2 entries visible',
      );
    });
  });

  group('processWindow watermark + short-circuit', () {
    test('Gatekeeper false advances watermark and skips Extract', () async {
      await seedAssistant('a1');
      final convo = await chatService.createConversation(
        title: 't',
        assistantId: 'a1',
      );
      expect(convo.lastMemoryExtractedOrder, -1);

      var calls = 0;
      final result = await pipeline.processWindow(
        conversationId: convo.id,
        assistant: assistant(),
        settings: settings,
        watermark: -1,
        window: sampleWindow(conversationId: convo.id, endOrder: 5),
        llmCall: (prompt) async {
          calls++;
          expect(prompt, contains('分析以下对话'));
          return '<gate><user_memory>false</user_memory></gate>';
        },
      );
      expect(result.advanced, isTrue);
      expect(result.gate, MemoryGateParseResult.skip);
      expect(calls, 1); // no Extract
      expect(convo.lastMemoryExtractedOrder, 5);
    });

    test('Gatekeeper malformed does not advance', () async {
      await seedAssistant('a1');
      final convo = await chatService.createConversation(
        title: 't',
        assistantId: 'a1',
      );
      final result = await pipeline.processWindow(
        conversationId: convo.id,
        assistant: assistant(),
        settings: settings,
        watermark: -1,
        window: sampleWindow(conversationId: convo.id, endOrder: 2),
        llmCall: (_) async => '???',
      );
      expect(result.advanced, isFalse);
      expect(result.gate, MemoryGateParseResult.malformed);
      expect(convo.lastMemoryExtractedOrder, -1);
    });

    test('Extract malformed does not advance', () async {
      await seedAssistant('a1');
      final convo = await chatService.createConversation(
        title: 't',
        assistantId: 'a1',
      );
      var step = 0;
      final result = await pipeline.processWindow(
        conversationId: convo.id,
        assistant: assistant(),
        settings: settings,
        watermark: -1,
        window: sampleWindow(conversationId: convo.id, endOrder: 4),
        llmCall: (_) async {
          step++;
          if (step == 1) {
            return '<gate><user_memory>true</user_memory></gate>';
          }
          return 'no extracted tag';
        },
      );
      expect(result.advanced, isFalse);
      expect(result.error, 'extract_parse_failed');
      expect(convo.lastMemoryExtractedOrder, -1);
    });

    test('successful extract + smart add advances watermark', () async {
      await seedAssistant('a1');
      final convo = await chatService.createConversation(
        title: 't',
        assistantId: 'a1',
      );
      var step = 0;
      final result = await pipeline.processWindow(
        conversationId: convo.id,
        assistant: assistant(mode: MemorySmartAddMode.perItem),
        settings: settings,
        watermark: -1,
        window: sampleWindow(conversationId: convo.id, endOrder: 7),
        llmCall: (prompt) async {
          step++;
          if (step == 1) {
            return '<gate><user_memory>true</user_memory></gate>';
          }
          if (step == 2) {
            return '''
<extracted>
<item type="identity">用户是大学生，学习软件工程。</item>
</extracted>
''';
          }
          // Smart Add per-item
          return jsonEncode({
            'action': 'NEW',
            'targetId': null,
            'mergedContent': null,
            'relatedIds': <String>[],
          });
        },
      );
      expect(result.advanced, isTrue);
      expect(result.extractedCount, 1);
      expect(convo.lastMemoryExtractedOrder, 7);
      final entries = await chatRepository.queryVisibleMemories(
        assistantId: 'a1',
        type: MemoryType.identity,
      );
      expect(entries, isNotEmpty);
      expect(entries.first.source, MemorySource.extracted);
    });

    test('user prompt override is used for Gatekeeper', () async {
      await seedAssistant('a1');
      await settings.setMemoryGatePromptZh('OVERRIDE-GATE {{conversation}}');
      final convo = await chatService.createConversation(
        title: 't',
        assistantId: 'a1',
      );
      String? seen;
      await pipeline.processWindow(
        conversationId: convo.id,
        assistant: assistant(),
        settings: settings,
        watermark: -1,
        window: sampleWindow(conversationId: convo.id),
        llmCall: (prompt) async {
          seen = prompt;
          return '<gate><user_memory>false</user_memory></gate>';
        },
      );
      expect(seen, startsWith('OVERRIDE-GATE '));
      expect(seen, isNot(contains(MemoryPrompts.gateZh.substring(0, 8))));
    });
  });

  group('Distiller parse malformed fails cleanly', () {
    test('bad distiller JSON does not throw and still advances', () async {
      await seedAssistant('a1');
      final convo = await chatService.createConversation(
        title: 't',
        assistantId: 'a1',
      );
      var step = 0;
      final result = await pipeline.processWindow(
        conversationId: convo.id,
        assistant: assistant(mode: MemorySmartAddMode.perItem),
        settings: settings,
        watermark: -1,
        window: sampleWindow(conversationId: convo.id, endOrder: 9),
        llmCall: (_) async {
          step++;
          if (step == 1) {
            return '<gate><user_memory>true</user_memory></gate>';
          }
          if (step == 2) {
            return '<extracted><item type="identity">用户希望被称为小明。</item></extracted>';
          }
          if (step == 3) {
            return jsonEncode({'action': 'NEW', 'relatedIds': <String>[]});
          }
          // Distiller
          return 'not-json';
        },
      );
      expect(result.advanced, isTrue);
      expect(convo.lastMemoryExtractedOrder, 9);
    });
  });
}
