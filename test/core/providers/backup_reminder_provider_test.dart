import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/backup_reminder_provider.dart';

Future<BackupReminderProvider> _loadProvider() async {
  final provider = BackupReminderProvider(autoLoad: false);
  await provider.load(startTimer: false);
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupReminderProvider', () {
    test('defaults to disabled with no due reminder', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = await _loadProvider();

      expect(provider.enabled, isFalse);
      expect(provider.shouldShowReminder, isFalse);
      expect(provider.nextReminderAt, isNull);
    });

    test('requires a chosen time before enabling', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = await _loadProvider();

      expect(
        () => provider.setEnabled(true, now: DateTime(2026, 5, 5)),
        throwsStateError,
      );
    });

    test('enables a weekly reminder from the chosen time', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = await _loadProvider();
      final enabledAt = DateTime(2026, 5, 5, 9);

      await provider.saveSchedule(
        enabled: true,
        intervalDays: 7,
        reminderMinutesOfDay: 20 * 60,
        now: enabledAt,
      );

      expect(provider.enabled, isTrue);
      expect(provider.intervalDays, 7);
      expect(provider.reminderMinutesOfDay, 20 * 60);
      expect(provider.nextReminderAt, DateTime(2026, 5, 12, 20));
      provider.evaluateDue(DateTime(2026, 5, 12, 19, 59));
      expect(provider.shouldShowReminder, isFalse);
      provider.evaluateDue(DateTime(2026, 5, 12, 20));
      expect(provider.shouldShowReminder, isTrue);
    });

    test('persists custom interval and validates supported range', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = await _loadProvider();

      expect(
        () => provider.saveSchedule(
          enabled: true,
          intervalDays: 0,
          reminderMinutesOfDay: 9 * 60,
          now: DateTime(2026, 5, 5),
        ),
        throwsArgumentError,
      );
      expect(
        () => provider.saveSchedule(
          enabled: true,
          intervalDays: 366,
          reminderMinutesOfDay: 9 * 60,
          now: DateTime(2026, 5, 5),
        ),
        throwsArgumentError,
      );

      await provider.saveSchedule(
        enabled: true,
        intervalDays: 45,
        reminderMinutesOfDay: 8 * 60 + 30,
        now: DateTime(2026, 5, 5, 12),
      );

      final loaded = await _loadProvider();

      expect(loaded.enabled, isTrue);
      expect(loaded.intervalDays, 45);
      expect(loaded.reminderMinutesOfDay, 8 * 60 + 30);
      expect(loaded.nextReminderAt, DateTime(2026, 6, 19, 8, 30));
    });

    test('shows missed due reminder after a new provider load', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = await _loadProvider();

      await provider.saveSchedule(
        enabled: true,
        intervalDays: 3,
        reminderMinutesOfDay: 10 * 60,
        now: DateTime(2026, 5, 1, 8),
      );

      final loaded = await _loadProvider();
      loaded.evaluateDue(DateTime(2026, 5, 4, 10, 1));

      expect(loaded.shouldShowReminder, isTrue);
    });

    test(
      'snooze hides the reminder only for the current provider session',
      () async {
        SharedPreferences.setMockInitialValues({});
        final provider = await _loadProvider();

        await provider.saveSchedule(
          enabled: true,
          intervalDays: 1,
          reminderMinutesOfDay: 9 * 60,
          now: DateTime(2026, 5, 1, 8),
        );
        provider.evaluateDue(DateTime(2026, 5, 2, 9));
        expect(provider.shouldShowReminder, isTrue);

        provider.snoozeForSession();
        expect(provider.shouldShowReminder, isFalse);

        final loaded = await _loadProvider();
        loaded.evaluateDue(DateTime(2026, 5, 2, 9));
        expect(loaded.shouldShowReminder, isTrue);
      },
    );

    test(
      'successful backup resets the next reminder from backup time',
      () async {
        SharedPreferences.setMockInitialValues({});
        final provider = await _loadProvider();

        await provider.saveSchedule(
          enabled: true,
          intervalDays: 14,
          reminderMinutesOfDay: 21 * 60 + 15,
          now: DateTime(2026, 5, 1, 8),
        );
        provider.evaluateDue(DateTime(2026, 5, 20, 9));
        expect(provider.shouldShowReminder, isTrue);

        await provider.recordBackupCompleted(now: DateTime(2026, 5, 20, 9));

        expect(provider.lastBackupAt, DateTime(2026, 5, 20, 9));
        expect(provider.shouldShowReminder, isFalse);
        expect(provider.nextReminderAt, DateTime(2026, 6, 3, 21, 15));
      },
    );
  });
}
