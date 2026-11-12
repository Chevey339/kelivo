import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';

import '../../support/business_test_harness.dart';

const _enabledKey = 'backup_encryption_enabled_v1';
const _password = '  private backup password 🔐  ';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'saves the encryption choice without persisting the session password',
    () async {
      final business = await createBusinessTestHarness();
      final settings = SettingsProvider(business.preferences);
      addTearDown(settings.dispose);
      await settings.loaded;
      expect(settings.backupEncryptionEnabled, isFalse);

      await settings.setBackupEncryptionPassword(_password);
      expect(settings.backupEncryptionEnabled, isTrue);
      final snapshot = await business.repository.readSnapshot();
      expect(snapshot.preferences[_enabledKey], isTrue);
      expect(jsonEncode(snapshot.preferences), isNot(contains(_password)));

      // Navigating between pages keeps the app-scoped provider and its password.
      for (var visit = 0; visit < 2; visit++) {
        expect(
          await settings.resolveBackupEncryptionPassword(() async {
            fail('The same app session must not ask again.');
          }),
          _password,
        );
      }

      await settings.setBackupEncryptionPassword(null);
      expect(settings.backupEncryptionEnabled, isFalse);
      expect(
        (await business.repository.readSnapshot()).preferences[_enabledKey],
        isFalse,
      );
      expect(
        await settings.resolveBackupEncryptionPassword(() async {
          fail('Disabled encryption must not prompt.');
        }),
        isNull,
      );
    },
  );

  test(
    'after restart, cancellation preserves enabled state and never returns plaintext mode',
    () async {
      final business = await createBusinessTestHarness();
      final firstSession = SettingsProvider(business.preferences);
      await firstSession.setBackupEncryptionPassword(_password);
      firstSession.dispose();

      final settings = SettingsProvider(
        BusinessPreferences(business.repository),
      );
      addTearDown(settings.dispose);
      await settings.loaded;
      expect(settings.backupEncryptionEnabled, isTrue);
      var prompts = 0;
      await expectLater(
        settings.resolveBackupEncryptionPassword(() async {
          prompts++;
          return null;
        }),
        throwsA(isA<BackupCancelledException>()),
      );
      expect(prompts, 1);
      expect(settings.backupEncryptionEnabled, isTrue);
      expect(
        await settings.resolveBackupEncryptionPassword(() async {
          prompts++;
          return _password;
        }),
        _password,
      );
      expect(
        await settings.resolveBackupEncryptionPassword(() async {
          fail('Re-entered password should remain available for this session.');
        }),
        _password,
      );
      expect(prompts, 2);
    },
  );

  test('rejects empty passwords without enabling encryption', () async {
    final business = await createBusinessTestHarness();
    final settings = SettingsProvider(business.preferences);
    addTearDown(settings.dispose);
    await settings.loaded;
    await expectLater(
      settings.setBackupEncryptionPassword(''),
      throwsArgumentError,
    );
    expect(settings.backupEncryptionEnabled, isFalse);
    expect(business.preferences.getBool(_enabledKey), isNull);
  });
}
