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
      'kelivo_timeline_fast_path_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    ChatService.timelineCacheFastPathEnabled = true;
  });

  tearDown(() async {
    ChatService.timelineCacheFastPathEnabled = true;
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
    int messageCount = 5,
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

  List<String> pageSignature(LoadedTimelinePage? page) {
    if (page == null) return const <String>['null'];
    return <String>[
      'total=${page.totalSlotCount}',
      'before=${page.hasMoreBefore}',
      'after=${page.hasMoreAfter}',
      for (final slot in page.slots)
        '${slot.identity.slotId}/${slot.identity.revisionId}/'
            '${slot.identity.parentRevisionId}/${slot.identity.versionCount}/'
            '${slot.identity.logicalIndex}/${slot.message.content}',
    ];
  }

  test('tail window is served from memory once fully cached', () async {
    final (service, conversationId, ids) = await seedRestartedService();

    await service.loadMessages(conversationId);
    expect(service.isConversationFullyCached(conversationId), isTrue);

    final page = await service.loadTimelinePage(conversationId);
    expect(service.debugTimelineFastPathHitCount, 1);
    expect(page, isNotNull);
    expect(page!.slots.map((slot) => slot.message.id), orderedEquals(ids));
    expect(page.totalSlotCount, ids.length);
    expect(page.hasMoreBefore, isFalse);
    expect(page.hasMoreAfter, isFalse);
    expect(
      page.slots.map((slot) => slot.identity.logicalIndex),
      orderedEquals([0, 1, 2, 3, 4]),
    );
  });

  test(
    'cold service misses the fast path and loads from the database',
    () async {
      final (service, conversationId, ids) = await seedRestartedService();

      expect(service.isConversationFullyCached(conversationId), isFalse);
      final page = await service.loadTimelinePage(conversationId);
      expect(service.debugTimelineFastPathHitCount, 0);
      expect(page, isNotNull);
      expect(page!.slots.map((slot) => slot.message.id), orderedEquals(ids));
    },
  );

  test('partial tail coverage misses the fast path', () async {
    final (service, conversationId, ids) = await seedRestartedService();

    // First load goes to the database and caches only the window's selected
    // revisions plus the order skeleton; the skeleton is not fully covered,
    // so the second load must still fall back to the database.
    final first = await service.loadTimelinePage(conversationId, limit: 2);
    expect(service.debugTimelineFastPathHitCount, 0);
    expect(service.isConversationFullyCached(conversationId), isFalse);

    final second = await service.loadTimelinePage(conversationId, limit: 2);
    expect(service.debugTimelineFastPathHitCount, 0);
    expect(pageSignature(second), orderedEquals(pageSignature(first)));
    expect(
      second!.slots.map((slot) => slot.message.id),
      orderedEquals(ids.sublist(ids.length - 2)),
    );
    expect(second.hasMoreBefore, isTrue);
    expect(second.totalSlotCount, ids.length);
  });

  test(
    'multi-version group honors the selected revision from memory',
    () async {
      final (service, conversationId, ids) = await seedRestartedService();

      // Add a second version for the last message's group and select the older
      // version, so the selected revision is not the latest one.
      final groupId = ids.last;
      final newer = await service.addMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: 'regenerated',
        groupId: groupId,
        version: 1,
        selectVersion: true,
      );
      await service.setSelectedVersion(conversationId, groupId, 0);

      ChatService.timelineCacheFastPathEnabled = false;
      final dbPage = await service.loadTimelinePage(conversationId);
      ChatService.timelineCacheFastPathEnabled = true;
      expect(service.debugTimelineFastPathHitCount, 0);

      await service.loadMessages(conversationId);
      final cachedPage = await service.loadTimelinePage(conversationId);
      expect(service.debugTimelineFastPathHitCount, 1);
      expect(pageSignature(cachedPage), orderedEquals(pageSignature(dbPage)));

      final tailSlot = cachedPage!.slots.last;
      expect(tailSlot.identity.slotId, groupId);
      expect(tailSlot.identity.revisionId, ids.last);
      expect(tailSlot.identity.versionCount, 2);
      expect(tailSlot.message.content, 'message 4');
      expect(cachedPage.totalSlotCount, ids.length);
      expect(newer.id, isNot(tailSlot.identity.revisionId));
    },
  );

  test('missing selected revision falls back to the database', () async {
    final (service, conversationId, ids) = await seedRestartedService();

    final groupId = ids.last;
    await service.addMessage(
      conversationId: conversationId,
      role: 'assistant',
      content: 'regenerated',
      groupId: groupId,
      version: 1,
      selectVersion: true,
    );

    // Cache only a head window so the selected revision of the multi-version
    // group is not present; the fast path must refuse to judge and miss.
    await service.loadMessagesRange(conversationId, start: 0, limit: 3);
    expect(service.isConversationFullyCached(conversationId), isFalse);

    final page = await service.loadTimelinePage(conversationId);
    expect(service.debugTimelineFastPathHitCount, 0);
    expect(page, isNotNull);
    // The database path returns the selected (regenerated) revision.
    expect(page!.slots.last.message.content, 'regenerated');
    expect(page.slots.last.identity.versionCount, 2);
    expect(page.totalSlotCount, ids.length);
  });

  test('kill switch disables the fast path', () async {
    final (service, conversationId, ids) = await seedRestartedService();

    await service.loadMessages(conversationId);
    ChatService.timelineCacheFastPathEnabled = false;

    final page = await service.loadTimelinePage(conversationId);
    expect(service.debugTimelineFastPathHitCount, 0);
    expect(page, isNotNull);
    expect(page!.slots.map((slot) => slot.message.id), orderedEquals(ids));
  });

  test('cursor-based loads never use the fast path', () async {
    final (service, conversationId, ids) = await seedRestartedService();

    await service.loadMessages(conversationId);
    final page = await service.loadTimelinePage(
      conversationId,
      beforeRevisionId: ids[2],
      limit: 2,
    );
    expect(service.debugTimelineFastPathHitCount, 0);
    expect(page, isNotNull);
    expect(
      page!.slots.map((slot) => slot.message.id),
      orderedEquals(ids.sublist(0, 2)),
    );
  });
}
