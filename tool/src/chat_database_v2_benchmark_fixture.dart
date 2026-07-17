import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

enum ChatBenchmarkDataset { d1, d2, d3, d4, d5, d6 }

extension ChatBenchmarkDatasetName on ChatBenchmarkDataset {
  String get id => name.toUpperCase();
}

typedef ChatBenchmarkPlan = ({
  int conversations,
  int logicalMessages,
  int physicalMessages,
  String description,
});

typedef ChatBenchmarkFixtureResult = ({
  ChatBenchmarkDataset dataset,
  String path,
  int conversations,
  int logicalMessages,
  int physicalMessages,
  int bytes,
  int walPeakBytes,
  int generationMicros,
  int checkpointMicros,
  String digest,
});

final class ChatDatabaseV2BenchmarkFixture {
  ChatDatabaseV2BenchmarkFixture._();

  static const seed = 20260711;

  static ChatBenchmarkPlan plan(ChatBenchmarkDataset dataset) =>
      switch (dataset) {
        ChatBenchmarkDataset.d1 => (
          conversations: 50,
          logicalMessages: 5000,
          physicalMessages: 5000,
          description: 'regular text and tool calls',
        ),
        ChatBenchmarkDataset.d2 => (
          conversations: 1000,
          logicalMessages: 100000,
          physicalMessages: 100000,
          description: 'Chinese and English search corpus',
        ),
        ChatBenchmarkDataset.d3 => (
          conversations: 1,
          logicalMessages: 10000,
          physicalMessages: 10617,
          description: '10000 slots with 1/20/100/500 revision slots',
        ),
        ChatBenchmarkDataset.d4 => (
          conversations: 1,
          logicalMessages: 1,
          physicalMessages: 1,
          description: '1 MiB streaming Markdown payload',
        ),
        ChatBenchmarkDataset.d5 => (
          conversations: 1,
          logicalMessages: 1,
          physicalMessages: 1,
          description: '100 4K images, table, code and attachments',
        ),
        ChatBenchmarkDataset.d6 => (
          conversations: 1,
          logicalMessages: 5,
          physicalMessages: 6,
          description: 'corrupt and inconsistent recovery fixtures',
        ),
      };

