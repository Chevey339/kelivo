import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/hive_migration_marker.dart';
import 'package:Kelivo/features/migration/hive_to_sqlite_migration_service.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

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
  late PathProviderPlatform previousPathProvider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_hive_sqlite_migration_test_',
    );
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    SharedPreferences.setMockInitialValues({
      'provider_configs_v1': '{"openai":{"apiKey":"test-key"}}',
      'display_chat_font_scale_v1': 1.3,
      'pinned_chat_ids': 'discarded-chat-id',
    });
  });

  tearDown(() async {
    await Hive.close();
    PathProviderPlatform.instance = previousPathProvider;
    SandboxPathResolver.debugSetDirs(docsDir: null, supportDir: null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('backs up Hive files and migrates chat data into SQLite', () async {
    final conversation = Conversation(
      id: 'conversation-1',
      title: 'Migration Source',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 2),
      assistantId: 'assistant-1',
    );
    final userMessage = ChatMessage(
      id: 'message-user',
      role: 'user',
      content: 'hello from hive',
      conversationId: conversation.id,
      timestamp: DateTime(2024, 1, 1, 10),
    );
    final assistantMessage = ChatMessage(
      id: 'message-assistant',
      role: 'assistant',
      content: 'hello from sqlite',
      conversationId: conversation.id,
      timestamp: DateTime(2024, 1, 1, 10, 1),
      reasoningStartAt: DateTime(2024, 1, 1, 10, 1, 2),
      reasoningFinishedAt: DateTime(2024, 1, 1, 10, 1, 3),
      modelId: 'model-a',
      providerId: 'provider-a',
      promptTokens: 3,
      completionTokens: 5,
    );
    conversation.messageIds
      ..add(userMessage.id)
      ..add(assistantMessage.id);

    _registerHiveAdapters();
    Hive.init(tempDir.path);
    final conversations = await Hive.openBox<Conversation>('conversations');
    final messages = await Hive.openBox<ChatMessage>('messages');
    final toolEvents = await Hive.openBox<dynamic>('tool_events_v1');
    await conversations.put(conversation.id, conversation);
    await messages.put(userMessage.id, userMessage);
    await messages.put(assistantMessage.id, assistantMessage);
    await toolEvents.put(assistantMessage.id, [
      {
        'id': 'tool-1',
        'name': 'search',
        'arguments': {'query': 'sqlite'},
        'content': 'result',
      },
    ]);
    await toolEvents.put('sig_${assistantMessage.id}', 'gemini-signature');
    await conversations.close();
    await messages.close();
    await toolEvents.close();
    await Hive.close();
    await Directory('${tempDir.path}/upload').create(recursive: true);
    await File('${tempDir.path}/upload/source.pdf').writeAsString('upload');
    await Directory('${tempDir.path}/images').create(recursive: true);
    await File('${tempDir.path}/images/prompt.png').writeAsBytes([1, 2, 3]);
    await Directory('${tempDir.path}/avatars').create(recursive: true);
    await File('${tempDir.path}/avatars/user.png').writeAsBytes([4, 5, 6]);
    await Directory('${tempDir.path}/fonts').create(recursive: true);
    await File('${tempDir.path}/fonts/custom.ttf').writeAsBytes([7, 8, 9]);

    final decision = await HiveToSqliteMigrationService.check();
    expect(decision.needsMigration, isTrue);

    final service = HiveToSqliteMigrationService(decision);
    final statuses = <HiveToSqliteMigrationStatus>[];
    final sub = service.statusStream.listen(statuses.add);
    addTearDown(sub.cancel);
    final backupRoot = Directory('${tempDir.path}/backup-target')..createSync();
    final backupFile = await service.backupTo(backupRoot);
    expect(backupFile.existsSync(), isTrue);
    expect(backupFile.path, endsWith('.zip'));
    final inputStream = InputFileStream(backupFile.path);
    final archive = ZipDecoder().decodeStream(inputStream);
    addTearDown(inputStream.closeSync);
    addTearDown(archive.clearSync);
    final entryNames = archive.files.map((file) => file.name);
    expect(entryNames, contains('settings.json'));
    expect(entryNames, contains('chats.json'));
    expect(entryNames, isNot(contains('manifest.json')));
    expect(entryNames, isNot(contains('database/kelivo.db')));
    expect(entryNames, contains('conversations.hive'));
    expect(entryNames, contains('messages.hive'));
    expect(entryNames, contains('tool_events_v1.hive'));
    expect(entryNames, contains('upload/source.pdf'));
    expect(entryNames, contains('images/prompt.png'));
    expect(entryNames, contains('avatars/user.png'));
    expect(entryNames, contains('fonts/custom.ttf'));
    final orderedEntryNames = entryNames.toList(growable: false);
    expect(
      orderedEntryNames.indexOf('conversations.hive'),
      lessThan(orderedEntryNames.indexOf('chats.json')),
    );
    final settingsEntry = archive.findFile('settings.json');
    expect(settingsEntry, isNotNull);
    final settingsJson = String.fromCharCodes(settingsEntry!.readBytes()!);
    expect(settingsJson, contains('provider_configs_v1'));
    expect(settingsJson, contains('test-key'));
    expect(settingsJson, isNot(contains('display_chat_font_scale_v1')));
    expect(settingsJson, isNot(contains('pinned_chat_ids')));
    final chatsEntry = archive.findFile('chats.json');
    expect(chatsEntry, isNotNull);
    final chatsJson = String.fromCharCodes(chatsEntry!.readBytes()!);
    expect(chatsJson, contains('Migration Source'));
    expect(chatsJson, contains('hello from sqlite'));
    await Future<void>.delayed(Duration.zero);
    final firstBackupStatus = statuses.firstWhere(
      (status) => status.stage == HiveToSqliteMigrationStage.backingUp,
    );
    expect(firstBackupStatus.detail, 'settings.json');
    expect(
      statuses.where(
        (status) => status.stage == HiveToSqliteMigrationStage.backingUp,
      ),
      isNot(
        contains(
          predicate<HiveToSqliteMigrationStatus>(
            (status) => status.detail == 'start',
          ),
        ),
      ),
    );
    expect(
      statuses.any(
        (status) =>
            status.stage == HiveToSqliteMigrationStage.backingUp &&
            status.backupItems.any(
              (item) => item.state == HiveToSqliteBackupItemState.active,
            ),
      ),
      isTrue,
    );
    final backupReadyIndex = statuses.indexWhere(
      (status) => status.stage == HiveToSqliteMigrationStage.backupReady,
    );
    expect(backupReadyIndex, isNonNegative);
    final beforeBackupReady = statuses.take(backupReadyIndex);
    expect(
      beforeBackupReady.any(
        (status) => status.backupItems.any(
          (item) => item.name == 'conversations.hive' && item.bytes > 0,
        ),
      ),
      isTrue,
    );
    expect(
      beforeBackupReady.any(
        (status) => status.backupItems.any(
          (item) => item.name == 'upload/' && item.bytes > 0,
        ),
      ),
      isTrue,
    );
    final backupReady = statuses.lastWhere(
      (status) => status.stage == HiveToSqliteMigrationStage.backupReady,
    );
    expect(
      backupReady.backupItems.map((item) => item.state),
      everyElement(HiveToSqliteBackupItemState.done),
    );

    await service.migrate(backupPath: backupFile.path);
    final firstMigrationStatus = statuses.firstWhere(
      (status) => status.stage == HiveToSqliteMigrationStage.migrating,
    );
    expect(firstMigrationStatus.detail, 'schema');
    expect(firstMigrationStatus.progress, 0);
    await service.dispose();

    final afterMigration = await HiveToSqliteMigrationService.check();
    expect(afterMigration.needsMigration, isFalse);
    expect(
      HiveMigrationMarker.isMigrationComplete(
        File('${tempDir.path}/kelivo.db'),
      ),
      isTrue,
    );

    final chatService = ChatService();
    await chatService.init();
    addTearDown(chatService.close);

    final migratedConversation = chatService.getConversation(conversation.id);
    expect(migratedConversation, isNotNull);
    expect(migratedConversation!.createdAt, conversation.createdAt);
    expect(migratedConversation.updatedAt, conversation.updatedAt);
    final migratedMessages = await chatService.loadMessages(conversation.id);
    expect(chatService.getMessageCount(conversation.id), 2);
    expect(migratedMessages.map((m) => m.content), [
      'hello from hive',
      'hello from sqlite',
    ]);
    expect(migratedMessages[0].timestamp, userMessage.timestamp);
    expect(migratedMessages[1].timestamp, assistantMessage.timestamp);
    final timeline = await chatService.loadActiveTimelineMessages(
      conversation.id,
    );
    expect(timeline.map((message) => message.id), [
      userMessage.id,
      assistantMessage.id,
    ]);
    expect(
      migratedMessages[1].reasoningStartAt,
      assistantMessage.reasoningStartAt,
    );
    expect(
      migratedMessages[1].reasoningFinishedAt,
      assistantMessage.reasoningFinishedAt,
    );
    expect(
      chatService.getToolEvents(assistantMessage.id).single['name'],
      'search',
    );
    expect(
      chatService.getGeminiThoughtSignature(assistantMessage.id),
      'gemini-signature',
    );
    await chatService.close();

    final repo = ChatDatabaseRepository.open(
      file: File('${tempDir.path}/kelivo.db'),
    );
    addTearDown(repo.close);
    expect(await repo.getTextPartCount(), 2);
    expect(await repo.getToolCallPartCount(), 1);
    expect(await repo.getTotalMessageCount(), 2);
    final digest = await repo.getTextPartContentDigest();
    expect(digest, isNotEmpty);
    expect(digest.length, 64);
    final raw = sqlite.sqlite3.open(
      '${tempDir.path}/kelivo.db',
      mode: sqlite.OpenMode.readOnly,
    );
    addTearDown(raw.close);
    expect(
      raw
          .select(
            "SELECT COUNT(*) AS c FROM message_part_rows WHERE kind = 'tool_result';",
          )
          .single['c'],
      0,
    );
  });

  test(
    'direct ZIP64 backup can omit chats.json without raw temp snapshots',
    () async {
      await _seedHiveChat(
        tempDir: tempDir,
        conversationId: 'conversation-direct-backup',
        messageId: 'message-direct-backup',
        content: 'large history fallback',
      );
      final decision = await HiveToSqliteMigrationService.check();
      final sourceBytes = await File(
        '${tempDir.path}/conversations.hive',
      ).readAsBytes();
      final service = HiveToSqliteMigrationService(decision)
        ..debugZip64ThresholdForTest = 0;
      addTearDown(service.dispose);
      final statuses = <HiveToSqliteMigrationStatus>[];
      final sub = service.statusStream.listen(statuses.add);
      addTearDown(sub.cancel);
      final output = File('${tempDir.path}/direct-migration-backup.zip');
      final outputHandle = await output.open(mode: FileMode.write);
      var streamedChunks = 0;

      try {
        await service.backupToWritableSink((bytes) async {
          streamedChunks++;
          expect(bytes.length, lessThanOrEqualTo(1024 * 1024));
          await outputHandle.writeFrom(bytes);
        }, includeChatsJson: false);
      } finally {
        await outputHandle.close();
      }

      final inputStream = InputFileStream(output.path);
      final archive = ZipDecoder().decodeStream(inputStream);
      addTearDown(inputStream.closeSync);
      addTearDown(archive.clearSync);
      expect(archive.findFile('chats.json'), isNull);
      expect(archive.findFile('conversations.hive')!.readBytes(), sourceBytes);
      expect(streamedChunks, greaterThan(0));
      expect(statuses.every((status) => status.backupPath == null), isTrue);
      expect(
        statuses.last.backupItems.map((item) => item.name),
        isNot(contains('chats.json')),
      );
      final leftoverWorkDirs = await tempDir
          .list()
          .where(
            (entity) =>
                entity is Directory &&
                entity.path.contains('.kelivo_migration_backup_'),
          )
          .toList();
      expect(leftoverWorkDirs, isEmpty);
    },
  );

  test(
    'validation fails when a text part payload is corrupted before validate',
    () async {
      await _seedHiveChat(
        tempDir: tempDir,
        conversationId: 'conversation-digest',
        messageId: 'message-digest',
        content: 'digest source',
      );
      final backupRoot = Directory('${tempDir.path}/backup-target')
        ..createSync();
      final decision = await HiveToSqliteMigrationService.check();
      final service = HiveToSqliteMigrationService(decision);
      addTearDown(service.dispose);
      final backupFile = await service.backupTo(backupRoot);
      service.debugBeforeValidateForTest = (repo) async {
        await repo.corruptTextPartPayloadForTest(
          'message-digest',
          'tampered-payload',
        );
      };

      await expectLater(
        service.migrate(backupPath: backupFile.path),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('text content digest'),
          ),
        ),
      );

      expect(backupFile.existsSync(), isTrue);
      expect(
        HiveMigrationMarker.isMigrationComplete(
          File('${tempDir.path}/kelivo.db'),
        ),
        isFalse,
      );
      expect(
        (await HiveToSqliteMigrationService.check()).needsMigration,
        isTrue,
      );
      expect(File('${tempDir.path}/messages.hive').existsSync(), isTrue);
    },
  );

  test(
    'validation fails when a text part is missing before validate',
    () async {
      await _seedHiveChat(
        tempDir: tempDir,
        conversationId: 'conversation-missing-text',
        messageId: 'message-missing-text',
        content: 'needs a text part',
      );
      final backupRoot = Directory('${tempDir.path}/backup-target')
        ..createSync();
      final decision = await HiveToSqliteMigrationService.check();
      final service = HiveToSqliteMigrationService(decision);
      addTearDown(service.dispose);
      final backupFile = await service.backupTo(backupRoot);
      service.debugBeforeValidateForTest = (repo) async {
        await repo.deleteTextPartsForTest('message-missing-text');
      };

      await expectLater(
        service.migrate(backupPath: backupFile.path),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('text content digest'),
          ),
        ),
      );

      expect(backupFile.existsSync(), isTrue);
      expect(
        HiveMigrationMarker.isMigrationComplete(
          File('${tempDir.path}/kelivo.db'),
        ),
        isFalse,
      );
      expect(File('${tempDir.path}/kelivo.db.migrating').existsSync(), isFalse);
      expect(File('${tempDir.path}/conversations.hive').existsSync(), isTrue);
    },
  );

  test(
    'migrates tool events as tool_call parts and never writes tool_result',
    () async {
      final conversation = Conversation(
        id: 'conversation-tools',
        title: 'Tools',
        createdAt: DateTime(2024, 5, 1),
        updatedAt: DateTime(2024, 5, 2),
      );
      final assistantMessage = ChatMessage(
        id: 'message-tools',
        role: 'assistant',
        content: 'used a tool',
        conversationId: conversation.id,
        timestamp: DateTime(2024, 5, 1, 10),
      );
      conversation.messageIds.add(assistantMessage.id);

      _registerHiveAdapters();
      Hive.init(tempDir.path);
      final conversations = await Hive.openBox<Conversation>('conversations');
      final messages = await Hive.openBox<ChatMessage>('messages');
      final toolEvents = await Hive.openBox<dynamic>('tool_events_v1');
      await conversations.put(conversation.id, conversation);
      await messages.put(assistantMessage.id, assistantMessage);
      await toolEvents.put(assistantMessage.id, [
        {
          'id': 'tool-a',
          'name': 'search',
          'arguments': {'query': 'a'},
          'content': 'a-result',
        },
        {
          'id': 'tool-b',
          'name': 'lookup',
          'arguments': {'id': 'b'},
          'content': 'b-result',
        },
      ]);
      await conversations.close();
      await messages.close();
      await toolEvents.close();
      await Hive.close();

      final service = HiveToSqliteMigrationService(
        await HiveToSqliteMigrationService.check(),
      );
      addTearDown(service.dispose);
      await service.migrate();

      final repo = ChatDatabaseRepository.open(
        file: File('${tempDir.path}/kelivo.db'),
      );
      addTearDown(repo.close);
      expect(await repo.getTotalMessageCount(), 1);
      expect(await repo.getTextPartCount(), 1);
      expect(await repo.getToolCallPartCount(), 2);

      await repo.close();
      final raw = sqlite.sqlite3.open(
        '${tempDir.path}/kelivo.db',
        mode: sqlite.OpenMode.readOnly,
      );
      addTearDown(raw.close);
      final kinds = {
        for (final row in raw.select(
          'SELECT kind, COUNT(*) AS c FROM message_part_rows GROUP BY kind;',
        ))
          row['kind'] as String: row['c'] as int,
      };
      expect(kinds, {'text': 1, 'tool_call': 2});
      expect(kinds.containsKey('tool_result'), isFalse);
      expect(
        raw
            .select(
              "SELECT COUNT(*) AS c FROM message_part_rows WHERE kind = 'tool_result';",
            )
            .single['c'],
        0,
      );
    },
  );

  test(
    'digest isolate infrastructure failure falls back without failing migration',
    () async {
      await _seedHiveChat(
        tempDir: tempDir,
        conversationId: 'conversation-digest-fallback',
        messageId: 'message-digest-fallback',
        content: 'fallback still validates',
      );
      final decision = await HiveToSqliteMigrationService.check();
      final service = HiveToSqliteMigrationService(decision);
      addTearDown(service.dispose);
      service.debugBeforeValidateForTest = (repo) async {
        // Force the worker-isolate path to throw before spawn; validation must
        // continue via the Drift in-process digest and complete the migration.
        repo.debugForceTextPartDigestIsolateFailureForTest = true;
      };

      await service.migrate();

      expect(
        HiveMigrationMarker.isMigrationComplete(
          File('${tempDir.path}/kelivo.db'),
        ),
        isTrue,
      );
      expect(
        (await HiveToSqliteMigrationService.check()).needsMigration,
        isFalse,
      );
      final repo = ChatDatabaseRepository.open(
        file: File('${tempDir.path}/kelivo.db'),
      );
      addTearDown(repo.close);
      expect(await repo.getTextPartCount(), 1);
      expect(await repo.getTotalMessageCount(), 1);
    },
  );

  test(
    'attachment-only message (no text) migrates without validation failure',
    () async {
      // Reproduces the release-blocking case: a message whose entire legacy
      // content is a single attachment marker. The decoder emits zero
      // TextParts, so the digest expectation must also be empty; a stale
      // [''] fallback made the text-content digest mismatch and rolled back
      // the whole migration.
      await _seedHiveChat(
        tempDir: tempDir,
        conversationId: 'conversation-attachment-only',
        messageId: 'message-attachment-only',
        content: '[image:/tmp/only-an-image.png]',
      );

      final service = HiveToSqliteMigrationService(
        await HiveToSqliteMigrationService.check(),
      );
      addTearDown(service.dispose);

      await service.migrate();

      expect(
        HiveMigrationMarker.isMigrationComplete(
          File('${tempDir.path}/kelivo.db'),
        ),
        isTrue,
      );
      expect(
        (await HiveToSqliteMigrationService.check()).needsMigration,
        isFalse,
      );

      final repo = ChatDatabaseRepository.open(
        file: File('${tempDir.path}/kelivo.db'),
      );
      addTearDown(repo.close);
      expect(await repo.getTotalMessageCount(), 1);
      expect(await repo.getTextPartCount(), 0);
      expect(await repo.getImagePartCount(), 1);
    },
  );

  test(
    'a single undecodable message is skipped without failing migration',
    () async {
      final conversation = Conversation(
        id: 'conversation-isolate',
        title: 'Isolate',
        createdAt: DateTime(2024, 7, 1),
        updatedAt: DateTime(2024, 7, 2),
      );
      final good = ChatMessage(
        id: 'message-good',
        role: 'user',
        content: 'survives migration',
        conversationId: conversation.id,
        timestamp: DateTime(2024, 7, 1, 10),
      );
      final bad = ChatMessage(
        id: 'message-bad',
        role: 'assistant',
        content: 'this one blows up',
        conversationId: conversation.id,
        timestamp: DateTime(2024, 7, 1, 11),
      );
      conversation.messageIds.addAll([good.id, bad.id]);

      _registerHiveAdapters();
      Hive.init(tempDir.path);
      final conversations = await Hive.openBox<Conversation>('conversations');
      final messages = await Hive.openBox<ChatMessage>('messages');
      await conversations.put(conversation.id, conversation);
      await messages.put(good.id, good);
      await messages.put(bad.id, bad);
      await conversations.close();
      await messages.close();
      await Hive.close();

      final service = HiveToSqliteMigrationService(
        await HiveToSqliteMigrationService.check(),
      );
      addTearDown(service.dispose);
      service.debugFailMessageIdsForTest = {'message-bad'};

      await service.migrate();

      expect(
        HiveMigrationMarker.isMigrationComplete(
          File('${tempDir.path}/kelivo.db'),
        ),
        isTrue,
      );
      expect(
        (await HiveToSqliteMigrationService.check()).needsMigration,
        isFalse,
      );

      final repo = ChatDatabaseRepository.open(
        file: File('${tempDir.path}/kelivo.db'),
      );
      addTearDown(repo.close);
      // The conversation and the decodable message survive; the corrupt
      // message is dropped rather than rolling back the whole migration.
      expect(await repo.getTotalMessageCount(), 1);
      final ids = (await repo.getAllConversations())
          .map((conversation) => conversation.id)
          .toList();
      expect(ids, contains('conversation-isolate'));
    },
  );

  test(
    'an undecodable conversation record is skipped without failing migration',
    () async {
      final good = Conversation(
        id: 'conversation-good',
        title: 'Good',
        createdAt: DateTime(2024, 7, 1),
        updatedAt: DateTime(2024, 7, 2),
      );
      final bad = Conversation(
        id: 'conversation-bad',
        title: 'Bad',
        createdAt: DateTime(2024, 7, 1),
        updatedAt: DateTime(2024, 7, 3),
      );
      final goodMessage = ChatMessage(
        id: 'message-good-conversation',
        role: 'user',
        content: 'survives migration',
        conversationId: good.id,
        timestamp: DateTime(2024, 7, 1, 10),
      );
      good.messageIds.add(goodMessage.id);

      _registerHiveAdapters();
      Hive.init(tempDir.path);
      final conversations = await Hive.openBox<Conversation>('conversations');
      final messages = await Hive.openBox<ChatMessage>('messages');
      await conversations.put(good.id, good);
      await conversations.put(bad.id, bad);
      await messages.put(goodMessage.id, goodMessage);
      await conversations.close();
      await messages.close();
      await Hive.close();

      final service = HiveToSqliteMigrationService(
        await HiveToSqliteMigrationService.check(),
      );
      addTearDown(service.dispose);
      service.debugFailConversationKeysForTest = {'conversation-bad'};

      await service.migrate();

      expect(
        HiveMigrationMarker.isMigrationComplete(
          File('${tempDir.path}/kelivo.db'),
        ),
        isTrue,
      );
      final repo = ChatDatabaseRepository.open(
        file: File('${tempDir.path}/kelivo.db'),
      );
      addTearDown(repo.close);
      final ids = (await repo.getAllConversations())
          .map((conversation) => conversation.id)
          .toList();
      expect(ids, contains('conversation-good'));
      expect(ids, isNot(contains('conversation-bad')));
      expect(await repo.getTotalMessageCount(), 1);
    },
  );

  test(
    'a message that fails to decode during prescan does not abort migration',
    () async {
      // truncateIndex > 0 forces _convertLegacyTruncateIndex to pre-read
      // messages before the tolerant main loop reaches them.
      final conversation = Conversation(
        id: 'conversation-prescan',
        title: 'Prescan',
        createdAt: DateTime(2024, 7, 1),
        updatedAt: DateTime(2024, 7, 2),
        truncateIndex: 1,
      );
      final first = ChatMessage(
        id: 'message-prescan-first',
        role: 'user',
        content: 'read during prescan',
        conversationId: conversation.id,
        timestamp: DateTime(2024, 7, 1, 10),
      );
      final second = ChatMessage(
        id: 'message-prescan-second',
        role: 'assistant',
        content: 'after truncate point',
        conversationId: conversation.id,
        timestamp: DateTime(2024, 7, 1, 11),
      );
      conversation.messageIds.addAll([first.id, second.id]);

      _registerHiveAdapters();
      Hive.init(tempDir.path);
      final conversations = await Hive.openBox<Conversation>('conversations');
      final messages = await Hive.openBox<ChatMessage>('messages');
      await conversations.put(conversation.id, conversation);
      await messages.put(first.id, first);
      await messages.put(second.id, second);
      await conversations.close();
      await messages.close();
      await Hive.close();

      final service = HiveToSqliteMigrationService(
        await HiveToSqliteMigrationService.check(),
      );
      addTearDown(service.dispose);
      service.debugFailPrescanMessageIdsForTest = {first.id};

      await service.migrate();

      expect(
        HiveMigrationMarker.isMigrationComplete(
          File('${tempDir.path}/kelivo.db'),
        ),
        isTrue,
      );
      final repo = ChatDatabaseRepository.open(
        file: File('${tempDir.path}/kelivo.db'),
      );
      addTearDown(repo.close);
      // The prescan failure only degrades the truncate-index repair; the
      // main loop still migrates both messages.
      expect(await repo.getTotalMessageCount(), 2);
    },
  );

  test('an empty legacy role is repaired instead of aborting', () async {
    final conversation = Conversation(
      id: 'conversation-empty-role',
      title: 'Empty Role',
      createdAt: DateTime(2024, 7, 1),
      updatedAt: DateTime(2024, 7, 2),
    );
    final message = ChatMessage(
      id: 'message-empty-role',
      role: '',
      content: 'kept with repaired role',
      conversationId: conversation.id,
      timestamp: DateTime(2024, 7, 1, 10),
    );
    conversation.messageIds.add(message.id);

    _registerHiveAdapters();
    Hive.init(tempDir.path);
    final conversations = await Hive.openBox<Conversation>('conversations');
    final messages = await Hive.openBox<ChatMessage>('messages');
    await conversations.put(conversation.id, conversation);
    await messages.put(message.id, message);
    await conversations.close();
    await messages.close();
    await Hive.close();

    final service = HiveToSqliteMigrationService(
      await HiveToSqliteMigrationService.check(),
    );
    addTearDown(service.dispose);

    await service.migrate();

    final chatService = ChatService();
    await chatService.init();
    addTearDown(chatService.close);
    final migrated = await chatService.loadMessages(conversation.id);
    expect(migrated, hasLength(1));
    expect(migrated.single.role, 'user');
    expect(migrated.single.content, 'kept with repaired role');
  });

  test(
    'validation failure keeps hive backup and leaves migration incomplete',
    () async {
      await _seedHiveChat(
        tempDir: tempDir,
        conversationId: 'conversation-rollback',
        messageId: 'message-rollback',
        content: 'rollback me',
      );
      final backupRoot = Directory('${tempDir.path}/backup-target')
        ..createSync();
      final decision = await HiveToSqliteMigrationService.check();
      final service = HiveToSqliteMigrationService(decision);
      addTearDown(service.dispose);
      final backupFile = await service.backupTo(backupRoot);
      expect(backupFile.existsSync(), isTrue);
      service.debugBeforeValidateForTest = (repo) async {
        await repo.deleteTextPartsForTest('message-rollback');
      };

      await expectLater(
        service.migrate(backupPath: backupFile.path),
        throwsA(isA<StateError>()),
      );

      expect(backupFile.existsSync(), isTrue);
      expect(
        HiveMigrationMarker.isMigrationComplete(
          File('${tempDir.path}/kelivo.db'),
        ),
        isFalse,
      );
      expect(
        (await HiveToSqliteMigrationService.check()).needsMigration,
        isTrue,
      );
      expect(File('${tempDir.path}/conversations.hive').existsSync(), isTrue);
      expect(File('${tempDir.path}/messages.hive').existsSync(), isTrue);
      expect(File('${tempDir.path}/kelivo.db').existsSync(), isFalse);
      expect(File('${tempDir.path}/kelivo.db.migrating').existsSync(), isFalse);

      // Retry succeeds once the injected corruption hook is cleared.
      final retry = HiveToSqliteMigrationService(
        await HiveToSqliteMigrationService.check(),
      );
      addTearDown(retry.dispose);
      await retry.migrate(backupPath: backupFile.path);
      expect(
        HiveMigrationMarker.isMigrationComplete(
          File('${tempDir.path}/kelivo.db'),
        ),
        isTrue,
      );
    },
  );

  for (final legacyActivation in <String, Object>{
    'instruction_injections_active_id_v1': 'learning-mode',
    'instruction_injections_active_ids_v1': '["learning-mode","review"]',
  }.entries) {
    test(
      'disaster backup preserves ${legacyActivation.key} for restoration',
      () async {
        SharedPreferences.setMockInitialValues({
          legacyActivation.key: legacyActivation.value,
        });
        _registerHiveAdapters();
        Hive.init(tempDir.path);
        await Hive.openBox<Conversation>('conversations');
        await Hive.close();

        final decision = await HiveToSqliteMigrationService.check();
        expect(decision.needsMigration, isTrue);
        final service = HiveToSqliteMigrationService(decision);
        addTearDown(service.dispose);

        final backupRoot = Directory('${tempDir.path}/backup-target');
        final backupFile = await service.backupTo(backupRoot);
        final inputStream = InputFileStream(backupFile.path);
        final archive = ZipDecoder().decodeStream(inputStream);
        addTearDown(inputStream.closeSync);
        addTearDown(archive.clearSync);

        final settingsEntry = archive.findFile('settings.json');
        expect(settingsEntry, isNotNull);
        final settings =
            jsonDecode(String.fromCharCodes(settingsEntry!.readBytes()!))
                as Map<String, dynamic>;
        expect(
          settings,
          containsPair(legacyActivation.key, legacyActivation.value),
        );
      },
    );
  }

  test('migrates chat data across multiple message batches', () async {
    const messageCount = 130;
    final baseTime = DateTime(2024, 2, 1, 9);
    final conversation = Conversation(
      id: 'conversation-many',
      title: 'Large Migration Source',
      createdAt: baseTime,
      updatedAt: baseTime.add(const Duration(hours: 1)),
      assistantId: 'assistant-many',
      mcpServerIds: ['filesystem', 'search'],
      truncateIndex: messageCount,
      versionSelections: {'group-12': 1},
      summary: 'large summary',
      lastSummarizedMessageCount: 64,
      chatSuggestions: ['next'],
    );
    final messages = [
      for (var i = 0; i < messageCount; i++)
        ChatMessage(
          id: 'message-$i',
          role: i.isEven ? 'user' : 'assistant',
          content: 'message content $i',
          conversationId: conversation.id,
          timestamp: baseTime.add(Duration(minutes: i)),
          modelId: i.isOdd ? 'model-$i' : null,
          providerId: i.isOdd ? 'provider' : null,
          groupId: i == 110 ? 'group-12' : 'group-$i',
          version: i == 110 ? 2 : i % 3,
          promptTokens: i,
          completionTokens: i + 1,
        ),
    ];
    conversation.messageIds.addAll(messages.map((message) => message.id));

    _registerHiveAdapters();
    Hive.init(tempDir.path);
    final conversations = await Hive.openBox<Conversation>('conversations');
    final messagesBox = await Hive.openBox<ChatMessage>('messages');
    final toolEvents = await Hive.openBox<dynamic>('tool_events_v1');
    await conversations.put(conversation.id, conversation);
    for (final message in messages) {
      await messagesBox.put(message.id, message);
    }
    await toolEvents.put('message-129', [
      {
        'id': 'tool-large',
        'name': 'batch-check',
        'content': 'last batch result',
      },
    ]);
    await toolEvents.put('sig_message-129', 'last-batch-signature');
    await conversations.close();
    await messagesBox.close();
    await toolEvents.close();
    await Hive.close();

    final decision = await HiveToSqliteMigrationService.check();
    expect(decision.needsMigration, isTrue);

    final service = HiveToSqliteMigrationService(decision);
    final statuses = <HiveToSqliteMigrationStatus>[];
    final sub = service.statusStream.listen(statuses.add);
    addTearDown(sub.cancel);
    await service.migrate();
    await service.dispose();

    expect(
      statuses
          .where(
            (status) =>
                status.stage == HiveToSqliteMigrationStage.migrating &&
                status.detail == 'messages',
          )
          .length,
      greaterThanOrEqualTo(2),
    );

    final chatService = ChatService();
    await chatService.init();
    addTearDown(chatService.close);

    final migratedConversation = chatService.getConversation(conversation.id);
    expect(migratedConversation, isNotNull);
    expect(migratedConversation!.mcpServerIds, ['filesystem', 'search']);
    expect(migratedConversation.truncateIndex, messageCount - 1);
    expect(migratedConversation.versionSelections, {'group-12': 2});
    expect(migratedConversation.summary, 'large summary');
    expect(migratedConversation.lastSummarizedMessageCount, 64);
    expect(migratedConversation.chatSuggestions, ['next']);

    final migratedMessages = await chatService.loadMessages(conversation.id);
    expect(migratedMessages, hasLength(messageCount));
    expect(migratedMessages.first.id, 'message-0');
    expect(migratedMessages[127].id, 'message-127');
    expect(migratedMessages.last.id, 'message-129');
    expect(migratedMessages.last.timestamp, messages.last.timestamp);
    expect(migratedMessages.last.modelId, messages.last.modelId);
    expect(migratedMessages.last.promptTokens, messages.last.promptTokens);
    final timeline = await chatService.loadActiveTimelineMessages(
      conversation.id,
    );
    expect(timeline, hasLength(messageCount - 1));
    expect(chatService.getContextStartIndex(conversation.id), messageCount - 1);
    expect(
      await chatService.loadSelectedContextMessages(
        conversation.id,
        truncateIndex: migratedConversation.truncateIndex,
        limit: messageCount,
      ),
      isEmpty,
    );
    expect(
      chatService.getToolEvents('message-129').single['name'],
      'batch-check',
    );
    expect(
      chatService.getGeminiThoughtSignature('message-129'),
      'last-batch-signature',
    );
  });

  test('repairs duplicate versions and preserves selection identity', () async {
    final baseTime = DateTime(2024, 3, 1, 9);
    final conversation = Conversation(
      id: 'conversation-dup-versions',
      title: 'Duplicate Versions Source',
      createdAt: baseTime,
      updatedAt: baseTime.add(const Duration(hours: 1)),
      versionSelections: {'dup-group': 1},
    );
    final messages = [
      ChatMessage(
        id: 'dup-a',
        role: 'assistant',
        content: 'first take',
        conversationId: conversation.id,
        timestamp: baseTime,
        groupId: 'dup-group',
        version: 0,
      ),
      ChatMessage(
        id: 'dup-b',
        role: 'assistant',
        content: 'second take',
        conversationId: conversation.id,
        timestamp: baseTime.add(const Duration(minutes: 1)),
        groupId: 'dup-group',
        version: 0,
      ),
      // '' is stored verbatim and is a real value to the SQLite unique
      // (conversationId, groupId, version) index, so empty-string groups
      // need the same version repair as named groups.
      ChatMessage(
        id: 'empty-a',
        role: 'assistant',
        content: 'empty group first',
        conversationId: conversation.id,
        timestamp: baseTime.add(const Duration(minutes: 2)),
        groupId: '',
        version: 0,
      ),
      ChatMessage(
        id: 'empty-b',
        role: 'assistant',
        content: 'empty group second',
        conversationId: conversation.id,
        timestamp: baseTime.add(const Duration(minutes: 3)),
        groupId: '',
        version: 0,
      ),
    ];
    conversation.messageIds.addAll(messages.map((message) => message.id));

    _registerHiveAdapters();
    Hive.init(tempDir.path);
    final conversations = await Hive.openBox<Conversation>('conversations');
    final messagesBox = await Hive.openBox<ChatMessage>('messages');
    await conversations.put(conversation.id, conversation);
    for (final message in messages) {
      await messagesBox.put(message.id, message);
    }
    await conversations.close();
    await messagesBox.close();
    await Hive.close();

    final decision = await HiveToSqliteMigrationService.check();
    expect(decision.needsMigration, isTrue);

    final service = HiveToSqliteMigrationService(decision);
    await service.migrate();
    await service.dispose();

    final chatService = ChatService();
    await chatService.init();
    addTearDown(chatService.close);

    final migrated = await chatService.loadMessages(conversation.id);
    expect(migrated.map((m) => m.id).toList(), [
      'dup-a',
      'dup-b',
      'empty-a',
      'empty-b',
    ]);
    expect(
      migrated
          .where((m) => m.groupId == 'dup-group')
          .map((m) => m.version)
          .toSet(),
      {0, 1},
    );
    expect(
      migrated.where((m) => m.groupId == '').map((m) => m.version).toSet(),
      {0, 1},
    );
    expect(chatService.getConversation(conversation.id)?.versionSelections, {
      'dup-group': 1,
    });
    final timeline = await chatService.loadActiveTimelineMessages(
      conversation.id,
    );
    expect(
      timeline.singleWhere((message) => message.groupId == 'dup-group').id,
      'dup-b',
    );
  });

  test('sanitizes negative durations and tokens from clock rollback', () async {
    final baseTime = DateTime(2024, 4, 1, 8);
    // Conversation counters below the schema CHECK floors (-1 / 0 / -1).
    final conversation = Conversation(
      id: 'conversation-dirty-numbers',
      title: 'Dirty Numbers Source',
      createdAt: baseTime,
      updatedAt: baseTime.add(const Duration(hours: 1)),
      truncateIndex: -7,
      lastSummarizedMessageCount: -3,
      lastMemoryExtractedOrder: -9,
    );
    final messages = [
      // Device clock rolled back mid-generation: negative duration and a
      // reasoning finish timestamp earlier than its start.
      ChatMessage(
        id: 'dirty-message',
        role: 'assistant',
        content: 'generated during clock rollback',
        conversationId: conversation.id,
        timestamp: baseTime,
        durationMs: -55696,
        totalTokens: -1,
        promptTokens: -2,
        completionTokens: -3,
        cachedTokens: -4,
        reasoningStartAt: baseTime.add(const Duration(minutes: 2)),
        reasoningFinishedAt: baseTime,
      ),
      ChatMessage(
        id: 'clean-message',
        role: 'assistant',
        content: 'normal message',
        conversationId: conversation.id,
        timestamp: baseTime.add(const Duration(minutes: 1)),
        durationMs: 1234,
        totalTokens: 10,
        promptTokens: 4,
        completionTokens: 6,
        reasoningStartAt: baseTime.add(const Duration(minutes: 1)),
        reasoningFinishedAt: baseTime.add(
          const Duration(minutes: 1, seconds: 5),
        ),
      ),
    ];
    conversation.messageIds.addAll(messages.map((message) => message.id));

    _registerHiveAdapters();
    Hive.init(tempDir.path);
    final conversations = await Hive.openBox<Conversation>('conversations');
    final messagesBox = await Hive.openBox<ChatMessage>('messages');
    await conversations.put(conversation.id, conversation);
    for (final message in messages) {
      await messagesBox.put(message.id, message);
    }
    await conversations.close();
    await messagesBox.close();
    await Hive.close();

    final decision = await HiveToSqliteMigrationService.check();
    expect(decision.needsMigration, isTrue);

    final service = HiveToSqliteMigrationService(decision);
    await service.migrate();
    await service.dispose();

    final chatService = ChatService();
    await chatService.init();
    addTearDown(chatService.close);

    final migrated = await chatService.loadMessages(conversation.id);
    expect(migrated.map((m) => m.id).toList(), [
      'dirty-message',
      'clean-message',
    ]);
    final dirty = migrated.singleWhere((m) => m.id == 'dirty-message');
    expect(dirty.durationMs, isNull);
    expect(dirty.totalTokens, isNull);
    expect(dirty.promptTokens, isNull);
    expect(dirty.completionTokens, isNull);
    expect(dirty.cachedTokens, isNull);
    expect(dirty.reasoningStartAt, isNotNull);
    expect(dirty.reasoningFinishedAt, isNull);
    expect(dirty.content, 'generated during clock rollback');
    final clean = migrated.singleWhere((m) => m.id == 'clean-message');
    expect(clean.durationMs, 1234);
    expect(clean.totalTokens, 10);
    expect(clean.reasoningFinishedAt, isNotNull);
    final migratedConversation = chatService.getConversation(conversation.id);
    expect(migratedConversation, isNotNull);
    expect(migratedConversation!.truncateIndex, -1);
    expect(migratedConversation.lastSummarizedMessageCount, 0);
    expect(migratedConversation.lastMemoryExtractedOrder, -1);
  });

  test(
    'failed migration removes the leftover .migrating database family',
    () async {
      _registerHiveAdapters();
      Hive.init(tempDir.path);
      final conversations = await Hive.openBox<Conversation>('conversations');
      await conversations.close();
      await Hive.close();
      // A directory at the target path makes the final replace step fail
      // after the temporary database was fully written.
      await Directory('${tempDir.path}/kelivo.db').create();
      final staleTemp = File('${tempDir.path}/kelivo.db.migrating');
      final staleWal = File('${tempDir.path}/kelivo.db.migrating-wal');

      final service = HiveToSqliteMigrationService(
        HiveToSqliteMigrationDecision(
          needsMigration: true,
          appDataDir: tempDir,
          sqliteFile: File('${tempDir.path}/kelivo.db'),
          hiveFiles: [File('${tempDir.path}/conversations.hive')],
        ),
      );
      addTearDown(service.dispose);

      await expectLater(service.migrate(), throwsA(anything));
      expect(await staleTemp.exists(), isFalse);
      expect(await staleWal.exists(), isFalse);
    },
  );

  test(
    'does not show empty resource directories in initial backup items',
    () async {
      final hiveFile = File('${tempDir.path}/conversations.hive');
      await hiveFile.writeAsBytes([1, 2, 3]);
      await Directory('${tempDir.path}/upload').create(recursive: true);
      await Directory('${tempDir.path}/fonts').create(recursive: true);

      final service = HiveToSqliteMigrationService(
        HiveToSqliteMigrationDecision(
          needsMigration: true,
          appDataDir: tempDir,
          sqliteFile: File('${tempDir.path}/kelivo.db'),
          hiveFiles: [hiveFile],
        ),
      );

      final itemNames = service.initialStatus().backupItems.map(
        (item) => item.name,
      );
      expect(itemNames, contains('conversations.hive'));
      expect(itemNames, isNot(contains('upload/')));
      expect(itemNames, isNot(contains('fonts/')));
      await service.dispose();
    },
  );

  test(
    'attempt counter persists across process kill and unlocks skip at 2',
    () async {
      _registerHiveAdapters();
      Hive.init(tempDir.path);
      final conversations = await Hive.openBox<Conversation>('conversations');
      await conversations.close();
      await Hive.close();
      // A directory at the live path makes publish fail after the attempt is
      // recorded, simulating a hard failure without needing a real OOM.
      await Directory('${tempDir.path}/kelivo.db').create();

      final decision = HiveToSqliteMigrationDecision(
        needsMigration: true,
        appDataDir: tempDir,
        sqliteFile: File('${tempDir.path}/kelivo.db'),
        hiveFiles: [File('${tempDir.path}/conversations.hive')],
      );

      final first = HiveToSqliteMigrationService(decision);
      addTearDown(first.dispose);
      expect(first.canOfferSkip, isFalse);
      await expectLater(first.migrate(), throwsA(anything));
      expect(first.attemptCount, 1);
      expect(first.canOfferSkip, isFalse);
      expect(first.lastAttemptStage, isNotNull);

      // Fresh service instance ≈ process relaunch against the same app data dir.
      final second = HiveToSqliteMigrationService(decision);
      addTearDown(second.dispose);
      expect(await second.loadAttemptState(), 1);
      expect(second.canOfferSkip, isFalse);
      await expectLater(second.migrate(), throwsA(anything));
      expect(second.attemptCount, 2);
      expect(second.canOfferSkip, isTrue);

      final relaunched = HiveToSqliteMigrationService(decision);
      addTearDown(relaunched.dispose);
      expect(await relaunched.loadAttemptState(), 2);
      expect(relaunched.canOfferSkip, isTrue);
      expect(relaunched.lastAttemptStage, isNotNull);
    },
  );

  test(
    'recordFailedAttempt counts backup-phase failures and unlocks skip',
    () async {
      _registerHiveAdapters();
      Hive.init(tempDir.path);
      final conversations = await Hive.openBox<Conversation>('conversations');
      await conversations.close();
      await Hive.close();

      final decision = await HiveToSqliteMigrationService.check();

      // A backup failure happens before migrate(), so the attempt counter must
      // advance without ever entering the migrate path.
      final first = HiveToSqliteMigrationService(decision);
      addTearDown(first.dispose);
      expect(first.canOfferSkip, isFalse);
      await first.recordFailedAttempt();
      expect(first.attemptCount, 1);
      expect(first.canOfferSkip, isFalse);

      // Fresh instance ≈ relaunch: the count is read back from disk and a
      // second backup failure crosses the skip threshold.
      final second = HiveToSqliteMigrationService(decision);
      addTearDown(second.dispose);
      expect(await second.loadAttemptState(), 1);
      await second.recordFailedAttempt();
      expect(second.attemptCount, 2);
      expect(second.canOfferSkip, isTrue);

      final relaunched = HiveToSqliteMigrationService(decision);
      addTearDown(relaunched.dispose);
      expect(await relaunched.loadAttemptState(), 2);
      expect(relaunched.canOfferSkip, isTrue);
    },
  );

  test('attempt counter clears after successful migration', () async {
    final conversation = Conversation(
      id: 'conversation-clear-attempts',
      title: 'Clear Attempts',
      createdAt: DateTime(2024, 4, 1),
      updatedAt: DateTime(2024, 4, 2),
    );
    final message = ChatMessage(
      id: 'message-clear',
      role: 'user',
      content: 'hello',
      conversationId: conversation.id,
      timestamp: DateTime(2024, 4, 1, 10),
    );
    conversation.messageIds.add(message.id);

    _registerHiveAdapters();
    Hive.init(tempDir.path);
    final conversations = await Hive.openBox<Conversation>('conversations');
    final messages = await Hive.openBox<ChatMessage>('messages');
    await conversations.put(conversation.id, conversation);
    await messages.put(message.id, message);
    await conversations.close();
    await messages.close();
    await Hive.close();

    final decision = await HiveToSqliteMigrationService.check();
    final priming = HiveToSqliteMigrationService(
      HiveToSqliteMigrationDecision(
        needsMigration: true,
        appDataDir: tempDir,
        sqliteFile: File('${tempDir.path}/kelivo.db'),
        hiveFiles: decision.hiveFiles,
      ),
    );
    addTearDown(priming.dispose);
    await Directory('${tempDir.path}/kelivo.db').create();
    await expectLater(priming.migrate(), throwsA(anything));
    expect(priming.attemptCount, 1);
    await Directory('${tempDir.path}/kelivo.db').delete(recursive: true);

    final service = HiveToSqliteMigrationService(
      await HiveToSqliteMigrationService.check(),
    );
    addTearDown(service.dispose);
    expect(await service.loadAttemptState(), 1);
    await service.migrate();
    expect(service.attemptCount, 0);
    expect(service.canOfferSkip, isFalse);

    final relaunched = HiveToSqliteMigrationService(
      await HiveToSqliteMigrationService.check(),
    );
    addTearDown(relaunched.dispose);
    expect(await relaunched.loadAttemptState(), 0);
    expect(
      File(
        '${tempDir.path}/hive_to_sqlite_migration_attempt_v1.json',
      ).existsSync(),
      isFalse,
    );
  });

  test('attempt counter clears when migration is skipped', () async {
    final hiveFile = File('${tempDir.path}/conversations.hive')
      ..writeAsBytesSync([1, 2, 3]);
    final decision = HiveToSqliteMigrationDecision(
      needsMigration: true,
      appDataDir: tempDir,
      sqliteFile: File('${tempDir.path}/kelivo.db'),
      hiveFiles: [hiveFile],
    );
    final stateFile = File(
      '${tempDir.path}/hive_to_sqlite_migration_attempt_v1.json',
    );
    await stateFile.writeAsString(
      '{"attempts":2,"stage":"migrating/messages"}',
    );

    final service = HiveToSqliteMigrationService(decision);
    addTearDown(service.dispose);
    expect(await service.loadAttemptState(), 2);
    expect(service.canOfferSkip, isTrue);

    await service.skipMigrationAndStartFresh();
    expect(service.attemptCount, 0);
    expect(service.canOfferSkip, isFalse);
    expect(stateFile.existsSync(), isFalse);
    expect(File('${hiveFile.path}.retired').existsSync(), isTrue);
  });

  test(
    'replaceSqlite publishes the migrated database on the happy path',
    () async {
      final live = File('${tempDir.path}/kelivo.db')
        ..writeAsStringSync('old-placeholder');
      final temp = File('${tempDir.path}/kelivo.db.migrating')
        ..writeAsStringSync('migrated-contents');
      final service = HiveToSqliteMigrationService(
        HiveToSqliteMigrationDecision(
          needsMigration: true,
          appDataDir: tempDir,
          sqliteFile: live,
          hiveFiles: const <File>[],
        ),
      );
      addTearDown(service.dispose);

      await service.replaceSqliteForTest(temp, live);

      expect(await live.readAsString(), 'migrated-contents');
      expect(temp.existsSync(), isFalse);
      expect(File('${live.path}.previous').existsSync(), isFalse);
    },
  );

  test('replaceSqlite fails loudly when a temp -wal sidecar exists', () async {
    final live = File('${tempDir.path}/kelivo.db')
      ..writeAsStringSync('old-placeholder');
    final temp = File('${tempDir.path}/kelivo.db.migrating')
      ..writeAsStringSync('migrated-contents');
    File('${temp.path}-wal').writeAsStringSync('stray-wal');
    final service = HiveToSqliteMigrationService(
      HiveToSqliteMigrationDecision(
        needsMigration: true,
        appDataDir: tempDir,
        sqliteFile: live,
        hiveFiles: const <File>[],
      ),
    );
    addTearDown(service.dispose);

    await expectLater(
      service.replaceSqliteForTest(temp, live),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'database_sidecar:-wal',
        ),
      ),
    );
    expect(await live.readAsString(), 'old-placeholder');
    expect(await temp.readAsString(), 'migrated-contents');
  });

  test(
    'replaceSqlite ignores a stray -wal next to the live placeholder',
    () async {
      final live = File('${tempDir.path}/kelivo.db')
        ..writeAsStringSync('old-placeholder');
      final liveWal = File('${live.path}-wal')
        ..writeAsStringSync('stale-placeholder-wal');
      final temp = File('${tempDir.path}/kelivo.db.migrating')
        ..writeAsStringSync('migrated-contents');
      final service = HiveToSqliteMigrationService(
        HiveToSqliteMigrationDecision(
          needsMigration: true,
          appDataDir: tempDir,
          sqliteFile: live,
          hiveFiles: const <File>[],
        ),
      );
      addTearDown(service.dispose);

      await service.replaceSqliteForTest(temp, live);

      expect(await live.readAsString(), 'migrated-contents');
      expect(temp.existsSync(), isFalse);
      expect(liveWal.existsSync(), isFalse);
      expect(File('${live.path}.previous').existsSync(), isFalse);
      expect(File('${live.path}.previous-wal').existsSync(), isFalse);
    },
  );

  test('replaceSqlite recovers after rename-aside before move-in', () async {
    final live = File('${tempDir.path}/kelivo.db');
    final temp = File('${tempDir.path}/kelivo.db.migrating')
      ..writeAsStringSync('migrated-contents');
    final aside = File('${live.path}.previous')
      ..writeAsStringSync('old-placeholder');
    // Simulate kill after rename-aside: live gone, aside + temp remain.
    expect(live.existsSync(), isFalse);

    final service = HiveToSqliteMigrationService(
      HiveToSqliteMigrationDecision(
        needsMigration: true,
        appDataDir: tempDir,
        sqliteFile: live,
        hiveFiles: const <File>[],
      ),
    );
    addTearDown(service.dispose);

    await service.replaceSqliteForTest(temp, live);

    expect(await live.readAsString(), 'migrated-contents');
    expect(temp.existsSync(), isFalse);
    expect(aside.existsSync(), isFalse);
  });

  test(
    'replaceSqlite recovers after move-in before retiring the old file',
    () async {
      final live = File('${tempDir.path}/kelivo.db')
        ..writeAsStringSync('migrated-contents');
      final aside = File('${live.path}.previous')
        ..writeAsStringSync('old-placeholder');
      final temp = File('${tempDir.path}/kelivo.db.migrating');
      expect(temp.existsSync(), isFalse);

      final service = HiveToSqliteMigrationService(
        HiveToSqliteMigrationDecision(
          needsMigration: true,
          appDataDir: tempDir,
          sqliteFile: live,
          hiveFiles: const <File>[],
        ),
      );
      addTearDown(service.dispose);

      await service.replaceSqliteForTest(temp, live);

      expect(await live.readAsString(), 'migrated-contents');
      expect(aside.existsSync(), isFalse);
    },
  );

  test(
    'decodes legacy attachment markers into image/file parts with stats',
    () async {
      final imagePath = '${tempDir.path}/images/prompt.png';
      final filePath = '${tempDir.path}/upload/spec.pdf';
      await Directory('${tempDir.path}/images').create(recursive: true);
      await Directory('${tempDir.path}/upload').create(recursive: true);
      await File(imagePath).writeAsBytes(const <int>[
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
      await File(filePath).writeAsBytes(const <int>[0x25, 0x50, 0x44, 0x46]);
      final missingPath = '${tempDir.path}/images/missing.png';
      final content = [
        'please review',
        '[image:$imagePath]',
        '[file:$filePath|spec.pdf|application/pdf]',
        '[image:$missingPath]',
        '[file:/tmp/bad|na|me|application/pdf]',
        'thanks',
      ].join('\n');

      await _seedHiveChat(
        tempDir: tempDir,
        conversationId: 'conversation-attachments',
        messageId: 'message-attachments',
        content: content,
      );

      final service = HiveToSqliteMigrationService(
        await HiveToSqliteMigrationService.check(),
      );
      addTearDown(service.dispose);
      final statuses = <HiveToSqliteMigrationStatus>[];
      final sub = service.statusStream.listen(statuses.add);
      addTearDown(sub.cancel);

      await service.migrate();

      final complete = statuses.lastWhere(
        (status) => status.stage == HiveToSqliteMigrationStage.complete,
      );
      expect(complete.converted, 3);
      expect(complete.malformed, 1);
      expect(complete.missingFiles, 1);
      expect(
        complete.log.any(
          (line) =>
              line.contains('legacy-content decode:') &&
              line.contains('converted=3') &&
              line.contains('malformed=1') &&
              line.contains('missingFiles=1'),
        ),
        isTrue,
      );

      // Hive retention (AC4).
      expect(File('${tempDir.path}/conversations.hive').existsSync(), isTrue);
      expect(File('${tempDir.path}/messages.hive').existsSync(), isTrue);

      final repo = ChatDatabaseRepository.open(
        file: File('${tempDir.path}/kelivo.db'),
      );
      addTearDown(repo.close);
      expect(await repo.getImagePartCount(), 2);
      expect(await repo.getFilePartCount(), 1);
      final message = await repo.getMessage('message-attachments');
      expect(message, isNotNull);
      expect(message!.parts.whereType<TextPart>().map((part) => part.text), [
        'please review',
        '\n[file:/tmp/bad|na|me|application/pdf]\nthanks',
      ]);
      expect(
        message.parts.whereType<TextPart>().map((part) => part.text).join(),
        'please review\n[file:/tmp/bad|na|me|application/pdf]\nthanks',
      );
      expect(message.parts.whereType<ImagePart>(), hasLength(2));
      expect(message.parts.whereType<FilePart>(), hasLength(1));
      final missingImage = message.parts.whereType<ImagePart>().singleWhere(
        (part) => part.uri == 'kelivo-file:///images/missing.png',
      );
      expect(missingImage.unavailable, isTrue);
      final presentImage = message.parts.whereType<ImagePart>().singleWhere(
        (part) => part.uri == 'kelivo-file:///images/prompt.png',
      );
      expect(presentImage.unavailable, isFalse);
      final presentFile = message.parts.whereType<FilePart>().single;
      expect(presentFile.uri, 'kelivo-file:///upload/spec.pdf');
      // Markers must not remain only inside TextPart after conversion.
      expect(
        message.parts.whereType<TextPart>().any(
          (part) => part.text.contains('[image:'),
        ),
        isFalse,
      );
      expect(
        message.parts.whereType<TextPart>().any(
          (part) => part.text.contains('[file:$filePath|'),
        ),
        isFalse,
      );
    },
  );

  test(
    'validation fails when an attachment part is missing before validate',
    () async {
      final imagePath = '${tempDir.path}/images/keep.png';
      await Directory('${tempDir.path}/images').create(recursive: true);
      await File(imagePath).writeAsBytes(const <int>[1, 2, 3, 4]);
      await _seedHiveChat(
        tempDir: tempDir,
        conversationId: 'conversation-missing-image',
        messageId: 'message-missing-image',
        content: 'caption\n[image:$imagePath]',
      );
      final backupRoot = Directory('${tempDir.path}/backup-target')
        ..createSync();
      final decision = await HiveToSqliteMigrationService.check();
      final service = HiveToSqliteMigrationService(decision);
      addTearDown(service.dispose);
      final backupFile = await service.backupTo(backupRoot);
      service.debugBeforeValidateForTest = (repo) async {
        await repo.deletePartsByKindForTest('message-missing-image', 'image');
      };

      await expectLater(
        service.migrate(backupPath: backupFile.path),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('image part count'),
          ),
        ),
      );

      expect(File('${tempDir.path}/messages.hive').existsSync(), isTrue);
      expect(
        HiveMigrationMarker.isMigrationComplete(
          File('${tempDir.path}/kelivo.db'),
        ),
        isFalse,
      );
    },
  );

  test(
    'validation rejects an image part with invalid JSON before publication',
    () async {
      final imagePath = '${tempDir.path}/images/corrupt.png';
      await Directory('${tempDir.path}/images').create(recursive: true);
      await File(imagePath).writeAsBytes(const <int>[1, 2, 3]);
      await _seedHiveChat(
        tempDir: tempDir,
        conversationId: 'conversation-invalid-image',
        messageId: 'message-invalid-image',
        content: 'caption\n[image:$imagePath]',
      );
      final backupRoot = Directory('${tempDir.path}/backup-target')
        ..createSync();
      final service = HiveToSqliteMigrationService(
        await HiveToSqliteMigrationService.check(),
      );
      addTearDown(service.dispose);
      final backupFile = await service.backupTo(backupRoot);
      service.debugBeforeValidateForTest = (repo) async {
        await repo.corruptPartPayloadForTest(
          'message-invalid-image',
          'image',
          'not-json',
        );
      };

      await expectLater(
        service.migrate(backupPath: backupFile.path),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'context without payload',
            allOf(
              contains('revisionId=message-invalid-image'),
              contains('ordinal=1'),
              contains('kind=image'),
              isNot(contains('not-json')),
            ),
          ),
        ),
      );

      expect(backupFile.existsSync(), isTrue);
      expect(File('${tempDir.path}/messages.hive').existsSync(), isTrue);
      expect(File('${tempDir.path}/kelivo.db').existsSync(), isFalse);
      expect(File('${tempDir.path}/kelivo.db.migrating').existsSync(), isFalse);
      expect(
        HiveMigrationMarker.isMigrationComplete(
          File('${tempDir.path}/kelivo.db'),
        ),
        isFalse,
      );
    },
  );

  test(
    'validation rejects a file part missing name before publication',
    () async {
      final filePath = '${tempDir.path}/upload/corrupt.pdf';
      await Directory('${tempDir.path}/upload').create(recursive: true);
      await File(filePath).writeAsBytes(const <int>[4, 5, 6]);
      await _seedHiveChat(
        tempDir: tempDir,
        conversationId: 'conversation-invalid-file',
        messageId: 'message-invalid-file',
        content: 'document\n[file:$filePath|corrupt.pdf|application/pdf]',
      );
      final service = HiveToSqliteMigrationService(
        await HiveToSqliteMigrationService.check(),
      );
      addTearDown(service.dispose);
      service.debugBeforeValidateForTest = (repo) async {
        await repo.corruptPartPayloadForTest(
          'message-invalid-file',
          'file',
          jsonEncode({'uri': filePath}),
        );
      };

      await expectLater(
        service.migrate(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'context without payload',
            allOf(
              contains('revisionId=message-invalid-file'),
              contains('ordinal=1'),
              contains('kind=file'),
              isNot(contains(filePath)),
            ),
          ),
        ),
      );

      expect(File('${tempDir.path}/messages.hive').existsSync(), isTrue);
      expect(File('${tempDir.path}/kelivo.db').existsSync(), isFalse);
      expect(File('${tempDir.path}/kelivo.db.migrating').existsSync(), isFalse);
      expect(
        HiveMigrationMarker.isMigrationComplete(
          File('${tempDir.path}/kelivo.db'),
        ),
        isFalse,
      );
    },
  );

  test(
    'failed validation can be retried idempotently with Hive retained',
    () async {
      await _seedHiveChat(
        tempDir: tempDir,
        conversationId: 'conversation-retry',
        messageId: 'message-retry',
        content: 'retry me',
      );
      final decision = await HiveToSqliteMigrationService.check();
      final failing = HiveToSqliteMigrationService(decision);
      addTearDown(failing.dispose);
      failing.debugBeforeValidateForTest = (repo) async {
        await repo.corruptTextPartPayloadForTest('message-retry', 'tampered');
      };

      await expectLater(failing.migrate(), throwsA(isA<StateError>()));
      expect(File('${tempDir.path}/messages.hive').existsSync(), isTrue);
      expect(
        (await HiveToSqliteMigrationService.check()).needsMigration,
        isTrue,
      );

      final retry = HiveToSqliteMigrationService(
        await HiveToSqliteMigrationService.check(),
      );
      addTearDown(retry.dispose);
      await retry.migrate();

      expect(
        HiveMigrationMarker.isMigrationComplete(
          File('${tempDir.path}/kelivo.db'),
        ),
        isTrue,
      );
      expect(File('${tempDir.path}/conversations.hive').existsSync(), isTrue);
      expect(File('${tempDir.path}/messages.hive').existsSync(), isTrue);

      final repo = ChatDatabaseRepository.open(
        file: File('${tempDir.path}/kelivo.db'),
      );
      addTearDown(repo.close);
      final message = await repo.getMessage('message-retry');
      expect(message?.content, 'retry me');
    },
  );
}

void _registerHiveAdapters() {
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ChatMessageAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(ConversationAdapter());
  }
}

Future<void> _seedHiveChat({
  required Directory tempDir,
  required String conversationId,
  required String messageId,
  required String content,
}) async {
  final conversation = Conversation(
    id: conversationId,
    title: 'Seed $conversationId',
    createdAt: DateTime(2024, 6, 1),
    updatedAt: DateTime(2024, 6, 2),
  );
  final message = ChatMessage(
    id: messageId,
    role: 'user',
    content: content,
    conversationId: conversationId,
    timestamp: DateTime(2024, 6, 1, 10),
  );
  conversation.messageIds.add(message.id);

  _registerHiveAdapters();
  Hive.init(tempDir.path);
  final conversations = await Hive.openBox<Conversation>('conversations');
  final messages = await Hive.openBox<ChatMessage>('messages');
  await conversations.put(conversation.id, conversation);
  await messages.put(message.id, message);
  await conversations.close();
  await messages.close();
  await Hive.close();
}
