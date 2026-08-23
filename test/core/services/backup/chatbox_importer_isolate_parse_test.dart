import 'dart:async';
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
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';
import 'package:Kelivo/core/services/backup/chatbox_importer.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';

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

Map<String, dynamic> _largeChatboxFixture({
  int sessions = 240,
  int messagesPerSession = 10,
}) {
  final sessionsList = <Map<String, dynamic>>[
    for (var i = 0; i < sessions; i++)
      <String, dynamic>{'id': 'assistant-$i', 'name': 'Session $i'},
  ];
  return <String, dynamic>{
    '__exported_at': '2026-07-18T00:00:00.000Z',
    'settings': <String, dynamic>{
      'providers': <String, dynamic>{
        'openai': <String, dynamic>{
          'apiKey': 'chatbox-secret',
          'apiHost': 'https://api.example.test',
          'apiPath': '/v1/chat/completions',
          'models': <Map<String, dynamic>>[
            <String, dynamic>{'modelId': 'gpt-test'},
          ],
        },
      },
    },
    'chat-sessions-list': sessionsList,
    for (var i = 0; i < sessions; i++)
      'session:assistant-$i': <String, dynamic>{
        'settings': <String, dynamic>{
          'provider': 'openai',
          'modelId': 'gpt-test',
        },
        'messages': <Map<String, dynamic>>[
          for (var j = 0; j < messagesPerSession; j++)
            <String, dynamic>{
              'id': 'message-$i-$j',
              'role': j == 0 ? 'system' : (j.isEven ? 'user' : 'assistant'),
              'content': 'payload-$i-$j-${'x' * 64}',
              'timestamp': 1784332800000 + i * 100 + j,
            },
        ],
      },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late AppDatabase database;
  late BusinessRepository businessRepository;
  late ChatService chatService;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo_chatbox_isolate_');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
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
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'cancel during Chatbox ZIP read stays BackupCancelledException',
    () async {
      final zip = File('${root.path}/chatbox.zip');
      await zip.writeAsBytes(const [0x50, 0x4b, 0x03, 0x04], flush: true);
      final token = BackupCancelToken()..cancel();
      addTearDown(token.dispose);

      await expectLater(
        ChatboxImporter.importFromChatbox(
          file: zip,
          mode: RestoreMode.merge,
          businessRepository: businessRepository,
          chatService: chatService,
          cancelToken: token,
        ),
        throwsA(isA<BackupCancelledException>()),
      );
    },
  );

  test('Chatbox parse progress is monotonic and does not regress phases', () async {
    final backup = await File('${root.path}/chatbox.json').writeAsString(
      jsonEncode(_largeChatboxFixture(sessions: 3, messagesPerSession: 4)),
      flush: true,
    );
    final events = <BackupProgress>[];

    await ChatboxImporter.importFromChatbox(
      file: backup,
      mode: RestoreMode.overwrite,
      businessRepository: businessRepository,
      chatService: chatService,
      onProgress: events.add,
    );

    _expectMonotonicProgress(events);
    expect(
      events.map((event) => event.phase),
      containsAllInOrder([
        BackupPhase.importingSessions,
        BackupPhase.importingMessages,
      ]),
    );
  });

  test(
    'cancels Chatbox session parse from the calling isolate while work continues',
    () async {
      final backup = await File('${root.path}/chatbox.json').writeAsString(
        jsonEncode(_largeChatboxFixture()),
        flush: true,
      );
      final token = BackupCancelToken();
      addTearDown(token.dispose);
      final phases = <BackupPhase>[];

      await expectLater(
        ChatboxImporter.importFromChatbox(
          file: backup,
          mode: RestoreMode.overwrite,
          businessRepository: businessRepository,
          chatService: chatService,
          cancelToken: token,
          onProgress: (progress) {
            phases.add(progress.phase);
            if (progress.phase == BackupPhase.importingMessages &&
                progress.processed == 1) {
              scheduleMicrotask(token.cancel);
            }
          },
        ),
        throwsA(isA<BackupCancelledException>()),
      );

      expect(phases, contains(BackupPhase.importingSessions));
      expect(phases, contains(BackupPhase.importingMessages));
      expect(phases, isNot(contains(BackupPhase.committing)));
      expect(chatService.getAllConversations(), isEmpty);
    },
  );
}

void _expectMonotonicProgress(List<BackupProgress> events) {
  expect(events, isNotEmpty);
  final finished = <BackupPhase>{};
  BackupPhase? current;
  var processed = -1;
  for (final event in events) {
    if (event.phase != current) {
      if (current != null) finished.add(current);
      expect(
        finished.contains(event.phase),
        isFalse,
        reason: 'phase regression to ${event.phase} after $current',
      );
      current = event.phase;
      processed = event.processed;
      continue;
    }
    expect(
      event.processed,
      greaterThanOrEqualTo(processed),
      reason: '${event.phase} processed went backwards',
    );
    processed = event.processed;
  }
}
