import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_bundle_preparation.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

Future<({Directory directory, String manifestSha256})> _createBundle(
  Directory root,
) async {
  final directory = Directory(p.join(root.path, 'extracted'));
  await directory.create();
  final settings = File(p.join(directory.path, 'settings.json'));
  await settings.writeAsString('{"theme":"dark"}', flush: true);
  final manifest = File(p.join(directory.path, 'manifest.json'));
  await manifest.writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': 2,
      'payloadKind': 'settings-only',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': 'test',
      'includeChats': false,
      'includeFiles': false,
      'secretsIncluded': false,
      'entries': {
        'settings.json': {
          'bytes': await settings.length(),
          'sha256': (await sha256.bind(settings.openRead()).first).toString(),
        },
      },
    }),
    flush: true,
  );
  return (
    directory: directory,
    manifestSha256: (await sha256.bind(manifest.openRead()).first).toString(),
  );
}

void main() {
  group('RestoreStartupGate', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'kelivo_restore_startup_gate_test_',
      );
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('allows startup when no restore run exists', () async {
      expect(await RestoreStartupGate.inspect(appDataDirectory: root), isNull);

      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      await File(
        p.join(workspace.path, RestoreWorkspaceLock.lockFileName),
      ).create();

      expect(await RestoreStartupGate.inspect(appDataDirectory: root), isNull);
      await RestoreStartupGate.requireBusinessReady(appDataDirectory: root);
    });

    test(
      'recognizes a valid prepared run and blocks business startup',
      () async {
        final bundle = await _createBundle(root);
        final prepared = await RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        );

        final pending = await RestoreStartupGate.inspect(
          appDataDirectory: root,
        );

        expect(pending?.runId, prepared.runId);
        expect(pending?.receipt.checksum, prepared.receipt.checksum);
        await expectLater(
          RestoreStartupGate.requireBusinessReady(appDataDirectory: root),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('recognizes an interrupted publication phase marker', () async {
      final bundle = await _createBundle(root);
      final prepared = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );
      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await File(
        p.join(workspace.path, RestoreWorkspaceLock.activeRunFileName),
      ).rename(
        p.join(workspace.path, RestoreWorkspaceLock.publishingRunFileName),
      );

      final pending = await RestoreStartupGate.inspect(appDataDirectory: root);

      expect(pending?.runId, prepared.runId);
      expect(
        pending?.markerFileName,
        RestoreWorkspaceLock.publishingRunFileName,
      );
    });

    test('rejects a prepared run whose candidate changed', () async {
      final bundle = await _createBundle(root);
      final prepared = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );
      await File(
        p.join(prepared.candidateDirectory.path, 'settings.json'),
      ).writeAsString('{"theme":"changed"}', flush: true);

      await expectLater(
        RestoreStartupGate.inspect(appDataDirectory: root),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown workspace entries', () async {
      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      await File(p.join(workspace.path, 'unknown')).writeAsString('value');

      await expectLater(
        RestoreStartupGate.inspect(appDataDirectory: root),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects a marker without its matching run directory', () async {
      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      await File(
        p.join(workspace.path, RestoreWorkspaceLock.activeRunFileName),
      ).writeAsString('0123456789abcdef0123456789abcdef', flush: true);

      await expectLater(
        RestoreStartupGate.inspect(appDataDirectory: root),
        throwsA(isA<StateError>()),
      );
    });
  });
}
