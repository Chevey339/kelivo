import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_restore_service.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => '$root/cache';

  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

Future<Map<String, dynamic>> _readBackupSettings(File backup) async {
  final archive = ZipDecoder().decodeBytes(await backup.readAsBytes());
  final entry = archive.findFile('settings.json');
  if (entry == null) throw StateError('settings.json');
  return jsonDecode(utf8.decode(entry.readBytes()!)) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> _readBackupManifest(File backup) async {
  final archive = ZipDecoder().decodeBytes(await backup.readAsBytes());
  final entry = archive.findFile('manifest.json');
  if (entry == null) throw StateError('manifest.json');
  return jsonDecode(utf8.decode(entry.readBytes()!)) as Map<String, dynamic>;
}

Map<String, Object?> _businessFixture({required String secret}) => {
  'provider_configs_v1': jsonEncode({
    'second': {
      'id': 'second',
      'name': 'Second',
      'apiKey': secret,
      'proxyPassword': 'proxy-secret',
    },
    'first': {'id': 'first', 'name': 'First', 'apiKey': 'first-secret'},
  }),
  'providers_order_v1': ['second', 'first'],
  'assistants_v1': jsonEncode([
    {'id': 'assistant-1', 'name': 'Assistant'},
  ]),
  'webdav_config_v1': jsonEncode({
    'url': 'https://dav.example.test',
    'password': 'dav-secret',
  }),
  's3_config_v1': jsonEncode({
    'endpoint': 'https://s3.example.test',
    'secretAccessKey': 's3-secret',
  }),
  'app_launch_count_v1': 42,
  'backup_reminder_last_backup_at_v1': '2026-07-18T12:30:00.000Z',
  'request_log_enabled_v1': true,
  'log_save_output_v1': true,
  'unknown_portable_key_v1': ['one', 'two'],
  'flutter_log_enabled_v1': true,
  'restore_transient_v1': 'local-only',
  'pinned_chat_ids': 'discarded',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataSync database-backed business settings', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_data_sync_db_');
      PathProviderPlatform.instance = _FakePathProvider(root.path);
      PackageInfo.setMockInitialValues(
        appName: 'Kelivo',
        packageName: 'Kelivo',
        version: '1.0.0-test',
        buildNumber: '1',
        buildSignature: 'test',
      );
      SharedPreferences.setMockInitialValues({
        'prefs_only_residual': 'must-not-export',
        'flutter_log_enabled_v1': true,
      });
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('exports the portable settings shape only from SQLite', () async {
      final database = AppDatabase.open(
        file: File('${root.path}/business.sqlite'),
      );
      final repository = BusinessRepository(database);
      File? backup;
      try {
        await BusinessRestoreService(
          repository,
        ).overwrite(_businessFixture(secret: 'provider-secret'));
        // Simulate stale rows written by an older or bypassing caller. The
        // portable exporter remains responsible for filtering them.
        await repository.setPreference('flutter_log_enabled_v1', true);
        await repository.setPreference('pinned_chat_ids', 'stale-chat');

        backup =
            await DataSync(
              chatService: ChatService(),
              businessRepository: repository,
            ).prepareBackupFile(
              const WebDavConfig(includeChats: false, includeFiles: false),
            );

        final settings = await _readBackupSettings(backup);
        final manifest = await _readBackupManifest(backup);
        final providers =
            jsonDecode(settings['provider_configs_v1'] as String) as Map;
        expect(settings['providers_order_v1'], ['second', 'first']);
        expect((providers['second'] as Map)['apiKey'], 'provider-secret');
        expect((providers['second'] as Map)['proxyPassword'], 'proxy-secret');
        expect(settings['app_launch_count_v1'], 42);
        expect(
          settings['backup_reminder_last_backup_at_v1'],
          '2026-07-18T12:30:00.000Z',
        );
        expect(settings['request_log_enabled_v1'], isTrue);
        expect(settings['log_save_output_v1'], isTrue);
        expect(settings['unknown_portable_key_v1'], ['one', 'two']);
        expect(settings, isNot(contains('prefs_only_residual')));
        expect(settings, isNot(contains('flutter_log_enabled_v1')));
        expect(settings, isNot(contains('restore_transient_v1')));
        expect(settings, isNot(contains('pinned_chat_ids')));
        final rowIds = manifest['businessEntityRowIds'] as Map;
        expect(rowIds['assistants_v1'], ['assistant-1']);
        expect(rowIds['assistant_tags_v1'], isEmpty);
      } finally {
        await DataSync.cleanupTemporaryBackupFile(backup);
        await database.close();
      }
    });

    test(
      'settings-only overwrite is one live DB replacement and touches no chat, asset, or workspace',
      () async {
        final sourceDatabase = AppDatabase.open(
          file: File('${root.path}/source.sqlite'),
        );
        final sourceRepository = BusinessRepository(sourceDatabase);
        File? backup;
        late Map<String, Object> expectedSettings;
        try {
          await BusinessRestoreService(sourceRepository).overwrite({
            ..._businessFixture(secret: 'restored-secret'),
            'mcp_servers_v1': jsonEncode([
              {
                'id': 'restored-mcp',
                'enabled': false,
                'name': 'Restored MCP',
                'transport': 'http',
                'url': 'https://restored.example.test/mcp',
                'tools': <Object?>[],
              },
            ]),
          });
          expectedSettings = await BusinessRestoreService(
            sourceRepository,
          ).exportSettings();
          final asset = File('${root.path}/upload/sentinel.txt');
          await asset.parent.create(recursive: true);
          await asset.writeAsString('from-backup');
          backup =
              await DataSync(
                chatService: ChatService(),
                businessRepository: sourceRepository,
              ).prepareBackupFile(
                const WebDavConfig(includeChats: false, includeFiles: true),
              );
        } finally {
          await sourceDatabase.close();
        }

        final targetDatabase = AppDatabase.open(
          file: File('${root.path}/target.sqlite'),
        );
        final targetRepository = BusinessRepository(targetDatabase);
        try {
          await BusinessRestoreService(targetRepository).overwrite({
            'provider_configs_v1': jsonEncode({
              'old': {'id': 'old', 'apiKey': 'old-secret'},
            }),
            'providers_order_v1': ['old'],
            'old_only_key_v1': true,
          });
          final businessPreferences = BusinessPreferences(targetRepository);
          await businessPreferences.load();
          final now = DateTime.now().microsecondsSinceEpoch;
          await targetDatabase.customStatement(
            'INSERT INTO conversation_rows '
            '(id, title, created_at, updated_at) VALUES (?, ?, ?, ?);',
            ['live-chat', 'Keep me', now, now],
          );

          final asset = File('${root.path}/upload/sentinel.txt');
          await asset.writeAsString('live-asset');

          await DataSync(
            chatService: ChatService(),
            businessRepository: targetRepository,
            businessPreferences: businessPreferences,
          ).restoreFromLocalFile(
            backup,
            const WebDavConfig(includeChats: false, includeFiles: true),
          );

          await expectLater(
            businessPreferences.setString(
              'mcp_servers_v1',
              jsonEncode([
                {
                  'id': 'stale-mcp',
                  'enabled': false,
                  'name': 'Stale MCP',
                  'transport': 'http',
                  'url': 'https://stale.example.test/mcp',
                  'tools': <Object?>[],
                },
              ]),
            ),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                'business_preferences_restore_fence',
              ),
            ),
          );

          expect(
            await BusinessRestoreService(targetRepository).exportSettings(),
            expectedSettings,
          );
          final chatCount = await targetDatabase
              .customSelect('SELECT COUNT(*) AS total FROM conversation_rows;')
              .getSingle();
          expect(chatCount.read<int>('total'), 1);
          expect(await asset.readAsString(), 'live-asset');
          expect(
            await Directory('${root.path}/.kelivo_restore').exists(),
            isFalse,
          );
        } finally {
          await DataSync.cleanupTemporaryBackupFile(backup);
          await targetDatabase.close();
        }
      },
    );

    for (final mode in const [RestoreMode.overwrite, RestoreMode.merge]) {
      test(
        'settings-only ${mode.name} keeps idless tag identity used by relationships',
        () async {
          final sourceDatabase = AppDatabase.open(
            file: File('${root.path}/idless-${mode.name}-source.sqlite'),
          );
          final sourceRepository = BusinessRepository(sourceDatabase);
          File? backup;
          late String sourceTagRowId;
          try {
            await BusinessRestoreService(sourceRepository).overwrite({
              'assistant_tags_v1': jsonEncode([
                {'name': 'Before rename'},
              ]),
            });
            final original = (await sourceRepository.readEntities(
              BusinessEntityKind.assistantTag,
            )).single;
            sourceTagRowId = original.id;
            await sourceRepository.synchronizeEntities(
              BusinessEntityKind.assistantTag,
              [
                original.copyWith(
                  payload: jsonEncode({'name': 'After rename'}),
                ),
              ],
            );
            await sourceRepository.setPreference(
              'assistant_tag_map_v1',
              jsonEncode({'assistant-a': sourceTagRowId}),
            );
            backup =
                await DataSync(
                  chatService: ChatService(),
                  businessRepository: sourceRepository,
                ).prepareBackupFile(
                  const WebDavConfig(includeChats: false, includeFiles: false),
                );
          } finally {
            await sourceDatabase.close();
          }

          final targetDatabase = AppDatabase.open(
            file: File('${root.path}/idless-${mode.name}-target.sqlite'),
          );
          final targetRepository = BusinessRepository(targetDatabase);
          try {
            await DataSync(
              chatService: ChatService(),
              businessRepository: targetRepository,
            ).restoreFromLocalFile(
              backup,
              const WebDavConfig(includeChats: false, includeFiles: false),
              mode: mode,
            );

            final restoredTag = (await targetRepository.readEntities(
              BusinessEntityKind.assistantTag,
            )).single;
            final restored = await BusinessRestoreService(
              targetRepository,
            ).exportSettings();
            final tagPayload =
                (jsonDecode(restored['assistant_tags_v1'] as String) as List)
                        .single
                    as Map;
            final tagMap =
                jsonDecode(restored['assistant_tag_map_v1'] as String) as Map;
            expect(restoredTag.id, sourceTagRowId);
            expect(tagPayload, {'name': 'After rename'});
            expect(tagMap['assistant-a'], restoredTag.id);
          } finally {
            await DataSync.cleanupTemporaryBackupFile(backup);
            await targetDatabase.close();
          }
        },
      );
    }

    test(
      'settings-only merge is one live DB transaction and touches no chat, asset, or workspace',
      () async {
        final sourceDatabase = AppDatabase.open(
          file: File('${root.path}/merge-source.sqlite'),
        );
        final sourceRepository = BusinessRepository(sourceDatabase);
        File? backup;
        try {
          await BusinessRestoreService(
            sourceRepository,
          ).overwrite(_businessFixture(secret: 'merged-secret'));
          final asset = File('${root.path}/upload/merge-sentinel.txt');
          await asset.parent.create(recursive: true);
          await asset.writeAsString('from-backup');
          backup =
              await DataSync(
                chatService: ChatService(),
                businessRepository: sourceRepository,
              ).prepareBackupFile(
                const WebDavConfig(includeChats: false, includeFiles: true),
              );
        } finally {
          await sourceDatabase.close();
        }

        final targetDatabase = AppDatabase.open(
          file: File('${root.path}/merge-target.sqlite'),
        );
        final targetRepository = BusinessRepository(targetDatabase);
        try {
          await BusinessRestoreService(targetRepository).overwrite({
            'provider_configs_v1': jsonEncode({
              'local': {'id': 'local', 'apiKey': 'local-secret'},
            }),
            'providers_order_v1': ['local'],
            'local_only_portable_key_v1': true,
          });
          final now = DateTime.now().microsecondsSinceEpoch;
          await targetDatabase.customStatement(
            'INSERT INTO conversation_rows '
            '(id, title, created_at, updated_at) VALUES (?, ?, ?, ?);',
            ['live-merge-chat', 'Keep me too', now, now],
          );
          final asset = File('${root.path}/upload/merge-sentinel.txt');
          await asset.writeAsString('live-asset');

          await DataSync(
            chatService: ChatService(),
            businessRepository: targetRepository,
          ).restoreFromLocalFile(
            backup,
            const WebDavConfig(includeChats: false, includeFiles: true),
            mode: RestoreMode.merge,
          );

          final restored = await BusinessRestoreService(
            targetRepository,
          ).exportSettings();
          final providers =
              jsonDecode(restored['provider_configs_v1'] as String) as Map;
          expect((providers['local'] as Map)['apiKey'], 'local-secret');
          expect((providers['second'] as Map)['apiKey'], 'merged-secret');
          expect(restored['local_only_portable_key_v1'], true);
          final chatCount = await targetDatabase
              .customSelect('SELECT COUNT(*) AS total FROM conversation_rows;')
              .getSingle();
          expect(chatCount.read<int>('total'), 1);
          expect(await asset.readAsString(), 'live-asset');
          expect(
            await Directory('${root.path}/.kelivo_restore').exists(),
            isFalse,
          );
        } finally {
          await DataSync.cleanupTemporaryBackupFile(backup);
          await targetDatabase.close();
        }
      },
    );
  });
}
