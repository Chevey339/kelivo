import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/generation_run.dart';
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
      'kelivo_chat_service_test_',
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

  test('windowed timeline cache stays appendable for the next send', () async {
    final service = createService();
    await service.init();
    final conversation = await service.createConversation(title: 'Chat');
    final ids = <String>[];
    for (var i = 0; i < 3; i++) {
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'message $i',
      );
      ids.add(message.id);
    }

    // Cache only a tail window so the append lands in a partial cache.
    await service.loadTimelinePage(conversation.id, limit: 1);
    expect(service.getMessages(conversation.id).map((message) => message.id), [
      ids.last,
    ]);

    final result = await service.beginSendGeneration(
      conversationId: conversation.id,
      userParts: const [TextPart('next question')],
      modelId: 'model',
      providerId: 'provider',
    );

    expect(service.getMessages(conversation.id).map((message) => message.id), [
      ids.last,
      result.userMessage!.id,
      result.assistantMessage.id,
    ]);
  });

  test('switching conversations evicts an oversized previous cache', () async {
    final service = createService();
    await service.init();
    final first = await service.createConversation(title: 'Large');
    await service.addMessage(
      conversationId: first.id,
      role: 'user',
      content: 'x' * (5 * 1024 * 1024),
    );
    expect(await service.loadMessages(first.id), hasLength(1));

    await service.createConversation(title: 'Next');

    expect(service.getMessages(first.id), isEmpty);
    expect(service.getMessageCount(first.id), 1);
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
        parts: [
          FilePart(uri: upload.path, name: 'spec.pdf', mime: 'application/pdf'),
        ],
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
    'unavailable local attachment does not leave asset sync dirty',
    () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(title: 'Missing');
      final missing = File('${tempDir.path}/upload/gone.png');
      await missing.parent.create(recursive: true);
      // Path is under upload/, but the file itself is intentionally absent.
      expect(await missing.exists(), isFalse);

      await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        parts: [
          ImagePart(uri: missing.path, mime: 'image/png', unavailable: true),
        ],
      );

      await service.runAssetReferenceMaintenance();
      final repo = service.chatRepositoryOrNull;
      expect(repo, isNotNull);
      expect(await repo!.hasPendingAssetReferenceSync(), isFalse);
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
        parts: [
          FilePart(uri: upload.path, name: 'legacy.txt', mime: 'text/plain'),
        ],
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

  test(
    'asset backfill skips malformed attachment without clearing its references',
    () async {
      final first = createService();
      await first.init();
      final repository = first.chatRepositoryOrNull!;
      final now = DateTime.utc(2026, 8, 10);
      const conversationId = 'conversation-malformed-backfill';
      const messageIds = ['a-healthy', 'b-malformed', 'c-healthy'];
      final files = <String, File>{
        for (final id in messageIds) id: File('${tempDir.path}/upload/$id.txt'),
      };
      for (final file in files.values) {
        await file.parent.create(recursive: true);
        await file.writeAsString('payload:${file.path}');
      }
      final messages = [
        for (final id in messageIds)
          ChatMessage(
            id: id,
            role: 'user',
            conversationId: conversationId,
            timestamp: now,
            parts: [
              FilePart(
                uri: files[id]!.path,
                name: '$id.txt',
                mime: 'text/plain',
              ),
            ],
          ),
      ];
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: conversationId,
            title: 'Malformed backfill',
            createdAt: now,
            updatedAt: now,
            messageIds: messageIds,
          ),
        ],
        messages: [
          for (var i = 0; i < messages.length; i++)
            (message: messages[i], messageOrder: i),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      for (var i = 0; i < messageIds.length; i++) {
        await repository.registerAsset(
          id: 'legacy-asset-$i',
          contentHash: List.filled(64, '${i + 1}').join(),
          path: files[messageIds[i]]!.path,
          byteSize: await files[messageIds[i]]!.length(),
          createdAt: now,
        );
        await repository.linkMessageAsset(
          conversationId: conversationId,
          revisionId: messageIds[i],
          assetId: 'legacy-asset-$i',
          kind: 'file',
        );
      }
      await first.close();
      services.remove(first);

      final database = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        database.execute(
          'DELETE FROM message_asset_rows '
          "WHERE revision_id IN ('a-healthy', 'c-healthy');",
        );
        database.execute(
          'UPDATE message_part_rows SET payload = ? '
          "WHERE revision_id = 'b-malformed' AND kind = 'file';",
          ['{"uri":"${files['b-malformed']!.path}"}'],
        );
        database.execute(
          'INSERT OR IGNORE INTO asset_reference_dirty_rows(revision_id) '
          "VALUES ('a-healthy'), ('b-malformed'), ('c-healthy');",
        );
        database.execute(
          "DELETE FROM chat_storage_meta_rows "
          "WHERE key = 'sandbox_path_migration_version';",
        );
      } finally {
        database.close();
      }

      final restarted = createService();
      await restarted.init().timeout(const Duration(seconds: 2));
      await restarted.runAssetReferenceMaintenance();

      final verify = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        expect(
          verify.select(
            "SELECT 1 FROM message_asset_rows WHERE revision_id = 'a-healthy';",
          ),
          isNotEmpty,
        );
        expect(
          verify.select(
            "SELECT 1 FROM message_asset_rows WHERE revision_id = 'c-healthy';",
          ),
          isNotEmpty,
        );
        final malformedRefs = verify.select(
          "SELECT asset_id FROM message_asset_rows "
          "WHERE revision_id = 'b-malformed';",
        );
        expect(malformedRefs, hasLength(1));
        expect(malformedRefs.single['asset_id'], 'legacy-asset-1');
        expect(
          verify
              .select(
                "SELECT revision_id FROM asset_reference_dirty_rows "
                'ORDER BY revision_id;',
              )
              .map((row) => row['revision_id']),
          ['b-malformed'],
        );
        expect(
          verify.select(
            "SELECT 1 FROM chat_storage_meta_rows "
            "WHERE key = 'sandbox_path_migration_version';",
          ),
          hasLength(1),
        );
      } finally {
        verify.close();
      }
    },
  );

  test(
    'editing malformed attachment preserves live asset references and dirty state',
    () async {
      final first = createService();
      await first.init();
      final conversation = await first.createConversation(title: 'Malformed');
      final upload = File('${tempDir.path}/upload/live.txt');
      await upload.parent.create(recursive: true);
      await upload.writeAsString('live attachment');
      final message = await first.addMessage(
        conversationId: conversation.id,
        role: 'user',
        parts: [
          FilePart(uri: upload.path, name: 'live.txt', mime: 'text/plain'),
        ],
      );
      await first.close();
      services.remove(first);

      final databasePath = '${tempDir.path}/${AppDatabase.databaseFileName}';
      final corrupt = sqlite.sqlite3.open(databasePath);
      late final String originalAssetId;
      const secret = '/private/attachment-metadata';
      final malformedPayload =
          '{"uri":"${upload.path}","name":"live.txt","mime":["$secret"]}';
      try {
        originalAssetId =
            corrupt.select(
                  'SELECT asset_id FROM message_asset_rows WHERE revision_id = ?;',
                  [message.id],
                ).single['asset_id']
                as String;
        corrupt.execute(
          'UPDATE message_part_rows SET payload = ? '
          'WHERE revision_id = ? AND kind = ?;',
          [malformedPayload, message.id, 'file'],
        );
        corrupt.execute(
          'DELETE FROM asset_reference_dirty_rows WHERE revision_id = ?;',
          [message.id],
        );
      } finally {
        corrupt.close();
      }

      final restarted = createService();
      await restarted.init();
      final loaded = await restarted.loadMessages(conversation.id);
      final malformed = loaded.single.parts.single as MalformedPart;
      expect(malformed.parseError, 'invalid_mime');
      expect(malformed.parseError, isNot(contains(secret)));

      await restarted.updateMessage(message.id, content: 'edited');

      final verify = sqlite.sqlite3.open(databasePath);
      try {
        final references = verify.select(
          'SELECT asset_id FROM message_asset_rows WHERE revision_id = ?;',
          [message.id],
        );
        expect(references, hasLength(1));
        expect(references.single['asset_id'], originalAssetId);
        expect(
          verify.select(
            'SELECT 1 FROM asset_reference_dirty_rows WHERE revision_id = ?;',
            [message.id],
          ),
          hasLength(1),
        );
      } finally {
        verify.close();
      }
      expect(await upload.exists(), isTrue);
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
      final timeline = await service.loadTimelinePage(
        conversation.id,
        fromStart: true,
      );
      expect(timeline!.slots.single.message.id, message.id);
      expect(timeline.slots.single.message.content, 'hello');
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
      await service.updateConversationSuggestions(conversation.id, const [
        'stale suggestion',
      ]);

      final deleted = await service.deleteMessages(
        conversationId: conversation.id,
        messageIds: {second.id, 'missing'},
        versionSelectionChanges: const {},
      );
      final page = await service.loadTimelinePage(conversation.id);

      expect(deleted, {second.id});
      expect(page!.slots.map((slot) => slot.identity.revisionId), [first.id]);
      expect(await service.loadMessages(conversation.id), [first]);
      expect(
        service.getConversation(conversation.id)!.chatSuggestions,
        isEmpty,
      );
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
        expect(service.isTemporaryConversation(temporary.id), isTrue);
      },
    );

    test(
      'late message cannot revive a discarded temporary conversation',
      () async {
        final service = createService();
        await service.init();

        final temporary = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        await service.createDraftConversation(title: 'Next Chat');

        final lateMessage = await service.addMessage(
          conversationId: temporary.id,
          role: 'assistant',
          content: 'late secret',
        );
        await service.setGeminiThoughtSignature(
          lateMessage.id,
          'late signature',
        );

        expect(service.getConversation(temporary.id), isNull);
        expect(service.getMessages(temporary.id), isEmpty);
        expect(service.getGeminiThoughtSignature(lateMessage.id), isNull);
        expect(
          service.getAllConversations().map((conversation) => conversation.id),
          isNot(contains(temporary.id)),
        );
      },
    );

    test(
      'late checkpoint leaves no artifacts for a discarded temporary conversation',
      () async {
        final service = createService();
        await service.init();

        final temporary = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        final assistantMessage = await service.addMessage(
          conversationId: temporary.id,
          role: 'assistant',
          content: '',
          isStreaming: true,
        );
        await service.createDraftConversation(title: 'Next Chat');

        await service.updateStreamingCheckpointSilent(
          assistantMessage.copyWith(content: 'late secret'),
          const [
            {'id': 'tool-1', 'name': 'memory_read'},
          ],
        );

        expect(service.getConversation(temporary.id), isNull);
        expect(service.getMessages(temporary.id), isEmpty);
        expect(service.getToolEvents(assistantMessage.id), isEmpty);
      },
    );

    test('late Gemini signature is ignored after temporary discard', () async {
      final service = createService();
      await service.init();

      final temporary = await service.createDraftConversation(
        title: 'Temporary Chat',
        temporary: true,
      );
      final assistantMessage = await service.addMessage(
        conversationId: temporary.id,
        role: 'assistant',
        content: '',
        isStreaming: true,
      );
      await service.createDraftConversation(title: 'Next Chat');

      await service.setGeminiThoughtSignature(
        assistantMessage.id,
        'late signature',
      );

      expect(service.getGeminiThoughtSignature(assistantMessage.id), isNull);
    });

    test(
      'clearing data keeps discarded temporary conversations protected',
      () async {
        final service = createService();
        await service.init();

        final temporary = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        await service.createDraftConversation(title: 'Next Chat');

        await service.clearAllData(deleteUploads: false);

        expect(service.isTemporaryConversation(temporary.id), isTrue);
        await service.addMessage(
          conversationId: temporary.id,
          role: 'assistant',
          content: 'late secret',
        );
        expect(service.getConversation(temporary.id), isNull);
        expect(service.getAllConversations(), isEmpty);
      },
    );

    test(
      'overwrite restore protects an active temporary conversation',
      () async {
        final service = createService();
        await service.init();

        final temporary = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        final assistantMessage = await service.addMessage(
          conversationId: temporary.id,
          role: 'assistant',
          content: '',
          isStreaming: true,
        );

        await service.replaceAllDataFromBackup(
          conversations: const [],
          messages: const [],
          toolEventsByMessageId: const {},
          geminiSignaturesByMessageId: const {},
        );

        expect(service.isTemporaryConversation(temporary.id), isTrue);
        await service.setGeminiThoughtSignature(
          assistantMessage.id,
          'late signature',
        );
        expect(service.getGeminiThoughtSignature(assistantMessage.id), isNull);
        expect(service.getConversation(temporary.id), isNull);
      },
    );

    test('database merge preserves an active temporary conversation', () async {
      final service = createService();
      await service.init();

      final temporary = await service.createDraftConversation(
        title: 'Temporary Chat',
        temporary: true,
      );
      final assistantMessage = await service.addMessage(
        conversationId: temporary.id,
        role: 'assistant',
        content: 'still streaming',
        isStreaming: true,
      );
      final snapshot = File('${tempDir.path}/merge.sqlite');
      await service.createBackupDatabaseSnapshot(snapshot);

      await service.mergeDatabaseSnapshot(snapshot);

      expect(service.getMessages(temporary.id), [assistantMessage]);
      await service.setGeminiThoughtSignature(
        assistantMessage.id,
        'live signature',
      );
      expect(
        service.getGeminiThoughtSignature(assistantMessage.id),
        'live signature',
      );
    });

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
      await service.updateConversationSuggestions(conversation.id, const [
        'stale suggestion',
      ]);

      await service.deleteMessage(message.id);

      expect(service.getAllConversations(), isEmpty);
      expect(service.getMessages(conversation.id), isEmpty);
      expect(service.getConversation(conversation.id)?.messageIds, isEmpty);
      expect(
        service.getConversation(conversation.id)?.chatSuggestions,
        isEmpty,
      );
    });

    test('temporary message editing appends an in-memory version', () async {
      final service = createService();
      await service.init();

      final conversation = await service.createDraftConversation(
        title: 'Temporary Chat',
        temporary: true,
      );
      final original = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'original question',
      );

      final edited = await service.appendMessageVersion(
        messageId: original.id,
        content: 'edited question',
      );

      expect(edited, isNotNull);
      expect(edited!.content, 'edited question');
      expect(edited.groupId, original.groupId ?? original.id);
      expect(edited.version, 1);
      expect(service.getMessages(conversation.id), [original, edited]);
      expect(service.getConversation(conversation.id)?.messageIds, [
        original.id,
        edited.id,
      ]);
      expect(service.getVersionSelections(conversation.id), {
        original.groupId ?? original.id: edited.version,
      });
      expect(service.getAllConversations(), isEmpty);

      final timeline = await service.loadTimelinePage(
        conversation.id,
        fromStart: true,
      );
      expect(timeline!.slots.single.message.id, edited.id);
    });

    test('temporary content-only append keeps prior ImagePart', () async {
      final service = createService();
      await service.init();

      final conversation = await service.createDraftConversation(
        title: 'Temporary Chat',
        temporary: true,
      );
      final original = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        parts: const [
          ImagePart(uri: '/tmp/keep.png', mime: 'image/png'),
          TextPart('original caption'),
        ],
      );

      final edited = await service.appendMessageVersion(
        messageId: original.id,
        content: 'edited caption',
      );

      expect(edited, isNotNull);
      expect(edited!.content, 'edited caption');
      expect(edited.parts, hasLength(2));
      expect(edited.parts[0], isA<ImagePart>());
      expect((edited.parts[0] as ImagePart).uri, '/tmp/keep.png');
      expect(edited.parts[1], isA<TextPart>());
      expect((edited.parts[1] as TextPart).text, 'edited caption');
    });

    test(
      'temporary content-only append keeps interleaved Text/Tool/Text slots',
      () async {
        final service = createService();
        await service.init();
        final persistedService = createService();
        await persistedService.init();

        final temporary = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        final persisted = await persistedService.createConversation(
          title: 'Persisted',
        );
        const parts = [
          TextPart('我查一下'),
          ToolCallPart('{"id":"search","name":"search"}'),
          TextPart('结果是 X'),
        ];
        const editedContent = '我查一下结果是 X';

        final tempOriginal = await service.addMessage(
          conversationId: temporary.id,
          role: 'assistant',
          parts: parts,
        );
        final persistedOriginal = await persistedService.addMessage(
          conversationId: persisted.id,
          role: 'assistant',
          parts: parts,
        );

        final tempEdited = await service.appendMessageVersion(
          messageId: tempOriginal.id,
          content: editedContent,
        );
        final persistedEdited = await persistedService.appendMessageVersion(
          messageId: persistedOriginal.id,
          content: editedContent,
        );

        expect(tempEdited!.parts.map((part) => part.kind), [
          'text',
          'tool_call',
          'text',
        ]);
        expect(persistedEdited!.parts.map((part) => part.kind), [
          'text',
          'tool_call',
          'text',
        ]);
        expect((tempEdited.parts[0] as TextPart).text, '我查一下');
        expect((persistedEdited.parts[0] as TextPart).text, '我查一下');
        expect((tempEdited.parts[2] as TextPart).text, '结果是 X');
        expect((persistedEdited.parts[2] as TextPart).text, '结果是 X');
      },
    );

    test(
      'temporary content-only append keeps collapsed assistant reasoning',
      () async {
        final service = createService();
        await service.init();
        const reasoningJson =
            '{"v":2,"segments":[{"text":"plan then check","expanded":false,'
            '"toolStartIndex":0}],"contentSplits":{"offsets":[5],'
            '"reasoningCounts":[1],"toolCounts":[1]},'
            '"reasoningDetails":[{"id":"rd_1","type":"reasoning.encrypted",'
            '"data":"sig","format":"anthropic-claude-v1"}]}';
        final reasoningStart = DateTime.utc(2026, 8, 22, 11, 59);
        final reasoningFinished = DateTime.utc(2026, 8, 22, 12);

        final conversation = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        final original = await service.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          parts: const [
            ReasoningPart('plan then check'),
            TextPart('original answer'),
          ],
          reasoningText: 'plan then check',
          reasoningStartAt: reasoningStart,
          reasoningFinishedAt: reasoningFinished,
        );
        await service.updateMessage(
          original.id,
          reasoningSegmentsJson: reasoningJson,
        );

        final edited = await service.appendMessageVersion(
          messageId: original.id,
          content: 'edited answer',
        );

        expect(edited, isNotNull);
        expect(edited!.content, 'edited answer');
        expect(edited.parts.map((part) => part.kind), ['reasoning', 'text']);
        expect((edited.parts[0] as ReasoningPart).text, 'plan then check');
        expect((edited.parts[1] as TextPart).text, 'edited answer');
        expect(edited.reasoningText, 'plan then check');
        expect(edited.reasoningStartAt, reasoningStart);
        expect(edited.reasoningFinishedAt, reasoningFinished);
        expect(edited.reasoningSegmentsJson, reasoningJson);
        expect(edited.translation, isNull);
        expect(edited.totalTokens, isNull);
        expect(service.getMessages(conversation.id).last.id, edited.id);
      },
    );

    test(
      'temporary content-only append keeps interleaved reasoning tool text',
      () async {
        final service = createService();
        await service.init();
        const reasoningJson =
            '{"v":2,"segments":['
            '{"text":"plan","expanded":false,"toolStartIndex":0},'
            '{"text":"check","expanded":false,"toolStartIndex":1}'
            '],"contentSplits":{"offsets":[6,11],'
            '"reasoningCounts":[1,2],"toolCounts":[1,1]}}';
        final reasoningStart = DateTime.utc(2026, 8, 22, 12, 50);
        final reasoningFinished = DateTime.utc(2026, 8, 22, 13);

        final conversation = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        final original = await service.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          parts: const [
            ReasoningPart('plan'),
            TextPart('hello '),
            ToolCallPart('{"id":"call_1","name":"lookup"}'),
            TextPart('world'),
            ReasoningPart('check'),
          ],
          reasoningText: 'plan\ncheck',
          reasoningStartAt: reasoningStart,
          reasoningFinishedAt: reasoningFinished,
        );
        await service.updateMessage(
          original.id,
          reasoningSegmentsJson: reasoningJson,
        );

        final edited = await service.appendMessageVersion(
          messageId: original.id,
          content: 'hello world',
        );

        expect(edited!.parts.map((part) => part.kind), [
          'reasoning',
          'text',
          'tool_call',
          'text',
          'reasoning',
        ]);
        expect((edited.parts[0] as ReasoningPart).text, 'plan');
        expect((edited.parts[4] as ReasoningPart).text, 'check');
        expect(edited.reasoningText, 'plan\ncheck');
        expect(edited.reasoningStartAt, reasoningStart);
        expect(edited.reasoningFinishedAt, reasoningFinished);
        expect(edited.reasoningSegmentsJson, reasoningJson);
      },
    );

    test(
      'temporary explicit parts does not inherit reasoning metadata',
      () async {
        final service = createService();
        await service.init();

        final conversation = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        final original = await service.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          parts: const [ReasoningPart('old plan'), TextPart('old answer')],
          reasoningText: 'old plan',
          reasoningStartAt: DateTime.utc(2026, 8, 22, 13, 50),
          reasoningFinishedAt: DateTime.utc(2026, 8, 22, 14),
        );
        await service.updateMessage(
          original.id,
          reasoningSegmentsJson:
              '{"segments":[{"text":"old plan","expanded":false}]}',
        );

        final edited = await service.appendMessageVersion(
          messageId: original.id,
          content: 'replacement',
          parts: const [TextPart('replacement')],
        );

        expect(edited!.parts, hasLength(1));
        expect(edited.parts.single, isA<TextPart>());
        expect(edited.reasoningText, isNull);
        expect(edited.reasoningStartAt, isNull);
        expect(edited.reasoningFinishedAt, isNull);
        expect(edited.reasoningSegmentsJson, isNull);
      },
    );
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

        expect(fork.title, source.title);
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

    test(
      'preserveVersions copies every version up to the target group',
      () async {
        final service = createService();
        await service.init();

        final source = await service.createConversation(title: 'Source');
        await service.addMessage(
          conversationId: source.id,
          role: 'user',
          content: 'q1',
        );
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
        await service.addMessage(
          conversationId: source.id,
          role: 'user',
          content: 'q2',
        );
        await service.addMessage(
          conversationId: source.id,
          role: 'assistant',
          content: 'later answer',
        );

        final fork = await service.forkConversationAtRevision(
          sourceConversationId: source.id,
          sourceRevisionId: original.id,
          title: 'Fork',
          preserveVersions: true,
        );

        expect(fork.title, source.title);
        expect(service.getMessages(fork.id), isEmpty);

        final timeline = await service.loadActiveTimelineMessages(fork.id);
        expect(timeline.map((message) => message.content), [
          'q1',
          'original answer',
        ]);
        expect(timeline.map((message) => message.version), [0, 0]);

        final assistantGroupId = timeline.last.groupId ?? timeline.last.id;
        final versions = await service.loadMessagesForGroups(fork.id, [
          assistantGroupId,
        ]);
        expect(versions.map((message) => message.version).toSet(), {0, 1});
        expect(versions.map((message) => message.content).toSet(), {
          'original answer',
          'edited answer',
        });
        expect(
          versions.map((message) => message.groupId ?? message.id).toSet(),
          {assistantGroupId},
        );
        expect(service.getVersionSelections(fork.id), {assistantGroupId: 0});
      },
    );

    test(
      'linear fork copies tool events and Gemini signatures onto new ids',
      () async {
        final service = createService();
        await service.init();

        final source = await service.createConversation(title: 'Source');
        await service.addMessage(
          conversationId: source.id,
          role: 'user',
          content: 'q1',
        );
        final assistant = await service.addMessage(
          conversationId: source.id,
          role: 'assistant',
          content: 'answer with tools',
        );
        const events = [
          <String, dynamic>{
            'id': 'tool-1',
            'name': 'search',
            'arguments': <String, dynamic>{'q': 'kelivo'},
            'content': 'found',
          },
        ];
        await service.setToolEvents(assistant.id, events);
        await service.setGeminiThoughtSignature(assistant.id, 'sig-source');

        final fork = await service.forkConversationAtRevision(
          sourceConversationId: source.id,
          sourceRevisionId: assistant.id,
          title: 'Fork',
        );

        final forkMessages = service.getMessages(fork.id);
        expect(forkMessages, hasLength(2));
        final forkedAssistant = forkMessages.last;
        expect(forkedAssistant.id, isNot(assistant.id));
        expect(service.getToolEvents(forkedAssistant.id), events);
        expect(
          service.getGeminiThoughtSignature(forkedAssistant.id),
          'sig-source',
        );
        expect(service.getToolEvents(assistant.id), events);
        expect(service.getGeminiThoughtSignature(assistant.id), 'sig-source');
      },
    );

    test(
      'forkConversationFromMessages copies tool events and Gemini signatures',
      () async {
        final service = createService();
        await service.init();

        final source = await service.createConversation(title: 'Source');
        final user = await service.addMessage(
          conversationId: source.id,
          role: 'user',
          content: 'q1',
        );
        final assistant = await service.addMessage(
          conversationId: source.id,
          role: 'assistant',
          content: 'answer with tools',
        );
        const events = [
          <String, dynamic>{
            'id': 'tool-keep',
            'name': 'lookup',
            'arguments': <String, dynamic>{},
            'content': 'ok',
          },
        ];
        await service.setToolEvents(assistant.id, events);
        await service.setGeminiThoughtSignature(assistant.id, 'sig-keep');

        final summary = ChatMessage(
          role: 'user',
          content: 'summary of earlier turns',
          conversationId: source.id,
        );
        final fork = await service.forkConversationFromMessages(
          title: source.title,
          assistantId: source.assistantId,
          sourceMessages: [summary, user, assistant],
        );

        final forkMessages = service.getMessages(fork.id);
        expect(forkMessages, hasLength(3));
        expect(forkMessages.first.content, 'summary of earlier turns');
        final forkedAssistant = forkMessages.last;
        expect(forkedAssistant.id, isNot(assistant.id));
        expect(service.getToolEvents(forkedAssistant.id), events);
        expect(
          service.getGeminiThoughtSignature(forkedAssistant.id),
          'sig-keep',
        );
        expect(service.getToolEvents(forkMessages.first.id), isEmpty);
      },
    );
  });

  test('final generation commit publishes one statistics revision', () async {
    final service = createService();
    await service.init();
    final conversation = await service.createConversation(title: 'Stats');
    final generation = await service.beginSendGeneration(
      conversationId: conversation.id,
      userParts: const [TextPart('question')],
      modelId: 'model',
      providerId: 'provider',
    );
    var run = await service.transitionGenerationRun(
      id: generation.run.id,
      expectedState: generation.run.state,
      expectedStateRevision: generation.run.stateRevision,
      nextState: GenerationRunState.requesting,
    );
    run = await service.transitionGenerationRun(
      id: run.id,
      expectedState: run.state,
      expectedStateRevision: run.stateRevision,
      nextState: GenerationRunState.streaming,
    );
    final completedMessage = generation.assistantMessage.copyWith(
      content: 'answer',
      totalTokens: 12,
      isStreaming: false,
      promptTokens: 3,
      completionTokens: 9,
    );
    final revisionBefore = service.statisticsRevision;
    var notifications = 0;
    void listener() => notifications++;
    service.addListener(listener);
    addTearDown(() => service.removeListener(listener));

    await service.finalizeGenerationRunSilent(
      message: completedMessage,
      toolEvents: const [],
      generationRunId: run.id,
      expectedState: run.state,
      expectedStateRevision: run.stateRevision,
      terminalState: GenerationRunState.completed,
    );

    expect(service.statisticsRevision, revisionBefore + 1);
    expect(notifications, 1);
    final aggregate = await service.loadStatsAggregate(
      rangeStart: null,
      rangeEndExclusive: null,
      heatmapStart: DateTime.utc(2000),
      trendStart: DateTime.utc(2000),
      trendEndExclusive: DateTime.utc(2100),
    );
    expect(aggregate.totals.messages, 2);
    expect(aggregate.totals.inputTokens, 3);
    expect(aggregate.totals.outputTokens, 9);
  });

  test('business selection uses linear group versions', () async {
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

    expect(edited, isNotNull);
    final groupId = edited!.groupId ?? original.id;

    await service.setSelectedVersion(conversation.id, groupId, 0);
    expect(service.getVersionSelections(conversation.id), {groupId: 0});
    final page = await service.loadTimelinePage(
      conversation.id,
      fromStart: true,
    );
    expect(page!.slots.single.message.id, original.id);
  });
}
