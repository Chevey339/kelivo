import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:Kelivo/core/services/backup/streaming_zip_entry.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Run in profile mode on the same device before and after a change. Assertions
// cover returned content; timing observations are deliberately not flaky gates.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Build with --dart-define=KELIVO_PERF_SCENE=/zip/256/stream (or archive)
  // to measure each decoder in a fresh process. Consecutive isolates share
  // allocator arenas, and Android's prewarmed engine ignores route intents.
  const sceneName = String.fromEnvironment('KELIVO_PERF_SCENE');
  final scene = sceneName.split('/');
  final zipOnly = scene.length == 4 && scene[1] == 'zip';
  testWidgets(
    'large history window growth',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('Large database benchmark'))),
        ),
      );
      final root = await Directory.systemTemp.createTemp('kelivo_large_data_');
      final results = <Map<String, Object?>>[];
      try {
        for (final scenario in [
          (1000, 0),
          (10000, 0),
          (100000, 0),
          (100000, 16384),
        ]) {
          final (count, historyBytes) = scenario;
          final db = AppDatabase.open(
            file: File('${root.path}/$count-$historyBytes.db'),
          );
          final repository = ChatDatabaseRepository(db);
          try {
            await repository.ensureReady();
            await db.customStatement(
              "INSERT INTO conversation_rows(id,title,created_at,updated_at) "
              "VALUES('bench','Performance',1,1)",
            );
            await db.customStatement(
              '''
WITH RECURSIVE seq(n) AS (VALUES(0) UNION ALL SELECT n+1 FROM seq WHERE n+1 < ?)
INSERT INTO message_rows(id,conversation_id,role,timestamp,message_order)
SELECT 'm-' || n,'bench',CASE WHEN n%2=0 THEN 'user' ELSE 'assistant' END,1,n
FROM seq
''',
              [count],
            );
            await db.customStatement('''
INSERT INTO message_part_rows(conversation_id,revision_id,ordinal,kind,payload,created_at,updated_at)
SELECT 'bench',id,0,'text','消息 ' || id || ' **Markdown**',1,1
FROM message_rows
''');
            if (historyBytes > 0) {
              await db.customStatement(
                'UPDATE message_part_rows SET payload=? WHERE revision_id IN '
                '(SELECT id FROM message_rows WHERE message_order < ?)',
                ['h' * historyBytes, count - 40],
              );
              await db.customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
            }
            final firstWatch = Stopwatch()..start();
            final initial = await repository.loadLinearMessageWindow(
              conversationId: 'bench',
              limit: 40,
            );
            final coldMicros = firstWatch.elapsedMicroseconds;
            expect(initial.totalSlotCount, count);
            expect(initial.slots.length, 40);
            expect(initial.slots.first.revisionId, 'm-${count - 40}');
            final samples = <int>[];
            final previous = <int>[];
            final around = <int>[];
            for (var sample = 0; sample < 5; sample++) {
              var watch = Stopwatch()..start();
              final page = await repository.loadLinearMessageWindow(
                conversationId: 'bench',
                limit: 40,
              );
              samples.add(watch.elapsedMicroseconds);
              expect(page.slots.last.revisionId, 'm-${count - 1}');
              watch = Stopwatch()..start();
              final before = await repository.loadLinearMessageWindow(
                conversationId: 'bench',
                beforeRevisionId: page.slots.first.revisionId,
                limit: 20,
              );
              previous.add(watch.elapsedMicroseconds);
              expect(before.slots.last.logicalIndex, count - 41);
              watch = Stopwatch()..start();
              final middle = await repository.loadLinearMessageWindow(
                conversationId: 'bench',
                aroundRevisionId: 'm-${count ~/ 2}',
                limit: 40,
              );
              around.add(watch.elapsedMicroseconds);
              expect(
                middle.slots.any((s) => s.revisionId == 'm-${count ~/ 2}'),
                isTrue,
              );
            }
            final bodies = await repository.getMessagesByIds(
              initial.slots.map((s) => s.revisionId).toList(),
            );
            expect(bodies, hasLength(40));
            expect(bodies.last.content, contains('m-${count - 1}'));
            final parts = await db
                .customSelect(
                  'SELECT COUNT(*) AS n FROM message_part_rows WHERE conversation_id = ?',
                  variables: [const Variable<String>('bench')],
                )
                .getSingle();
            expect(parts.read<int>('n'), count);
            int median(List<int> values) =>
                (values..sort())[values.length ~/ 2];
            final result = <String, Object?>{
              'messages': count,
              'historyBytesPerMessage': historyBytes,
              'databaseBytes': await File(
                '${root.path}/$count-$historyBytes.db',
              ).length(),
              'coldWindowMicros': coldMicros,
              'tailMedianMicros': median(samples),
              'previousMedianMicros': median(previous),
              'aroundMedianMicros': median(around),
              'rssBytes': ProcessInfo.currentRss,
            };
            results.add(result);
            // ignore: avoid_print
            print('LARGE_DATABASE_RESULT ${jsonEncode(result)}');
          } finally {
            await repository.close();
          }
        }
        binding.reportData = {
          ...?binding.reportData,
          'largeDatabase': results,
          'os': Platform.operatingSystem,
        };
      } finally {
        await root.delete(recursive: true);
      }
    },
    skip: zipOnly,
    timeout: const Timeout(Duration(minutes: 20)),
  );

  testWidgets(
    'inserting into versioned history keeps bulk reorder costs bounded',
    (tester) async {
      final root = await Directory.systemTemp.createTemp('kelivo_order_shift_');
      final results = <Map<String, Object?>>[];
      try {
        for (final count in [1000, 6000, 12000]) {
          for (final indexed in [false, true]) {
            final db = AppDatabase.open(
              file: File('${root.path}/$count-$indexed.db'),
            );
            final repository = ChatDatabaseRepository(db);
            try {
              await repository.ensureReady();
              await db.customStatement(
                "INSERT INTO conversation_rows(id,title,created_at,updated_at) VALUES('c','reorder',1,1)",
              );
              await db.customStatement(
                '''
WITH RECURSIVE seq(n) AS (VALUES(0) UNION ALL SELECT n+1 FROM seq WHERE n+1<?)
INSERT INTO message_rows(id,conversation_id,role,timestamp,message_order)
SELECT 'm'||n,'c',CASE WHEN n%2=0 THEN 'user' ELSE 'assistant' END,1,n FROM seq
''',
                [count],
              );
              await db.customStatement(
                '''
INSERT INTO message_rows(id,conversation_id,role,timestamp,message_order,group_id,version)
SELECT 'v'||message_order,'c','assistant',1,?+message_order/2,id,1
FROM message_rows WHERE role='assistant'
''',
                [count],
              );
              if (indexed) {
                await repository.loadLinearMessageWindow(
                  conversationId: 'c',
                  limit: 40,
                );
              }
              final physicalCount = count * 3 ~/ 2;
              final watch = Stopwatch()..start();
              await db.transaction(() async {
                await db.customStatement(
                  "UPDATE message_rows SET message_order=message_order+? WHERE conversation_id='c' AND message_order>0",
                  [physicalCount],
                );
                await db.customStatement(
                  "UPDATE message_rows SET message_order=message_order-?+1 WHERE conversation_id='c' AND message_order>?",
                  [physicalCount, physicalCount - 1],
                );
              });
              watch.stop();
              final tail = await repository.loadLinearMessageWindow(
                conversationId: 'c',
                limit: 40,
              );
              expect(tail.totalSlotCount, count);
              expect(tail.slots.last.revisionId, 'v${count - 1}');
              expect(await repository.getMessageCount('c'), physicalCount);
              final result = <String, Object?>{
                'logicalSlots': count,
                'physicalRows': physicalCount,
                'indexed': indexed,
                'shiftMicros': watch.elapsedMicroseconds,
              };
              results.add(result);
              // ignore: avoid_print
              print('BULK_REORDER_RESULT ${jsonEncode(result)}');
            } finally {
              await repository.close();
            }
          }
        }
        binding.reportData = {...?binding.reportData, 'bulkReorder': results};
      } finally {
        await root.delete(recursive: true);
      }
    },
    skip: zipOnly,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  testWidgets(
    'large ZIP entries retain complete output with bounded decoding',
    (tester) async {
      final root = await Directory.systemTemp.createTemp('kelivo_zip_memory_');
      final results = <Map<String, Object?>>[];
      try {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('ZIP memory benchmark'))),
        );
        for (final mib in zipOnly ? [int.parse(scene[2])] : [32, 256]) {
          final zip = '${root.path}/$mib.zip';
          final expected = await _createZipIsolated(zip, mib);
          for (final streaming
              in zipOnly ? [scene[3] == 'stream'] : [false, true]) {
            final result = await _measureZipIsolated(zip, streaming);
            expect(result['bytes'], mib * 1024 * 1024);
            expect(result['sha256'], expected);
            results.add(result);
            // ignore: avoid_print
            print('ZIP_MEMORY_RESULT ${jsonEncode(result)}');
          }
        }
        binding.reportData = {...?binding.reportData, 'zipMemory': results};
      } finally {
        await root.delete(recursive: true);
      }
    },
    skip: sceneName == '/database',
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<String> _createZipIsolated(String path, int mib) =>
    Isolate.run(() => _createZip(path, mib));

