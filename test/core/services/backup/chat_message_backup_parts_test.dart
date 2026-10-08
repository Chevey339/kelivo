import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/migration/legacy_message_content_decoder.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:archive/archive_io.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late AppDatabase database;
  late BusinessRepository businessRepository;
  late ChatService chatService;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo_backup_parts_');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    SandboxPathResolver.debugSetDirs(docsDir: root.path, supportDir: root.path);
    SharedPreferences.setMockInitialValues({});
    final databaseFile = File('${root.path}/kelivo.db');
    database = AppDatabase.open(file: databaseFile);
    businessRepository = BusinessRepository(database);
    chatService = ChatService(
      existingRepository: ChatDatabaseRepository(
        database,
        databaseFile: databaseFile,
      ),
    );
  });

  tearDown(() async {
    await chatService.close();
    await database.close();
    SandboxPathResolver.debugSetDirs(docsDir: null, supportDir: null);
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> writeLegacyZip({
    required Map<String, dynamic> chats,
    Map<String, List<int>> assets = const {},
  }) async {
    final settings = File('${root.path}/settings.json');
    await settings.writeAsString('{}');
    final chatsFile = File('${root.path}/chats.json');
    await chatsFile.writeAsString(jsonEncode(chats));
    final zipFile = File('${root.path}/legacy_parts.zip');
    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);
    encoder.addFileSync(settings, 'settings.json');
    encoder.addFileSync(chatsFile, 'chats.json');
    for (final entry in assets.entries) {
      final assetFile = File(
        '${root.path}/asset_${entry.key.replaceAll('/', '_')}',
      );
      await assetFile.writeAsBytes(entry.value, flush: true);
      encoder.addFileSync(assetFile, entry.key);
    }
    encoder.closeSync();
    return zipFile;
  }

  test('legacy chats.json content markers decode at import boundary', () async {
    final zip = await writeLegacyZip(
      chats: {
        'conversations': [
          Conversation(
            id: 'c1',
            title: 'Legacy',
            messageIds: const ['m1'],
          ).toJson(),
        ],
        'messages': [
          {
            'id': 'm1',
            'role': 'user',
            'content': 'caption\n[image:https://example.com/a.png]',
            'timestamp': DateTime.utc(2026, 1, 1).toIso8601String(),
            'conversationId': 'c1',
          },
        ],
      },
    );

    final sync = DataSync(
      businessRepository: businessRepository,
      chatService: chatService,
    );
    await sync.restoreFromLocalFile(
      zip,
      const WebDavConfig(
        scope: BackupScope(
          excluded: {
            BackupCategory.files,
            BackupCategory.skills,
            BackupCategory.workspaces,
          },
        ),
      ),
      mode: RestoreMode.overwrite,
    );

    final messages = await chatService.loadMessages('c1');
    expect(messages, hasLength(1));
    final message = messages.single;
    expect(message.content, 'caption');
    expect(message.content.contains('[image:'), isFalse);
    expect(message.parts.whereType<TextPart>().single.text, 'caption');
    expect(
      message.parts.whereType<ImagePart>().single.uri,
      'https://example.com/a.png',
    );
  });

  test(
    'legacy chats.json with dirty numeric fields and empty role restores',
    () async {
      final dirtyConversation =
          Conversation(
              id: 'c-dirty',
              title: 'Dirty',
              messageIds: const ['m1'],
            ).toJson()
            ..['truncateIndex'] = -7
            ..['lastSummarizedMessageCount'] = -3
            ..['lastMemoryExtractedOrder'] = -9;
      final zip = await writeLegacyZip(
        chats: {
          'conversations': [dirtyConversation],
          'messages': [
            {
              'id': 'm1',
              'role': '',
              'content': 'kept despite dirty fields',
              'timestamp': DateTime.utc(2026, 1, 1).toIso8601String(),
              'conversationId': 'c-dirty',
              'durationMs': -55696,
              'totalTokens': -12,
              'version': -1,
            },
          ],
        },
      );

      final sync = DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      );
      await sync.restoreFromLocalFile(
        zip,
        const WebDavConfig(
          scope: BackupScope(
            excluded: {
              BackupCategory.files,
              BackupCategory.skills,
              BackupCategory.workspaces,
            },
          ),
        ),
        mode: RestoreMode.overwrite,
      );

      final messages = await chatService.loadMessages('c-dirty');
      expect(messages, hasLength(1));
      final message = messages.single;
      expect(message.role, 'user');
      expect(message.content, 'kept despite dirty fields');
      expect(message.durationMs, isNull);
      expect(message.totalTokens, isNull);
      expect(message.version, 0);
    },
  );

  test(
    'new chats.json parts round-trip without reintroducing markers',
    () async {
      final original = ChatMessage(
        id: 'm1',
        role: 'user',
        conversationId: 'c1',
        parts: const [
          TextPart('hi'),
          ImagePart(uri: 'https://example.com/b.png', mime: 'image/png'),
          FilePart(
            uri: 'https://example.com/c.pdf',
            name: 'c.pdf',
            mime: 'application/pdf',
          ),
        ],
      );
      final zip = await writeLegacyZip(
        chats: {
          'conversations': [
            Conversation(
              id: 'c1',
              title: 'Parts',
              messageIds: const ['m1'],
            ).toJson(),
          ],
          'messages': [original.toJson()],
        },
      );

      final sync = DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      );
      await sync.restoreFromLocalFile(
        zip,
        const WebDavConfig(
          scope: BackupScope(
            excluded: {
              BackupCategory.files,
              BackupCategory.skills,
              BackupCategory.workspaces,
            },
          ),
        ),
        mode: RestoreMode.overwrite,
      );

      final restored = (await chatService.loadMessages('c1')).single;
      expect(restored.content, 'hi');
      expect(restored.parts, hasLength(3));
      expect(restored.parts[0], isA<TextPart>());
      expect(restored.parts[1], isA<ImagePart>());
      expect((restored.parts[1] as ImagePart).uri, 'https://example.com/b.png');
      expect(restored.parts[2], isA<FilePart>());
      expect((restored.parts[2] as FilePart).name, 'c.pdf');
      for (final part in restored.parts) {
        expect(part.encodePayload().contains('[image:'), isFalse);
        expect(part.encodePayload().contains('[file:'), isFalse);
      }
    },
  );

  test(
    'new chats.json with literal [image:] text in parts is not promoted',
    () async {
      const literal =
          'mention\n[image:https://example.com/literal.png]\nas text';
      final original = ChatMessage(
        id: 'm1',
        role: 'user',
        conversationId: 'c1',
        parts: const [TextPart(literal)],
      );
      final zip = await writeLegacyZip(
        chats: {
          'conversations': [
            Conversation(
              id: 'c1',
              title: 'Literal',
              messageIds: const ['m1'],
            ).toJson(),
          ],
          'messages': [original.toJson()],
        },
      );

      final sync = DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      );
      await sync.restoreFromLocalFile(
        zip,
        const WebDavConfig(
          scope: BackupScope(
            excluded: {
              BackupCategory.files,
              BackupCategory.skills,
              BackupCategory.workspaces,
            },
          ),
        ),
        mode: RestoreMode.overwrite,
      );

      final restored = (await chatService.loadMessages('c1')).single;
      expect(restored.parts.whereType<ImagePart>(), isEmpty);
      expect(restored.parts.whereType<TextPart>().single.text, literal);
      expect(restored.content, literal);
    },
  );

  test('recomputeAttachmentAvailability flips local missing to available', () {
    final missing = ImagePart(uri: '${root.path}/nope.png', unavailable: true);
    final remote = ImagePart(
      uri: 'https://example.com/a.png',
      unavailable: false,
    );
    final presentPath = '${root.path}/exists.png';
    File(presentPath).writeAsBytesSync(const [1, 2, 3]);
    final present = ImagePart(uri: presentPath, unavailable: true);

    final next = recomputeAttachmentAvailability([
      missing,
      remote,
      present,
    ], fileExists: (path) => path == presentPath);
    expect((next[0] as ImagePart).unavailable, isTrue);
    expect((next[1] as ImagePart).unavailable, isFalse);
    expect((next[2] as ImagePart).unavailable, isFalse);
  });

  test(
    'local attachment becomes available after chats+files restore',
    () async {
      final uploadRel = 'upload/restored.png';
      final restoredPath = '${root.path}/$uploadRel';
      final png = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      final zip = await writeLegacyZip(
        chats: {
          'conversations': [
            Conversation(
              id: 'c1',
              title: 'Files',
              messageIds: const ['m1'],
            ).toJson(),
          ],
          'messages': [
            {
              'id': 'm1',
              'role': 'user',
              'content': 'caption\n[image:$restoredPath]',
              'timestamp': DateTime.utc(2026, 1, 1).toIso8601String(),
              'conversationId': 'c1',
            },
          ],
        },
        assets: {uploadRel: png},
      );

      // Confirm decode-without-file would mark unavailable.
      final before = await decodeLegacyContent(
        'caption\n[image:$restoredPath]',
        fileExists: (_) => false,
      );
      expect((before.parts.whereType<ImagePart>().single).unavailable, isTrue);

      final sync = DataSync(
        businessRepository: businessRepository,
        chatService: chatService,
      );
      await sync.restoreFromLocalFile(
        zip,
        const WebDavConfig(scope: BackupScope(excluded: {})),
        mode: RestoreMode.overwrite,
      );

      expect(await File(restoredPath).exists(), isTrue);
      final restored = (await chatService.loadMessages('c1')).single;
      final image = restored.parts.whereType<ImagePart>().single;
      expect(image.uri, 'kelivo-file:///upload/restored.png');
      expect(image.unavailable, isFalse);
    },
  );
}
