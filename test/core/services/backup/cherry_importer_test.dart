import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_restore_service.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';
import 'package:Kelivo/core/services/backup/cherry_direct_backup_reader.dart';
import 'package:Kelivo/core/services/backup/cherry_importer.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

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
  late AppDatabase database;
  late BusinessRepository businessRepository;
  late ChatService chatService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kelivo_cherry_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    final databaseFile = File('${tempDir.path}/kelivo.db');
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
    CherryImporter.debugResetJsonProbeBudgets();
    await chatService.close();
    await database.close();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CherryImporter', () {
    test('imports Cherry Studio v6 direct backup zip', () async {
      final backup = await _createZip(tempDir, <String, List<int>>{
        'metadata.json': utf8.encode(
          jsonEncode(<String, dynamic>{
            'version': 6,
            'timestamp': 1780403199033,
            'appName': 'Cherry Studio',
          }),
        ),
        'Local Storage/leveldb/000001.log': _levelDbLogBytes(
          _persistStateJson(includeAdditionalTopics: true),
        ),
        'IndexedDB/file__0.indexeddb.leveldb/000001.log': <int>[
          0,
          1,
          ..._hex(_topicValueHex),
          2,
          3,
          ..._hex(_blockValueHex),
        ],
        'IndexedDB/file__0.indexeddb.leveldb/000002.ldb':
            _levelDbTableBytes(<List<int>>[
              _hex(_topic2ValueHex),
              _hex(_block2ValueHex),
              _hex(_message3ValueHex),
              _hex(_block3ValueHex),
            ], compressed: true),
      });

      final result = await CherryImporter.importFromCherryStudio(
        file: backup,
        mode: RestoreMode.overwrite,
        businessRepository: businessRepository,
        chatService: chatService,
      );

      expect(result.providers, 1);
      expect(result.assistants, 1);
      expect(result.conversations, 4);
      expect(result.messages, 3);

      final conversations = <String, dynamic>{
        for (final conversation in chatService.getAllConversations())
          conversation.id: conversation,
      };
      expect(
        conversations.keys,
        containsAll(<String>[
          'topic-1',
          'topic-2',
          'topic-empty',
          'topic-standalone',
        ]),
      );
      expect(conversations['topic-1'].title, 'Topic One');
      expect(conversations['topic-1'].assistantId, 'assistant-1');
      expect(conversations['topic-2'].title, 'Topic From LDB');
      expect(conversations['topic-2'].assistantId, 'assistant-1');
      expect(conversations['topic-empty'].title, 'Empty Topic');
      expect(conversations['topic-standalone'].title, 'Standalone Topic');
      expect(await chatService.loadMessages('topic-empty'), isEmpty);

      final message = (await chatService.loadMessages('topic-1')).single;
      expect(message.id, 'msg-1');
      expect(message.role, 'user');
      expect(message.content, '你好 from block');
      expect(message.modelId, 'gpt-test');
      expect(message.providerId, 'openai');

      final ldbMessage = (await chatService.loadMessages('topic-2')).single;
      expect(ldbMessage.id, 'msg-2');
      expect(ldbMessage.role, 'assistant');
      expect(ldbMessage.content, 'hello from ldb');

      final standaloneMessage = (await chatService.loadMessages(
        'topic-standalone',
      )).single;
      expect(standaloneMessage.id, 'msg-3');
      expect(standaloneMessage.role, 'user');
      expect(standaloneMessage.content, 'hello from standalone message');

      final exported = await BusinessRestoreService(
        businessRepository,
      ).exportSettings();
      final providers =
          jsonDecode(exported['provider_configs_v1'] as String) as Map;
      expect((providers['openai'] as Map)['apiKey'], 'sk-test');
      expect(exported['providers_order_v1'], ['openai']);
      expect(exported['assistants_v1'], contains('assistant-1'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('provider_configs_v1'), isNull);
      expect(prefs.getString('assistants_v1'), isNull);
    });

    test('keeps legacy data.json zip import working', () async {
      final backup = await _createZip(tempDir, <String, List<int>>{
        'data.json': utf8.encode(
          jsonEncode(<String, dynamic>{
            'version': 5,
            'localStorage': <String, dynamic>{
              'persist:cherry-studio': _persistStateJson(),
            },
            'indexedDB': <String, dynamic>{
              'topics': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'topic-1',
                  'messages': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'msg-1',
                      'role': 'user',
                      'topicId': 'topic-1',
                      'assistantId': 'assistant-1',
                      'createdAt': '2026-01-01T00:00:00.000Z',
                      'status': 'success',
                      'blocks': <String>['block-1'],
                    },
                  ],
                },
              ],
              'message_blocks': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'block-1',
                  'messageId': 'msg-1',
                  'type': 'main_text',
                  'createdAt': '2026-01-01T00:00:01.000Z',
                  'status': 'success',
                  'content': 'hello from legacy',
                },
              ],
              'files': <Map<String, dynamic>>[],
            },
          }),
        ),
      });

      final result = await CherryImporter.importFromCherryStudio(
        file: backup,
        mode: RestoreMode.overwrite,
        businessRepository: businessRepository,
        chatService: chatService,
      );

      expect(result.conversations, 1);
      expect(result.messages, 1);
      expect(
        (await chatService.loadMessages('topic-1')).single.content,
        'hello from legacy',
      );
    });

    test(
      'overwrite with a type-invalid message does not clear live chats',
      () async {
        await chatService.init();
        final existing = await chatService.createConversation(title: 'Keep me');
        final backup = await _createZip(tempDir, <String, List<int>>{
          'data.json': utf8.encode(
            jsonEncode(<String, dynamic>{
              'version': 5,
              'localStorage': <String, dynamic>{
                'persist:cherry-studio': _persistStateJson(),
              },
              'indexedDB': <String, dynamic>{
                'topics': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'topic-invalid',
                    'messages': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'id': 'msg-invalid',
                        'role': 'user',
                        'topicId': 'topic-invalid',
                        'assistantId': 'assistant-1',
                        'createdAt': '2026-01-01T00:00:00.000Z',
                        'status': 'success',
                        'modelId': 123,
                        'content': 'should never land',
                      },
                    ],
                  },
                ],
                'message_blocks': <Map<String, dynamic>>[],
                'files': <Map<String, dynamic>>[],
              },
            }),
          ),
        });

        await expectLater(
          CherryImporter.importFromCherryStudio(
            file: backup,
            mode: RestoreMode.overwrite,
            businessRepository: businessRepository,
            chatService: chatService,
          ),
          throwsA(anything),
        );

        expect(
          chatService.getAllConversations().any((c) => c.id == existing.id),
          isTrue,
        );
        expect(
          chatService.getAllConversations().any((c) => c.title == 'Keep me'),
          isTrue,
        );
      },
    );

    test('merge re-import of the same backup adds nothing twice', () async {
      Map<String, List<int>> entries() => <String, List<int>>{
        'data.json': utf8.encode(
          jsonEncode(<String, dynamic>{
            'version': 5,
            'localStorage': <String, dynamic>{
              'persist:cherry-studio': _persistStateJson(),
            },
            'indexedDB': <String, dynamic>{
              'topics': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'topic-1',
                  'messages': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'msg-1',
                      'role': 'user',
                      'topicId': 'topic-1',
                      'assistantId': 'assistant-1',
                      'createdAt': '2026-01-01T00:00:00.000Z',
                      'status': 'success',
                      'blocks': <String>['block-1'],
                    },
                  ],
                },
              ],
              'message_blocks': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'block-1',
                  'messageId': 'msg-1',
                  'type': 'main_text',
                  'createdAt': '2026-01-01T00:00:01.000Z',
                  'status': 'success',
                  'content': 'hello from legacy',
                },
              ],
              'files': <Map<String, dynamic>>[],
            },
          }),
        ),
      };

      final first = await CherryImporter.importFromCherryStudio(
        file: await _createZip(tempDir, entries()),
        mode: RestoreMode.merge,
        businessRepository: businessRepository,
        chatService: chatService,
      );
      expect(first.conversations, 1);
      expect(first.messages, 1);

      // Merge dedup now reads ids only; the second pass must still skip both
      // the existing conversation and its existing message.
      final second = await CherryImporter.importFromCherryStudio(
        file: await _createZip(tempDir, entries()),
        mode: RestoreMode.merge,
        businessRepository: businessRepository,
        chatService: chatService,
      );
      expect(second.conversations, 0);
      expect(second.messages, 0);
      expect(await chatService.loadMessages('topic-1'), hasLength(1));
    });

    test('rejects v6 direct backup without persisted Cherry state', () async {
      final backup = await _createZip(tempDir, <String, List<int>>{
        'metadata.json': utf8.encode(
          jsonEncode(<String, dynamic>{
            'version': 6,
            'timestamp': 1780403199033,
            'appName': 'Cherry Studio',
          }),
        ),
      });

      await expectLater(
        CherryImporter.importFromCherryStudio(
          file: backup,
          mode: RestoreMode.overwrite,
          businessRepository: businessRepository,
          chatService: chatService,
        ),
        throwsA(anything),
      );
    });

    test(
      'rolls back its whole business patch when an entity write fails',
      () async {
        final backup = await _createZip(tempDir, <String, List<int>>{
          'data.json': utf8.encode(
            jsonEncode(<String, dynamic>{
              'version': 5,
              'localStorage': <String, dynamic>{
                'persist:cherry-studio': _persistStateJson(),
              },
              'indexedDB': <String, dynamic>{
                'topics': <dynamic>[],
                'message_blocks': <dynamic>[],
                'files': <dynamic>[],
              },
            }),
          ),
        });
        await BusinessRestoreService(businessRepository).overwrite({
          'provider_configs_v1': jsonEncode({
            'local': {'id': 'local', 'apiKey': 'keep-me'},
          }),
          'providers_order_v1': ['local'],
          'assistants_v1': jsonEncode([
            {'id': 'local-assistant', 'name': 'Keep me'},
          ]),
        });
        final before = await BusinessRestoreService(
          businessRepository,
        ).exportSettings();
        await database.customStatement(
          'CREATE TRIGGER fail_cherry_assistant_insert '
          'BEFORE INSERT ON assistant_rows BEGIN '
          "SELECT RAISE(ABORT, 'injected failure'); END;",
        );

        await expectLater(
          CherryImporter.importFromCherryStudio(
            file: backup,
            mode: RestoreMode.merge,
            businessRepository: businessRepository,
            chatService: chatService,
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
      'rejects v7 slim archive without decoding sqlite as a string',
      () async {
        // If the sqlite entry were UTF-8-decoded (old bug), this valid Cherry
        // JSON payload would import conversation "poison-topic" successfully.
        final poisonJson = utf8.encode(
          jsonEncode(<String, dynamic>{
            'version': 5,
            'localStorage': <String, dynamic>{
              'persist:cherry-studio': _persistStateJson(),
            },
            'indexedDB': <String, dynamic>{
              'topics': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'poison-topic',
                  'messages': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'poison-msg',
                      'role': 'user',
                      'topicId': 'poison-topic',
                      'assistantId': 'assistant-1',
                      'createdAt': '2026-01-01T00:00:00.000Z',
                      'status': 'success',
                      'content': 'should-not-import',
                      'blocks': <String>[],
                    },
                  ],
                },
              ],
              'message_blocks': <Map<String, dynamic>>[],
              'files': <Map<String, dynamic>>[],
            },
          }),
        );
        final sqliteBytes = <int>[
          ...poisonJson,
          // Invalid UTF-8 — must never be stringified via speculative probe.
          0xff,
          0xfe,
          ...List<int>.filled(1024, 0x80),
        ];
        expect(
          CherryImporter.isSpeculativeJsonEntryCandidate(
            'Data/cherrystudio.sqlite',
            sqliteBytes.length,
          ),
          isFalse,
        );
        expect(
          CherryImporter.isIdentifiedJsonEntryName('Data/cherrystudio.sqlite'),
          isFalse,
        );

        final backup = await _createZip(tempDir, <String, List<int>>{
          'metadata.json': utf8.encode(
            jsonEncode(<String, dynamic>{
              'version': 7,
              'timestamp': 1780403199033,
              'appName': 'Cherry Studio',
              'resources': <String, dynamic>{
                'database': false,
                'cache': true,
                'indexedDB': false,
                'localStorage': false,
                'data': true,
              },
            }),
          ),
          'Data/cherrystudio.sqlite': sqliteBytes,
          'cache.json': utf8.encode('{}'),
        });

        await expectLater(
          CherryImporter.importFromCherryStudio(
            file: backup,
            mode: RestoreMode.overwrite,
            businessRepository: businessRepository,
            chatService: chatService,
          ),
          throwsA(
            isA<CherryUnsupportedBackupVersionException>().having(
              (e) => e.version,
              'version',
              7,
            ),
          ),
        );
        expect(chatService.getAllConversations(), isEmpty);
      },
    );

    test(
      'rejects v7 full archive instead of reading stale Local Storage',
      () async {
        final backup = await _createZip(tempDir, <String, List<int>>{
          'metadata.json': utf8.encode(
            jsonEncode(<String, dynamic>{
              'version': 7,
              'timestamp': 1780403199033,
              'appName': 'Cherry Studio',
              'resources': <String, dynamic>{
                'database': false,
                'cache': true,
                'indexedDB': true,
                'localStorage': true,
                'data': true,
              },
            }),
          ),
          'Data/cherrystudio.sqlite': List<int>.filled(64 * 1024, 0xff),
          'Local Storage/leveldb/000001.log': _levelDbLogBytes(
            _persistStateJson(includeAdditionalTopics: true),
          ),
          'IndexedDB/file__0.indexeddb.leveldb/000001.log': <int>[
            0,
            1,
            ..._hex(_topicValueHex),
            2,
            3,
            ..._hex(_blockValueHex),
          ],
        });

        await expectLater(
          CherryImporter.importFromCherryStudio(
            file: backup,
            mode: RestoreMode.overwrite,
            businessRepository: businessRepository,
            chatService: chatService,
          ),
          throwsA(
            isA<CherryUnsupportedBackupVersionException>().having(
              (e) => e.version,
              'version',
              7,
            ),
          ),
        );
        expect(chatService.getAllConversations(), isEmpty);
        expect(
          () => CherryDirectBackupReader.readArchive(
            Archive()..add(
              ArchiveFile.string(
                'metadata.json',
                jsonEncode(<String, dynamic>{'version': 7}),
              ),
            ),
          ),
          throwsA(isA<CherryUnsupportedBackupVersionException>()),
        );
      },
    );

    test(
      'version 6 direct backup does not throw unsupported-version',
      () async {
        final backup = await _createZip(tempDir, <String, List<int>>{
          'metadata.json': utf8.encode(
            jsonEncode(<String, dynamic>{
              'version': 6,
              'timestamp': 1780403199033,
              'appName': 'Cherry Studio',
            }),
          ),
          'Local Storage/leveldb/000001.log': _levelDbLogBytes(
            _persistStateJson(),
          ),
          'IndexedDB/file__0.indexeddb.leveldb/000001.log': <int>[
            0,
            1,
            ..._hex(_topicValueHex),
            2,
            3,
            ..._hex(_blockValueHex),
          ],
        });

        final result = await CherryImporter.importFromCherryStudio(
          file: backup,
          mode: RestoreMode.overwrite,
          businessRepository: businessRepository,
          chatService: chatService,
        );
        expect(result.conversations, greaterThan(0));
      },
    );

    test(
      'rejects v7 full archive before importing nested old-format backup JSON',
      () async {
        final nestedStale = utf8.encode(
          jsonEncode(
            _legacyBackupRoot(
              topicId: 'stale-nested-topic',
              messageId: 'stale-nested-msg',
              content: 'STALE_NESTED_V1_BACKUP_MUST_NOT_IMPORT',
            ),
          ),
        );

        final backup = await _createZip(tempDir, <String, List<int>>{
          'metadata.json': utf8.encode(
            jsonEncode(<String, dynamic>{
              'version': 7,
              'timestamp': 1780403199033,
              'appName': 'Cherry Studio',
              'resources': <String, dynamic>{
                'database': false,
                'cache': true,
                'indexedDB': true,
                'localStorage': true,
                'data': true,
              },
            }),
          ),
          'Data/cherrystudio.sqlite': List<int>.filled(1024, 0xff),
          'Data/Files/old-cherry-export.json': nestedStale,
          'Local Storage/leveldb/000001.log': _levelDbLogBytes(
            _persistStateJson(),
          ),
          'IndexedDB/file__0.indexeddb.leveldb/000001.log': <int>[
            0,
            1,
            ..._hex(_topicValueHex),
            2,
            3,
            ..._hex(_blockValueHex),
          ],
          'cache.json': utf8.encode('{}'),
        });

        await expectLater(
          CherryImporter.importFromCherryStudio(
            file: backup,
            mode: RestoreMode.overwrite,
            businessRepository: businessRepository,
            chatService: chatService,
          ),
          throwsA(
            isA<CherryUnsupportedBackupVersionException>().having(
              (e) => e.version,
              'version',
              7,
            ),
          ),
        );
        expect(chatService.getAllConversations(), isEmpty);
        expect(
          chatService.getAllConversations().map((c) => c.id),
          isNot(contains('stale-nested-topic')),
        );
      },
    );

    test('rejects v7 before probing a large nested .json entry', () async {
      const tinyIdentifiedCap = 256;
      CherryImporter.debugIdentifiedArchiveJsonBytes = tinyIdentifiedCap;
      CherryImporter.debugZipJsonProbeDecodeCount = 0;

      final nestedLarge = <int>[
        ...utf8.encode('{"pad":"'),
        ...List<int>.filled(tinyIdentifiedCap, 0x41),
        ...utf8.encode('"}'),
      ];
      expect(nestedLarge.length, greaterThan(tinyIdentifiedCap));

      final backup = await _createZip(tempDir, <String, List<int>>{
        'metadata.json': utf8.encode(
          jsonEncode(<String, dynamic>{
            'version': 7,
            'appName': 'Cherry Studio',
          }),
        ),
        'Data/Files/huge-dataset.json': nestedLarge,
        'cache.json': utf8.encode('{}'),
      });

      await expectLater(
        CherryImporter.importFromCherryStudio(
          file: backup,
          mode: RestoreMode.overwrite,
          businessRepository: businessRepository,
          chatService: chatService,
        ),
        throwsA(isA<CherryUnsupportedBackupVersionException>()),
      );
      expect(CherryImporter.debugZipJsonProbeDecodeCount, 0);
      expect(
        CherryImporter.debugIdentifiedArchiveJsonBytes,
        tinyIdentifiedCap,
      );
    });

    test(
      'imports nested backup JSON when archive has no metadata.json',
      () async {
        final backup = await _createZip(tempDir, <String, List<int>>{
          'Data/Files/embedded-backup.json': utf8.encode(
            jsonEncode(
              _legacyBackupRoot(
                topicId: 'nested-real-topic',
                messageId: 'nested-real-msg',
                content: 'from-nested-without-metadata',
              ),
            ),
          ),
        });

        final result = await CherryImporter.importFromCherryStudio(
          file: backup,
          mode: RestoreMode.overwrite,
          businessRepository: businessRepository,
          chatService: chatService,
        );
        expect(result.conversations, greaterThanOrEqualTo(1));
        expect(
          (await chatService.loadMessages('nested-real-topic')).single.content,
          'from-nested-without-metadata',
        );
      },
    );

    test('still parses plain JSON and gzipped JSON backups', () async {
      final root = <String, dynamic>{
        'version': 5,
        'localStorage': <String, dynamic>{
          'persist:cherry-studio': _persistStateJson(),
        },
        'indexedDB': <String, dynamic>{
          'topics': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'topic-1',
              'messages': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'msg-1',
                  'role': 'user',
                  'topicId': 'topic-1',
                  'assistantId': 'assistant-1',
                  'createdAt': '2026-01-01T00:00:00.000Z',
                  'status': 'success',
                  'content': 'plain-json',
                  'blocks': <String>[],
                },
              ],
            },
          ],
          'message_blocks': <Map<String, dynamic>>[],
          'files': <Map<String, dynamic>>[],
        },
      };
      final jsonBytes = utf8.encode(jsonEncode(root));
      final plain = File('${tempDir.path}/plain.bak');
      await plain.writeAsBytes(jsonBytes);

      final plainResult = await CherryImporter.importFromCherryStudio(
        file: plain,
        mode: RestoreMode.overwrite,
        businessRepository: businessRepository,
        chatService: chatService,
      );
      expect(plainResult.conversations, 1);
      expect(
        (await chatService.loadMessages('topic-1')).single.content,
        'plain-json',
      );

      root['indexedDB'] = <String, dynamic>{
        'topics': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'topic-gz',
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'msg-gz',
                'role': 'user',
                'topicId': 'topic-gz',
                'assistantId': 'assistant-1',
                'createdAt': '2026-01-01T00:00:00.000Z',
                'status': 'success',
                'content': 'gzip-json',
                'blocks': <String>[],
              },
            ],
          },
        ],
        'message_blocks': <Map<String, dynamic>>[],
        'files': <Map<String, dynamic>>[],
      };
      final gzipFile = File('${tempDir.path}/gzip.bak');
      await gzipFile.writeAsBytes(
        GZipEncoder().encodeBytes(utf8.encode(jsonEncode(root))),
      );

      final gzipResult = await CherryImporter.importFromCherryStudio(
        file: gzipFile,
        mode: RestoreMode.overwrite,
        businessRepository: businessRepository,
        chatService: chatService,
      );
      expect(gzipResult.conversations, greaterThanOrEqualTo(1));
      expect(
        (await chatService.loadMessages('topic-gz')).single.content,
        'gzip-json',
      );
    });

    test('plain JSON larger than the speculative cap still imports', () async {
      const tinyCap = 64;
      CherryImporter.debugSpeculativeJsonProbeBytes = tinyCap;
      final root = _legacyBackupRoot(
        topicId: 'topic-large-plain',
        messageId: 'msg-large-plain',
        content: 'x' * (tinyCap + 32),
      );
      final bytes = utf8.encode(jsonEncode(root));
      expect(bytes.length, greaterThan(tinyCap));

      final plain = File('${tempDir.path}/large_plain.bak');
      await plain.writeAsBytes(bytes);

      final result = await CherryImporter.importFromCherryStudio(
        file: plain,
        mode: RestoreMode.overwrite,
        businessRepository: businessRepository,
        chatService: chatService,
      );
      expect(result.conversations, greaterThanOrEqualTo(1));
      expect(
        (await chatService.loadMessages('topic-large-plain')).single.content,
        'x' * (tinyCap + 32),
      );
    });

    test(
      'in-zip data.json larger than the speculative cap still imports',
      () async {
        const tinyCap = 64;
        CherryImporter.debugSpeculativeJsonProbeBytes = tinyCap;
        final root = _legacyBackupRoot(
          topicId: 'topic-large-zip',
          messageId: 'msg-large-zip',
          content: 'y' * (tinyCap + 32),
        );
        final dataJson = utf8.encode(jsonEncode(root));
        expect(dataJson.length, greaterThan(tinyCap));
        expect(CherryImporter.isIdentifiedJsonEntryName('data.json'), isTrue);

        final backup = await _createZip(tempDir, <String, List<int>>{
          'data.json': dataJson,
        });

        final result = await CherryImporter.importFromCherryStudio(
          file: backup,
          mode: RestoreMode.overwrite,
          businessRepository: businessRepository,
          chatService: chatService,
        );
        expect(result.conversations, greaterThanOrEqualTo(1));
        expect(
          (await chatService.loadMessages('topic-large-zip')).single.content,
          'y' * (tinyCap + 32),
        );
      },
    );

    test(
      'skips nested oversized .json while root backup JSON still imports',
      () async {
        final rootJson = utf8.encode(
          jsonEncode(
            _legacyBackupRoot(
              topicId: 'topic-root',
              messageId: 'msg-root',
              content: 'from-root-data-json',
            ),
          ),
        );
        // Cap sits above a real root backup JSON but below the nested attachment.
        final identifiedCap = rootJson.length + 32;
        CherryImporter.debugIdentifiedArchiveJsonBytes = identifiedCap;

        final nestedPoison = utf8.encode(
          jsonEncode(
            _legacyBackupRoot(
              topicId: 'nested-poison',
              messageId: 'nested-msg',
              content: 'from-nested-json',
            ),
          ),
        );
        final nestedOversized = <int>[
          ...nestedPoison,
          ...List<int>.filled(identifiedCap - nestedPoison.length + 1, 0x41),
        ];
        expect(rootJson.length, lessThanOrEqualTo(identifiedCap));
        expect(nestedOversized.length, greaterThan(identifiedCap));
        expect(
          CherryImporter.isIdentifiedArchiveJsonEntryCandidate(
            'data.json',
            rootJson.length,
          ),
          isTrue,
        );
        expect(
          CherryImporter.isIdentifiedArchiveJsonEntryCandidate(
            'Data/Files/some-dataset.json',
            nestedOversized.length,
          ),
          isFalse,
        );
        expect(
          CherryImporter.isArchiveRootEntryName('Data/Files/some-dataset.json'),
          isFalse,
        );
        expect(CherryImporter.isArchiveRootEntryName('data.json'), isTrue);

        final backup = await _createZip(tempDir, <String, List<int>>{
          // Nested entry first in the archive to prove root ordering matters.
          'Data/Files/some-dataset.json': nestedOversized,
          'data.json': rootJson,
        });

        final result = await CherryImporter.importFromCherryStudio(
          file: backup,
          mode: RestoreMode.overwrite,
          businessRepository: businessRepository,
          chatService: chatService,
        );
        expect(result.conversations, greaterThanOrEqualTo(1));
        expect(
          (await chatService.loadMessages('topic-root')).single.content,
          'from-root-data-json',
        );
        expect(
          chatService.getAllConversations().map((c) => c.id),
          isNot(contains('nested-poison')),
        );
        expect(CherryImporter.debugZipJsonProbeDecodeCount, 1);
      },
    );

    test(
      'skips oversized non-JSON ZIP entries without decoding them',
      () async {
        const tinyCap = 64;
        CherryImporter.debugSpeculativeJsonProbeBytes = tinyCap;

        final hugePoison = utf8.encode(
          jsonEncode(
            _legacyBackupRoot(
              topicId: 'huge-poison',
              messageId: 'huge-msg',
              content: 'from-huge-entry',
            ),
          ),
        );
        final oversized = hugePoison.length > tinyCap
            ? hugePoison
            : <int>[
                ...hugePoison,
                ...List<int>.filled(tinyCap - hugePoison.length + 1, 0x41),
              ];
        expect(oversized.length, greaterThan(tinyCap));
        expect(
          CherryImporter.isSpeculativeJsonEntryCandidate(
            'huge.bin',
            oversized.length,
          ),
          isFalse,
        );

        final backup = await _createZip(tempDir, <String, List<int>>{
          'huge.bin': oversized,
          'data.json': utf8.encode(
            jsonEncode(
              _legacyBackupRoot(
                topicId: 'topic-1',
                messageId: 'msg-1',
                content: 'from-data-json',
              ),
            ),
          ),
        });

        final result = await CherryImporter.importFromCherryStudio(
          file: backup,
          mode: RestoreMode.overwrite,
          businessRepository: businessRepository,
          chatService: chatService,
        );
        expect(result.conversations, greaterThanOrEqualTo(1));
        expect(
          (await chatService.loadMessages('topic-1')).single.content,
          'from-data-json',
        );
        expect(
          chatService.getAllConversations().map((c) => c.id),
          isNot(contains('huge-poison')),
        );
        expect(CherryImporter.debugZipJsonProbeDecodeCount, 1);
      },
    );

    test('backup JSON with an invalid UTF-8 byte still imports', () async {
      final prefix = utf8.encode(
        '{"version":5,"localStorage":{"persist:cherry-studio":',
      );
      final persist = utf8.encode(jsonEncode(_persistStateJson()));
      final mid = utf8.encode(
        '},"indexedDB":{"topics":[{"id":"topic-bad","messages":[{"id":"msg-bad","role":"user","topicId":"topic-bad","assistantId":"assistant-1","createdAt":"2026-01-01T00:00:00.000Z","status":"success","content":"ok-with-bad-byte","blocks":[]}],"name":"Bad"},{"id":"pad","messages":[],"name":"',
      );
      // Insert a stray invalid UTF-8 byte inside a JSON string value.
      final suffix = utf8.encode('"}],"message_blocks":[],"files":[]}}');
      final bytes = <int>[...prefix, ...persist, ...mid, 0xff, ...suffix];

      final plain = File('${tempDir.path}/malformed_utf8.bak');
      await plain.writeAsBytes(bytes);

      final result = await CherryImporter.importFromCherryStudio(
        file: plain,
        mode: RestoreMode.overwrite,
        businessRepository: businessRepository,
        chatService: chatService,
      );
      expect(result.conversations, greaterThanOrEqualTo(1));
      expect(
        (await chatService.loadMessages('topic-bad')).single.content,
        'ok-with-bad-byte',
      );
    });

    test(
      'materializes attachments via basename, rel path, uuid id, and large entry',
      () async {
        const uuidId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
        final byBaseBytes = utf8.encode('basename-route-bytes');
        final byRelBytes = utf8.encode('rel-path-route-bytes');
        final byIdBytes = utf8.encode('uuid-id-route-bytes');
        final largeBytes = List<int>.generate(
          3 * 1024 * 1024,
          (i) => i % 251,
          growable: false,
        );

        final backup = await _createZip(tempDir, <String, List<int>>{
          'data.json': utf8.encode(
            jsonEncode(
              _legacyBackupWithAttachments(
                files: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'file-base',
                    'name': 'by-base.txt',
                    'origin_name': 'by-base.txt',
                    'type': 'text/plain',
                  },
                  <String, dynamic>{
                    'id': 'file-rel',
                    'name': 'rel-doc.bin',
                    'origin_name': 'rel-doc.bin',
                    'path': 'Data/Files/rel-doc.bin',
                    'type': 'application/octet-stream',
                  },
                  <String, dynamic>{
                    'id': uuidId,
                    'name': 'id-route.bin',
                    'origin_name': 'id-route.bin',
                    'ext': 'bin',
                    'type': 'application/octet-stream',
                  },
                  <String, dynamic>{
                    'id': 'file-large',
                    'name': 'large.bin',
                    'origin_name': 'large.bin',
                    'type': 'application/octet-stream',
                  },
                ],
              ),
            ),
          ),
          'Data/Files/by-base.txt': byBaseBytes,
          // Prefixed so indexOf('/data/files/') matches (same as nested layouts).
          'bundle/Data/Files/rel-doc.bin': byRelBytes,
          'Data/Files/$uuidId.bin': byIdBytes,
          'Data/Files/large.bin': largeBytes,
        });

        final events = <BackupProgress>[];
        final result = await CherryImporter.importFromCherryStudio(
          file: backup,
          mode: RestoreMode.overwrite,
          businessRepository: businessRepository,
          chatService: chatService,
          onProgress: events.add,
        );
        expect(result.files, greaterThanOrEqualTo(4));
        final materializing = events.where(
          (event) => event.phase == BackupPhase.materializingFiles,
        );
        expect(materializing, isNotEmpty);
        expect(
          materializing,
          everyElement(
            predicate<BackupProgress>((event) => event.cancellable == false),
          ),
        );

        final upload = await AppDirectories.getUploadDirectory();
        Future<List<int>> readUpload(String id, String name) {
          return File('${upload.path}/cherry_${id}_$name').readAsBytes();
        }

        expect(await readUpload('file-base', 'by-base.txt'), byBaseBytes);
        expect(await readUpload('file-rel', 'rel-doc.bin'), byRelBytes);
        expect(await readUpload(uuidId, 'id-route.bin'), byIdBytes);
        expect(await readUpload('file-large', 'large.bin'), largeBytes);

        final imported = await chatService.loadMessages('topic-files');
        expect(imported, hasLength(1));
        final message = imported.single;
        expect(message.content, 'with-attachments');
        expect(message.content.contains('[file:'), isFalse);
        expect(message.content.contains('[image:'), isFalse);
        final files = message.parts.whereType<FilePart>().toList();
        expect(files, hasLength(4));
        expect(files.map((part) => part.name).toSet(), {
          'by-base.txt',
          'rel-doc.bin',
          'id-route.bin',
          'large.bin',
        });
        for (final part in message.parts) {
          expect(part.encodePayload().contains('[file:'), isFalse);
          expect(part.encodePayload().contains('[image:'), isFalse);
        }
      },
    );

    test('missing archive file yields unavailable part', () async {
      final backup = await _createZip(tempDir, <String, List<int>>{
        'data.json': utf8.encode(
          jsonEncode(
            _legacyBackupWithAttachments(
              files: <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'file-missing',
                  'name': 'ghost.png',
                  // No path/origin_name/url → stable cherry-missing placeholder.
                  'type': 'image/png',
                },
                <String, dynamic>{
                  'id': 'file-missing-path',
                  'name': 'gone.bin',
                  'origin_name': 'gone.bin',
                  'path': 'Data/Files/gone.bin',
                  'type': 'application/octet-stream',
                },
              ],
            ),
          ),
        ),
        // Intentionally no Data/Files entries for either id.
      });

      await CherryImporter.importFromCherryStudio(
        file: backup,
        mode: RestoreMode.overwrite,
        businessRepository: businessRepository,
        chatService: chatService,
      );

      final imported = await chatService.loadMessages('topic-files');
      expect(imported, hasLength(1));
      final parts = imported.single.parts;
      final image = parts.whereType<ImagePart>().single;
      expect(image.unavailable, isTrue);
      expect(image.uri, 'cherry-missing:file-missing');
      final file = parts.whereType<FilePart>().single;
      expect(file.unavailable, isTrue);
      expect(file.uri, 'Data/Files/gone.bin');
      expect(file.name, 'gone.bin');
    });

    test('missing message_block fileId yields unavailable part', () async {
      final backup = await _createZip(tempDir, <String, List<int>>{
        'data.json': utf8.encode(
          jsonEncode(<String, dynamic>{
            'version': 5,
            'localStorage': <String, dynamic>{
              'persist:cherry-studio': _persistStateJson(),
            },
            'indexedDB': <String, dynamic>{
              'topics': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'topic-blocks',
                  'messages': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'msg-blocks',
                      'role': 'user',
                      'topicId': 'topic-blocks',
                      'assistantId': 'assistant-1',
                      'createdAt': '2026-01-01T00:00:00.000Z',
                      'status': 'success',
                      'content': 'with-block-attachment',
                      'blocks': <String>['block-img', 'block-file'],
                      'files': <dynamic>[],
                    },
                  ],
                },
              ],
              'message_blocks': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'block-img',
                  'messageId': 'msg-blocks',
                  'type': 'image',
                  'createdAt': '2026-01-01T00:00:01.000Z',
                  'status': 'success',
                  'file': <String, dynamic>{
                    'id': 'block-file-missing',
                    'name': 'shot.png',
                    'origin_name': 'shot.png',
                    'type': 'image/png',
                  },
                },
                <String, dynamic>{
                  'id': 'block-file',
                  'messageId': 'msg-blocks',
                  'type': 'file',
                  'createdAt': '2026-01-01T00:00:02.000Z',
                  'status': 'success',
                  'file': <String, dynamic>{
                    'id': 'block-doc-missing',
                    'name': 'notes.bin',
                    'origin_name': 'notes.bin',
                    'path': 'Data/Files/notes.bin',
                    'type': 'application/octet-stream',
                  },
                },
              ],
              'files': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'block-file-missing',
                  'name': 'shot.png',
                  'origin_name': 'shot.png',
                  'type': 'image/png',
                },
                <String, dynamic>{
                  'id': 'block-doc-missing',
                  'name': 'notes.bin',
                  'origin_name': 'notes.bin',
                  'path': 'Data/Files/notes.bin',
                  'type': 'application/octet-stream',
                },
              ],
            },
          }),
        ),
        // Intentionally omit Data/Files entries.
      });

      await CherryImporter.importFromCherryStudio(
        file: backup,
        mode: RestoreMode.overwrite,
        businessRepository: businessRepository,
        chatService: chatService,
      );

      final imported = await chatService.loadMessages('topic-blocks');
      expect(imported, hasLength(1));
      final parts = imported.single.parts;
      final image = parts.whereType<ImagePart>().single;
      expect(image.unavailable, isTrue);
      expect(image.uri, 'cherry-missing:block-file-missing');
      final file = parts.whereType<FilePart>().single;
      expect(file.unavailable, isTrue);
      expect(file.uri, 'Data/Files/notes.bin');
      expect(file.name, 'notes.bin');
    });

    test(
      'path attachment uses materialized URI when materialize succeeds',
      () async {
        final bytes = utf8.encode('local-disk-bytes');
        final backup = await _createZip(tempDir, <String, List<int>>{
          'data.json': utf8.encode(
            jsonEncode(
              _legacyBackupWithAttachments(
                files: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'file-path',
                    'name': 'local.bin',
                    'origin_name': 'local.bin',
                    'path': 'Data/Files/local.bin',
                    'type': 'application/octet-stream',
                  },
                ],
              ),
            ),
          ),
          'Data/Files/local.bin': bytes,
        });

        await CherryImporter.importFromCherryStudio(
          file: backup,
          mode: RestoreMode.overwrite,
          businessRepository: businessRepository,
          chatService: chatService,
        );

        final upload = await AppDirectories.getUploadDirectory();
        final saved = File('${upload.path}/cherry_file-path_local.bin');
        expect(await saved.exists(), isTrue);
        final file = (await chatService.loadMessages(
          'topic-files',
        )).single.parts.whereType<FilePart>().single;
        expect(file.unavailable, isFalse);
        expect(file.uri, SandboxPathResolver.canonicalize(saved.path));
      },
    );

    test(
      'url attachment uses materialized URI when materialize succeeds',
      () async {
        final bytes = utf8.encode('cdn-photo-bytes');
        final backup = await _createZip(tempDir, <String, List<int>>{
          'data.json': utf8.encode(
            jsonEncode(
              _legacyBackupWithAttachments(
                files: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'file-url',
                    'name': 'photo.png',
                    'origin_name': 'photo.png',
                    'type': 'image/png',
                    'url': 'https://cdn.example.com/photo.png',
                  },
                ],
              ),
            ),
          ),
          'Data/Files/photo.png': bytes,
        });

        await CherryImporter.importFromCherryStudio(
          file: backup,
          mode: RestoreMode.overwrite,
          businessRepository: businessRepository,
          chatService: chatService,
        );

        final upload = await AppDirectories.getUploadDirectory();
        final saved = File('${upload.path}/cherry_file-url_photo.png');
        expect(await saved.exists(), isTrue);
        final image = (await chatService.loadMessages(
          'topic-files',
        )).single.parts.whereType<ImagePart>().single;
        expect(image.unavailable, isFalse);
        expect(image.uri, SandboxPathResolver.canonicalize(saved.path));
      },
    );

    test(
      'failed materialize keeps fallback URI and marks unavailable',
      () async {
        final backup = await _createZip(tempDir, <String, List<int>>{
          'data.json': utf8.encode(
            jsonEncode(
              _legacyBackupWithAttachments(
                files: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'file-missing-path',
                    'name': 'gone.bin',
                    'origin_name': 'gone.bin',
                    'path': 'Data/Files/gone.bin',
                    'type': 'application/octet-stream',
                  },
                ],
              ),
            ),
          ),
        });

        await CherryImporter.importFromCherryStudio(
          file: backup,
          mode: RestoreMode.overwrite,
          businessRepository: businessRepository,
          chatService: chatService,
        );

        final file = (await chatService.loadMessages(
          'topic-files',
        )).single.parts.whereType<FilePart>().single;
        expect(file.unavailable, isTrue);
        expect(file.uri, 'Data/Files/gone.bin');
      },
    );

    test('each pending write is accessed exactly once at commit', () async {
      const messageCount = 24;
      const tinyPng =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      final backup = await _createZip(tempDir, <String, List<int>>{
        'data.json': utf8.encode(
          jsonEncode(<String, dynamic>{
            'version': 5,
            'localStorage': <String, dynamic>{
              'persist:cherry-studio': _persistStateJson(),
            },
            'indexedDB': <String, dynamic>{
              'topics': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'topic-many',
                  'messages': <Map<String, dynamic>>[
                    for (var i = 0; i < messageCount; i++)
                      <String, dynamic>{
                        'id': 'msg-many-$i',
                        'role': 'assistant',
                        'topicId': 'topic-many',
                        'assistantId': 'assistant-1',
                        'createdAt': '2026-01-01T00:00:00.000Z',
                        'status': 'success',
                        'content': tinyPng,
                        'blocks': <String>[],
                        'files': <dynamic>[],
                      },
                  ],
                },
              ],
              'message_blocks': <Map<String, dynamic>>[],
              'files': <Map<String, dynamic>>[],
            },
          }),
        ),
      });

      CherryImporter.debugPendingWriteAccessCount = 0;
      await CherryImporter.importFromCherryStudio(
        file: backup,
        mode: RestoreMode.overwrite,
        businessRepository: businessRepository,
        chatService: chatService,
      );

      expect(CherryImporter.debugPendingWriteAccessCount, messageCount);
      expect(await chatService.loadMessages('topic-many'), hasLength(messageCount));
    });

    test('extensionless image URL with image MIME becomes ImagePart', () async {
      final backup = await _createZip(tempDir, <String, List<int>>{
        'data.json': utf8.encode(
          jsonEncode(
            _legacyBackupWithAttachments(
              files: <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'file-presigned',
                  'name': 'photo',
                  'origin_name': 'photo',
                  'type': 'image/png',
                  'url': 'https://cdn.example.com/download?id=1',
                },
              ],
            ),
          ),
        ),
      });

      await CherryImporter.importFromCherryStudio(
        file: backup,
        mode: RestoreMode.overwrite,
        businessRepository: businessRepository,
        chatService: chatService,
      );

      final imported = await chatService.loadMessages('topic-files');
      expect(imported, hasLength(1));
      final image = imported.single.parts.whereType<ImagePart>().single;
      expect(image.unavailable, isFalse);
      expect(image.uri, 'https://cdn.example.com/download?id=1');
      expect(image.mime, 'image/png');
    });

    test('non-ZIP backup falls back to sibling Data/Files directory', () async {
      final filesDir = Directory('${tempDir.path}/Data/Files')
        ..createSync(recursive: true);
      final diskBytes = utf8.encode('from-sibling-disk');
      await File('${filesDir.path}/disk-only.txt').writeAsBytes(diskBytes);

      final bak = File('${tempDir.path}/cherry_disk.bak');
      await bak.writeAsString(
        jsonEncode(
          _legacyBackupWithAttachments(
            files: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'file-disk',
                'name': 'disk-only.txt',
                'origin_name': 'disk-only.txt',
                'path': 'Data/Files/disk-only.txt',
                'type': 'text/plain',
              },
            ],
          ),
        ),
      );

      final result = await CherryImporter.importFromCherryStudio(
        file: bak,
        mode: RestoreMode.overwrite,
        businessRepository: businessRepository,
        chatService: chatService,
      );
      expect(result.files, greaterThanOrEqualTo(1));
      final upload = await AppDirectories.getUploadDirectory();
      expect(
        await File(
          '${upload.path}/cherry_file-disk_disk-only.txt',
        ).readAsBytes(),
        diskBytes,
      );
    });

    test(
      'already-written attachment path is reused without rewriting',
      () async {
        final payload = utf8.encode('original-zip-bytes');
        final backup = await _createZip(tempDir, <String, List<int>>{
          'data.json': utf8.encode(
            jsonEncode(
              _legacyBackupWithAttachments(
                files: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'file-reuse',
                    'name': 'reuse.txt',
                    'origin_name': 'reuse.txt',
                    'type': 'text/plain',
                  },
                ],
              ),
            ),
          ),
          'Data/Files/reuse.txt': payload,
        });

        await CherryImporter.importFromCherryStudio(
          file: backup,
          mode: RestoreMode.merge,
          businessRepository: businessRepository,
          chatService: chatService,
        );

        final upload = await AppDirectories.getUploadDirectory();
        final out = File('${upload.path}/cherry_file-reuse_reuse.txt');
        expect(await out.readAsBytes(), payload);
        final marker = utf8.encode('LOCAL_MARKER_DO_NOT_OVERWRITE');
        await out.writeAsBytes(marker);

        await CherryImporter.importFromCherryStudio(
          file: backup,
          mode: RestoreMode.merge,
          businessRepository: businessRepository,
          chatService: chatService,
        );
        expect(await out.readAsBytes(), marker);
      },
    );

    test(
      'resolves zip attachments whose entry names use backslash separators',
      () async {
        const uuidId = 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff';
        final bytes = utf8.encode('backslash-entry-bytes');
        final archive = Archive()
          ..add(
            ArchiveFile.string(
              'data.json',
              jsonEncode(
                _legacyBackupWithAttachments(
                  files: <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': uuidId,
                      'name': 'win.bin',
                      'origin_name': 'win.bin',
                      'ext': 'bin',
                      'type': 'application/octet-stream',
                    },
                  ],
                ),
              ),
            ),
          )
          ..add(ArchiveFile.bytes('Data\\Files\\$uuidId.bin', bytes));

        final zip = File(
          '${tempDir.path}/backslash_${DateTime.now().microsecondsSinceEpoch}.zip',
        );
        await zip.writeAsBytes(ZipEncoder().encodeBytes(archive));

        final result = await CherryImporter.importFromCherryStudio(
          file: zip,
          mode: RestoreMode.overwrite,
          businessRepository: businessRepository,
          chatService: chatService,
        );
        expect(result.files, greaterThanOrEqualTo(1));
        final upload = await AppDirectories.getUploadDirectory();
        expect(
          await File('${upload.path}/cherry_${uuidId}_win.bin').readAsBytes(),
          bytes,
        );
      },
    );
  });
}

