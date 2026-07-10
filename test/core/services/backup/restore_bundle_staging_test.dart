import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'package:Kelivo/core/services/backup/restore_bundle_staging.dart';

Future<String> _manifestSha256(Directory extracted) async {
  return (await sha256
          .bind(File(p.join(extracted.path, 'manifest.json')).openRead())
          .first)
      .toString();
}

Future<Directory> _createExtractedBundle(
  Directory root, {
  bool includeDatabase = false,
  bool includeSettings = true,
}) async {
  final extracted = Directory(p.join(root.path, 'extracted'));
  await extracted.create(recursive: true);
  final settings = File(p.join(extracted.path, 'settings.json'));
  if (includeSettings) {
    await settings.writeAsString(jsonEncode({'theme': 'dark'}), flush: true);
  }
  final database = File(p.join(extracted.path, 'database', 'kelivo.sqlite'));
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
      'includeFiles': false,
      'secretsIncluded': false,
      if (includeDatabase)
        'database': {
          'entry': 'database/kelivo.sqlite',
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
          'database/kelivo.sqlite': {
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
