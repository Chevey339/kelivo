import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_encryption.dart';
import 'package:Kelivo/core/services/backup/backup_secure_password_store.dart';

import '../../support/backup_password_store.dart';
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

  test(
    'manual consent survives a restart, rotation and disabling automatic backups',
    () async {
      final db = await createBusinessTestHarness();
      final vault = TestBackupPasswordStore();
      final first = SettingsProvider(
        db.preferences,
        backupPasswordStore: vault,
      );
      addTearDown(first.dispose);
      await first.setBackupEncryptionPassword(_password);
      await expectLater(
        first.rememberBackupPassword('wrong'),
        throwsA(isA<BackupDecryptionException>()),
      );
      expect(vault.value, isNull);
      await first.rememberBackupPassword(_password);
      expect(vault.lastNewConsent, true);
      final next = SettingsProvider(
        BusinessPreferences(db.repository),
        backupPasswordStore: vault,
      );
      addTearDown(next.dispose);
      Future<String?> noPrompt() =>
          next.resolveBackupEncryptionPassword(() => fail('unexpected prompt'));
      expect(await noPrompt(), _password);
      expect(next.backupPasswordRemembered, true);
      expect(next.autoBackupEnabled, false);
      await expectLater(
        next.automaticBackupPassword(),
        throwsA(isA<BackupKeychainUnavailable>()),
      );
      expect(
        jsonEncode((await db.repository.readSnapshot()).preferences),
        isNot(contains(_password)),
      );

      await next.setBackupEncryptionPassword('changed');
      expect(vault.value, 'changed');
      expect(vault.lastNewConsent, false);
      vault.readable = false;
      await next.rememberBackupPassword('changed');
      expect(vault.lastNewConsent, false);
      vault.readable = true;
      vault.cancelAuthorization = true; // Reading works, rewriting would fail.
      await next.setAutomaticBackup(true, password: 'changed');
      vault.cancelAuthorization = false;
      await next.setAutomaticBackup(false);
      expect(next.backupPasswordRemembered, true);
      expect(vault.value, 'changed');
      await next.setAutomaticBackup(true, password: 'changed');
      await next.forgetBackupPassword();
      expect(next.backupEncryptionEnabled, true);
      expect(next.autoBackupEnabled, false);
      expect(next.backupPasswordRemembered, false);
      expect(vault.value, isNull);
      await expectLater(
        next.resolveBackupEncryptionPassword(() async => null),
        throwsA(isA<BackupCancelledException>()),
      );
      await next.rememberBackupPassword('changed');
      await next.setBackupEncryptionPassword(null);
      expect(vault.value, isNull);
    },
  );

  test(
    'forget takes effect while the keychain is offline and cleanup retries after restart',
    () async {
      final db = await createBusinessTestHarness();
      final vault = TestBackupPasswordStore();
      final settings = SettingsProvider(
        db.preferences,
        backupPasswordStore: vault,
      );
      addTearDown(settings.dispose);
      await settings.setBackupEncryptionPassword(_password);
      await settings.rememberBackupPassword(_password);
      vault.available = false;
      await expectLater(
        settings.forgetBackupPassword(),
        throwsA(isA<BackupKeychainUnavailable>()),
      );
      final next = SettingsProvider(
        BusinessPreferences(db.repository),
        backupPasswordStore: vault,
      );
      addTearDown(next.dispose);
      vault.available = true;
      await expectLater(
        next.resolveBackupEncryptionPassword(() async => null),
        throwsA(isA<BackupCancelledException>()),
      );
      expect(vault.value, _password);
      await next.retryBackupPasswordRemoval();
      expect(vault.value, isNull);
      expect(next.backupPasswordRemembered, false);
    },
  );
}
