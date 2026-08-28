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

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_restore_service.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/schema_migrations.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/utils/kelivo_file_uri.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:Kelivo/core/providers/backup_provider.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/instruction_injection_store.dart';

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
  List<Conversation>? replacedConversations;
  List<ChatMessage>? replacedMessages;

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
    replacedConversations = conversations;
    replacedMessages = messages;
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

Future<Map<String, ({int bytes, String sha256})>>
_expectedPackedEntriesFromManifest(File zipFile) async {
  final input = InputFileStream(zipFile.path);
  Archive? archive;
  try {
    archive = ZipDecoder().decodeStream(input);
    final manifestEntry = archive.findFile('manifest.json');
    expect(manifestEntry, isNotNull);
    final manifestBytes = manifestEntry!.readBytes()!;
    final manifest =
        jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;
    final rawEntries = manifest['entries'] as Map;
    return {
      for (final entry in rawEntries.entries)
        entry.key as String: (
          bytes: (entry.value as Map)['bytes'] as int,
          sha256: (entry.value as Map)['sha256'] as String,
        ),
      'manifest.json': (
        bytes: manifestBytes.length,
        sha256: sha256.convert(manifestBytes).toString(),
      ),
    };
  } finally {
    archive?.clearSync();
    input.closeSync();
  }
}