Future<Map<String, Object?>> _measureZipIsolated(String path, bool streaming) =>
    Isolate.run(() => _measureZip(path, streaming));

String _createZip(String path, int mib) {
  final file = File('$path.source');
  final output = file.openSync(mode: FileMode.write);
  final block = Uint8List(1024 * 1024);
  for (var i = 0; i < block.length; i++) {
    block[i] = i % 251;
  }
  final digest = _DigestResult();
  final hash = sha256.startChunkedConversion(digest);
  try {
    for (var i = 0; i < mib; i++) {
      output.writeFromSync(block);
      hash.add(block);
    }
  } finally {
    output.closeSync();
    hash.close();
  }
  final encoder = ZipFileEncoder()..create(path);
  try {
    encoder.addFileSync(file);
  } finally {
    encoder.closeSync();
  }
  file.deleteSync();
  return digest.value.toString();
}

Map<String, Object?> _measureZip(String path, bool streaming) {
  final input = InputFileStream(path);
  final archive = ZipDecoder().decodeStream(input);
  final digest = _DigestResult();
  final hash = sha256.startChunkedConversion(digest);
  final output = _MeasuredOutput(hash);
  final watch = Stopwatch()..start();
  final before = ProcessInfo.currentRss;
  try {
    if (streaming) {
      writeZipEntryStreaming(archive.single, output);
    } else {
      archive.single.writeContent(output);
    }
    hash.close();
    return {
      'streaming': streaming,
      'bytes': output.bytes,
      'sha256': digest.value.toString(),
      'rssBefore': before,
      'rssFirstOutput': output.firstRss,
      'rssPeakDuringOutput': output.peakRss,
      'elapsedMicros': watch.elapsedMicroseconds,
    };
  } finally {
    archive.clearSync();
    input.closeSync();
  }
}

final class _DigestResult implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

final class _MeasuredOutput extends OutputMemoryStream {
  _MeasuredOutput(this.hash);
  final Sink<List<int>> hash;
  int bytes = 0;
  int? firstRss;
  int peakRss = 0;
  @override
  void writeBytes(List<int> data, {int? length}) {
    final rss = ProcessInfo.currentRss;
    firstRss ??= rss;
    if (rss > peakRss) peakRss = rss;
    final chunk = length == null ? data : data.sublist(0, length);
    hash.add(chunk);
    bytes += chunk.length;
  }
}
