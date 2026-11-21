import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_history.dart';

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
      'kelivo_chat_lifecycle_test_',
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

  ChatService createService() {
    final service = ChatService();
    services.add(service);
    return service;
  }

  group('cache lifecycle', () {
    for (final sameConversation in [false, true]) {
      test(
        'finishing a large reply keeps another recovered native turn (same chat=$sameConversation)',
        () async {
          final service = createService();
          await service.init();
          final first = await service.createConversation();
          final second = sameConversation
              ? first
              : await service.createConversation();
          final active = await service.addMessage(
            conversationId: first.id,
            role: 'assistant',
            content: '',
            isStreaming: true,
          );
          final recovered = await service.addMessage(
            conversationId: second.id,
            role: 'assistant',
            content: 'prior',
          );
          await service.setProviderArtifact(
            recovered.id,
            responsesTurnArtifactKind,
            'prior native rounds',
          );
          final held = (await service.loadMessagesByIds([recovered.id])).single;
          final pressure = await service.createConversation(activate: false);
          await service.addMessage(
            conversationId: pressure.id,
            role: 'user',
            content: 'x' * (5 << 20),
          );
          expect(
            service.getMessages(second.id).any((m) => m.id == recovered.id),
            isFalse,
          );
          // The real recovery path reopens the persisted row before receiving
          // new chunks. A late checkpoint alone cannot resurrect a finished turn.
          await service.updateMessageSilent(recovered.id, isStreaming: true);
          await service.setProviderArtifact(
            recovered.id,
            responsesTurnArtifactKind,
            'new native rounds',
          );
          await service.updateStreamingCheckpointSilent(
            active.copyWith(content: 'x' * (5 << 20), isStreaming: false),
            const [],
          );
          expect(
            service.getProviderArtifact(
              recovered.id,
              responsesTurnArtifactKind,
            ),
            'new native rounds',
          );
          final resumed = held.copyWith(
            isStreaming: true,
            content: 'new answer',
          );
          await service.updateStreamingCheckpointSilent(resumed, const []);
          expect(
            service.getProviderArtifactForMessage(
              resumed,
              responsesTurnArtifactKind,
            ),
            'new native rounds',
          );
          expect(
            (await service.loadMessagesByIds([recovered.id])).single.content,
            'new answer',
          );
        },
      );
    }

    test(
      'a large reply is protected while running and obeys the cache budget after completion',
      () async {
        final service = createService();
        await service.init();
        final conversation = await service.createConversation(
          title: 'Long run',
        );
        final reply = await service.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: '',
          isStreaming: true,
        );
        final text = '长' * (5 * 1024 * 1024);
        final checkpoint = reply.copyWith(content: text);
        await service.updateStreamingCheckpointSilent(checkpoint, const []);
        service.releaseInactiveMessageCaches({});
        expect(
          service.getMessages(conversation.id).single.content.length,
          text.length,
        );
        await service.updateStreamingCheckpointSilent(
          checkpoint.copyWith(isStreaming: false),
          const [],
        );
        expect(
          service.debugCachedMessageBytes,
          lessThanOrEqualTo(8 * 1024 * 1024),
        );
        expect(
          (await service.loadMessagesByIds([reply.id])).single.content,
          text,
        );
      },
    );

    test(
      'background release keeps temporary and active replies and reloads durable history',
      () async {
        final service = createService();
        await service.init();
        final cold = await service.createConversation(title: 'Earlier chat');
        final saved = await service.addMessage(
          conversationId: cold.id,
          role: 'assistant',
          content: 'saved answer',
        );
        await service.setToolEvents(saved.id, [
          {
            'id': 't',
            'name': 'calculate',
            'arguments': <String, dynamic>{},
            'content': '12',
          },
        ]);
        final active = await service.createConversation(
          title: 'Still generating',
        );
        final live = await service.addMessage(
          conversationId: active.id,
          role: 'assistant',
          content: 'partial',
          isStreaming: true,
        );
        final temp = await service.createDraftConversation(temporary: true);
        final private = await service.addMessage(
          conversationId: temp.id,
          role: 'user',
          content: 'temporary',
        );
        service.releaseInactiveMessageCaches({active.id});
        expect(service.getMessages(cold.id), isEmpty);
        expect(service.getMessages(active.id).single.id, live.id);
        expect(service.getMessages(temp.id).single.id, private.id);
        final restored = (await service.loadMessages(cold.id)).single;
        expect(restored.content, 'saved answer');
        expect(
          service.getToolEventsForMessage(restored).single['content'],
          '12',
        );
      },
    );

    test(
      'oversized conversation is tail-trimmed without evicting others',
      () async {
        final service = createService();
        await service.init();
        final large = await service.createConversation(title: 'Large');
        final largeIds = <String>[];
        for (var i = 0; i < 3; i++) {
          final message = await service.addMessage(
            conversationId: large.id,
            role: 'user',
            content: 'x' * (3 * 1024 * 1024),
          );
          largeIds.add(message.id);
        }
        await service.loadMessages(large.id);

        // Switching away enforces the budget: the 18MB conversation alone
        // exceeds 8MB, so it keeps only its most recent tail instead of
        // cascading an eviction of every other cached conversation.
        final small = await service.createConversation(title: 'Small');
        final smallMessage = await service.addMessage(
          conversationId: small.id,
          role: 'user',
          content: 'small',
        );
        await service.loadMessages(small.id);

        expect(service.getMessages(large.id).map((message) => message.id), [
          largeIds.last,
        ]);
        expect(service.isConversationFullyCached(large.id), isFalse);
        expect(service.getMessageCount(large.id), 3);
        expect(service.getMessages(small.id).map((message) => message.id), [
          smallMessage.id,
        ]);
      },
    );

    test(
      'write paths refresh the LRU position of a cached conversation',
      () async {
        final service = createService();
        await service.init();
        final first = await service.createConversation(title: 'A');
        await service.addMessage(
          conversationId: first.id,
          role: 'user',
          content: 'a' * (2 * 1024 * 1024),
        );
        await service.loadMessages(first.id);

        final second = await service.createConversation(title: 'B');
        await service.addMessage(
          conversationId: second.id,
          role: 'user',
          content: 'b' * (2 * 1024 * 1024),
        );
        await service.loadMessages(second.id);

        // Both fit exactly under the byte budget; a write against the first
        // conversation must count as an access so it survives the next
        // enforcement round.
        await service.addMessage(
          conversationId: first.id,
          role: 'user',
          content: 'x',
        );

        final third = await service.createConversation(title: 'C');
        final cMessage = await service.addMessage(
          conversationId: third.id,
          role: 'user',
          content: 'c' * (2 * 1024 * 1024),
        );
        await service.loadMessages(third.id);

        expect(service.getMessages(first.id), isNotEmpty);
        expect(service.getMessages(second.id), isEmpty);
        expect(service.getMessages(third.id).map((message) => message.id), [
          cMessage.id,
        ]);
      },
    );

    test('deleteConversation clears cached order, count, artifacts, and group '
        'indices', () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(title: 'Chat');
      final user = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'question',
      );
      final assistant = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'answer',
      );
      await service.loadMessages(conversation.id);
      await service.setToolEvents(assistant.id, [
        <String, dynamic>{
          'id': 'tool-1',
          'name': 'search',
          'arguments': <String, dynamic>{},
          'content': 'result',
        },
      ]);
      await service.setGeminiThoughtSignature(assistant.id, 'sig');
      final indices = await service.loadFirstMessageIndicesForGroups(
        conversation.id,
        [user.id],
      );
      expect(indices, isNotEmpty);

      await service.deleteConversation(conversation.id);

      expect(service.getMessageCount(conversation.id), -1);
      expect(service.isMessageCountKnown(conversation.id), isFalse);
      expect(service.getMessages(conversation.id), isEmpty);
      expect(service.getMessageIndex(conversation.id, user.id), -1);
      expect(service.getToolEvents(assistant.id), isEmpty);
      expect(service.getGeminiThoughtSignature(assistant.id), isNull);
      expect(
        service.getFirstMessageIndicesForGroups(conversation.id, [user.id]),
        isEmpty,
      );
    });

    test(
      'a migrated legacy signature is readable before its write lands',
      () async {
        final service = createService();
        await service.init();
        final conversation = await service.createConversation(title: 'Chat');
        final assistant = await service.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: 'answer',
        );
        await service.loadMessages(conversation.id);

        final cleaned = service.migrateLegacyGeminiThoughtSignature(
          'answer\n<!-- gemini_thought_signatures:{"text":{"k":"ts","v":"sig"}} -->',
          assistant.id,
        );

        expect(cleaned, 'answer');
        expect(
          service.getGeminiThoughtSignature(assistant.id),
          '{"text":{"k":"ts","v":"sig"}}',
        );
        // Let the unawaited write finish before teardown closes the database.
        await service.setToolEvents(assistant.id, const []);
      },
    );

    test('deleteMessages invalidates cached group indices', () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(title: 'Chat');
      final first = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'first',
      );
      final second = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'second',
      );
      final indices = await service.loadFirstMessageIndicesForGroups(
        conversation.id,
        [first.id, second.id],
      );
      expect(indices, {first.id: 0, second.id: 1});

      await service.deleteMessages(
        conversationId: conversation.id,
        messageIds: {first.id},
        versionSelectionChanges: const {},
      );

      // The stale entry must be dropped, not served.
      expect(
        service.getFirstMessageIndicesForGroups(conversation.id, [
          first.id,
          second.id,
        ]),
        isEmpty,
      );
      final reloaded = await service.loadFirstMessageIndicesForGroups(
        conversation.id,
        [second.id],
      );
      // Indices are raw message_order values; deletion leaves the gap.
      expect(reloaded, {second.id: 1});
    });
  });

  group('generateTitleSource', () {
    test(
      'serves a fully cached conversation with version collapsing',
      () async {
        final service = createService();
        await service.init();
        final conversation = await service.createConversation(title: 'Chat');
        await service.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'hello',
        );
        final original = await service.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: 'old answer',
        );
        final regenerated = await service.appendMessageVersion(
          messageId: original.id,
          content: 'new answer',
        );
        expect(regenerated, isNotNull);
        await service.loadMessages(conversation.id);
        expect(service.isConversationFullyCached(conversation.id), isTrue);

        final source = await service.generateTitleSource(conversation.id);

        expect(source, 'User: hello\n\nAssistant: new answer');
      },
    );

    test('honors a logical truncateIndex after regeneration', () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(title: 'Chat');
      await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'hidden question',
      );
      final original = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'hidden answer',
      );
      await service.appendMessageVersion(
        messageId: original.id,
        content: 'regenerated hidden answer',
      );
      await service.clearConversationContext(conversation.id);
      await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'visible question',
      );
      await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'visible answer',
      );

      final cold = await service.generateTitleSource(conversation.id);
      await service.loadMessages(conversation.id);
      final warm = await service.generateTitleSource(conversation.id);

      expect(cold, 'User: visible question\n\nAssistant: visible answer');
      expect(warm, cold);
    });

    test(
      'pages from the tail on a cold cache and stops at 3000 chars',
      () async {
        final writer = createService();
        await writer.init();
        final conversation = await writer.createConversation(title: 'Chat');
        for (var i = 0; i < 40; i++) {
          await writer.addMessage(
            conversationId: conversation.id,
            role: i.isEven ? 'user' : 'assistant',
            content: 'message-$i-${'x' * 180}',
          );
        }
        await writer.close();
        services.remove(writer);

        final service = createService();
        await service.init();
        expect(service.isConversationFullyCached(conversation.id), isFalse);

        final source = await service.generateTitleSource(conversation.id);

        expect(source.length, lessThanOrEqualTo(3000));
        expect(source, contains('message-2'));
        expect(source, isNot(contains('message-0-')));
        // Only a tail window was loaded into the cache, not the whole history.
        final cached = service.getMessages(conversation.id);
        expect(cached, isNotEmpty);
        expect(cached.length, lessThan(40));
        expect(service.isConversationFullyCached(conversation.id), isFalse);
      },
    );

    test('cold and fully cached loads produce the same short source', () async {
      final writer = createService();
      await writer.init();
      final conversation = await writer.createConversation(title: 'Chat');
      for (var i = 0; i < 5; i++) {
        await writer.addMessage(
          conversationId: conversation.id,
          role: i.isEven ? 'user' : 'assistant',
          content: 'short message $i',
        );
      }
      await writer.close();
      services.remove(writer);

      final service = createService();
      await service.init();

      final cold = await service.generateTitleSource(conversation.id);
      await service.loadMessages(conversation.id);
      final warm = await service.generateTitleSource(conversation.id);

      expect(cold, warm);
      expect(warm, contains('User: short message 0'));
      expect(warm, contains('Assistant: short message 1'));
    });

    test('cold and fully cached loads agree on the tail of a long '
        'conversation', () async {
      final writer = createService();
      await writer.init();
      final conversation = await writer.createConversation(title: 'Chat');
      for (var i = 0; i < 40; i++) {
        await writer.addMessage(
          conversationId: conversation.id,
          role: i.isEven ? 'user' : 'assistant',
          content: 'message-$i-${'x' * 180}',
        );
      }
      await writer.close();
      services.remove(writer);

      final service = createService();
      await service.init();
      expect(service.isConversationFullyCached(conversation.id), isFalse);

      final cold = await service.generateTitleSource(conversation.id);
      await service.loadMessages(conversation.id);
      expect(service.isConversationFullyCached(conversation.id), isTrue);
      final warm = await service.generateTitleSource(conversation.id);

      // Both paths feed the model the same tail window; cache state must not
      // change the title source.
      expect(warm, cold);
      expect(warm.length, lessThanOrEqualTo(3000));
      expect(warm, contains('message-2'));
      expect(warm, isNot(contains('message-0-')));
    });

    test('returns empty for unknown or empty conversations', () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(title: 'Chat');

      expect(await service.generateTitleSource('missing'), isEmpty);
      expect(await service.generateTitleSource(conversation.id), isEmpty);
    });
  });

  group('getMessageIds', () {
    test('matches loadMessages ids without hydrating the cache', () async {
      final writer = createService();
      await writer.init();
      final conversation = await writer.createConversation(title: 'Chat');
      final first = await writer.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'one',
      );
      final second = await writer.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'two',
      );
      await writer.close();
      services.remove(writer);

      final service = createService();
      await service.init();
      expect(service.isConversationFullyCached(conversation.id), isFalse);

      final ids = await service.getMessageIds(conversation.id);

      expect(ids, [first.id, second.id]);
      // The ids-only path must not pull message bodies into the cache;
      // import merge dedup relies on this to avoid flushing the LRU.
      expect(service.getMessages(conversation.id), isEmpty);
      expect(service.isConversationFullyCached(conversation.id), isFalse);

      final loaded = await service.loadMessages(conversation.id);
      expect(loaded.map((message) => message.id), ids);
    });
  });
}