Future<String> _readSnapshotMessageContent(String snapshotPath) async {
  final repository = ChatDatabaseRepository.open(file: File(snapshotPath));
  try {
    await repository.ensureReady();
    await repository.validateIntegrity();
    if (await repository.getConversation('snapshot-conversation') == null) {
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

Future<void> _overwriteLastDataDescriptorUncompressedSize(
  File zipFile,
  int size,
) async {
  final bytes = await zipFile.readAsBytes();
  const signature = [0x50, 0x4b, 0x07, 0x08];
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
  if (headerOffset < 0) throw StateError('data_descriptor');
  for (var i = 0; i < 4; i++) {
    bytes[headerOffset + 12 + i] = (size >> (8 * i)) & 0xff;
  }
  await zipFile.writeAsBytes(bytes, flush: true);
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
  Object? businessEntityRowIds,
  int? schemaVersionOverride,
  int? minimumReadableOverride,
  Map<String, String> extraEntries = const {},
  Map<String, Object> extraManifestFields = const {},
  Map<String, Object> extraManifestDatabaseFields = const {},
  int? formatVersionOverride,
  int? minimumReadableFormatOverride,
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
  final extraFiles = <String, File>{};
  for (final extra in extraEntries.entries) {
    final file = File('${root.path}/${prefix}_extra_${extraFiles.length}.bin');
    await file.writeAsString(extra.value, flush: true);
    extraFiles[extra.key] = file;
    entries[extra.key] = {
      'bytes': await file.length(),
      'sha256': await _fileSha256(file),
    };
  }
  final manifestFile = File('${root.path}/${prefix}_manifest.json');
  await manifestFile.writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': formatVersionOverride ?? 2,
      if (minimumReadableFormatOverride != null)
        'minimumReadableFormatVersion': minimumReadableFormatOverride,
      'payloadKind': 'sqlite',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': '1.0.0-test+1',
      'includeChats': true,
      'includeFiles': includeFiles,
      'secretsIncluded': secretsIncluded,
      if (businessEntityRowIds != null)
        'businessEntityRowIds': businessEntityRowIds,
      ...extraManifestFields,
      'database': {
        ...extraManifestDatabaseFields,
        'entry': 'database/kelivo.db',
        'schemaVersion': schemaVersionOverride ?? snapshotInfo.schemaVersion,
        if (minimumReadableOverride != null)
          SchemaMigrations.minimumReadableManifestKey: minimumReadableOverride,
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
  for (final extra in extraFiles.entries) {
    encoder.addFileSync(extra.value, extra.key);
  }
  encoder.closeSync();
  return zipFile;
}

Future<RestoreReceipt?> _recoverAcrossColdRestart({
  required Directory appDataDirectory,
}) => RestoreStartupGate.recoverAndRequireBusinessReady(
  appDataDirectory: appDataDirectory,
);

void main() {
  group('DataSync backup file', () {
    late Directory root;
    late File validSettingsFile;
    late AppDatabase businessDatabase;
    late BusinessRepository businessRepository;

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
      businessDatabase = AppDatabase.open(
        file: File('${root.path}/business_test.sqlite'),
      );
      businessRepository = BusinessRepository(businessDatabase);
      await BusinessRestoreService(
        businessRepository,
      ).overwrite({'backup_test_key': 'value'});
      validSettingsFile = File('${root.path}/valid_settings.json');
      await validSettingsFile.writeAsString('{}');
    });

    tearDown(() async {
      await businessDatabase.close();
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
        // Abandoned entries (older than the 6h reclaim threshold) carry their
        // age in the name, matching prepareBackupFile's naming.
        final staleWorkDir = Directory(
          '${tmpDir.path}/kelivo_backup_2000-01-01T00-00-00.000000',
        );
        await staleWorkDir.create(recursive: true);
        await File('${staleWorkDir.path}/orphan.zip').writeAsString('old');
        final staleZip = File(
          '${tmpDir.path}/kelivo_backup_2000-01-01T00-00-01.000000.zip',
        );
        await staleZip.writeAsString('old');
        final staleLegacy = File('${tmpDir.path}/_bk_chats.json');
        await staleLegacy.writeAsString('{}');
        await staleLegacy.setLastModified(DateTime(2000));
        // A fresh leftover looks like a backup another provider is running
        // right now and must survive the sweep.
        final freshWorkDir = Directory(
          '${tmpDir.path}/kelivo_backup_'
          '${DateTime.now().toIso8601String().replaceAll(':', '-')}',
        );
        await freshWorkDir.create(recursive: true);

        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        );
        final backupFile = await sync.prepareBackupFile(
          const WebDavConfig(includeChats: false, includeFiles: true),
        );

        expect(await staleWorkDir.exists(), isFalse);
        expect(await staleZip.exists(), isFalse);
        expect(await staleLegacy.exists(), isFalse);
        expect(await freshWorkDir.exists(), isTrue);
        await freshWorkDir.delete(recursive: true);

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
      'streaming export verify rejects a packed zip after one entry byte is corrupted',
      () async {
        final uploadDir = Directory('${root.path}/upload');
        await uploadDir.create(recursive: true);
        await File('${uploadDir.path}/payload.bin').writeAsBytes(
          List<int>.generate(64 * 1024, (index) => index % 251),
          flush: true,
        );
        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        );
        final backupFile = await sync.prepareBackupFile(
          const WebDavConfig(includeChats: false, includeFiles: true),
        );
        addTearDown(() => DataSync.cleanupTemporaryBackupFile(backupFile));

        final expected = await _expectedPackedEntriesFromManifest(backupFile);
        DataSync.verifyPackedBackupSync(
          zipPath: backupFile.path,
          expectedEntries: expected,
        );

        final bytes = await backupFile.readAsBytes();
        final flipAt = bytes.length ~/ 2;
        bytes[flipAt] = bytes[flipAt] ^ 0xff;
        await backupFile.writeAsBytes(bytes, flush: true);

        expect(
          () => DataSync.verifyPackedBackupSync(
            zipPath: backupFile.path,
            expectedEntries: expected,
          ),
          throwsA(anything),
        );
      },
    );

    test(
      'streaming export verify rejects a packed zip when manifest.json hash mismatches',
      () async {
        final uploadDir = Directory('${root.path}/upload');
        await uploadDir.create(recursive: true);
        await File('${uploadDir.path}/payload.bin').writeAsBytes(
          List<int>.generate(8 * 1024, (index) => index % 251),
          flush: true,
        );
        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        );
        final backupFile = await sync.prepareBackupFile(
          const WebDavConfig(includeChats: false, includeFiles: true),
        );
        addTearDown(() => DataSync.cleanupTemporaryBackupFile(backupFile));

        final expected = await _expectedPackedEntriesFromManifest(backupFile);
        DataSync.verifyPackedBackupSync(
          zipPath: backupFile.path,
          expectedEntries: expected,
        );

        final mutated = Map<String, ({int bytes, String sha256})>.from(
          expected,
        );
        mutated['manifest.json'] = (
          bytes: expected['manifest.json']?.bytes ?? 1,
          sha256: '0' * 64,
        );

        expect(
          () => DataSync.verifyPackedBackupSync(
            zipPath: backupFile.path,
            expectedEntries: mutated,
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('manifest'),
            ),
          ),
        );
      },
    );

    test('export does not create a sibling extract directory', () async {
      final uploadDir = Directory('${root.path}/upload');
      await uploadDir.create(recursive: true);
      await File(
        '${uploadDir.path}/payload.bin',
      ).writeAsBytes(List<int>.filled(32 * 1024, 5), flush: true);
      final tmpDir = Directory('${root.path}/tmp');
      await tmpDir.create(recursive: true);
      final createdVerify = <String>[];
      final watch = tmpDir.watch(recursive: true).listen((event) {
        if (p.basename(event.path) == '_verify') {
          createdVerify.add(event.path);
        }
      });
      addTearDown(watch.cancel);

      final sync = DataSync(
        businessRepository: businessRepository,
        chatService: ChatService(),
      );
      final backupFile = await sync.prepareBackupFile(
        const WebDavConfig(includeChats: false, includeFiles: true),
      );
      addTearDown(() => DataSync.cleanupTemporaryBackupFile(backupFile));
      await Future<void>.delayed(Duration.zero);

      expect(createdVerify, isEmpty);
      expect(
        Directory(p.join(backupFile.parent.path, '_verify')).existsSync(),
        isFalse,
      );
      expect(backupFile.parent.listSync().whereType<Directory>(), isEmpty);
      expect(
        backupFile.parent.listSync().map((entity) => p.basename(entity.path)),
        [p.basename(backupFile.path)],
      );
    });

    test(
      'export succeeds for a package that restore still size-rejects',
      () async {
        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        );
        final backupFile = await sync.prepareBackupFile(
          const WebDavConfig(includeChats: false, includeFiles: false),
        );
        addTearDown(() => DataSync.cleanupTemporaryBackupFile(backupFile));
        expect(await backupFile.exists(), isTrue);
        expect(
          Directory(p.join(backupFile.parent.path, '_verify')).existsSync(),
          isFalse,
        );

        await _overwriteLastDataDescriptorUncompressedSize(
          backupFile,
          16 * 1024 * 1024 + 1,
        );
        final before = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();

        await expectLater(
          sync.restoreFromLocalFile(
            backupFile,
            const WebDavConfig(includeChats: false, includeFiles: false),
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'manifest_size',
            ),
          ),
        );
        expect(
          await BusinessRestoreService(businessRepository).exportSettings(),
          before,
        );
      },
    );

    test('cancelling packing deletes the work directory', () async {
      final uploadDir = Directory('${root.path}/upload');
      await uploadDir.create(recursive: true);
      await File(
        '${uploadDir.path}/payload.bin',
      ).writeAsBytes(List<int>.filled(2 * 1024 * 1024, 3));

      final token = BackupCancelToken();
      addTearDown(token.dispose);
      final sync = DataSync(
        businessRepository: businessRepository,
        chatService: ChatService(),
      );

      await expectLater(
        sync.prepareBackupFile(
          const WebDavConfig(includeChats: false, includeFiles: true),
          onProgress: (progress) {
            if (progress.phase == BackupPhase.packing) {
              token.cancel();
            }
          },
          cancelToken: token,
        ),
        throwsA(isA<BackupCancelledException>()),
      );

      final tmp = Directory('${root.path}/tmp');
      if (await tmp.exists()) {
        final leftovers = tmp
            .listSync(recursive: true, followLinks: false)
            .map((entity) => p.basename(entity.path))
            .toList();
        expect(
          leftovers.where(
            (name) =>
                name.startsWith('kelivo_backup_') ||
                name.startsWith('_bk_') ||
                name.endsWith('.zip'),
          ),
          isEmpty,
        );
      }
    });

    test('cancel after pack worker success does not return the zip', () async {
      final token = BackupCancelToken()..cancel();
      addTearDown(token.dispose);
      final zip = File('${root.path}/packed.zip');
      await zip.writeAsBytes([1, 2, 3], flush: true);

      expect(
        () => DataSync.takePreparedBackupFile(zip, token),
        throwsA(isA<BackupCancelledException>()),
      );

      final events = <BackupProgress>[];
      final liveToken = BackupCancelToken();
      addTearDown(liveToken.dispose);
      await expectLater(
        DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).prepareBackupFile(
          const WebDavConfig(includeChats: false, includeFiles: false),
          cancelToken: liveToken,
          onProgress: (progress) {
            events.add(progress);
            if (progress.phase == BackupPhase.verifying &&
                progress.total != null &&
                progress.processed >= progress.total!) {
              liveToken.cancel();
            }
          },
        ),
        throwsA(isA<BackupCancelledException>()),
      );
      expect(
        events.map((event) => event.phase),
        contains(BackupPhase.verifying),
      );
      final tmp = Directory('${root.path}/tmp');
      if (await tmp.exists()) {
        final leftovers = tmp
            .listSync(recursive: true, followLinks: false)
            .map((entity) => p.basename(entity.path))
            .toList();
        expect(
          leftovers.where(
            (name) =>
                name.startsWith('kelivo_backup_') ||
                name.startsWith('_bk_') ||
                name.endsWith('.zip'),
          ),
          isEmpty,
        );
      }
    });

    test(
      'extracting a versioned zip emits a final 100% extracting event',
      () async {
        final zip = await _createSqliteBackupFixture(
          root: root,
          prefix: 'extract_progress',
          settings: const {},
        );
        final events = <BackupProgress>[];
        final chatService = ChatService();
        await chatService.init();
        addTearDown(chatService.close);

        await DataSync(
          businessRepository: businessRepository,
          chatService: chatService,
        ).restoreFromLocalFile(
          zip,
          const WebDavConfig(includeChats: true, includeFiles: false),
          onProgress: events.add,
        );

        final extracting = events
            .where((event) => event.phase == BackupPhase.extracting)
            .toList();
        expect(extracting, isNotEmpty);
        expect(extracting.last.total, isNotNull);
        expect(extracting.last.total, greaterThan(0));
        expect(extracting.last.processed, extracting.last.total);
      },
    );

    test(
      'after byte-verify 100% an indeterminate validating tail then finalizing',
      () async {
        final zip = await _createSqliteBackupFixture(
          root: root,
          prefix: 'validate_tail',
          settings: const {},
        );
        final events = <BackupProgress>[];
        final chatService = ChatService();
        await chatService.init();
        addTearDown(chatService.close);

        await DataSync(
          businessRepository: businessRepository,
          chatService: chatService,
        ).restoreFromLocalFile(
          zip,
          const WebDavConfig(includeChats: true, includeFiles: false),
          onProgress: events.add,
        );

        final verifyDoneIndex = events.indexWhere(
          (event) =>
              event.phase == BackupPhase.validating &&
              event.total != null &&
              event.total! > 0 &&
              event.processed >= event.total!,
        );
        expect(verifyDoneIndex, greaterThanOrEqualTo(0));
        final afterVerify = events.sublist(verifyDoneIndex);
        expect(
          afterVerify.any(
            (event) =>
                event.phase == BackupPhase.validating && event.total == null,
          ),
          isTrue,
        );
        expect(
          afterVerify.map((event) => event.phase),
          contains(BackupPhase.finalizing),
        );
        final tailIndex = afterVerify.indexWhere(
          (event) =>
              event.phase == BackupPhase.validating && event.total == null,
        );
        final finalizingIndex = afterVerify.indexWhere(
          (event) => event.phase == BackupPhase.finalizing,
        );
        expect(tailIndex, greaterThanOrEqualTo(0));
        expect(finalizingIndex, greaterThan(tailIndex));
      },
    );

    test('DEFLATE back-references hash in multi-byte slices', () {
      final prefix = List<int>.generate(16, (index) => index + 1);
      const count = 200000;
      final hashed = DataSync.debugHashBackReference(
        prefix: prefix,
        distance: prefix.length,
        count: count,
      );
      expect(hashed.sliceSizes, isNotEmpty);
      expect(hashed.sliceSizes.every((size) => size > 1), isTrue);
      expect(hashed.sliceSizes.reduce((a, b) => a + b), count);

      final expected = sha256.convert([
        ...prefix,
        for (var i = 0; i < count; i++) prefix[i % prefix.length],
      ]).toString();
      expect(hashed.digest, expected);
    });

    test('cancelling extracting deletes the restore directory', () async {
      final settingsFile = File('${root.path}/extract_cancel_settings.json');
      await settingsFile.writeAsString('{}');
      final blob = File('${root.path}/extract_cancel.bin');
      await blob.writeAsBytes(List<int>.filled(2 * 1024 * 1024, 5));
      final zipFile = File('${root.path}/extract_cancel.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(settingsFile, 'settings.json');
      encoder.addFileSync(blob, 'upload/blob.bin');
      encoder.closeSync();

      final token = BackupCancelToken();
      addTearDown(token.dispose);
      final sync = DataSync(
        businessRepository: businessRepository,
        chatService: ChatService(),
      );

      await expectLater(
        sync.restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: true),
          onProgress: (progress) {
            if (progress.phase == BackupPhase.extracting) {
              token.cancel();
            }
          },
          cancelToken: token,
        ),
        throwsA(isA<BackupCancelledException>()),
      );

      final tmp = Directory('${root.path}/tmp');
      if (await tmp.exists()) {
        final leftovers = tmp
            .listSync(followLinks: false)
            .map((entity) => p.basename(entity.path))
            .toList();
        expect(leftovers.where((name) => name.startsWith('restore_')), isEmpty);
      }
    });

    test(
      'cancelling after legacy chat parse does not overwrite live chats',
      () async {
        final chatService = ChatService();
        await chatService.init();
        addTearDown(chatService.close);
        final existing = await chatService.createConversation(title: 'Live');

        final settingsFile = File('${root.path}/legacy_cancel_settings.json');
        await settingsFile.writeAsString(jsonEncode({'theme': 'dark'}));
        final chatsFile = File('${root.path}/legacy_cancel_chats.json');
        await chatsFile.writeAsString(
          jsonEncode({
            'conversations': [
              Conversation(
                id: 'imported-conversation',
                title: 'Imported',
                messageIds: const ['imported-message'],
              ).toJson(),
            ],
            'messages': [
              ChatMessage(
                id: 'imported-message',
                role: 'user',
                content: 'imported',
                conversationId: 'imported-conversation',
              ).toJson(),
            ],
          }),
        );
        final zipFile = File('${root.path}/legacy_cancel_restore.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(settingsFile, 'settings.json');
        encoder.addFileSync(chatsFile, 'chats.json');
        encoder.closeSync();

        final token = BackupCancelToken();
        addTearDown(token.dispose);

        await expectLater(
          DataSync(
            businessRepository: businessRepository,
            chatService: chatService,
          ).restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: true, includeFiles: false),
            onProgress: (progress) {
              if (progress.phase == BackupPhase.readingSettings) {
                token.cancel();
              }
            },
            cancelToken: token,
          ),
          throwsA(isA<BackupCancelledException>()),
        );

        expect(chatService.getConversation(existing.id), isNotNull);
        expect(chatService.getConversation('imported-conversation'), isNull);
      },
    );

    test(
      'listBackupFiles cancel closes the client and reports listingRemote',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });
        server.listen((_) {});

        final token = BackupCancelToken();
        addTearDown(token.dispose);
        final phases = <BackupPhase>[];
        final future =
            DataSync(
              businessRepository: businessRepository,
              chatService: ChatService(),
            ).listBackupFiles(
              WebDavConfig(
                url: 'http://${server.address.address}:${server.port}',
                path: 'kelivo_backups',
              ),
              onProgress: (progress) => phases.add(progress.phase),
              cancelToken: token,
            );
        await Future<void>.delayed(const Duration(milliseconds: 40));
        token.cancel();

        await expectLater(future, throwsA(isA<BackupCancelledException>()));
        expect(phases, contains(BackupPhase.listingRemote));
      },
    );

    test('cancelling staging leaves no published restore receipt', () async {
      final zipFile = await _createSqliteBackupFixture(
        root: root,
        prefix: 'staging_cancel',
        settings: const {},
      );
      final token = BackupCancelToken();
      addTearDown(token.dispose);
      final chatService = ChatService();
      addTearDown(chatService.close);

      await expectLater(
        DataSync(
          businessRepository: businessRepository,
          chatService: chatService,
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
          onProgress: (progress) {
            if (progress.phase == BackupPhase.stagingCandidate) {
              token.cancel();
            }
          },
          cancelToken: token,
        ),
        throwsA(isA<BackupCancelledException>()),
      );

      expect(await RestoreStartupGate.inspect(appDataDirectory: root), isNull);
    });

    test(
      'normal backup includes credentials and declares that in manifest',
      () async {
        await BusinessRestoreService(businessRepository).overwrite({
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
        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        );

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
      'settings-only overwrite restores saved secrets and replaces unrelated business settings',
      () async {
        await BusinessRestoreService(businessRepository).overwrite({
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
        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        );
        final backupFile = await sync.prepareBackupFile(
          const WebDavConfig(includeChats: false, includeFiles: false),
        );
        addTearDown(() => DataSync.cleanupTemporaryBackupFile(backupFile));

        await BusinessRestoreService(businessRepository).overwrite({
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
          'search_services_v1': jsonEncode([
            {
              'id': 'old-search',
              'type': 'tavily',
              'apiKey': 'target-search-secret',
            },
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

        final restored = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
        expect(restored['global_proxy_enabled_v1'], isTrue);
        expect(restored['global_proxy_host_v1'], 'source.example');
        expect(restored, isNot(contains('global_proxy_password_v1')));
        final providers =
            jsonDecode(restored['provider_configs_v1'] as String) as Map;
        final provider = providers['openai'] as Map;
        expect(provider['name'], 'Source Provider');
        expect(provider['apiKey'], 'source-api-secret');
        for (final key in [
          'search_services_v1',
          'tts_services_v1',
          'mcp_servers_v1',
          'assistants_v1',
        ]) {
          expect(jsonDecode(restored[key] as String), isEmpty, reason: key);
        }
        for (final key in ['webdav_config_v1', 's3_config_v1']) {
          expect(restored, isNot(contains(key)), reason: key);
        }
        expect(
          await RestoreStartupGate.inspect(appDataDirectory: root),
          isNull,
        );
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
        await BusinessRestoreService(
          businessRepository,
        ).overwrite({'global_proxy_password_v1': 'target-proxy-secret'});
        final before = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();

        await expectLater(
          DataSync(
            businessRepository: businessRepository,
            chatService: ChatService(),
          ).restoreFromLocalFile(
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

        expect(
          await BusinessRestoreService(businessRepository).exportSettings(),
          before,
        );
        expect(
          await RestoreStartupGate.inspect(appDataDirectory: root),
          isNull,
        );
      },
    );

    test(
      'rejects malformed business entity row ids before changing live data',
      () async {
        final backupFile = await _createSqliteBackupFixture(
          root: root,
          prefix: 'malformed_business_row_ids',
          settings: const {'incoming': 'value'},
          businessEntityRowIds: const {
            'assistant_tags_v1': ['valid', 42],
          },
        );
        await BusinessRestoreService(
          businessRepository,
        ).overwrite({'preserved': 'local'});
        final before = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();

        await expectLater(
          DataSync(
            businessRepository: businessRepository,
            chatService: ChatService(),
          ).restoreFromLocalFile(
            backupFile,
            const WebDavConfig(includeChats: false, includeFiles: false),
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'manifest_business_entity_row_ids',
            ),
          ),
        );

        expect(
          await BusinessRestoreService(businessRepository).exportSettings(),
          before,
        );
      },
    );

    test('complete settings merge applies source credentials', () async {
      await BusinessRestoreService(businessRepository).overwrite({
        'provider_configs_v1': jsonEncode({
          'openai': {
            'id': 'openai',
            'name': 'Source Provider',
            'apiKey': 'source-api-secret',
            'baseUrl': 'https://source.example',
          },
        }),
      });
      final sync = DataSync(
        businessRepository: businessRepository,
        chatService: ChatService(),
      );
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
      await BusinessRestoreService(
        businessRepository,
      ).overwrite({'provider_configs_v1': targetProviders});

      await sync.restoreFromLocalFile(
        backupFile,
        const WebDavConfig(includeChats: false, includeFiles: false),
        mode: RestoreMode.merge,
      );

      final restored = await BusinessRestoreService(
        businessRepository,
      ).exportSettings();
      final providers =
          jsonDecode(restored['provider_configs_v1'] as String) as Map;
      final provider = providers['openai'] as Map;
      expect(provider['name'], 'Source Provider');
      expect(provider['baseUrl'], 'https://source.example');
      expect(provider['apiKey'], 'source-api-secret');
      expect(sync.lastMergeReport, isNull);
    });

    test(
      'settings-only restore never reads or writes residual preferences',
      () async {
        await BusinessRestoreService(
          businessRepository,
        ).overwrite({'source_setting': 'source'});
        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        );
        final backupFile = await sync.prepareBackupFile(
          const WebDavConfig(includeChats: false, includeFiles: false),
        );
        addTearDown(() => DataSync.cleanupTemporaryBackupFile(backupFile));

        final targetSearchServices = jsonEncode([
          {'id': 'target', 'type': 'tavily', 'apiKey': 'target-search-secret'},
        ]);
        await BusinessRestoreService(
          businessRepository,
        ).overwrite({'search_services_v1': targetSearchServices});
        SharedPreferences.setMockInitialValues({
          'search_services_v1': targetSearchServices,
        });

        await sync.restoreFromLocalFile(
          backupFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        expect(prefs.getString('search_services_v1'), targetSearchServices);
        expect(prefs.containsKey('source_setting'), isFalse);
        final restored = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
        expect(restored['source_setting'], 'source');
        expect(jsonDecode(restored['search_services_v1'] as String), isEmpty);
        expect(
          await RestoreStartupGate.inspect(appDataDirectory: root),
          isNull,
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

      final backupFile =
          await DataSync(
            businessRepository: businessRepository,
            chatService: chatService,
          ).prepareBackupFile(
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
        final snapshotPath = snapshotFile.path;
        final archivedContent = await _readSnapshotMessageContent(snapshotPath);
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

      await DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      ).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: true, includeFiles: false),
      );

      expect(chatService.getConversation(existing.id), isNotNull);
      expect(chatService.getConversation('restored-conversation'), isNull);

      await chatService.close();
      final terminal = await _recoverAcrossColdRestart(appDataDirectory: root);
      expect(terminal?.state, RestoreReceiptState.committed);
      expect(await _recoverAcrossColdRestart(appDataDirectory: root), isNull);
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

    test('ignores unknown archive entries from a newer build', () async {
      final zipFile = await _createSqliteBackupFixture(
        root: root,
        prefix: 'forward_extra_entry',
        settings: const {},
        schemaVersionOverride: AppDatabase.currentSchemaVersion + 1,
        extraEntries: const {
          'future/thing.bin': 'something this build knows nothing about',
        },
      );
      final chatService = ChatService();

      await DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      ).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: true, includeFiles: false),
        allowUnverifiedForwardCompatible: true,
      );

      // Dropped from the staged candidate rather than carried into app data:
      // the archive-level counterpart of the unknown tables and columns the
      // database normalizer strips.
      final runDirectory = await _singleRestoreRunDirectory(root);
      final candidateManifest =
          jsonDecode(
                await File(
                  '${runDirectory.path}/candidate/manifest.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(
        (candidateManifest['entries'] as Map).keys,
        isNot(contains('future/thing.bin')),
      );
      expect(await Directory('${root.path}/future').exists(), isFalse);
    });

    test('rejects unknown archive entries from a same-version build', () async {
      // Nothing vouches for these, and no newer build wrote them: the archive
      // is simply malformed.
      final zipFile = await _createSqliteBackupFixture(
        root: root,
        prefix: 'same_version_extra_entry',
        settings: const {},
        extraEntries: const {'future/thing.bin': 'unexpected'},
      );

      await expectLater(
        DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'manifest_entry_scope:future/thing.bin',
          ),
        ),
      );
    });

    test('ignores unknown manifest fields from a newer build', () async {
      // The archive-entry counterpart is covered above; this is the metadata
      // one. Every validator downstream is single-version -- RestoreBundleStaging
      // checks the manifest's root key set exactly -- so an unrecognised field
      // has to be dropped in the preflight or the restore fails after the user
      // already consented to it.
      final zipFile = await _createSqliteBackupFixture(
        root: root,
        prefix: 'forward_extra_manifest_field',
        settings: const {},
        schemaVersionOverride: AppDatabase.currentSchemaVersion + 1,
        extraManifestFields: const {'futureTopLevel': 'ignored'},
        extraManifestDatabaseFields: const {'codecVersion': 2},
      );
      final chatService = ChatService();

      await DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      ).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: true, includeFiles: false),
        allowUnverifiedForwardCompatible: true,
      );

      final runDirectory = await _singleRestoreRunDirectory(root);
      final candidateManifest =
          jsonDecode(
                await File(
                  '${runDirectory.path}/candidate/manifest.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(candidateManifest.keys, isNot(contains('futureTopLevel')));
      expect(
        (candidateManifest['database'] as Map).keys,
        isNot(contains('codecVersion')),
      );
    });

    test('rejects unknown manifest fields from a same-version build', () async {
      final zipFile = await _createSqliteBackupFixture(
        root: root,
        prefix: 'same_version_extra_manifest_field',
        settings: const {},
        extraManifestDatabaseFields: const {'codecVersion': 2},
      );

      await expectLater(
        DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'restore_staging_database',
          ),
        ),
      );
    });

    test('accepts a newer archive format that vouches for this build', () async {
      // The archive format and the database schema move independently: a newer
      // build can add an ignorable directory without touching the schema at
      // all. Keying tolerance to the schema alone would reject this.
      final zipFile = await _createSqliteBackupFixture(
        root: root,
        prefix: 'forward_format_only',
        settings: const {},
        formatVersionOverride: 3,
        minimumReadableFormatOverride: 2,
        extraEntries: const {'stickers/future.bin': 'ignorable'},
        extraManifestFields: const {'futureTopLevel': 'ignored'},
      );
      final chatService = ChatService();

      await DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      ).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: true, includeFiles: false),
      );

      final runDirectory = await _singleRestoreRunDirectory(root);
      final candidateManifest =
          jsonDecode(
                await File(
                  '${runDirectory.path}/candidate/manifest.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      // Reduced to this build's format, so the staged candidate is an ordinary
      // one that the single-version validators accept unchanged.
      expect(candidateManifest['formatVersion'], 2);
      expect(candidateManifest.keys, isNot(contains('futureTopLevel')));
      expect(
        candidateManifest.keys,
        isNot(contains('minimumReadableFormatVersion')),
      );
      expect(
        (candidateManifest['entries'] as Map).keys,
        isNot(contains('stickers/future.bin')),
      );
      expect(await Directory('${root.path}/stickers').exists(), isFalse);
    });

    test('refuses a newer archive format that vouches for nothing', () async {
      final zipFile = await _createSqliteBackupFixture(
        root: root,
        prefix: 'forward_format_undeclared',
        settings: const {},
        formatVersionOverride: 3,
      );

      await expectLater(
        DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'manifest_version',
          ),
        ),
      );
    });

    test('refuses a newer archive format that demands a newer build', () async {
      final zipFile = await _createSqliteBackupFixture(
        root: root,
        prefix: 'forward_format_too_new',
        settings: const {},
        formatVersionOverride: 3,
        minimumReadableFormatOverride: 3,
      );

      await expectLater(
        DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'manifest_version',
          ),
        ),
      );
    });

    test('every backup this build writes declares its readers', () async {
      // Without this the whole mechanism is inert: a future build has nothing
      // to check against and must refuse today's archives.
      final zipFile =
          await DataSync(
            businessRepository: businessRepository,
            chatService: ChatService(),
          ).exportToFile(
            const WebDavConfig(includeChats: false, includeFiles: false),
          );
      final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
      final manifest =
          jsonDecode(
                utf8.decode(
                  archive.findFile('manifest.json')!.content as List<int>,
                ),
              )
              as Map<String, dynamic>;

      expect(manifest['formatVersion'], 2);
      expect(manifest['minimumReadableFormatVersion'], 2);
      expect(
        manifest['minimumReadableFormatVersion'],
        lessThanOrEqualTo(manifest['formatVersion'] as int),
        reason:
            'declaring a minimum above our own version tells every future '
            'build we are unreadable',
      );
    });

    test('accepts a newer settings-only backup with unknown entries', () async {
      // A settings-only backup carries no database block at all, so a
      // schema-version comparison can never recognise it as newer. Only the
      // archive format can.
      final settingsFile = File('${root.path}/future_settings_only.json');
      await settingsFile.writeAsString(
        jsonEncode({'preserved_setting': 'imported'}),
        flush: true,
      );
      final extraFile = File('${root.path}/future_settings_only_extra.bin');
      await extraFile.writeAsString('ignorable', flush: true);
      final manifestFile = File('${root.path}/future_settings_only_man.json');
      await manifestFile.writeAsString(
        jsonEncode({
          'format': 'kelivo-backup',
          'formatVersion': 3,
          'minimumReadableFormatVersion': 2,
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
            'stickers/future.bin': {
              'bytes': await extraFile.length(),
              'sha256': await _fileSha256(extraFile),
            },
          },
        }),
        flush: true,
      );
      final zipFile = File('${root.path}/future_settings_only.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(manifestFile, 'manifest.json');
      encoder.addFileSync(settingsFile, 'settings.json');
      encoder.addFileSync(extraFile, 'stickers/future.bin');
      encoder.closeSync();

      await BusinessRestoreService(
        businessRepository,
      ).overwrite({'preserved_setting': 'local'});
      final chatService = ChatService();
      await chatService.init();
      addTearDown(chatService.close);

      await DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      ).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: false, includeFiles: false),
      );

      final restored = await BusinessRestoreService(
        businessRepository,
      ).exportSettings();
      expect(restored['preserved_setting'], 'imported');
      expect(await Directory('${root.path}/stickers').exists(), isFalse);
    });

    test('retains a prepared SQLite candidate under app data', () async {
      final zipFile = await _createSqliteBackupFixture(
        root: root,
        prefix: 'same_volume_staging',
        settings: const {},
      );
      final chatService = ChatService();

      await DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      ).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: true, includeFiles: false),
      );

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
      'settings-only restore creates no candidate or asset writes',
      () async {
        final liveAsset = File('${root.path}/upload/live.txt');
        await liveAsset.parent.create(recursive: true);
        await liveAsset.writeAsString('keep-live');
        final zipFile = await _createSqliteBackupFixture(
          root: root,
          prefix: 'selected_candidate_only',
          settings: const {'theme': 'dark'},
          includeFiles: true,
          assetContent: 'private unselected asset',
        );

        await DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
        );

        final restored = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
        expect(restored['theme'], 'dark');
        expect(await liveAsset.readAsString(), 'keep-live');
        expect(
          await Directory('${root.path}/.kelivo_restore').exists(),
          isFalse,
        );
      },
    );

    test(
      'versioned settings-only overwrite preserves an explicitly empty instruction list',
      () async {
        final zipFile = await _createSqliteBackupFixture(
          root: root,
          prefix: 'empty_instructions_overwrite',
          settings: {'instruction_injections_v1': jsonEncode(const <Object>[])},
        );

        await DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
        );

        expect(
          await InstructionInjectionStore(
            BusinessPreferences(businessRepository),
          ).getAll(),
          isEmpty,
        );
      },
    );

    test(
      'versioned settings-only merge keeps local instructions when backup is empty',
      () async {
        final zipFile = await _createSqliteBackupFixture(
          root: root,
          prefix: 'empty_instructions_merge',
          settings: {'instruction_injections_v1': jsonEncode(const <Object>[])},
        );
        await BusinessRestoreService(businessRepository).overwrite({
          'instruction_injections_v1': jsonEncode([
            {'id': 'local', 'title': 'Local', 'prompt': 'Keep'},
          ]),
        });

        await DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
          mode: RestoreMode.merge,
        );

        final restored = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
        expect(jsonDecode(restored['instruction_injections_v1']! as String), [
          {'id': 'local', 'title': 'Local', 'prompt': 'Keep'},
        ]);
        expect(
          (await InstructionInjectionStore(
            BusinessPreferences(businessRepository),
          ).getAll()).map((item) => item.id),
          ['local'],
        );
      },
    );

    test(
      'rejects a linked same-volume staging root before live writes',
      () async {
        await BusinessRestoreService(
          businessRepository,
        ).overwrite({'preserved_setting': 'local'});
        final before = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
        final outside = Directory('${root.path}/outside_staging');
        await outside.create(recursive: true);
        await Link('${root.path}/.kelivo_restore').create(outside.path);
        final zipFile = await _createSqliteBackupFixture(
          root: root,
          prefix: 'linked_staging_root',
          settings: const {'preserved_setting': 'imported'},
        );

        await expectLater(
          DataSync(
            businessRepository: businessRepository,
            chatService: ChatService(),
          ).restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: true, includeFiles: false),
          ),
          throwsStateError,
        );

        expect(
          await BusinessRestoreService(businessRepository).exportSettings(),
          before,
        );
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

      await DataSync(
        businessRepository: businessRepository,
        chatService: ChatService(),
      ).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: true, includeFiles: true),
      );

      for (final rootName in const ['upload', 'images', 'avatars', 'fonts']) {
        expect(
          await File('${root.path}/$rootName/old.bin').exists(),
          isTrue,
          reason: rootName,
        );
      }

      final terminal = await _recoverAcrossColdRestart(appDataDirectory: root);
      expect(terminal?.state, RestoreReceiptState.committed);

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

      await DataSync(
        businessRepository: businessRepository,
        chatService: ChatService(),
      ).restoreFromLocalFile(
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
        containsAll(['database/kelivo.db', 'upload/fixture.txt']),
      );
      expect(
        (manifest['entries'] as Map<String, dynamic>),
        isNot(contains('settings.json')),
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
        await BusinessRestoreService(businessRepository).overwrite({
          'preserved_setting': 'local',
          'target_only_setting': 'keep',
          'global_proxy_password_v1': 'local-secret',
        });
        final before = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
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
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        );

        expect(
          await BusinessRestoreService(businessRepository).exportSettings(),
          before,
        );
        final pending = await RestoreStartupGate.inspect(
          appDataDirectory: root,
        );
        expect(pending?.receipt.state, RestoreReceiptState.prepared);
      },
    );

    test('rolls back a failed versioned settings transaction', () async {
      await BusinessRestoreService(businessRepository).overwrite({
        'preserved_setting': 'local',
        'target_only_setting': 'keep',
      });
      final before = await BusinessRestoreService(
        businessRepository,
      ).exportSettings();
      await businessDatabase.customStatement('''
        CREATE TRIGGER fail_incoming_setting
        BEFORE INSERT ON preference_rows
        WHEN NEW.key = 'incoming_only_setting'
        BEGIN
          SELECT RAISE(ABORT, 'forced settings failure');
        END;
      ''');
      final zipFile = await _createSqliteBackupFixture(
        root: root,
        prefix: 'partial_settings_rollback',
        settings: const {
          'preserved_setting': 'imported',
          'incoming_only_setting': 'remove-on-rollback',
        },
      );

      await expectLater(
        DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
        ),
        throwsA(anything),
      );

      expect(
        await BusinessRestoreService(businessRepository).exportSettings(),
        before,
      );
      expect(await RestoreStartupGate.inspect(appDataDirectory: root), isNull);
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
        await BusinessRestoreService(
          businessRepository,
        ).overwrite({'preserved_setting': 'local'});
        final before = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
        final chatService = ChatService();
        await chatService.init();
        addTearDown(chatService.close);
        final existing = await chatService.createConversation(title: 'Local');

        await expectLater(
          DataSync(
            businessRepository: businessRepository,
            chatService: chatService,
          ).restoreFromLocalFile(
            fixture,
            const WebDavConfig(includeChats: true, includeFiles: false),
          ),
          throwsA(isA<FormatException>()),
        );

        expect(
          await BusinessRestoreService(businessRepository).exportSettings(),
          before,
        );
        expect(chatService.getConversation(existing.id), isNotNull);
        expect(chatService.getConversation('fixture-conversation'), isNull);
      },
    );

    test(
      'validates business row identities before merging versioned chats',
      () async {
        final fixture = await _createSqliteBackupFixture(
          root: root,
          prefix: 'invalid_business_identity_before_chat_merge',
          settings: {
            'assistant_tags_v1': jsonEncode([
              {'name': 'Imported tag'},
            ]),
          },
          businessEntityRowIds: const {
            'assistant_tags_v1': <String>['row-a', 'row-b'],
          },
        );
        await BusinessRestoreService(
          businessRepository,
        ).overwrite({'preserved_setting': 'local'});
        final businessBefore = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
        final chatService = ChatService();
        await chatService.init();
        addTearDown(chatService.close);
        final existing = await chatService.createConversation(title: 'Local');

        await expectLater(
          DataSync(
            businessRepository: businessRepository,
            chatService: chatService,
          ).restoreFromLocalFile(
            fixture,
            const WebDavConfig(includeChats: true, includeFiles: false),
            mode: RestoreMode.merge,
          ),
          throwsA(isA<FormatException>()),
        );

        expect(
          await BusinessRestoreService(businessRepository).exportSettings(),
          businessBefore,
        );
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

        await BusinessRestoreService(
          businessRepository,
        ).overwrite({'preserved_setting': 'local'});
        final before = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
        final chatService = ChatService();
        await chatService.init();
        addTearDown(chatService.close);

        await expectLater(
          DataSync(
            businessRepository: businessRepository,
            chatService: chatService,
          ).restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: true, includeFiles: false),
          ),
          throwsA(isA<FormatException>()),
        );

        expect(
          await BusinessRestoreService(businessRepository).exportSettings(),
          before,
        );
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
      await BusinessRestoreService(
        businessRepository,
      ).overwrite({'preserved_setting': 'local'});
      final before = await BusinessRestoreService(
        businessRepository,
      ).exportSettings();

      await expectLater(
        DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
        ),
        throwsA(isA<FormatException>()),
      );

      expect(
        await BusinessRestoreService(businessRepository).exportSettings(),
        before,
      );
    });

    test(
      'rejects oversized settings before extraction or JSON parsing',
      () async {
        const maximumSettingsBytes = 1024 * 1024 * 1024;
        final settingsFile = File('${root.path}/oversized_settings.json');
        await settingsFile.writeAsString(
          jsonEncode({'preserved_setting': 'imported'}),
        );
        final zipFile = File('${root.path}/oversized_settings.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(settingsFile, 'settings.json');
        encoder.closeSync();
        await _overwriteCentralDirectoryUncompressedSize(
          zipFile,
          maximumSettingsBytes + 1,
        );
        final before = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();

        await expectLater(
          DataSync(
            businessRepository: businessRepository,
            chatService: ChatService(),
          ).restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: false, includeFiles: false),
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'settings_size',
            ),
          ),
        );

        expect(
          await BusinessRestoreService(businessRepository).exportSettings(),
          before,
        );
      },
    );

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
        await BusinessRestoreService(
          businessRepository,
        ).overwrite({'preserved_setting': 'local'});
        final before = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();

        await expectLater(
          DataSync(
            businessRepository: businessRepository,
            chatService: ChatService(),
          ).restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: false, includeFiles: false),
          ),
          throwsA(isA<FormatException>()),
        );

        expect(
          await BusinessRestoreService(businessRepository).exportSettings(),
          before,
        );
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
      await BusinessRestoreService(
        businessRepository,
      ).overwrite({'preserved_setting': 'local'});
      final before = await BusinessRestoreService(
        businessRepository,
      ).exportSettings();

      await expectLater(
        DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
        ),
        throwsA(isA<FormatException>()),
      );

      expect(
        await BusinessRestoreService(businessRepository).exportSettings(),
        before,
      );
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
      await BusinessRestoreService(
        businessRepository,
      ).overwrite({'preserved_setting': 'local'});
      final before = await BusinessRestoreService(
        businessRepository,
      ).exportSettings();

      await expectLater(
        DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        ),
        throwsA(isA<FormatException>()),
      );

      expect(
        await BusinessRestoreService(businessRepository).exportSettings(),
        before,
      );
    });

    test('merges SQLite snapshot without clobbering local data', () async {
      final fixture = await _createSqliteBackupFixture(
        root: root,
        prefix: 'merge_rejected',
        settings: const {'preserved_setting': 'imported'},
      );
      await BusinessRestoreService(
        businessRepository,
      ).overwrite({'preserved_setting': 'local'});
      final chatService = ChatService();
      await chatService.init();
      addTearDown(chatService.close);
      final existing = await chatService.createConversation(title: 'Local');

      final sync = DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      );
      await sync.restoreFromLocalFile(
        fixture,
        const WebDavConfig(includeChats: true, includeFiles: false),
        mode: RestoreMode.merge,
      );

      final restored = await BusinessRestoreService(
        businessRepository,
      ).exportSettings();
      expect(restored['preserved_setting'], 'local');
      expect(chatService.getConversation(existing.id), isNotNull);
      expect(chatService.getConversation('fixture-conversation'), isNotNull);
      expect(sync.lastMergeReport?.importedConversations, 1);
    });

    test(
      'merge settings rolls back every key when a later write fails',
      () async {
        await BusinessRestoreService(
          businessRepository,
        ).overwrite({'local_setting': 'keep'});
        final before = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
        await businessDatabase.customStatement('''
          CREATE TRIGGER fail_merged_setting
          BEFORE INSERT ON preference_rows
          WHEN NEW.key = 'incoming_b'
          BEGIN
            SELECT RAISE(ABORT, 'forced merge failure');
          END;
        ''');
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
          DataSync(
            businessRepository: businessRepository,
            chatService: ChatService(),
          ).restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: false, includeFiles: false),
            mode: RestoreMode.merge,
          ),
          throwsA(anything),
        );

        expect(
          await BusinessRestoreService(businessRepository).exportSettings(),
          before,
        );
      },
    );

    test(
      'legacy settings-only overwrite and merge restore selected files',
      () async {
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

        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        );
        await sync.restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: true),
          mode: RestoreMode.merge,
        );

        expect(await existingFile.exists(), isTrue);
        expect(await File('${fontsDir.path}/custom.ttf').exists(), isTrue);
        expect(
          await Directory('${root.path}/.kelivo_restore').exists(),
          isFalse,
        );

        await sync.restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: true),
          mode: RestoreMode.overwrite,
        );

        expect(await existingFile.exists(), isFalse);
        expect(await File('${fontsDir.path}/custom.ttf').exists(), isTrue);
        expect(
          await Directory('${root.path}/.kelivo_restore').exists(),
          isFalse,
        );
      },
    );

    test(
      'merge restore imports assistant memories and mcp servers without clobbering local entries',
      () async {
        await BusinessRestoreService(businessRepository).overwrite({
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

        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        );
        await sync.restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
          mode: RestoreMode.merge,
        );

        final restored = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
        final memories =
            jsonDecode(restored['assistant_memories_v1'] as String) as List;
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

        final servers =
            jsonDecode(restored['mcp_servers_v1'] as String) as List;
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
        await BusinessRestoreService(businessRepository).overwrite({
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

        await DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
          mode: RestoreMode.merge,
        );

        final restored = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
        expect(
          restored['pinned_models_v1'],
          containsAllInOrder(const ['local-model', 'remote-model']),
        );
      },
    );

    test('validates all merged settings before writing any live key', () async {
      final existingAssistants = jsonEncode([
        {'id': 'local', 'name': 'Local'},
      ]);
      await BusinessRestoreService(
        businessRepository,
      ).overwrite({'assistants_v1': existingAssistants});
      final before = await BusinessRestoreService(
        businessRepository,
      ).exportSettings();

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

      final sync = DataSync(
        businessRepository: businessRepository,
        chatService: ChatService(),
      );

      await expectLater(
        sync.restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
          mode: RestoreMode.merge,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        await BusinessRestoreService(businessRepository).exportSettings(),
        before,
      );
    });

    test(
      'rejects malformed structured settings before overwrite writes',
      () async {
        await BusinessRestoreService(
          businessRepository,
        ).overwrite({'preserved_setting': 'old'});
        final before = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
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

        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        );

        await expectLater(
          sync.restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: false, includeFiles: false),
          ),
          throwsA(isA<FormatException>()),
        );
        expect(
          await BusinessRestoreService(businessRepository).exportSettings(),
          before,
        );
      },
    );

    test('rejects malformed first-time merged structured settings', () async {
      final before = await BusinessRestoreService(
        businessRepository,
      ).exportSettings();
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

      final sync = DataSync(
        businessRepository: businessRepository,
        chatService: ChatService(),
      );

      await expectLater(
        sync.restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
          mode: RestoreMode.merge,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        await BusinessRestoreService(businessRepository).exportSettings(),
        before,
      );
    });

    test('rejects non-object entries in structured setting lists', () async {
      await BusinessRestoreService(
        businessRepository,
      ).overwrite({'preserved_setting': 'old'});
      final before = await BusinessRestoreService(
        businessRepository,
      ).exportSettings();
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
        DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        await BusinessRestoreService(businessRepository).exportSettings(),
        before,
      );
    });

    test('rejects non-object provider configuration values', () async {
      final before = await BusinessRestoreService(
        businessRepository,
      ).exportSettings();
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
        DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: false, includeFiles: false),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        await BusinessRestoreService(businessRepository).exportSettings(),
        before,
      );
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
        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: chatService,
        );

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

        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        );

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

        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: _FailingArtifactChatService(),
        );

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

        final businessPreferences = BusinessPreferences(businessRepository);
        final provider = BackupProvider(
          chatService: _FailingRestoreChatService(),
          businessRepository: businessRepository,
          businessPreferences: businessPreferences,
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
        await expectLater(
          businessPreferences.setString('after_failed_restore', 'writable'),
          completes,
        );
      },
    );

    test('rejects malformed chat payload before clearing live chats', () async {
      await BusinessRestoreService(
        businessRepository,
      ).overwrite({'preserved_setting': 'old'});
      final before = await BusinessRestoreService(
        businessRepository,
      ).exportSettings();
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
      final sync = DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      );

      await expectLater(
        sync.restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(chatService.cleared, isFalse);
      expect(
        await BusinessRestoreService(businessRepository).exportSettings(),
        before,
      );
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
        DataSync(
          businessRepository: businessRepository,
          chatService: chatService,
        ).restoreFromLocalFile(
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
        DataSync(
          businessRepository: businessRepository,
          chatService: chatService,
        ).restoreFromLocalFile(
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
        await BusinessRestoreService(
          businessRepository,
        ).overwrite({'preserved_setting': 'old'});
        final before = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
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

        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        );

        await expectLater(
          sync.restoreFromLocalFile(
            zipFile,
            const WebDavConfig(includeChats: true, includeFiles: false),
          ),
          throwsA(isA<FormatException>()),
        );
        expect(
          await BusinessRestoreService(businessRepository).exportSettings(),
          before,
        );
      },
    );

    test(
      'restores a legacy settings-only backup without clearing chats',
      () async {
        await BusinessRestoreService(
          businessRepository,
        ).overwrite({'restored_setting': 'old'});
        final settingsFile = File('${root.path}/settings_only.json');
        await settingsFile.writeAsString(
          jsonEncode({
            'restored_setting': 'new',
            'global_proxy_password_v1': 'legacy-proxy-secret',
            'instruction_injections_v1': jsonEncode(const <Object>[]),
            'provider_configs_v1': jsonEncode({
              'openai': {
                'id': 'openai',
                'apiKey': 'legacy-api-secret',
                'modelOverrides': {
                  'legacy-embedding': {
                    'type': 'embedding',
                    'abilities': ['vision'],
                    'output': ['text'],
                    'builtInTools': ['search'],
                    'built_in_tools': ['search'],
                    'tools': ['search'],
                    'dimensions': 1536,
                  },
                },
              },
            }),
          }),
        );

        final zipFile = File('${root.path}/settings_only_restore.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(settingsFile, 'settings.json');
        encoder.closeSync();

        final chatService = _RecordingClearChatService();
        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: chatService,
        );

        await sync.restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        );

        expect(chatService.cleared, isFalse);
        final restored = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
        expect(restored['restored_setting'], 'new');
        expect(restored['global_proxy_password_v1'], 'legacy-proxy-secret');
        final providers =
            jsonDecode(restored['provider_configs_v1'] as String) as Map;
        final provider = providers['openai'] as Map;
        expect(provider['apiKey'], 'legacy-api-secret');
        final embedding =
            (provider['modelOverrides'] as Map)['legacy-embedding'] as Map;
        expect(embedding['dimensions'], 1536);
        for (final field in const [
          'abilities',
          'output',
          'builtInTools',
          'built_in_tools',
          'tools',
        ]) {
          expect(embedding, isNot(contains(field)), reason: field);
        }
        expect(
          jsonDecode(
            restored['instruction_injections_active_ids_by_assistant_v1']!
                as String,
          ),
          {'__global__': <Object>[]},
        );
        expect(
          await RestoreStartupGate.inspect(appDataDirectory: root),
          isNull,
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
      final sync = DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      );

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

      await DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      ).restoreFromLocalFile(
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

        await DataSync(
          businessRepository: businessRepository,
          chatService: chatService,
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        );

        expect(chatService.replaced, isTrue);
      },
    );

    test('sanitizes an orphan-message candidate into an empty chat restore '
        'while settings still apply', () async {
      await BusinessRestoreService(
        businessRepository,
      ).overwrite({'preserved_setting': 'old'});
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

      final sync = DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      );

      // 1.1.17 silently tolerated messages whose conversation is missing:
      // they were simply invisible. The sanitizer now prunes the orphan and
      // the overwrite restore proceeds with an empty chat payload.
      await sync.restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: true, includeFiles: false),
      );

      final after = await BusinessRestoreService(
        businessRepository,
      ).exportSettings();
      expect(after['preserved_setting'], 'new');
      expect(chatService.getConversation(existingConversation.id), isNull);
    });

    test('prunes a dangling declared message and restores the conversation '
        'empty', () async {
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

      await DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      ).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: true, includeFiles: false),
      );

      expect(chatService.replaced, isTrue);
      final conversation = chatService.replacedConversations!.single;
      expect(conversation.id, 'conversation');
      expect(conversation.messageIds, isEmpty);
      expect(chatService.replacedMessages, isEmpty);
    });

    test(
      'restores messages in the order the conversation declares them',
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

        // 1.1.17 rendered conversations by messageIds, so that list is the
        // authoritative order; the messages array is realigned to it.
        await DataSync(
          businessRepository: businessRepository,
          chatService: chatService,
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        );

        expect(chatService.replaced, isTrue);
        expect(chatService.replacedConversations!.single.messageIds, [
          'second-message',
          'first-message',
        ]);
        expect(chatService.replacedMessages!.map((m) => m.id).toList(), [
          'second-message',
          'first-message',
        ]);
      },
    );

    test(
      'remaps a legacy raw truncate index to logical message slots',
      () async {
        final chatsFile = File('${root.path}/legacy_truncate_index.json');
        await chatsFile.writeAsString(
          jsonEncode({
            'conversations': [
              Conversation(
                id: 'conversation',
                title: 'Conversation',
                messageIds: const ['question', 'answer-v0', 'answer-v1'],
                truncateIndex: 3,
              ).toJson(),
              Conversation(
                id: 'missing-before-kept',
                title: 'Missing before kept',
                messageIds: const ['missing', 'kept'],
                truncateIndex: 1,
              ).toJson(),
              Conversation(
                id: 'duplicate-before-truncate',
                title: 'Duplicate before truncate',
                messageIds: const ['truncate-a', 'truncate-a', 'truncate-b'],
                truncateIndex: 3,
              ).toJson(),
              Conversation(
                id: 'shared-owner',
                title: 'Shared owner',
                messageIds: const ['shared'],
              ).toJson(),
              Conversation(
                id: 'cross-reuse',
                title: 'Cross reuse',
                messageIds: const ['shared', 'cross-h', 'later-g'],
                truncateIndex: 1,
              ).toJson(),
            ],
            'messages': [
              ChatMessage(
                id: 'question',
                role: 'user',
                content: 'question',
                conversationId: 'conversation',
              ).toJson(),
              ChatMessage(
                id: 'answer-v0',
                role: 'assistant',
                content: 'answer v0',
                conversationId: 'conversation',
                groupId: 'answer',
                version: 0,
              ).toJson(),
              ChatMessage(
                id: 'answer-v1',
                role: 'assistant',
                content: 'answer v1',
                conversationId: 'conversation',
                groupId: 'answer',
                version: 1,
              ).toJson(),
              ChatMessage(
                id: 'kept',
                role: 'user',
                content: 'kept question',
                conversationId: 'missing-before-kept',
              ).toJson(),
              ChatMessage(
                id: 'truncate-a',
                role: 'user',
                content: 'truncate a',
                conversationId: 'duplicate-before-truncate',
              ).toJson(),
              ChatMessage(
                id: 'truncate-b',
                role: 'assistant',
                content: 'truncate b',
                conversationId: 'duplicate-before-truncate',
              ).toJson(),
              ChatMessage(
                id: 'shared',
                role: 'user',
                content: 'shared',
                conversationId: 'shared-owner',
                groupId: 'g',
              ).toJson(),
              ChatMessage(
                id: 'cross-h',
                role: 'user',
                content: 'cross h',
                conversationId: 'cross-reuse',
                groupId: 'h',
              ).toJson(),
              ChatMessage(
                id: 'later-g',
                role: 'assistant',
                content: 'later g',
                conversationId: 'cross-reuse',
                groupId: 'g',
              ).toJson(),
            ],
          }),
        );
        final zipFile = File('${root.path}/legacy_truncate_index.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(validSettingsFile, 'settings.json');
        encoder.addFileSync(chatsFile, 'chats.json');
        encoder.closeSync();
        final chatService = ChatService();
        await chatService.init();
        addTearDown(chatService.close);

        await DataSync(
          businessRepository: businessRepository,
          chatService: chatService,
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        );

        final restored = chatService.getConversation('conversation')!;
        expect(restored.truncateIndex, 2);
        expect(
          await chatService.loadSelectedContextMessages(
            restored.id,
            truncateIndex: restored.truncateIndex,
            limit: 10,
          ),
          isEmpty,
        );
        final missingBeforeKept = chatService.getConversation(
          'missing-before-kept',
        )!;
        expect(missingBeforeKept.truncateIndex, 1);
        expect(
          await chatService.loadSelectedContextMessages(
            missingBeforeKept.id,
            truncateIndex: missingBeforeKept.truncateIndex,
            limit: 10,
          ),
          isEmpty,
        );
        final duplicateBeforeTruncate = chatService.getConversation(
          'duplicate-before-truncate',
        )!;
        expect(duplicateBeforeTruncate.truncateIndex, 2);
        expect(
          await chatService.loadSelectedContextMessages(
            duplicateBeforeTruncate.id,
            truncateIndex: duplicateBeforeTruncate.truncateIndex,
            limit: 10,
          ),
          isEmpty,
        );
        final crossReuse = chatService.getConversation('cross-reuse')!;
        expect(crossReuse.truncateIndex, 0);
        expect(
          (await chatService.loadSelectedContextMessages(
            crossReuse.id,
            truncateIndex: crossReuse.truncateIndex,
            limit: 10,
          )).map((message) => message.id),
          ['cross-h', 'later-g'],
        );
      },
    );

    test(
      'remaps a legacy version ordinal to the selected message version',
      () async {
        final chatsFile = File('${root.path}/legacy_version_selection.json');
        await chatsFile.writeAsString(
          jsonEncode({
            'conversations': [
              Conversation(
                id: 'conversation',
                title: 'Conversation',
                messageIds: const ['answer-v1', 'answer-v2'],
                versionSelections: const {'answer': 1},
              ).toJson(),
              Conversation(
                id: 'duplicate-reference',
                title: 'Duplicate reference',
                messageIds: const ['duplicate-a', 'duplicate-a', 'duplicate-b'],
                versionSelections: const {'duplicate-answer': 1},
              ).toJson(),
            ],
            'messages': [
              ChatMessage(
                id: 'answer-v1',
                role: 'assistant',
                content: 'answer v1',
                conversationId: 'conversation',
                groupId: 'answer',
                version: 1,
              ).toJson(),
              ChatMessage(
                id: 'answer-v2',
                role: 'assistant',
                content: 'answer v2',
                conversationId: 'conversation',
                groupId: 'answer',
                version: 2,
              ).toJson(),
              ChatMessage(
                id: 'duplicate-a',
                role: 'assistant',
                content: 'duplicate answer a',
                conversationId: 'duplicate-reference',
                groupId: 'duplicate-answer',
                version: 1,
              ).toJson(),
              ChatMessage(
                id: 'duplicate-b',
                role: 'assistant',
                content: 'duplicate answer b',
                conversationId: 'duplicate-reference',
                groupId: 'duplicate-answer',
                version: 2,
              ).toJson(),
            ],
          }),
        );
        final zipFile = File('${root.path}/legacy_version_selection.zip');
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path);
        encoder.addFileSync(validSettingsFile, 'settings.json');
        encoder.addFileSync(chatsFile, 'chats.json');
        encoder.closeSync();
        final chatService = ChatService();
        await chatService.init();
        addTearDown(chatService.close);

        await DataSync(
          businessRepository: businessRepository,
          chatService: chatService,
        ).restoreFromLocalFile(
          zipFile,
          const WebDavConfig(includeChats: true, includeFiles: false),
        );

        final restored = chatService.getConversation('conversation')!;
        expect(restored.versionSelections, const {'answer': 2});
        final timeline = await chatService.loadActiveTimelineMessages(
          restored.id,
        );
        expect(timeline.single.id, 'answer-v2');
        expect(timeline.single.content, 'answer v2');
        final duplicateReference = chatService.getConversation(
          'duplicate-reference',
        )!;
        expect(duplicateReference.versionSelections, const {
          'duplicate-answer': 1,
        });
        final duplicateTimeline = await chatService.loadActiveTimelineMessages(
          duplicateReference.id,
        );
        expect(duplicateTimeline.single.id, 'duplicate-a');
      },
    );

    test('reassigns duplicate (groupId, version) pairs a 1.1.17 runtime '
        'tolerated instead of rejecting the backup', () async {
      final chatsFile = File('${root.path}/duplicate_group_versions.json');
      await chatsFile.writeAsString(
        jsonEncode({
          'conversations': [
            Conversation(
              id: 'conversation',
              title: 'Conversation',
              messageIds: const [
                'grouped-a',
                'grouped-b',
                'empty-group-a',
                'empty-group-b',
              ],
            ).toJson(),
          ],
          'messages': [
            ChatMessage(
              id: 'grouped-a',
              role: 'assistant',
              content: 'first take',
              conversationId: 'conversation',
              groupId: 'group',
              version: 0,
            ).toJson(),
            ChatMessage(
              id: 'grouped-b',
              role: 'assistant',
              content: 'second take',
              conversationId: 'conversation',
              groupId: 'group',
              version: 0,
            ).toJson(),
            ChatMessage(
              id: 'empty-group-a',
              role: 'assistant',
              content: 'empty group first',
              conversationId: 'conversation',
              groupId: '',
              version: 0,
            ).toJson(),
            ChatMessage(
              id: 'empty-group-b',
              role: 'assistant',
              content: 'empty group second',
              conversationId: 'conversation',
              groupId: '',
              version: 0,
            ).toJson(),
          ],
        }),
      );
      final zipFile = File('${root.path}/duplicate_group_versions.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFileSync(validSettingsFile, 'settings.json');
      encoder.addFileSync(chatsFile, 'chats.json');
      encoder.closeSync();
      final chatService = _RecordingClearChatService();

      // message_rows has unique(conversationId, groupId, version) and the
      // restore writes with INSERT OR REPLACE, so without version repair a
      // duplicate pair silently swallows the earlier row and the overwrite
      // candidate validation rejects the whole archive.
      await DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      ).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: true, includeFiles: false),
      );

      expect(chatService.replaced, isTrue);
      final messages = chatService.replacedMessages!;
      expect(messages.map((m) => m.id).toList(), [
        'grouped-a',
        'grouped-b',
        'empty-group-a',
        'empty-group-b',
      ]);
      final groupedVersions = {
        for (final m in messages.where((m) => m.groupId == 'group'))
          m.id: m.version,
      };
      expect(groupedVersions['grouped-a'], 0);
      expect(groupedVersions['grouped-b'], 1);
      final emptyGroupVersions = {
        for (final m in messages.where((m) => m.groupId == '')) m.id: m.version,
      };
      expect(emptyGroupVersions['empty-group-a'], 0);
      expect(emptyGroupVersions['empty-group-b'], 1);
    });

    test('deduplicates MCP server relations in a candidate', () async {
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

      await DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      ).restoreFromLocalFile(
        zipFile,
        const WebDavConfig(includeChats: true, includeFiles: false),
      );

      expect(chatService.replaced, isTrue);
      expect(chatService.replacedConversations!.single.mcpServerIds, [
        'server',
      ]);
    });

    test(
      'WebDAV settings-only restore ignores untrusted display names',
      () async {
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

        final sync = DataSync(
          businessRepository: businessRepository,
          chatService: ChatService(),
        );
        final tmpDir = Directory('${root.path}/tmp');
        final relativeSentinel = File('${root.path}/webdav_relative.zip');
        final absoluteSentinel = File('${root.path}/webdav_absolute.zip');
        await relativeSentinel.writeAsString('keep relative');
        await absoluteSentinel.writeAsString('keep absolute');
        final remoteNames = <String>[
          '../webdav_relative.zip',
          absoluteSentinel.path,
        ];

        for (var i = 0; i < remoteNames.length; i++) {
          final item = BackupFileItem(
            href: Uri.parse(
              'http://127.0.0.1:${server.port}/restore_source_$i.zip',
            ),
            displayName: remoteNames[i],
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
        }

        expect(await relativeSentinel.readAsString(), 'keep relative');
        expect(await absoluteSentinel.readAsString(), 'keep absolute');
        expect(await tmpDir.list().toList(), isEmpty);
      },
    );
  });

  group('kelivo-file portable attachments', () {
    test('resolve after root change without rewriting persisted URIs', () async {
      final rootA = await Directory.systemTemp.createTemp(
        'kelivo_file_root_a_',
      );
      final rootB = await Directory.systemTemp.createTemp(
        'kelivo_file_root_b_',
      );
      addTearDown(() async {
        SandboxPathResolver.debugSetDirs(docsDir: null, supportDir: null);
        if (await rootA.exists()) await rootA.delete(recursive: true);
        if (await rootB.exists()) await rootB.delete(recursive: true);
      });

      SandboxPathResolver.debugSetDirs(docsDir: rootA.path);
      final dbFile = File('${rootA.path}/kelivo.db');
      final repository = ChatDatabaseRepository.open(file: dbFile);
      await repository.ensureReady();

      final uploadA = Directory('${rootA.path}/upload')
        ..createSync(recursive: true);
      final bytes = const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      File('${uploadA.path}/pic.png').writeAsBytesSync(bytes);

      const uri = 'kelivo-file:///upload/pic.png';
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'c-portable',
            title: 'Portable',
            messageIds: const ['m-portable'],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: 'm-portable',
              conversationId: 'c-portable',
              role: 'user',
              content: 'portable',
              parts: const [ImagePart(uri: uri)],
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      await repository.close();

      // Simulate backup restore onto a different container root: copy DB+file,
      // switch docsDir, and do NOT rewrite message URIs.
      final dbB = File('${rootB.path}/kelivo.db');
      await dbFile.copy(dbB.path);
      final uploadB = Directory('${rootB.path}/upload')
        ..createSync(recursive: true);
      File('${uploadB.path}/pic.png').writeAsBytesSync(bytes);

      SandboxPathResolver.debugSetDirs(docsDir: rootB.path);
      final restoredRepo = ChatDatabaseRepository.open(file: dbB);
      addTearDown(restoredRepo.close);
      await restoredRepo.ensureReady();

      final before = (await restoredRepo.getMessagesRange(
        'c-portable',
        start: 0,
        limit: 1,
      )).single;
      expect(before.parts.whereType<ImagePart>().single.uri, uri);

      final resolved = SandboxPathResolver.fix(uri);
      expect(resolved, '${rootB.path}/upload/pic.png');
      expect(File(resolved).existsSync(), isTrue);

      // Path-migration pass with the production rewriteUri must leave URI intact.
      final result = await restoredRepo.migrateSandboxPaths(
        targetVersion: 1,
        targetRoot: rootB.path,
        rewriteUri: (value) => KelivoFileUri.isKelivoFileUri(value)
            ? value
            : SandboxPathResolver.fix(value),
      );
      expect(result.ran, isTrue);
      final after = (await restoredRepo.getMessagesRange(
        'c-portable',
        start: 0,
        limit: 1,
      )).single;
      expect(after.parts.whereType<ImagePart>().single.uri, uri);
      expect(after.parts.whereType<ImagePart>().single.unavailable, isFalse);
    });
  });
}
