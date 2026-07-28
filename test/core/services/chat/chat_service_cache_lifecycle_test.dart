import 'dart:io';

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

      expect(service.getMessageCount(conversation.id), 0);
      expect(service.getMessages(conversation.id), isEmpty);
      expect(service.getMessageIndex(conversation.id, user.id), -1);
      expect(service.getToolEvents(assistant.id), isEmpty);
      expect(service.getGeminiThoughtSignature(assistant.id), isNull);
      expect(
        service.getFirstMessageIndicesForGroups(conversation.id, [user.id]),
        isEmpty,
      );
    });

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

    test('honors the conversation truncateIndex', () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(title: 'Chat');
      await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'hidden question',
      );
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
      await service.loadMessages(conversation.id);

      service.getConversation(conversation.id)!.truncateIndex = 1;

      final source = await service.generateTitleSource(conversation.id);
      expect(source, 'User: visible question\n\nAssistant: visible answer');
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
