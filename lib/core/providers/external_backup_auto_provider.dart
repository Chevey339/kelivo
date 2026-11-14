import 'dart:io';
import 'package:flutter/foundation.dart';

import '../database/business_preferences.dart';
import '../services/backup/backup_activity.dart';
import '../services/backup/backup_cancel_token.dart';
import '../services/backup/backup_folder_access.dart';
import '../services/backup/backup_partials.dart';
import '../services/backup/backup_task_progress.dart';
import '../services/backup/data_sync.dart';
import '../services/backup/local_folder_backup.dart';
import 'backup_provider.dart';
import 'backup_reminder_provider.dart';
import 's3_backup_provider.dart';
import 'settings_provider.dart';

enum BackupDestination { webdav, s3, local }

enum BackupDestinationError implements Exception { remote, destination, folder }

class ExternalBackupAutoProvider extends ChangeNotifier {
  ExternalBackupAutoProvider({
    required this.preferences,
    required this.settings,
    required this.reminder,
    required this.webdav,
    required this.s3,
    this.folders = const BackupFolderAccess(),
    this.clock = DateTime.now,
    bool? desktop,
  }) : desktop = desktop ?? BackupFolderAccess.isDesktop;

  final BusinessPreferences preferences;
  final SettingsProvider settings;
  final BackupReminderProvider reminder;
  final BackupProvider webdav;
  final S3BackupProvider s3;
  final BackupFolderAccess folders;
  final DateTime Function() clock;
  final bool desktop;

  static const _destinationKey = 'backup_auto_destination_v1';
  static const _lastKey = 'backup_auto_last_destination_v1';
  static const _dirKey = 'backup_auto_local_dir_v1';
  static const _bookmarkKey = 'backup_auto_local_bookmark_v1';
  static const _retentionKey = 'backup_auto_local_retention_v1';
  bool get enabled => settings.autoBackupEnabled;
  BackupFolder get folder => (
    path: preferences.getString(_dirKey) ?? '',
    bookmark: preferences.getString(_bookmarkKey) ?? '',
  );
  int get retention => preferences.getInt(_retentionKey) ?? 5;
  BackupCancelToken? _active;
  bool get busy => _active != null;
  bool get cancellable => _active?.cancellable ?? false;
  Object? failure;
  DateTime? _attemptedDue;
  Future<void>? _folderCleanup;
  List<BackupDestination> get available => [
    if (settings.webDavConfig.url.trim().isNotEmpty) BackupDestination.webdav,
    if (settings.s3Config.endpoint.trim().isNotEmpty &&
        settings.s3Config.bucket.trim().isNotEmpty &&
        settings.s3Config.accessKeyId.trim().isNotEmpty)
      BackupDestination.s3,
    if (desktop && folder.path.isNotEmpty) BackupDestination.local,
  ];

  BackupDestination? get savedDestination => BackupDestination.values
      .where((d) => d.name == preferences.getString(_destinationKey))
      .firstOrNull;
  BackupDestination? get destination {
    if (savedDestination case final value?) return value;
    final options = available;
    return options
            .where((d) => d.name == preferences.getString(_lastKey))
            .firstOrNull ??
        options.firstOrNull;
  }

  Future<void> select(BackupDestination value) async {
    if (!available.contains(value)) throw BackupDestinationError.destination;
    await preferences.setString(_destinationKey, value.name);
    resetAttempt();
    notifyListeners();
  }

  Future<void> enable(bool value, {String? password}) async {
    if (value) {
      if (!reminder.enabled) return;
      final options = available;
      final selected = destination;
      if (selected == null || !options.contains(selected)) {
        throw desktop
            ? BackupDestinationError.destination
            : BackupDestinationError.remote;
      }
      await preferences.setString(_destinationKey, selected.name);
    }
    await settings.setAutomaticBackup(value, password: password);
    resetAttempt();
    notifyListeners();
  }

  Future<void> chooseFolder() async {
    if (!desktop || busy) return;
    final selected = await folders.choose();
    if (selected == null) return;
    var bookmark = selected.bookmark;
    await folders.access(
      selected,
      refresh: (value) async {
        bookmark = value;
      },
      run: (_) async {},
    );
    await preferences.setMany({
      _dirKey: selected.path,
      _bookmarkKey: bookmark,
      _destinationKey: BackupDestination.local.name,
    });
    resetAttempt();
    notifyListeners();
  }

  Future<void> setRetention(int value) async {
    if (!const [0, 3, 5, 10].contains(value)) throw ArgumentError.value(value);
    await preferences.setInt(_retentionKey, value);
    notifyListeners();
  }

