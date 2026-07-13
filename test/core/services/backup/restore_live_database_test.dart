import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/services/backup/restore_live_database.dart';

void main() {
  group('RestoreLiveDatabase', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'kelivo_restore_live_database_test_',
      );
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('preserves a completely missing database family', () async {
      final database = File(p.join(root.path, 'kelivo.db'));

      expect(
        await RestoreLiveDatabase.normalize(databaseFile: database),
        isFalse,
      );
      expect(await database.exists(), isFalse);
    });

    test('checkpoints a crash-style WAL family into one main file', () async {
      final source = File(p.join(root.path, 'source.sqlite'));
      final target = File(p.join(root.path, 'kelivo.db'));
      final open = sqlite.sqlite3.open(source.path);
      try {
        open.execute('PRAGMA journal_mode = WAL;');
        open.execute('PRAGMA wal_autocheckpoint = 0;');
        open.execute('CREATE TABLE items (value TEXT NOT NULL);');
        open.execute("INSERT INTO items VALUES ('from-wal');");
        await source.copy(target.path);
        await File('${source.path}-wal').copy('${target.path}-wal');
        await File('${source.path}-shm').copy('${target.path}-shm');
      } finally {
        open.close();
      }

      expect(await RestoreLiveDatabase.normalize(databaseFile: target), isTrue);

      expect(await File('${target.path}-wal').exists(), isFalse);
      expect(await File('${target.path}-shm').exists(), isFalse);
      final reopened = sqlite.sqlite3.open(
        target.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        expect(
          reopened.select('SELECT value FROM items;').single['value'],
          'from-wal',
        );
      } finally {
        reopened.close();
      }
    });

    test('normalizes WAL mode even after its sidecars disappeared', () async {
      final databaseFile = File(p.join(root.path, 'kelivo.db'));
      final database = sqlite.sqlite3.open(databaseFile.path);
      try {
        expect(
          database.select('PRAGMA journal_mode = WAL;').single.values.single,
          'wal',
        );
        database.execute('CREATE TABLE items (value TEXT NOT NULL);');
        database.execute("INSERT INTO items VALUES ('persisted');");
      } finally {
        database.close();
      }
      expect(await File('${databaseFile.path}-wal').exists(), isFalse);
      expect(await File('${databaseFile.path}-shm').exists(), isFalse);

      expect(
        await RestoreLiveDatabase.normalize(databaseFile: databaseFile),
        isTrue,
      );

      final reopened = sqlite.sqlite3.open(
        databaseFile.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        expect(
          reopened.select('PRAGMA journal_mode;').single.values.single,
          'delete',
        );
        expect(
          reopened.select('SELECT value FROM items;').single['value'],
          'persisted',
        );
      } finally {
        reopened.close();
      }
    });

    test('rejects an orphan sidecar without creating a new database', () async {
      final database = File(p.join(root.path, 'kelivo.db'));
      await File('${database.path}-wal').writeAsBytes([1], flush: true);

      await expectLater(
        RestoreLiveDatabase.normalize(databaseFile: database),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'restore_live_database_orphan_sidecar',
          ),
        ),
      );
      expect(await database.exists(), isFalse);
    });

    test('rejects linked main files without touching the target', () async {
      if (Platform.isWindows) return;
      final target = File(p.join(root.path, 'target.sqlite'));
      await target.writeAsString('not sqlite', flush: true);
      final link = Link(p.join(root.path, 'kelivo.db'));
      await link.create(target.path);

      await expectLater(
        RestoreLiveDatabase.normalize(databaseFile: File(link.path)),
        throwsA(isA<StateError>()),
      );
      expect(await target.readAsString(), 'not sqlite');
    });
  });
}