  static String planDigest(ChatBenchmarkDataset dataset) => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'seed': seed,
            'dataset': dataset.id,
            'plan': {
              'conversations': plan(dataset).conversations,
              'logicalMessages': plan(dataset).logicalMessages,
              'physicalMessages': plan(dataset).physicalMessages,
              'description': plan(dataset).description,
            },
          }),
        ),
      )
      .toString();

  static Future<ChatBenchmarkFixtureResult> generate({
    required ChatBenchmarkDataset dataset,
    required Directory outputDirectory,
    bool smoke = false,
  }) async {
    await outputDirectory.create(recursive: true);
    if (dataset == ChatBenchmarkDataset.d6) {
      return _generateD6(outputDirectory);
    }
    final file = File(p.join(outputDirectory.path, '${dataset.id}.sqlite'));
    if (await file.exists()) await file.delete();
    final watch = Stopwatch()..start();
    final database = sqlite3.open(file.path);
    var walPeak = 0;
    var checkpointMicros = 0;
    try {
      _createSchema(database);
      database.execute('PRAGMA journal_mode = WAL;');
      database.execute('PRAGMA synchronous = NORMAL;');
      database.execute('BEGIN IMMEDIATE;');
      try {
        switch (dataset) {
          case ChatBenchmarkDataset.d1:
            _generateCorpus(
              database,
              conversations: smoke ? 2 : 50,
              messages: smoke ? 100 : 5000,
              toolEvery: 10,
              bilingual: false,
            );
          case ChatBenchmarkDataset.d2:
            _generateCorpus(
              database,
              conversations: smoke ? 5 : 1000,
              messages: smoke ? 250 : 100000,
              toolEvery: 25,
              bilingual: true,
            );
          case ChatBenchmarkDataset.d3:
            _generateD3(database, smoke: smoke);
          case ChatBenchmarkDataset.d4:
            _generateD4(database, smoke: smoke);
          case ChatBenchmarkDataset.d5:
            await _generateD5(
              database,
              outputDirectory: outputDirectory,
              smoke: smoke,
            );
          case ChatBenchmarkDataset.d6:
            throw StateError('unreachable');
        }
        database.execute('COMMIT;');
      } catch (_) {
        database.execute('ROLLBACK;');
        rethrow;
      }
      final wal = File('${file.path}-wal');
      walPeak = wal.existsSync() ? wal.lengthSync() : 0;
      final checkpoint = Stopwatch()..start();
      database.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      checkpoint.stop();
      checkpointMicros = checkpoint.elapsedMicroseconds;
    } finally {
      database.close();
      watch.stop();
    }
    final counts = _readCounts(file);
    return (
      dataset: dataset,
      path: file.path,
      conversations: counts.conversations,
      logicalMessages: counts.logicalMessages,
      physicalMessages: counts.physicalMessages,
      bytes: file.lengthSync(),
      walPeakBytes: walPeak,
      generationMicros: watch.elapsedMicroseconds,
      checkpointMicros: checkpointMicros,
      digest: planDigest(dataset),
    );
  }

  static ({int conversations, int logicalMessages, int physicalMessages})
  _readCounts(File file) {
    final database = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      int count(String sql) => database.select(sql).single.values.single as int;
      return (
        conversations: count('SELECT COUNT(*) FROM conversation_rows;'),
        logicalMessages: count(
          'SELECT COUNT(*) FROM ('
          'SELECT conversation_id, COALESCE(group_id, id) '
          'FROM message_rows GROUP BY conversation_id, COALESCE(group_id, id));',
        ),
        physicalMessages: count('SELECT COUNT(*) FROM message_rows;'),
      );
    } finally {
      database.close();
    }
  }

  static void _createSchema(Database database) {
    database.execute('PRAGMA user_version = 1;');
    database.execute('PRAGMA foreign_keys = ON;');
    database.execute('''
CREATE TABLE conversation_rows (
  id TEXT NOT NULL PRIMARY KEY,
  title TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  is_pinned INTEGER NOT NULL DEFAULT 0,
  assistant_id TEXT,
  truncate_index INTEGER NOT NULL DEFAULT -1,
  version_selections_json TEXT NOT NULL DEFAULT '{}',
  summary TEXT,
  last_summarized_message_count INTEGER NOT NULL DEFAULT 0,
  chat_suggestions_json TEXT NOT NULL DEFAULT '[]'
);
CREATE TABLE message_rows (
  id TEXT NOT NULL PRIMARY KEY,
  conversation_id TEXT NOT NULL REFERENCES conversation_rows(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  model_id TEXT,
  provider_id TEXT,
  total_tokens INTEGER,
  is_streaming INTEGER NOT NULL DEFAULT 0,
  reasoning_text TEXT,
  reasoning_start_at INTEGER,
  reasoning_finished_at INTEGER,
  translation TEXT,
  reasoning_segments_json TEXT,
  group_id TEXT,
  version INTEGER NOT NULL DEFAULT 0,
  prompt_tokens INTEGER,
  completion_tokens INTEGER,
  cached_tokens INTEGER,
  duration_ms INTEGER,
  message_order INTEGER NOT NULL
);
CREATE TABLE conversation_mcp_server_rows (
  conversation_id TEXT NOT NULL REFERENCES conversation_rows(id) ON DELETE CASCADE,
  server_id TEXT NOT NULL,
  ordinal INTEGER NOT NULL,
  PRIMARY KEY (conversation_id, server_id)
);
CREATE TABLE tool_event_rows (
  message_id TEXT NOT NULL PRIMARY KEY REFERENCES message_rows(id) ON DELETE CASCADE,
  events_json TEXT NOT NULL
);
CREATE TABLE gemini_thought_signature_rows (
  message_id TEXT NOT NULL PRIMARY KEY REFERENCES message_rows(id) ON DELETE CASCADE,
  signature TEXT NOT NULL
);
CREATE TABLE chat_storage_meta_rows (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE INDEX idx_messages_conversation_order
  ON message_rows(conversation_id, message_order);
CREATE INDEX idx_messages_conversation_timestamp
  ON message_rows(conversation_id, timestamp);
CREATE INDEX idx_messages_group ON message_rows(group_id);
CREATE INDEX idx_conversations_updated_at ON conversation_rows(updated_at);
CREATE INDEX idx_conversations_assistant ON conversation_rows(assistant_id);
''');
  }

  static void _generateCorpus(
    Database database, {
    required int conversations,
    required int messages,
    required int toolEvery,
    required bool bilingual,
  }) {
    final conversationInsert = database.prepare(
      'INSERT INTO conversation_rows (id, title, created_at, updated_at) '
      'VALUES (?, ?, ?, ?);',
    );
    final messageInsert = database.prepare(
      'INSERT INTO message_rows '
      '(id, conversation_id, role, content, timestamp, group_id, version, message_order) '
      'VALUES (?, ?, ?, ?, ?, ?, 0, ?);',
    );
    final toolInsert = database.prepare(
      'INSERT INTO tool_event_rows (message_id, events_json) VALUES (?, ?);',
    );
    try {
      for (var conversation = 0; conversation < conversations; conversation++) {
        final id = 'c-${conversation.toString().padLeft(5, '0')}';
        conversationInsert.execute([
          id,
          'Conversation $conversation',
          seed + conversation,
          seed + conversation,
        ]);
      }
      final order = List<int>.filled(conversations, 0);
      for (var index = 0; index < messages; index++) {
        final conversation = index % conversations;
        final conversationId = 'c-${conversation.toString().padLeft(5, '0')}';
        final id = 'm-${index.toString().padLeft(7, '0')}';
        final text = bilingual
            ? (index.isEven
                  ? '中文搜索 基准消息 $index 固定种子 $seed'
                  : 'English search benchmark message $index seed $seed')
            : 'Benchmark message $index seed $seed';
        messageInsert.execute([
          id,
          conversationId,
          index.isEven ? 'user' : 'assistant',
          text,
          seed + index,
          'slot-$id',
          order[conversation]++,
        ]);
        if (index % toolEvery == 0) {
          toolInsert.execute([
            id,
            jsonEncode([
              {'type': 'result', 'index': index},
            ]),
          ]);
        }
      }
    } finally {
      conversationInsert.close();
      messageInsert.close();
      toolInsert.close();
    }
  }

  static void _generateD3(Database database, {required bool smoke}) {
    _insertConversation(database, 'd3', 'Revision fan-out');
    final slots = smoke ? 100 : 10000;
    const revisionCounts = {0: 1, 1: 20, 2: 100, 3: 500};
    var order = 0;
    for (var slot = 0; slot < slots; slot++) {
      final revisions = revisionCounts[slot] ?? 1;
      for (var version = 0; version < revisions; version++) {
        _insertMessage(
          database,
          id: 'd3-$slot-$version',
          conversationId: 'd3',
          order: order++,
          groupId: 'slot-$slot',
          version: version,
          content: 'slot=$slot revision=$version',
        );
      }
    }
  }

  static void _generateD4(Database database, {required bool smoke}) {
    _insertConversation(database, 'd4', 'Long streaming Markdown');
    final targetBytes = smoke ? 32 << 10 : 1 << 20;
    const block =
        '''# Streaming\n```dart\nvoid main() {}\n```\n|列|value|\n|-|-|\n|中文|English|\n```mermaid\ngraph TD; A-->B;\n```\n[image:/fixture/images/stream.png]\n''';
    final buffer = StringBuffer(block);
    while (buffer.length < targetBytes) {
      buffer.writeln('Streaming plain text 中文 English seed=$seed.');
    }
    _insertMessage(
      database,
      id: 'd4-message',
      conversationId: 'd4',
      order: 0,
      groupId: 'd4-slot',
      version: 0,
      content: buffer.toString().substring(0, targetBytes),
      reasoning: List<String>.filled(1024, 'reasoning ').join(),
    );
  }

  static Future<void> _generateD5(
    Database database, {
    required Directory outputDirectory,
    required bool smoke,
  }) async {
    _insertConversation(database, 'd5', 'Renderer stress');
    final imageCount = smoke ? 2 : 100;
    final tableRows = smoke ? 20 : 1000;
    final codeRows = smoke ? 100 : 10000;
    final assetDirectory = Directory(p.join(outputDirectory.path, 'D5_assets'));
    await assetDirectory.create(recursive: true);
    final bitmap = image.Image(width: 3840, height: 2160);
    image.fill(bitmap, color: image.ColorRgb8(24, 96, 180));
    final png = image.encodePng(bitmap, level: 1);
    final content = StringBuffer('# Renderer fixture\n');
    for (var index = 0; index < imageCount; index++) {
      final file = File(p.join(assetDirectory.path, 'image_$index.png'));
      await file.writeAsBytes(png, flush: index == imageCount - 1);
      content.writeln('[image:${file.path}]');
    }
    final attachmentCount = smoke ? 2 : 100;
    for (var index = 0; index < attachmentCount; index++) {
      final file = File(p.join(assetDirectory.path, 'attachment_$index.bin'));
      await file.writeAsBytes(
        List<int>.generate(1024, (offset) => (index + offset) & 0xff),
      );
      content.writeln(
        '[file:${file.path}|attachment_$index.bin|application/octet-stream]',
      );
    }
    content.writeln('|index|中文|value|');
    content.writeln('|-:|:-|:-|');
    for (var index = 0; index < tableRows; index++) {
      content.writeln('|$index|行|value-$index|');
    }
    content.writeln('```dart');
    for (var index = 0; index < codeRows; index++) {
      content.writeln('final value$index = $index;');
    }
    content.writeln('```');
    _insertMessage(
      database,
      id: 'd5-message',
      conversationId: 'd5',
      order: 0,
      groupId: 'd5-slot',
      version: 0,
      content: content.toString(),
    );
  }

  static Future<ChatBenchmarkFixtureResult> _generateD6(
    Directory outputDirectory,
  ) async {
    final watch = Stopwatch()..start();
    final root = Directory(p.join(outputDirectory.path, 'D6_faults'));
    if (await root.exists()) await root.delete(recursive: true);
    await root.create(recursive: true);
    final databaseFile = File(p.join(root.path, 'inconsistent.sqlite'));
    final database = sqlite3.open(databaseFile.path);
    try {
      _createSchema(database);
      database.execute('PRAGMA foreign_keys = OFF;');
      _insertConversation(database, 'd6', 'Faults');
      _insertMessage(
        database,
        id: 'bad-json',
        conversationId: 'd6',
        order: 0,
        groupId: 'bad-json-slot',
        version: 0,
        content: 'bad JSON metadata owner',
      );
      _insertMessage(
        database,
        id: 'duplicate-a',
        conversationId: 'd6',
        order: 0,
        groupId: 'duplicate-slot',
        version: 7,
        content: 'duplicate order and version A',
      );
      _insertMessage(
        database,
        id: 'duplicate-b',
        conversationId: 'd6',
        order: 0,
        groupId: 'duplicate-slot',
        version: 7,
        content: 'duplicate order and version B',
      );
      _insertMessage(
        database,
        id: 'missing-attachment',
        conversationId: 'd6',
        order: 2,
        groupId: 'missing-attachment-slot',
        version: 0,
        content:
            '[file:/missing/attachment.bin|missing|application/octet-stream]',
      );
      _insertMessage(
        database,
        id: 'version-gap',
        conversationId: 'd6',
        order: 3,
        groupId: 'version-gap-slot',
        version: 9,
        content: 'version gap',
      );
      database.execute(
        'UPDATE conversation_rows SET version_selections_json = ? WHERE id = ?;',
        ['{bad json', 'd6'],
      );
      database.execute(
        'INSERT INTO message_rows '
        '(id, conversation_id, role, content, timestamp, message_order) '
        "VALUES ('orphan', 'missing-conversation', 'user', 'orphan', 0, 3);",
      );
    } finally {
      database.close();
    }
    await File(
      p.join(root.path, 'truncated.sqlite-wal'),
    ).writeAsBytes(List<int>.generate(127, (index) => index & 0xff));
    await File(
      p.join(root.path, 'truncated.zip'),
    ).writeAsBytes(const [0x50, 0x4b, 0x03, 0x04, 0x00]);
    await File(p.join(root.path, 'legacy_bad_chats.json')).writeAsString(
      '{"version":1,"conversations":[{"id":"missing-message"}],"messages":[]}',
    );
    await File(p.join(root.path, 'manifest.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'seed': seed,
        'faults': [
          'orphan message',
          'duplicate order/version',
          'bad JSON metadata',
          'missing attachment',
          'truncated WAL',
          'truncated ZIP',
          'legacy JSON missing reference',
        ],
      }),
    );
    watch.stop();
    return (
      dataset: ChatBenchmarkDataset.d6,
      path: root.path,
      conversations: 1,
      logicalMessages: 5,
      physicalMessages: 6,
      bytes: root
          .listSync(recursive: true)
          .whereType<File>()
          .fold(0, (sum, file) => sum + file.lengthSync()),
      walPeakBytes: 127,
      generationMicros: watch.elapsedMicroseconds,
      checkpointMicros: 0,
      digest: planDigest(ChatBenchmarkDataset.d6),
    );
  }

  static void _insertConversation(Database database, String id, String title) {
    database.execute(
      'INSERT INTO conversation_rows (id, title, created_at, updated_at) '
      'VALUES (?, ?, ?, ?);',
      [id, title, seed, seed],
    );
  }

  static void _insertMessage(
    Database database, {
    required String id,
    required String conversationId,
    required int order,
    required String groupId,
    required int version,
    required String content,
    String? reasoning,
  }) {
    database.execute(
      'INSERT INTO message_rows '
      '(id, conversation_id, role, content, timestamp, reasoning_text, '
      'group_id, version, message_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);',
      [
        id,
        conversationId,
        'assistant',
        content,
        seed + order,
        reasoning,
        groupId,
        version,
        order,
      ],
    );
  }
}

