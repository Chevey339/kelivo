import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/providers/backup_provider.dart';
import 'package:Kelivo/core/providers/backup_reminder_provider.dart';
import 'package:Kelivo/core/providers/external_backup_auto_provider.dart';
import 'package:Kelivo/core/providers/s3_backup_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/backup/backup_activity.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_encryption.dart';
import 'package:Kelivo/core/services/backup/backup_secure_password_store.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import '../../support/business_test_harness.dart';
import '../../support/backup_password_store.dart';

class _WebDav extends BackupProvider {
  _WebDav(BusinessTestHarness db)
    : super(
        chatService: ChatService(),
        businessRepository: db.repository,
        businessPreferences: db.preferences,
      );
  final passwords = <String?>[];
  final urls = <String>[];
  Future<bool>? result;
  @override
  Future<bool> backup(
    WebDavConfig cfg, {
    String? password,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    passwords.add(password);
    urls.add(cfg.url);
    return await result ?? true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'foreground due work runs once, waits for busy tasks, never counts failure and honours reminder disable',
    () async {
      final db = await createBusinessTestHarness();
      final store = TestBackupPasswordStore();
      final settings = SettingsProvider(
        db.preferences,
        backupPasswordStore: store,
      );
      await settings.loaded;
      await settings.updateWebDavConfig(
        (cfg) => cfg.copyWith(url: 'https://backup.example'),
      );
      final reminder = BackupReminderProvider(
        preferences: db.preferences,
        autoLoad: false,
        onDisabled: () => settings.setAutomaticBackup(false),
      );
      await reminder.load(startTimer: false);
      final start = DateTime(2026, 1, 1, 12);
      var now = start;
      await reminder.saveSchedule(
        enabled: true,
        intervalDays: 1,
        reminderMinutesOfDay: 600,
        now: start,
      );
      final webdav = _WebDav(db);
      final auto = ExternalBackupAutoProvider(
        preferences: db.preferences,
        settings: settings,
        reminder: reminder,
        webdav: webdav,
        s3: S3BackupProvider(
          chatService: ChatService(),
          businessRepository: db.repository,
          businessPreferences: db.preferences,
        ),
        desktop: false,
        clock: () => now,
      );
      await auto.enable(true);
      expect(await auto.runIfDue(now, foreground: true), false);
      now = DateTime(2026, 1, 7, 10);
      expect(await auto.runIfDue(now, foreground: false), false);
      BackupActivity.begin();
      try {
        expect(await auto.runIfDue(now, foreground: true), false);
      } finally {
        BackupActivity.end();
      }
      final finishing = Completer<bool>();
      webdav.result = finishing.future;
      final editGate = Completer<void>();
      unawaited(db.preferences.runExclusiveMutation(() => editGate.future));
      final s3Edit = settings.updateS3Config(
        (cfg) => cfg.copyWith(bucket: 'other-server'),
      );
      final run = auto.runIfDue(now, foreground: true);
      try {
        expect(settings.savingS3Config, isTrue);
        expect(auto.busy, true);
        expect(await auto.runIfDue(now, foreground: true), false);
      } finally {
        editGate.complete();
      }
      await s3Edit;
      now = now.add(const Duration(minutes: 15));
      finishing.complete(true);
      expect(await run, true);
      expect(reminder.lastBackupAt, now);
      expect(reminder.nextReminderAt, DateTime(2026, 1, 8, 10));
      expect(await auto.runIfDue(now, foreground: true), false);
      expect(webdav.passwords, hasLength(1));
      now = DateTime(2026, 1, 9, 10);
      webdav.result = Future.value(false);
      final matchingEditGate = Completer<void>();
      unawaited(
        db.preferences.runExclusiveMutation(() => matchingEditGate.future),
      );
      final webDavEdit = settings.updateWebDavConfig(
        (cfg) => cfg.copyWith(url: 'https://updated.example'),
      );
      final failedRun = expectLater(
        auto.runIfDue(now, foreground: true),
        throwsException,
      );
      try {
        expect(settings.savingWebDavConfig, isTrue);
        expect(auto.busy, isTrue);
        expect(auto.cancellable, isTrue);
        expect(await auto.runIfDue(now, foreground: true), isFalse);
      } finally {
        matchingEditGate.complete();
      }
      await webDavEdit;
      await failedRun;
      expect(webdav.urls.last, 'https://updated.example');
      expect(auto.failure, isNotNull);
      expect(reminder.lastBackupAt, DateTime(2026, 1, 7, 10, 15));
      expect(await auto.runIfDue(now, foreground: true), false);
      await reminder.setEnabled(false);
      expect(auto.enabled, false);
    },
  );

  test(
    'credential consent persists across sessions; inaccessible vault blocks automatic use and password rotation disables it',
    () async {
      final db = await createBusinessTestHarness();
      final vault = TestBackupPasswordStore();
      final settings = SettingsProvider(
        db.preferences,
        backupPasswordStore: vault,
      );
      await settings.setBackupEncryptionPassword('first');
      vault.available = false;
      await expectLater(
        settings.setAutomaticBackup(true, password: 'first'),
        throwsA(isA<BackupKeychainUnavailable>()),
      );
      expect(settings.autoBackupEnabled, false);
      vault.available = true;
      await expectLater(
        settings.setAutomaticBackup(true, password: 'typo'),
        throwsA(isA<BackupDecryptionException>()),
      );
      expect(vault.value, isNull);
      await settings.setAutomaticBackup(true, password: 'first');
      final next = SettingsProvider(db.preferences, backupPasswordStore: vault);
      expect(
        await next.resolveBackupEncryptionPassword(
          () async => fail('unexpected prompt'),
        ),
        'first',
      );
      vault.value = 'unexpected credential';
      await expectLater(
        next.automaticBackupPassword(),
        throwsA(isA<BackupDecryptionException>()),
      );
      expect(vault.value, 'unexpected credential');
      vault.value = 'first';
      vault.cancelAuthorization = true;
      final oldVerifier = db.preferences.getString(
        'backup_password_verifier_v1',
      );
      await expectLater(
        next.setBackupEncryptionPassword('cancelled change'),
        throwsA(isA<BackupMacKeychainAccessError>()),
      );
      expect(next.autoBackupEnabled, true);
      expect(vault.value, 'first');
      expect(
        db.preferences.getString('backup_password_verifier_v1'),
        oldVerifier,
      );
      await next.retryBackupPasswordRemoval();
      expect(await next.automaticBackupPassword(), 'first');
      vault.cancelAuthorization = false;
      await next.setBackupEncryptionPassword('second');
      expect(vault.value, 'second');
      vault.available = false;
      await expectLater(
        next.automaticBackupPassword(),
        throwsA(isA<BackupKeychainUnavailable>()),
      );
      expect(next.autoBackupEnabled, true);
      await expectLater(
        next.setBackupEncryptionPassword('third'),
        throwsA(isA<BackupKeychainUnavailable>()),
      );
      expect(next.autoBackupEnabled, false);
      expect(vault.value, 'second');
      vault.available = true;
      await next.retryBackupPasswordRemoval();
      expect(vault.value, null);
      await next.setAutomaticBackup(true, password: 'third');
      await next.setAutomaticBackup(false);
      expect(vault.value, null);
      var prompted = false;
      await next.resolveBackupEncryptionPassword(() async {
        prompted = true;
        return 'third';
      });
      expect(prompted, true);
      await next.setAutomaticBackup(true, password: 'third');
      await next.setBackupEncryptionPassword(null);
      expect(next.autoBackupEnabled, false);
      expect(vault.value, null);
    },
  );

  test(
    'desktop folder preference on mobile requires explicit selection of a remote',
    () async {
      final db = await createBusinessTestHarness(
        initial: {
          'backup_auto_destination_v1': 'local',
          'backup_auto_local_dir_v1': '/chosen',
        },
      );
      final settings = SettingsProvider(db.preferences);
      await settings.loaded;
      await settings.updateWebDavConfig(
        (cfg) => cfg.copyWith(url: 'https://backup.example'),
      );
      final reminder = BackupReminderProvider(
        preferences: db.preferences,
        autoLoad: false,
      );
      await reminder.saveSchedule(
        enabled: true,
        intervalDays: 1,
        reminderMinutesOfDay: 0,
      );
      final auto = ExternalBackupAutoProvider(
        preferences: db.preferences,
        settings: settings,
        reminder: reminder,
        webdav: _WebDav(db),
        s3: S3BackupProvider(
          chatService: ChatService(),
          businessRepository: db.repository,
          businessPreferences: db.preferences,
        ),
        desktop: false,
      );
      expect(auto.available, [BackupDestination.webdav]);
      await expectLater(
        auto.enable(true),
        throwsA(BackupDestinationError.remote),
      );
      await auto.select(BackupDestination.webdav);
      await auto.enable(true);
      expect(auto.folder.path, '/chosen');
      expect(auto.destination, BackupDestination.webdav);
    },
  );
}
