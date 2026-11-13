import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/providers/webdav_backup_schedule_provider.dart';
import 'package:Kelivo/core/services/backup/backup_activity.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/business_preferences_test_harness.dart';

class _ScheduleStore extends WebDavBackupScheduleStore {
  WebDavBackupScheduleSettings settings = const WebDavBackupScheduleSettings();
  WebDavBackupScheduleState state = const WebDavBackupScheduleState();

  @override
  Future<WebDavBackupScheduleSettings> readSettings() async => settings;
  @override
  Future<void> writeSettings(WebDavBackupScheduleSettings value) async {
    settings = value;
  }

  @override
  Future<WebDavBackupScheduleState> readState() async => state;
  @override
  Future<void> writeState(WebDavBackupScheduleState value) async {
    state = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BusinessPreferencesTestHarness harness;
  late BusinessPreferencesTestSession session;
  late _ScheduleStore store;
  final now = DateTime.utc(2026, 10, 22, 12);

  setUp(() async {
    BackupActivity.debugReset();
    harness = await BusinessPreferencesTestHarness.create();
    session = await harness.open();
    store = _ScheduleStore();
    await session.preferences.setString(
      'webdav_config_v1',
      jsonEncode({'url': 'https://dav.example.com', 'path': 'kelivo_backups'}),
    );
  });
  tearDown(() async {
    BackupActivity.debugReset();
    await harness.dispose();
  });

  WebDavBackupScheduleProvider provider({
    required Future<void> Function(BackupCancelToken) backup,
    Future<bool> Function(bool)? network,
  }) => WebDavBackupScheduleProvider(
    preferences: session.preferences,
    backup: backup,
    store: store,
    networkAvailable: network ?? (_) async => true,
    syncSchedule: (_) async {},
    now: () => now,
    autoLoad: false,
  );

  test('enabling validates server and arms a future first run', () async {
    final vm = provider(backup: (_) async {});
    await vm.refresh();
    expect(vm.settings.enabled, isFalse);
    await vm.updateSettings(vm.settings.copyWith(enabled: true));
    expect(vm.nextRunAt, now.add(const Duration(hours: 24)));
    await session.preferences.remove('webdav_config_v1');
    expect(
      () => vm.updateSettings(vm.settings.copyWith(enabled: true)),
      throwsStateError,
    );
    vm.dispose();
  });

  test(
    'offline Wi-Fi policy defers without uploading or recording success',
    () async {
      var uploads = 0;
      final vm = provider(
        backup: (_) async => uploads++,
        network: (_) async => false,
      );
      expect(await vm.runNow(), isFalse);
      expect(uploads, 0);
      expect(vm.state.lastSuccess, isNull);
      expect(vm.state.lastAttempt, isNull);
      expect(vm.state.lastError, 'wifi_required');
      vm.dispose();
    },
  );

  for (final force in [false, true]) {
    test(
      '${force ? 'run now' : 'due schedule'} waits for manual encryption confirmation without uploading',
      () async {
        final previous = now.subtract(const Duration(days: 3));
        store.settings = WebDavBackupScheduleSettings(
          enabled: true,
          enabledAt: now.subtract(const Duration(days: 2)),
        );
        store.state = WebDavBackupScheduleState(lastSuccess: previous);
        await session.preferences.setBool('backup_encryption_enabled_v1', true);
        var uploads = 0;
        var networkChecks = 0;
        final vm = provider(
          backup: (_) async => uploads++,
          network: (_) async {
            networkChecks++;
            return true;
          },
        );

        expect(await (force ? vm.runNow() : vm.runIfDue()), isFalse);
        expect(uploads, 0);
        expect(networkChecks, 0);
        expect(vm.state.lastSuccess, previous);
        expect(vm.state.lastAttempt, isNull);
        expect(vm.state.lastError, 'backup_password_required');
        expect(store.state.lastError, 'backup_password_required');
        expect(BackupActivity.isActive, isFalse);

        await session.preferences.setBool(
          'backup_encryption_enabled_v1',
          false,
        );
        expect(await vm.runNow(), isTrue);
        expect(uploads, 1);
        expect(vm.state.lastError, isNull);
        vm.dispose();
      },
    );
  }

  test(
    'only one backup runs and success is recorded after upload completes',
    () async {
      final started = Completer<void>();
      final finish = Completer<void>();
      var uploads = 0;
      final vm = provider(
        backup: (_) async {
          uploads++;
          started.complete();
          await finish.future;
        },
      );
      final first = vm.runNow();
      await started.future;
      expect(vm.busy, isTrue);
      expect(vm.state.lastSuccess, isNull);
      expect(await vm.runNow(), isFalse);
      expect(uploads, 1);
      finish.complete();
      expect(await first, isTrue);
      expect(vm.state.lastSuccess, now);
      expect(vm.state.lastError, isNull);
      expect(vm.busy, isFalse);
      expect(BackupActivity.isActive, isFalse);
      vm.dispose();
    },
  );

  test(
    'changing network policy clears a stale waiting-for-Wi-Fi message',
    () async {
      final vm = provider(backup: (_) async {}, network: (_) async => false);
      expect(await vm.runNow(), isFalse);
      expect(vm.state.lastError, 'wifi_required');
      await vm.updateSettings(vm.settings.copyWith(wifiOnly: false));
      expect(vm.state.lastError, isNull);
      expect(store.state.lastError, isNull);
      expect(vm.settings.wifiOnly, isFalse);
      vm.dispose();
    },
  );

  test(
    'changing network policy stops an upload using the old policy',
    () async {
      final started = Completer<void>();
      final vm = provider(
        backup: (token) async {
          started.complete();
          await token.whenCancelled;
          throw const BackupCancelledException();
        },
      );
      final upload = vm.runNow();
      await started.future;
      await vm.updateSettings(vm.settings.copyWith(wifiOnly: false));
      expect(await upload, isFalse);
      expect(vm.busy, isFalse);
      expect(vm.state.lastSuccess, isNull);
      expect(vm.state.lastError, isNull);
      vm.dispose();
    },
  );

  test(
    'manual restore handoff waits until cancelled SQLite worker exits',
    () async {
      final started = Completer<void>();
      final workerExited = Completer<void>();
      final vm = provider(
        backup: (token) async {
          started.complete();
          await token.whenCancelled;
          throw BackupCancelledException(
            isolateExited: false,
            isolateExit: workerExited.future,
          );
        },
      );
      final upload = vm.runNow();
      await started.future;
      BackupActivity.begin();
      var handedOff = false;
      final handoff = BackupActivity.cancelAutomaticAndWait().then((_) {
        handedOff = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(handedOff, isFalse);
      expect(vm.busy, isTrue);
      workerExited.complete();
      await handoff;
      expect(await upload, isFalse);
      expect(handedOff, isTrue);
      expect(vm.state.lastError, isNull);
      // The manual task still owns its own activity count.
      expect(BackupActivity.isActive, isTrue);
      BackupActivity.end();
      expect(BackupActivity.isActive, isFalse);
      vm.dispose();
    },
  );

  test(
    'failed upload retains last success and persists a redacted outcome',
    () async {
      final previous = now.subtract(const Duration(days: 1));
      store.state = WebDavBackupScheduleState(lastSuccess: previous);
      final vm = provider(
        backup: (_) async => throw Exception(
          'Upload https://alice:secret@example.com/private failed: 503',
        ),
      );
      expect(await vm.runNow(), isFalse);
      expect(vm.state.lastSuccess, previous);
      expect(vm.state.lastAttempt, now);
      expect(vm.state.lastError, contains('503'));
      expect(vm.state.lastError, isNot(contains('secret')));
      expect(store.state.lastError, vm.state.lastError);
      vm.dispose();
    },
  );
}
