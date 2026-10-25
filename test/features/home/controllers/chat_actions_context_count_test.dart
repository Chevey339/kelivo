import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/chat_actions.dart';
import 'package:Kelivo/utils/app_directories.dart';

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

class _SpyChatDatabaseRepository extends ChatDatabaseRepository {
  _SpyChatDatabaseRepository(super.db, {super.databaseFile});

  int messageCountsByConversationCalls = 0;
  int perConversationMessageCountCalls = 0;

  @override
  Future<Map<String, int>> getMessageCountsByConversation() async {
    messageCountsByConversationCalls++;
    return super.getMessageCountsByConversation();
  }

  @override
  Future<int> getMessageCount(String conversationId) async {
    perConversationMessageCountCalls++;
    return super.getMessageCount(conversationId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final services = <ChatService>[];
  final repositories = <ChatDatabaseRepository>[];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_context_count_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    for (final service in services) {
      await service.close();
    }
    services.clear();
    for (final repository in repositories) {
      await repository.close();
    }
    repositories.clear();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> databaseFile() async {
    final appDataDir = await AppDirectories.getAppDataDirectory();
    return File('${appDataDir.path}/${AppDatabase.databaseFileName}');
  }

  Future<_SpyChatDatabaseRepository> openSpyRepository() async {
    final file = await databaseFile();
    final spy = _SpyChatDatabaseRepository(
      AppDatabase.open(file: file),
      databaseFile: file,
    );
    await spy.ensureReady();
    repositories.add(spy);
    return spy;
  }

  ChatService createService({ChatDatabaseRepository? existingRepository}) {
    final service = ChatService(existingRepository: existingRepository);
    services.add(service);
    return service;
  }

  Future<(String, List<String>)> seedConversation({
    required int messageCount,
  }) async {
    final repo = await openSpyRepository();
    final now = DateTime.utc(2026, 8, 10);
    const conversationId = 'long-conversation';
    final ids = <String>[for (var i = 0; i < messageCount; i++) 'msg-$i'];
    final batch = <({ChatMessage message, int messageOrder})>[
      for (var i = 0; i < messageCount; i++)
        (
          message: ChatMessage(
            id: ids[i],
            role: i.isEven ? 'user' : 'assistant',
            content: 'message $i',
            conversationId: conversationId,
            timestamp: now.add(Duration(seconds: i)),
          ),
          messageOrder: i,
        ),
    ];
    await repo.putMigrationBatch(
      conversations: [
        Conversation(
          id: conversationId,
          title: 'Long chat',
          messageIds: ids,
          createdAt: now,
          updatedAt: now.add(Duration(seconds: messageCount)),
        ),
      ],
      messages: batch,
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
    await repo.close();
    repositories.remove(repo);
    return (conversationId, ids);
  }

  test(
    'cold-start unlimited context resolves 1507 and includes first/last',
    () async {
      const total = 1507;
      final (conversationId, ids) = await seedConversation(messageCount: total);
      final spy = await openSpyRepository();
      final service = createService(existingRepository: spy);
      await service.init();

      expect(spy.messageCountsByConversationCalls, 0);
      expect(service.isMessageCountKnown(conversationId), isFalse);
      expect(service.getMessageCount(conversationId), -1);

      final beforeCountLookups = spy.perConversationMessageCountCalls;
      final limit = await ChatActions.resolveContextReadLimit(
        assistant: const Assistant(
          id: 'assistant-1',
          name: 'Unlimited',
          limitContextMessages: false,
        ),
        resolvePersistedCount: () =>
            service.resolveMessageCount(conversationId),
      );

      expect(limit, total);
      expect(limit, isNot(Assistant.maxContextMessageSize));
      expect(
        spy.perConversationMessageCountCalls,
        greaterThan(beforeCountLookups),
      );
      expect(spy.messageCountsByConversationCalls, 0);

      final context = await service.loadSelectedContextMessages(
        conversationId,
        limit: limit,
      );
      expect(context.first.id, ids.first);
      expect(context.last.id, ids.last);
      expect(context.length, total);
    },
  );

  test(
    'limited context does not query per-conversation message count',
    () async {
      final (conversationId, _) = await seedConversation(messageCount: 20);
      final spy = await openSpyRepository();
      final service = createService(existingRepository: spy);
      await service.init();
      expect(service.isMessageCountKnown(conversationId), isFalse);

      final before = spy.perConversationMessageCountCalls;
      final limit = await ChatActions.resolveContextReadLimit(
        assistant: const Assistant(
          id: 'assistant-1',
          name: 'Limited',
          contextMessageSize: 64,
          limitContextMessages: true,
        ),
        resolvePersistedCount: () =>
            service.resolveMessageCount(conversationId),
      );

      expect(limit, 64);
      expect(spy.perConversationMessageCountCalls, before);
      expect(spy.messageCountsByConversationCalls, 0);
    },
  );

  test('temporary conversation uses memory length without DB count', () async {
    final spy = await openSpyRepository();
    final service = createService(existingRepository: spy);
    await service.init();
    final draft = await service.createDraftConversation(
      title: 'Temp',
      temporary: true,
    );
    await service.addMessage(
      conversationId: draft.id,
      role: 'user',
      content: 'hello',
    );
    await service.addMessage(
      conversationId: draft.id,
      role: 'assistant',
      content: 'hi',
    );

    final before = spy.perConversationMessageCountCalls;
    final count = await service.resolveMessageCount(draft.id);
    expect(count, 2);
    expect(spy.perConversationMessageCountCalls, before);
    expect(spy.messageCountsByConversationCalls, 0);
  });

  test('new draft uses memory length without DB count', () async {
    final spy = await openSpyRepository();
    final service = createService(existingRepository: spy);
    await service.init();
    final draft = await service.createDraftConversation(title: 'Draft');

    final before = spy.perConversationMessageCountCalls;
    final count = await service.resolveMessageCount(draft.id);
    expect(count, 0);
    expect(spy.perConversationMessageCountCalls, before);
    expect(spy.messageCountsByConversationCalls, 0);

    final limit = await ChatActions.resolveContextReadLimit(
      assistant: const Assistant(
        id: 'assistant-1',
        name: 'Unlimited',
        limitContextMessages: false,
      ),
      resolvePersistedCount: () => service.resolveMessageCount(draft.id),
    );
    // Empty draft falls back to max when count is 0 (no history to read).
    expect(limit, Assistant.maxContextMessageSize);
    expect(spy.perConversationMessageCountCalls, before);
    expect(spy.messageCountsByConversationCalls, 0);
  });
}
