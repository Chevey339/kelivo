import 'package:Kelivo/core/services/backup/webdav_backup_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final enabledAt = DateTime.utc(2026, 10, 22, 9);

  test('first run waits a complete interval after enabling', () {
    final settings = WebDavBackupScheduleSettings(
      enabled: true,
      intervalHours: 6,
      enabledAt: enabledAt,
    );
    const state = WebDavBackupScheduleState();
    expect(
      WebDavBackupSchedule.nextRunAt(settings, state),
      DateTime.utc(2026, 10, 22, 15),
    );
    expect(
      WebDavBackupSchedule.isDue(
        settings,
        state,
        DateTime.utc(2026, 10, 22, 14, 59),
      ),
      isFalse,
    );
    expect(
      WebDavBackupSchedule.isDue(
        settings,
        state,
        DateTime.utc(2026, 10, 22, 15),
      ),
      isTrue,
    );
  });

  test('successful manual backup restarts the scheduled interval', () {
    final settings = WebDavBackupScheduleSettings(
      enabled: true,
      enabledAt: enabledAt,
    );
    final success = enabledAt.add(const Duration(hours: 2));
    expect(
      WebDavBackupSchedule.nextRunAt(
        settings,
        WebDavBackupScheduleState(lastSuccess: success),
      ),
      success.add(const Duration(hours: 24)),
    );
  });

  test('a failed due upload waits before retrying and preserves cadence', () {
    final settings = WebDavBackupScheduleSettings(
      enabled: true,
      intervalHours: 1,
      enabledAt: enabledAt,
    );
    final failedAt = enabledAt.add(const Duration(hours: 1));
    final state = WebDavBackupScheduleState(
      lastAttempt: failedAt,
      lastError: 'Upload failed: 503',
    );
    expect(
      WebDavBackupSchedule.nextRunAt(settings, state),
      failedAt.add(const Duration(minutes: 15)),
    );
    expect(
      WebDavBackupSchedule.nextRunAt(settings.copyWith(enabled: false), state),
      isNull,
    );
  });

  test('malformed stored interval cannot create a tight backup loop', () {
    final settings = WebDavBackupScheduleSettings.fromJson({
      'enabled': true,
      'intervalHours': -1,
      'enabledAt': enabledAt.toIso8601String(),
    });
    expect(settings.intervalHours, 24);
    expect(settings.wifiOnly, isTrue);
    expect(
      WebDavBackupScheduleSettings.fromJson({
        'intervalHours': 6.0,
      }).intervalHours,
      24,
    );
    expect(
      WebDavBackupScheduleSettings.fromJson(settings.toJson()).enabledAt,
      enabledAt,
    );
  });

  test('stored failures do not expose WebDAV URLs or Basic credentials', () {
    final error = WebDavBackupSchedule.safeError(
      Exception(
        'GET https://alice:secret@example.com/private/backup.zip '
        'failed; Authorization: Basic YWxpY2U6c2VjcmV0',
      ),
    );
    expect(error, isNot(contains('alice')));
    expect(error, isNot(contains('secret')));
    expect(error, isNot(contains('example.com')));
    expect(error, isNot(contains('YWxpY2U6c2VjcmV0')));
  });

  test('required encryption confirmation has a stable user-facing code', () {
    expect(
      WebDavBackupSchedule.safeError(
        const FormatException('backup_password_required'),
      ),
      'backup_password_required',
    );
  });
}
