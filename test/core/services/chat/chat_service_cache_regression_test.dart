import 'dart:io';
import 'dart:async';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'dart:convert';
import 'package:Kelivo/core/services/api/providers/google/gemini_thought_signature.dart';

import 'package:Kelivo/core/models/message_part.dart';

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

class _DelayedSnapshotRepository extends ChatDatabaseRepository {
  _DelayedSnapshotRepository(super.database);
  Completer<void>? rangeGate;
  Completer<void>? captured;
  Completer<void>? pageGate;
  Completer<void>? pageCaptured;
  @override
  Future<List<ChatMessage>> getMessagesByIds(List<String> ids) async {
    final snapshot = await super.getMessagesByIds(ids);
    final gate = pageGate;
    if (gate != null) {
      pageGate = null;
      pageCaptured!.complete();
      await gate.future;
    }
    return snapshot;
  }

  @override
  Future<List<ChatMessage>> getMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) async {
    final snapshot = await super.getMessagesRange(
      conversationId,
      start: start,
      limit: limit,
    );
    final gate = rangeGate;
    if (gate != null) {
      rangeGate = null;
      captured!.complete();
      await gate.future;
    }
    return snapshot;
  }
}

Future<void> _flushIdleTasks() async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.scheduleFrame();
  binding.handleBeginFrame(Duration.zero);
  binding.handleDrawFrame();
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
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
      // Bodies are cached on the first-page return path without loading the
      // complete identity list during idle time.
      expect(
        service
            .getMessages(conversationId)
            .map((message) => message.id)
            .toSet(),
        ids.toSet(),
      );
      await _flushIdleTasks();
      expect(service.debugHasMessageOrderSkeleton(conversationId), isFalse);
      expect(await service.resolveMessageCount(conversationId), ids.length);
      expect(
        service.getMessages(conversationId).map((message) => message.id),
        orderedEquals(ids),
      );
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
  test(
    'current conversation and retained request snapshots obey cache ownership',
    () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(
        title: 'Large current',
      );
      final tool = {
        'id': 'lookup',
        'name': 'search',
        'arguments': {'q': 'kept'},
        'content': 'complete result',
      };
      final source = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        parts: [const TextPart('original'), ToolCallPart(jsonEncode(tool))],
      );
      const kind = geminiThoughtSignatureArtifactKind;
      await service.setProviderArtifact(
        source.id,
        kind,
        'opaque-original-signature',
      );
      final snapshot = (await service.loadSelectedContextMessages(
        conversation.id,
        truncateIndex: -1,
        limit: 1,
      )).single;
      await service.updateMessage(source.id, translation: 'translated');
      final updatedSnapshot = service.getMessages(conversation.id).single;
      for (var i = 0; i < 12; i++) {
        await service.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: '$i${'x' * (512 * 1024)}',
        );
      }
      expect(service.currentConversationId, conversation.id);
      expect(
        service.debugCachedMessageBytes,
        lessThanOrEqualTo(8 * 1024 * 1024),
      );
      expect(
        service.getMessages(conversation.id).any((m) => m.id == source.id),
        isFalse,
      );
      expect(service.getToolEventsForMessage(snapshot).single, tool);
      expect(
        service.getProviderArtifactForMessage(snapshot, kind),
        'opaque-original-signature',
      );
      expect(
        service.getProviderArtifactForMessage(updatedSnapshot, kind),
        'opaque-original-signature',
      );
      expect(
        service.getProviderArtifactForMessage(
          snapshot.copyWith(content: 'edited'),
          kind,
        ),
        'opaque-original-signature',
      );
      expect(snapshot.copyWith(id: 'new-id').providerArtifactSnapshot, isEmpty);
      expect(
        (await service.loadMessagesByIds([source.id])).single.content,
        'original',
      );
    },
  );

  test(
    'cache eviction keeps an in-flight generation and its replay metadata',
    () async {
      final service = createService();
      await service.init();
      final first = await service.createConversation(title: 'Generating');
      final active = await service.addMessage(
        conversationId: first.id,
        role: 'assistant',
        content: 'partial',
        isStreaming: true,
      );
      const kind = geminiThoughtSignatureArtifactKind;
      await service.setProviderArtifact(active.id, kind, 'active-signature');
      final second = await service.createConversation(title: 'Browsing');
      for (var i = 0; i < 12; i++) {
        await service.addMessage(
          conversationId: second.id,
          role: 'user',
          content: '$i${'y' * (512 * 1024)}',
        );
      }
      expect(service.getMessages(first.id).single.id, active.id);
      expect(service.getProviderArtifact(active.id, kind), 'active-signature');
    },
  );
  test('a delayed full snapshot cannot erase a concurrent append', () async {
    final repository = _DelayedSnapshotRepository(
      AppDatabase.open(file: File('${tempDir.path}/kelivo.db')),
    );
    final service = ChatService(existingRepository: repository);
    await service.init();
    try {
      final conversation = await service.createConversation(
        title: 'Concurrent',
      );
      final initial = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'initial',
      );
      service.debugPrimeMessageCountState(
        conversation.id,
        cachedMessages: const [],
        messageCount: 1,
      );
      repository.rangeGate = Completer<void>();
      repository.captured = Completer<void>();
      final gate = repository.rangeGate!;
      final loading = service.loadMessages(conversation.id);
      await repository.captured!.future;
      final added = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'concurrent',
      );
      gate.complete();
      expect((await loading).map((m) => m.id), [initial.id, added.id]);
      expect(
        service
            .getMessagesRange(conversation.id, start: 0, limit: 10)
            .map((m) => m.id),
        [initial.id, added.id],
      );
      expect(service.getMessageCount(conversation.id), 2);
    } finally {
      await service.close();
      await repository.close();
    }
  });

  test(
    'collecting every page backwards does not reorder model history',
    () async {
      final (service, id, ids) = await seedRestartedService(messageCount: 4);
      await service.resolveMessageCount(id);
      final tail = (await service.loadTimelinePage(id, limit: 2))!;
      await service.loadTimelinePage(
        id,
        beforeRevisionId: tail.slots.first.message.id,
        limit: 2,
      );
      expect(service.isConversationFullyCached(id), isTrue);
      expect((await service.loadMessages(id)).map((m) => m.id), ids);
    },
  );

  test('a delayed page cannot undo a completed version choice', () async {
    final repository = _DelayedSnapshotRepository(
      AppDatabase.open(file: File('${tempDir.path}/kelivo.db')),
    );
    final service = ChatService(existingRepository: repository);
    await service.init();
    try {
      final conversation = await service.createConversation(title: 'Selection');
      final original = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'original',
      );
      await service.appendMessageVersion(
        messageId: original.id,
        content: 'edited',
      );
      repository.pageGate = Completer<void>();
      repository.pageCaptured = Completer<void>();
      final gate = repository.pageGate!;
      final page = service.loadTimelinePage(conversation.id);
      await repository.pageCaptured!.future;
      await service.setSelectedVersion(conversation.id, original.id, 0);
      gate.complete();
      expect((await page)!.slots.single.message.id, original.id);
    } finally {
      await service.close();
      await repository.close();
    }
  });
}
