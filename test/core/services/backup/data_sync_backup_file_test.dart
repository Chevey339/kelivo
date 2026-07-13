import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/backup_provider.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';

import 'restore_cold_process_test_helper.dart';

bool _containsContiguousBytes(List<int> source, List<int> pattern) {
  for (var start = 0; start <= source.length - pattern.length; start++) {
    var matches = true;
    for (var index = 0; index < pattern.length; index++) {
      if (source[start + index] != pattern[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

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

class _FailingRemovePreferencesStore extends InMemorySharedPreferencesStore {
  _FailingRemovePreferencesStore(super.data) : super.withData();

  @override
  Future<bool> remove(String key) async => false;
}

class _FailingNthSetPreferencesStore extends InMemorySharedPreferencesStore {
  _FailingNthSetPreferencesStore(super.data, {required this.failOnCall})
    : super.withData();

  final int failOnCall;
  var _setCalls = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    _setCalls++;
    if (_setCalls == failOnCall) return false;
    return super.setValue(valueType, key, value);
  }
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

class _FailingSnapshotRestoreChatService extends ChatService {
  @override
  Future<void> restoreDatabaseSnapshot(File snapshotFile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('written_during_restore', 'keep-concurrent-write');
    throw StateError('snapshot restore failed');
  }
}

class _RecordingSnapshotPathChatService extends ChatService {
  String? snapshotPath;

  @override
  Future<void> restoreDatabaseSnapshot(File snapshotFile) async {
    snapshotPath = snapshotFile.path;
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

Future<String> _fileSha256(File file) async {
  return (await sha256.bind(file.openRead()).first).toString();
}

Future<Directory> _singleRestoreRunDirectory(Directory appDataDirectory) async {
  final workspace = Directory(
    '${appDataDirectory.path}${Platform.pathSeparator}.kelivo_restore',
  );
  final runs = await workspace
      .list(followLinks: false)
      .where((entity) {
        if (entity is! Directory) return false;
        final name = entity.uri.pathSegments
            .where((segment) => segment.isNotEmpty)
            .last;
        return RegExp(r'^run_[a-f0-9]{32}$').hasMatch(name);
      })
      .cast<Directory>()
      .toList();
  expect(runs, hasLength(1));
  return runs.single;
}

Future<void> _overwriteCentralDirectoryUncompressedSize(
  File zipFile,
  int size,
) async {
  final bytes = await zipFile.readAsBytes();
  const signature = [0x50, 0x4b, 0x01, 0x02];
  var headerOffset = -1;
  for (var i = bytes.length - signature.length; i >= 0; i--) {
    if (bytes[i] == signature[0] &&
        bytes[i + 1] == signature[1] &&
        bytes[i + 2] == signature[2] &&
        bytes[i + 3] == signature[3]) {
      headerOffset = i;
      break;
    }
  }
  if (headerOffset < 0) throw StateError('central_directory');
  for (var i = 0; i < 4; i++) {
    bytes[headerOffset + 24 + i] = (size >> (8 * i)) & 0xff;
  }
  await zipFile.writeAsBytes(bytes, flush: true);
}

Future<File> _createSqliteBackupFixture({
  required Directory root,
  required String prefix,
  required Map<String, dynamic> settings,
  String? databaseSha256,
  bool secretsIncluded = true,
  bool includeFiles = false,
  String? assetContent,
}) async {
  if (assetContent != null && !includeFiles) {
    throw ArgumentError.value(assetContent, 'assetContent');
  }
  final databasePath = '${root.path}/${prefix}_database.sqlite';
  final snapshotInfo = await Isolate.run(() async {
    final databaseFile = File(databasePath);
    final repository = ChatDatabaseRepository.open(file: databaseFile);
    try {
      await repository.ensureReady();
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'fixture-conversation',
            title: 'Fixture',
            messageIds: const ['fixture-message'],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: 'fixture-message',
              role: 'assistant',
              content: 'fixture content',
              conversationId: 'fixture-conversation',
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      await repository.checkpoint();
    } finally {
      await repository.close();
    }
    return ChatDatabaseRepository.prepareSnapshotForRestore(databaseFile);
  });
  final databaseFile = File(databasePath);
  final settingsFile = File('${root.path}/${prefix}_settings.json');
  await settingsFile.writeAsString(jsonEncode(settings));
  final assetFile = assetContent == null
      ? null
      : await File(
          '${root.path}/${prefix}_asset.txt',
        ).writeAsString(assetContent, flush: true);
  final entries = <String, Map<String, Object>>{
    'settings.json': {
      'bytes': await settingsFile.length(),
      'sha256': await _fileSha256(settingsFile),
    },
    'database/kelivo.db': {
      'bytes': await databaseFile.length(),
      'sha256': databaseSha256 ?? await _fileSha256(databaseFile),
    },
    if (assetFile != null)
      'upload/fixture.txt': {
        'bytes': await assetFile.length(),
        'sha256': await _fileSha256(assetFile),
      },
  };
  final manifestFile = File('${root.path}/${prefix}_manifest.json');
  await manifestFile.writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': 2,
      'payloadKind': 'sqlite',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': '1.0.0-test+1',
      'includeChats': true,
      'includeFiles': includeFiles,
      'secretsIncluded': secretsIncluded,
      'database': {
        'entry': 'database/kelivo.db',
        'schemaVersion': snapshotInfo.schemaVersion,
        'conversationCount': snapshotInfo.conversationCount,
        'messageCount': snapshotInfo.messageCount,
      },
      'entries': entries,
    }),
  );
  final zipFile = File('${root.path}/$prefix.zip');
  final encoder = ZipFileEncoder();
  encoder.create(zipFile.path);
  encoder.addFileSync(manifestFile, 'manifest.json');
  encoder.addFileSync(settingsFile, 'settings.json');
  encoder.addFileSync(databaseFile, 'database/kelivo.db');
  if (assetFile != null) {
    encoder.addFileSync(assetFile, 'upload/fixture.txt');
  }
  encoder.closeSync();
  return zipFile;
}

Future<RestoreReceipt?> _recoverAcrossColdRestart({
  required Directory appDataDirectory,
  SharedPreferences? preferences,
}) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      return await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: appDataDirectory,
        preferences: preferences,
      );
    } on RestoreColdRestartRequired {
      await simulateRestoreColdProcessBoundary(appDataDirectory);
    }
  }
  throw StateError('restore_test_cold_restart_limit');
}

