import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_bundle_staging.dart';

Future<Directory> _createExtractedBundle(
  Directory root, {
  bool includeDatabase = true,
}) async {
  final extracted = Directory(p.join(root.path, 'extracted'));
  await extracted.create(recursive: true);
  final settings = File(p.join(extracted.path, 'settings.json'));
  await settings.writeAsString(jsonEncode({'theme': 'dark'}), flush: true);
  final database = File(p.join(extracted.path, 'database', 'kelivo.sqlite'));
  if (includeDatabase) {
    await database.parent.create(recursive: true);
    await database.writeAsBytes([1, 2, 3, 4], flush: true);
  }
  await File(p.join(extracted.path, 'manifest.json')).writeAsString(
    jsonEncode({
      'includeChats': true,
      'includeFiles': false,
      'entries': {
        'settings.json': {'bytes': 0, 'sha256': 'source'},
        'database/kelivo.sqlite': {'bytes': 0, 'sha256': 'source'},
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
        includeChats: true,
        includeFiles: false,
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
        includeDatabase: false,
      );

      await expectLater(
        RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: true,
          includeFiles: false,
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
  });
}
