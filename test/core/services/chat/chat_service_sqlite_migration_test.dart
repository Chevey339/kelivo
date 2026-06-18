import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/hive_chat_migrator.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';

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

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_chat_sqlite_migration_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'stores new chats in sqlite and restores them after service restart',
    () async {
      final service = ChatService();
      await service.init();

      final conversation = await service.createConversation(
        title: 'SQLite chat',
      );
      final user = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'hello sqlite',
      );
      final assistant = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'hi',
        isStreaming: true,
      );
      await service.setToolEvents(assistant.id, [
        {
          'id': 'tool-1',
          'name': 'lookup',
          'arguments': {'q': 'sqlite'},
          'content': 'done',
        },
      ]);
      await service.setGeminiThoughtSignature(assistant.id, 'thought-sig');

      final restarted = ChatService();
      await restarted.init();

      expect(restarted.getAllConversations().map((c) => c.id), [
        conversation.id,
      ]);
      expect(restarted.getMessages(conversation.id).map((m) => m.id), [
        user.id,
        assistant.id,
      ]);
      expect(restarted.getMessages(conversation.id).last.isStreaming, isFalse);
      expect(restarted.getMessagesRange(conversation.id, start: 1, limit: 1), [
        isA<ChatMessage>().having((m) => m.id, 'id', assistant.id),
      ]);
      expect(restarted.getToolEvents(assistant.id).single['name'], 'lookup');
      expect(restarted.getGeminiThoughtSignature(assistant.id), 'thought-sig');
    },
  );

  test('imports legacy Hive chats once without deleting Hive files', () async {
    await Hive.initFlutter(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ConversationAdapter());
    }

    final conversations = await Hive.openBox<Conversation>(
      HiveChatMigrator.conversationsBoxName,
    );
    final messages = await Hive.openBox<ChatMessage>(
      HiveChatMigrator.messagesBoxName,
    );
    final toolEvents = await Hive.openBox(HiveChatMigrator.toolEventsBoxName);

    final first = ChatMessage(
      id: 'legacy-user',
      role: 'user',
      content: 'legacy hello',
      conversationId: 'legacy-conversation',
    );
    final second = ChatMessage(
      id: 'legacy-assistant',
      role: 'assistant',
      content: 'legacy answer',
      conversationId: 'legacy-conversation',
      isStreaming: true,
    );
    await messages.put(first.id, first);
    await messages.put(second.id, second);
    await conversations.put(
      'legacy-conversation',
      Conversation(
        id: 'legacy-conversation',
        title: 'Legacy',
        messageIds: [first.id, second.id],
        versionSelections: {'legacy-assistant': 0},
      ),
    );
    await toolEvents.put(second.id, [
      {'id': 'tool-legacy', 'name': 'legacy_tool'},
    ]);
    await toolEvents.put('sig_${second.id}', 'legacy-sig');
    await toolEvents.put('orphan-assistant', [
      {'id': 'tool-orphan', 'name': 'missing_message_tool'},
    ]);
    await toolEvents.put('sig_orphan-assistant', 'orphan-sig');
    await Hive.close();

    final service = ChatService();
    await service.init();

    final restored = service.getMessages('legacy-conversation');
    expect(restored.map((m) => m.id), [first.id, second.id]);
    expect(restored.last.isStreaming, isFalse);
    expect(service.getVersionSelections('legacy-conversation'), {
      'legacy-assistant': 0,
    });
    expect(service.getToolEvents(second.id).single['id'], 'tool-legacy');
    expect(service.getGeminiThoughtSignature(second.id), 'legacy-sig');
    expect(service.getToolEvents('orphan-assistant'), isEmpty);
    expect(service.getGeminiThoughtSignature('orphan-assistant'), isNull);
    expect(
      await File(
        '${tempDir.path}/${HiveChatMigrator.messagesBoxName}.hive',
      ).exists(),
      isTrue,
    );

    await service.clearAllData();
    final restarted = ChatService();
    await restarted.init();

    expect(restarted.getAllConversations(), isEmpty);
  });
}
