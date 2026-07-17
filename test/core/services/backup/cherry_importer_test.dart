import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/database/chat_database_gateway.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/backup/cherry_importer.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';

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

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kelivo_cherry_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
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

      final chatService = ChatService(databaseGateway: ChatDatabaseGateway());
      final result = await CherryImporter.importFromCherryStudio(
        file: backup,
        mode: RestoreMode.overwrite,
        settings: SettingsProvider(),
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

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('provider_configs_v1'), contains('openai'));
      expect(prefs.getString('assistants_v1'), contains('assistant-1'));
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

      final chatService = ChatService(databaseGateway: ChatDatabaseGateway());
      final result = await CherryImporter.importFromCherryStudio(
        file: backup,
        mode: RestoreMode.overwrite,
        settings: SettingsProvider(),
        chatService: chatService,
      );

      expect(result.conversations, 1);
      expect(result.messages, 1);
      expect(
        (await chatService.loadMessages('topic-1')).single.content,
        'hello from legacy',
      );
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
          settings: SettingsProvider(),
          chatService: ChatService(databaseGateway: ChatDatabaseGateway()),
        ),
        throwsA(anything),
      );
    });
  });
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
