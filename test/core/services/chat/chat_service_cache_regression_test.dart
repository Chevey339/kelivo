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
    tempDir = await Directory.systemTemp.createTemp('kelivo_chat_cache_test_');
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

  Future<(ChatService, String, List<String>)> seedRestartedService({
    int messageCount = 3,
  }) async {
    final writer = createService();
    await writer.init();
    final conversation = await writer.createConversation(title: 'Chat');
    final ids = <String>[];
    for (var i = 0; i < messageCount; i++) {
      final message = await writer.addMessage(
        conversationId: conversation.id,
        role: i.isEven ? 'user' : 'assistant',
        content: 'message $i',
      );
      ids.add(message.id);
    }
    await writer.close();
    services.remove(writer);

    final reader = createService();
    await reader.init();
    return (reader, conversation.id, ids);
  }

  test(
    'first loadTimelinePage on a cold service populates the cache',
    () async {
      final (service, conversationId, ids) = await seedRestartedService();

      final page = await service.loadTimelinePage(conversationId);
      expect(page, isNotNull);
      expect(page!.slots.map((slot) => slot.message.id), orderedEquals(ids));

      // The regression wrote an empty list here: without the order skeleton the
      // intersection in _cacheLoadedMessages dropped every loaded message.
      expect(
        service.getMessages(conversationId).map((message) => message.id),
        orderedEquals(ids),
      );
      expect(service.getMessageCount(conversationId), ids.length);
    },
  );

  test('loadMessages backfills the order skeleton', () async {
    final (service, conversationId, ids) = await seedRestartedService();

    final messages = await service.loadMessages(conversationId);
    expect(messages.map((message) => message.id), orderedEquals(ids));

    // getMessagesRange projects through _messageOrderIds; it stays empty when
    // the full read does not backfill the skeleton.
    expect(
      service
          .getMessagesRange(conversationId, start: 0, limit: ids.length)
          .map((message) => message.id),
      orderedEquals(ids),
    );
  });

  test('paging after a full loadMessages keeps the cache intact', () async {
    final (service, conversationId, ids) = await seedRestartedService(
      messageCount: 5,
    );

    await service.loadMessages(conversationId);
    final page = await service.loadTimelinePage(conversationId, limit: 2);
    expect(page, isNotNull);

    expect(
      service.getMessages(conversationId).map((message) => message.id),
      orderedEquals(ids),
    );
  });

  test('addMessage racing a loadMessages in flight is not dropped from the '
      'order skeleton', () async {
    final (service, conversationId, ids) = await seedRestartedService();

    // Start the full load, then append while its reads are still in
    // flight; the write-back must merge instead of replacing the order
    // skeleton with the pre-append snapshot.
    final loadFuture = service.loadMessages(conversationId);
    final added = await service.addMessage(
      conversationId: conversationId,
      role: 'user',
      content: 'concurrent message',
    );
    await loadFuture;

    expect(service.getMessageCount(conversationId), ids.length + 1);
    // Pre-fix, the write-back replaced the order skeleton with the
    // pre-append snapshot; _loadMessageOrder short-circuits on the cached
    // skeleton, so the appended id stayed lost (count back at 3 and the
    // reload below returned without it) until a restart rebuilt the order.
    final reloaded = await service.loadMessages(conversationId);
    expect(
      reloaded.map((message) => message.id),
      orderedEquals([...ids, added.id]),
    );
    expect(
      service
          .getMessagesRange(conversationId, start: 0, limit: 10)
          .map((message) => message.id),
      orderedEquals([...ids, added.id]),
    );
  });

  test('deleteMessages keeps cache, order, and count consistent', () async {
    final service = createService();
    await service.init();
    final conversation = await service.createConversation(title: 'Chat');
    final ids = <String>[];
    for (var i = 0; i < 3; i++) {
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: i.isEven ? 'user' : 'assistant',
        content: 'message $i',
      );
      ids.add(message.id);
    }
    await service.loadMessages(conversation.id);

    final deleted = await service.deleteMessages(
      conversationId: conversation.id,
      messageIds: {ids[1]},
      versionSelectionChanges: const {},
    );
    expect(deleted, {ids[1]});

    final remaining = [ids[0], ids[2]];
    expect(service.getMessageCount(conversation.id), remaining.length);

    final page = await service.loadTimelinePage(conversation.id);
    expect(page, isNotNull);
    expect(
      service.getMessages(conversation.id).map((message) => message.id),
      orderedEquals(remaining),
    );
    expect(
      service
          .getMessagesRange(conversation.id, start: 0, limit: 10)
          .map((message) => message.id),
      orderedEquals(remaining),
    );
  });
}
