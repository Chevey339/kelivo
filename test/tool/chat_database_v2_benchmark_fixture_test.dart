import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../tool/src/chat_database_v2_benchmark_fixture.dart';

void main() {
  group('P0 benchmark fixture', () {
    test('D1-D6 full plans freeze required scales', () {
      expect(ChatDatabaseV2BenchmarkFixture.plan(ChatBenchmarkDataset.d1), (
        conversations: 50,
        logicalMessages: 5000,
        physicalMessages: 5000,
        description: 'regular text and tool calls',
      ));
      expect(
        ChatDatabaseV2BenchmarkFixture.plan(
          ChatBenchmarkDataset.d2,
        ).logicalMessages,
        100000,
      );
      expect(ChatDatabaseV2BenchmarkFixture.plan(ChatBenchmarkDataset.d3), (
        conversations: 1,
        logicalMessages: 10000,
        physicalMessages: 10617,
        description: '10000 slots with 1/20/100/500 revision slots',
      ));
      expect(
        ChatDatabaseV2BenchmarkFixture.plan(
          ChatBenchmarkDataset.d4,
        ).description,
        contains('1 MiB'),
      );
      expect(
        ChatDatabaseV2BenchmarkFixture.plan(
          ChatBenchmarkDataset.d5,
        ).description,
        contains('100 4K'),
      );
      expect(
        ChatDatabaseV2BenchmarkFixture.plan(
          ChatBenchmarkDataset.d6,
        ).description,
        contains('corrupt'),
      );
    });

    test('plan digest is deterministic and dataset-specific', () {
      const expected = {
        ChatBenchmarkDataset.d1:
            'b805cf381d3fc368daed6bc1db8e12afb37b1bc0def4e6eaca0edf56b3ae50e7',
        ChatBenchmarkDataset.d2:
            'bc0ffaf0014dc29f9a8177be368c9f5d8dda77ef57bad197c559edeec456e854',
        ChatBenchmarkDataset.d3:
            '63435d9714972631f792f70f819cc4915df856a67621605099ddf5993c731aad',
        ChatBenchmarkDataset.d4:
            '84becae2895559d1ef28d20927d96e3fda1a2cdfa9783ed3599dc9400bcec8cf',
        ChatBenchmarkDataset.d5:
            '417dbe17adb696b5f92c25bf52ca1ccd47880d79b66f04f22bda881d1028093c',
        ChatBenchmarkDataset.d6:
            '35716820727014bafcbfe9064c9534cfd9b4f08179a04603295e3416101e4392',
      };
      for (final entry in expected.entries) {
        expect(
          ChatDatabaseV2BenchmarkFixture.planDigest(entry.key),
          entry.value,
        );
      }
    });

    test('smoke SQLite fixture has stable counts and associations', () async {
      final directory = await Directory.systemTemp.createTemp(
        'kelivo_benchmark_smoke_',
      );
      addTearDown(() => directory.delete(recursive: true));

      final result = await ChatDatabaseV2BenchmarkFixture.generate(
        dataset: ChatBenchmarkDataset.d1,
        outputDirectory: directory,
        smoke: true,
      );

      expect(result.conversations, 2);
      expect(result.logicalMessages, 100);
      expect(result.physicalMessages, 100);
      final database = sqlite.sqlite3.open(
        result.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        expect(database.select('PRAGMA foreign_key_check;'), isEmpty);
        expect(
          database
              .select('SELECT COUNT(*) FROM tool_event_rows;')
              .single
              .values
              .single,
          10,
        );
      } finally {
        database.close();
      }
    });

    test('D6 emits named malformed recovery artifacts', () async {
      final directory = await Directory.systemTemp.createTemp(
        'kelivo_benchmark_d6_',
      );
      addTearDown(() => directory.delete(recursive: true));

      final result = await ChatDatabaseV2BenchmarkFixture.generate(
        dataset: ChatBenchmarkDataset.d6,
        outputDirectory: directory,
      );
      final names = Directory(
        result.path,
      ).listSync().map((entity) => entity.uri.pathSegments.last).toSet();

      expect(
        names,
        containsAll({
          'inconsistent.sqlite',
          'truncated.sqlite-wal',
          'truncated.zip',
          'legacy_bad_chats.json',
          'manifest.json',
        }),
      );
    });
  });
}