Map<String, dynamic> _legacyBackupWithAttachments({
  required List<Map<String, dynamic>> files,
}) {
  final fileRefs = <Map<String, dynamic>>[
    for (final file in files)
      <String, dynamic>{
        'id': file['id'],
        'name': file['name'],
        'origin_name': file['origin_name'] ?? file['name'],
        'type': file['type'] ?? 'application/octet-stream',
        if (file['path'] != null) 'path': file['path'],
        if (file['url'] != null) 'url': file['url'],
      },
  ];
  return <String, dynamic>{
    'version': 5,
    'localStorage': <String, dynamic>{
      'persist:cherry-studio': _persistStateJson(),
    },
    'indexedDB': <String, dynamic>{
      'topics': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'topic-files',
          'messages': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'msg-files',
              'role': 'user',
              'topicId': 'topic-files',
              'assistantId': 'assistant-1',
              'createdAt': '2026-01-01T00:00:00.000Z',
              'status': 'success',
              'content': 'with-attachments',
              'blocks': <String>[],
              'files': fileRefs,
            },
          ],
        },
      ],
      'message_blocks': <Map<String, dynamic>>[],
      'files': files,
    },
  };
}

Map<String, dynamic> _legacyBackupRoot({
  required String topicId,
  required String messageId,
  required String content,
}) {
  return <String, dynamic>{
    'version': 5,
    'localStorage': <String, dynamic>{
      'persist:cherry-studio': _persistStateJson(),
    },
    'indexedDB': <String, dynamic>{
      'topics': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': topicId,
          'messages': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': messageId,
              'role': 'user',
              'topicId': topicId,
              'assistantId': 'assistant-1',
              'createdAt': '2026-01-01T00:00:00.000Z',
              'status': 'success',
              'content': content,
              'blocks': <String>[],
            },
          ],
        },
      ],
      'message_blocks': <Map<String, dynamic>>[],
      'files': <Map<String, dynamic>>[],
    },
  };
}

