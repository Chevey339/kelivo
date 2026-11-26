import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/memory_entry.dart';
import 'package:Kelivo/core/providers/memory_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/logging/context_logger.dart';
import 'package:Kelivo/core/services/memory/memory_block_builder.dart';
import 'package:Kelivo/core/services/memory/memory_prompts.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

class _FakeChatService extends ChatService {
  _FakeChatService({this.persistedMessages = const []});

  final List<ChatMessage> persistedMessages;

  @override
  List<ChatMessage> getMessages(String conversationId) {
    return persistedMessages
        .where((message) => message.conversationId == conversationId)
        .toList();
  }
}

void main() {
  late AppDatabase database;
  late BusinessRepository businessRepository;
  late BusinessPreferences preferences;
  late ChatDatabaseRepository chatRepository;
  late SettingsProvider settings;
  late MemoryProvider memoryProvider;
  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;

  Future<void> openHarness() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('kelivo_memory_legacy_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
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
    memoryProvider = MemoryProvider(preferences: preferences);
    await memoryProvider.initialize();
    await ContextLogger.setEnabled(false);
  }

  Future<void> closeHarness() async {
    await ContextLogger.setEnabled(false);
    PathProviderPlatform.instance = previousPathProvider;
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }

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
  }) {
    final created = DateTime.utc(2026, 8, 1).microsecondsSinceEpoch;
    return businessRepository.upsertEntity(
      BusinessEntityKind.memoryEntry,
      BusinessEntityValue(
        id: id,
        sortOrder: 0,
        payload: jsonEncode({
          'id': id,
          'scope': 'global',
          'assistantId': null,
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

  Future<Conversation> seedConversation(String id) async {
    final conversation = Conversation(id: id, title: id);
    await chatRepository.putConversation(conversation);
    return conversation;
  }

  Future<ChatMessage> seedUserMessage({
    required String id,
    required String conversationId,
    String content = 'hi',
  }) async {
    final message = ChatMessage(
      id: id,
      role: 'user',
      content: content,
      conversationId: conversationId,
    );
    await chatRepository.putMessage(message);
    return message;
  }

  MessageBuilderService buildService({
    BuildContext? context,
    List<ChatMessage> messages = const [],
  }) {
    return MessageBuilderService(
      chatService: _FakeChatService(persistedMessages: messages),
      contextProvider: context ?? _FakeBuildContext(),
      chatRepository: chatRepository,
    );
  }

  const assistant = Assistant(
    id: 'assistant-1',
    name: 'Test',
    enableMemory: true,
    messageTemplate: '{{ message }}',
  );

  group('legacyMemoryMode ON', () {
    setUp(openHarness);
    tearDown(closeHarness);

    test(
      'resolveMemoryPrefix is empty and freeze writes no snapshot',
      () async {
        await settings.setLegacyMemoryMode(true);
        await seedAssistant(assistant.id);
        await putEntry(id: 'mem_01', content: 'User likes Flutter.');
        final conversation = await seedConversation('conv-1');
        final message = await seedUserMessage(
          id: 'u1',
          conversationId: 'conv-1',
          content: 'hello',
        );
        final service = buildService(messages: [message]);
        final apiMessages = <Map<String, dynamic>>[
          {
            'role': 'user',
            'content': 'hello',
            MessageBuilderService.internalRevisionIdKey: 'u1',
          },
        ];

        final result = await service.resolveMemoryPrefix(
          conversation: conversation,
          assistant: assistant,
          apiMessages: apiMessages,
          currentMessageId: 'u1',
          lang: MemoryPromptLang.zh,
          settings: settings,
        );
        expect(result.prefix, isEmpty);
        expect(result.hash, isNull);
        expect(result.snapshotKind, isNull);

        await service.processUserMessagesForApi(
          apiMessages,
          settings,
          assistant,
          conversation: conversation,
          sourceMessages: [message],
        );
        final frozen = await chatRepository.getMessagePrompt('u1');
        expect(frozen, isNotNull);
        expect(frozen!.carriesMemorySnapshot, isFalse);
        expect(frozen.payload, isNot(contains('<user_memory')));
        expect(frozen.payload, isNot(contains(MemoryPrompts.introFullZh)));
      },
    );

    test(
      'strips a previously frozen v2 snapshot from send, keeps the freeze row',
      () async {
        await seedAssistant(assistant.id);
        final conversation = await seedConversation('conv-switch');
        final message = await seedUserMessage(
          id: 'u-switch',
          conversationId: 'conv-switch',
          content: 'hello',
        );
        final prefix = MemoryBlockBuilder.buildFullSnapshotPrefix(
          MemoryBlockBuilder.buildProfileBlock(
            fields: const [],
            lang: MemoryPromptLang.zh,
          ),
          MemoryBlockBuilder.buildMemoryBlock(
            visible: const [],
            totalByType: const {},
            lang: MemoryPromptLang.zh,
            maxItems: 10,
          ),
          MemoryPromptLang.zh,
        );
        final payload = '${prefix}hello';
        await chatRepository.putMessagePrompt(
          revisionId: 'u-switch',
          conversationId: 'conv-switch',
          payload: payload,
          carriesMemorySnapshot: true,
        );

        await settings.setLegacyMemoryMode(true);
        final service = buildService(messages: [message]);
        final apiMessages = <Map<String, dynamic>>[
          {
            'role': 'user',
            'content': 'hello',
            MessageBuilderService.internalRevisionIdKey: 'u-switch',
          },
        ];
        await service.processUserMessagesForApi(
          apiMessages,
          settings,
          assistant,
          conversation: conversation,
          sourceMessages: [message],
        );

        expect(apiMessages.single['content'], 'hello');
        expect(apiMessages.single['content'], isNot(contains('<user_memory')));
        expect(
          apiMessages.single['content'],
          isNot(contains(MemoryPrompts.introFullZh)),
        );

        final frozen = await chatRepository.getMessagePrompt('u-switch');
        expect(frozen, isNotNull);
        expect(frozen!.carriesMemorySnapshot, isTrue);
        expect(frozen.payload, payload);
      },
    );
  });

  group('legacyMemoryMode OFF', () {
    setUp(openHarness);
    tearDown(closeHarness);

    test(
      'system message is byte-identical before and after a memory is created',
      () async {
        await seedAssistant(assistant.id);
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
  });

  group('legacyMemoryMode ON inject', () {
    for (final lang in ['zh', 'en']) {
      testWidgets(
        '$lang legacy memory uses absolute dates without injecting the current hour',
        (tester) async {
          await tester.runAsync(openHarness);
          addTearDown(() => tester.runAsync(closeHarness));

          late String content;
          await tester.runAsync(() async {
            await settings.setLegacyMemoryMode(true);
            await settings.setMemoryPromptLang(lang);
            await memoryProvider.add(
              assistantId: assistant.id,
              content: 'User likes Flutter.',
            );
          });

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<SettingsProvider>.value(value: settings),
                ChangeNotifierProvider<MemoryProvider>.value(
                  value: memoryProvider,
                ),
              ],
              child: const SizedBox.shrink(),
            ),
          );
          final context = tester.element(find.byType(SizedBox));
          final api = <Map<String, dynamic>>[
            {'role': 'system', 'content': 'base system'},
          ];

          await tester.runAsync(() async {
            await buildService(context: context).injectMemoryAndRecentChats(
              api,
              assistant.copyWith(allowPastConversationRecall: true),
              settings: settings,
            );
            content = (api.first['content'] ?? '').toString();
          });

          expect(content, contains('<memories>'));
          expect(content, contains('User likes Flutter.'));
          expect(content, contains('## Memory Tool'));
          expect(content, contains('create_memory'));
          expect(
            content,
            contains(
              lang == 'zh'
                  ? '请使用绝对时间格式。'
                  : 'include them in an absolute time format.',
            ),
          );
          final template = lang == 'zh'
              ? MemoryPrompts.legacyRulesZh
              : MemoryPrompts.legacyRulesEn;
          expect(content, contains(template));
          expect(template, isNot(contains('{{currentTime}}')));
          expect(content, isNot(contains('{{currentTime}}')));
          expect(
            content,
            isNot(matches(RegExp(r'\d{4}年\d{1,2}月\d{1,2}日的\d{1,2}点'))),
          );
          expect(content, isNot(contains('## 长期记忆')));
          expect(content, isNot(contains(MemoryPrompts.rulesZh)));
          expect(
            content,
            isNot(contains(MemoryPrompts.rulesPastConversationRecallZh)),
          );
        },
      );
    }

    testWidgets('uses the customizable legacy rules template', (tester) async {
      await tester.runAsync(openHarness);
      addTearDown(() => tester.runAsync(closeHarness));

      late String content;
      await tester.runAsync(() async {
        await settings.setLegacyMemoryMode(true);
        await settings.setMemoryPromptLang('en');
        await settings.setLegacyMemoryPromptEn(
          'Custom legacy rules at {{currentTime}}',
        );
        await memoryProvider.add(
          assistantId: assistant.id,
          content: 'User likes Flutter.',
        );
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<MemoryProvider>.value(value: memoryProvider),
          ],
          child: const SizedBox.shrink(),
        ),
      );
      final context = tester.element(find.byType(SizedBox));
      final api = <Map<String, dynamic>>[
        {'role': 'system', 'content': 'base system'},
      ];

      await tester.runAsync(() async {
        await buildService(
          context: context,
        ).injectMemoryAndRecentChats(api, assistant, settings: settings);
        content = (api.first['content'] ?? '').toString();
      });

      expect(content.trimRight(), endsWith('Custom legacy rules at'));
      expect(
        settings.legacyMemoryPromptEn,
        'Custom legacy rules at {{currentTime}}',
      );
      expect(
        content,
        isNot(matches(RegExp(r'\d{4}年\d{1,2}月\d{1,2}日的\d{1,2}点'))),
      );
      expect(content, isNot(contains('{{currentTime}}')));
      expect(content, contains('User likes Flutter.'));
    });
  });
}
