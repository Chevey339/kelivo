import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_restore_service.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/services/backup/restore_bundle_staging.dart';

Future<String> _sha256(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

void main() {
  group('full-overwrite business candidate staging', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_business_staging_');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test(
      'settings.json replaces snapshot business tables before the formal candidate is published',
      () async {
        final extracted = Directory(p.join(root.path, 'extracted'));
        final databaseFile = File(
          p.join(extracted.path, 'database', 'kelivo.db'),
        );
        await databaseFile.parent.create(recursive: true);
        final database = AppDatabase.open(file: databaseFile);
        try {
          await BusinessRestoreService(BusinessRepository(database)).overwrite({
            'provider_configs_v1': jsonEncode({
              'snapshot-provider': {
                'id': 'snapshot-provider',
                'apiKey': 'snapshot-secret',
              },
            }),
            'providers_order_v1': ['snapshot-provider'],
            'snapshot_only_v1': true,
          });
          final now = DateTime.now().microsecondsSinceEpoch;
          await database.customStatement(
            'INSERT INTO conversation_rows '
            '(id, title, created_at, updated_at) VALUES (?, ?, ?, ?);',
            ['conversation-1', 'Preserved chat', now, now],
          );
        } finally {
          await database.close();
        }
        final databaseInfo =
            await ChatDatabaseRepository.prepareSnapshotForRestore(
              databaseFile,
            );
        final sourceDatabaseHash = await _sha256(databaseFile);

        final settingsFile = File(p.join(extracted.path, 'settings.json'));
        await settingsFile.writeAsString(
          jsonEncode({
            'provider_configs_v1': jsonEncode({
              'portable-provider': {
                'id': 'portable-provider',
                'apiKey': 'portable-secret',
                'proxyPassword': 'portable-proxy-secret',
              },
            }),
            'providers_order_v1': ['portable-provider'],
            'portable_only_v1': ['a', 'b'],
            'flutter_log_enabled_v1': true,
          }),
          flush: true,
        );
        final manifestFile = File(p.join(extracted.path, 'manifest.json'));
        await manifestFile.writeAsString(
          jsonEncode({
            'format': 'kelivo-backup',
            'formatVersion': 2,
            'payloadKind': 'sqlite',
            'createdAtUtc': '2026-07-18T00:00:00.000Z',
            'appVersion': 'test',
            'includeChats': true,
            'includeFiles': false,
            'secretsIncluded': true,
            'database': {
              'entry': 'database/kelivo.db',
              'schemaVersion': databaseInfo.schemaVersion,
              'conversationCount': databaseInfo.conversationCount,
              'messageCount': databaseInfo.messageCount,
            },
            'entries': {
              'settings.json': {
                'bytes': await settingsFile.length(),
                'sha256': await _sha256(settingsFile),
              },
              'database/kelivo.db': {
                'bytes': await databaseFile.length(),
                'sha256': sourceDatabaseHash,
              },
            },
          }),
          flush: true,
        );

        final staged = await RestoreBundleStaging.create(
          appDataDirectory: root,
          extractedDirectory: extracted,
          includeChats: true,
          includeFiles: false,
          sourceManifestSha256: await _sha256(manifestFile),
        );

        expect(
          await File(
            p.join(staged.payloadDirectory.path, 'settings.json'),
          ).exists(),
          isFalse,
        );
        final candidateManifest =
            jsonDecode(
                  await File(
                    p.join(staged.payloadDirectory.path, 'manifest.json'),
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        expect(candidateManifest, isNot(contains('secretsIncluded')));
        expect((candidateManifest['entries'] as Map).keys, [
          'database/kelivo.db',
        ]);
        expect(
          ((candidateManifest['entries'] as Map)['database/kelivo.db']
              as Map)['sha256'],
          isNot(sourceDatabaseHash),
        );

        final validated = await RestoreBundleStaging.validateExistingCandidate(
          candidateDirectory: staged.payloadDirectory,
          expectedManifestSha256: staged.candidateManifestSha256,
        );
        expect(validated.databaseInfo?.conversationCount, 1);

        final inspectionFile = await File(
          p.join(staged.payloadDirectory.path, 'database', 'kelivo.db'),
        ).copy(p.join(root.path, 'inspection.sqlite'));
        final inspectionDatabase = AppDatabase.open(file: inspectionFile);
        try {
          final exported = await BusinessRestoreService(
            BusinessRepository(inspectionDatabase),
          ).exportSettings();
          final providers =
              jsonDecode(exported['provider_configs_v1'] as String) as Map;
          expect(providers.keys, ['portable-provider']);
          expect(
            (providers['portable-provider'] as Map)['apiKey'],
            'portable-secret',
          );
          expect(exported['portable_only_v1'], ['a', 'b']);
          expect(exported, isNot(contains('snapshot_only_v1')));
          expect(exported, isNot(contains('flutter_log_enabled_v1')));
        } finally {
          await inspectionDatabase.close();
        }
      },
    );
  });
}
