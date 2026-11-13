import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../database/business_preferences.dart';
import '../models/backup.dart';
import '../services/backup/backup_activity.dart';
import '../services/backup/backup_cancel_token.dart';
import '../services/backup/backup_isolate_runner.dart';
import '../services/backup/webdav_background_backup.dart';
import '../services/backup/webdav_backup_schedule.dart';

export '../services/backup/webdav_backup_schedule.dart';

/// The same schedule is used by the visible app and Android WorkManager.
class WebDavBackupScheduleProvider extends ChangeNotifier {
  WebDavBackupScheduleProvider({
    required BusinessPreferences preferences,
    required Future<void> Function(BackupCancelToken token) backup,
    bool Function()? isBusy,
    WebDavBackupScheduleStore? store,
    Future<bool> Function(bool wifiOnly)? networkAvailable,
    Future<void> Function(WebDavBackupScheduleSettings)? syncSchedule,
    DateTime Function()? now,
    bool autoLoad = true,
  }) : // Keep the public injection names independent of private storage.
       // ignore: prefer_initializing_formals
       _preferences = preferences,
       // ignore: prefer_initializing_formals
       _backup = backup,
       _isBusy = isBusy ?? (() => false),
       _store = store ?? WebDavBackupScheduleStore(),
       _networkAvailable =
           networkAvailable ?? WebDavBackupSchedule.networkAvailable,
       _syncSchedule = syncSchedule ?? WebDavBackgroundBackup.syncSchedule,
       _now = now ?? DateTime.now {
    if (autoLoad) unawaited(refresh());
  }

  final BusinessPreferences _preferences;
  final Future<void> Function(BackupCancelToken token) _backup;
  final bool Function() _isBusy;
  final WebDavBackupScheduleStore _store;
  final Future<bool> Function(bool wifiOnly) _networkAvailable;
  final Future<void> Function(WebDavBackupScheduleSettings) _syncSchedule;
  final DateTime Function() _now;

  WebDavBackupScheduleSettings _settings = const WebDavBackupScheduleSettings();
  WebDavBackupScheduleState _state = const WebDavBackupScheduleState();
  bool _initialized = false;
  bool _busy = false;
  bool _disposed = false;
  BackupCancelToken? _cancelToken;
  Future<bool>? _running;

  WebDavBackupScheduleSettings get settings => _settings;
  WebDavBackupScheduleState get state => _state;
  bool get initialized => _initialized;
  bool get busy => _busy;
  bool get supportsBackground => Platform.isAndroid;
  DateTime? get nextRunAt => WebDavBackupSchedule.nextRunAt(_settings, _state);

