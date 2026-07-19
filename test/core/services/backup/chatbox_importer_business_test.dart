import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_restore_service.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/backup/chatbox_importer.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => '$root/cache';

  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

Map<String, dynamic> _chatboxFixture() => {
  '__exported_at': '2026-07-18T00:00:00.000Z',
  'settings': {
    'providers': {
      'openai': {
        'apiKey': 'chatbox-secret',
        'apiHost': 'https://api.example.test',
        'apiPath': '/v1/chat/completions',
        'models': [
          {'modelId': 'gpt-test'},
        ],
      },
    },
  },
  'chat-sessions-list': [
    {'id': 'assistant-1', 'name': 'Chatbox assistant', 'starred': true},
  ],
  'session:assistant-1': {
    'settings': {
      'provider': 'openai',
      'modelId': 'gpt-test',
      'temperature': 0.5,
    },
    'messages': [
      {'id': 'system-1', 'role': 'system', 'content': 'Imported system prompt'},
      {
        'id': 'message-1',
        'role': 'user',
        'content': 'Hello',
        'timestamp': 1784332800000,
      },
    ],
    'threads': <dynamic>[],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('ChatboxImporter SQLite business patch', () {
    late Directory root;
    late AppDatabase database;
    late BusinessRepository businessRepository;
    late ChatService chatService;
    late File backup;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_chatbox_db_');
      PathProviderPlatform.instance = _FakePathProvider(root.path);
      SharedPreferences.setMockInitialValues({});
      final databaseFile = File('${root.path}/kelivo.db');
      database = AppDatabase.open(file: databaseFile);
      businessRepository = BusinessRepository(database);
      chatService = ChatService(
        existingRepository: ChatDatabaseRepository(
          database,
          databaseFile: databaseFile,
        ),
      );
      backup = await File(
        '${root.path}/chatbox.json',
      ).writeAsString(jsonEncode(_chatboxFixture()), flush: true);
    });

    tearDown(() async {
      await chatService.close();
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    });

    test(
      'writes providers, assistants, tags, and relationships to SQLite',
      () async {
        final replacedUpload = await File(
          '${root.path}/upload/replace.txt',
        ).create(recursive: true);
        final result = await ChatboxImporter.importFromChatbox(
          file: backup,
          mode: RestoreMode.overwrite,
          businessRepository: businessRepository,
          chatService: chatService,
        );

        expect(result.providers, 1);
        expect(result.assistants, 1);
        expect(result.conversations, 1);
        expect(result.messages, 1);
        final exported = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
        final providers =
            jsonDecode(exported['provider_configs_v1'] as String) as Map;
        expect((providers['openai'] as Map)['apiKey'], 'chatbox-secret');
        expect(exported['providers_order_v1'], ['openai']);
        expect(exported['assistants_v1'], contains('assistant-1'));
        expect(exported['assistant_tags_v1'], contains('Chatbox'));
        expect(exported['assistant_tag_map_v1'], contains('assistant-1'));
        expect(chatService.getAllConversations(), hasLength(1));
        expect(await replacedUpload.exists(), isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('provider_configs_v1'), isNull);
        expect(prefs.getString('assistants_v1'), isNull);
        expect(prefs.getString('assistant_tags_v1'), isNull);
      },
    );

    test(
      'rolls back all business rows when a later table write fails',
      () async {
        final retainedUpload = await File(
          '${root.path}/upload/keep.txt',
        ).create(recursive: true);
        await retainedUpload.writeAsString('keep');
        await chatService.restoreConversation(
          Conversation(id: 'local-chat', title: 'Keep chat'),
          [
            ChatMessage(
              id: 'local-message',
              role: 'user',
              content: 'Keep message',
              conversationId: 'local-chat',
            ),
          ],
        );
        await BusinessRestoreService(businessRepository).overwrite({
          'provider_configs_v1': jsonEncode({
            'local': {'id': 'local', 'apiKey': 'keep-me'},
          }),
          'providers_order_v1': ['local'],
          'assistants_v1': jsonEncode([
            {'id': 'local-assistant', 'name': 'Keep me'},
          ]),
        });
        final before = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
        await database.customStatement(
          'CREATE TRIGGER fail_chatbox_assistant_insert '
          'BEFORE INSERT ON assistant_rows BEGIN '
          "SELECT RAISE(ABORT, 'injected failure'); END;",
        );

        await expectLater(
          ChatboxImporter.importFromChatbox(
            file: backup,
            mode: RestoreMode.overwrite,
            businessRepository: businessRepository,
            chatService: chatService,
          ),
          throwsA(anything),
        );

        expect(
          await BusinessRestoreService(businessRepository).exportSettings(),
          before,
        );
        expect(chatService.getConversation('local-chat'), isNotNull);
        expect(
          await chatService.loadMessages('local-chat'),
          contains(
            isA<ChatMessage>()
                .having((message) => message.id, 'id', 'local-message')
                .having(
                  (message) => message.content,
                  'content',
                  'Keep message',
                ),
          ),
        );
        expect(await retainedUpload.exists(), isTrue);

        final reloaded = ChatService(
          existingRepository: ChatDatabaseRepository(
            database,
            databaseFile: File('${root.path}/kelivo.db'),
          ),
        );
        await reloaded.init();
        try {
          expect(reloaded.getConversation('local-chat'), isNotNull);
          expect(
            await reloaded.loadMessages('local-chat'),
            contains(
              isA<ChatMessage>().having(
                (message) => message.id,
                'id',
                'local-message',
              ),
            ),
          );
        } finally {
          await reloaded.close();
        }
      },
    );

    test('merge parses every session before writing any chat rows', () async {
      final businessBefore = await BusinessRestoreService(
        businessRepository,
      ).exportSettings();
      final malformed = _chatboxFixture();
      (malformed['chat-sessions-list'] as List).add({
        'id': 'broken-assistant',
        'name': 'Broken',
        'starred': 'not-a-bool',
      });
      malformed['session:broken-assistant'] = {
        'messages': <dynamic>[],
        'threads': <dynamic>[],
      };
      await backup.writeAsString(jsonEncode(malformed), flush: true);

      await expectLater(
        ChatboxImporter.importFromChatbox(
          file: backup,
          mode: RestoreMode.merge,
          businessRepository: businessRepository,
          chatService: chatService,
        ),
        throwsA(anything),
      );

      expect(
        chatService.getConversation('chatbox_default_assistant-1'),
        isNull,
      );
      expect(
        await BusinessRestoreService(businessRepository).exportSettings(),
        businessBefore,
      );
    });

    test('fails closed when chat and business repositories differ', () async {
      await chatService.restoreConversation(
        Conversation(id: 'local-chat', title: 'Keep chat'),
        const <ChatMessage>[],
      );
      final otherFile = File('${root.path}/other.db');
      final otherDatabase = AppDatabase.open(file: otherFile);
      final otherBusinessRepository = BusinessRepository(otherDatabase);
      try {
        final businessBefore = await BusinessRestoreService(
          otherBusinessRepository,
        ).exportSettings();
        await expectLater(
          ChatboxImporter.importFromChatbox(
            file: backup,
            mode: RestoreMode.overwrite,
            businessRepository: otherBusinessRepository,
            chatService: chatService,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'chat_business_database_mismatch',
            ),
          ),
        );

        expect(chatService.getConversation('local-chat'), isNotNull);
        expect(
          chatService.getConversation('chatbox_default_assistant-1'),
          isNull,
        );
        expect(
          await BusinessRestoreService(
            otherBusinessRepository,
          ).exportSettings(),
          businessBefore,
        );
      } finally {
        await otherDatabase.close();
      }
    });
  });
}
