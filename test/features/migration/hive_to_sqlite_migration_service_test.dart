import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/migration/hive_to_sqlite_migration_service.dart';

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
    });
  });

  tearDown(() async {
    await Hive.close();
    PathProviderPlatform.instance = previousPathProvider;
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
    expect(entryNames, isNot(contains('database/kelivo.sqlite')));
    expect(entryNames, contains('conversations.hive'));
    expect(entryNames, contains('messages.hive'));
    expect(entryNames, contains('tool_events_v1.hive'));
    expect(entryNames, contains('upload/source.pdf'));
    expect(entryNames, contains('images/prompt.png'));
    expect(entryNames, contains('avatars/user.png'));
    expect(entryNames, contains('fonts/custom.ttf'));
    final settingsEntry = archive.findFile('settings.json');
    expect(settingsEntry, isNotNull);
    final settingsJson = String.fromCharCodes(settingsEntry!.readBytes()!);
    expect(settingsJson, contains('provider_configs_v1'));
    expect(settingsJson, isNot(contains('display_chat_font_scale_v1')));
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

    await service.migrate(backupFile: backupFile);
    final firstMigrationStatus = statuses.firstWhere(
      (status) => status.stage == HiveToSqliteMigrationStage.migrating,
    );
    expect(firstMigrationStatus.detail, 'schema');
    expect(firstMigrationStatus.progress, 0);
    await service.dispose();

    final afterMigration = await HiveToSqliteMigrationService.check();
    expect(afterMigration.needsMigration, isFalse);

    final chatService = ChatService();
    await chatService.init();
    addTearDown(chatService.close);

    final migratedConversation = chatService.getConversation(conversation.id);
    expect(migratedConversation, isNotNull);
    expect(migratedConversation!.createdAt, conversation.createdAt);
    expect(migratedConversation.updatedAt, conversation.updatedAt);
    expect(chatService.getMessageCount(conversation.id), 2);
    final migratedMessages = chatService.getMessages(conversation.id);
    expect(migratedMessages.map((m) => m.content), [
      'hello from hive',
      'hello from sqlite',
    ]);
    expect(migratedMessages[0].timestamp, userMessage.timestamp);
    expect(migratedMessages[1].timestamp, assistantMessage.timestamp);
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
  });

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
      truncateIndex: 12,
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
          groupId: 'group-$i',
          version: i % 3,
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
    await service.migrate(backupFile: File('${tempDir.path}/backup.zip'));
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
    expect(migratedConversation.truncateIndex, 12);
    expect(migratedConversation.versionSelections, {'group-12': 1});
    expect(migratedConversation.summary, 'large summary');
    expect(migratedConversation.lastSummarizedMessageCount, 64);
    expect(migratedConversation.chatSuggestions, ['next']);

    final migratedMessages = chatService.getMessages(conversation.id);
    expect(migratedMessages, hasLength(messageCount));
    expect(migratedMessages.first.id, 'message-0');
    expect(migratedMessages[127].id, 'message-127');
    expect(migratedMessages.last.id, 'message-129');
    expect(migratedMessages.last.timestamp, messages.last.timestamp);
    expect(migratedMessages.last.modelId, messages.last.modelId);
    expect(migratedMessages.last.promptTokens, messages.last.promptTokens);
    expect(
      chatService.getToolEvents('message-129').single['name'],
      'batch-check',
    );
    expect(
      chatService.getGeminiThoughtSignature('message-129'),
      'last-batch-signature',
    );
  });

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
          sqliteFile: File('${tempDir.path}/kelivo.sqlite'),
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
}

void _registerHiveAdapters() {
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ChatMessageAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(ConversationAdapter());
  }
}
