import 'package:Kelivo/core/models/message_part.dart';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

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
  final services = <ChatService>[];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_chat_list_revision_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    for (final service in services) {
      await service.close();
    }
    services.clear();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ChatService createService({Future<String> Function(File)? assetContentHash}) {
    final service = ChatService(assetContentHash: assetContentHash);
    services.add(service);
    return service;
  }

  group('conversationListRevision', () {
    test('bumps on create, rename, pin, mcp, assistant move, delete', () async {
      final service = createService();
      await service.init();
      final initial = service.conversationListRevision;

      final conversation = await service.createConversation(title: 'A');
      expect(service.conversationListRevision, greaterThan(initial));

      var last = service.conversationListRevision;
      await service.renameConversation(conversation.id, 'B');
      expect(service.conversationListRevision, greaterThan(last));

      last = service.conversationListRevision;
      await service.togglePinConversation(conversation.id);
      expect(service.conversationListRevision, greaterThan(last));

      last = service.conversationListRevision;
      await service.setConversationMcpServers(conversation.id, ['server-1']);
      expect(service.conversationListRevision, greaterThan(last));

      last = service.conversationListRevision;
      await service.moveConversationToAssistant(
        conversationId: conversation.id,
        assistantId: 'assistant-1',
      );
      expect(service.conversationListRevision, greaterThan(last));

      last = service.conversationListRevision;
      await service.deleteConversation(conversation.id);
      expect(service.conversationListRevision, greaterThan(last));
    });

    test('duplicate is cached and bumps the list revision', () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(title: 'A');
      final last = service.conversationListRevision;

      final duplicate = await service.duplicateConversation(conversation.id);

      expect(duplicate, isNotNull);
      expect(duplicate!.id, isNot(conversation.id));
      expect(service.getConversation(duplicate.id), same(duplicate));
      expect(service.conversationListRevision, greaterThan(last));
    });

    test('does not bump on selection, streaming, or summary updates', () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(title: 'A');
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'hello',
      );

      var last = service.conversationListRevision;
      service.setCurrentConversation(conversation.id);
      expect(service.conversationListRevision, last);

      await service.updateMessage(message.id, content: 'hello world');
      expect(service.conversationListRevision, last);

      await service.updateMessageSilent(message.id, content: 'hello again');
      expect(service.conversationListRevision, last);

      await service.updateStreamingCheckpointSilent(message, const []);
      expect(service.conversationListRevision, last);

      await service.updateConversationSummary(conversation.id, 'summary', 1);
      expect(service.conversationListRevision, last);

      await service.updateConversationSuggestions(conversation.id, ['s']);
      expect(service.conversationListRevision, last);
    });

    test('assistant move invalidates only memory snapshot prompts', () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(
        title: 'A',
        assistantId: 'assistant-a',
      );
      final snapshotMessage = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'snapshot',
      );
      final plainMessage = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'plain',
      );
      final repository = service.chatRepositoryOrNull!;
      await repository.freezeMessagePrompt(
        revisionId: snapshotMessage.id,
        conversationId: conversation.id,
        payload: 'assistant A memory',
        carriesMemorySnapshot: true,
        injectedMemoryHash: const Value('assistant-a-hash'),
      );
      await repository.putMessagePrompt(
        revisionId: plainMessage.id,
        conversationId: conversation.id,
        payload: 'plain frozen prompt',
        carriesMemorySnapshot: false,
      );

      await service.moveConversationToAssistant(
        conversationId: conversation.id,
        assistantId: 'assistant-b',
      );

      expect(await repository.getMessagePrompt(snapshotMessage.id), isNull);
      expect(
        (await repository.getMessagePrompt(plainMessage.id))?.payload,
        'plain frozen prompt',
      );
      expect(
        await repository.getConversationInjectedMemoryHash(conversation.id),
        isNull,
      );
      expect(
        service.getConversation(conversation.id)?.assistantId,
        'assistant-b',
      );
    });

    test('assistant move is rejected while generation is active', () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(
        title: 'A',
        assistantId: 'assistant-a',
      );
      await service.beginSendGeneration(
        conversationId: conversation.id,
        userParts: const [TextPart('hello')],
        modelId: 'model',
        providerId: 'provider',
      );

      final moved = await service.moveConversationToAssistant(
        conversationId: conversation.id,
        assistantId: 'assistant-b',
      );

      expect(moved, isFalse);
      expect(
        service.getConversation(conversation.id)?.assistantId,
        'assistant-a',
      );
    });

    test('persisted message append bumps; temporary draft does not', () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(title: 'A');

      final last = service.conversationListRevision;
      await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'hello',
      );
      expect(service.conversationListRevision, greaterThan(last));

      final temporary = await service.createDraftConversation(
        title: 'Temp',
        temporary: true,
      );
      final beforeTemporary = service.conversationListRevision;
      await service.addMessage(
        conversationId: temporary.id,
        role: 'user',
        content: 'secret',
      );
      expect(service.conversationListRevision, beforeTemporary);
    });
  });

  group('batch conversation mutations', () {
    test('deleteConversations bumps and notifies once', () async {
      final service = createService();
      await service.init();
      final a = await service.createConversation(title: 'A');
      final b = await service.createConversation(title: 'B');
      final c = await service.createConversation(title: 'C');
      final last = service.conversationListRevision;
      var notifications = 0;
      service.addListener(() => notifications++);

      final count = await service.deleteConversations([
        a.id,
        b.id,
        c.id,
        a.id,
        'missing',
      ]);

      expect(count, 3);
      expect(service.conversationListRevision, last + 1);
      expect(notifications, 1);
      expect(service.getConversation(a.id), isNull);
      expect(service.getConversation(b.id), isNull);
      expect(service.getConversation(c.id), isNull);
    });

    test('deleteConversations on drafts still bumps once', () async {
      final service = createService();
      await service.init();
      final draft = await service.createDraftConversation(title: 'Draft');
      final last = service.conversationListRevision;
      var notifications = 0;
      service.addListener(() => notifications++);

      final count = await service.deleteConversations([draft.id]);

      expect(count, 1);
      expect(service.conversationListRevision, last + 1);
      expect(notifications, 1);
      expect(service.getConversation(draft.id), isNull);
    });

    test(
      'deleteConversations no-ops without notify when nothing matches',
      () async {
        final service = createService();
        await service.init();
        final last = service.conversationListRevision;
        var notifications = 0;
        service.addListener(() => notifications++);

        final count = await service.deleteConversations(['missing']);

        expect(count, 0);
        expect(service.conversationListRevision, last);
        expect(notifications, 0);
      },
    );

    test('setConversationsPinned sets target and skips unchanged', () async {
      final service = createService();
      await service.init();
      final a = await service.createConversation(title: 'A');
      final b = await service.createConversation(title: 'B');
      final last = service.conversationListRevision;
      var notifications = 0;
      service.addListener(() => notifications++);

      final count = await service.setConversationsPinned([a.id, b.id], true);

      expect(count, 2);
      expect(service.getConversation(a.id)!.isPinned, isTrue);
      expect(service.getConversation(b.id)!.isPinned, isTrue);
      expect(service.conversationListRevision, last + 1);
      expect(notifications, 1);

      notifications = 0;
      final again = await service.setConversationsPinned([a.id, b.id], true);
      expect(again, 0);
      expect(service.conversationListRevision, last + 1);
      expect(notifications, 0);

      notifications = 0;
      final unpinned = await service.setConversationsPinned([a.id], false);
      expect(unpinned, 1);
      expect(service.getConversation(a.id)!.isPinned, isFalse);
      expect(service.getConversation(b.id)!.isPinned, isTrue);
      expect(service.conversationListRevision, last + 2);
      expect(notifications, 1);
    });

    test('setConversationsPinned on drafts notifies once', () async {
      final service = createService();
      await service.init();
      final draft = await service.createDraftConversation(title: 'Draft');
      final last = service.conversationListRevision;
      var notifications = 0;
      service.addListener(() => notifications++);

      final count = await service.setConversationsPinned([draft.id], true);

      expect(count, 1);
      expect(draft.isPinned, isTrue);
      expect(service.conversationListRevision, last + 1);
      expect(notifications, 1);
    });

    test('moveConversationsToAssistant bumps and notifies once', () async {
      final service = createService();
      await service.init();
      final a = await service.createConversation(
        title: 'A',
        assistantId: 'assistant-a',
      );
      final b = await service.createConversation(
        title: 'B',
        assistantId: 'assistant-a',
      );
      final last = service.conversationListRevision;
      var notifications = 0;
      service.addListener(() => notifications++);

      final count = await service.moveConversationsToAssistant(
        conversationIds: [a.id, b.id, a.id],
        assistantId: 'assistant-b',
      );

      expect(count, 2);
      expect(service.conversationListRevision, last + 1);
      expect(notifications, 1);
      expect(service.getConversation(a.id)?.assistantId, 'assistant-b');
      expect(service.getConversation(b.id)?.assistantId, 'assistant-b');
      expect(service.getConversation(a.id)?.injectedMemoryHash, isNull);
    });

    test('moveConversationsToAssistant skips already-on-target', () async {
      final service = createService();
      await service.init();
      final a = await service.createConversation(
        title: 'A',
        assistantId: 'assistant-a',
      );
      final last = service.conversationListRevision;
      var notifications = 0;
      service.addListener(() => notifications++);

      final count = await service.moveConversationsToAssistant(
        conversationIds: [a.id],
        assistantId: 'assistant-a',
      );

      expect(count, 0);
      expect(service.conversationListRevision, last);
      expect(notifications, 0);
    });

    test(
      'moveConversationsToAssistant skips ids with active generation',
      () async {
        final service = createService();
        await service.init();
        final a = await service.createConversation(
          title: 'A',
          assistantId: 'assistant-a',
        );
        final b = await service.createConversation(
          title: 'B',
          assistantId: 'assistant-a',
        );
        await service.beginSendGeneration(
          conversationId: a.id,
          userParts: const [TextPart('hello')],
          modelId: 'model',
          providerId: 'provider',
        );
        final last = service.conversationListRevision;
        var notifications = 0;
        service.addListener(() => notifications++);

        final count = await service.moveConversationsToAssistant(
          conversationIds: [a.id, b.id],
          assistantId: 'assistant-b',
        );

        expect(count, 1);
        expect(service.conversationListRevision, last + 1);
        expect(notifications, 1);
        expect(service.getConversation(a.id)?.assistantId, 'assistant-a');
        expect(service.getConversation(b.id)?.assistantId, 'assistant-b');
      },
    );
  });

  group('sorted conversation cache', () {
    test(
      'returns equal lists across calls and caller mutation is isolated',
      () async {
        final service = createService();
        await service.init();
        await service.createConversation(title: 'A');
        await service.createConversation(title: 'B');

        final first = service.getAllConversations();
        final second = service.getAllConversations();
        expect(second.map((c) => c.id), first.map((c) => c.id));
        expect(
          service.conversationListRevision,
          service.conversationListRevision,
        );

        first.clear();
        expect(service.getAllConversations(), hasLength(2));
      },
    );

    test('rename invalidates the cached order', () async {
      final service = createService();
      await service.init();
      final older = await service.createConversation(title: 'Older');
      final newer = await service.createConversation(title: 'Newer');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(service.getAllConversations().first.id, newer.id);

      await service.renameConversation(older.id, 'Older renamed');
      expect(service.getAllConversations().first.id, older.id);
      expect(service.getConversation(older.id)!.title, 'Older renamed');
    });
  });

  group('resolveImageContentHashes cache', () {
    test('hashes each unchanged file once and rehashes after change', () async {
      var hashCalls = 0;
      final service = createService(
        assetContentHash: (file) async {
          hashCalls++;
          final bytes = await file.readAsBytes();
          return 'hash-${bytes.length}';
        },
      );
      await service.init();

      final image = File('${tempDir.path}/images/pic.png');
      await image.parent.create(recursive: true);
      await image.writeAsBytes(List.filled(8, 1));

      final first = await service.resolveImageContentHashes([image.path]);
      expect(first[image.path], 'hash-8');
      expect(hashCalls, 1);

      final second = await service.resolveImageContentHashes([
        image.path,
        image.path,
      ]);
      expect(second[image.path], 'hash-8');
      expect(hashCalls, 1, reason: 'unchanged file must not be re-read');

      await image.writeAsBytes(List.filled(16, 2), flush: true);
      final third = await service.resolveImageContentHashes([image.path]);
      expect(third[image.path], 'hash-16');
      expect(hashCalls, 2, reason: 'changed file must be re-hashed');
    });

    test('skips missing files and leaves data URLs uncached', () async {
      var hashCalls = 0;
      final service = createService(
        assetContentHash: (file) async {
          hashCalls++;
          return 'hash';
        },
      );
      await service.init();

      final missing = await service.resolveImageContentHashes([
        '${tempDir.path}/images/missing.png',
      ]);
      expect(missing, isEmpty);
      expect(hashCalls, 0);

      const dataUrl = 'data:image/png;base64,aGVsbG8=';
      final first = await service.resolveImageContentHashes([dataUrl]);
      final second = await service.resolveImageContentHashes([dataUrl]);
      expect(first[dataUrl], second[dataUrl]);
      expect(hashCalls, 0);
    });
  });
}
