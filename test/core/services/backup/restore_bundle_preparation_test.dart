import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_bundle_preparation.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

Future<({Directory directory, String manifestSha256})> _createBundle(
  Directory root, {
  bool includeFiles = false,
}) async {
  final directory = Directory(p.join(root.path, 'extracted'));
  await directory.create();
  final settings = File(p.join(directory.path, 'settings.json'));
  await settings.writeAsString('{"theme":"dark"}', flush: true);
  final entries = <String, Map<String, Object>>{
    'settings.json': {
      'bytes': await settings.length(),
      'sha256': (await sha256.bind(settings.openRead()).first).toString(),
    },
  };
  if (includeFiles) {
    final asset = File(p.join(directory.path, 'upload', 'note.txt'));
    await asset.parent.create();
    await asset.writeAsString('asset', flush: true);
    entries['upload/note.txt'] = {
      'bytes': await asset.length(),
      'sha256': (await sha256.bind(asset.openRead()).first).toString(),
    };
  }
  final manifest = File(p.join(directory.path, 'manifest.json'));
  await manifest.writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': 2,
      'payloadKind': 'settings-only',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': 'test',
      'includeChats': false,
      'includeFiles': includeFiles,
      'secretsIncluded': false,
      'entries': entries,
    }),
    flush: true,
  );
  return (
    directory: directory,
    manifestSha256: (await sha256.bind(manifest.openRead()).first).toString(),
  );
}

void main() {
  group('RestoreBundlePreparation', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'kelivo_restore_preparation_test_',
      );
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('publishes a prepared receipt and retains the candidate', () async {
      final bundle = await _createBundle(root);

      final prepared = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: true,
        restoreFiles: true,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );

      expect(prepared.receipt.state, RestoreReceiptState.prepared);
      expect(prepared.receipt.selectedComponents, {RestoreComponent.settings});
      expect(await prepared.candidateDirectory.exists(), isTrue);
      final store = RestoreReceiptStore(
        appDataDirectory: root,
        runId: prepared.runId,
      );
      expect((await store.readLatest())?.checksum, prepared.receipt.checksum);
    });

    test('stages only requested components from a larger bundle', () async {
      final bundle = await _createBundle(root, includeFiles: true);

      final prepared = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: true,
        restoreChats: true,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );

      expect(prepared.receipt.selectedComponents, {RestoreComponent.settings});
      expect(
        await File(
          p.join(prepared.candidateDirectory.path, 'upload', 'note.txt'),
        ).exists(),
        isFalse,
      );
      for (final rootName in const ['upload', 'images', 'avatars', 'fonts']) {
        expect(
          await Directory(
            p.join(prepared.candidateDirectory.path, rootName),
          ).exists(),
          isFalse,
        );
      }
      final candidateManifest =
          jsonDecode(
                await File(
                  p.join(prepared.candidateDirectory.path, 'manifest.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(candidateManifest['includeFiles'], isFalse);
      expect((candidateManifest['entries'] as Map<String, dynamic>).keys, [
        'settings.json',
      ]);
    });

    test('records requested assets when the bundle includes files', () async {
      final bundle = await _createBundle(root, includeFiles: true);

      final prepared = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: true,
        restoreChats: false,
        restoreFiles: true,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );

      expect(prepared.receipt.selectedComponents, {
        RestoreComponent.settings,
        RestoreComponent.assets,
      });
    });

    test('cleans its run when receipt construction fails', () async {
      final bundle = await _createBundle(root);

      await expectLater(
        RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime(2026, 7, 9, 12),
        ),
        throwsArgumentError,
      );

      final workspaceRoot = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      expect(
        await workspaceRoot
            .list(followLinks: false)
            .where((entry) => p.basename(entry.path).startsWith('run_'))
            .toList(),
        isEmpty,
      );
      expect(
        await File(
          p.join(workspaceRoot.path, RestoreWorkspaceLock.activeRunFileName),
        ).exists(),
        isFalse,
      );
    });

    test('admits at most one concurrent prepared bundle', () async {
      final bundle = await _createBundle(root);

      Future<Object> prepare() async {
        try {
          return await RestoreBundlePreparation.prepare(
            appDataDirectory: root,
            extractedDirectory: bundle.directory,
            sourceManifestSha256: bundle.manifestSha256,
            bundleIncludesChats: false,
            bundleIncludesFiles: false,
            restoreChats: false,
            restoreFiles: false,
            createdAtUtc: DateTime.utc(2026, 7, 9, 12),
          );
        } catch (error) {
          return error;
        }
      }

      final results = await Future.wait([prepare(), prepare()]);

      expect(results.whereType<PreparedRestoreBundle>(), hasLength(1));
      expect(results.whereType<StateError>(), hasLength(1));
    });
  });
}
