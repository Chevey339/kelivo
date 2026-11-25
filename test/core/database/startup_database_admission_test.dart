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
        onStage: stage.complete,
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

  test(
    'a failed migration reports rollback before returning its error',
    () async {
      await createOldDatabase(file);
      final db = sqlite.sqlite3.open(file.path);
      // The v6 index creation must fail after the safety copy is durable.
      db.execute('CREATE TABLE generation_topic_rows (id TEXT PRIMARY KEY)');
      db.close();
      await expectLater(
        open(),
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
        DatabaseUpgradeStage.restoring,
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
