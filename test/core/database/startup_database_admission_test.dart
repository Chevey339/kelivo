import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:Kelivo/core/database/database_upgrade_io.dart';
import 'package:Kelivo/core/database/schema_migrations.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';

import '../../support/recovery_fault_durability.dart';
import 'generated_schema/schema_v5.dart' as v5;

Future<void> _waitForUi(
  SendPort reply,
  RestoreDurability durability,
  DatabaseUpgradeStageSink? report,
) async {
  final resume = ReceivePort();
  try {
    reply.send((Isolate.current.controlPort, resume.sendPort));
    report!(DatabaseUpgradeStage.updating);
    await resume.first;
  } finally {
    resume.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File file;
  late List<DatabaseUpgradeStage> stages;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'kelivo-upgrade-progress-',
    );
    file = File('${directory.path}/${AppDatabase.databaseFileName}');
    stages = [];
  });
  tearDown(() => directory.delete(recursive: true));

  Future<DatabaseInstallationReceipt> open() =>
      DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
        allowDatabaseIdentityChange: false,
        onUpgradeStage: stages.add,
      );

  Future<void> createOldDatabase(File target) async {
    final database = v5.DatabaseAtV5(NativeDatabase(target));
    try {
      await database.customStatement('PRAGMA user_version = 5');
      await database.customStatement(
        "INSERT INTO conversation_rows(id,title,created_at,updated_at) VALUES('saved','Chat',1,1)",
      );
    } finally {
      await database.close();
    }
  }

  test(
    'the UI receives progress while the disk worker is still busy',
    () async {
      final reply = ReceivePort();
      addTearDown(reply.close);
      final stage = Completer<DatabaseUpgradeStage>();
      final work = runDatabaseUpgradeIo(
        reply.sendPort,
        _waitForUi,
        durability: RestorePlatformDurability(),
        onStage: (value) {
          stage.complete(value);
          throw StateError('UI observer failed while the worker was waiting');
        },
      );
      final (worker, resume) = await reply.first as (SendPort, SendPort);
      try {
        expect(worker, isNot(Isolate.current.controlPort));
        expect(
          await stage.future.timeout(const Duration(seconds: 5)),
          DatabaseUpgradeStage.updating,
        );
      } finally {
        resume.send(null);
        await work;
      }
    },
  );

  test('fresh and up-to-date launches do not announce an upgrade', () async {
    final first = await open();
    expect(stages, isEmpty);
    expect((await open()).databaseId, first.databaseId);
    expect(stages, isEmpty);
  });

  for (final interrupted in [false, true]) {
    test(
      'reports the real upgrade stages (interrupted: $interrupted)',
      () async {
        await createOldDatabase(
          interrupted ? File('${file.path}.premigrate-v5') : file,
        );
        await open();
        expect(stages, [
          if (interrupted) ...[
            DatabaseUpgradeStage.checking,
            DatabaseUpgradeStage.restoring,
          ],
          DatabaseUpgradeStage.backingUp,
          DatabaseUpgradeStage.updating,
          DatabaseUpgradeStage.checking,
        ]);
        final db = sqlite.sqlite3.open(
          file.path,
          mode: sqlite.OpenMode.readOnly,
        );
        try {
          expect(db.userVersion, AppDatabase.currentSchemaVersion);
          expect(
            db.select('SELECT id FROM conversation_rows').single['id'],
            'saved',
          );
        } finally {
          db.close();
        }
      },
    );
  }

  for (final interrupted in [false, true]) {
    test(
      'a busy WAL survives upgrade and retry (interrupted: $interrupted)',
      () async {
        await createOldDatabase(file);
        final backup = File('${file.path}.premigrate-v5');
        final writer = sqlite.sqlite3.open(file.path);
        final reader = sqlite.sqlite3.open(file.path);
        try {
          writer.execute('PRAGMA journal_mode=WAL');
          writer.execute('PRAGMA wal_autocheckpoint=0');
          writer.select('PRAGMA wal_checkpoint(TRUNCATE)');
          if (interrupted) await file.copy(backup.path);
          reader.execute('BEGIN');
          reader.select('SELECT id FROM conversation_rows');
          writer.execute(
            "INSERT INTO conversation_rows(id,title,created_at,updated_at) VALUES('wal-only','New chat',2,2)",
          );
          expect(
            writer.select('PRAGMA wal_checkpoint(TRUNCATE)').single['busy'],
            1,
          );
          await expectLater(
            open(),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                'database_upgrade_busy',
              ),
            ),
          );
          expect(await backup.exists(), interrupted);
          expect(writer.userVersion, 5);
        } finally {
          reader.close();
          writer.close();
        }
        await open();
        final db = sqlite.sqlite3.open(
          file.path,
          mode: sqlite.OpenMode.readOnly,
        );
        try {
          expect(db.userVersion, AppDatabase.currentSchemaVersion);
          expect(
            db
                .select('SELECT id FROM conversation_rows ORDER BY id')
                .map((r) => r['id']),
            ['saved', 'wal-only'],
          );
        } finally {
          db.close();
        }
      },
    );
  }

  test(
    'an active rollback-journal writer can still commit after a refused upgrade',
    () async {
      await createOldDatabase(file);
      final writer = sqlite.sqlite3.open(file.path);
      try {
        writer.select('PRAGMA journal_mode=DELETE');
        writer.execute('BEGIN IMMEDIATE');
        writer.execute("UPDATE conversation_rows SET title='Active write'");
        await expectLater(
          open(),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'database_upgrade_busy',
            ),
          ),
        );
        expect(await File('${file.path}.premigrate-v5').exists(), isFalse);
        writer.execute('COMMIT');
      } finally {
        writer.close();
      }
      await open();
      final db = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
      try {
        expect(
          db.select('SELECT title FROM conversation_rows').single['title'],
          'Active write',
        );
      } finally {
        db.close();
      }
    },
  );

  test(
    'a writer is excluded from the backup through the migration rollback',
    () async {
      await createOldDatabase(file);
      final setup = sqlite.sqlite3.open(file.path);
      setup.select('PRAGMA journal_mode=WAL');
      setup.execute('CREATE TABLE generation_topic_rows (id TEXT PRIMARY KEY)');
      setup.close();
      var triedDuringBackup = false;
      final durability = FaultDurability()
        ..onSync = (copy) async {
          if (copy.path != '${file.path}.upgrade-copy.tmp') return;
          final writer = sqlite.sqlite3.open(file.path);
          try {
            expect(
              () => writer.execute(
                "UPDATE conversation_rows SET title='Concurrent'",
              ),
              throwsA(
                isA<sqlite.SqliteException>().having(
                  (error) => error.resultCode,
                  'resultCode',
                  sqlite.SqlError.SQLITE_BUSY,
                ),
              ),
            );
            triedDuringBackup = true;
          } finally {
            writer.close();
          }
        };
      await expectLater(
        DatabaseInstallationGate.ensureReady(
          appDataDirectory: directory,
          durability: durability,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_migration_failed:5',
          ),
        ),
      );
      expect(triedDuringBackup, isTrue);
      final writer = sqlite.sqlite3.open(file.path);
      try {
        expect(writer.userVersion, 5);
        expect(
          writer.select('SELECT title FROM conversation_rows').single['title'],
          'Chat',
        );
        writer.execute("UPDATE conversation_rows SET title='Concurrent'");
        expect(
          writer.select('SELECT title FROM conversation_rows').single['title'],
          'Concurrent',
        );
      } finally {
        writer.close();
      }
    },
  );

  for (final journal in ['DELETE', 'WAL']) {
    test(
      'a second process cannot grow a $journal database during upgrade',
      () async {
        await createOldDatabase(file);
        final setup = sqlite.sqlite3.open(file.path);
        setup.select('PRAGMA journal_mode=$journal');
        setup.close();
        String writeFromAnotherProcess() {
          final result = Process.runSync('python3', [
            '-c',
            '''
import sqlite3, sys
with sqlite3.connect(sys.argv[1], timeout=0) as db:
    try:
        db.execute("BEGIN IMMEDIATE")
        db.execute("UPDATE conversation_rows SET title=hex(zeroblob(131072))")
        db.commit()
        print("committed")
    except sqlite3.OperationalError as e:
        if "locked" not in str(e):
            raise
        print("busy")
''',
            file.path,
          ]);
          expect(result.exitCode, 0, reason: result.stderr.toString());
          return result.stdout.toString().trim();
        }

        final writes = <String>[];
        final io = FaultDurability()
          ..onSync = (copy) async {
            if (copy.path.endsWith('.upgrade-copy.tmp')) {
              writes.add(writeFromAnotherProcess());
            }
          };
        await DatabaseInstallationGate.ensureReady(
          appDataDirectory: directory,
          durability: io,
          onUpgradeStage: (stage) {
            if (stage == DatabaseUpgradeStage.checking) {
              writes.add(writeFromAnotherProcess());
            }
          },
        );
        expect(writes, ['busy', 'busy']);
        expect(writeFromAnotherProcess(), 'committed');
        final db = sqlite.sqlite3.open(
          file.path,
          mode: sqlite.OpenMode.readOnly,
        );
        try {
          expect(
            db
                .select('SELECT length(title) FROM conversation_rows')
                .single
                .values
                .single,
            262144,
          );
          expect(db.select('PRAGMA quick_check').single.values.single, 'ok');
          expect(db.select('PRAGMA foreign_key_check'), isEmpty);
        } finally {
          db.close();
        }
      },
      skip: !(Platform.isMacOS || Platform.isLinux)
          ? 'Uses a POSIX host process'
          : false,
    );
  }

  for (final customDurability in [false, true]) {
    test(
      'a failing progress observer cannot interrupt rollback (custom durability: $customDurability)',
      () async {
        await createOldDatabase(file);
        final db = sqlite.sqlite3.open(file.path);
        // The v6 index creation must fail after the safety copy is durable.
        db.execute('CREATE TABLE generation_topic_rows (id TEXT PRIMARY KEY)');
        db.close();
        await expectLater(
          DatabaseInstallationGate.ensureReady(
            appDataDirectory: directory,
            durability: customDurability ? FaultDurability() : null,
            onUpgradeStage: (stage) {
              stages.add(stage);
              throw StateError('progress failed');
            },
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'database_migration_failed:5',
            ),
          ),
        );
        expect(stages, [
          DatabaseUpgradeStage.backingUp,
          DatabaseUpgradeStage.updating,
          DatabaseUpgradeStage.checking,
        ]);
        final restored = sqlite.sqlite3.open(
          file.path,
          mode: sqlite.OpenMode.readOnly,
        );
        try {
          expect(restored.userVersion, 5);
          expect(
            restored.select('SELECT id FROM conversation_rows').single['id'],
            'saved',
          );
        } finally {
          restored.close();
        }
      },
    );
  }

  test(
    'a rejected newer schema keeps its error and triggers no upgrade UI',
    () async {
      await createOldDatabase(file);
      final db = sqlite.sqlite3.open(file.path);
      db.userVersion = AppDatabase.currentSchemaVersion + 1;
      db.close();
      await expectLater(
        open(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_schema_too_new',
          ),
        ),
      );
      expect(stages, isEmpty);
    },
  );
}
