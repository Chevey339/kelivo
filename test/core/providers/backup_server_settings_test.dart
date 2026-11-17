import 'dart:convert';

import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a damaged field preserves other stored fields and exclusions on save',
    () async {
      const scope = BackupScope(
        excluded: {
          BackupCategory.chats,
          BackupCategory.files,
          BackupCategory.workspaces,
        },
      );
      const dav = WebDavConfig(
        url: 'https://dav.example',
        username: 'user',
        password: ' secret ',
        path: 'custom-dav',
        scope: scope,
      );
      const s3 = S3Config(
        endpoint: 'https://s3.example',
        bucket: 'bucket',
        accessKeyId: 'key',
        secretAccessKey: ' secret ',
        sessionToken: ' token ',
        prefix: 'custom-s3',
        scope: scope,
      );
      final damagedScope = {
        ...scope.toJson(),
        'memories': 'private-fixture',
        'unknown-private-key': ['unknown-private-value'],
      };
      final initial = {
        'webdav_config_v1': jsonEncode({
          ...dav.toJson(),
          'userAgent': 17,
          'scope': damagedScope,
        }),
        's3_config_v1': jsonEncode({
          ...s3.toJson(),
          'pathStyle': 'private-fixture',
          'scope': {...damagedScope, 'chats': 'invalid'},
        }),
      };
      final business = await createBusinessTestHarness(initial: initial);
      final warnings = <String>[];
      final previousPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null && message.startsWith('[BackupSettings]')) {
          warnings.add(message);
        }
      };
      addTearDown(() => debugPrint = previousPrint);
      final settings = SettingsProvider(business.preferences);
      final firstDav = settings.webDavConfig;
      final firstS3 = settings.s3Config;
      await settings.loaded;
      expect(firstDav.toJson(), dav.toJson());
      expect(firstS3.toJson(), s3.toJson());
      expect(settings.webDavConfig.scope.excluded, scope.excluded);
      expect(settings.s3Config.scope.excluded, scope.excluded);
      expect(
        warnings,
        unorderedEquals([
          '[BackupSettings] Ignoring invalid webdav_config_v1.userAgent.',
          '[BackupSettings] Ignoring invalid webdav_config_v1.scope.memories.',
          '[BackupSettings] Ignoring invalid s3_config_v1.pathStyle.',
          '[BackupSettings] Ignoring invalid s3_config_v1.scope.chats.',
          '[BackupSettings] Ignoring invalid s3_config_v1.scope.memories.',
        ]),
      );
      for (final entry in initial.entries) {
        expect(await business.repository.getPreference(entry.key), entry.value);
      }
      final updated = scope
          .withCategory(BackupCategory.chats, true)
          .withCategory(BackupCategory.skills, false);
      await settings.setBackupScope(updated);
      expect(
        await business.repository.getPreference('webdav_config_v1'),
        dav.copyWith(scope: updated).toJsonString(),
      );
      expect(
        await business.repository.getPreference('s3_config_v1'),
        s3.copyWith(scope: updated).toJsonString(),
      );
    },
  );

  test('an unreadable record or scope reports only the affected location', () {
    final invalid = <String?>[];
    for (final stored in [42, '{"password":"sensitive"', '["sensitive"]']) {
      invalid.clear();
      expect(
        WebDavConfig.fromPreference(
          stored,
          onInvalidField: invalid.add,
        ).toJson(),
        const WebDavConfig().toJson(),
      );
      expect(invalid, [null]);
    }
    invalid.clear();
    final server = S3Config.fromPreference(
      jsonEncode({
        'region': '  ',
        'bucket': ' saved-bucket ',
        'sessionToken': ' token ',
        'prefix': ' folder ',
        'scope': ['sensitive'],
      }),
      onInvalidField: invalid.add,
    );
    expect(
      server.toJson(),
      const S3Config(
        bucket: 'saved-bucket',
        sessionToken: ' token ',
        prefix: 'folder',
      ).toJson(),
    );
    expect(invalid, ['scope']);
    invalid.clear();
    expect(
      WebDavConfig.fromPreference(null, onInvalidField: invalid.add).toJson(),
      const WebDavConfig().toJson(),
    );
    expect(
      S3Config.fromPreference('{}', onInvalidField: invalid.add).toJson(),
      const S3Config().toJson(),
    );
    expect(invalid, isEmpty);
  });

  test('queued server edits merge with the latest shared scope', () async {
    final business = await createBusinessTestHarness();
    final settings = SettingsProvider(business.preferences);
    await settings.loaded;
    const scope = BackupScope(excluded: {BackupCategory.files});
    await Future.wait([
      settings.updateWebDavConfig(
        (cfg) => cfg.copyWith(url: 'https://dav.example'),
      ),
      settings.updateS3Config((cfg) => cfg.copyWith(bucket: 'saved-bucket')),
      settings.setBackupScope(scope),
      settings.updateWebDavConfig(
        (cfg) => cfg.copyWith(password: 'dav-password'),
      ),
      settings.updateS3Config(
        (cfg) => cfg.copyWith(secretAccessKey: 's3-secret'),
      ),
    ]);
    expect(settings.webDavConfig.url, 'https://dav.example');
    expect(settings.webDavConfig.password, 'dav-password');
    expect(settings.s3Config.bucket, 'saved-bucket');
    expect(settings.s3Config.secretAccessKey, 's3-secret');
    expect(settings.webDavConfig.scope.excluded, scope.excluded);
    expect(settings.s3Config.scope.excluded, scope.excluded);
  });

  test(
    'a failed scope write leaves both server configurations intact and can be retried',
    () async {
      const dav = WebDavConfig(url: 'https://dav.example');
      const s3 = S3Config(bucket: 'saved-bucket');
      final initial = {
        'webdav_config_v1': dav.toJsonString(),
        's3_config_v1': s3.toJsonString(),
      };
      final business = await createBusinessTestHarness(initial: initial);
      final settings = SettingsProvider(business.preferences);
      await settings.loaded;
      await business.database.customStatement('''
      CREATE TRIGGER reject_s3 BEFORE INSERT ON preference_rows
      WHEN NEW.key = 's3_config_v1'
      BEGIN SELECT RAISE(ABORT, 'scope write rejected'); END
    ''');
      const scope = BackupScope(excluded: {BackupCategory.chats});
      await expectLater(
        settings.setBackupScope(scope),
        throwsA(isA<BackupSettingsSaveException>()),
      );
      expect(settings.savingWebDavConfig, isFalse);
      expect(settings.savingS3Config, isFalse);
      expect(settings.webDavConfig.toJson(), dav.toJson());
      expect(settings.s3Config.toJson(), s3.toJson());
      for (final entry in initial.entries) {
        expect(await business.repository.getPreference(entry.key), entry.value);
      }
      await business.database.customStatement('DROP TRIGGER reject_s3');
      await settings.setBackupScope(scope);
      expect(settings.webDavConfig.scope.excluded, scope.excluded);
      expect(settings.s3Config.scope.excluded, scope.excluded);
    },
  );
}