Future<File> _createZip(Directory root, Map<String, List<int>> entries) async {
  final zip = File(
    '${root.path}/backup_${DateTime.now().microsecondsSinceEpoch}.zip',
  );
  final encoder = ZipFileEncoder();
  encoder.create(zip.path);
  var index = 0;
  for (final entry in entries.entries) {
    final source = File('${root.path}/zip_entry_$index.bin');
    await source.writeAsBytes(entry.value);
    encoder.addFileSync(source, entry.key);
    index++;
  }
  encoder.closeSync();
  return zip;
}

String _persistStateJson({bool includeAdditionalTopics = false}) {
  final topics = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'topic-1',
      'assistantId': 'assistant-1',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:01.000Z',
      'name': 'Topic One',
      'messages': <dynamic>[],
    },
  ];
  if (includeAdditionalTopics) {
    topics.addAll(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'topic-2',
        'assistantId': 'default',
        'createdAt': '2026-01-01T00:00:02.000Z',
        'updatedAt': '2026-01-01T00:00:03.000Z',
        'name': 'Topic From LDB',
        'messages': <dynamic>[],
      },
      <String, dynamic>{
        'id': 'topic-empty',
        'assistantId': 'assistant-1',
        'createdAt': '2026-01-01T00:00:04.000Z',
        'updatedAt': '2026-01-01T00:00:05.000Z',
        'name': 'Empty Topic',
        'messages': <dynamic>[],
      },
      <String, dynamic>{
        'id': 'topic-standalone',
        'assistantId': 'assistant-1',
        'createdAt': '2026-01-01T00:00:04.000Z',
        'updatedAt': '2026-01-01T00:00:05.000Z',
        'name': 'Standalone Topic',
        'messages': <dynamic>[],
      },
    ]);
  }

  return jsonEncode(<String, dynamic>{
    'assistants': jsonEncode(<String, dynamic>{
      'assistants': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'assistant-1',
          'name': 'Assistant One',
          'prompt': 'System prompt',
          'topics': topics,
          'settings': <String, dynamic>{
            'temperature': 1,
            'contextCount': 5,
            'enableMaxTokens': false,
            'streamOutput': true,
            'topP': 1,
          },
          'model': <String, dynamic>{'provider': 'openai', 'id': 'gpt-test'},
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
  });
}

List<int> _levelDbLogBytes(String persistState) {
  final key = <int>[
    ...ascii.encode('_file://'),
    0,
    1,
    ...ascii.encode('persist:cherry-studio'),
  ];
  final value = <int>[0];
  for (final unit in persistState.codeUnits) {
    value.add(unit & 0xff);
    value.add(unit >> 8);
  }

  final batch = <int>[
    0, 0, 0, 0, 0, 0, 0, 0, // sequence number
    1, 0, 0, 0, // record count
    1, // value record
    ..._varint(key.length),
    ...key,
    ..._varint(value.length),
    ...value,
  ];

  final split = batch.length ~/ 2;
  return <int>[
    ..._logRecord(2, batch.sublist(0, split)),
    ..._logRecord(4, batch.sublist(split)),
  ];
}

List<int> _logRecord(int type, List<int> payload) {
  return <int>[
    0, 0, 0, 0, // CRC is ignored by the importer.
    payload.length & 0xff,
    payload.length >> 8,
    type,
    ...payload,
  ];
}

List<int> _varint(int value) {
  final bytes = <int>[];
  while (value >= 0x80) {
    bytes.add((value & 0x7f) | 0x80);
    value >>= 7;
  }
  bytes.add(value);
  return bytes;
}

List<int> _levelDbTableBytes(
  List<List<int>> values, {
  required bool compressed,
}) {
  final dataEntries = <(List<int>, List<int>)>[];
  for (var index = 0; index < values.length; index++) {
    dataEntries.add((ascii.encode('key-$index'), values[index]));
  }

  final dataBlock = _tableBlock(dataEntries);
  final dataPayload = compressed ? _snappyLiteralBlock(dataBlock) : dataBlock;
  final dataPhysical = _tablePhysicalBlock(dataPayload, compressed: compressed);
  final metaIndexBlock = _tableBlock(const <(List<int>, List<int>)>[]);
  final metaIndexPayload = metaIndexBlock;
  final metaIndexPhysical = _tablePhysicalBlock(
    metaIndexPayload,
    compressed: false,
  );
  final dataHandle = _blockHandle(0, dataPayload.length);
  final metaIndexOffset = dataPhysical.length;
  final metaIndexHandle = _blockHandle(
    metaIndexOffset,
    metaIndexPayload.length,
  );
  final indexOffset = dataPhysical.length + metaIndexPhysical.length;
  final indexBlock = _tableBlock(<(List<int>, List<int>)>[
    (ascii.encode('key-final'), dataHandle),
  ]);
  final indexPayload = indexBlock;
  final indexPhysical = _tablePhysicalBlock(indexPayload, compressed: false);
  final indexHandle = _blockHandle(indexOffset, indexPayload.length);
  final footer = <int>[...metaIndexHandle, ...indexHandle];
  while (footer.length < 40) {
    footer.add(0);
  }
  footer.addAll(<int>[0x57, 0xfb, 0x80, 0x8b, 0x24, 0x75, 0x47, 0xdb]);

  return <int>[
    ...dataPhysical,
    ...metaIndexPhysical,
    ...indexPhysical,
    ...footer,
  ];
}

List<int> _tableBlock(List<(List<int>, List<int>)> entries) {
  final out = <int>[];
  for (final entry in entries) {
    out
      ..addAll(_varint(0))
      ..addAll(_varint(entry.$1.length))
      ..addAll(_varint(entry.$2.length))
      ..addAll(entry.$1)
      ..addAll(entry.$2);
  }
  out
    ..addAll(_fixed32(0))
    ..addAll(_fixed32(1));
  return out;
}

List<int> _tablePhysicalBlock(List<int> payload, {required bool compressed}) {
  return <int>[...payload, compressed ? 1 : 0, 0, 0, 0, 0];
}

List<int> _snappyLiteralBlock(List<int> bytes) {
  final out = <int>[..._varint(bytes.length)];
  if (bytes.length < 60) {
    out.add((bytes.length - 1) << 2);
  } else if (bytes.length <= 0x100) {
    out.add(60 << 2);
    out.add(bytes.length - 1);
  } else {
    out.add(61 << 2);
    out.add((bytes.length - 1) & 0xff);
    out.add((bytes.length - 1) >> 8);
  }
  out.addAll(bytes);
  return out;
}

List<int> _blockHandle(int offset, int size) {
  return <int>[..._varint(offset), ..._varint(size)];
}

List<int> _fixed32(int value) {
  return <int>[
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ];
}

List<int> _hex(String value) {
  final bytes = <int>[];
  for (var i = 0; i < value.length; i += 2) {
    bytes.add(int.parse(value.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

const _topicValueHex =
    'ff0f6f220269642207746f7069632d3122086d6573736167657341016f2202696422056d73672d312204726f6c652204757365722207746f70696349642207746f7069632d31220b617373697374616e744964220b617373697374616e742d3122096372656174656441742218323032362d30312d30315430303a30303a30302e3030305a22067374617475732207737563636573732206626c6f636b7341012207626c6f636b2d3124000122076d6f64656c496422086770742d7465737422056d6f64656c6f2202696422086770742d74657374220870726f766964657222066f70656e61697b02220575736167656f220c746f74616c5f746f6b656e73490e7b017b0a2400017b02';

const _blockValueHex =
    'ff0f6f220269642207626c6f636b2d3122096d657373616765496422056d73672d3122047479706522096d61696e5f7465787422096372656174656441742218323032362d30312d30315430303a30303a30312e3030305a22067374617475732207737563636573732207636f6e74656e74631a604f7d592000660072006f006d00200062006c006f0063006b007b06';

const _topic2ValueHex =
    'ff0f6f220269642207746f7069632d3222086d6573736167657341016f2202696422056d73672d322204726f6c652209617373697374616e742207746f70696349642207746f7069632d32220b617373697374616e744964220b617373697374616e742d3122096372656174656441742218323032362d30312d30315430303a30303a30322e3030305a22067374617475732207737563636573732206626c6f636b7341012207626c6f636b2d3224000122076d6f64656c496422086770742d7465737422056d6f64656c6f2202696422086770742d74657374220870726f766964657222066f70656e6169220b6465736372697074696f6e0063042d4e87657b03220575736167656f220c746f74616c5f746f6b656e7349127b017b0a2400017b02';

const _block2ValueHex =
    'ff0f6f220269642207626c6f636b2d3222096d657373616765496422056d73672d3222047479706522096d61696e5f7465787422096372656174656441742218323032362d30312d30315430303a30303a30332e3030305a22067374617475732207737563636573732207636f6e74656e74220e68656c6c6f2066726f6d206c64627b06';

const _message3ValueHex =
    'ff0f6f2202696422056d73672d332204726f6c652204757365722207746f70696349642210746f7069632d7374616e64616c6f6e65220b617373697374616e744964220b617373697374616e742d3122096372656174656441742218323032362d30312d30315430303a30303a30342e3030305a22067374617475732207737563636573732206626c6f636b7341012207626c6f636b2d3324000122076d6f64656c496422086770742d7465737422056d6f64656c6f2202696422086770742d74657374220870726f766964657222066f70656e61697b02220575736167656f220c746f74616c5f746f6b656e73490a7b017b0a';

const _block3ValueHex =
    'ff0f6f220269642207626c6f636b2d3322096d657373616765496422056d73672d3322047479706522096d61696e5f7465787422096372656174656441742218323032362d30312d30315430303a30303a30352e3030305a22067374617475732207737563636573732207636f6e74656e74221d68656c6c6f2066726f6d207374616e64616c6f6e65206d6573736167657b06';
