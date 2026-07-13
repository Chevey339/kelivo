import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'package:Kelivo/core/services/backup/restore_bundle_staging.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

Future<String> _manifestSha256(Directory extracted) async {
  return (await sha256
          .bind(File(p.join(extracted.path, 'manifest.json')).openRead())
          .first)
      .toString();
}

Future<Directory> _createExtractedBundle(
  Directory root, {
  bool includeDatabase = false,
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
  if (includeDatabase) {
    await database.parent.create(recursive: true);
    await database.writeAsBytes([1, 2, 3, 4], flush: true);
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
      'secretsIncluded': false,
      if (includeDatabase)
        'database': {
          'entry': 'database/kelivo.db',
          'schemaVersion': 1,
          'conversationCount': 0,
          'messageCount': 0,
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

void main() {
  group('RestoreBundleStaging', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_staging_test_');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('binds a normalized candidate to a strict run identity', () async {
      final extracted = await _createExtractedBundle(root);

      final staged = await RestoreBundleStaging.create(
        appDataDirectory: root,
        extractedDirectory: extracted,
        includeChats: false,
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
      expect(validated.secretsIncluded, isFalse);
      expect(validated.settings, {'theme': 'dark'});
      expect(validated.entries.keys, ['settings.json']);
      expect(validated.databaseInfo, isNull);
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
          includeChats: false,
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
          includeChats: false,
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
            includeChats: false,
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
              includeChats: false,
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
        includeChats: false,
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
        includeChats: false,
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
          includeChats: false,
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
      manifest['secretsIncluded'] = true;
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);

      await expectLater(
        RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: false,
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
          includeChats: false,
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
          includeChats: false,
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
      settingsMetadata['bytes'] = 16 * 1024 * 1024 + 1;
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);

      await expectLater(
        RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: false,
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
          includeChats: false,
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

    test(
      'rejects a falsely declared secret-free candidate before publication',
      () async {
        final extracted = await _createExtractedBundle(root);
        final settingsFile = File(p.join(extracted.path, 'settings.json'));
        await settingsFile.writeAsString(
          jsonEncode({'global_proxy_password_v1': 'source-secret'}),
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
            includeChats: false,
            includeFiles: false,
            sourceManifestSha256: await _manifestSha256(extracted),
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'restore_settings_not_secret_free',
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
      },
    );

    test('requires every declared empty asset root on revalidation', () async {
      final extracted = await _createExtractedBundle(root, includeFiles: true);
      final staged = await RestoreBundleStaging.create(
        appDataDirectory: root,
        extractedDirectory: extracted,
        includeChats: false,
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
        includeChats: false,
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
        );

        await expectLater(
          RestoreBundleStaging.create(
            appDataDirectory: root,
            extractedDirectory: extracted,
            includeChats: true,
            includeFiles: false,
            sourceManifestSha256: await _manifestSha256(extracted),
          ),
          throwsA(isA<SqliteException>()),
        );
      },
    );
  });
}
