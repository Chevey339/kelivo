import 'dart:async';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/conversation_mcp_settings.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

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
  final services = <ChatService>[];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_conversation_mcp_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    SandboxPathResolver.debugSetDirs(
      docsDir: tempDir.path,
      supportDir: tempDir.path,
    );
  });

  tearDown(() async {
    for (final service in services) {
      await service.close();
    }
    services.clear();
    await Hive.close();
    SandboxPathResolver.debugSetDirs(docsDir: null, supportDir: null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ChatService createService() {
    final service = ChatService();
    services.add(service);
    return service;
  }

  for (final ids in <List<String>>[
    ['remote'],
    [],
  ]) {
    test(
      'MCP override $ids survives restart, duplication and both fork modes',
      () async {
        const assistant = Assistant(
          id: 'a',
          name: 'A',
          allowConversationMcp: true,
          mcpServerIds: ['default'],
        );
        final chat = createService();
        final conversation = await chat.createConversation(
          title: 'MCP',
          assistantId: 'a',
        );
        final message = await chat.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'hello',
        );
        final other = await chat.createConversation(
          title: 'Other',
          assistantId: 'a',
        );
        await chat.updateConversationExtras(
          conversation.id,
          (extras) => {...extras, 'keep': true},
        );
        final revision = chat.contextRevision(conversation.id);
        await chat.setConversationMcpServers(conversation.id, ids);
        expect(chat.contextRevision(conversation.id), revision + 1);
        expect(
          ConversationMcpSettings.effectiveServerIds(
            assistant,
            chat.getConversation(other.id),
          ),
          ['default'],
        );
        await chat.close();
        services.remove(chat);

        final reopened = createService();
        await reopened.init();
        final saved = reopened.getConversation(conversation.id)!;
        expect(saved.mcpServerIds, ids);
        expect(ConversationMcpSettings.isOverridden(saved), isTrue);
        expect(saved.extras['keep'], isTrue);
        final copy = await reopened.duplicateConversation(conversation.id);
        expect(
          ConversationMcpSettings.effectiveServerIds(assistant, copy),
          ids,
        );
        expect(ConversationMcpSettings.isOverridden(copy), isTrue);
        for (final preserve in [false, true]) {
          final fork = await reopened.forkConversationAtRevision(
            sourceConversationId: conversation.id,
            sourceRevisionId: message.id,
            title: 'Fork',
            preserveVersions: preserve,
          );
          expect(ConversationMcpSettings.isOverridden(fork), isTrue);
          expect(
            ConversationMcpSettings.effectiveServerIds(assistant, fork),
            ids,
          );
        }
        await reopened.setConversationMcpServers(conversation.id, null);
        final reset = reopened.getConversation(conversation.id)!;
        expect(ConversationMcpSettings.isOverridden(reset), isFalse);
        expect(ConversationMcpSettings.effectiveServerIds(assistant, reset), [
          'default',
        ]);
        expect(reset.extras['keep'], isTrue);
        expect(
          ConversationMcpSettings.effectiveServerIds(
            assistant,
            reopened.getConversation(copy!.id),
          ),
          ids,
        );
      },
    );
  }

  test(
    'new-chat MCP overrides survive draft restart and first-message persistence',
    () async {
      final chat = createService();
      final draft = await chat.createDraftConversation(
        assistantId: 'a',
        reuseNewEntry: true,
      );
      await chat.setConversationMcpServers(draft.id, ['remote', 'remote']);
      await chat.close();
      services.remove(chat);
      final reopened = createService();
      final restored = await reopened.createDraftConversation(
        assistantId: 'a',
        reuseNewEntry: true,
      );
      expect(restored.id, draft.id);
      expect(restored.mcpServerIds, ['remote']);
      expect(ConversationMcpSettings.isOverridden(restored), isTrue);
      await reopened.setConversationMcpServers(restored.id, []);
      await reopened.addMessage(
        conversationId: restored.id,
        role: 'user',
        content: 'hello',
      );
      final persisted = await reopened.chatRepositoryOrNull!.getConversation(
        restored.id,
      );
      expect(ConversationMcpSettings.isOverridden(persisted), isTrue);
      expect(persisted!.mcpServerIds, isEmpty);
    },
  );

  for (final ids in <List<String>>[
    [],
    ['remote'],
  ]) {
    test(
      'temporary message forks and compressed conversations preserve MCP $ids',
      () async {
        final chat = createService();
        final source = await chat.createDraftConversation(
          assistantId: 'a',
          temporary: true,
        );
        final message = await chat.addMessage(
          conversationId: source.id,
          role: 'user',
          content: 'hello',
        );
        await chat.setConversationMcpServers(source.id, ids);
        final fork = await chat.forkConversationFromMessages(
          title: 'Fork',
          assistantId: 'a',
          sourceMessages: [message],
          activate: false,
        );
        expect(ConversationMcpSettings.isOverridden(fork), isTrue);
        expect(fork.mcpServerIds, ids);
        final snapshot = await chat.loadContextSnapshot(source.id);
        final groupId = message.groupId ?? message.id;
        final compressed = await chat.createCompressedConversation(
          source.id,
          ContextOperation(
            id: 'compress',
            kind: ContextOperationKind.compress,
            anchorGroupId: groupId,
            appliedAfterGroupId: groupId,
            sourceGroups: [groupId],
            dependencies: [],
            createdAt: DateTime.now(),
            summary: 'Summary',
            originalSummary: 'Summary',
          ),
          expectedFingerprint: snapshot.fingerprint,
          retained: [],
        );
        expect(ConversationMcpSettings.isOverridden(compressed), isTrue);
        expect(compressed.mcpServerIds, ids);
        for (final id in [fork.id, compressed.id]) {
          final saved = await chat.chatRepositoryOrNull!.getConversation(id);
          expect(ConversationMcpSettings.isOverridden(saved), isTrue);
          expect(saved!.mcpServerIds, ids);
        }
      },
    );
  }

  for (final mode in ['append', 'send', 'regenerate', 'assistant']) {
    for (final selection in <List<String>?>[
      [],
      ['other'],
      null,
    ]) {
      test('MCP edit $selection is ordered with $mode publication', () async {
        final chat = createService();
        final draft = await chat.createDraftConversation(
          assistantId: 'a',
          reuseNewEntry: true,
        );
        await chat.setConversationMcpServers(draft.id, ['remote']);
        if (mode == 'regenerate' || mode == 'assistant') {
          await chat.addMessage(
            conversationId: draft.id,
            role: 'user',
            content: 'hello',
            groupId: 'user-group',
          );
          await chat.addMessage(
            conversationId: draft.id,
            role: 'assistant',
            content: 'reply',
            groupId: 'reply-group',
            version: 0,
          );
        }
        final repository = chat.chatRepositoryOrNull!;
        await repository.composerDrafts.flush();
        final entered = Completer<void>();
        final release = Completer<void>();
        final barrier = repository.genUiStates.transaction(() async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        final promotion = switch (mode) {
          'send' => chat.beginSendGeneration(
            conversationId: draft.id,
            userParts: const [TextPart('hello')],
            modelId: 'model',
            providerId: 'provider',
          ),
          'regenerate' => chat.beginRegeneration(
            conversationId: draft.id,
            modelId: 'model',
            providerId: 'provider',
            groupId: 'reply-group',
            version: 1,
            truncateFuture: false,
          ),
          'assistant' => chat.beginAssistantGeneration(
            conversationId: draft.id,
            modelId: 'model',
            providerId: 'provider',
            anchorGroupId: 'user-group',
            truncateFuture: false,
          ),
          _ => chat.addMessage(
            conversationId: draft.id,
            role: 'user',
            content: 'hello',
          ),
        };
        var editCompleted = false;
        final edit = chat
            .setConversationMcpServers(draft.id, selection)
            .then((_) => editCompleted = true);
        await pumpEventQueue();
        expect(
          editCompleted,
          isFalse,
          reason:
              'The edit must wait for the captured conversation to be published',
        );
        release.complete();
        await barrier;
        await promotion;
        await edit;
        final cached = chat.getConversation(draft.id)!;
        final stored = (await repository.getConversation(draft.id))!;
        expect(cached.mcpServerIds, selection ?? []);
        expect(stored.mcpServerIds, selection ?? []);
        expect(ConversationMcpSettings.isOverridden(cached), selection != null);
        expect(ConversationMcpSettings.isOverridden(stored), selection != null);
      });
    }
  }

  test('temporary chats keep MCP overrides in memory', () async {
    final chat = createService();
    final draft = await chat.createDraftConversation(
      assistantId: 'a',
      temporary: true,
    );
    await chat.setConversationMcpServers(draft.id, ['remote']);
    expect(chat.getConversation(draft.id)!.mcpServerIds, ['remote']);
    expect(
      ConversationMcpSettings.isOverridden(chat.getConversation(draft.id)),
      isTrue,
    );
    expect(await chat.chatRepositoryOrNull!.getConversation(draft.id), isNull);
    await chat.setConversationMcpServers(draft.id, null);
    expect(
      ConversationMcpSettings.isOverridden(chat.getConversation(draft.id)),
      isFalse,
    );
  });
}
