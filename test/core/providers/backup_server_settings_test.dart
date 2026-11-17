import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