  bool get configured {
    try {
      final value = _preferences.getString('webdav_config_v1');
      if (value == null) return false;
      final config = WebDavConfig.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
      final uri = Uri.tryParse(config.url.trim());
      return uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> refresh() async {
    try {
      _settings = await _store.readSettings();
      _state = await _store.readState();
      await _syncSchedule(_settings);
    } catch (error) {
      _state = WebDavBackupScheduleState(
        lastAttempt: _state.lastAttempt,
        lastSuccess: _state.lastSuccess,
        lastError: WebDavBackupSchedule.safeError(error),
      );
    } finally {
      _initialized = true;
      _notify();
    }
  }

  Future<void> updateSettings(WebDavBackupScheduleSettings next) async {
    if (next.enabled && !configured) {
      throw StateError('webdav_not_configured');
    }
    if (!WebDavBackupScheduleSettings.intervalPresets.contains(
      next.intervalHours,
    )) {
      throw ArgumentError.value(next.intervalHours, 'intervalHours');
    }
    final resetCadence =
        next.enabled &&
        (!_settings.enabled ||
            _settings.intervalHours != next.intervalHours ||
            _settings.enabledAt == null);
    final saved = resetCadence
        ? next.copyWith(enabledAt: _now().toUtc())
        : next;
    final networkPolicyChanged = saved.wifiOnly != _settings.wifiOnly;
    await _store.writeSettings(saved);
    _settings = saved;
    if (!saved.enabled || networkPolicyChanged) await cancelAndWait();
    if (const {
      'wifi_required',
      'network_unavailable',
      'backup_busy',
    }.contains(_state.lastError)) {
      _state = WebDavBackupScheduleState(
        lastAttempt: _state.lastAttempt,
        lastSuccess: _state.lastSuccess,
      );
      await _store.writeState(_state);
    }
    await _syncSchedule(saved);
    _notify();
  }

  Future<bool> runIfDue() => _run(force: false);
  Future<bool> runNow() => _run(force: true);

  Future<void> cancelAndWait() async {
    _cancelToken?.cancel();
    await _running;
  }

  Future<bool> _run({required bool force}) {
    if (_busy ||
        BackupActivity.isActive ||
        WebDavBackgroundBackup.isBackgroundRunning ||
        _isBusy()) {
      if (force) {
        _state = WebDavBackupScheduleState(
          lastAttempt: _state.lastAttempt,
          lastSuccess: _state.lastSuccess,
          lastError: 'backup_busy',
        );
        _notify();
      }
      return Future<bool>.value(false);
    }
    _busy = true;
    _notify();
    final cancelled = BackupCancelToken();
    _cancelToken = cancelled;
    final completion = Completer<void>();
    BackupActivity.registerAutomatic(completion.future, cancelled.cancel);
    var timedOut = false;
    final deadline = Timer(const Duration(minutes: 7, seconds: 30), () {
      timedOut = true;
      cancelled.cancel();
    });
    // Mark synchronously before the first I/O so a local snapshot cannot race
    // a schedule that has passed its due check but is still checking Wi-Fi.
    BackupActivity.begin();
    final running =
        _execute(
          force: force,
          cancelToken: cancelled,
          timedOut: () => timedOut,
        ).whenComplete(() {
          deadline.cancel();
          BackupActivity.end();
          BackupActivity.clearAutomatic(completion.future);
          completion.complete();
          _cancelToken = null;
          _running = null;
          _busy = false;
          cancelled.dispose();
          _notify();
        });
    _running = running;
    return running;
  }

  Future<bool> _execute({
    required bool force,
    required BackupCancelToken cancelToken,
    required bool Function() timedOut,
  }) async {
    try {
      _settings = await _store.readSettings();
      _state = await _store.readState();
      if (!force &&
          !WebDavBackupSchedule.isDue(_settings, _state, _now().toUtc())) {
        return false;
      }
      cancelToken.throwIfCancelled();
      if (!configured) {
        await _recordSkipped('webdav_not_configured');
        return false;
      }
      if (_preferences.getBool('backup_encryption_enabled_v1') == true) {
        await _recordSkipped('backup_password_required');
        return false;
      }
      if (!await _networkAvailable(_settings.wifiOnly)) {
        await _recordSkipped(
          _settings.wifiOnly ? 'wifi_required' : 'network_unavailable',
        );
        return false;
      }
      cancelToken.throwIfCancelled();
      final attempted = _now().toUtc();
      _state = WebDavBackupScheduleState(
        lastAttempt: attempted,
        lastSuccess: _state.lastSuccess,
      );
      await _store.writeState(_state);
      _notify();
      await _backup(cancelToken);
      cancelToken.throwIfCancelled();
      _state = WebDavBackupScheduleState(
        lastAttempt: attempted,
        lastSuccess: _now().toUtc(),
      );
      await _store.writeState(_state);
      return true;
    } catch (error) {
      // A cancelled snapshot isolate can still own a SQLite handle. A manual
      // restore waiting on BackupActivity must not proceed until it exits.
      final workerExit = backupIsolateExitFuture(error);
      if (workerExit != null) await workerExit;
      if (!timedOut() &&
          (error is BackupCancelledException || cancelToken.isCancelled)) {
        return false;
      }
      _state = WebDavBackupScheduleState(
        lastAttempt: _state.lastAttempt ?? _now().toUtc(),
        lastSuccess: _state.lastSuccess,
        lastError: timedOut()
            ? 'backup_timeout'
            : WebDavBackupSchedule.safeError(error),
      );
      try {
        await _store.writeState(_state);
      } catch (_) {
        // The standing in-memory error is still useful when preferences
        // themselves are unavailable; an unattended timer must finish cleanly.
      }
      return false;
    }
  }

  Future<void> _recordSkipped(String message) async {
    _state = WebDavBackupScheduleState(
      lastAttempt: _state.lastAttempt,
      lastSuccess: _state.lastSuccess,
      lastError: message,
    );
    await _store.writeState(_state);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelToken?.cancel();
    super.dispose();
  }
}
