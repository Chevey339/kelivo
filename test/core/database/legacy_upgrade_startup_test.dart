import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_gateway.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:Kelivo/features/migration/hive_to_sqlite_migration_service.dart';

import 'generated_schema/schema.dart';

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

/// Reproduces the device state that fails closed on a schema upgrade: an
/// installed database a schema behind, its installation receipt, and the legacy
/// Hive files that a completed Hive migration deliberately leaves on disk.
///
/// Every user who ever migrated from Hive is in this state, so the startup
/// sequence below is the one that runs on their first launch of a release that
/// publishes a new schema. The database is built from the generated schema for
/// each published version rather than by stamping `user_version` onto a
/// current-schema file, so a future version genuinely exercises its own upgrade.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const databaseId = 'fad818d5-d208-48e6-8d1a-c00b2a62dcb9';
  const installationId = '2f4a2c05-6b1e-4a7d-9c3f-8e0d1b2a3c4d';
  const conversationId = 'conversation-legacy';

  // The schema-1 column set. Later versions may only add columns that are
  // nullable or defaulted, so this insert stays valid at every version.
  const insertConversation =
      'INSERT INTO conversation_rows '
      '(id, title, created_at, updated_at, is_pinned, truncate_index, '
      'version_selections_json, last_summarized_message_count, '
      "chat_suggestions_json, last_memory_extracted_order) VALUES "
      "('$conversationId', 'Migrated chat', 1, 2, 0, -1, '{}', 0, '[]', -1);";

  late Directory directory;
  late PathProviderPlatform previousPathProvider;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo_legacy_upgrade_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(directory.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  File databaseFile() =>
      File(p.join(directory.path, AppDatabase.databaseFileName));

  /// Installs a database built at [schemaVersion] together with everything a
  /// device that came from Hive carries.
  ///
  /// When [hotWal] is set the write-ahead log is left unfolded and its `-shm`
  /// discarded, which is what a crashed launch leaves behind — the shape the
  /// receipt read has to survive without reporting corruption.
  Future<void> seedHiveMigratedInstall(
    int schemaVersion, {
    required bool hotWal,
  }) async {
    final staging = await Directory(p.join(directory.path, 'staging')).create();
    final stagedFile = File(p.join(staging.path, AppDatabase.databaseFileName));
    final database = GeneratedHelper().databaseForVersion(
      NativeDatabase(stagedFile),
      schemaVersion,
    );
    try {
      await database.customStatement('PRAGMA user_version = $schemaVersion;');
      await database.customStatement(insertConversation);
    } finally {
      await database.close();
    }

    final raw = sqlite.sqlite3.open(stagedFile.path);
    raw.select('PRAGMA journal_mode = WAL;');
    for (final entry in const {
      ChatStorageMetaKeys.hiveMigrationComplete: 'true',
      ChatStorageMetaKeys.databaseIdentity: databaseId,
    }.entries) {
      raw.execute(
        'INSERT OR REPLACE INTO chat_storage_meta_rows (key, value) '
        'VALUES (?, ?);',
        [entry.key, entry.value],
      );
    }

    Future<void> install() async {
      await stagedFile.copy(databaseFile().path);
      // -shm is rebuilt on demand; a crash rarely leaves a usable one.
      final wal = File('${stagedFile.path}-wal');
      if (hotWal && wal.existsSync()) {
        await wal.copy('${databaseFile().path}-wal');
      }
    }

    if (hotWal) {
      // Copy while the connection is open: closing it would fold the WAL back
      // into the database and destroy the state under test.
      await install();
      raw.close();
    } else {
      raw.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      raw.select('PRAGMA journal_mode = DELETE;');
      raw.close();
      await install();
    }
    await staging.delete(recursive: true);

    await File(
      p.join(directory.path, 'database_installation_receipt_$databaseId.json'),
    ).writeAsString(
      jsonEncode({
        'version': 1,
        'installationId': installationId,
        'databaseId': databaseId,
      }),
    );

    // The Hive migration keeps its sources; they are what made the legacy
    // check open the database in the first place.
    for (final name in const [
      'conversations.hive',
      'messages.hive',
      'tool_events_v1.hive',
    ]) {
      await File(p.join(directory.path, name)).writeAsString('legacy');
    }
  }

  Future<void> expectStartupSucceeds() async {
    // 1. The legacy check, which used to open a live connection here and throw
    //    DriftRemoteException('database_schema_version').
    final decision = await HiveToSqliteMigrationService.check();
    expect(decision.needsMigration, isFalse);

    // 2. Admission, which is what may upgrade the schema.
    final receipt = await DatabaseInstallationGate.ensureReady(
      appDataDirectory: directory,
    );
    expect(receipt.databaseId, databaseId);
    expect(receipt.installationId, installationId);
    expect(
      ChatDatabaseRepository.inspectInstalledDatabase(
        databaseFile(),
      ).schemaVersion,
      AppDatabase.currentSchemaVersion,
    );

    // 3. The live connection, now that the file is at the current schema.
    final lease = await ChatDatabaseGateway.instance.acquire(databaseFile());
    try {
      final contract = await lease.repository.validateConnectionContract();
      expect(contract.schemaVersion, AppDatabase.currentSchemaVersion);
    } finally {
      await lease.release();
    }

    final raw = sqlite.sqlite3.open(
      databaseFile().path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      final rows = raw.select('SELECT id FROM conversation_rows;');
      expect(rows.map((row) => row['id']), [conversationId]);
    } finally {
      raw.close();
    }
  }

  test('every published schema has a generated schema to build from', () {
    // Without this, a new published version would silently fall back to
    // whatever shape the generated helper still knows about.
    expect(GeneratedHelper.versions, AppDatabase.publishedSchemaVersions);
  });

  for (final schemaVersion in AppDatabase.publishedSchemaVersions) {
    test('a Hive-migrated schema-$schemaVersion install starts', () async {
      await seedHiveMigratedInstall(schemaVersion, hotWal: false);
      await expectStartupSucceeds();
    });

    test(
      'a Hive-migrated schema-$schemaVersion install starts with a hot WAL',
      () async {
        await seedHiveMigratedInstall(schemaVersion, hotWal: true);
        expect(File('${databaseFile().path}-wal').existsSync(), isTrue);
        await expectStartupSucceeds();
      },
    );
  }
}
