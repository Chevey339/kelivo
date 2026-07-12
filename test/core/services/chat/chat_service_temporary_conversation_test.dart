import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/app_database.dart';
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
      'kelivo_chat_service_test_',
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

  test('cold init clears every stale streaming flag', () async {
    final first = createService();
    await first.init();
    final conversation = await first.createConversation(title: 'Chat');
    await first.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'partial',
      isStreaming: true,
    );
    await first.close();
    services.remove(first);

    final restarted = createService();
    await restarted.init();

    final messages = await restarted.loadMessages(conversation.id);
    expect(messages, hasLength(1));
    expect(messages.single.content, 'partial');
    expect(messages.single.isStreaming, isFalse);
  });

  test('retained timeline cache stays appendable for the next send', () async {
    final service = createService();
    await service.init();
    final conversation = await service.createConversation(title: 'Chat');
    final first = await service.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'first answer',
    );
    await service.loadMessages(conversation.id);

    service.retainTimelineWindow(conversation.id, [first.id]);
    expect(service.getMessages(conversation.id).map((message) => message.id), [
      first.id,
    ]);

    final result = await service.beginSendGeneration(
      conversationId: conversation.id,
      userContent: 'next question',
      modelId: 'model',
      providerId: 'provider',
    );

    expect(service.getMessages(conversation.id).map((message) => message.id), [
      first.id,
      result.userMessage!.id,
      result.assistantMessage.id,
    ]);
  });

  test(
    'persistent attachment uses delayed reference GC after message delete',
    () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(title: 'Assets');
      final upload = File('${tempDir.path}/upload/spec.pdf');
      await upload.parent.create(recursive: true);
      await upload.writeAsString('attachment payload');
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: '[file:${upload.path}|spec.pdf|application/pdf]',
      );

      await service.deleteMessage(message.id);

      expect(await upload.exists(), isTrue, reason: 'GC must be delayed');
      await service.runAssetMaintenance(
        now: DateTime.now().toUtc().add(const Duration(days: 8)),
      );
      expect(await upload.exists(), isFalse);
    },
  );

  test(
    'cold init backfills attachment references left by an older writer',
    () async {
      final first = createService();
      await first.init();
      final conversation = await first.createConversation(title: 'Assets');
      final upload = File('${tempDir.path}/upload/legacy.txt');
      await upload.parent.create(recursive: true);
      await upload.writeAsString('legacy attachment payload');
      final message = await first.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: '[file:${upload.path}|legacy.txt|text/plain]',
      );
      await first.close();
      services.remove(first);

      final database = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        database.execute('DELETE FROM asset_rows;');
        database.execute(
          "DELETE FROM chat_storage_meta_rows "
          "WHERE key = 'asset_reference_backfill_version';",
        );
      } finally {
        database.close();
      }

      final hashStarted = Completer<void>();
      final hashResult = Completer<String>();
      final restarted = createService(
        assetContentHash: (file) {
          if (!hashStarted.isCompleted) hashStarted.complete();
          return hashResult.future;
        },
      );
      await restarted.init().timeout(const Duration(seconds: 1));
      await hashStarted.future.timeout(const Duration(seconds: 1));
      expect(hashResult.isCompleted, isFalse);

      hashResult.complete(List.filled(64, 'b').join());
      await restarted.runAssetReferenceMaintenance();
      await restarted.deleteMessage(message.id);
      await restarted.runAssetMaintenance(
        now: DateTime.now().toUtc().add(const Duration(days: 8)),
      );

      expect(await upload.exists(), isFalse);
    },
  );

  group('ChatService temporary conversations', () {
    test('ordinary draft persists when its first message is added', () async {
      final service = createService();
      await service.init();

      final conversation = await service.createDraftConversation(title: 'Chat');
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'hello',
      );

      expect(service.getAllConversations().map((c) => c.id), [conversation.id]);
      expect(await service.loadMessages(conversation.id), hasLength(1));
      final timeline = await service.loadMessageGraphTimeline(conversation.id);
      expect(timeline!.activeRevisions.single.revisionId, message.id);
      expect(timeline.activeRevisions.single.text, 'hello');
    });

    test(
      'temporary draft keeps messages in memory without entering history',
      () async {
        final service = createService();
        await service.init();

        final conversation = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        await service.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'secret',
        );

        expect(service.getAllConversations(), isEmpty);
        expect(service.getConversation(conversation.id), isNotNull);
        expect(service.getMessages(conversation.id), hasLength(1));
        expect(service.isTemporaryConversation(conversation.id), isTrue);
      },
    );

    test(
      'temporary conversation supports range and recent message reads',
      () async {
        final service = createService();
        await service.init();

        final conversation = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        for (var i = 0; i < 5; i++) {
          await service.addMessage(
            conversationId: conversation.id,
            role: i.isEven ? 'user' : 'assistant',
            content: 'temporary message $i',
          );
        }

        final range = service.getMessagesRange(
          conversation.id,
          start: 1,
          limit: 3,
        );
        final recent = service.getRecentMessages(
          conversation.id,
          minMessages: 2,
          maxMessages: 2,
        );

        expect(range.map((message) => message.content), [
          'temporary message 1',
          'temporary message 2',
          'temporary message 3',
        ]);
        expect(recent.map((message) => message.content), [
          'temporary message 3',
          'temporary message 4',
        ]);
      },
    );

    test(
      'temporary timeline pages stay bounded without evicting memory history',
      () async {
        final service = createService();
        await service.init();

        final conversation = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        for (var i = 0; i < 45; i++) {
          await service.addMessage(
            conversationId: conversation.id,
            role: i.isEven ? 'user' : 'assistant',
            content: 'temporary message $i',
          );
        }

        final tail = await service.loadTimelinePage(conversation.id, limit: 40);
        expect(tail, isNotNull);
        expect(tail!.slots, hasLength(40));
        expect(tail.slots.first.message.content, 'temporary message 5');
        expect(tail.hasMoreBefore, isTrue);
        service.retainTimelineWindow(
          conversation.id,
          tail.slots.map((slot) => slot.identity.revisionId),
        );

        expect(await service.loadMessages(conversation.id), hasLength(45));
        final before = await service.loadTimelinePage(
          conversation.id,
          beforeRevisionId: tail.slots.first.identity.revisionId,
          limit: 20,
        );
        expect(before!.slots, hasLength(5));
        expect(before.slots.first.message.content, 'temporary message 0');
      },
    );

    test('temporary batch deletion reports the removed revisions', () async {
      final service = createService();
      await service.init();

      final conversation = await service.createDraftConversation(
        title: 'Temporary Chat',
        temporary: true,
      );
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

      final deleted = await service.deleteMessages(
        conversationId: conversation.id,
        messageIds: {second.id, 'missing'},
        versionSelectionChanges: const {},
      );
      final page = await service.loadTimelinePage(conversation.id);

      expect(deleted, {second.id});
      expect(page!.slots.map((slot) => slot.identity.revisionId), [first.id]);
      expect(await service.loadMessages(conversation.id), [first]);
    });

    test(
      'temporary timeline projects the selected revision per slot',
      () async {
        final service = createService();
        await service.init();

        final conversation = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        await service.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: 'version zero',
          groupId: 'answer-slot',
          version: 0,
          selectVersion: true,
        );
        final selected = await service.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: 'version two',
          groupId: 'answer-slot',
          version: 2,
          selectVersion: true,
        );

        final page = await service.loadTimelinePage(conversation.id);

        expect(page!.slots, hasLength(1));
        expect(page.slots.single.identity.versionCount, 2);
        expect(page.slots.single.message, selected);
      },
    );

    test(
      'temporary conversation is discarded when current conversation changes',
      () async {
        final service = createService();
        await service.init();

        final temporary = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        await service.addMessage(
          conversationId: temporary.id,
          role: 'user',
          content: 'secret',
        );

        final ordinary = await service.createDraftConversation(title: 'Chat');

        expect(service.getConversation(temporary.id), isNull);
        expect(service.getMessages(temporary.id), isEmpty);
        expect(service.currentConversationId, ordinary.id);
        expect(service.getAllConversations(), isEmpty);
      },
    );

    test('temporary message deletion only affects memory', () async {
      final service = createService();
      await service.init();

      final conversation = await service.createDraftConversation(
        title: 'Temporary Chat',
        temporary: true,
      );
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'secret',
      );

      await service.deleteMessage(message.id);

      expect(service.getAllConversations(), isEmpty);
      expect(service.getMessages(conversation.id), isEmpty);
      expect(service.getConversation(conversation.id)?.messageIds, isEmpty);
    });
  });

  group('ChatService fork conversations', () {
    test(
      'fork copies selected path as plain single-version messages',
      () async {
        final service = createService();
        await service.init();

        final source = await service.createConversation(title: 'Source');
        final original = await service.addMessage(
          conversationId: source.id,
          role: 'assistant',
          content: 'original answer',
        );
        final edited = await service.appendMessageVersion(
          messageId: original.id,
          content: 'edited answer',
        );
        expect(edited, isNotNull);

        final fork = await service.forkConversationAtRevision(
          sourceConversationId: source.id,
          sourceRevisionId: edited!.id,
          title: 'Fork',
        );

        final forkMessages = service.getMessages(fork.id);
        expect(forkMessages, hasLength(1));
        expect(forkMessages.single.conversationId, fork.id);
        expect(forkMessages.single.content, 'edited answer');
        expect(
          forkMessages.single.groupId ?? forkMessages.single.id,
          forkMessages.single.id,
        );
        expect(forkMessages.single.version, 0);
        expect(service.getVersionSelections(fork.id), isEmpty);
      },
    );
  });

  test(
    'business selection and context are projected from stable graph IDs',
    () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(title: 'Graph');
      final original = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'v0',
      );
      final edited = await service.appendMessageVersion(
        messageId: original.id,
        content: 'v1',
      );

      var timeline = await service.loadMessageGraphTimeline(
        conversation.id,
        force: true,
      );
      expect(timeline!.activeRevisions.single.revisionId, edited!.id);
      expect(service.getVersionSelections(conversation.id), {original.id: 1});

      await service.setSelectedVersion(conversation.id, original.id, 0);
      timeline = await service.loadMessageGraphTimeline(
        conversation.id,
        force: true,
      );
      expect(timeline!.activeRevisions.single.revisionId, original.id);

      await service.toggleTruncateAtTail(conversation.id);
      expect(service.getContextStartRevisionId(conversation.id), original.id);
      await service.toggleTruncateAtTail(conversation.id);
      expect(service.getContextStartRevisionId(conversation.id), isNull);
    },
  );
}
