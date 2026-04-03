import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/chat_controller.dart';
import 'package:Kelivo/features/home/controllers/generation_controller.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as home_stream;
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessageGenerationService.calculateRegenerationVersioning', () {
    late MessageGenerationService service;

    setUp(() {
      service = _createMessageGenerationService();
    });

    test(
      'user retry targets direct assistant child of selected user version',
      () {
        const userGroupId = 'user-group';
        const oldAssistantGroupId = 'assistant-old';
        const newAssistantGroupId = 'assistant-new';

        final oldUser = ChatMessage(
          id: 'u1',
          role: 'user',
          content: 'old user',
          conversationId: 'conversation',
          groupId: userGroupId,
          version: 0,
        );
        final oldAssistant = ChatMessage(
          id: 'a1',
          role: 'assistant',
          content: 'old assistant',
          conversationId: 'conversation',
          groupId: oldAssistantGroupId,
          version: 0,
          parentId: oldUser.id,
        );
        final editedUser = ChatMessage(
          id: 'u2',
          role: 'user',
          content: 'edited user',
          conversationId: 'conversation',
          groupId: userGroupId,
          version: 1,
        );
        final editedAssistantV0 = ChatMessage(
          id: 'a2',
          role: 'assistant',
          content: 'edited assistant',
          conversationId: 'conversation',
          groupId: newAssistantGroupId,
          version: 0,
          parentId: editedUser.id,
        );
        final editedAssistantV1 = ChatMessage(
          id: 'a3',
          role: 'assistant',
          content: 'edited assistant retry',
          conversationId: 'conversation',
          groupId: newAssistantGroupId,
          version: 1,
          parentId: editedUser.id,
        );

        final result = service.calculateRegenerationVersioning(
          message: editedUser,
          messages: <ChatMessage>[
            oldUser,
            oldAssistant,
            editedUser,
            editedAssistantV0,
            editedAssistantV1,
          ],
          assistantAsNewReply: false,
        );

        expect(result.targetGroupId, newAssistantGroupId);
        expect(result.nextVersion, 2);
        expect(result.lastKeep, 3);
      },
    );

    test(
      'user retry without direct assistant child creates new assistant group',
      () {
        final user = ChatMessage(
          id: 'u1',
          role: 'user',
          content: 'user',
          conversationId: 'conversation',
          groupId: 'user-group',
          version: 1,
        );
        final otherAssistant = ChatMessage(
          id: 'a1',
          role: 'assistant',
          content: 'other branch',
          conversationId: 'conversation',
          groupId: 'assistant-group',
          version: 0,
          parentId: 'different-user',
        );

        final result = service.calculateRegenerationVersioning(
          message: user,
          messages: <ChatMessage>[user, otherAssistant],
          assistantAsNewReply: false,
        );

        expect(result.targetGroupId, isNull);
        expect(result.nextVersion, 0);
        expect(result.lastKeep, 0);
      },
    );

    test('assistant retry appends version in same group', () {
      final assistant = ChatMessage(
        id: 'a2',
        role: 'assistant',
        content: 'assistant',
        conversationId: 'conversation',
        groupId: 'assistant-group',
        version: 1,
        parentId: 'u1',
      );

      final result = service.calculateRegenerationVersioning(
        message: assistant,
        messages: <ChatMessage>[
          ChatMessage(
            id: 'a1',
            role: 'assistant',
            content: 'assistant-v0',
            conversationId: 'conversation',
            groupId: 'assistant-group',
            version: 0,
            parentId: 'u1',
          ),
          assistant,
        ],
        assistantAsNewReply: false,
      );

      expect(result.targetGroupId, 'assistant-group');
      expect(result.nextVersion, 2);
      expect(result.lastKeep, 1);
    });

    test(
      'assistantAsNewReply forces brand-new reply for both user and assistant',
      () {
        final user = ChatMessage(
          id: 'u1',
          role: 'user',
          content: 'user',
          conversationId: 'conversation',
        );
        final assistant = ChatMessage(
          id: 'a1',
          role: 'assistant',
          content: 'assistant',
          conversationId: 'conversation',
          parentId: user.id,
        );

        final userResult = service.calculateRegenerationVersioning(
          message: user,
          messages: <ChatMessage>[user, assistant],
          assistantAsNewReply: true,
        );
        final assistantResult = service.calculateRegenerationVersioning(
          message: assistant,
          messages: <ChatMessage>[user, assistant],
          assistantAsNewReply: true,
        );

        expect(userResult.targetGroupId, isNull);
        expect(userResult.nextVersion, 0);
        expect(userResult.lastKeep, 0);

        expect(assistantResult.targetGroupId, isNull);
        expect(assistantResult.nextVersion, 0);
        expect(assistantResult.lastKeep, 1);
      },
    );

    test('returns invalid marker when target message is absent', () {
      final result = service.calculateRegenerationVersioning(
        message: ChatMessage(
          id: 'missing',
          role: 'user',
          content: 'missing',
          conversationId: 'conversation',
        ),
        messages: const <ChatMessage>[],
        assistantAsNewReply: false,
      );

      expect(result.targetGroupId, isNull);
      expect(result.nextVersion, 0);
      expect(result.lastKeep, -1);
    });
  });

  group('MessageBuilderService.collapseVersions', () {
    late MessageBuilderService service;

    setUp(() {
      service = MessageBuilderService(
        chatService: ChatService(),
        contextProvider: _FakeBuildContext(),
      );
    });

    test('falls back to flat order for legacy messages without parentId', () {
      final userV0 = ChatMessage(
        id: 'u1',
        role: 'user',
        content: 'user-v0',
        conversationId: 'conversation',
        groupId: 'user-group',
        version: 0,
      );
      final userV1 = ChatMessage(
        id: 'u2',
        role: 'user',
        content: 'user-v1',
        conversationId: 'conversation',
        groupId: 'user-group',
        version: 1,
      );
      final assistantV0 = ChatMessage(
        id: 'a1',
        role: 'assistant',
        content: 'assistant-v0',
        conversationId: 'conversation',
        groupId: 'assistant-group',
        version: 0,
      );
      final assistantV1 = ChatMessage(
        id: 'a2',
        role: 'assistant',
        content: 'assistant-v1',
        conversationId: 'conversation',
        groupId: 'assistant-group',
        version: 1,
      );

      final collapsed = service.collapseVersions(
        <ChatMessage>[userV0, userV1, assistantV0, assistantV1],
        const <String, int>{'user-group': 0, 'assistant-group': 1},
      );

      expect(collapsed.map((m) => m.id).toList(), <String>['u1', 'a2']);
    });

    test('tree traversal follows selected user branch', () {
      final userV0 = ChatMessage(
        id: 'u1',
        role: 'user',
        content: 'user-v0',
        conversationId: 'conversation',
        groupId: 'user-group',
        version: 0,
      );
      final assistantOld = ChatMessage(
        id: 'a1',
        role: 'assistant',
        content: 'assistant-old',
        conversationId: 'conversation',
        groupId: 'assistant-old-group',
        parentId: userV0.id,
      );
      final userV1 = ChatMessage(
        id: 'u2',
        role: 'user',
        content: 'user-v1',
        conversationId: 'conversation',
        groupId: 'user-group',
        version: 1,
      );
      final assistantNew = ChatMessage(
        id: 'a2',
        role: 'assistant',
        content: 'assistant-new',
        conversationId: 'conversation',
        groupId: 'assistant-new-group',
        parentId: userV1.id,
      );

      final collapsed = service.collapseVersions(
        <ChatMessage>[userV0, assistantOld, userV1, assistantNew],
        const <String, int>{'user-group': 1},
      );

      expect(collapsed.map((m) => m.id).toList(), <String>['u2', 'a2']);
    });
  });

  group('ChatController tree collapse', () {
    late _ChatServiceHarness harness;

    setUp(() async {
      harness = await _ChatServiceHarness.create();
    });

    tearDown(() async {
      await harness.dispose();
    });

    test(
      'collapsedMessages switches visible branch with version selection',
      () async {
        const userGroupId = 'user-group';

        final conversation = await harness.chatService.createConversation(
          title: 'Tree test',
        );

        final userV0 = await harness.chatService.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'user-v0',
          groupId: userGroupId,
          version: 0,
        );
        final assistantOld = await harness.chatService.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: 'assistant-old',
          parentId: userV0.id,
        );
        final userV1 = await harness.chatService.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'user-v1',
          groupId: userGroupId,
          version: 1,
        );
        final assistantNew = await harness.chatService.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: 'assistant-new',
          parentId: userV1.id,
        );

        harness.chatController.setCurrentConversation(conversation);
        expect(
          harness.chatController.collapsedMessages.map((m) => m.id).toList(),
          <String>[userV1.id, assistantNew.id],
        );

        await harness.chatController.setSelectedVersion(userGroupId, 0);
        expect(
          harness.chatController.collapsedMessages.map((m) => m.id).toList(),
          <String>[userV0.id, assistantOld.id],
        );
      },
    );
  });

  group('ChatService.deleteMessage', () {
    late _ChatServiceHarness harness;

    setUp(() async {
      harness = await _ChatServiceHarness.create();
    });

    tearDown(() async {
      await harness.dispose();
    });

    test(
      'deleting middle message reparents direct children and preserves branch visibility',
      () async {
        final conversation = await harness.chatService.createConversation(
          title: 'Delete middle',
        );

        final user1 = await harness.chatService.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'u1',
        );
        final assistant1 = await harness.chatService.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: 'a1',
          parentId: user1.id,
        );
        final user2 = await harness.chatService.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'u2',
          parentId: assistant1.id,
        );
        final assistant2 = await harness.chatService.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: 'a2',
          parentId: user2.id,
        );

        await harness.chatService.deleteMessage(assistant1.id);

        final messages = harness.chatService.getMessages(conversation.id);
        final reparentedUser2 = messages.firstWhere((m) => m.id == user2.id);

        expect(messages.map((m) => m.id).toList(), <String>[
          user1.id,
          user2.id,
          assistant2.id,
        ]);
        expect(reparentedUser2.parentId, user1.id);
        expect(
          harness.builderService
              .collapseVersions(messages, const <String, int>{})
              .map((m) => m.id)
              .toList(),
          <String>[user1.id, user2.id, assistant2.id],
        );
      },
    );

    test(
      'deleting root message reparents child to root and keeps branch reachable',
      () async {
        final conversation = await harness.chatService.createConversation(
          title: 'Delete root',
        );

        final user1 = await harness.chatService.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'u1',
        );
        final assistant1 = await harness.chatService.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: 'a1',
          parentId: user1.id,
        );
        final user2 = await harness.chatService.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'u2',
          parentId: assistant1.id,
        );

        await harness.chatService.deleteMessage(user1.id);

        final messages = harness.chatService.getMessages(conversation.id);
        final reparentedAssistant = messages.firstWhere(
          (m) => m.id == assistant1.id,
        );

        expect(reparentedAssistant.parentId, isNull);
        expect(
          harness.builderService
              .collapseVersions(messages, const <String, int>{})
              .map((m) => m.id)
              .toList(),
          <String>[assistant1.id, user2.id],
        );
      },
    );

    test(
      'deleting assistant cleans tool metadata and removes empty group selection',
      () async {
        const assistantGroupId = 'assistant-group';

        final conversation = await harness.chatService.createConversation(
          title: 'Delete metadata',
        );

        final user = await harness.chatService.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'u1',
        );
        final assistant = await harness.chatService.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: 'a1',
          groupId: assistantGroupId,
          parentId: user.id,
        );

        await harness.chatService.setToolEvents(
          assistant.id,
          <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'call_1',
              'name': 'tool',
              'arguments': <String, dynamic>{'query': 'hello'},
            },
          ],
        );
        await harness.chatService.setGeminiThoughtSignature(
          assistant.id,
          '<!-- sig -->',
        );
        await harness.chatService.setSelectedVersion(
          conversation.id,
          assistantGroupId,
          0,
        );

        await harness.chatService.deleteMessage(assistant.id);

        final updatedConversation = harness.chatService.getConversation(
          conversation.id,
        )!;
        expect(
          updatedConversation.versionSelections.containsKey(assistantGroupId),
          isFalse,
        );
        expect(harness.chatService.getToolEvents(assistant.id), isEmpty);
        expect(
          harness.chatService.getGeminiThoughtSignature(assistant.id),
          isNull,
        );
      },
    );
  });
}

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform(this.basePath);

  final String basePath;

  @override
  Future<String?> getApplicationSupportPath() async => basePath;

  @override
  Future<String?> getApplicationDocumentsPath() async => basePath;

  @override
  Future<String?> getApplicationCachePath() async => p.join(basePath, 'cache');

  @override
  Future<String?> getTemporaryPath() async => p.join(basePath, 'tmp');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChatServiceHarness {
  _ChatServiceHarness({
    required this.tempDir,
    required this.chatService,
    required this.builderService,
    required this.chatController,
  });

  final Directory tempDir;
  final ChatService chatService;
  final MessageBuilderService builderService;
  final ChatController chatController;

  static Future<_ChatServiceHarness> create() async {
    final tempDir = await Directory.systemTemp.createTemp('kelivo_tree_test_');
    PathProviderPlatform.instance = _TestPathProviderPlatform(tempDir.path);

    final chatService = ChatService();
    await chatService.init();
    final builderService = MessageBuilderService(
      chatService: chatService,
      contextProvider: _FakeBuildContext(),
    );

    return _ChatServiceHarness(
      tempDir: tempDir,
      chatService: chatService,
      builderService: builderService,
      chatController: ChatController(chatService: chatService),
    );
  }

  Future<void> dispose() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

MessageGenerationService _createMessageGenerationService() {
  final chatService = ChatService();
  final context = _FakeBuildContext();
  final builderService = MessageBuilderService(
    chatService: chatService,
    contextProvider: context,
  );
  final chatController = ChatController(chatService: chatService);
  final streamController = home_stream.StreamController(
    chatService: chatService,
    onStateChanged: () {},
    getSettingsProvider: () => throw UnimplementedError(),
    getCurrentConversationId: () => null,
  );
  final generationController = GenerationController(
    chatService: chatService,
    chatController: chatController,
    streamController: streamController,
    messageBuilderService: builderService,
    contextProvider: context,
    onStateChanged: () {},
    getTitleForLocale: (_) => 'Test',
  );

  return MessageGenerationService(
    chatService: chatService,
    messageBuilderService: builderService,
    generationController: generationController,
    streamController: streamController,
    contextProvider: context,
  );
}
