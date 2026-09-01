import 'dart:convert';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/memory_entry.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/logging/context_log_models.dart';
import 'package:Kelivo/core/services/logging/context_logger.dart';
import 'package:Kelivo/core/services/memory/memory_block_builder.dart';
import 'package:Kelivo/core/services/memory/memory_prompts.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/ocr_service.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatService extends ChatService {
  _FakeChatService(this.persistedMessages);

  final List<ChatMessage> persistedMessages;

  @override
  List<ChatMessage> getMessages(String conversationId) {
    return persistedMessages
        .where((message) => message.conversationId == conversationId)
        .toList();
  }
}

class _CountingPromptRepository extends ChatDatabaseRepository {
  _CountingPromptRepository(super.database);

  int singlePromptReads = 0;
  int batchPromptReads = 0;

  @override
  Future<MessagePromptRow?> getMessagePrompt(String revisionId) {
    singlePromptReads++;
    return super.getMessagePrompt(revisionId);
  }

  @override
  Future<Map<String, MessagePromptRow>> getMessagePrompts(
    Iterable<String> revisionIds,
  ) {
    batchPromptReads++;
    return super.getMessagePrompts(revisionIds);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late BusinessRepository businessRepository;
  late BusinessPreferences preferences;
  late ChatDatabaseRepository chatRepository;
  late SettingsProvider settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    businessRepository = BusinessRepository(database);
    preferences = BusinessPreferences(businessRepository);
    chatRepository = ChatDatabaseRepository(database);
    await chatRepository.ensureReady();
    await preferences.load();
    settings = SettingsProvider(preferences);
    await settings.loaded;
    await settings.setMemoryPromptLang('zh');
  });

  tearDown(() async {
    await ContextLogger.setEnabled(false);
    await database.close();
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

  Future<void> putEntry({
    required String id,
    required String content,
    MemoryType type = MemoryType.identity,
    MemoryScope scope = MemoryScope.global,
    String? assistantId,
  }) {
    final created = DateTime.utc(2026, 8, 1).microsecondsSinceEpoch;
    return businessRepository.upsertEntity(
      BusinessEntityKind.memoryEntry,
      BusinessEntityValue(
        id: id,
        sortOrder: 0,
        payload: jsonEncode({
          'id': id,
          'scope': MemoryEntry.scopeToString(scope),
          'assistantId': assistantId,
          'type': MemoryEntry.typeToString(type),
          'status': 'active',
          'content': content,
          'source': 'manual',
          'relatedIds': <String>[],
          'createdAt': created,
          'updatedAt': created,
        }),
      ),
    );
  }

  Future<Conversation> seedConversation(
    String id, {
    String? injectedMemoryHash,
  }) async {
    final conversation = Conversation(
      id: id,
      title: id,
      injectedMemoryHash: injectedMemoryHash,
    );
    await chatRepository.putConversation(conversation);
    return conversation;
  }

  Future<ChatMessage> seedUserMessage({
    required String id,
    required String conversationId,
    String content = 'hi',
    List<MessagePart>? parts,
    DateTime? timestamp,
    int? messageOrder,
  }) async {
    final message = ChatMessage(
      id: id,
      role: 'user',
      content: content,
      parts: parts,
      conversationId: conversationId,
      timestamp: timestamp,
    );
    await chatRepository.putMessage(message, messageOrder: messageOrder);
    return message;
  }

  MessageBuilderService buildService({
    List<ChatMessage> messages = const [],
    ChatDatabaseRepository? repository,
    Future<String?> Function(
      List<String> imagePaths, {
      String? revisionId,
      OcrPrepareSession? session,
      String? requestId,
    })?
    ocrHandler,
    Future<OcrPrepareSession> Function({
      required List<String> revisionIds,
      required List<String> imagePaths,
    })?
    ocrPrefetch,
  }) {
    return MessageBuilderService(
      chatService: _FakeChatService(messages),
      contextProvider: _FakeBuildContext(),
      chatRepository: repository ?? chatRepository,
      ocrHandler: ocrHandler,
      ocrPrefetch: ocrPrefetch,
    );
  }

  const assistant = Assistant(
    id: 'assistant-1',
    name: 'Test',
    enableMemory: true,
    messageTemplate: '{{ message }}',
  );

  group('§18.1 item 6 — §7.6 decision table', () {
    test('enableMemory off returns empty and writes nothing', () async {
      await seedAssistant('assistant-1');
      await putEntry(id: 'mem_01', content: 'User likes Flutter.');
      final conversation = await seedConversation('conv-1');
      final service = buildService();

      final result = await service.resolveMemoryPrefix(
        conversation: conversation,
        assistant: assistant.copyWith(enableMemory: false),
        apiMessages: const [],
        currentMessageId: 'u-new',
        lang: MemoryPromptLang.zh,
      );

      expect(result.prefix, isEmpty);
      expect(result.hash, isNull);
      expect(conversation.injectedMemoryHash, isNull);
    });

    test(
      'empty profile and visible set returns empty without writing hash',
      () async {
        await seedAssistant('assistant-1');
        final conversation = await seedConversation('conv-1');
        final service = buildService();

        final result = await service.resolveMemoryPrefix(
          conversation: conversation,
          assistant: assistant,
          apiMessages: const [],
          currentMessageId: 'u-new',
          lang: MemoryPromptLang.zh,
        );

        expect(result.prefix, isEmpty);
        expect(result.hash, isNull);
        expect(conversation.injectedMemoryHash, isNull);
      },
    );

    test('no snapshot in history → full snapshot', () async {
      await seedAssistant('assistant-1');
      await putEntry(id: 'mem_01', content: 'User likes Flutter.');
      final conversation = await seedConversation('conv-1');
      await seedUserMessage(id: 'u1', conversationId: 'conv-1');
      await seedUserMessage(
        id: 'u-new',
        conversationId: 'conv-1',
        content: 'next',
        messageOrder: 1,
      );
      final service = buildService();
      final apiMessages = [
        {
          'role': 'user',
          'content': 'hi',
          MessageBuilderService.internalRevisionIdKey: 'u1',
        },
        {'role': 'assistant', 'content': 'hello'},
        {
          'role': 'user',
          'content': 'next',
          MessageBuilderService.internalRevisionIdKey: 'u-new',
        },
      ];

      final result = await service.resolveMemoryPrefix(
        conversation: conversation,
        assistant: assistant,
        apiMessages: apiMessages,
        currentMessageId: 'u-new',
        lang: MemoryPromptLang.zh,
      );

      expect(result.prefix, contains(MemoryPrompts.introFullZh));
      expect(result.prefix, contains('<user_memory type="identity">'));
      expect(result.prefix, isNot(contains('<user_memory_update>')));
      expect(result.hash, isNotNull);
    });

    test('has snapshot + same hash → empty', () async {
      await seedAssistant('assistant-1');
      await putEntry(id: 'mem_01', content: 'User likes Flutter.');
      final fields = await chatRepository.readProfileFields();
      final visible = await chatRepository.queryVisibleMemories(
        assistantId: 'assistant-1',
      );
      final totals = await chatRepository.countVisibleMemoriesByType(
        assistantId: 'assistant-1',
      );
      final profileBlock = MemoryBlockBuilder.buildProfileBlock(
        fields: fields,
        lang: MemoryPromptLang.zh,
      );
      final memoryBlock = MemoryBlockBuilder.buildMemoryBlock(
        visible: visible,
        totalByType: totals,
        lang: MemoryPromptLang.zh,
        maxItems: 10,
      );
      final hash = MemoryBlockBuilder.hashBlocks(profileBlock, memoryBlock);

      final conversation = await seedConversation(
        'conv-1',
        injectedMemoryHash: hash,
      );
      await seedUserMessage(id: 'u1', conversationId: 'conv-1');
      await seedUserMessage(
        id: 'u-new',
        conversationId: 'conv-1',
        content: 'next',
        messageOrder: 1,
      );
      await chatRepository.freezeMessagePrompt(
        revisionId: 'u1',
        conversationId: 'conv-1',
        payload: 'frozen',
        carriesMemorySnapshot: true,
        injectedMemoryHash: Value(hash),
      );

      final service = buildService();
      final apiMessages = [
        {
          'role': 'user',
          'content': 'hi',
          MessageBuilderService.internalRevisionIdKey: 'u1',
        },
        {
          'role': 'user',
          'content': 'next',
          MessageBuilderService.internalRevisionIdKey: 'u-new',
        },
      ];

      final result = await service.resolveMemoryPrefix(
        conversation: conversation,
        assistant: assistant,
        apiMessages: apiMessages,
        currentMessageId: 'u-new',
        lang: MemoryPromptLang.zh,
      );

      expect(result.prefix, isEmpty);
      expect(result.hash, isNull);
    });

    test('has snapshot + different hash → full snapshot', () async {
      await seedAssistant('assistant-1');
      await putEntry(id: 'mem_01', content: 'User likes Flutter.');
      final conversation = await seedConversation(
        'conv-1',
        injectedMemoryHash: 'oldhash012345678',
      );
      await seedUserMessage(id: 'u1', conversationId: 'conv-1');
      await seedUserMessage(
        id: 'u-new',
        conversationId: 'conv-1',
        content: 'next',
        messageOrder: 1,
      );
      await chatRepository.freezeMessagePrompt(
        revisionId: 'u1',
        conversationId: 'conv-1',
        payload: 'frozen-old',
        carriesMemorySnapshot: true,
        injectedMemoryHash: Value('oldhash012345678'),
      );

      final service = buildService();
      final apiMessages = [
        {
          'role': 'user',
          'content': 'hi',
          MessageBuilderService.internalRevisionIdKey: 'u1',
        },
        {
          'role': 'user',
          'content': 'next',
          MessageBuilderService.internalRevisionIdKey: 'u-new',
        },
      ];

      final result = await service.resolveMemoryPrefix(
        conversation: conversation,
        assistant: assistant,
        apiMessages: apiMessages,
        currentMessageId: 'u-new',
        lang: MemoryPromptLang.zh,
      );

      expect(result.prefix, contains(MemoryPrompts.introFullZh));
      expect(result.prefix, isNot(contains('<user_memory_update>')));
      expect(result.persistHash, isTrue);
      expect(result.hash, isNotNull);
      expect(result.hash, isNot('oldhash012345678'));
    });

    test('deleting the last memory clears the hash, injects nothing', () async {
      await seedAssistant('assistant-1');
      await putEntry(id: 'mem_01', content: 'User likes Flutter.');
      final conversation = await seedConversation('conv-1');
      await seedUserMessage(id: 'u1', conversationId: 'conv-1');
      await seedUserMessage(
        id: 'u-new',
        conversationId: 'conv-1',
        content: 'next',
        messageOrder: 1,
      );
      final service = buildService();
      final first = await service.resolveMemoryPrefix(
        conversation: conversation,
        assistant: assistant,
        apiMessages: [
          {
            'role': 'user',
            'content': 'hi',
            MessageBuilderService.internalRevisionIdKey: 'u1',
          },
        ],
        currentMessageId: 'u1',
        lang: MemoryPromptLang.zh,
      );
      await chatRepository.freezeMessagePrompt(
        revisionId: 'u1',
        conversationId: 'conv-1',
        payload: '${first.prefix}hi',
        carriesMemorySnapshot: true,
        injectedMemoryHash: Value(first.hash),
      );

      await businessRepository.deleteEntity(
        BusinessEntityKind.memoryEntry,
        'mem_01',
      );
      final cleared = await service.resolveMemoryPrefix(
        conversation: conversation,
        assistant: assistant,
        apiMessages: [
          {
            'role': 'user',
            'content': 'hi',
            MessageBuilderService.internalRevisionIdKey: 'u1',
          },
          {
            'role': 'user',
            'content': 'next',
            MessageBuilderService.internalRevisionIdKey: 'u-new',
          },
        ],
        currentMessageId: 'u-new',
        lang: MemoryPromptLang.zh,
      );

      // The stale snapshot on u1 is dropped at send time instead of being
      // corrected by an empty update block, so nothing is injected here — but
      // the conversation must record that its context now carries none.
      expect(cleared.prefix, isEmpty);
      expect(cleared.persistHash, isTrue);
      expect(cleared.hash, isNull);
      expect(
        await chatRepository.getConversationInjectedMemoryHash('conv-1'),
        isNotNull,
        reason: 'the first turn recorded its snapshot',
      );
    });

    test(
      'the prior hash is read from the database, not from the model',
      () async {
        // Callers pass `conversation.copyWith(...)` and nothing ever loads this
        // column back into the model, so a stale copy must not be trusted:
        // doing so makes every turn look like a change and re-sends the same
        // update block forever.
        await seedAssistant('assistant-1');
        await putEntry(id: 'mem_01', content: 'User likes Flutter.');
        final fields = await chatRepository.readProfileFields();
        final visible = await chatRepository.queryVisibleMemories(
          assistantId: 'assistant-1',
        );
        final totals = await chatRepository.countVisibleMemoriesByType(
          assistantId: 'assistant-1',
        );
        final hash = MemoryBlockBuilder.hashBlocks(
          MemoryBlockBuilder.buildProfileBlock(
            fields: fields,
            lang: MemoryPromptLang.zh,
          ),
          MemoryBlockBuilder.buildMemoryBlock(
            visible: visible,
            totalByType: totals,
            lang: MemoryPromptLang.zh,
            maxItems: 10,
          ),
        );

        await seedConversation('conv-1');
        await seedUserMessage(id: 'u1', conversationId: 'conv-1');
        await seedUserMessage(
          id: 'u-new',
          conversationId: 'conv-1',
          content: 'next',
          messageOrder: 1,
        );
        await chatRepository.freezeMessagePrompt(
          revisionId: 'u1',
          conversationId: 'conv-1',
          payload: 'frozen',
          carriesMemorySnapshot: true,
          injectedMemoryHash: Value(hash),
        );

        // The model still carries the pre-freeze value.
        final staleConversation = Conversation(id: 'conv-1', title: 'conv-1');
        expect(staleConversation.injectedMemoryHash, isNull);

        final apiMessages = [
          {
            'role': 'user',
            'content': 'hi',
            MessageBuilderService.internalRevisionIdKey: 'u1',
          },
          {
            'role': 'user',
            'content': 'next',
            MessageBuilderService.internalRevisionIdKey: 'u-new',
          },
        ];
        final result = await buildService().resolveMemoryPrefix(
          conversation: staleConversation,
          assistant: assistant,
          apiMessages: apiMessages,
          currentMessageId: 'u-new',
          lang: MemoryPromptLang.zh,
        );

        expect(result.prefix, isEmpty);
        expect(result.hash, isNull);
      },
    );

    test(
      'a hash injected earlier in the same request is not re-injected',
      () async {
        // Temporary conversations never reach the database, so the prior hash
        // has to come from the request itself. Without that, every message
        // after the first repeats a byte-identical update block.
        await seedAssistant('assistant-1');
        await putEntry(id: 'mem_01', content: 'User likes Flutter.');
        final conversation = await seedConversation('conv-1');
        await seedUserMessage(id: 'u1', conversationId: 'conv-1');
        await seedUserMessage(
          id: 'u2',
          conversationId: 'conv-1',
          content: 'next',
          messageOrder: 1,
        );

        final service = buildService();
        final apiMessages = [
          {
            'role': 'user',
            'content': 'hi',
            MessageBuilderService.internalRevisionIdKey: 'u1',
          },
          {
            'role': 'user',
            'content': 'next',
            MessageBuilderService.internalRevisionIdKey: 'u2',
          },
        ];
        final pass = MemoryInjectionPass();

        final first = await service.resolveMemoryPrefix(
          conversation: conversation,
          assistant: assistant,
          apiMessages: apiMessages,
          currentMessageId: 'u1',
          lang: MemoryPromptLang.zh,
          pass: pass,
        );
        pass.snapshotCarriers.add('u1');

        final second = await service.resolveMemoryPrefix(
          conversation: conversation,
          assistant: assistant,
          apiMessages: apiMessages,
          currentMessageId: 'u2',
          lang: MemoryPromptLang.zh,
          pass: pass,
        );

        expect(first.prefix, contains(MemoryPrompts.introFullZh));
        expect(second.prefix, isEmpty);
        expect(second.hash, isNull);
      },
    );
  });

  group('hash ordering regression (appendix item 6)', () {
    test(
      'compares prior hash before writing — the change is not swallowed',
      () async {
        await seedAssistant('assistant-1');
        await putEntry(id: 'mem_01', content: 'Original content.');
        final fields = await chatRepository.readProfileFields();
        final visible = await chatRepository.queryVisibleMemories(
          assistantId: 'assistant-1',
        );
        final totals = await chatRepository.countVisibleMemoriesByType(
          assistantId: 'assistant-1',
        );
        final oldHash = MemoryBlockBuilder.hashBlocks(
          MemoryBlockBuilder.buildProfileBlock(
            fields: fields,
            lang: MemoryPromptLang.zh,
          ),
          MemoryBlockBuilder.buildMemoryBlock(
            visible: visible,
            totalByType: totals,
            lang: MemoryPromptLang.zh,
            maxItems: 10,
          ),
        );

        final conversation = await seedConversation(
          'conv-1',
          injectedMemoryHash: oldHash,
        );
        await seedUserMessage(id: 'u1', conversationId: 'conv-1');
        await seedUserMessage(
          id: 'u-new',
          conversationId: 'conv-1',
          content: 'next',
          messageOrder: 1,
        );
        await chatRepository.freezeMessagePrompt(
          revisionId: 'u1',
          conversationId: 'conv-1',
          payload: 'snap',
          carriesMemorySnapshot: true,
          injectedMemoryHash: Value(oldHash),
        );

        // Change memory so currentHash != oldHash.
        await putEntry(
          id: 'mem_01',
          content: 'Changed content that alters hash.',
        );

        final service = buildService();
        final apiMessages = [
          {
            'role': 'user',
            'content': 'hi',
            MessageBuilderService.internalRevisionIdKey: 'u1',
          },
          {
            'role': 'user',
            'content': 'next',
            MessageBuilderService.internalRevisionIdKey: 'u-new',
          },
        ];

        // If someone writes conversation.injectedMemoryHash = currentHash BEFORE
        // comparing, this returns '' and the model never sees the change.
        final result = await service.resolveMemoryPrefix(
          conversation: conversation,
          assistant: assistant,
          apiMessages: apiMessages,
          currentMessageId: 'u-new',
          lang: MemoryPromptLang.zh,
        );

        expect(
          result.prefix,
          contains(MemoryPrompts.introFullZh),
          reason:
              'Writing injectedMemoryHash before comparing makes the change '
              'branch unreachable (appendix item 6).',
        );
        expect(result.prefix, contains('Changed content that alters hash.'));
        expect(result.hash, isNot(oldHash));
      },
    );
  });

  group('§18.4 item 29 — promptContent immutability', () {
    test(
      'building the same message twice returns identical bytes; retry matches',
      () async {
        await seedAssistant('assistant-1');
        await putEntry(id: 'mem_01', content: 'User likes Flutter.');

        final ts = DateTime(2026, 8, 7, 14, 3, 22);
        final conversation = await seedConversation('conv-1');
        final message = await seedUserMessage(
          id: 'u1',
          conversationId: 'conv-1',
          content: 'hello world',
          timestamp: ts,
        );
        final service = buildService(messages: [message]);
        final apiMessages = <Map<String, dynamic>>[
          {
            'role': 'user',
            'content': 'hello world',
            MessageBuilderService.internalRevisionIdKey: 'u1',
          },
        ];

        final first = await service.resolvePromptContent(
          message: message,
          processedUserBody: 'hello world',
          assistant: assistant.copyWith(appendCurrentTimeToUserMessage: true),
          conversation: conversation,
          settings: settings,
          apiMessages: apiMessages,
        );
        final second = await service.resolvePromptContent(
          message: message,
          processedUserBody: 'hello world CHANGED',
          assistant: assistant.copyWith(
            appendCurrentTimeToUserMessage: true,
            messageTemplate: 'IGNORE {{ message }}',
          ),
          conversation: conversation,
          settings: settings,
          apiMessages: apiMessages,
        );
        // Retry path: same frozen row.
        final retry = await service.resolvePromptContent(
          message: message,
          processedUserBody: 'retry body',
          assistant: assistant,
          conversation: conversation,
          settings: settings,
          apiMessages: apiMessages,
        );

        expect(second, first);
        expect(retry, first);
        expect(first, contains('hello world'));
        expect(first, contains(MemoryPrompts.formatCurrentTimeTag(ts)));
        expect(first, contains('<user_memory type="identity">'));
      },
    );

    test(
      'first message of a fresh conversation gets the snapshot even when the '
      'chat cache is empty',
      () async {
        // ChatService only serves conversations already in its cache, so on a
        // brand new conversation the lookup misses. Falling back to an
        // unfrozen render silently dropped memory from the first turn, then
        // added it a turn later — rewriting history and losing the cache.
        await seedAssistant('assistant-1');
        await putEntry(id: 'mem_01', content: 'User likes Flutter.');

        final conversation = await seedConversation('conv-fresh');
        final message = await seedUserMessage(
          id: 'u1',
          conversationId: 'conv-fresh',
          content: 'what is my name',
        );

        // Empty cache, exactly as for a conversation created this turn.
        final service = buildService();
        final apiMessages = <Map<String, dynamic>>[
          {
            'role': 'user',
            'content': 'what is my name',
            MessageBuilderService.internalRevisionIdKey: 'u1',
          },
        ];

        await service.processUserMessagesForApi(
          apiMessages,
          settings,
          assistant,
          conversation: conversation,
          sourceMessages: [message],
        );

        final content = apiMessages.single['content'] as String;
        expect(content, contains(MemoryPrompts.introFullZh));
        expect(content, contains('<user_memory type="identity">'));
        expect(content, endsWith('what is my name'));

        // And it is frozen, so the next turn replays the same bytes.
        final frozen = await chatRepository.getMessagePrompt('u1');
        expect(frozen, isNotNull);
        expect(frozen!.payload, content);
        expect(frozen.carriesMemorySnapshot, isTrue);
      },
    );

    test(
      'failed OCR is retried instead of freezing an incomplete prompt',
      () async {
        await seedAssistant('assistant-1');
        final conversation = await seedConversation('conv-ocr-retry');
        final message = await seedUserMessage(
          id: 'u1',
          conversationId: conversation.id,
          parts: const [
            TextPart('describe this'),
            ImagePart(uri: '/tmp/retry.png', mime: 'image/png'),
          ],
        );
        await settings.setOcrModel('ocr-provider', 'ocr-model');
        await settings.setOcrEnabled(true);

        var ocrCalls = 0;
        final service = buildService(
          messages: [message],
          ocrHandler: (imagePaths, {revisionId, session, requestId}) async {
            ocrCalls++;
            return ocrCalls == 1 ? null : 'recognized image';
          },
        );

        List<Map<String, dynamic>> apiMessages() => [
          {
            'role': 'user',
            'content': message.content,
            MessageBuilderService.internalRevisionIdKey: message.id,
          },
        ];

        final first = apiMessages();
        await service.processUserMessagesForApi(
          first,
          settings,
          assistant,
          conversation: conversation,
          sourceMessages: [message],
        );
        expect(await chatRepository.getMessagePrompt(message.id), isNull);

        final retry = apiMessages();
        await service.processUserMessagesForApi(
          retry,
          settings,
          assistant,
          conversation: conversation,
          sourceMessages: [message],
        );

        expect(ocrCalls, 2);
        expect(retry.single['content'], contains('recognized image'));
        expect(
          (await chatRepository.getMessagePrompt(message.id))?.payload,
          retry.single['content'],
        );
      },
    );

    test(
      'cancelled OCR does not freeze the prompt or continue later messages',
      () async {
        await seedAssistant('assistant-1');
        final conversation = await seedConversation('conv-ocr-cancel');
        final first = await seedUserMessage(
          id: 'u1',
          conversationId: conversation.id,
          parts: const [
            TextPart('first'),
            ImagePart(uri: '/tmp/first.png', mime: 'image/png'),
          ],
        );
        final second = await seedUserMessage(
          id: 'u2',
          conversationId: conversation.id,
          parts: const [
            TextPart('second'),
            ImagePart(uri: '/tmp/second.png', mime: 'image/png'),
          ],
          messageOrder: 1,
        );
        await settings.setOcrModel('ocr-provider', 'ocr-model');
        await settings.setOcrEnabled(true);

        final ocrCalls = <String?>[];
        final service = buildService(
          messages: [first, second],
          ocrHandler: (imagePaths, {revisionId, session, requestId}) async {
            ocrCalls.add(revisionId);
            if (revisionId == first.id) return 'ocr-first';
            throw http.ClientException('cancelled');
          },
        );

        final apiMessages = <Map<String, dynamic>>[
          {
            'role': 'user',
            'content': first.content,
            MessageBuilderService.internalRevisionIdKey: first.id,
          },
          {
            'role': 'user',
            'content': second.content,
            MessageBuilderService.internalRevisionIdKey: second.id,
          },
        ];

        await expectLater(
          service.processUserMessagesForApi(
            apiMessages,
            settings,
            assistant,
            conversation: conversation,
            sourceMessages: [first, second],
          ),
          throwsA(isA<http.ClientException>()),
        );

        expect(ocrCalls, [first.id, second.id]);
        expect(await chatRepository.getMessagePrompt(second.id), isNull);
      },
    );

    test('frozen prompts are batch-read once and reused by OCR', () async {
      await seedAssistant('assistant-1');
      final conversation = await seedConversation('conv-batch');
      final first = await seedUserMessage(
        id: 'u1',
        conversationId: 'conv-batch',
        parts: const [
          TextPart('first'),
          ImagePart(uri: '/tmp/first.png', mime: 'image/png'),
        ],
      );
      final second = await seedUserMessage(
        id: 'u2',
        conversationId: 'conv-batch',
        parts: const [
          TextPart('second'),
          ImagePart(uri: '/tmp/second.png', mime: 'image/png'),
        ],
        messageOrder: 1,
      );
      await chatRepository.putMessagePrompt(
        revisionId: 'u1',
        conversationId: 'conv-batch',
        payload: 'frozen first',
        carriesMemorySnapshot: false,
      );
      await chatRepository.putMessagePrompt(
        revisionId: 'u2',
        conversationId: 'conv-batch',
        payload: 'frozen second',
        carriesMemorySnapshot: false,
      );
      await settings.setProviderConfig(
        'ocr-provider',
        ProviderConfig(
          id: 'ocr-provider',
          enabled: true,
          name: 'OCR',
          apiKey: 'key',
          baseUrl: 'https://example.test',
          models: const ['ocr-model'],
          modelOverrides: const {
            'ocr-model': {
              'input': ['text', 'image'],
            },
          },
        ),
      );
      await settings.setOcrModel('ocr-provider', 'ocr-model');
      await settings.setOcrEnabled(true);

      final countingRepository = _CountingPromptRepository(database);
      var ocrPrefetchCalls = 0;
      final service = buildService(
        messages: [first, second],
        repository: countingRepository,
        ocrPrefetch: ({required revisionIds, required imagePaths}) async {
          ocrPrefetchCalls++;
          return OcrPrepareSession();
        },
      );
      final apiMessages = <Map<String, dynamic>>[
        {
          'role': 'user',
          'content': first.content,
          MessageBuilderService.internalRevisionIdKey: first.id,
        },
        {
          'role': 'user',
          'content': second.content,
          MessageBuilderService.internalRevisionIdKey: second.id,
        },
      ];

      await service.processUserMessagesForApi(
        apiMessages,
        settings,
        assistant,
        conversation: conversation,
        sourceMessages: [first, second],
      );

      expect(apiMessages.map((message) => message['content']), [
        'frozen first',
        'frozen second',
      ]);
      expect(countingRepository.batchPromptReads, 1);
      expect(countingRepository.singlePromptReads, 0);
      expect(ocrPrefetchCalls, 0);
    });

    test(
      'frozen carriesMemorySnapshot splits prefix from the user turn',
      () async {
        await seedAssistant('assistant-1');
        await putEntry(id: 'mem_01', content: 'User likes Flutter.');
        final conversation = await seedConversation('conv-frozen-tag');
        final message = await seedUserMessage(
          id: 'u1',
          conversationId: 'conv-frozen-tag',
          content: 'hello',
        );
        final profileBlock = MemoryBlockBuilder.buildProfileBlock(
          fields: await chatRepository.readProfileFields(),
          lang: MemoryPromptLang.zh,
        );
        final memoryBlock = MemoryBlockBuilder.buildMemoryBlock(
          visible: await chatRepository.queryVisibleMemories(
            assistantId: 'assistant-1',
          ),
          totalByType: await chatRepository.countVisibleMemoriesByType(
            assistantId: 'assistant-1',
          ),
          lang: MemoryPromptLang.zh,
          maxItems: 10,
        );
        final prefix = MemoryBlockBuilder.buildFullSnapshotPrefix(
          profileBlock,
          memoryBlock,
          MemoryPromptLang.zh,
        );
        final payload = '${prefix}hello';
        await chatRepository.freezeMessagePrompt(
          revisionId: 'u1',
          conversationId: 'conv-frozen-tag',
          payload: payload,
          carriesMemorySnapshot: true,
          injectedMemoryHash: Value(
            MemoryBlockBuilder.hashBlocks(profileBlock, memoryBlock),
          ),
        );

        await ContextLogger.setEnabled(true);
        addTearDown(() => ContextLogger.setEnabled(false));

        final service = buildService(messages: [message]);
        final apiMessages = <Map<String, dynamic>>[
          {
            'role': 'user',
            'content': 'hello',
            MessageBuilderService.internalRevisionIdKey: 'u1',
          },
        ];
        await service.processUserMessagesForApi(
          apiMessages,
          settings,
          assistant,
          conversation: conversation,
          sourceMessages: [message],
        );

        expect(apiMessages.single['content'], payload);
        final tags = ContextSegmentTags.read(apiMessages.single);
        expect(tags, hasLength(2));
        expect(tags[0]['source'], ContextSource.memorySnapshot.wireName);
        expect(tags[0]['length'], prefix.length);
        expect(tags[0]['meta']?['kind'], 'full');
        expect(tags[1]['source'], ContextSource.chatHistory.wireName);
        expect(tags[1]['length'], 'hello'.length);
      },
    );
  });

  group('superseded snapshots are stripped from history', () {
    test(
      'memories moved to another assistant stop replaying in this one',
      () async {
        // The reported bug: memories were global when this conversation took
        // its snapshot, the user then scoped them to a different assistant, and
        // the frozen snapshot kept handing them back on every later turn.
        await seedAssistant('assistant-1');
        await seedAssistant('assistant-2');
        await putEntry(id: 'mem_01', content: 'User likes Flutter.');

        final conversation = await seedConversation('conv-2');
        final u1 = await seedUserMessage(id: 'u1', conversationId: 'conv-2');
        final assistant2 = assistant.copyWith(id: 'assistant-2');
        final firstTurn = <Map<String, dynamic>>[
          {
            'role': 'user',
            'content': 'hi',
            MessageBuilderService.internalRevisionIdKey: 'u1',
          },
        ];
        await buildService(messages: [u1]).processUserMessagesForApi(
          firstTurn,
          settings,
          assistant2,
          conversation: conversation,
          sourceMessages: [u1],
        );
        expect(firstTurn.single['content'], contains('User likes Flutter.'));

        // Scope the memory to assistant-1 only.
        await putEntry(
          id: 'mem_01',
          content: 'User likes Flutter.',
          scope: MemoryScope.assistant,
          assistantId: 'assistant-1',
        );

        final u2 = await seedUserMessage(
          id: 'u2',
          conversationId: 'conv-2',
          content: 'next',
          messageOrder: 1,
        );
        final secondTurn = <Map<String, dynamic>>[
          {
            'role': 'user',
            'content': 'hi',
            MessageBuilderService.internalRevisionIdKey: 'u1',
          },
          {'role': 'assistant', 'content': 'hello'},
          {
            'role': 'user',
            'content': 'next',
            MessageBuilderService.internalRevisionIdKey: 'u2',
          },
        ];
        await buildService(messages: [u1, u2]).processUserMessagesForApi(
          secondTurn,
          settings,
          assistant2,
          conversation: conversation,
          sourceMessages: [u1, u2],
        );

        final sent = secondTurn.map((m) => m['content'].toString()).join('\n');
        expect(sent, isNot(contains('User likes Flutter.')));
        expect(sent, isNot(contains('<user_profile/>')));
        expect(sent, isNot(contains(MemoryPrompts.introFullZh)));
        expect(secondTurn.first['content'], 'hi');
        expect(
          await chatRepository.getConversationInjectedMemoryHash('conv-2'),
          isNull,
          reason: 'the context no longer carries a snapshot',
        );

        // The freeze row still records what was actually sent that turn.
        final frozen = await chatRepository.getMessagePrompt('u1');
        expect(frozen?.payload, contains('User likes Flutter.'));
        expect(frozen?.carriesMemorySnapshot, isTrue);
      },
    );

    test('only the newest snapshot survives into the request', () async {
      await seedAssistant('assistant-1');
      await putEntry(id: 'mem_01', content: 'User likes Flutter.');

      final conversation = await seedConversation('conv-1');
      final u1 = await seedUserMessage(id: 'u1', conversationId: 'conv-1');
      final u2 = await seedUserMessage(
        id: 'u2',
        conversationId: 'conv-1',
        content: 'again',
        messageOrder: 1,
      );
      final u3 = await seedUserMessage(
        id: 'u3',
        conversationId: 'conv-1',
        content: 'third',
        messageOrder: 2,
      );

      final profileBlock = MemoryBlockBuilder.buildProfileBlock(
        fields: await chatRepository.readProfileFields(),
        lang: MemoryPromptLang.zh,
      );
      final memoryBlock = MemoryBlockBuilder.buildMemoryBlock(
        visible: await chatRepository.queryVisibleMemories(
          assistantId: 'assistant-1',
        ),
        totalByType: await chatRepository.countVisibleMemoriesByType(
          assistantId: 'assistant-1',
        ),
        lang: MemoryPromptLang.zh,
        maxItems: 10,
      );
      // u2 carries the snapshot the conversation's hash names; u1 carries an
      // older one that a previous version left frozen in history.
      final stale = MemoryBlockBuilder.buildFullSnapshotPrefix(
        profileBlock,
        '<user_memory type="identity">\n'
        '- [2026-08-01] stale entry\n'
        '</user_memory>\n'
        '<user_memory type="workflow"/>\n'
        '<user_memory type="voice"/>\n'
        '<user_memory type="instruction"/>\n',
        MemoryPromptLang.zh,
      );
      await chatRepository.freezeMessagePrompt(
        revisionId: 'u1',
        conversationId: 'conv-1',
        payload: '${stale}hi',
        carriesMemorySnapshot: true,
        injectedMemoryHash: const Value('stalehash0000001'),
      );
      await chatRepository.freezeMessagePrompt(
        revisionId: 'u2',
        conversationId: 'conv-1',
        payload:
            '${MemoryBlockBuilder.buildFullSnapshotPrefix(profileBlock, memoryBlock, MemoryPromptLang.zh)}again',
        carriesMemorySnapshot: true,
        injectedMemoryHash: Value(
          MemoryBlockBuilder.hashBlocks(profileBlock, memoryBlock),
        ),
      );

      final apiMessages = <Map<String, dynamic>>[
        {
          'role': 'user',
          'content': 'hi',
          MessageBuilderService.internalRevisionIdKey: 'u1',
        },
        {
          'role': 'user',
          'content': 'again',
          MessageBuilderService.internalRevisionIdKey: 'u2',
        },
        {
          'role': 'user',
          'content': 'third',
          MessageBuilderService.internalRevisionIdKey: 'u3',
        },
      ];
      await buildService(messages: [u1, u2, u3]).processUserMessagesForApi(
        apiMessages,
        settings,
        assistant,
        conversation: conversation,
        sourceMessages: [u1, u2, u3],
      );

      expect(apiMessages[0]['content'], 'hi');
      expect(apiMessages[1]['content'], contains('User likes Flutter.'));
      expect(apiMessages[2]['content'], 'third');
      final sent = apiMessages.map((m) => m['content'].toString()).join('\n');
      expect(sent, isNot(contains('stale entry')));
    });
  });

  group('regeneration and forged snapshots', () {
    // Snapshot + hash for whatever [assistantId] can currently see.
    Future<({String prefix, String hash})> currentSnapshot(
      String assistantId,
    ) async {
      final profileBlock = MemoryBlockBuilder.buildProfileBlock(
        fields: await chatRepository.readProfileFields(),
        lang: MemoryPromptLang.zh,
      );
      final memoryBlock = MemoryBlockBuilder.buildMemoryBlock(
        visible: await chatRepository.queryVisibleMemories(
          assistantId: assistantId,
        ),
        totalByType: await chatRepository.countVisibleMemoriesByType(
          assistantId: assistantId,
        ),
        lang: MemoryPromptLang.zh,
        maxItems: 10,
      );
      return (
        prefix: MemoryBlockBuilder.buildFullSnapshotPrefix(
          profileBlock,
          memoryBlock,
          MemoryPromptLang.zh,
        ),
        hash: MemoryBlockBuilder.hashBlocks(profileBlock, memoryBlock),
      );
    }

    test(
      'regenerating after a scope change drops the stale snapshot',
      () async {
        // Regeneration adds no user message, so nothing calls
        // resolveMemoryPrefix and the stored hash alone cannot say whether the
        // frozen snapshot is still accurate.
        await seedAssistant('assistant-1');
        await seedAssistant('assistant-2');
        await putEntry(id: 'mem_01', content: 'User likes Flutter.');
        final conversation = await seedConversation('conv-2');
        final u1 = await seedUserMessage(id: 'u1', conversationId: 'conv-2');
        final snapshot = await currentSnapshot('assistant-2');
        await chatRepository.freezeMessagePrompt(
          revisionId: 'u1',
          conversationId: 'conv-2',
          payload: '${snapshot.prefix}hi',
          carriesMemorySnapshot: true,
          injectedMemoryHash: Value(snapshot.hash),
        );

        await putEntry(
          id: 'mem_01',
          content: 'User likes Flutter.',
          scope: MemoryScope.assistant,
          assistantId: 'assistant-1',
        );

        final apiMessages = <Map<String, dynamic>>[
          {
            'role': 'user',
            'content': 'hi',
            MessageBuilderService.internalRevisionIdKey: 'u1',
          },
        ];
        await buildService(messages: [u1]).processUserMessagesForApi(
          apiMessages,
          settings,
          assistant.copyWith(id: 'assistant-2'),
          conversation: conversation,
          sourceMessages: [u1],
        );

        expect(apiMessages.single['content'], 'hi');
      },
    );

    test('regenerating after a memory is added refreshes in place', () async {
      // Stripping instead of refreshing would hand the regenerated reply no
      // memory at all, which the automatic memory pipeline would trigger
      // constantly.
      await seedAssistant('assistant-1');
      await putEntry(id: 'mem_01', content: 'User likes Flutter.');
      final conversation = await seedConversation('conv-1');
      final u1 = await seedUserMessage(id: 'u1', conversationId: 'conv-1');
      final snapshot = await currentSnapshot('assistant-1');
      await chatRepository.freezeMessagePrompt(
        revisionId: 'u1',
        conversationId: 'conv-1',
        payload: '${snapshot.prefix}hi',
        carriesMemorySnapshot: true,
        injectedMemoryHash: Value(snapshot.hash),
      );

      await putEntry(id: 'mem_02', content: 'User ships on Fridays.');

      final apiMessages = <Map<String, dynamic>>[
        {
          'role': 'user',
          'content': 'hi',
          MessageBuilderService.internalRevisionIdKey: 'u1',
        },
      ];
      await buildService(messages: [u1]).processUserMessagesForApi(
        apiMessages,
        settings,
        assistant,
        conversation: conversation,
        sourceMessages: [u1],
      );

      final sent = apiMessages.single['content'].toString();
      expect(sent, contains('User likes Flutter.'));
      expect(sent, contains('User ships on Fridays.'));
      expect(sent, endsWith('hi'));
      // Ephemeral: the stored hash keeps describing the freeze row, or the next
      // turn would believe the stale prefix is current.
      expect(
        await chatRepository.getConversationInjectedMemoryHash('conv-1'),
        snapshot.hash,
      );
      expect(
        (await chatRepository.getMessagePrompt('u1'))?.payload,
        '${snapshot.prefix}hi',
      );
    });

    test(
      'regenerating an earlier reply refreshes that turn\'s snapshot',
      () async {
        // Regeneration cuts the later messages out of the request, so the
        // conversation's stored hash — which names the snapshot the *newest*
        // message carries — says nothing about the one that survives here.
        await seedAssistant('assistant-1');
        await seedAssistant('assistant-2');
        await putEntry(id: 'mem_01', content: 'User likes Flutter.');
        final conversation = await seedConversation('conv-1');
        final u1 = await seedUserMessage(id: 'u1', conversationId: 'conv-1');
        final u2 = await seedUserMessage(
          id: 'u2',
          conversationId: 'conv-1',
          content: 'again',
          messageOrder: 1,
        );

        // u1 froze snapshot A, back when the memory was global.
        final snapshotA = await currentSnapshot('assistant-1');
        await chatRepository.freezeMessagePrompt(
          revisionId: 'u1',
          conversationId: 'conv-1',
          payload: '${snapshotA.prefix}hi',
          carriesMemorySnapshot: true,
          injectedMemoryHash: Value(snapshotA.hash),
        );

        // The memory moves to another assistant, then u2 froze snapshot B and
        // advanced the conversation hash to it.
        await putEntry(
          id: 'mem_01',
          content: 'User likes Flutter.',
          scope: MemoryScope.assistant,
          assistantId: 'assistant-2',
        );
        final snapshotB = await currentSnapshot('assistant-1');
        await chatRepository.freezeMessagePrompt(
          revisionId: 'u2',
          conversationId: 'conv-1',
          payload: '${snapshotB.prefix}again',
          carriesMemorySnapshot: true,
          injectedMemoryHash: Value(snapshotB.hash),
        );

        // Regenerating the reply after u1 leaves u2 out of the request.
        final apiMessages = <Map<String, dynamic>>[
          {
            'role': 'user',
            'content': 'hi',
            MessageBuilderService.internalRevisionIdKey: 'u1',
          },
        ];
        await buildService(messages: [u1, u2]).processUserMessagesForApi(
          apiMessages,
          settings,
          assistant,
          conversation: conversation,
          sourceMessages: [u1, u2],
        );

        final sent = apiMessages.single['content'].toString();
        expect(sent, isNot(contains('User likes Flutter.')));
        expect(sent, 'hi');
      },
    );

    test(
      'a snapshot injected mid-request outranks a later frozen one',
      () async {
        // A history message that could not be frozen (failed OCR, sandbox data
        // file) is reassembled in place and can take the fresh snapshot while an
        // older frozen one still follows it.
        await seedAssistant('assistant-1');
        await putEntry(id: 'mem_01', content: 'User likes Flutter.');
        final conversation = await seedConversation('conv-1');
        final u1 = await seedUserMessage(id: 'u1', conversationId: 'conv-1');
        final u2 = await seedUserMessage(
          id: 'u2',
          conversationId: 'conv-1',
          content: 'again',
          messageOrder: 1,
        );
        // u1 has no freeze row; u2 froze a snapshot from before mem_01 changed.
        final stale = MemoryBlockBuilder.buildFullSnapshotPrefix(
          MemoryBlockBuilder.buildProfileBlock(
            fields: const [],
            lang: MemoryPromptLang.zh,
          ),
          '<user_memory type="identity">\n'
          '- [2026-08-01] stale entry\n'
          '</user_memory>\n'
          '<user_memory type="workflow"/>\n'
          '<user_memory type="voice"/>\n'
          '<user_memory type="instruction"/>\n',
          MemoryPromptLang.zh,
        );
        await chatRepository.freezeMessagePrompt(
          revisionId: 'u2',
          conversationId: 'conv-1',
          payload: '${stale}again',
          carriesMemorySnapshot: true,
          injectedMemoryHash: const Value('stalehash0000001'),
        );

        final apiMessages = <Map<String, dynamic>>[
          {
            'role': 'user',
            'content': 'hi',
            MessageBuilderService.internalRevisionIdKey: 'u1',
          },
          {
            'role': 'user',
            'content': 'again',
            MessageBuilderService.internalRevisionIdKey: 'u2',
          },
        ];
        await buildService(messages: [u1, u2]).processUserMessagesForApi(
          apiMessages,
          settings,
          assistant,
          conversation: conversation,
          sourceMessages: [u1, u2],
        );

        expect(apiMessages[0]['content'], contains('User likes Flutter.'));
        expect(apiMessages[1]['content'], 'again');
        final sent = apiMessages.map((m) => m['content'].toString()).join('\n');
        expect(sent, isNot(contains('stale entry')));
      },
    );

    test('user text that looks like a snapshot is left alone', () async {
      // Format alone must not decide: a user pasting a snapshot out of the
      // context log would otherwise lose the head of their own message.
      await seedAssistant('assistant-1');
      await putEntry(id: 'mem_01', content: 'User likes Flutter.');
      final conversation = await seedConversation('conv-1');
      final u1 = await seedUserMessage(id: 'u1', conversationId: 'conv-1');
      final u2 = await seedUserMessage(
        id: 'u2',
        conversationId: 'conv-1',
        content: 'again',
        messageOrder: 1,
      );
      final snapshot = await currentSnapshot('assistant-1');
      final pasted = '${snapshot.prefix}why is this in my prompt?';
      await chatRepository.putMessagePrompt(
        revisionId: 'u1',
        conversationId: 'conv-1',
        payload: pasted,
        carriesMemorySnapshot: false,
      );
      await chatRepository.freezeMessagePrompt(
        revisionId: 'u2',
        conversationId: 'conv-1',
        payload: '${snapshot.prefix}again',
        carriesMemorySnapshot: true,
        injectedMemoryHash: Value(snapshot.hash),
      );

      final apiMessages = <Map<String, dynamic>>[
        {
          'role': 'user',
          'content': 'hi',
          MessageBuilderService.internalRevisionIdKey: 'u1',
        },
        {
          'role': 'user',
          'content': 'again',
          MessageBuilderService.internalRevisionIdKey: 'u2',
        },
      ];
      await buildService(messages: [u1, u2]).processUserMessagesForApi(
        apiMessages,
        settings,
        assistant,
        conversation: conversation,
        sourceMessages: [u1, u2],
      );

      expect(apiMessages[0]['content'], pasted);
      expect(apiMessages[1]['content'], '${snapshot.prefix}again');
    });
  });

  group('§18.4 item 30 — self-heal after truncateIndex advances', () {
    test(
      'dropping snapshot-carrying message yields full snapshot next turn',
      () async {
        await seedAssistant('assistant-1');
        await putEntry(id: 'mem_01', content: 'User likes Flutter.');

        final conversation = await seedConversation('conv-1');
        await seedUserMessage(id: 'u1', conversationId: 'conv-1');
        await seedUserMessage(
          id: 'u2',
          conversationId: 'conv-1',
          content: 'again',
          messageOrder: 1,
        );
        await seedUserMessage(
          id: 'u3',
          conversationId: 'conv-1',
          content: 'after truncate',
          messageOrder: 2,
        );
        final service = buildService();

        // First turn: no history snapshot → full snapshot, freeze u1.
        final first = await service.resolveMemoryPrefix(
          conversation: conversation,
          assistant: assistant,
          apiMessages: [
            {
              'role': 'user',
              'content': 'hi',
              MessageBuilderService.internalRevisionIdKey: 'u1',
            },
          ],
          currentMessageId: 'u1',
          lang: MemoryPromptLang.zh,
        );
        expect(first.prefix, contains(MemoryPrompts.introFullZh));
        await chatRepository.freezeMessagePrompt(
          revisionId: 'u1',
          conversationId: 'conv-1',
          payload: '${first.prefix}hi',
          carriesMemorySnapshot: true,
          injectedMemoryHash: Value(first.hash),
        );

        // Same hash, snapshot still in apiMessages → empty.
        final same = await service.resolveMemoryPrefix(
          conversation: conversation,
          assistant: assistant,
          apiMessages: [
            {
              'role': 'user',
              'content': 'hi',
              MessageBuilderService.internalRevisionIdKey: 'u1',
            },
            {
              'role': 'user',
              'content': 'again',
              MessageBuilderService.internalRevisionIdKey: 'u2',
            },
          ],
          currentMessageId: 'u2',
          lang: MemoryPromptLang.zh,
        );
        expect(same.prefix, isEmpty);

        // truncateIndex advanced: u1 left apiMessages → full snapshot again.
        final healed = await service.resolveMemoryPrefix(
          conversation: conversation,
          assistant: assistant,
          apiMessages: [
            {
              'role': 'user',
              'content': 'after truncate',
              MessageBuilderService.internalRevisionIdKey: 'u3',
            },
          ],
          currentMessageId: 'u3',
          lang: MemoryPromptLang.zh,
        );

        expect(healed.prefix, contains(MemoryPrompts.introFullZh));
        expect(healed.prefix, isNot(contains('<user_memory_update>')));
      },
    );
  });

  group('§11.1 system message stability', () {
    test(
      'system message is byte-identical before and after a memory is created',
      () async {
        await seedAssistant('assistant-1');
        final service = buildService();
        final apiBefore = <Map<String, dynamic>>[
          {'role': 'system', 'content': 'base system'},
        ];
        await service.injectMemoryAndRecentChats(
          apiBefore,
          assistant.copyWith(allowPastConversationRecall: true),
          settings: settings,
        );
        final before = (apiBefore.first['content'] ?? '').toString();

        await putEntry(id: 'mem_01', content: 'Brand new memory.');

        final apiAfter = <Map<String, dynamic>>[
          {'role': 'system', 'content': 'base system'},
        ];
        await service.injectMemoryAndRecentChats(
          apiAfter,
          assistant.copyWith(allowPastConversationRecall: true),
          settings: settings,
        );
        final after = (apiAfter.first['content'] ?? '').toString();

        expect(after, before);
        expect(before, contains('## 长期记忆'));
        expect(before, contains(MemoryPrompts.rulesPastConversationRecallZh));
        expect(before, isNot(contains('<memories>')));
        expect(before, isNot(contains('<recent_chats>')));
        expect(before, isNot(contains('当前时间是')));
      },
    );

    test(
      'recall rules ship without memory rules when only recall is on',
      () async {
        // chat_search is registered on allowPastConversationRecall alone, so its
        // usage rules cannot ride along with the long-term memory rules or the
        // tool reaches the model with no instructions at all.
        await seedAssistant('assistant-1');
        final api = <Map<String, dynamic>>[
          {'role': 'system', 'content': 'base system'},
        ];
        await buildService().injectMemoryAndRecentChats(
          api,
          assistant.copyWith(
            enableMemory: false,
            allowPastConversationRecall: true,
          ),
          settings: settings,
        );

        final content = (api.first['content'] ?? '').toString();
        expect(content, contains(MemoryPrompts.rulesPastConversationRecallZh));
        expect(content, isNot(contains('## 长期记忆')));
      },
    );

    test('neither gate injects nothing', () async {
      await seedAssistant('assistant-1');
      final api = <Map<String, dynamic>>[
        {'role': 'system', 'content': 'base system'},
      ];
      await buildService().injectMemoryAndRecentChats(
        api,
        assistant.copyWith(
          enableMemory: false,
          allowPastConversationRecall: false,
        ),
        settings: settings,
      );
      expect(api.first['content'], 'base system');
    });
  });
}
