import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';
import 'package:Kelivo/core/services/backup/cherry_importer.dart';
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

Map<String, dynamic> _largeCherryRoot({
  int topics = 180,
  int messagesPerTopic = 8,
}) {
  final topicMeta = <Map<String, dynamic>>[
    for (var i = 0; i < topics; i++)
      <String, dynamic>{
        'id': 'topic-$i',
        'assistantId': 'assistant-1',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:01.000Z',
        'name': 'Topic $i',
        'messages': <dynamic>[],
      },
  ];
  final topicsWithMessages = <Map<String, dynamic>>[
    for (var i = 0; i < topics; i++)
      <String, dynamic>{
        'id': 'topic-$i',
        'messages': <Map<String, dynamic>>[
          for (var j = 0; j < messagesPerTopic; j++)
            <String, dynamic>{
              'id': 'msg-$i-$j',
              'role': 'user',
              'topicId': 'topic-$i',
              'assistantId': 'assistant-1',
              'createdAt': '2026-01-01T00:00:00.000Z',
              'status': 'success',
              'content': '',
              'blocks': <String>['block-$i-$j'],
            },
        ],
      },
  ];
  final blocks = <Map<String, dynamic>>[
    for (var i = 0; i < topics; i++)
      for (var j = 0; j < messagesPerTopic; j++)
        <String, dynamic>{
          'id': 'block-$i-$j',
          'type': 'main_text',
          'messageId': 'msg-$i-$j',
          'content': 'block-$i-$j-${'y' * 48}',
        },
  ];

  return <String, dynamic>{
    'version': 5,
    'localStorage': <String, dynamic>{
      'persist:cherry-studio': jsonEncode(<String, dynamic>{
        'assistants': jsonEncode(<String, dynamic>{
          'assistants': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'assistant-1',
              'name': 'Assistant One',
              'prompt': 'System prompt',
              'topics': topicMeta,
              'settings': <String, dynamic>{
                'temperature': 1,
                'contextCount': 5,
                'streamOutput': true,
              },
              'model': <String, dynamic>{
                'provider': 'openai',
                'id': 'gpt-test',
              },
            },
          ],
        }),
        'llm': jsonEncode(<String, dynamic>{
          'providers': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'openai',
              'type': 'openai',
              'name': 'OpenAI',
              'apiKey': 'sk-test',
              'apiHost': 'https://api.example.com',
              'enabled': true,
              'models': <Map<String, dynamic>>[
                <String, dynamic>{'id': 'gpt-test'},
              ],
            },
          ],
        }),
      }),
    },
    'indexedDB': <String, dynamic>{
      'topics': topicsWithMessages,
      'message_blocks': blocks,
      'files': <Map<String, dynamic>>[],
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
    root = await Directory.systemTemp.createTemp('kelivo_cherry_isolate_');
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
    await Hive.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'importingMessages advances to the real message total and does not finish early',
    () async {
      final backup = await File('${root.path}/cherry_msg_progress.bak')
          .writeAsString(
            jsonEncode(_largeCherryRoot(topics: 1, messagesPerTopic: 5)),
            flush: true,
          );
      final events = <BackupProgress>[];

      await CherryImporter.importFromCherryStudio(
        file: backup,
        mode: RestoreMode.overwrite,
        businessRepository: businessRepository,
        chatService: chatService,
        onProgress: events.add,
      );

      final messageEvents = events
          .where((event) => event.phase == BackupPhase.importingMessages)
          .toList();
      expect(messageEvents, isNotEmpty);
      expect(messageEvents.every((event) => event.total == 5), isTrue);
      expect(messageEvents.last.processed, 5);
      expect(messageEvents.last.total, 5);
      final earlyComplete = messageEvents.where(
        (event) =>
            event.total != null &&
            event.total! > 0 &&
            event.processed >= event.total! &&
            event.processed < 5,
      );
      expect(earlyComplete, isEmpty);
    },
  );

  test(
    'Cherry parse progress is monotonic and does not regress phases',
    () async {
      final backup = await File('${root.path}/cherry.bak').writeAsString(
        jsonEncode(_largeCherryRoot(topics: 3, messagesPerTopic: 3)),
        flush: true,
      );
      final events = <BackupProgress>[];

      await CherryImporter.importFromCherryStudio(
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
    },
  );

  test(
    'cancels Cherry body parse from the calling isolate while work continues',
    () async {
      final backup = await File(
        '${root.path}/cherry.bak',
      ).writeAsString(jsonEncode(_largeCherryRoot()), flush: true);
      final token = BackupCancelToken();
      addTearDown(token.dispose);
      final phases = <BackupPhase>[];

      await expectLater(
        CherryImporter.importFromCherryStudio(
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