  Future<void> _withFolder(
    Future<void> Function(LocalFolderBackup) action,
  ) async {
    if (!desktop || folder.path.isEmpty) throw BackupDestinationError.folder;
    final selected = folder;
    final id = await BackupPartials.installationId(preferences);
    await folders.access(
      selected,
      refresh: (bookmark) async {
        if (folder == selected) {
          await preferences.setString(_bookmarkKey, bookmark);
        }
      },
      run: (dir) =>
          action(LocalFolderBackup(dir, id, BackupPartials(preferences))),
    );
  }

  Future<void> cleanupDestinations() async {
    Future<void> quiet(Future<void> Function() clean) async {
      try {
        await clean();
      } catch (_) {}
    }

    final options = available;
    await Future.wait([
      if (options.contains(BackupDestination.local) && !busy)
        _folderCleanup ??= quiet(
          () => _withFolder((local) => local.cleanup()),
        ).whenComplete(() => _folderCleanup = null),
      if (options.contains(BackupDestination.webdav))
        quiet(() => webdav.cleanPartials(settings.webDavConfig)),
      if (options.contains(BackupDestination.s3))
        quiet(() => s3.cleanPartials(settings.s3Config)),
    ]);
  }

  void allowNextCheck() {
    _attemptedDue = null;
  }

  void resetAttempt() {
    _attemptedDue = null;
    failure = null;
  }

  void cancel() => _active?.cancel();

  /// Used by both the progress dialog and the foreground due check.
  Future<void> run(
    BackupDestination target, {
    required Future<String?> Function() password,
    required BackupCancelToken token,
    BackupProgressSink? onProgress,
  }) async {
    if (busy || BackupActivity.externalActive) {
      throw StateError('Backup already running');
    }
    BackupActivity.externalActive = true;
    _active = token;
    var wasCancellable = token.cancellable;
    notifyListeners();
    void report(BackupProgress progress) {
      if (!progress.cancellable) token.setCancellable(false);
      onProgress?.call(progress);
      if (wasCancellable != token.cancellable) {
        wasCancellable = token.cancellable;
        notifyListeners();
      }
    }

    try {
      final secret = await password();
      token.throwIfCancelled();
      switch (target) {
        case BackupDestination.webdav:
          webdav.updateConfig(settings.webDavConfig);
          if (!await webdav.backup(
            password: secret,
            onProgress: report,
            cancelToken: token,
          )) {
            throw Exception(webdav.message ?? 'WebDAV backup failed');
          }
        case BackupDestination.s3:
          s3.updateConfig(settings.s3Config);
          if (!await s3.backup(
            password: secret,
            onProgress: report,
            cancelToken: token,
          )) {
            throw Exception(s3.message ?? 'S3 backup failed');
          }
        case BackupDestination.local:
          await _folderCleanup;
          await _withFolder((local) async {
            webdav.updateConfig(settings.webDavConfig);
            File? file;
            try {
              file = await webdav.exportToFile(
                password: secret,
                onProgress: report,
                cancelToken: token,
              );
              await local.publish(
                file,
                retention: retention,
                cancelToken: token,
                onProgress: report,
              );
            } finally {
              await DataSync.cleanupTemporaryBackupFile(file);
            }
          });
      }
      await reminder.recordBackupCompleted(now: clock());
      await preferences.setString(_lastKey, target.name);
      resetAttempt();
    } finally {
      _active = null;
      BackupActivity.externalActive = false;
      notifyListeners();
    }
  }

  Future<bool> runIfDue(DateTime now, {required bool foreground}) async {
    final due = reminder.nextReminderAt;
    if (!foreground ||
        !enabled ||
        !reminder.enabled ||
        due == null ||
        now.isBefore(due) ||
        busy ||
        BackupActivity.isActive ||
        _attemptedDue == due) {
      return false;
    }
    _attemptedDue = due;
    final token = BackupCancelToken();
    BackupActivity.begin();
    try {
      final target = destination;
      if (target == null || !available.contains(target)) {
        if (target == BackupDestination.local && desktop) {
          throw BackupDestinationError.folder;
        }
        throw desktop
            ? BackupDestinationError.destination
            : BackupDestinationError.remote;
      }
      await run(
        target,
        password: settings.automaticBackupPassword,
        token: token,
      );
      return true;
    } catch (error) {
      failure = error;
      rethrow;
    } finally {
      token.dispose();
      BackupActivity.end();
      notifyListeners();
    }
  }
}
