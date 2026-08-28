import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart'
    as sqlite
    show sqlite3, OpenMode, SqliteException;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';
import 'package:Kelivo/core/services/backup/backup_isolate_runner.dart';
import 'package:Kelivo/core/services/backup/restore_bundle_staging.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

import '../../database/generated_schema/schema_v1.dart' as v1;

Future<String> _manifestSha256(Directory extracted) async {
  return (await sha256
          .bind(File(p.join(extracted.path, 'manifest.json')).openRead())
          .first)
      .toString();
}

Future<Directory> _createExtractedBundle(
  Directory root, {
  bool includeDatabase = true,
  bool validDatabase = true,
  bool includeFiles = false,
  bool includeSettings = true,
}) async {
  final extracted = Directory(p.join(root.path, 'extracted'));
  await extracted.create(recursive: true);
  final settings = File(p.join(extracted.path, 'settings.json'));
  if (includeSettings) {
    await settings.writeAsString(jsonEncode({'theme': 'dark'}), flush: true);
  }
  final database = File(p.join(extracted.path, 'database', 'kelivo.db'));
  ChatDatabaseSnapshotInfo? databaseInfo;
  if (includeDatabase) {
    await database.parent.create(recursive: true);
    if (validDatabase) {
      final appDatabase = AppDatabase.open(file: database);
      try {
        await appDatabase.customSelect('SELECT 1;').get();
      } finally {
        await appDatabase.close();
      }
      databaseInfo = await ChatDatabaseRepository.prepareSnapshotForRestore(
        database,
      );
    } else {
      await database.writeAsBytes([1, 2, 3, 4], flush: true);
    }
  }
  await File(p.join(extracted.path, 'manifest.json')).writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': 2,
      'payloadKind': includeDatabase ? 'sqlite' : 'settings-only',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': 'test',
      'includeChats': includeDatabase,
      'includeFiles': includeFiles,
      'secretsIncluded': true,
      if (includeDatabase)
        'database': {
          'entry': 'database/kelivo.db',
          'schemaVersion':
              databaseInfo?.schemaVersion ?? AppDatabase.currentSchemaVersion,
          'conversationCount': databaseInfo?.conversationCount ?? 0,
          'messageCount': databaseInfo?.messageCount ?? 0,
        },
      'entries': {
        'settings.json': includeSettings
            ? {
                'bytes': await settings.length(),
                'sha256': (await sha256.bind(settings.openRead()).first)
                    .toString(),
              }
            : {'bytes': 2, 'sha256': List.filled(64, '0').join()},
        if (includeDatabase)
          'database/kelivo.db': {
            'bytes': await database.length(),
            'sha256': (await sha256.bind(database.openRead()).first).toString(),
          },
      },
    }),
    flush: true,
  );
  return extracted;
}

/// Builds an extracted bundle whose payload is a real schema-1 database, the
/// way a backup taken by an older build looks.
Future<Directory> _createLegacyV1Bundle(
  Directory root, {
  String conversationId = 'legacy-conv',
}) async {
  final extracted = Directory(p.join(root.path, 'extracted'));
  await extracted.create(recursive: true);
  final settings = File(p.join(extracted.path, 'settings.json'));
  await settings.writeAsString(jsonEncode({'theme': 'dark'}), flush: true);

  final database = File(p.join(extracted.path, 'database', 'kelivo.db'));
  await database.parent.create(recursive: true);
  final legacy = v1.DatabaseAtV1(NativeDatabase(database));
  try {
    await legacy.customStatement('PRAGMA user_version = 1;');
    await legacy.customStatement(
      'INSERT INTO conversation_rows '
      '(id, title, created_at, updated_at, is_pinned, truncate_index, '
      'version_selections_json, last_summarized_message_count, '
      'chat_suggestions_json, last_memory_extracted_order) '
      "VALUES ('$conversationId', 'Legacy chat', 1, 2, 0, -1, '{}', 0, "
      "'[]', -1);",
    );
    // A real archived snapshot has been through prepareSnapshotForRestore,
    // which stamps this receipt.
    await legacy.customStatement(
      'INSERT INTO chat_storage_meta_rows (key, value) '
      "VALUES ('hive_migration_complete_v1', 'true');",
    );
  } finally {
    await legacy.close();
  }
  // An archived snapshot arrives without sidecars and in DELETE mode.
  final raw = sqlite.sqlite3.open(database.path);
  try {
    raw.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    raw.select('PRAGMA journal_mode = DELETE;');
  } finally {
    raw.close();
  }
  for (final suffix in const ['-wal', '-shm']) {
    final sidecar = File('${database.path}$suffix');
    if (await sidecar.exists()) await sidecar.delete();
  }

  await File(p.join(extracted.path, 'manifest.json')).writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': 2,
      'payloadKind': 'sqlite',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': 'test',
      'includeChats': true,
      'includeFiles': false,
      'secretsIncluded': true,
      'database': {
        'entry': 'database/kelivo.db',
        'schemaVersion': 1,
        'conversationCount': 1,
        'messageCount': 0,
      },
      'entries': {
        'settings.json': {
          'bytes': await settings.length(),
          'sha256': (await sha256.bind(settings.openRead()).first).toString(),
        },
        'database/kelivo.db': {
          'bytes': await database.length(),
          'sha256': (await sha256.bind(database.openRead()).first).toString(),
        },
      },
    }),
    flush: true,
  );
  return extracted;
}

