import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/proactive_care_message_flow.dart';

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

ChatMessage _msg({
  required String id,
  required String role,
  required String content,
  required String conversationId,
  String? groupId,
  int version = 0,
  bool isStreaming = false,
}) {
  return ChatMessage(
    id: id,
    role: role,
    content: content,
    conversationId: conversationId,
    groupId: groupId,
    version: version,
    isStreaming: isStreaming,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 6, 13, 9, 0, 0);

  group('ProactiveCareMessageFlow.collapseMessageVersions', () {
    test('keeps the selected version per group', () {
      final items = [
        _msg(
          id: 'g1v0',
          role: 'assistant',
          content: 'a0',
          conversationId: 'c',
          groupId: 'g1',
          version: 0,
        ),
        _msg(
          id: 'g1v1',
          role: 'assistant',
          content: 'a1',
          conversationId: 'c',
          groupId: 'g1',
          version: 1,
        ),
      ];
      final collapsed = ProactiveCareMessageFlow.collapseMessageVersions(
        items,
        {'g1': 0},
      );
      expect(collapsed, hasLength(1));
      expect(collapsed.first.content, 'a0');
    });

    test('defaults to the latest version when no selection exists', () {
      final items = [
        _msg(
          id: 'g1v0',
          role: 'assistant',
          content: 'a0',
          conversationId: 'c',
          groupId: 'g1',
          version: 0,
        ),
        _msg(
          id: 'g1v1',
          role: 'assistant',
          content: 'a1',
          conversationId: 'c',
          groupId: 'g1',
          version: 1,
        ),
      ];
      final collapsed = ProactiveCareMessageFlow.collapseMessageVersions(
        items,
        const <String, int>{},
      );
      expect(collapsed, hasLength(1));
      expect(collapsed.first.content, 'a1');
    });
  });

  group('ProactiveCareMessageFlow.buildHistory', () {
    test('drops empty, streaming, and pre-truncate messages', () {
      final convo = Conversation(
        title: 't',
        assistantId: 'a1',
        truncateIndex: 1,
      );
      final messages = [
        _msg(
          id: 'm0',
          role: 'user',
          content: 'before truncate',
          conversationId: convo.id,
        ),
        _msg(
          id: 'm1',
          role: 'assistant',
          content: 'kept',
          conversationId: convo.id,
        ),
        _msg(id: 'm2', role: 'user', content: '   ', conversationId: convo.id),
        _msg(
          id: 'm3',
          role: 'assistant',
          content: 'streaming',
          conversationId: convo.id,
          isStreaming: true,
        ),
        _msg(
          id: 'm4',
          role: 'user',
          content: 'kept user',
          conversationId: convo.id,
        ),
      ];
      final history = ProactiveCareMessageFlow.buildHistory(
        conversation: convo,
        messages: messages,
      );
      expect(history, [
        {'role': 'assistant', 'content': 'kept'},
        {'role': 'user', 'content': 'kept user'},
      ]);
    });
  });

  group('ProactiveCareMessageFlow.buildHeadlessPlaceholders', () {
    test('substitutes assistant name, model and nickname', () {
      final assistant = Assistant(id: 'a1', name: 'Mimi');
      final vars = ProactiveCareMessageFlow.buildHeadlessPlaceholders(
        assistant: assistant,
        modelId: 'gpt-x',
        userNickname: 'Kero',
        now: now,
      );
      expect(vars['{assistant_name}'], 'Mimi');
      expect(vars['{model_name}'], 'gpt-x');
      expect(vars['{nickname}'], 'Kero');
      expect(vars['{cur_datetime}'], contains('2026-06-13'));
    });
  });

  group('ProactiveCareMessageFlow.buildCareApiMessages', () {
    test('puts system first, care prompt as the final user turn', () async {
      final assistant = Assistant(
        id: 'a1',
        name: 'Mimi',
        systemPrompt: 'You are {assistant_name}.',
      );
      final messages = await ProactiveCareMessageFlow.buildCareApiMessages(
        assistant: assistant,
        userNickname: 'Kero',
        modelId: 'gpt-x',
        history: const [
          {'role': 'user', 'content': 'earlier'},
          {'role': 'assistant', 'content': 'reply'},
        ],
        carePrompt: 'Reach out warmly.',
        now: now,
      );
      expect(messages.first['role'], 'system');
      expect(messages.first['content'], 'You are Mimi.');
      expect(messages.last['role'], 'user');
      expect(messages.last['content'], contains('Reach out warmly.'));
      expect(messages.last['content'], contains(now.toIso8601String()));
    });

    test('omits system message when assistant has no system prompt', () async {
      final assistant = Assistant(id: 'a1', name: 'Mimi');
      final messages = await ProactiveCareMessageFlow.buildCareApiMessages(
        assistant: assistant,
        userNickname: 'Kero',
        modelId: 'gpt-x',
        history: const <Map<String, dynamic>>[],
        carePrompt: 'hi',
        now: now,
      );
      expect(messages.any((m) => m['role'] == 'system'), isFalse);
      expect(messages, hasLength(1));
      expect(messages.single['role'], 'user');
    });
  });

  group('ProactiveCareHeadlessChatStore', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('kelivo_pc_flow_');
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
      ProactiveCareHeadlessChatStore.dataDirPathProvider = () async =>
          tempDir.path;
      // Initialize Hive for the fresh temp dir before any direct box access in
      // the test body (production always goes through the store which inits).
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(ChatMessageAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ConversationAdapter());
      }
    });

    tearDown(() async {
      await ProactiveCareHeadlessChatStore.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns null conversation when assistant has none', () async {
      final result =
          await ProactiveCareHeadlessChatStore.loadRecentConversationFor('a1');
      expect(result.conversation, isNull);
      expect(result.messages, isEmpty);
    });

    test('appends an assistant reply readable by ChatService', () async {
      // Seed an existing conversation for the assistant.
      final seedConvo = Conversation(title: 'seed', assistantId: 'a1');
      final convBox = await Hive.openBox<Conversation>(
        ChatService.conversationsBoxName,
      );
      await convBox.put(seedConvo.id, seedConvo);

      final recent =
          await ProactiveCareHeadlessChatStore.loadRecentConversationFor('a1');
      expect(recent.conversation, isNotNull);

      final appended =
          await ProactiveCareHeadlessChatStore.appendAssistantReply(
            assistantId: 'a1',
            conversation: recent.conversation,
            content: 'proactive hello',
            fallbackTitle: 'New Chat',
            modelId: 'gpt-x',
            providerId: 'prov',
          );
      expect(appended.conversation.id, seedConvo.id);
      expect(appended.message.role, 'assistant');
      final appendedMessageId = appended.message.id;
      await ProactiveCareHeadlessChatStore.close();

      // Reopening the same Hive boxes (as ChatService would on next launch)
      // must surface the appended message with the persisted fields intact.
      Hive.init(tempDir.path);
      final convBox2 = await Hive.openBox<Conversation>(
        ChatService.conversationsBoxName,
      );
      final msgBox2 = await Hive.openBox<ChatMessage>(
        ChatService.messagesBoxName,
      );
      final reloadedConvo = convBox2.get(seedConvo.id);
      expect(reloadedConvo, isNotNull);
      expect(reloadedConvo!.messageIds, contains(appendedMessageId));
      final reloadedMsg = msgBox2.get(appendedMessageId);
      expect(reloadedMsg, isNotNull);
      expect(reloadedMsg!.content, 'proactive hello');
      expect(reloadedMsg.role, 'assistant');
      expect(reloadedMsg.conversationId, seedConvo.id);
      expect(reloadedMsg.modelId, 'gpt-x');
      expect(reloadedMsg.providerId, 'prov');
    });

    test('creates a new conversation when none is passed', () async {
      final appended =
          await ProactiveCareHeadlessChatStore.appendAssistantReply(
            assistantId: 'a2',
            conversation: null,
            content: 'brand new',
            fallbackTitle: 'New Chat',
          );
      expect(appended.conversation.assistantId, 'a2');
      expect(appended.conversation.title, 'New Chat');
      expect(appended.conversation.messageIds, contains(appended.message.id));
    });
  });
}
