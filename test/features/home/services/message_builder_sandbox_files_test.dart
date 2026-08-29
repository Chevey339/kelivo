import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';

import '../../../support/business_test_harness.dart';

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

class _FakeChatService extends ChatService {
  @override
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) =>
      const [];
}

void main() {
  late Directory tempDir;
  late File csv;
  late File notes;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kelivo_sandbox_files');
    csv = File('${tempDir.path}/sales.csv')
      ..writeAsStringSync('region,amount\nnorth,1\n');
    notes = File('${tempDir.path}/notes.txt')..writeAsStringSync('read me');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  ChatMessage userWithFiles() => ChatMessage(
    id: 'u1',
    role: 'user',
    conversationId: 'c1',
    parts: [
      const TextPart('analyse this'),
      FilePart(uri: csv.path, name: 'sales.csv', mime: 'text/csv'),
      FilePart(uri: notes.path, name: 'notes.txt', mime: 'text/plain'),
    ],
  );

  Future<
    ({MessageBuilderService service, SettingsProvider settings, ChatMessage m})
  >
  setUpService() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final service = MessageBuilderService(
      chatService: _FakeChatService(),
      contextProvider: _FakeBuildContext(),
    );
    return (service: service, settings: settings, m: userWithFiles());
  }

  test(
    'buildApiMessages lists documents under the document-paths key',
    () async {
      final s = await setUpService();
      final apiMessages = s.service.buildApiMessages(
        messages: [s.m],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );
      final refs = parseInternalDocumentRefs(
        apiMessages.single[multimodalInternalDocumentPathsKey],
      );
      expect(refs.map((r) => r.name), ['sales.csv', 'notes.txt']);
      expect(refs.first.uri, csv.path);
      expect(
        apiMessages.single.containsKey(multimodalInternalMediaPathsKey),
        isFalse,
      );
    },
  );

  test(
    'without a sandbox every document is extracted into the prompt',
    () async {
      final s = await setUpService();
      final apiMessages = s.service.buildApiMessages(
        messages: [s.m],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );
      expect(
        s.service.hasPendingAttachmentWork(
          apiMessages,
          s.settings,
          sourceMessages: [s.m],
        ),
        isTrue,
      );
      await s.service.processUserMessagesForApi(
        apiMessages,
        s.settings,
        const Assistant(id: 'a1', name: 'test'),
        sourceMessages: [s.m],
      );
      final content = apiMessages.single['content'] as String;
      expect(content, contains('region,amount'));
      expect(content, contains('read me'));
    },
  );

  test('with a sandbox the data file stays out of the prompt', () async {
    final s = await setUpService();
    final apiMessages = s.service.buildApiMessages(
      messages: [s.m],
      versionSelections: const {},
      currentConversation: Conversation(title: 'test'),
    );
    await s.service.processUserMessagesForApi(
      apiMessages,
      s.settings,
      const Assistant(id: 'a1', name: 'test'),
      sourceMessages: [s.m],
      sandboxDataFiles: true,
    );
    final content = apiMessages.single['content'] as String;
    expect(content, isNot(contains('region,amount')));
    expect(content, contains('read me'), reason: 'prose is still extracted');
    expect(content, contains('analyse this'));
    // The provider still finds the file to upload.
    final refs = parseInternalDocumentRefs(
      apiMessages.single[multimodalInternalDocumentPathsKey],
    );
    expect(refs.map((r) => r.name), contains('sales.csv'));
  });

  test('a lone data file is no pending extraction work', () async {
    final s = await setUpService();
    final onlyCsv = ChatMessage(
      id: 'u2',
      role: 'user',
      conversationId: 'c1',
      parts: [FilePart(uri: csv.path, name: 'sales.csv', mime: 'text/csv')],
    );
    final apiMessages = s.service.buildApiMessages(
      messages: [onlyCsv],
      versionSelections: const {},
      currentConversation: Conversation(title: 'test'),
    );
    expect(
      s.service.hasPendingAttachmentWork(
        apiMessages,
        s.settings,
        sourceMessages: [onlyCsv],
        sandboxDataFiles: true,
      ),
      isFalse,
    );
    expect(
      s.service.hasPendingAttachmentWork(
        apiMessages,
        s.settings,
        sourceMessages: [onlyCsv],
      ),
      isTrue,
    );
  });

  group('a conversation that changes provider', () {
    late AppDatabase database;
    late ChatDatabaseRepository repo;
    late ChatService chatService;
    late SettingsProvider settings;
    late MessageBuilderService service;
    late Conversation convo;
    late ChatMessage stored;
    late PathProviderPlatform previousPathProvider;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
      database = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
        ),
      );
      repo = ChatDatabaseRepository(database);
      await repo.ensureReady();
      chatService = ChatService(existingRepository: repo);
      await chatService.init();
      settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      service = MessageBuilderService(
        chatService: chatService,
        contextProvider: _FakeBuildContext(),
        chatRepository: repo,
      );
      convo = await chatService.createConversation(title: 't');
      stored = await chatService.addMessage(
        conversationId: convo.id,
        role: 'user',
        content: 'analyse this',
        parts: [
          const TextPart('analyse this'),
          FilePart(uri: csv.path, name: 'sales.csv', mime: 'text/csv'),
        ],
      );
    });

    tearDown(() async {
      PathProviderPlatform.instance = previousPathProvider;
      await chatService.close();
      await database.close();
    });

    Future<String> replay({required bool sandboxDataFiles}) async {
      final apiMessages = service.buildApiMessages(
        messages: [stored],
        versionSelections: const {},
        currentConversation: convo,
      );
      await service.processUserMessagesForApi(
        apiMessages,
        settings,
        const Assistant(id: 'a1', name: 'test'),
        conversation: convo,
        sourceMessages: [stored],
        sandboxDataFiles: sandboxDataFiles,
      );
      return apiMessages.single['content'] as String;
    }

    test('a message built for the sandbox gets its text back later', () async {
      // Sent to Claude with code execution on: the CSV goes to the container
      // and the prompt is not frozen, since it is not what every provider
      // would need.
      expect(
        await replay(sandboxDataFiles: true),
        isNot(contains('region,amount')),
      );
      expect(await repo.getMessagePrompt(stored.id), isNull);

      // Replayed to a provider without a sandbox, the same message is read
      // again and the CSV is in the prompt.
      expect(await replay(sandboxDataFiles: false), contains('region,amount'));
      expect(await repo.getMessagePrompt(stored.id), isNotNull);
    });

    test('a frozen prompt keeps its text when a sandbox comes later', () async {
      // Sent without a sandbox first: extracted and frozen. Turning code
      // execution on afterwards reuses the frozen prompt - the text stays,
      // and the provider uploads the file as well.
      expect(await replay(sandboxDataFiles: false), contains('region,amount'));
      expect(await replay(sandboxDataFiles: true), contains('region,amount'));
    });
  });
}
