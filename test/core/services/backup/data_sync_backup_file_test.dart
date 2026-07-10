import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/backup_provider.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => '$root/cache';

  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

class _FailingRestoreChatService extends ChatService {
  int replaceCalls = 0;

  @override
  Future<void> replaceAllDataFromBackup({
    required List<Conversation> conversations,
    required List<ChatMessage> messages,
    required Map<String, List<Map<String, dynamic>>> toolEventsByMessageId,
    required Map<String, String> geminiSignaturesByMessageId,
  }) async {
    replaceCalls++;
    throw StateError('chat replacement failed');
  }
}

class _FailingArtifactChatService extends ChatService {
  @override
  Future<void> replaceAllDataFromBackup({
    required List<Conversation> conversations,
    required List<ChatMessage> messages,
    required Map<String, List<Map<String, dynamic>>> toolEventsByMessageId,
    required Map<String, String> geminiSignaturesByMessageId,
  }) async {
    throw StateError('tool events restore failed');
  }
}

class _RecordingClearChatService extends ChatService {
  bool cleared = false;
  bool replaced = false;

  @override
  Future<void> clearAllData({bool deleteUploads = true}) async {
    cleared = true;
  }

  @override
  Future<void> restoreConversation(
    Conversation conversation,
    List<ChatMessage> messages,
  ) async {}

  @override
  Future<void> replaceAllDataFromBackup({
    required List<Conversation> conversations,
    required List<ChatMessage> messages,
    required Map<String, List<Map<String, dynamic>>> toolEventsByMessageId,
    required Map<String, String> geminiSignaturesByMessageId,
  }) async {
    replaced = true;
  }

  @override
  Future<void> setGeminiThoughtSignature(
    String assistantMessageId,
    String signature,
  ) async {}
}

class _CandidateCleanupChatService extends ChatService {
  _CandidateCleanupChatService(this.temporaryRoot);

  final Directory temporaryRoot;
  bool replaced = false;

  @override
  Future<void> replaceAllDataFromBackup({
    required List<Conversation> conversations,
    required List<ChatMessage> messages,
    required Map<String, List<Map<String, dynamic>>> toolEventsByMessageId,
    required Map<String, String> geminiSignaturesByMessageId,
  }) async {
    final candidateFiles = await temporaryRoot
        .list(recursive: true, followLinks: false)
        .where(
          (entity) =>
              entity is File && entity.path.contains('candidate.sqlite'),
        )
        .toList();
    expect(candidateFiles, isEmpty);
    replaced = true;
  }
}

