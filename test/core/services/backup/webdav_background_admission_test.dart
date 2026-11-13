import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/database_family_preserver.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';
import 'package:Kelivo/core/services/backup/webdav_background_backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  File databaseFile() =>
      File(p.join(directory.path, AppDatabase.databaseFileName));

  Future<DatabaseInstallationReceipt> install() =>
      DatabaseInstallationGate.ensureReady(appDataDirectory: directory);

  File receiptFile(DatabaseInstallationReceipt receipt) => File(
    p.join(
      directory.path,
      'database_installation_receipt_${receipt.databaseId}.json',
    ),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'kelivo_webdav_admission_',
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'admits a valid existing installation without rewriting its data',
    () async {
      final receipt = await install();
      final originalDatabase = await databaseFile().readAsBytes();
      final originalReceipt = await receiptFile(receipt).readAsString();

      expect(await WebDavBackgroundBackup.canOpenDatabase(directory), isTrue);

      expect(await databaseFile().readAsBytes(), originalDatabase);
      expect(await receiptFile(receipt).readAsString(), originalReceipt);
    },
  );

  test(
    'missing database is deferred without creating an empty installation',
    () async {
      expect(await WebDavBackgroundBackup.canOpenDatabase(directory), isFalse);
      expect(await databaseFile().exists(), isFalse);
      expect(await directory.list().isEmpty, isTrue);
    },
  );

  test(
    'missing installation receipt is deferred without adopting the database',
    () async {
      final receipt = await install();
      await receiptFile(receipt).delete();
      final original = await databaseFile().readAsBytes();

      expect(await WebDavBackgroundBackup.canOpenDatabase(directory), isFalse);

      expect(await receiptFile(receipt).exists(), isFalse);
      expect(await databaseFile().readAsBytes(), original);
    },
  );

  test(
    'mismatched installation identity is rejected without reassignment',
    () async {
      final receipt = await install();
      final originalReceipt = await receiptFile(receipt).readAsString();
      const replacementId = '31415926-5358-4979-9323-846264338327';
      final database = sqlite.sqlite3.open(databaseFile().path);
      try {
        database.execute(
          'UPDATE chat_storage_meta_rows SET value = ? WHERE key = ?',
          [replacementId, ChatStorageMetaKeys.databaseIdentity],
        );
      } finally {
        database.close();
      }

      await expectLater(
        WebDavBackgroundBackup.canOpenDatabase(directory),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_installation_receipt_match',
          ),
        ),
      );

      expect(await receiptFile(receipt).readAsString(), originalReceipt);
      expect(
        ChatDatabaseRepository.inspectInstalledDatabase(
          databaseFile(),
        ).databaseId,
        replacementId,
      );
    },
  );

  for (final marker in [
    DatabaseFamilyPreserver.pendingName,
    '${AppDatabase.databaseFileName}${ChatDatabaseRepository.premigrationBackupPrefix}2',
    RestoreWorkspaceLock.snapshotRecoveryMarkerName,
  ]) {
    test('defers $marker and leaves recovery evidence untouched', () async {
      await install();
      final evidence = File(p.join(directory.path, marker));
      await evidence.writeAsString('unfinished recovery');
      final original = await databaseFile().readAsBytes();

      expect(await WebDavBackgroundBackup.canOpenDatabase(directory), isFalse);

      expect(await evidence.readAsString(), 'unfinished recovery');
      expect(await databaseFile().readAsBytes(), original);
    });
  }

  test(
    'pending restore is deferred before validating or modifying its receipt',
    () async {
      await install();
      final workspace = Directory(
        p.join(directory.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      final marker = File(
        p.join(workspace.path, RestoreWorkspaceLock.activeRunFileName),
      );
      await marker.writeAsString('unfinished restore');

      expect(await WebDavBackgroundBackup.canOpenDatabase(directory), isFalse);
      expect(await marker.readAsString(), 'unfinished restore');
    },
  );

  test(
    'malformed restore workspace is rejected despite an empty cheap probe',
    () async {
      await install();
      final workspace = File(
        p.join(directory.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.writeAsString('not a directory');

      await expectLater(
        WebDavBackgroundBackup.canOpenDatabase(directory),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'restore_startup_workspace_root',
          ),
        ),
      );
      expect(await workspace.readAsString(), 'not a directory');
    },
  );

  test('newer schema is rejected without running a migration', () async {
    await install();
    final database = sqlite.sqlite3.open(databaseFile().path);
    try {
      database.userVersion = AppDatabase.currentSchemaVersion + 1;
    } finally {
      database.close();
    }
    final original = await databaseFile().readAsBytes();

    await expectLater(
      WebDavBackgroundBackup.canOpenDatabase(directory),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'database_schema_too_new',
        ),
      ),
    );
    expect(await databaseFile().readAsBytes(), original);
  });

  test(
    'empty live database cannot hide unreadable local recovery data',
    () async {
      await install();
      final recovery = File(
        '${databaseFile().path}${DatabaseInstallationGate.displacedDatabasePrefix}20261022123456',
      );
      await recovery.writeAsString('unreadable recovery data');
      final original = await databaseFile().readAsBytes();

      await expectLater(
        WebDavBackgroundBackup.canOpenDatabase(directory),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_empty_with_recovery_copies',
          ),
        ),
      );
      expect(await recovery.readAsString(), 'unreadable recovery data');
      expect(await databaseFile().readAsBytes(), original);
    },
  );
}