void main() {
  group('DataSync backup file', () {
    late Directory root;
    late File validSettingsFile;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_data_sync_test_');
      PathProviderPlatform.instance = _FakePathProviderPlatform(root.path);
      PackageInfo.setMockInitialValues(
        appName: 'Kelivo',
        packageName: 'Kelivo',
        version: '1.0.0-test',
        buildNumber: '1',
        buildSignature: 'test',
      );
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
          final manifestEntry = archive.findFile('manifest.json');
          final uploadEntry = archive.findFile('upload/large.bin');
          final fontEntry = archive.findFile('fonts/custom.ttf');

          expect(settingsEntry, isNotNull);
          expect(manifestEntry, isNotNull);
          expect(uploadEntry, isNotNull);
          expect(fontEntry, isNotNull);
          expect(settingsEntry!.compression, CompressionType.deflate);
          expect(uploadEntry!.compression, CompressionType.deflate);
          expect(fontEntry!.compression, CompressionType.deflate);
          expect(uploadEntry.readBytes(), List<int>.filled(1024 * 1024, 7));
          expect(fontEntry.readBytes(), List<int>.filled(256, 9));
          final manifest =
              jsonDecode(utf8.decode(manifestEntry!.readBytes()!))
                  as Map<String, dynamic>;
          final manifestEntries = manifest['entries'] as Map;
          expect(
            (manifestEntries['upload/large.bin'] as Map)['sha256'],
            await _fileSha256(uploadFile),
          );
          expect(
            (manifestEntries['fonts/custom.ttf'] as Map)['sha256'],
            await _fileSha256(fontFile),
          );
        } finally {
          archive?.clearSync();
          input.closeSync();
        }
        expect(
          _containsContiguousBytes(await backupFile.readAsBytes(), const [
            0x50,
            0x4b,
            0x06,
            0x06,
          ]),
          isTrue,
          reason: 'normal backups must publish a ZIP64 end record',
        );

        expect(
          await File('${backupFile.parent.path}/_bk_settings.json').exists(),
          isFalse,
        );

        await DataSync.cleanupTemporaryBackupFile(backupFile);

        expect(await backupFile.exists(), isFalse);
        expect(await backupFile.parent.exists(), isFalse);
      },
    );

    test(
      'normal backup includes credentials and declares that in manifest',
      () async {
        SharedPreferences.setMockInitialValues({
          'safe_setting_v1': 'safe-value',
          'global_proxy_password_v1': 'normal-backup-proxy-secret',
          'provider_configs_v1': jsonEncode({
            'openai': {
              'id': 'openai',
              'name': 'Safe Provider',
              'apiKey': 'normal-backup-api-secret',
              'baseUrl': 'https://safe.example',
            },
          }),
        });
        final sync = DataSync(chatService: ChatService());

        final backupFile = await sync.prepareBackupFile(
          const WebDavConfig(includeChats: false, includeFiles: false),
        );

        final input = InputFileStream(backupFile.path);
        Archive? archive;
        try {
          archive = ZipDecoder().decodeStream(input);
          final manifestEntry = archive.findFile('manifest.json');
          final settingsEntry = archive.findFile('settings.json');
          expect(manifestEntry, isNotNull);
          expect(settingsEntry, isNotNull);
          final manifest =
              jsonDecode(utf8.decode(manifestEntry!.readBytes()!))
                  as Map<String, dynamic>;
          final settingsBytes = settingsEntry!.readBytes()!;
          final settings =
              jsonDecode(utf8.decode(settingsBytes)) as Map<String, dynamic>;
          expect(manifest['secretsIncluded'], isTrue);
          expect(settings['safe_setting_v1'], 'safe-value');
          expect(
            settings['global_proxy_password_v1'],
            'normal-backup-proxy-secret',
          );
          final providers =
              jsonDecode(settings['provider_configs_v1'] as String) as Map;
          final provider = providers['openai'] as Map;
          expect(provider['name'], 'Safe Provider');
          expect(provider['baseUrl'], 'https://safe.example');
          expect(provider['apiKey'], 'normal-backup-api-secret');
          expect(
            utf8.decode(settingsBytes),
            contains('normal-backup-api-secret'),
          );
        } finally {
          archive?.clearSync();
          input.closeSync();
          await DataSync.cleanupTemporaryBackupFile(backupFile);
        }
      },
    );

    test(
      'credential backup restores saved secrets and preserves unrelated ones',
      () async {
        SharedPreferences.setMockInitialValues({
          'global_proxy_enabled_v1': true,
          'global_proxy_host_v1': 'source.example',
          'provider_configs_v1': jsonEncode({
            'openai': {
              'id': 'openai',
              'name': 'Source Provider',
              'apiKey': 'source-api-secret',
              'baseUrl': 'https://source.example',
            },
          }),
        });
        final sync = DataSync(chatService: ChatService());
        final backupFile = await sync.prepareBackupFile(
          const WebDavConfig(includeChats: false, includeFiles: false),
        );
        addTearDown(() => DataSync.cleanupTemporaryBackupFile(backupFile));

        SharedPreferences.setMockInitialValues({
          'global_proxy_enabled_v1': false,
          'global_proxy_host_v1': 'target.example',
          'global_proxy_password_v1': 'target-proxy-secret',
          'provider_configs_v1': jsonEncode({
            'openai': {
              'id': 'openai',
              'name': 'Target Provider',
              'apiKey': 'target-api-secret',
              'baseUrl': 'https://target.example',
            },
          }),
          'provider_configs_backup_v1': jsonEncode({
            'old': {'apiKey': 'target-provider-backup-secret'},
          }),
          'search_services_v1': jsonEncode([
            {'id': 'old-search', 'apiKey': 'target-search-secret'},
          ]),
          'tts_services_v1': jsonEncode([
            {'id': 'old-tts', 'apiKey': 'target-tts-secret'},
          ]),
          'mcp_servers_v1': jsonEncode([
            {
              'id': 'old-mcp',
              'headers': {'Authorization': 'target-mcp-secret'},
            },
          ]),
          'assistants_v1': jsonEncode([
            {
              'id': 'old-assistant',
              'customHeaders': [
                {'name': 'Authorization', 'value': 'target-assistant-secret'},
              ],
            },
          ]),
          'webdav_config_v1': jsonEncode({'password': 'target-webdav-secret'}),
          's3_config_v1': jsonEncode({'secretAccessKey': 'target-s3-secret'}),
        });

        await sync.restoreFromLocalFile(
          backupFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('global_proxy_enabled_v1'), isFalse);
        expect(prefs.getString('global_proxy_host_v1'), 'target.example');
        expect(
          prefs.getString('global_proxy_password_v1'),
          'target-proxy-secret',
        );

        await _recoverAcrossColdRestart(
          appDataDirectory: root,
          preferences: prefs,
        );
        await prefs.reload();
        expect(prefs.getBool('global_proxy_enabled_v1'), isTrue);
        expect(prefs.getString('global_proxy_host_v1'), 'source.example');
        expect(
          prefs.getString('global_proxy_password_v1'),
          'target-proxy-secret',
        );
        final providers =
            jsonDecode(prefs.getString('provider_configs_v1')!) as Map;
        final provider = providers['openai'] as Map;
        expect(provider['name'], 'Source Provider');
        expect(provider['apiKey'], 'source-api-secret');
        for (final key in [
          'provider_configs_backup_v1',
          'search_services_v1',
          'tts_services_v1',
          'mcp_servers_v1',
          'assistants_v1',
          'webdav_config_v1',
          's3_config_v1',
        ]) {
          expect(prefs.containsKey(key), isTrue, reason: key);
        }
      },
    );

    test(
      'rejects a falsely declared secret-free bundle before prepared receipt',
      () async {
        final backupFile = await _createSqliteBackupFixture(
          root: root,
          prefix: 'false_secret_free',
          settings: const {'global_proxy_password_v1': 'source-proxy-secret'},
          secretsIncluded: false,
        );
        SharedPreferences.setMockInitialValues({
          'global_proxy_password_v1': 'target-proxy-secret',
        });

        await expectLater(
          DataSync(chatService: ChatService()).restoreFromLocalFile(
            backupFile,
            const WebDavConfig(includeChats: true, includeFiles: false),
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'manifest_fields',
            ),
          ),
        );

        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.getString('global_proxy_password_v1'),
          'target-proxy-secret',
        );
        expect(
          await RestoreStartupGate.inspect(appDataDirectory: root),
          isNull,
        );
      },
    );

    test('complete settings merge applies source credentials', () async {
      SharedPreferences.setMockInitialValues({
        'provider_configs_v1': jsonEncode({
          'openai': {
            'id': 'openai',
            'name': 'Source Provider',
            'apiKey': 'source-api-secret',
            'baseUrl': 'https://source.example',
          },
        }),
      });
      final sync = DataSync(chatService: ChatService());
      final backupFile = await sync.prepareBackupFile(
        const WebDavConfig(includeChats: false, includeFiles: false),
      );
      addTearDown(() => DataSync.cleanupTemporaryBackupFile(backupFile));

      final targetProviders = jsonEncode({
        'openai': {
          'id': 'openai',
          'name': 'Target Provider',
          'apiKey': 'target-api-secret',
          'baseUrl': 'https://target.example',
        },
      });
      SharedPreferences.setMockInitialValues({
        'provider_configs_v1': targetProviders,
      });

      await sync.restoreFromLocalFile(
        backupFile,
        const WebDavConfig(includeChats: false, includeFiles: false),
        mode: RestoreMode.merge,
      );

      final prefs = await SharedPreferences.getInstance();
      final providers =
          jsonDecode(prefs.getString('provider_configs_v1')!) as Map;
      final provider = providers['openai'] as Map;
      expect(provider['name'], 'Source Provider');
      expect(provider['baseUrl'], 'https://source.example');
      expect(provider['apiKey'], 'source-api-secret');
    });

    test(
      'credential backup does not remove unrelated credential settings',
      () async {
        SharedPreferences.setMockInitialValues({'source_setting': 'source'});
        final sync = DataSync(chatService: ChatService());
        final backupFile = await sync.prepareBackupFile(
          const WebDavConfig(includeChats: false, includeFiles: false),
        );
        addTearDown(() => DataSync.cleanupTemporaryBackupFile(backupFile));

        final targetSearchServices = jsonEncode([
          {'id': 'target', 'apiKey': 'target-search-secret'},
        ]);
        SharedPreferences.setMockInitialValues({
          'search_services_v1': targetSearchServices,
        });
        SharedPreferencesStorePlatform.instance =
            _FailingRemovePreferencesStore({
              'flutter.search_services_v1': targetSearchServices,
            });

        await sync.restoreFromLocalFile(
          backupFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        expect(prefs.getString('search_services_v1'), targetSearchServices);
        expect(prefs.getString('source_setting'), isNull);

        final result = await _recoverAcrossColdRestart(
          appDataDirectory: root,
          preferences: prefs,
        );
        expect(result?.state, RestoreReceiptState.committed);

        await prefs.reload();
        expect(prefs.getString('search_services_v1'), targetSearchServices);
        expect(prefs.getString('source_setting'), 'source');
        expect(
          await RestoreStartupGate.inspect(appDataDirectory: root),
          isNull,
        );
        expect(
          (await RestoreReceiptStore(
            appDataDirectory: root,
            runId: result!.runId,
            archived: true,
          ).readLatest())?.state,
          RestoreReceiptState.committed,
        );
      },
    );

    test('writes a consistent SQLite snapshot instead of chats.json', () async {
      final chatService = ChatService();
      await chatService.init();
      addTearDown(chatService.close);
      await chatService.restoreConversation(
        Conversation(
          id: 'snapshot-conversation',
          title: 'Snapshot',
          messageIds: const ['snapshot-message'],
        ),
        [
          ChatMessage(
            id: 'snapshot-message',
            role: 'assistant',
            content: 'snapshot content',
            conversationId: 'snapshot-conversation',
          ),
        ],
      );

      final backupFile = await DataSync(chatService: chatService)
          .prepareBackupFile(
            const WebDavConfig(includeChats: true, includeFiles: false),
          );
      addTearDown(() => DataSync.cleanupTemporaryBackupFile(backupFile));

      final input = InputFileStream(backupFile.path);
      Archive? archive;
      try {
        archive = ZipDecoder().decodeStream(input);
        final manifestEntry = archive.findFile('manifest.json');
        final databaseEntry = archive.findFile('database/kelivo.db');

        expect(manifestEntry, isNotNull);
        expect(databaseEntry, isNotNull);
        expect(archive.findFile('chats.json'), isNull);

        final snapshotFile = File('${root.path}/archived.sqlite');
        await snapshotFile.writeAsBytes(databaseEntry!.readBytes()!);
        final archivedHash = await _fileSha256(snapshotFile);
        final archivedContent = await Isolate.run(() async {
          final repository = ChatDatabaseRepository.open(file: snapshotFile);
          try {
            await repository.ensureReady();
            await repository.validateIntegrity();
            if (await repository.getConversation('snapshot-conversation') ==
                null) {
              throw StateError('snapshot-conversation');
            }
            return (await repository.getMessagesRange(
              'snapshot-conversation',
              start: 0,
              limit: 1,
            )).single.content;
          } finally {
            await repository.close();
          }
        });
        expect(archivedContent, 'snapshot content');

        final manifest =
            jsonDecode(utf8.decode(manifestEntry!.readBytes()!))
                as Map<String, dynamic>;
        expect(manifest['format'], 'kelivo-backup');
        expect(manifest['formatVersion'], 2);
        expect(manifest['payloadKind'], 'sqlite');
        expect(manifest['includeChats'], isTrue);
        expect(manifest['appVersion'], '1.0.0-test+1');
        expect(
          ((manifest['entries'] as Map)['database/kelivo.db'] as Map)['sha256'],
          archivedHash,
        );
      } finally {
        archive?.clearSync();
        input.closeSync();
      }
    });

    test('restores a prepared SQLite snapshot on the next startup', () async {
      final sourceFile = File('${root.path}/source.sqlite');
      final sourceRepository = ChatDatabaseRepository.open(file: sourceFile);
      await sourceRepository.ensureReady();
      await sourceRepository.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'restored-conversation',
            title: 'Restored',
            messageIds: const ['restored-message'],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: 'restored-message',
              role: 'assistant',
              content: 'restored from sqlite',
              conversationId: 'restored-conversation',
              isStreaming: true,
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {
          'restored-message': [
            {'id': 'tool-event'},
          ],
        },
        geminiSignaturesByMessageId: const {'restored-message': 'signature'},
      );
      await sourceRepository.markMigrationComplete();
      await sourceRepository.checkpoint();
      await sourceRepository.close();

      final settingsFile = File('${root.path}/sqlite_settings.json');
      await settingsFile.writeAsString('{}');
      final manifestFile = File('${root.path}/sqlite_manifest.json');
      await manifestFile.writeAsString(
        jsonEncode({
          'format': 'kelivo-backup',
          'formatVersion': 2,
          'payloadKind': 'sqlite',
          'createdAtUtc': '2026-07-09T00:00:00.000Z',
          'includeChats': true,
          'includeFiles': false,
          'appVersion': '1.0.0-test+1',
          'secretsIncluded': true,
          'database': {
            'entry': 'database/kelivo.db',
            'schemaVersion': AppDatabase.currentSchemaVersion,
            'conversationCount': 1,
            'messageCount': 1,
          },
          'entries': {
            'settings.json': {
              'bytes': await settingsFile.length(),
              'sha256': await _fileSha256(settingsFile),
            },
            'database/kelivo.db': {
              'bytes': await sourceFile.length(),
              'sha256': await _fileSha256(sourceFile),
            },
          },
        }),
      );
      final zipFile = File('${root.path}/sqlite_backup.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(manifestFile, 'manifest.json');
      encoder.addFileSync(settingsFile, 'settings.json');
      encoder.addFileSync(sourceFile, 'database/kelivo.db');
      encoder.closeSync();

      final chatService = ChatService();
      await chatService.init();
      addTearDown(chatService.close);
      final existing = await chatService.createConversation(title: 'Existing');

      await DataSync(chatService: chatService).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: true, includeFiles: false),
      );

      expect(chatService.getConversation(existing.id), isNotNull);
      expect(chatService.getConversation('restored-conversation'), isNull);

      await chatService.close();
      await _recoverAcrossColdRestart(appDataDirectory: root);
      await chatService.init();

      expect(chatService.getConversation(existing.id), isNull);
      expect(
        chatService.getConversation('restored-conversation')?.title,
        'Restored',
      );
      final restoredMessage = (await chatService.loadMessages(
        'restored-conversation',
      )).single;
      expect(restoredMessage.content, 'restored from sqlite');
      expect(restoredMessage.isStreaming, isFalse);
      expect(chatService.getToolEvents('restored-message'), const [
        {'id': 'tool-event'},
      ]);
      expect(
        chatService.getGeminiThoughtSignature('restored-message'),
        'signature',
      );
    });

    test('retains a prepared SQLite candidate under app data', () async {
      final zipFile = await _createSqliteBackupFixture(
        root: root,
        prefix: 'same_volume_staging',
        settings: const {},
      );
      final chatService = _RecordingSnapshotPathChatService();

      await DataSync(chatService: chatService).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: true, includeFiles: false),
      );

      expect(chatService.snapshotPath, isNull);
      final workspace = Directory('${root.path}/.kelivo_restore');
      final runDirectory = await _singleRestoreRunDirectory(root);
      final runId = await File('${workspace.path}/.active_run').readAsString();
      expect(
        runDirectory.path.endsWith('${Platform.pathSeparator}run_$runId'),
        isTrue,
      );
      final candidateDatabase = File(
        '${runDirectory.path}/candidate/database/kelivo.db',
      );
      final candidateManifest =
          jsonDecode(
                await File(
                  '${runDirectory.path}/candidate/manifest.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(
        ((candidateManifest['entries'] as Map)['database/kelivo.db']
            as Map)['sha256'],
        await _fileSha256(candidateDatabase),
      );
      final receipt = await RestoreReceiptStore(
        appDataDirectory: root,
        runId: runId,
      ).readLatest();
      expect(receipt?.state, RestoreReceiptState.prepared);
    });

    test(
      'does not retain unselected SQLite or assets in the candidate',
      () async {
        final zipFile = await _createSqliteBackupFixture(
          root: root,
          prefix: 'selected_candidate_only',
          settings: const {'theme': 'dark'},
          includeFiles: true,
          assetContent: 'private unselected asset',
        );

        await DataSync(chatService: ChatService()).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
        );

        final runDirectory = await _singleRestoreRunDirectory(root);
        final candidate = Directory(p.join(runDirectory.path, 'candidate'));
        final manifest =
            jsonDecode(
                  await File(
                    p.join(candidate.path, 'manifest.json'),
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        expect(manifest['payloadKind'], 'settings-only');
        expect(manifest['includeChats'], isFalse);
        expect(manifest['includeFiles'], isFalse);
        expect(manifest['database'], isNull);
        expect((manifest['entries'] as Map<String, dynamic>).keys, [
          'settings.json',
        ]);
        expect(
          await Directory(p.join(candidate.path, 'database')).exists(),
          isFalse,
        );
        for (final rootName in const ['upload', 'images', 'avatars', 'fonts']) {
          expect(
            await Directory(p.join(candidate.path, rootName)).exists(),
            isFalse,
            reason: rootName,
          );
        }
      },
    );

    test(
      'rejects a linked same-volume staging root before live writes',
      () async {
        SharedPreferences.setMockInitialValues({'preserved_setting': 'local'});
        final outside = Directory('${root.path}/outside_staging');
        await outside.create(recursive: true);
        await Link('${root.path}/.kelivo_restore').create(outside.path);
        final zipFile = await _createSqliteBackupFixture(
          root: root,
          prefix: 'linked_staging_root',
          settings: const {'preserved_setting': 'imported'},
        );

        await expectLater(
          DataSync(chatService: ChatService()).restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: false, includeFiles: false),
          ),
          throwsStateError,
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('preserved_setting'), 'local');
      },
      skip: Platform.isWindows
          ? 'Creating a symbolic link requires elevated Windows privileges.'
          : false,
    );

    test('empty versioned asset roots clear old files on startup', () async {
      for (final rootName in const ['upload', 'images', 'avatars', 'fonts']) {
        final directory = Directory('${root.path}/$rootName');
        await directory.create(recursive: true);
        await File('${directory.path}/old.bin').writeAsBytes([1, 2, 3]);
      }
      final zipFile = await _createSqliteBackupFixture(
        root: root,
        prefix: 'empty_asset_roots',
        settings: const {},
        includeFiles: true,
      );

      await DataSync(chatService: ChatService()).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: false, includeFiles: true),
      );

      for (final rootName in const ['upload', 'images', 'avatars', 'fonts']) {
        expect(
          await File('${root.path}/$rootName/old.bin').exists(),
          isTrue,
          reason: rootName,
        );
      }

      await _recoverAcrossColdRestart(appDataDirectory: root);

      for (final rootName in const ['upload', 'images', 'avatars', 'fonts']) {
        final directory = Directory('${root.path}/$rootName');
        expect(await directory.exists(), isTrue, reason: rootName);
        expect(await directory.list().toList(), isEmpty, reason: rootName);
      }
    });

    test('retains every selected SQLite and asset component', () async {
      final zipFile = await _createSqliteBackupFixture(
        root: root,
        prefix: 'all_selected_candidate',
        settings: const {'theme': 'dark'},
        includeFiles: true,
        assetContent: 'selected asset',
      );

      await DataSync(chatService: ChatService()).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: true, includeFiles: true),
      );

      final runDirectory = await _singleRestoreRunDirectory(root);
      final candidate = Directory(p.join(runDirectory.path, 'candidate'));
      final manifest =
          jsonDecode(
                await File(
                  p.join(candidate.path, 'manifest.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(manifest['payloadKind'], 'sqlite');
      expect(manifest['includeChats'], isTrue);
      expect(manifest['includeFiles'], isTrue);
      expect(manifest['database'], isA<Map<String, dynamic>>());
      expect(
        (manifest['entries'] as Map<String, dynamic>).keys,
        containsAll([
          'settings.json',
          'database/kelivo.db',
          'upload/fixture.txt',
        ]),
      );
      expect(
        await File(p.join(candidate.path, 'database', 'kelivo.db')).exists(),
        isTrue,
      );
      expect(
        await File(
          p.join(candidate.path, 'upload', 'fixture.txt'),
        ).readAsString(),
        'selected asset',
      );
    });

    test(
      'versioned preparation does not call the open live database service',
      () async {
        SharedPreferences.setMockInitialValues({
          'preserved_setting': 'local',
          'target_only_setting': 'keep',
          'global_proxy_password_v1': 'local-secret',
        });
        final zipFile = await _createSqliteBackupFixture(
          root: root,
          prefix: 'settings_rollback',
          settings: const {
            'preserved_setting': 'imported',
            'incoming_only_setting': 'remove-on-rollback',
            'global_proxy_password_v1': 'source-secret',
          },
          secretsIncluded: true,
        );

        await DataSync(
          chatService: _FailingSnapshotRestoreChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('preserved_setting'), 'local');
        expect(prefs.getString('target_only_setting'), 'keep');
        expect(prefs.getString('incoming_only_setting'), isNull);
        expect(prefs.getString('global_proxy_password_v1'), 'local-secret');
        expect(prefs.getString('written_during_restore'), isNull);
        final pending = await RestoreStartupGate.inspect(
          appDataDirectory: root,
        );
        expect(pending?.receipt.state, RestoreReceiptState.prepared);
      },
    );

    test('rolls back a partial versioned settings write', () async {
      SharedPreferences.setMockInitialValues({
        'preserved_setting': 'local',
        'target_only_setting': 'keep',
      });
      SharedPreferencesStorePlatform.instance = _FailingNthSetPreferencesStore({
        'flutter.preserved_setting': 'local',
        'flutter.target_only_setting': 'keep',
      }, failOnCall: 2);
      final zipFile = await _createSqliteBackupFixture(
        root: root,
        prefix: 'partial_settings_rollback',
        settings: const {
          'preserved_setting': 'imported',
          'incoming_only_setting': 'remove-on-rollback',
        },
      );

      await DataSync(chatService: ChatService()).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: false, includeFiles: false),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getString('preserved_setting'), 'local');
      expect(prefs.getString('target_only_setting'), 'keep');
      expect(prefs.getString('incoming_only_setting'), isNull);

      final result = await _recoverAcrossColdRestart(
        appDataDirectory: root,
        preferences: prefs,
      );
      expect(result?.state, RestoreReceiptState.rolledBack);

      await prefs.reload();
      expect(prefs.getString('preserved_setting'), 'local');
      expect(prefs.getString('target_only_setting'), 'keep');
      expect(prefs.getString('incoming_only_setting'), isNull);
      expect(await RestoreStartupGate.inspect(appDataDirectory: root), isNull);
      expect(
        (await RestoreReceiptStore(
          appDataDirectory: root,
          runId: result!.runId,
          archived: true,
        ).readLatest())?.state,
        RestoreReceiptState.rolledBack,
      );
    });

    test(
      'rejects a SQLite manifest hash mismatch before changing live data',
      () async {
        final fixture = await _createSqliteBackupFixture(
          root: root,
          prefix: 'bad_hash',
          settings: const {'preserved_setting': 'imported'},
          databaseSha256: List.filled(64, '0').join(),
        );
        SharedPreferences.setMockInitialValues({'preserved_setting': 'local'});
        final chatService = ChatService();
        await chatService.init();
        addTearDown(chatService.close);
        final existing = await chatService.createConversation(title: 'Local');

        await expectLater(
          DataSync(chatService: chatService).restoreFromLocalFile(
            fixture,
            const WebDavConfig(includeChats: true, includeFiles: false),
          ),
          throwsA(isA<FormatException>()),
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('preserved_setting'), 'local');
        expect(chatService.getConversation(existing.id), isNotNull);
        expect(chatService.getConversation('fixture-conversation'), isNull);
      },
    );

    test(
      'does not fall back to legacy JSON when a future manifest is present',
      () async {
        final settingsFile = File('${root.path}/future_manifest_settings.json');
        await settingsFile.writeAsString(
          jsonEncode({'preserved_setting': 'imported'}),
        );
        final chatsFile = File('${root.path}/future_manifest_chats.json');
        await chatsFile.writeAsString(
          jsonEncode({
            'version': 1,
            'conversations': [
              Conversation(id: 'legacy-fallback', title: 'Legacy').toJson(),
            ],
            'messages': <Map<String, dynamic>>[],
          }),
        );
        final manifestFile = File('${root.path}/future_manifest.json');
        await manifestFile.writeAsString(
          jsonEncode({
            'format': 'kelivo-backup',
            'formatVersion': 3,
            'payloadKind': 'settings-only',
            'createdAtUtc': '2026-07-09T00:00:00.000Z',
            'appVersion': 'future',
            'includeChats': false,
            'includeFiles': false,
            'secretsIncluded': true,
            'entries': {
              'settings.json': {
                'bytes': await settingsFile.length(),
                'sha256': await _fileSha256(settingsFile),
              },
            },
          }),
        );
        final zipFile = File('${root.path}/future_manifest.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(manifestFile, 'manifest.json');
        encoder.addFileSync(settingsFile, 'settings.json');
        encoder.addFileSync(chatsFile, 'chats.json');
        encoder.closeSync();

        SharedPreferences.setMockInitialValues({'preserved_setting': 'local'});
        final chatService = ChatService();
        await chatService.init();
        addTearDown(chatService.close);

        await expectLater(
          DataSync(chatService: chatService).restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: true, includeFiles: false),
          ),
          throwsA(isA<FormatException>()),
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('preserved_setting'), 'local');
        expect(chatService.getConversation('legacy-fallback'), isNull);
      },
    );

    test('rejects case-folded duplicate ZIP paths before restoring', () async {
      final firstSettings = File('${root.path}/duplicate_settings_one.json');
      final secondSettings = File('${root.path}/duplicate_settings_two.json');
      await firstSettings.writeAsString(
        jsonEncode({'preserved_setting': 'first'}),
      );
      await secondSettings.writeAsString(
        jsonEncode({'preserved_setting': 'second'}),
      );
      final zipFile = File('${root.path}/duplicate_paths.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(firstSettings, 'settings.json');
      encoder.addFileSync(secondSettings, 'SETTINGS.JSON');
      encoder.closeSync();
      SharedPreferences.setMockInitialValues({'preserved_setting': 'local'});

      await expectLater(
        DataSync(chatService: ChatService()).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
        ),
        throwsA(isA<FormatException>()),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('preserved_setting'), 'local');
    });

    test(
      'stops extraction when expanded bytes exceed the ZIP header',
      () async {
        final settingsFile = File('${root.path}/bounded_settings.json');
        await settingsFile.writeAsString(
          jsonEncode({'preserved_setting': 'imported'}),
        );
        final zipFile = File('${root.path}/bounded_restore.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(settingsFile, 'settings.json');
        encoder.closeSync();
        await _overwriteCentralDirectoryUncompressedSize(zipFile, 1);
        SharedPreferences.setMockInitialValues({'preserved_setting': 'local'});

        await expectLater(
          DataSync(chatService: ChatService()).restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: false, includeFiles: false),
          ),
          throwsA(isA<FormatException>()),
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('preserved_setting'), 'local');
      },
    );

    test('bounds manifest expansion before parsing it', () async {
      final manifestFile = File('${root.path}/bounded_manifest.json');
      await manifestFile.writeAsString(
        jsonEncode({
          'format': 'kelivo-backup',
          'formatVersion': 2,
          'payloadKind': 'settings-only',
          'createdAtUtc': '2026-07-09T00:00:00.000Z',
          'appVersion': 'test',
          'includeChats': false,
          'includeFiles': false,
          'secretsIncluded': true,
          'entries': const <String, dynamic>{},
        }),
      );
      final zipFile = File('${root.path}/bounded_manifest.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(manifestFile, 'manifest.json');
      encoder.closeSync();
      await _overwriteCentralDirectoryUncompressedSize(zipFile, 1);
      SharedPreferences.setMockInitialValues({'preserved_setting': 'local'});

      await expectLater(
        DataSync(chatService: ChatService()).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
        ),
        throwsA(isA<FormatException>()),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('preserved_setting'), 'local');
    });

    test('rejects a SQLite payload without a manifest', () async {
      final settingsFile = File('${root.path}/unversioned_db_settings.json');
      final databaseFile = File('${root.path}/unversioned.sqlite');
      await settingsFile.writeAsString(
        jsonEncode({'preserved_setting': 'imported'}),
      );
      await databaseFile.writeAsBytes(const [1, 2, 3]);
      final zipFile = File('${root.path}/unversioned_db.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(settingsFile, 'settings.json');
      encoder.addFileSync(databaseFile, 'database/kelivo.db');
      encoder.closeSync();
      SharedPreferences.setMockInitialValues({'preserved_setting': 'local'});

      await expectLater(
        DataSync(chatService: ChatService()).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        ),
        throwsA(isA<FormatException>()),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('preserved_setting'), 'local');
    });

    test('merges SQLite snapshot without clobbering local data', () async {
      final fixture = await _createSqliteBackupFixture(
        root: root,
        prefix: 'merge_rejected',
        settings: const {'preserved_setting': 'imported'},
      );
      SharedPreferences.setMockInitialValues({'preserved_setting': 'local'});
      final chatService = ChatService();
      await chatService.init();
      addTearDown(chatService.close);
      final existing = await chatService.createConversation(title: 'Local');

      final sync = DataSync(chatService: chatService);
      await sync.restoreFromLocalFile(
        fixture,
        const WebDavConfig(includeChats: true, includeFiles: false),
        mode: RestoreMode.merge,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('preserved_setting'), 'local');
      expect(chatService.getConversation(existing.id), isNotNull);
      expect(chatService.getConversation('fixture-conversation'), isNotNull);
      expect(sync.lastMergeReport?.importedConversations, 1);
    });

    test(
      'merge settings rolls back every key when a later write fails',
      () async {
        SharedPreferences.setMockInitialValues({'local_setting': 'keep'});
        SharedPreferencesStorePlatform.instance =
            _FailingNthSetPreferencesStore({
              'flutter.local_setting': 'keep',
            }, failOnCall: 2);
        final settingsFile = File('${root.path}/atomic_merge_settings.json');
        await settingsFile.writeAsString(
          jsonEncode({'incoming_a': 'first', 'incoming_b': 'second'}),
        );
        final zipFile = File('${root.path}/atomic_merge_settings.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(settingsFile, 'settings.json');
        encoder.closeSync();

        await expectLater(
          DataSync(chatService: ChatService()).restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: false, includeFiles: false),
            mode: RestoreMode.merge,
          ),
          throwsA(isA<StateError>()),
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        expect(prefs.getString('local_setting'), 'keep');
        expect(prefs.getString('incoming_a'), isNull);
        expect(prefs.getString('incoming_b'), isNull);
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
          jsonEncode({
            'restored_setting': 'new',
            'global_proxy_password_v1': 'legacy-proxy-secret',
            'provider_configs_v1': jsonEncode({
              'openai': {'id': 'openai', 'apiKey': 'legacy-api-secret'},
            }),
          }),
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
        expect(
          prefs.getString('global_proxy_password_v1'),
          'legacy-proxy-secret',
        );
        expect(
          prefs.getString('provider_configs_v1'),
          contains('legacy-api-secret'),
        );
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
        (await chatService.loadMessages('cache-conversation')).single.content,
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
        (await chatService.loadMessages('cache-conversation')).single.content,
        'new content',
      );
      expect(
        (await chatService.loadMessages(
          'cache-conversation',
        )).single.isStreaming,
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