void main() {
  group('DataSync backup file', () {
    late Directory root;
    late File validSettingsFile;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_data_sync_test_');
      PathProviderPlatform.instance = _FakePathProviderPlatform(root.path);
      SharedPreferences.setMockInitialValues({'backup_test_key': 'value'});
      validSettingsFile = File('${root.path}/valid_settings.json');
      await validSettingsFile.writeAsString('{}');
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    test(
      'packs files as deflated zip entries and removes staging files',
      () async {
        final uploadDir = Directory('${root.path}/upload');
        await uploadDir.create(recursive: true);
        final uploadFile = File('${uploadDir.path}/large.bin');
        await uploadFile.writeAsBytes(List<int>.filled(1024 * 1024, 7));
        final fontsDir = Directory('${root.path}/fonts');
        await fontsDir.create(recursive: true);
        final fontFile = File('${fontsDir.path}/custom.ttf');
        await fontFile.writeAsBytes(List<int>.filled(256, 9));

        final tmpDir = Directory('${root.path}/tmp');
        final staleWorkDir = Directory('${tmpDir.path}/kelivo_backup_stale');
        await staleWorkDir.create(recursive: true);
        await File('${staleWorkDir.path}/orphan.zip').writeAsString('old');
        await File('${tmpDir.path}/kelivo_backup_old.zip').writeAsString('old');
        await File('${tmpDir.path}/_bk_chats.json').writeAsString('{}');

        final sync = DataSync(chatService: ChatService());
        final backupFile = await sync.prepareBackupFile(
          const WebDavConfig(includeChats: false, includeFiles: true),
        );

        expect(await staleWorkDir.exists(), isFalse);
        expect(
          await File('${tmpDir.path}/kelivo_backup_old.zip').exists(),
          isFalse,
        );
        expect(await File('${tmpDir.path}/_bk_chats.json').exists(), isFalse);

        final input = InputFileStream(backupFile.path);
        Archive? archive;
        try {
          archive = ZipDecoder().decodeStream(input);
          final settingsEntry = archive.findFile('settings.json');
          final uploadEntry = archive.findFile('upload/large.bin');
          final fontEntry = archive.findFile('fonts/custom.ttf');

          expect(settingsEntry, isNotNull);
          expect(uploadEntry, isNotNull);
          expect(fontEntry, isNotNull);
          expect(settingsEntry!.compression, CompressionType.deflate);
          expect(uploadEntry!.compression, CompressionType.deflate);
          expect(fontEntry!.compression, CompressionType.deflate);
          expect(uploadEntry.readBytes(), List<int>.filled(1024 * 1024, 7));
          expect(fontEntry.readBytes(), List<int>.filled(256, 9));
        } finally {
          archive?.clearSync();
          input.closeSync();
        }

        expect(
          await File('${backupFile.parent.path}/_bk_settings.json').exists(),
          isFalse,
        );

        await DataSync.cleanupTemporaryBackupFile(backupFile);

        expect(await backupFile.exists(), isFalse);
        expect(await backupFile.parent.exists(), isFalse);
      },
    );

    test('restores managed font files in overwrite and merge modes', () async {
      final sourceDir = Directory('${root.path}/source_fonts');
      await sourceDir.create(recursive: true);
      final sourceFile = File('${sourceDir.path}/custom.ttf');
      await sourceFile.writeAsBytes(List<int>.filled(128, 5));

      final zipFile = File('${root.path}/fonts_backup.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(validSettingsFile, 'settings.json');
      encoder.addFileSync(sourceFile, 'fonts/custom.ttf');
      encoder.closeSync();

      final fontsDir = Directory('${root.path}/fonts');
      await fontsDir.create(recursive: true);
      final existingFile = File('${fontsDir.path}/existing.ttf');
      await existingFile.writeAsBytes(List<int>.filled(64, 3));

      final sync = DataSync(chatService: ChatService());
      await sync.restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: false, includeFiles: true),
        mode: RestoreMode.merge,
      );

      expect(await existingFile.exists(), isTrue);
      expect(
        await File('${fontsDir.path}/custom.ttf').readAsBytes(),
        List<int>.filled(128, 5),
      );

      await sync.restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: false, includeFiles: true),
        mode: RestoreMode.overwrite,
      );

      expect(await existingFile.exists(), isFalse);
      expect(
        await File('${fontsDir.path}/custom.ttf').readAsBytes(),
        List<int>.filled(128, 5),
      );
    });

    test(
      'merge restore imports assistant memories and mcp servers without clobbering local entries',
      () async {
        SharedPreferences.setMockInitialValues({
          'assistant_memories_v1': jsonEncode([
            {'id': 1, 'assistantId': 'local', 'content': 'keep local'},
            {'id': 2, 'assistantId': 'dup', 'content': 'same memory'},
          ]),
          'mcp_servers_v1': jsonEncode([
            {
              'id': 'local-server',
              'enabled': true,
              'name': 'Local Server',
              'transport': 'sse',
              'url': 'http://local.example/sse',
              'tools': [],
            },
            {
              'id': 'shared-server',
              'enabled': true,
              'name': 'Local Shared Server',
              'transport': 'sse',
              'url': 'http://local-shared.example/sse',
              'tools': [],
            },
          ]),
        });

        final settingsFile = File('${root.path}/settings.json');
        await settingsFile.writeAsString(
          jsonEncode({
            'assistant_memories_v1': jsonEncode([
              {'id': 1, 'assistantId': 'remote', 'content': 'remote memory'},
              {'id': 2, 'assistantId': 'dup', 'content': 'same memory'},
              {'id': 4, 'assistantId': 'new', 'content': 'new memory'},
            ]),
            'mcp_servers_v1': jsonEncode([
              {
                'id': 'shared-server',
                'enabled': false,
                'name': 'Imported Shared Server',
                'transport': 'sse',
                'url': 'http://imported-shared.example/sse',
                'tools': [],
              },
              {
                'id': 'remote-server',
                'enabled': true,
                'name': 'Remote Server',
                'transport': 'http',
                'url': 'http://remote.example/mcp',
                'tools': [],
              },
            ]),
          }),
        );

        final zipFile = File('${root.path}/settings_merge_backup.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(settingsFile, 'settings.json');
        encoder.closeSync();

        final sync = DataSync(chatService: ChatService());
        await sync.restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
          mode: RestoreMode.merge,
        );

        final prefs = await SharedPreferences.getInstance();
        final memories =
            jsonDecode(prefs.getString('assistant_memories_v1')!) as List;
        expect(memories, hasLength(4));
        expect(
          memories.where(
            (e) =>
                (e as Map)['assistantId'] == 'dup' &&
                e['content'] == 'same memory',
          ),
          hasLength(1),
        );
        expect(
          memories.any(
            (e) =>
                (e as Map)['assistantId'] == 'remote' &&
                e['content'] == 'remote memory' &&
                e['id'] != 1,
          ),
          isTrue,
        );
        expect(
          memories.any(
            (e) =>
                (e as Map)['assistantId'] == 'new' &&
                e['content'] == 'new memory' &&
                e['id'] == 4,
          ),
          isTrue,
        );

        final servers = jsonDecode(prefs.getString('mcp_servers_v1')!) as List;
        expect(servers, hasLength(3));
        expect(
          servers
              .where((e) => (e as Map)['id'] == 'shared-server')
              .single['name'],
          'Local Shared Server',
        );
        expect(
          servers.any(
            (e) =>
                (e as Map)['id'] == 'remote-server' &&
                e['name'] == 'Remote Server',
          ),
          isTrue,
        );
      },
    );

    test(
      'normalizes legacy JSON string lists before merging settings',
      () async {
        SharedPreferences.setMockInitialValues({
          'pinned_models_v1': <String>['local-model'],
        });
        final settingsFile = File('${root.path}/legacy_list_settings.json');
        await settingsFile.writeAsString(
          jsonEncode({
            'pinned_models_v1': jsonEncode(['remote-model']),
          }),
        );
        final zipFile = File('${root.path}/legacy_list_settings.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(settingsFile, 'settings.json');
        encoder.closeSync();

        await DataSync(chatService: ChatService()).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
          mode: RestoreMode.merge,
        );

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('pinned_models_v1'),
          containsAllInOrder(const ['local-model', 'remote-model']),
        );
      },
    );

    test('validates all merged settings before writing any live key', () async {
      final existingAssistants = jsonEncode([
        {'id': 'local', 'name': 'Local'},
      ]);
      SharedPreferences.setMockInitialValues({
        'assistants_v1': existingAssistants,
      });

      final settingsFile = File('${root.path}/invalid_merged_settings.json');
      await settingsFile.writeAsString(
        jsonEncode({
          'new_setting_before_failure': 'must-not-be-written',
          'assistants_v1': '{invalid nested json',
        }),
      );
      final zipFile = File('${root.path}/invalid_merged_settings.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(settingsFile, 'settings.json');
      encoder.closeSync();

      final sync = DataSync(chatService: ChatService());

      await expectLater(
        sync.restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
          mode: RestoreMode.merge,
        ),
        throwsA(isA<FormatException>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('new_setting_before_failure'), isNull);
      expect(prefs.getString('assistants_v1'), existingAssistants);
    });

    test(
      'rejects malformed structured settings before overwrite writes',
      () async {
        SharedPreferences.setMockInitialValues({'preserved_setting': 'old'});
        final settingsFile = File(
          '${root.path}/invalid_overwrite_settings.json',
        );
        await settingsFile.writeAsString(
          jsonEncode({
            'preserved_setting': 'new',
            'assistants_v1': '{invalid nested json',
          }),
        );
        final zipFile = File('${root.path}/invalid_overwrite_settings.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(settingsFile, 'settings.json');
        encoder.closeSync();

        final sync = DataSync(chatService: ChatService());

        await expectLater(
          sync.restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: false, includeFiles: false),
          ),
          throwsA(isA<FormatException>()),
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('preserved_setting'), 'old');
        expect(prefs.getString('assistants_v1'), isNull);
      },
    );

    test('rejects malformed first-time merged structured settings', () async {
      SharedPreferences.setMockInitialValues({});
      final settingsFile = File(
        '${root.path}/invalid_new_merged_settings.json',
      );
      await settingsFile.writeAsString(
        jsonEncode({
          'new_setting_before_failure': 'must-not-be-written',
          'assistants_v1': '{invalid nested json',
        }),
      );
      final zipFile = File('${root.path}/invalid_new_merged_settings.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(settingsFile, 'settings.json');
      encoder.closeSync();

      final sync = DataSync(chatService: ChatService());

      await expectLater(
        sync.restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
          mode: RestoreMode.merge,
        ),
        throwsA(isA<FormatException>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('new_setting_before_failure'), isNull);
      expect(prefs.getString('assistants_v1'), isNull);
    });

    test('rejects non-object entries in structured setting lists', () async {
      SharedPreferences.setMockInitialValues({'preserved_setting': 'old'});
      final settingsFile = File('${root.path}/invalid_assistant_entries.json');
      await settingsFile.writeAsString(
        jsonEncode({
          'preserved_setting': 'new',
          'assistants_v1': jsonEncode([42]),
        }),
      );
      final zipFile = File('${root.path}/invalid_assistant_entries.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(settingsFile, 'settings.json');
      encoder.closeSync();

      await expectLater(
        DataSync(chatService: ChatService()).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
        ),
        throwsA(isA<FormatException>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('preserved_setting'), 'old');
    });

    test('rejects non-object provider configuration values', () async {
      SharedPreferences.setMockInitialValues({});
      final settingsFile = File('${root.path}/invalid_provider_configs.json');
      await settingsFile.writeAsString(
        jsonEncode({
          'provider_configs_v1': jsonEncode({'provider': 42}),
        }),
      );
      final zipFile = File('${root.path}/invalid_provider_configs.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(settingsFile, 'settings.json');
      encoder.closeSync();

      await expectLater(
        DataSync(chatService: ChatService()).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
        ),
        throwsA(isA<FormatException>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('provider_configs_v1'), isNull);
    });

    test(
      'reports an atomic chat replacement failure instead of returning success',
      () async {
        final chatsFile = File('${root.path}/chats.json');
        await chatsFile.writeAsString(
          jsonEncode({
            'conversations': [
              Conversation(id: 'first', title: 'First').toJson(),
              Conversation(id: 'second', title: 'Second').toJson(),
            ],
            'messages': <Map<String, dynamic>>[],
          }),
        );

        final zipFile = File('${root.path}/failing_chat_restore.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(validSettingsFile, 'settings.json');
        encoder.addFileSync(chatsFile, 'chats.json');
        encoder.closeSync();

        final chatService = _FailingRestoreChatService();
        final sync = DataSync(chatService: chatService);

        await expectLater(
          sync.restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: true, includeFiles: false),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'chat replacement failed',
            ),
          ),
        );
        expect(chatService.replaceCalls, 1);
      },
    );

    test(
      'reports an invalid settings backup instead of returning success',
      () async {
        final settingsFile = File('${root.path}/invalid_settings.json');
        await settingsFile.writeAsString('{not valid json');

        final zipFile = File('${root.path}/invalid_settings_restore.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(settingsFile, 'settings.json');
        encoder.closeSync();

        final sync = DataSync(chatService: ChatService());

        await expectLater(
          sync.restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: false, includeFiles: false),
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'reports a tool event restore failure instead of returning success',
      () async {
        final chatsFile = File('${root.path}/artifact_chats.json');
        await chatsFile.writeAsString(
          jsonEncode({
            'conversations': [
              Conversation(
                id: 'artifact-conversation',
                title: 'Artifacts',
                messageIds: const ['assistant-message'],
              ).toJson(),
            ],
            'messages': [
              ChatMessage(
                id: 'assistant-message',
                role: 'assistant',
                content: 'answer',
                conversationId: 'artifact-conversation',
              ).toJson(),
            ],
            'toolEvents': {
              'assistant-message': [
                {'id': 'tool-call'},
              ],
            },
          }),
        );

        final zipFile = File('${root.path}/failing_artifact_restore.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(validSettingsFile, 'settings.json');
        encoder.addFileSync(chatsFile, 'chats.json');
        encoder.closeSync();

        final sync = DataSync(chatService: _FailingArtifactChatService());

        await expectLater(
          sync.restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: true, includeFiles: false),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'tool events restore failed',
            ),
          ),
        );
      },
    );

    test(
      'WebDAV provider completes with an error when restore fails',
      () async {
        final chatsFile = File('${root.path}/provider_chats.json');
        await chatsFile.writeAsString(
          jsonEncode({
            'conversations': [
              Conversation(id: 'first', title: 'First').toJson(),
              Conversation(id: 'second', title: 'Second').toJson(),
            ],
            'messages': <Map<String, dynamic>>[],
          }),
        );

        final zipFile = File('${root.path}/provider_restore.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(validSettingsFile, 'settings.json');
        encoder.addFileSync(chatsFile, 'chats.json');
        encoder.closeSync();

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });
        server.listen((request) async {
          request.response.statusCode = HttpStatus.ok;
          await request.response.addStream(zipFile.openRead());
          await request.response.close();
        });

        final provider = BackupProvider(
          chatService: _FailingRestoreChatService(),
          initialConfig: const WebDavConfig(
            includeChats: true,
            includeFiles: false,
          ),
        );
        final item = BackupFileItem(
          href: Uri.parse(
            'http://127.0.0.1:${server.port}/provider_restore.zip',
          ),
          displayName: 'provider_restore.zip',
          size: await zipFile.length(),
          lastModified: null,
        );

        await expectLater(
          provider.restoreFromItem(item),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'chat replacement failed',
            ),
          ),
        );
        expect(provider.busy, isFalse);
        expect(provider.message, contains('chat replacement failed'));
      },
    );

    test('rejects malformed chat payload before clearing live chats', () async {
      SharedPreferences.setMockInitialValues({'preserved_setting': 'old'});
      final settingsFile = File('${root.path}/malformed_chat_settings.json');
      await settingsFile.writeAsString(
        jsonEncode({'preserved_setting': 'new'}),
      );
      final chatsFile = File('${root.path}/malformed_chats.json');
      await chatsFile.writeAsString('{}');

      final zipFile = File('${root.path}/malformed_chats_restore.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(settingsFile, 'settings.json');
      encoder.addFileSync(chatsFile, 'chats.json');
      encoder.closeSync();

      final chatService = _RecordingClearChatService();
      final sync = DataSync(chatService: chatService);

      await expectLater(
        sync.restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(chatService.cleared, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('preserved_setting'), 'old');
    });

    test('rejects an unsupported future chat backup version', () async {
      final chatsFile = File('${root.path}/future_chats.json');
      await chatsFile.writeAsString(
        jsonEncode({
          'version': 2,
          'conversations': <Map<String, dynamic>>[],
          'messages': <Map<String, dynamic>>[],
        }),
      );
      final zipFile = File('${root.path}/future_chats.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(validSettingsFile, 'settings.json');
      encoder.addFileSync(chatsFile, 'chats.json');
      encoder.closeSync();
      final chatService = _RecordingClearChatService();

      await expectLater(
        DataSync(chatService: chatService).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(chatService.cleared, isFalse);
    });

    test('rejects a non-string Gemini thought signature', () async {
      final chatsFile = File('${root.path}/invalid_signature_chats.json');
      await chatsFile.writeAsString(
        jsonEncode({
          'version': 1,
          'conversations': [
            Conversation(
              id: 'conversation',
              title: 'Conversation',
              messageIds: const ['assistant-message'],
            ).toJson(),
          ],
          'messages': [
            ChatMessage(
              id: 'assistant-message',
              role: 'assistant',
              content: 'answer',
              conversationId: 'conversation',
            ).toJson(),
          ],
          'geminiThoughtSigs': {
            'assistant-message': {'bad': true},
          },
        }),
      );
      final zipFile = File('${root.path}/invalid_signature_chats.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(validSettingsFile, 'settings.json');
      encoder.addFileSync(chatsFile, 'chats.json');
      encoder.closeSync();
      final chatService = _RecordingClearChatService();

      await expectLater(
        DataSync(chatService: chatService).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(chatService.cleared, isFalse);
    });

    test(
      'rejects a missing settings payload before changing live data',
      () async {
        SharedPreferences.setMockInitialValues({'preserved_setting': 'old'});
        final chatsFile = File('${root.path}/preflight_chats.json');
        await chatsFile.writeAsString(
          jsonEncode({
            'conversations': <Map<String, dynamic>>[],
            'messages': <Map<String, dynamic>>[],
          }),
        );

        final zipFile = File('${root.path}/missing_settings_restore.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(chatsFile, 'chats.json');
        encoder.closeSync();

        final sync = DataSync(chatService: ChatService());

        await expectLater(
          sync.restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: true, includeFiles: false),
          ),
          throwsA(isA<FormatException>()),
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('preserved_setting'), 'old');
      },
    );

    test(
      'restores a legacy settings-only backup without clearing chats',
      () async {
        SharedPreferences.setMockInitialValues({'restored_setting': 'old'});
        final settingsFile = File('${root.path}/settings_only.json');
        await settingsFile.writeAsString(
          jsonEncode({'restored_setting': 'new'}),
        );

        final zipFile = File('${root.path}/settings_only_restore.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(settingsFile, 'settings.json');
        encoder.closeSync();

        final chatService = _RecordingClearChatService();
        final sync = DataSync(chatService: chatService);

        await sync.restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        );

        expect(chatService.cleared, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('restored_setting'), 'new');
      },
    );

    test('chat-only overwrite preserves live uploaded files', () async {
      final uploadDir = Directory('${root.path}/upload');
      await uploadDir.create(recursive: true);
      final uploadFile = File('${uploadDir.path}/preserved.txt');
      await uploadFile.writeAsString('keep');

      final chatsFile = File('${root.path}/empty_chats.json');
      await chatsFile.writeAsString(
        jsonEncode({
          'conversations': <Map<String, dynamic>>[],
          'messages': <Map<String, dynamic>>[],
        }),
      );
      final zipFile = File('${root.path}/chat_only_restore.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(validSettingsFile, 'settings.json');
      encoder.addFileSync(chatsFile, 'chats.json');
      encoder.closeSync();

      final chatService = ChatService();
      await chatService.init();
      addTearDown(chatService.close);
      final sync = DataSync(chatService: chatService);

      await sync.restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: true, includeFiles: false),
      );

      expect(await uploadFile.readAsString(), 'keep');
    });

    test('atomic overwrite invalidates loaded message caches', () async {
      final chatService = ChatService();
      await chatService.init();
      addTearDown(chatService.close);
      await chatService.restoreConversation(
        Conversation(
          id: 'cache-conversation',
          title: 'Old',
          messageIds: const ['cache-message'],
        ),
        [
          ChatMessage(
            id: 'cache-message',
            role: 'assistant',
            content: 'old content',
            conversationId: 'cache-conversation',
          ),
        ],
      );
      expect(
        chatService.getMessages('cache-conversation').single.content,
        'old content',
      );

      final chatsFile = File('${root.path}/cache_replacement_chats.json');
      await chatsFile.writeAsString(
        jsonEncode({
          'version': 1,
          'conversations': [
            Conversation(
              id: 'cache-conversation',
              title: 'New',
              messageIds: const ['cache-message'],
            ).toJson(),
          ],
          'messages': [
            ChatMessage(
              id: 'cache-message',
              role: 'assistant',
              content: 'new content',
              conversationId: 'cache-conversation',
              isStreaming: true,
            ).toJson(),
          ],
        }),
      );
      final zipFile = File('${root.path}/cache_replacement.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(validSettingsFile, 'settings.json');
      encoder.addFileSync(chatsFile, 'chats.json');
      encoder.closeSync();

      await DataSync(chatService: chatService).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: true, includeFiles: false),
      );

      expect(chatService.getConversation('cache-conversation')?.title, 'New');
      expect(
        chatService.getMessages('cache-conversation').single.content,
        'new content',
      );
      expect(
        chatService.getMessages('cache-conversation').single.isStreaming,
        isFalse,
      );
    });

    test(
      'removes the validated candidate before replacing live chats',
      () async {
        final chatsFile = File('${root.path}/candidate_cleanup_chats.json');
        await chatsFile.writeAsString(
          jsonEncode({
            'version': 1,
            'conversations': <Map<String, dynamic>>[],
            'messages': <Map<String, dynamic>>[],
          }),
        );
        final zipFile = File('${root.path}/candidate_cleanup.zip');
        final untrustedCandidate = File(
          '${root.path}/untrusted_candidate.sqlite',
        );
        await untrustedCandidate.writeAsString('not a sqlite database');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(validSettingsFile, 'settings.json');
        encoder.addFileSync(chatsFile, 'chats.json');
        encoder.addFileSync(untrustedCandidate, 'candidate.sqlite');
        encoder.closeSync();
        final chatService = _CandidateCleanupChatService(
          Directory('${root.path}/tmp'),
        );

        await DataSync(chatService: chatService).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        );

        expect(chatService.replaced, isTrue);
      },
    );

    test(
      'rejects an invalid chat candidate without changing live data',
      () async {
        SharedPreferences.setMockInitialValues({'preserved_setting': 'old'});
        final chatService = ChatService();
        await chatService.init();
        addTearDown(chatService.close);
        final existingConversation = await chatService.createConversation(
          title: 'Existing',
        );

        final settingsFile = File('${root.path}/candidate_settings.json');
        await settingsFile.writeAsString(
          jsonEncode({'preserved_setting': 'new'}),
        );
        final chatsFile = File('${root.path}/invalid_candidate_chats.json');
        await chatsFile.writeAsString(
          jsonEncode({
            'conversations': <Map<String, dynamic>>[],
            'messages': [
              ChatMessage(
                id: 'orphan-message',
                role: 'user',
                content: 'orphan',
                conversationId: 'missing-conversation',
              ).toJson(),
            ],
          }),
        );
        final zipFile = File('${root.path}/invalid_candidate_restore.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(settingsFile, 'settings.json');
        encoder.addFileSync(chatsFile, 'chats.json');
        encoder.closeSync();

        final sync = DataSync(chatService: chatService);

        await expectLater(
          sync.restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: true, includeFiles: false),
          ),
          throwsA(anything),
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('preserved_setting'), 'old');
        expect(chatService.getConversation(existingConversation.id), isNotNull);
      },
    );

    test('rejects a conversation that declares a missing message', () async {
      final chatsFile = File('${root.path}/missing_declared_message.json');
      await chatsFile.writeAsString(
        jsonEncode({
          'conversations': [
            Conversation(
              id: 'conversation',
              title: 'Conversation',
              messageIds: const ['missing-message'],
            ).toJson(),
          ],
          'messages': <Map<String, dynamic>>[],
        }),
      );
      final zipFile = File('${root.path}/missing_declared_message.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(validSettingsFile, 'settings.json');
      encoder.addFileSync(chatsFile, 'chats.json');
      encoder.closeSync();
      final chatService = _RecordingClearChatService();

      await expectLater(
        DataSync(chatService: chatService).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'conversation_message_ids',
          ),
        ),
      );
      expect(chatService.cleared, isFalse);
    });

    test(
      'rejects message order that disagrees with the conversation',
      () async {
        final chatsFile = File('${root.path}/mismatched_message_order.json');
        await chatsFile.writeAsString(
          jsonEncode({
            'conversations': [
              Conversation(
                id: 'conversation',
                title: 'Conversation',
                messageIds: const ['second-message', 'first-message'],
              ).toJson(),
            ],
            'messages': [
              ChatMessage(
                id: 'first-message',
                role: 'user',
                content: 'first',
                conversationId: 'conversation',
              ).toJson(),
              ChatMessage(
                id: 'second-message',
                role: 'assistant',
                content: 'second',
                conversationId: 'conversation',
              ).toJson(),
            ],
          }),
        );
        final zipFile = File('${root.path}/mismatched_message_order.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(validSettingsFile, 'settings.json');
        encoder.addFileSync(chatsFile, 'chats.json');
        encoder.closeSync();
        final chatService = _RecordingClearChatService();

        await expectLater(
          DataSync(chatService: chatService).restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: true, includeFiles: false),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'conversation_message_order',
            ),
          ),
        );
        expect(chatService.cleared, isFalse);
      },
    );

    test('rejects duplicate MCP server relations in a candidate', () async {
      final chatsFile = File('${root.path}/duplicate_mcp_relations.json');
      await chatsFile.writeAsString(
        jsonEncode({
          'version': 1,
          'conversations': [
            Conversation(
              id: 'conversation',
              title: 'Conversation',
              mcpServerIds: const ['server', 'server'],
            ).toJson(),
          ],
          'messages': <Map<String, dynamic>>[],
        }),
      );
      final zipFile = File('${root.path}/duplicate_mcp_relations.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(validSettingsFile, 'settings.json');
      encoder.addFileSync(chatsFile, 'chats.json');
      encoder.closeSync();
      final chatService = _RecordingClearChatService();

      await expectLater(
        DataSync(chatService: chatService).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'conversation_mcp_server_ids',
          ),
        ),
      );
      expect(chatService.replaced, isFalse);
    });

    test('cleans temporary restore files when WebDAV restore fails', () async {
      final sourceDir = Directory('${root.path}/source_upload');
      await sourceDir.create(recursive: true);
      final sourceFile = File('${sourceDir.path}/file.txt');
      await sourceFile.writeAsString('payload');

      final zipFile = File('${root.path}/restore_source.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(validSettingsFile, 'settings.json');
      encoder.addFileSync(sourceFile, 'upload/file.txt');
      encoder.closeSync();

      await File('${root.path}/upload').writeAsString('not a directory');

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        request.response.statusCode = HttpStatus.ok;
        await request.response.addStream(zipFile.openRead());
        await request.response.close();
      });

      final sync = DataSync(chatService: ChatService());
      final tmpDir = Directory('${root.path}/tmp');
      final item = BackupFileItem(
        href: Uri.parse('http://127.0.0.1:${server.port}/restore_source.zip'),
        displayName: 'restore_source.zip',
        size: await zipFile.length(),
        lastModified: null,
      );

      await expectLater(
        sync.restoreFromWebDav(
          const WebDavConfig(includeChats: false, includeFiles: true),
          item,
        ),
        throwsA(anything),
      );

      expect(await File('${tmpDir.path}/restore_source.zip').exists(), isFalse);
      expect(await tmpDir.list().toList(), isEmpty);
    });
  });
}