void main() {
  group('RestoreBundleStaging', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_staging_test_');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('stages a schema 1 payload by migrating it forward', () async {
      final extracted = await _createLegacyV1Bundle(root);

      final staged = await RestoreBundleStaging.create(
        appDataDirectory: root,
        extractedDirectory: extracted,
        includeChats: true,
        includeFiles: false,
        sourceManifestSha256: await _manifestSha256(extracted),
      );

      // The source manifest records the schema the backup was authored at; the
      // candidate records the schema after migration.
      final validated = await RestoreBundleStaging.validateExistingCandidate(
        candidateDirectory: staged.payloadDirectory,
        expectedManifestSha256: staged.candidateManifestSha256,
      );
      expect(
        validated.databaseInfo?.schemaVersion,
        AppDatabase.currentSchemaVersion,
      );
      // A migration must never add or drop rows.
      expect(validated.databaseInfo?.conversationCount, 1);
      expect(validated.databaseInfo?.messageCount, 0);

      final staler = File(
        p.join(staged.payloadDirectory.path, 'database', 'kelivo.db'),
      );
      final raw = sqlite.sqlite3.open(
        staler.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        final rows = raw.select(
          'SELECT id, chat_model_provider FROM conversation_rows;',
        );
        expect(rows, hasLength(1));
        expect(rows.single['id'], 'legacy-conv');
        expect(rows.single['chat_model_provider'], null);
      } finally {
        raw.close();
      }
    });

    test('stages a forward-compatible payload by stripping it down', () async {
      final extracted = await _createExtractedBundle(root);
      // Make the staged source look like it came from a newer build: extra
      // column, extra table, bumped user_version, and a manifest declaring
      // that this build may still read it.
      final database = File(p.join(extracted.path, 'database', 'kelivo.db'));
      final raw = sqlite.sqlite3.open(database.path);
      raw.execute('ALTER TABLE conversation_rows ADD COLUMN future_col TEXT;');
      raw.execute('CREATE TABLE future_rows (id TEXT PRIMARY KEY);');
      raw.userVersion = AppDatabase.currentSchemaVersion + 1;
      raw.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      raw.select('PRAGMA journal_mode = DELETE;');
      raw.close();

      await ChatDatabaseRepository.normalizeForwardCompatibleSnapshot(database);
      // The real pipeline rewrites the entry descriptor after preparing the
      // snapshot, because preparing rewrites the file.
      final manifestFile = File(p.join(extracted.path, 'manifest.json'));
      final manifestJson =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      (manifestJson['entries'] as Map)['database/kelivo.db'] = {
        'bytes': await database.length(),
        'sha256': (await sha256.bind(database.openRead()).first).toString(),
      };
      await manifestFile.writeAsString(jsonEncode(manifestJson), flush: true);

      final staged = await RestoreBundleStaging.create(
        appDataDirectory: root,
        extractedDirectory: extracted,
        includeChats: true,
        includeFiles: false,
        sourceManifestSha256: await _manifestSha256(extracted),
      );

      final validated = await RestoreBundleStaging.validateExistingCandidate(
        candidateDirectory: staged.payloadDirectory,
        expectedManifestSha256: staged.candidateManifestSha256,
      );
      expect(
        validated.databaseInfo?.schemaVersion,
        AppDatabase.currentSchemaVersion,
      );

      final candidate = File(
        p.join(staged.payloadDirectory.path, 'database', 'kelivo.db'),
      );
      final check = sqlite.sqlite3.open(
        candidate.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        expect(
          check
              .select('PRAGMA table_info(conversation_rows);')
              .map((r) => r['name']),
          isNot(contains('future_col')),
        );
        expect(
          check
              .select("SELECT name FROM sqlite_master WHERE type = 'table';")
              .map((r) => r['name']),
          isNot(contains('future_rows')),
        );
      } finally {
        check.close();
      }
    });

    test('binds a normalized candidate to a strict run identity', () async {
      final extracted = await _createExtractedBundle(root);

      final staged = await RestoreBundleStaging.create(
        appDataDirectory: root,
        extractedDirectory: extracted,
        includeChats: true,
        includeFiles: false,
        sourceManifestSha256: await _manifestSha256(extracted),
      );

      expect(staged.runId, matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(p.basename(staged.workspace.path), 'run_${staged.runId}');
      expect(p.basename(staged.payloadDirectory.path), 'candidate');
      final manifest = File(
        p.join(staged.payloadDirectory.path, 'manifest.json'),
      );
      expect(
        staged.candidateManifestSha256,
        (await sha256.bind(manifest.openRead()).first).toString(),
      );
      final validated = await RestoreBundleStaging.validateExistingCandidate(
        candidateDirectory: staged.payloadDirectory,
        expectedManifestSha256: staged.candidateManifestSha256,
      );
      expect(validated.includeChats, isTrue);
      expect(validated.entries.keys, ['database/kelivo.db']);
      expect(validated.databaseInfo, isNotNull);
      expect(
        await File(
          p.join(staged.payloadDirectory.path, 'settings.json'),
        ).exists(),
        isFalse,
      );
      expect(
        await root
            .list(recursive: true, followLinks: false)
            .where(
              (entry) => p.basename(entry.path).startsWith('.restore_probe_'),
            )
            .toList(),
        isEmpty,
      );
    });

    test('removes its run workspace when candidate creation fails', () async {
      final extracted = await _createExtractedBundle(
        root,
        includeSettings: false,
      );

      await expectLater(
        RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: true,
          includeFiles: false,
          sourceManifestSha256: await _manifestSha256(extracted),
        ),
        throwsA(isA<FormatException>()),
      );

      final workspaceRoot = Directory(
        p.join(root.path, RestoreBundleStaging.workspaceRootName),
      );
      expect(
        await workspaceRoot
            .list(followLinks: false)
            .where((entry) => p.basename(entry.path).startsWith('run_'))
            .toList(),
        isEmpty,
      );
    });

    test('blocks instead of deleting an existing orphan run', () async {
      final workspaceRoot = Directory(
        p.join(root.path, RestoreBundleStaging.workspaceRootName),
      );
      final orphan = Directory(
        p.join(workspaceRoot.path, 'run_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
      );
      await orphan.create(recursive: true);
      final marker = File(p.join(orphan.path, 'unknown'));
      await marker.writeAsString('preserve', flush: true);
      final extracted = await _createExtractedBundle(root);

      await expectLater(
        RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: true,
          includeFiles: false,
          sourceManifestSha256: await _manifestSha256(extracted),
        ),
        throwsStateError,
      );

      expect(await marker.readAsString(), 'preserve');
    });

    test('admits at most one concurrent staging run', () async {
      final extracted = await _createExtractedBundle(root);
      final manifestSha256 = await _manifestSha256(extracted);

      Future<Object> stage() async {
        try {
          return await RestoreBundleStaging.create(
            appDataDirectory: root,
            extractedDirectory: extracted,
            includeChats: true,
            includeFiles: false,
            sourceManifestSha256: manifestSha256,
          );
        } catch (error) {
          return error;
        }
      }

      final results = await Future.wait([stage(), stage()]);

      expect(results.whereType<StagedRestoreBundle>(), hasLength(1));
      expect(results.whereType<StateError>(), hasLength(1));
      final workspaceRoot = Directory(
        p.join(root.path, RestoreBundleStaging.workspaceRootName),
      );
      expect(
        await workspaceRoot
            .list(followLinks: false)
            .where((entry) => p.basename(entry.path).startsWith('run_'))
            .toList(),
        hasLength(1),
      );
    });

    test('admits at most one run across worker isolates', () async {
      final extracted = await _createExtractedBundle(root);
      final manifestSha256 = await _manifestSha256(extracted);
      final appDataPath = root.path;
      final extractedPath = extracted.path;

      Future<bool> stageInWorker() {
        return Isolate.run(() async {
          try {
            await RestoreBundleStaging.create(
              appDataDirectory: Directory(appDataPath),
              extractedDirectory: Directory(extractedPath),
              includeChats: true,
              includeFiles: false,
              sourceManifestSha256: manifestSha256,
            );
            return true;
          } catch (_) {
            return false;
          }
        });
      }

      final results = await Future.wait([stageInWorker(), stageInWorker()]);

      expect(results.where((result) => result), hasLength(1));
      expect(results.where((result) => !result), hasLength(1));
      final activeRun = File(
        p.join(
          root.path,
          RestoreBundleStaging.workspaceRootName,
          RestoreWorkspaceLock.activeRunFileName,
        ),
      );
      expect(await activeRun.length(), 32);
    });

    test('discards only a run that has not started publication', () async {
      final extracted = await _createExtractedBundle(root);
      final staged = await RestoreBundleStaging.create(
        appDataDirectory: root,
        extractedDirectory: extracted,
        includeChats: true,
        includeFiles: false,
        sourceManifestSha256: await _manifestSha256(extracted),
      );

      await RestoreBundleStaging.discardUnpublished(
        appDataDirectory: root,
        runId: staged.runId,
      );

      expect(await staged.workspace.exists(), isFalse);
    });

    test('preserves a run once a receipt directory exists', () async {
      final extracted = await _createExtractedBundle(root);
      final staged = await RestoreBundleStaging.create(
        appDataDirectory: root,
        extractedDirectory: extracted,
        includeChats: true,
        includeFiles: false,
        sourceManifestSha256: await _manifestSha256(extracted),
      );
      final receipts = Directory(p.join(staged.workspace.path, 'receipts'));
      await receipts.create();

      await expectLater(
        RestoreBundleStaging.discardUnpublished(
          appDataDirectory: root,
          runId: staged.runId,
        ),
        throwsStateError,
      );

      expect(await receipts.exists(), isTrue);
      expect(
        await File(
          p.join(
            root.path,
            RestoreBundleStaging.workspaceRootName,
            RestoreWorkspaceLock.activeRunFileName,
          ),
        ).readAsString(),
        staged.runId,
      );
      expect(
        await File(
          p.join(
            root.path,
            RestoreBundleStaging.workspaceRootName,
            RestoreWorkspaceLock.discardingRunFileName,
          ),
        ).exists(),
        isFalse,
      );
    });

    test('rejects a source entry changed after its descriptor froze', () async {
      final extracted = await _createExtractedBundle(root);
      await File(
        p.join(extracted.path, 'settings.json'),
      ).writeAsString(jsonEncode({'theme': 'changed'}), flush: true);

      await expectLater(
        RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: true,
          includeFiles: false,
          sourceManifestSha256: await _manifestSha256(extracted),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a manifest changed after preflight froze its hash', () async {
      final extracted = await _createExtractedBundle(root);
      final frozenManifestSha256 = await _manifestSha256(extracted);
      final manifestFile = File(p.join(extracted.path, 'manifest.json'));
      final manifest = jsonDecode(await manifestFile.readAsString()) as Map;
      manifest['appVersion'] = 'tampered';
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);

      await expectLater(
        RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: true,
          includeFiles: false,
          sourceManifestSha256: frozenManifestSha256,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown candidate manifest fields', () async {
      final extracted = await _createExtractedBundle(root);
      final manifestFile = File(p.join(extracted.path, 'manifest.json'));
      final manifest = jsonDecode(await manifestFile.readAsString()) as Map;
      manifest['futureField'] = true;
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);

      await expectLater(
        RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: true,
          includeFiles: false,
          sourceManifestSha256: await _manifestSha256(extracted),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a non-canonical declared asset path', () async {
      final extracted = await _createExtractedBundle(root);
      final manifestFile = File(p.join(extracted.path, 'manifest.json'));
      final manifest = jsonDecode(await manifestFile.readAsString()) as Map;
      manifest['includeFiles'] = true;
      final entries = manifest['entries'] as Map;
      entries['upload/../settings.json'] = entries['settings.json'];
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);

      await expectLater(
        RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: true,
          includeFiles: true,
          sourceManifestSha256: await _manifestSha256(extracted),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects oversized settings from metadata before copying', () async {
      final extracted = await _createExtractedBundle(root);
      final manifestFile = File(p.join(extracted.path, 'manifest.json'));
      final manifest = jsonDecode(await manifestFile.readAsString()) as Map;
      final settingsMetadata =
          (manifest['entries'] as Map)['settings.json'] as Map;
      settingsMetadata['bytes'] = 1024 * 1024 * 1024 + 1;
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);

      await expectLater(
        RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: true,
          includeFiles: false,
          sourceManifestSha256: await _manifestSha256(extracted),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid settings semantics before returning a run', () async {
      final extracted = await _createExtractedBundle(root);
      final settingsFile = File(p.join(extracted.path, 'settings.json'));
      await settingsFile.writeAsString(
        jsonEncode({
          'assistants_v1': jsonEncode(['not-an-object']),
        }),
        flush: true,
      );
      final manifestFile = File(p.join(extracted.path, 'manifest.json'));
      final manifest = jsonDecode(await manifestFile.readAsString()) as Map;
      final settingsMetadata =
          (manifest['entries'] as Map)['settings.json'] as Map;
      settingsMetadata['bytes'] = await settingsFile.length();
      settingsMetadata['sha256'] =
          (await sha256.bind(settingsFile.openRead()).first).toString();
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);

      await expectLater(
        RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: true,
          includeFiles: false,
          sourceManifestSha256: await _manifestSha256(extracted),
        ),
        throwsA(isA<FormatException>()),
      );

      final workspaceRoot = Directory(
        p.join(root.path, RestoreBundleStaging.workspaceRootName),
      );
      expect(
        await workspaceRoot
            .list(followLinks: false)
            .where((entry) => p.basename(entry.path).startsWith('run_'))
            .toList(),
        isEmpty,
      );
    });

    test('rejects the unpublished secret-free backup format', () async {
      final extracted = await _createExtractedBundle(root);
      final manifestFile = File(p.join(extracted.path, 'manifest.json'));
      final manifest = jsonDecode(await manifestFile.readAsString()) as Map;
      manifest['secretsIncluded'] = false;
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);

      await expectLater(
        RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: true,
          includeFiles: false,
          sourceManifestSha256: await _manifestSha256(extracted),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'restore_staging_manifest_fields',
          ),
        ),
      );

      final workspaceRoot = Directory(
        p.join(root.path, RestoreBundleStaging.workspaceRootName),
      );
      expect(
        await workspaceRoot
            .list(followLinks: false)
            .where((entry) => p.basename(entry.path).startsWith('run_'))
            .toList(),
        isEmpty,
      );
    });

    test('requires every declared empty asset root on revalidation', () async {
      final extracted = await _createExtractedBundle(root, includeFiles: true);
      final staged = await RestoreBundleStaging.create(
        appDataDirectory: root,
        extractedDirectory: extracted,
        includeChats: true,
        includeFiles: true,
        sourceManifestSha256: await _manifestSha256(extracted),
      );
      await Directory(p.join(staged.payloadDirectory.path, 'fonts')).delete();

      await expectLater(
        RestoreBundleStaging.validateExistingCandidate(
          candidateDirectory: staged.payloadDirectory,
          expectedManifestSha256: staged.candidateManifestSha256,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an extra empty candidate directory', () async {
      final extracted = await _createExtractedBundle(root, includeFiles: true);
      final staged = await RestoreBundleStaging.create(
        appDataDirectory: root,
        extractedDirectory: extracted,
        includeChats: true,
        includeFiles: true,
        sourceManifestSha256: await _manifestSha256(extracted),
      );
      await Directory(
        p.join(staged.payloadDirectory.path, 'upload', 'unexpected'),
      ).create();

      await expectLater(
        RestoreBundleStaging.validateExistingCandidate(
          candidateDirectory: staged.payloadDirectory,
          expectedManifestSha256: staged.candidateManifestSha256,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'rejects a hash-valid payload that is not a SQLite database',
      () async {
        final extracted = await _createExtractedBundle(
          root,
          includeDatabase: true,
          validDatabase: false,
        );

        await expectLater(
          RestoreBundleStaging.create(
            appDataDirectory: root,
            extractedDirectory: extracted,
            includeChats: true,
            includeFiles: false,
            sourceManifestSha256: await _manifestSha256(extracted),
          ),
          throwsA(isA<sqlite.SqliteException>()),
        );
      },
    );

    test('reuses validated settings without parsing settings.json', () async {
      final extracted = await _createExtractedBundle(root);
      final settingsFile = File(p.join(extracted.path, 'settings.json'));
      await settingsFile.writeAsString('not-json', flush: true);
      await _rewriteSettingsDescriptor(extracted, settingsFile);

      await expectLater(
        RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: true,
          includeFiles: false,
          sourceManifestSha256: await _manifestSha256(extracted),
        ),
        throwsA(isA<FormatException>()),
      );

      final staged = await RestoreBundleStaging.create(
        appDataDirectory: root,
        extractedDirectory: extracted,
        includeChats: true,
        includeFiles: false,
        sourceManifestSha256: await _manifestSha256(extracted),
        validatedSettings: const {'theme': 'dark'},
      );
      expect(staged.runId, isNotEmpty);
      expect(
        await Directory(
          p.join(root.path, RestoreBundleStaging.workspaceRootName),
        ).exists(),
        isTrue,
      );
    });

    test(
      'cancel during staging of a large file does not publish a candidate',
      () async {
        final extracted = await _createExtractedBundle(
          root,
          includeFiles: true,
        );
        final blob = File(p.join(extracted.path, 'upload', 'large.bin'));
        await blob.parent.create(recursive: true);
        await blob.writeAsBytes(
          List<int>.filled(4 * 1024 * 1024, 7),
          flush: true,
        );
        await _addDeclaredEntry(
          extracted,
          name: 'upload/large.bin',
          file: blob,
        );

        final token = BackupCancelToken();
        addTearDown(token.dispose);
        await expectLater(
          RestoreBundleStaging.create(
            appDataDirectory: root,
            extractedDirectory: extracted,
            includeChats: true,
            includeFiles: true,
            sourceManifestSha256: await _manifestSha256(extracted),
            cancelToken: token,
            onProgress: (progress) {
              if (progress.phase == BackupPhase.stagingCandidate &&
                  progress.processed >= 1) {
                token.cancel();
              }
            },
          ),
          throwsA(isA<BackupCancelledException>()),
        );

        final workspaceRoot = Directory(
          p.join(root.path, RestoreBundleStaging.workspaceRootName),
        );
        expect(
          await workspaceRoot
              .list(followLinks: false)
              .where((entry) => p.basename(entry.path).startsWith('run_'))
              .toList(),
          isEmpty,
        );
      },
    );

    test('UI heartbeat continues during candidate DB validation', () async {
      final extracted = await _createExtractedBundle(root);
      RestoreBundleStaging.debugCandidateDbStallMs = 120;
      addTearDown(() => RestoreBundleStaging.debugCandidateDbStallMs = 0);

      var inDb = false;
      var beats = 0;
      final heartbeat = Timer.periodic(const Duration(milliseconds: 5), (_) {
        if (inDb) beats++;
      });
      addTearDown(heartbeat.cancel);

      await RestoreBundleStaging.create(
        appDataDirectory: root,
        extractedDirectory: extracted,
        includeChats: true,
        includeFiles: false,
        sourceManifestSha256: await _manifestSha256(extracted),
        onProgress: (progress) {
          if (progress.detail == 'candidate-db') inDb = true;
        },
      );

      heartbeat.cancel();
      expect(inDb, isTrue);
      expect(beats, greaterThan(0));
    });

    test('cancel during candidate DB validation can return', () async {
      final extracted = await _createExtractedBundle(root);
      RestoreBundleStaging.debugCandidateDbStallMs = 800;
      addTearDown(() => RestoreBundleStaging.debugCandidateDbStallMs = 0);

      final token = BackupCancelToken();
      addTearDown(token.dispose);
      final started = DateTime.now();

      await expectLater(
        RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: true,
          includeFiles: false,
          sourceManifestSha256: await _manifestSha256(extracted),
          cancelToken: token,
          onProgress: (progress) {
            if (progress.detail == 'candidate-db') {
              token.cancel();
            }
          },
        ),
        throwsA(isA<BackupCancelledException>()),
      );
      expect(
        DateTime.now().difference(started) < const Duration(seconds: 2),
        isTrue,
      );
    });

    test(
      'does not delete candidate while the db isolate has not exited',
      () async {
        final extracted = await _createExtractedBundle(root);
        RestoreBundleStaging.debugCandidateDbHangSeconds = 2;
        RestoreBundleStaging.debugIsolateKillGrace = const Duration(
          milliseconds: 40,
        );
        RestoreBundleStaging.debugIsolateExitDeadline = const Duration(
          milliseconds: 80,
        );
        RestoreBundleStaging.debugIsolateTimeout = const Duration(
          milliseconds: 150,
        );
        debugSkipBackupIsolateKill = true;
        addTearDown(() {
          RestoreBundleStaging.debugCandidateDbHangSeconds = 0;
          RestoreBundleStaging.debugIsolateKillGrace = null;
          RestoreBundleStaging.debugIsolateExitDeadline = null;
          RestoreBundleStaging.debugIsolateTimeout = null;
          debugSkipBackupIsolateKill = false;
        });

        final token = BackupCancelToken();
        addTearDown(token.dispose);
        Directory? workspaceRoot;
        Object? error;
        try {
          await RestoreBundleStaging.create(
            appDataDirectory: root,
            extractedDirectory: extracted,
            includeChats: true,
            includeFiles: false,
            sourceManifestSha256: await _manifestSha256(extracted),
            cancelToken: token,
            onProgress: (progress) {
              if (progress.detail == 'candidate-db') {
                token.cancel();
              }
            },
          );
        } catch (e) {
          error = e;
        }

        expect(error, isNotNull);
        expect(backupIsolateStillAlive(error!), isTrue);
        workspaceRoot = Directory(
          p.join(root.path, RestoreBundleStaging.workspaceRootName),
        );
        final runs = await workspaceRoot
            .list(followLinks: false)
            .where((entry) => p.basename(entry.path).startsWith('run_'))
            .toList();
        expect(runs, isNotEmpty);

        final isolateExit = backupIsolateExitFuture(error);
        expect(isolateExit, isNotNull);
        await isolateExit!.timeout(const Duration(seconds: 5));
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (DateTime.now().isBefore(deadline)) {
          final remaining = await workspaceRoot
              .list(followLinks: false)
              .where((entry) => p.basename(entry.path).startsWith('run_'))
              .toList();
          if (remaining.isEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(
          await workspaceRoot
              .list(followLinks: false)
              .where((entry) => p.basename(entry.path).startsWith('run_'))
              .toList(),
          isEmpty,
        );
      },
    );

    test('UI heartbeat continues during final DB/hash revalidation', () async {
      final extracted = await _createExtractedBundle(root);
      RestoreBundleStaging.debugCandidateValidateStallMs = 120;
      addTearDown(() => RestoreBundleStaging.debugCandidateValidateStallMs = 0);

      var inRevalidate = false;
      var beats = 0;
      final heartbeat = Timer.periodic(const Duration(milliseconds: 5), (_) {
        if (inRevalidate) beats++;
      });
      addTearDown(heartbeat.cancel);

      await RestoreBundleStaging.create(
        appDataDirectory: root,
        extractedDirectory: extracted,
        includeChats: true,
        includeFiles: false,
        sourceManifestSha256: await _manifestSha256(extracted),
        onProgress: (progress) {
          if (progress.detail == 'candidate-revalidate') inRevalidate = true;
        },
      );

      heartbeat.cancel();
      expect(inRevalidate, isTrue);
      expect(beats, greaterThan(0));
    });

    test('cancel during final DB/hash revalidation can return', () async {
      final extracted = await _createExtractedBundle(root);
      RestoreBundleStaging.debugCandidateValidateStallMs = 800;
      addTearDown(() => RestoreBundleStaging.debugCandidateValidateStallMs = 0);

      final token = BackupCancelToken();
      addTearDown(token.dispose);
      final started = DateTime.now();

      await expectLater(
        RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: true,
          includeFiles: false,
          sourceManifestSha256: await _manifestSha256(extracted),
          cancelToken: token,
          onProgress: (progress) {
            if (progress.detail == 'candidate-revalidate') {
              token.cancel();
            }
          },
        ),
        throwsA(isA<BackupCancelledException>()),
      );
      expect(
        DateTime.now().difference(started) < const Duration(seconds: 2),
        isTrue,
      );
    });

    test(
      'does not delete candidate while the revalidation isolate has not exited',
      () async {
        final extracted = await _createExtractedBundle(root);
        RestoreBundleStaging.debugCandidateValidateHangSeconds = 2;
        RestoreBundleStaging.debugIsolateKillGrace = const Duration(
          milliseconds: 40,
        );
        RestoreBundleStaging.debugIsolateExitDeadline = const Duration(
          milliseconds: 80,
        );
        RestoreBundleStaging.debugIsolateTimeout = const Duration(
          milliseconds: 150,
        );
        debugSkipBackupIsolateKill = true;
        addTearDown(() {
          RestoreBundleStaging.debugCandidateValidateHangSeconds = 0;
          RestoreBundleStaging.debugIsolateKillGrace = null;
          RestoreBundleStaging.debugIsolateExitDeadline = null;
          RestoreBundleStaging.debugIsolateTimeout = null;
          debugSkipBackupIsolateKill = false;
        });

        final token = BackupCancelToken();
        addTearDown(token.dispose);
        Directory? workspaceRoot;
        Object? error;
        try {
          await RestoreBundleStaging.create(
            appDataDirectory: root,
            extractedDirectory: extracted,
            includeChats: true,
            includeFiles: false,
            sourceManifestSha256: await _manifestSha256(extracted),
            cancelToken: token,
            onProgress: (progress) {
              if (progress.detail == 'candidate-revalidate') {
                token.cancel();
              }
            },
          );
        } catch (e) {
          error = e;
        }

        expect(error, isNotNull);
        expect(backupIsolateStillAlive(error!), isTrue);
        workspaceRoot = Directory(
          p.join(root.path, RestoreBundleStaging.workspaceRootName),
        );
        final runs = await workspaceRoot
            .list(followLinks: false)
            .where((entry) => p.basename(entry.path).startsWith('run_'))
            .toList();
        expect(runs, isNotEmpty);

        final isolateExit = backupIsolateExitFuture(error);
        expect(isolateExit, isNotNull);
        await isolateExit!.timeout(const Duration(seconds: 5));
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (DateTime.now().isBefore(deadline)) {
          final remaining = await workspaceRoot
              .list(followLinks: false)
              .where((entry) => p.basename(entry.path).startsWith('run_'))
              .toList();
          if (remaining.isEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(
          await workspaceRoot
              .list(followLinks: false)
              .where((entry) => p.basename(entry.path).startsWith('run_'))
              .toList(),
          isEmpty,
        );
      },
    );

    test('chunked hash observes cancel between chunks', () async {
      final file = File(p.join(root.path, 'large.bin'));
      await file.writeAsBytes(
        List<int>.filled(2 * 1024 * 1024, 3),
        flush: true,
      );
      final token = BackupCancelToken()..cancel();
      addTearDown(token.dispose);

      await expectLater(
        RestoreBundleStaging.debugSha256(file, cancelToken: token),
        throwsA(isA<BackupCancelledException>()),
      );
    });
  });
}

Future<void> _rewriteSettingsDescriptor(
  Directory extracted,
  File settingsFile,
) async {
  await _addDeclaredEntry(extracted, name: 'settings.json', file: settingsFile);
}

Future<void> _addDeclaredEntry(
  Directory extracted, {
  required String name,
  required File file,
}) async {
  final manifestFile = File(p.join(extracted.path, 'manifest.json'));
  final manifest = jsonDecode(await manifestFile.readAsString()) as Map;
  final entries = (manifest['entries'] as Map).cast<String, dynamic>();
  entries[name] = {
    'bytes': await file.length(),
    'sha256': (await sha256.bind(file.openRead()).first).toString(),
  };
  await manifestFile.writeAsString(jsonEncode(manifest), flush: true);
}
