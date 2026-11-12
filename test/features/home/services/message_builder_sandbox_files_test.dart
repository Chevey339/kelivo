import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_session_sync.dart';
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

  test(
    'native PDF keeps its workspace path and native document ref without extraction',
    () async {
      final s = await setUpService();
      final uri = '${tempDir.path}/report.pdf';
      final apiMessages = <Map<String, dynamic>>[
        {
          'role': 'user',
          'content': 'Read this PDF',
          MessageBuilderService.internalRevisionIdKey: 'pdf-user',
          multimodalInternalDocumentPathsKey: [
            encodeInternalDocumentRef((
              uri: uri,
              name: 'report.pdf',
              mime: 'application/pdf',
            )),
          ],
        },
      ];
      final workspace = {
        uri: AttachmentInfo(
          name: 'report.pdf',
          sourceUri: uri,
          size: 8,
          modelPath: '/chat/attachments/report (2).pdf',
        ),
      };
      expect(
        s.service.hasPendingAttachmentWork(apiMessages, s.settings),
        isTrue,
      );
      expect(
        s.service.hasPendingAttachmentWork(
          apiMessages,
          s.settings,
          nativePdfInput: true,
        ),
        isFalse,
      );
      await s.service.processUserMessagesForApi(
        apiMessages,
        s.settings,
        null,
        nativePdfInput: true,
        workspaceAttachments: workspace,
      );
      expect(apiMessages.single['content'], contains('Read this PDF'));
      expect(
        apiMessages.single['content'],
        contains('/chat/attachments/report (2).pdf'),
      );
      expect(apiMessages.single['content'], contains('8 bytes'));
      expect(
        parseInternalDocumentRefs(
          apiMessages.single[multimodalInternalDocumentPathsKey],
        ).single.uri,
        uri,
      );
    },
  );

  test(
    'local workspace sends paths instead of document contents or cloud uploads',
    () async {
      final s = await setUpService();
      final apiMessages = s.service.buildApiMessages(
        messages: [s.m],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );
      final attachments = {
        for (final file in [csv, notes])
          file.path: AttachmentInfo(
            sourceUri: file.path,
            name: file.uri.pathSegments.last,
            size: await file.length(),
            modelPath: '/chat/attachments/${file.uri.pathSegments.last}',
          ),
      };
      expect(
        s.service.hasPendingAttachmentWork(
          apiMessages,
          s.settings,
          sourceMessages: [s.m],
          workspaceAttachments: attachments,
        ),
        isFalse,
      );
      await s.service.processUserMessagesForApi(
        apiMessages,
        s.settings,
        const Assistant(id: 'a1', name: 'test'),
        sourceMessages: [s.m],
        sandboxDataFiles: true,
        workspaceAttachments: attachments,
      );
      final content = apiMessages.single['content'] as String;
      expect(content, contains('/chat/attachments/sales.csv'));
      expect(content, contains('/chat/attachments/notes.txt'));
      expect(content, isNot(contains('region,amount')));
      expect(content, isNot(contains('read me')));
      expect(content, contains('analyse this'));
      expect(
        apiMessages.single.containsKey(multimodalInternalDocumentPathsKey),
        isFalse,
      );
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

  for (final useSourceMessages in [false, true]) {
    test(
      'workspace paths follow only this message and deduplicate image/file refs '
      '(source messages: $useSourceMessages)',
      () async {
        final s = await setUpService();
        final imagePath = '${tempDir.path}/image.png';
        final missingPath = '${tempDir.path}/unavailable.png';
        final message = ChatMessage(
          id: 'mixed',
          role: 'user',
          conversationId: 'c1',
          parts: [
            const TextPart('Compare these'),
            ImagePart(uri: imagePath, mime: 'image/png'),
            FilePart(uri: imagePath, name: 'image.png', mime: 'image/png'),
            FilePart(uri: notes.path, name: 'notes.txt', mime: 'text/plain'),
            ImagePart(uri: missingPath, mime: 'image/png', unavailable: true),
          ],
        );
        final apiMessages = s.service.buildApiMessages(
          messages: [message],
          versionSelections: const {},
          currentConversation: Conversation(title: 'test'),
        );
        await s.service.processUserMessagesForApi(
          apiMessages,
          s.settings,
          const Assistant(id: 'a1', name: 'test'),
          sourceMessages: useSourceMessages ? [message] : null,
          workspaceAttachments: {
            for (final path in [imagePath, notes.path, missingPath, csv.path])
              path: AttachmentInfo(
                name: path.split('/').last,
                sourceUri: path,
                size: 3,
                modelPath: '/chat/attachments/${path.split('/').last}',
              ),
          },
        );
        final content = apiMessages.single['content'] as String;
        expect('/chat/attachments/image.png'.allMatches(content), hasLength(1));
        expect('/chat/attachments/notes.txt'.allMatches(content), hasLength(1));
        expect(content, isNot(contains('unavailable.png')));
        expect(content, isNot(contains('sales.csv')));
        expect(content, isNot(contains('read me')));
        expect(content, contains('Compare these'));
        expect(
          parseInternalMediaRefs(
            apiMessages.single[multimodalInternalMediaPathsKey],
          ).map((ref) => ref.uri),
          [imagePath],
        );
      },
    );
  }

  test(
    'OCR keeps the workspace image path without resending image bytes',
    () async {
      final s = await setUpService();
      await s.settings.setOcrModel('ocr-provider', 'ocr-model');
      await s.settings.setOcrEnabled(true);
      final imagePath = '${tempDir.path}/image.png';
      final service = MessageBuilderService(
        chatService: _FakeChatService(),
        contextProvider: _FakeBuildContext(),
        ocrHandler: (paths, {revisionId, session, requestId}) async {
          expect(paths, [imagePath]);
          return 'Recognized image text';
        },
      );
      final message = ChatMessage(
        id: 'ocr',
        role: 'user',
        conversationId: 'c1',
        parts: [ImagePart(uri: imagePath, mime: 'image/png')],
      );
      final apiMessages = service.buildApiMessages(
        messages: [message],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );
      await service.processUserMessagesForApi(
        apiMessages,
        s.settings,
        null,
        sourceMessages: [message],
        workspaceAttachments: {
          imagePath: AttachmentInfo(
            name: 'image.png',
            sourceUri: imagePath,
            size: 3,
            modelPath: '/chat/attachments/image.png',
          ),
        },
      );
      expect(apiMessages.single['content'], contains('Recognized image text'));
      expect(
        apiMessages.single['content'],
        contains('/chat/attachments/image.png'),
      );
      expect(
        apiMessages.single.containsKey(multimodalInternalMediaPathsKey),
        isFalse,
      );
    },
  );

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

    Future<String> replay({
      required bool sandboxDataFiles,
      bool nativePdfInput = false,
      Map<String, AttachmentInfo> workspaceAttachments = const {},
    }) async {
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
        nativePdfInput: nativePdfInput,
        workspaceAttachments: workspaceAttachments,
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

    for (final frozenBeforeBinding in [false, true]) {
      test('image paths survive replay without entering the frozen prompt '
          '(already frozen: $frozenBeforeBinding)', () async {
        final image = File('${tempDir.path}/image.png')
          ..writeAsBytesSync([1, 2, 3]);
        stored = await chatService.addMessage(
          conversationId: convo.id,
          role: 'user',
          content: '',
          parts: [ImagePart(uri: image.path, mime: 'image/png')],
        );
        final local = {
          image.path: AttachmentInfo(
            name: 'image.png',
            sourceUri: image.path,
            size: 3,
            modelPath: '/chat/attachments/image.png',
          ),
        };
        if (frozenBeforeBinding) {
          expect(await replay(sandboxDataFiles: false), isEmpty);
        }
        final first = await replay(
          sandboxDataFiles: false,
          workspaceAttachments: local,
        );
        expect(first, contains('/chat/attachments/image.png'));
        expect(first, contains('3 bytes'));
        expect((await repo.getMessagePrompt(stored.id))!.payload, isEmpty);

        // A new builder must reconstruct the same request from persisted
        // prompts, without relying on in-memory attachment state.
        service = MessageBuilderService(
          chatService: chatService,
          contextProvider: _FakeBuildContext(),
          chatRepository: repo,
        );
        expect(
          await replay(sandboxDataFiles: false, workspaceAttachments: local),
          first,
        );
        expect(await replay(sandboxDataFiles: false), isEmpty);
        final relocated = await replay(
          sandboxDataFiles: false,
          workspaceAttachments: {
            image.path: AttachmentInfo(
              name: 'image.png',
              sourceUri: image.path,
              size: 3,
              modelPath: '/new-session/attachments/image.png',
            ),
          },
        );
        expect(relocated, contains('/new-session/attachments/image.png'));
        expect(relocated, isNot(contains('/chat/attachments/image.png')));
        expect((await repo.getMessagePrompt(stored.id))!.payload, isEmpty);
      });
    }

    test(
      'PDF switches between native bytes and extraction without stale frozen text',
      () async {
        final document = PdfDocument();
        document.pages.add().graphics.drawString(
          'Original PDF text',
          PdfStandardFont(PdfFontFamily.helvetica, 12),
        );
        final pdf = File('${tempDir.path}/report.pdf');
        await pdf.writeAsBytes(await document.save());
        document.dispose();
        stored = await chatService.addMessage(
          conversationId: convo.id,
          role: 'user',
          content: 'analyse PDF',
          parts: [
            const TextPart('analyse PDF'),
            FilePart(
              uri: pdf.path,
              name: 'report.pdf',
              mime: 'application/pdf',
            ),
          ],
        );
        expect(
          await replay(sandboxDataFiles: false, nativePdfInput: true),
          'analyse PDF',
        );
        expect(await repo.getMessagePrompt(stored.id), isNull);
        final extracted = await replay(sandboxDataFiles: false);
        expect(extracted, contains('Original PDF text'));
        expect(
          await replay(sandboxDataFiles: false, nativePdfInput: true),
          'analyse PDF',
        );
        expect((await repo.getMessagePrompt(stored.id))!.payload, extracted);
        expect(await replay(sandboxDataFiles: false), extracted);
      },
    );

    test(
      'binding and unbinding workspace does not freeze local paths into ordinary chat',
      () async {
        final local = {
          csv.path: AttachmentInfo(
            name: 'sales.csv',
            sourceUri: csv.path,
            size: await csv.length(),
            modelPath: '/chat/attachments/sales.csv',
          ),
        };
        expect(
          await replay(sandboxDataFiles: false, workspaceAttachments: local),
          contains('/chat/attachments/sales.csv'),
        );
        expect(await repo.getMessagePrompt(stored.id), isNull);
        expect(
          await replay(sandboxDataFiles: false),
          contains('region,amount'),
        );
        final rebound = await replay(
          sandboxDataFiles: false,
          workspaceAttachments: local,
        );
        // Previously frozen ordinary prompts remain immutable; workspace
        // paths are appended to the owning message only for this request.
        expect(rebound, contains('region,amount'));
        expect(rebound, contains('/chat/attachments/sales.csv'));
        expect(
          (await repo.getMessagePrompt(stored.id))!.payload,
          isNot(contains('/chat/attachments/sales.csv')),
        );
        expect(
          await replay(sandboxDataFiles: false),
          contains('region,amount'),
        );
      },
    );
  });
}