final class ChatDatabaseV2BenchmarkMetrics {
  ChatDatabaseV2BenchmarkMetrics._();

  static Map<String, Object?> measure(
    ChatBenchmarkFixtureResult fixture, {
    int samples = 30,
  }) {
    if (fixture.dataset == ChatBenchmarkDataset.d6) return const {};
    final database = sqlite3.open(fixture.path, mode: OpenMode.readOnly);
    try {
      final conversationId =
          database
                  .select(
                    'SELECT id FROM conversation_rows ORDER BY id LIMIT 1;',
                  )
                  .single['id']
              as String;
      final openSamples = <int>[];
      final pageSamples = <int>[];
      final searchChinese2Samples = <int>[];
      final searchChinese4Samples = <int>[];
      final searchRareTailSamples = <int>[];
      for (var index = 0; index < samples; index++) {
        openSamples.add(
          _time(
            () => database.select(
              'SELECT * FROM message_rows WHERE conversation_id = ? '
              'ORDER BY message_order DESC LIMIT 50;',
              [conversationId],
            ),
          ),
        );
        pageSamples.add(
          _time(
            () => database.select(
              'SELECT * FROM message_rows WHERE conversation_id = ? '
              'AND message_order < ? ORDER BY message_order DESC LIMIT 50;',
              [conversationId, 1 << 30],
            ),
          ),
        );
        if (fixture.dataset == ChatBenchmarkDataset.d2) {
          searchChinese2Samples.add(
            _time(
              () => database.select(
                'SELECT id FROM message_rows WHERE content LIKE ? LIMIT 50;',
                ['%搜索%'],
              ),
            ),
          );
          searchChinese4Samples.add(
            _time(
              () => database.select(
                'SELECT id FROM message_rows WHERE content LIKE ? LIMIT 50;',
                ['%中文搜索%'],
              ),
            ),
          );
          searchRareTailSamples.add(
            _time(
              () => database.select(
                'SELECT id FROM message_rows WHERE content LIKE ? LIMIT 50;',
                ['%message 99999 seed%'],
              ),
            ),
          );
        }
      }
      return {
        'open50P50Micros': _percentile(openSamples, 0.50),
        'open50P95Micros': _percentile(openSamples, 0.95),
        'page50P50Micros': _percentile(pageSamples, 0.50),
        'page50P95Micros': _percentile(pageSamples, 0.95),
        if (searchChinese2Samples.isNotEmpty)
          'searchChinese2P95Micros': _percentile(searchChinese2Samples, 0.95),
        if (searchChinese4Samples.isNotEmpty)
          'searchChinese4P95Micros': _percentile(searchChinese4Samples, 0.95),
        if (searchRareTailSamples.isNotEmpty)
          'searchRareTailP95Micros': _percentile(searchRareTailSamples, 0.95),
      };
    } finally {
      database.close();
    }
  }

  static int _time(void Function() operation) {
    final watch = Stopwatch()..start();
    operation();
    watch.stop();
    return watch.elapsedMicroseconds;
  }

  static int _percentile(List<int> values, double percentile) {
    final sorted = [...values]..sort();
    final index = ((sorted.length - 1) * percentile).ceil();
    return sorted[index];
  }
}
