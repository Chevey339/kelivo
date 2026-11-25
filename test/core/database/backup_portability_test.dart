import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/backup_portability.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_restore_service.dart';
import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';

Map<String, Object> _workspace(String id, {bool linked = false}) => {
  'id': id,
  'name': id,
  'kind': linked ? 'linked' : 'managed',
  'hostPath': '/source/$id',
  'lastUsedAt': '2026-09-11T00:00:00Z',
};

void main() {
  late AppDatabase database;
  late BusinessRepository repository;
  late ExtensionEntityStore store;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = BusinessRepository(database);
    store = ExtensionEntityStore(database);
    final prefs = BusinessPreferences(repository);
    for (final key in BackupPortability.devicePreferenceKeys) {
      await prefs.setString(key, 'local-$key');
    }
    await prefs.setString('environment_mirrors_v1', '{}');
    await store.upsert('workspace', 'managed', _workspace('managed'));
    await store.upsert(
      'workspace',
      'linked',
      _workspace('linked', linked: true),
    );
    await store.upsert('externalMounts', 'global', {
      'mounts': [
        {'bookmark': 'local-bookmark', 'sourcePath': '/local/folder'},
      ],
    });
  });

  tearDown(() => database.close());

  test(
    'settings export excludes device data and keeps row identities aligned',
    () async {
      final before = await repository.readSnapshot();
      final exported = await DataSync.exportBusinessSettingsFrom(repository);
      final settings =
          jsonDecode(exported.settingsJson) as Map<String, dynamic>;
      for (final key in BackupPortability.devicePreferenceKeys) {
        expect(settings, isNot(contains(key)));
      }
      expect(settings['environment_mirrors_v1'], '{}');
      final workspaces =
          jsonDecode(settings['workspaces_v1'] as String) as List;
      expect(workspaces.single['id'], 'managed');
      expect(workspaces.single, isNot(contains('hostPath')));
      expect(workspaces.single, isNot(contains('lastUsedAt')));
      expect(exported.entityRowIds['workspaces_v1'], ['managed']);
      BusinessSettingsRouter.normalizeAndRoute(
        settings,
        entityRowIds: exported.entityRowIds,
      );
      expect((await repository.readSnapshot()).preferences, before.preferences);
      expect(await store.get('workspace', 'linked'), isNotNull);
    },
  );

  for (final merge in [false, true]) {
    test(
      '${merge ? 'merge' : 'overwrite'} ignores old device state and preserves local state',
      () async {
        final service = BusinessRestoreService(repository);
        final incoming = <String, Object?>{
          for (final key in BackupPortability.devicePreferenceKeys)
            key: {'old': 'invalid-device-value'},
          'workspaces_v1': jsonEncode([
            _workspace('foreign-linked', linked: true),
            _workspace('foreign-managed'),
          ]),
          'assistants_v1': jsonEncode([
            {'id': 'assistant', 'defaultWorkspaceId': 'foreign-linked'},
          ]),
        };
        if (merge) {
          await service.merge(incoming);
        } else {
          await service.overwrite(incoming);
        }
        final snapshot = await repository.readSnapshot();
        for (final key in BackupPortability.devicePreferenceKeys) {
          expect(snapshot.preferences[key], 'local-$key');
        }
        expect(await store.get('workspace', 'linked'), isNotNull);
        expect(await store.get('workspace', 'foreign-linked'), isNull);
        expect(await store.get('workspace', 'foreign-managed'), isNotNull);
        expect(await store.get('externalMounts', 'global'), isNotNull);
        final settings = await service.exportSettings();
        expect(
          (jsonDecode(settings['assistants_v1'] as String) as List).single,
          isNot(contains('defaultWorkspaceId')),
        );
      },
    );
  }

  test(
    'raw SQLite sanitization removes grants and detaches linked chats only',
    () async {
      for (final id in ['managed', 'linked']) {
        await database.customStatement(
          'INSERT INTO conversation_rows (id, title, created_at, updated_at, extras_json) VALUES (?, ?, 0, 0, ?)',
          [
            id,
            id,
            jsonEncode({
              'workspace.id': id,
              'workspace.cwd': 'src',
              'workspace.tools_used': true,
              'workspace.allowAll': true,
              'tools.permission_mode': 'fullAccess',
              'other.feature': 'keep',
            }),
          ],
        );
      }
      await BackupPortability.sanitizeDatabase(database);
      expect(await store.get('workspace', 'linked'), isNull);
      expect(await store.get('externalMounts', 'global'), isNull);
      expect(
        (await repository.readSnapshot()).preferences.keys,
        isNot(anyElement(isIn(BackupPortability.devicePreferenceKeys))),
      );
      final rows = await database
          .customSelect('SELECT id, extras_json FROM conversation_rows')
          .get();
      for (final row in rows) {
        final extras = jsonDecode(row.read<String>('extras_json')) as Map;
        expect(extras['other.feature'], 'keep');
        expect(extras, isNot(contains('workspace.allowAll')));
        expect(extras, isNot(contains('tools.permission_mode')));
        if (row.read<String>('id') == 'managed') {
          expect(extras['workspace.id'], 'managed');
          expect(extras['workspace.cwd'], 'src');
        } else {
          expect(extras.keys, ['other.feature']);
        }
      }
    },
  );

  test(
    'backup reminder lastBackupAt is device-local while schedule preferences remain portable',
    () async {
      const lastBackupKey = 'backup_reminder_last_backup_at_v1';
      const portableKeys = {
        'backup_reminder_enabled_v1': true,
        'backup_reminder_interval_days_v1': 7,
        'backup_reminder_minutes_of_day_v1': 1200,
        'backup_reminder_enabled_at_v1': '2026-07-18T09:00:00.000Z',
      };

      expect(
        BusinessKeyRegistry.classify(lastBackupKey),
        BusinessKeyDisposition.preference,
      );
      expect(BackupPortability.devicePreferenceKeys, contains(lastBackupKey));
      for (final key in portableKeys.keys) {
        expect(BackupPortability.devicePreferenceKeys, isNot(contains(key)));
      }

      final prefs = BusinessPreferences(repository);
      await prefs.setBool('backup_reminder_enabled_v1', true);
      await prefs.setInt('backup_reminder_interval_days_v1', 7);
      await prefs.setInt('backup_reminder_minutes_of_day_v1', 1200);
      await prefs.setString(
        'backup_reminder_enabled_at_v1',
        '2026-07-18T09:00:00.000Z',
      );
      await prefs.setString(lastBackupKey, '2026-07-19T23:30:00.000Z');

      final portableSnapshot = BackupPortability.portable(
        await repository.readSnapshot(),
      );
      expect(portableSnapshot.preferences, isNot(contains(lastBackupKey)));
      for (final entry in portableKeys.entries) {
        expect(portableSnapshot.preferences[entry.key], entry.value);
      }

      final exported = await DataSync.exportBusinessSettingsFrom(repository);
      final exportedSettings =
          jsonDecode(exported.settingsJson) as Map<String, dynamic>;
      expect(exportedSettings, isNot(contains(lastBackupKey)));
      for (final entry in portableKeys.entries) {
        expect(exportedSettings[entry.key], entry.value);
      }

      await BackupPortability.sanitizeDatabase(database);
      final sanitized = await repository.readSnapshot();
      expect(sanitized.preferences, isNot(contains(lastBackupKey)));
      for (final entry in portableKeys.entries) {
        expect(sanitized.preferences[entry.key], entry.value);
      }
    },
  );

  for (final merge in [false, true]) {
    test(
      '${merge ? 'merge' : 'overwrite'} keeps local backup reminder timestamp and ignores stale incoming timestamp',
      () async {
        const lastBackupKey = 'backup_reminder_last_backup_at_v1';
        final prefs = BusinessPreferences(repository);
        await prefs.setString(lastBackupKey, '2026-07-19T23:30:00.000Z');

        final service = BusinessRestoreService(repository);
        final foreignBackup = <String, Object?>{
          'backup_reminder_enabled_v1': true,
          'backup_reminder_interval_days_v1': 3,
          'backup_reminder_minutes_of_day_v1': 540,
          'backup_reminder_enabled_at_v1': '2026-07-17T08:00:00.000Z',
          lastBackupKey: '2026-07-17T21:41:00.000Z',
        };
        if (merge) {
          await service.merge(foreignBackup);
        } else {
          await service.overwrite(foreignBackup);
        }

        final afterExisting = await repository.readSnapshot();
        expect(
          afterExisting.preferences[lastBackupKey],
          '2026-07-19T23:30:00.000Z',
        );
        expect(afterExisting.preferences['backup_reminder_enabled_v1'], isTrue);
        expect(
          afterExisting.preferences['backup_reminder_interval_days_v1'],
          3,
        );
        expect(
          afterExisting.preferences['backup_reminder_minutes_of_day_v1'],
          540,
        );
        expect(
          afterExisting.preferences['backup_reminder_enabled_at_v1'],
          '2026-07-17T08:00:00.000Z',
        );

        final freshDb = AppDatabase(NativeDatabase.memory());
        try {
          final freshRepo = BusinessRepository(freshDb);
          final freshService = BusinessRestoreService(freshRepo);
          if (merge) {
            await freshService.merge(foreignBackup);
          } else {
            await freshService.overwrite(foreignBackup);
          }
          final afterFresh = await freshRepo.readSnapshot();
          expect(afterFresh.preferences, isNot(contains(lastBackupKey)));
          expect(afterFresh.preferences['backup_reminder_enabled_v1'], isTrue);
          expect(afterFresh.preferences['backup_reminder_interval_days_v1'], 3);
          expect(
            afterFresh.preferences['backup_reminder_minutes_of_day_v1'],
            540,
          );
          expect(
            afterFresh.preferences['backup_reminder_enabled_at_v1'],
            '2026-07-17T08:00:00.000Z',
          );
        } finally {
          await freshDb.close();
        }
      },
    );
  }
}
