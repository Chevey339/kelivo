import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:workmanager/workmanager.dart';

import '../../database/app_database.dart';
import '../../database/business_preferences.dart';
import '../../database/chat_database_gateway.dart';
import '../../database/chat_database_repository.dart';
import '../../database/database_family_preserver.dart';
import '../../database/database_installation_gate.dart';
import '../../database/empty_database_recovery_guard.dart';
import '../../models/backup.dart';
import '../../../utils/app_directories.dart';
import 'backup_cancel_token.dart';
import 'backup_isolate_runner.dart';
import 'data_sync.dart';
import 'restore_business_lease.dart';
import 'restore_startup_gate.dart';
import 'webdav_backup_schedule.dart';

/// Retained as a top-level entry point for Android's headless Flutter engine.
@pragma('vm:entry-point')
void webDavBackupCallbackDispatcher() {
  Workmanager().executeTask(
    (task, _) async {
      if (task != WebDavBackgroundBackup.taskName) return true;
      return WebDavBackgroundBackup.runBackgroundTask();
    },
    onTaskStopped: (task, _) async {
      if (task == WebDavBackgroundBackup.taskName) {
        await WebDavBackgroundBackup.stopBackgroundTask();
      }
    },
  );
}

/// Android scheduling and the handoff between headless and visible engines.
///
/// A running app owns the business lease for its lifetime, so a headless worker
/// asks that engine to do the backup. With no running app, it takes the same
/// lease as startup, packs a consistent archive, then closes the database and
/// releases the lease before uploading. A newly launched app cancels the worker
/// and waits for cleanup before opening business data or changing its schedule.
final class WebDavBackgroundBackup {
  WebDavBackgroundBackup._();

  static const taskName = 'kelivo.webdav.periodic-backup';
  static const _uniqueName = 'kelivo-webdav-periodic-backup-v1';
  static const _foregroundPortName = 'kelivo.webdav.foreground.v1';
  static const _backgroundPortName = 'kelivo.webdav.background.v1';
  static const _startupPortName = 'kelivo.webdav.startup.v1';
  static const _workerBudget = Duration(minutes: 8);

  static Future<void>? _initializing;
  static ReceivePort? _foregroundPort;
  static ReceivePort? _startupPort;
  static Future<bool>? _activeWork;
  static BackupCancelToken? _activeCancelToken;
  static SendPort? _delegatedForeground;

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static bool get isBackgroundRunning =>
      IsolateNameServer.lookupPortByName(_backgroundPortName) != null;

  static Future<void> initialize() {
    if (!isSupported) return Future<void>.value();
    return _initializing ??= Workmanager().initialize(
      webDavBackupCallbackDispatcher,
    );
  }

  static Future<void> syncSchedule(
    WebDavBackupScheduleSettings settings,
  ) async {
    if (!isSupported) return;
    await initialize();
    if (!settings.enabled) {
      await Workmanager().cancelByUniqueName(_uniqueName);
      return;
    }
    final state = await WebDavBackupScheduleStore().readState();
    final due = WebDavBackupSchedule.nextRunAt(settings, state);
    final remaining = due?.difference(DateTime.now().toUtc());
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      taskName,
      // Check often; the persisted due time is authoritative. Repeating at the
      // selected cadence would drift because upload completion moves the next
      // due time beyond WorkManager's fixed interval boundary.
      frequency: const Duration(minutes: 15),
      initialDelay: remaining == null || remaining.isNegative
          ? Duration.zero
          : remaining,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(
        networkType: settings.wifiOnly
            ? NetworkType.unmetered
            : NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: WebDavBackupSchedule.failureRetryDelay,
    );
  }

  /// Keeps the visible engine usable by WorkManager even while it is paused.
  static void attachForeground(
    Future<bool> Function() runIfDue, {
    required Future<void> Function() cancelAndWait,
  }) {
    if (!isSupported) return;
    detachForeground();
    // Reaching the visible tree proves that this engine owns the business
    // lease. Any mapping left by a predecessor engine is therefore stale.
    IsolateNameServer.removePortNameMapping(_foregroundPortName);
    final port = ReceivePort();
    if (!IsolateNameServer.registerPortWithName(
      port.sendPort,
      _foregroundPortName,
    )) {
      port.close();
      return;
    }
    _foregroundPort = port;
    IsolateNameServer.removePortNameMapping(_startupPortName);
    _startupPort?.close();
    _startupPort = null;
    port.listen((message) async {
      if (message is! List || message.length != 2 || message[1] is! SendPort) {
        return;
      }
      final response = message[1] as SendPort;
      try {
        if (message[0] == 'cancel') {
          await cancelAndWait();
          response.send(true);
        } else if (message[0] == 'run') {
          response.send(await runIfDue());
        } else {
          response.send(false);
        }
      } catch (_) {
        response.send(false);
      }
    });
  }

  static void detachForeground() {
    if (_foregroundPort == null) return;
    IsolateNameServer.removePortNameMapping(_foregroundPortName);
    _foregroundPort?.close();
    _foregroundPort = null;
  }

  /// Called before startup takes the business lease, never after opening data.
  static Future<void> yieldToForeground({VoidCallback? onWaiting}) async {
    if (!isSupported) return;
    if (_startupPort == null) {
      final startup = ReceivePort();
      if (IsolateNameServer.registerPortWithName(
        startup.sendPort,
        _startupPortName,
      )) {
        _startupPort = startup;
      } else {
        startup.close();
      }
    }
    // Publish startup before looking for a worker. The worker publishes its
    // own port before checking this sentinel, so one side must see the other
    // even when both engines start during the same event-loop turn.
    final background = IsolateNameServer.lookupPortByName(_backgroundPortName);
    if (background == null) return;
    onWaiting?.call();
    final reply = ReceivePort();
    try {
      background.send(reply.sendPort);
      // Cancellation normally completes in a few seconds. If a native worker
      // cannot stop, startup must fail closed rather than open the same data.
      await reply.first.timeout(const Duration(seconds: 45));
    } finally {
      reply.close();
    }
  }

  static Future<bool> runBackgroundTask() {
    if (!isSupported) return Future<bool>.value(true);
    return _activeWork ??= _runBackgroundTask().whenComplete(() {
      _activeWork = null;
    });
  }

  static Future<void> stopBackgroundTask() async {
    _activeCancelToken?.cancel();
    await _cancelDelegatedTask();
    try {
      await _activeWork?.timeout(const Duration(seconds: 5));
    } catch (_) {
      // WorkManager tears down this engine next. Do not prematurely unlock
      // data a native packing isolate may still be reading.
    }
  }

  static Future<void> _cancelDelegatedTask() async {
    final foreground = _delegatedForeground;
    if (foreground == null) return;
    final reply = ReceivePort();
    try {
      foreground.send(['cancel', reply.sendPort]);
      await reply.first.timeout(const Duration(seconds: 5));
    } catch (_) {
      // The visible engine retains its own lease and BackupActivity until the
      // native operation exits; stopping this headless engine cannot unlock it.
    } finally {
      reply.close();
    }
  }

  /// Admission under the caller's business lease without changing business
  /// data. Recovery, migration, and installation belong to visible startup.
  @visibleForTesting
  static Future<bool> canOpenDatabase(Directory appData) async {
    if (await FileSystemEntity.type(
          p.join(appData.path, DatabaseFamilyPreserver.pendingName),
          followLinks: false,
        ) !=
        FileSystemEntityType.notFound) {
      return false;
    }
    final migrationPrefix =
        '${AppDatabase.databaseFileName}'
        '${ChatDatabaseRepository.premigrationBackupPrefix}';
    await for (final entity in appData.list(followLinks: false)) {
      if (p.basename(entity.path).startsWith(migrationPrefix)) return false;
    }
    if (await RestoreStartupGate.hasPendingWork(appDataDirectory: appData)) {
      return false;
    }
    if (await RestoreStartupGate.inspect(appDataDirectory: appData) != null) {
      return false;
    }
    final database = p.join(appData.path, AppDatabase.databaseFileName);
    if (await FileSystemEntity.type(database, followLinks: false) !=
        FileSystemEntityType.file) {
      return false;
    }
    final receipt = await DatabaseInstallationGate.read(
      appDataDirectory: appData,
    );
    if (receipt == null) return false;
    await EmptyDatabaseRecoveryGuard.check(
      appDataDirectory: appData,
      databaseId: receipt.databaseId,
    );
    return true;
  }

  static Future<bool> _runBackgroundTask() async {
    final store = WebDavBackupScheduleStore();
    final settings = await store.readSettings();
    final state = await store.readState();
    if (!settings.enabled ||
        !WebDavBackupSchedule.isDue(settings, state, DateTime.now().toUtc())) {
      return true;
    }
    if (!await WebDavBackupSchedule.networkAvailable(settings.wifiOnly)) {
      return false;
    }

    final foreground = IsolateNameServer.lookupPortByName(_foregroundPortName);
    if (foreground != null) {
      final response = ReceivePort();
      _delegatedForeground = foreground;
      try {
        foreground.send(['run', response.sendPort]);
        return await response.first.timeout(_workerBudget) == true;
      } on TimeoutException {
        await _cancelDelegatedTask();
        return false;
      } finally {
        _delegatedForeground = null;
        response.close();
      }
    }

    final requests = ReceivePort();
    if (!IsolateNameServer.registerPortWithName(
      requests.sendPort,
      _backgroundPortName,
    )) {
      requests.close();
      return false;
    }
    final cancelToken = BackupCancelToken();
    _activeCancelToken = cancelToken;
    final workerFinished = Completer<void>();
    requests.listen((message) async {
      if (message is! SendPort) return;
      cancelToken.cancel();
      await workerFinished.future;
      message.send(true);
    });
    var deadlineExpired = false;
    final deadline = Timer(_workerBudget, () {
      deadlineExpired = true;
      cancelToken.cancel();
    });
    RestoreBusinessLease? businessLease;
    ChatDatabaseLease? databaseLease;
    File? archive;
    var attempted = false;
    try {
      if (IsolateNameServer.lookupPortByName(_startupPortName) != null) {
        return false;
      }
      final appData = await AppDirectories.getAppDataDirectory();
      businessLease = await RestoreBusinessLease.acquire(
        appDataDirectory: appData,
        sameProcessOwnerGrace: Duration.zero,
        foreignLockGrace: Duration.zero,
      );
      cancelToken.throwIfCancelled();
      if (!await canOpenDatabase(appData)) return true;
      final databaseFile = File(
        p.join(appData.path, AppDatabase.databaseFileName),
      );
      databaseLease = await ChatDatabaseGateway.instance.acquire(databaseFile);
      if (!await databaseLease.businessRepository.hasMigrationReceipt()) {
        return true;
      }
      final preferences = BusinessPreferences(databaseLease.businessRepository);
      await preferences.load();
      final encoded = preferences.getString('webdav_config_v1');
      if (encoded == null) return true;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return true;
      final config = WebDavConfig.fromJson(decoded);
      final uri = Uri.tryParse(config.url.trim());
      if (uri == null ||
          !const ['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        return true;
      }
      // Settings can change while the task waits for the engine or lease.
      final currentSettings = await store.readSettings();
      final currentState = await store.readState();
      if (!WebDavBackupSchedule.isDue(
        currentSettings,
        currentState,
        DateTime.now().toUtc(),
      )) {
        return true;
      }
      if (!await WebDavBackupSchedule.networkAvailable(
        currentSettings.wifiOnly,
      )) {
        return false;
      }
      cancelToken.throwIfCancelled();
      attempted = true;
      await store.writeState(
        WebDavBackupScheduleState(
          lastAttempt: DateTime.now().toUtc(),
          lastSuccess: currentState.lastSuccess,
          lastError: currentState.lastError,
        ),
      );
      try {
        archive = await DataSync.prepareScheduledBackupArchive(
          databaseFile: databaseFile,
          businessRepository: databaseLease.businessRepository,
          config: config,
          cancelToken: cancelToken,
        );
      } catch (error) {
        // Never release the live-data lease before a cancelled native worker
        // has really exited, even when its normal cancellation timeout expired.
        await backupIsolateExitFuture(error);
        rethrow;
      }
      await databaseLease.release();
      databaseLease = null;
      await businessLease.close();
      businessLease = null;
      cancelToken.throwIfCancelled();
      await DataSync.uploadWebDavBackupFile(
        config,
        archive,
        cancelToken: cancelToken,
      );
      final latest = await store.readState();
      await store.writeState(
        WebDavBackupScheduleState(
          lastAttempt: latest.lastAttempt,
          lastSuccess: DateTime.now().toUtc(),
        ),
      );
      return true;
    } on RestoreBusinessLeaseUnavailable {
      return false;
    } on BackupCancelledException {
      // Opening the app or changing the schedule is a handoff, not a failure.
      if (attempted && deadlineExpired) {
        final latest = await store.readState();
        await store.writeState(
          WebDavBackupScheduleState(
            lastAttempt: latest.lastAttempt,
            lastSuccess: latest.lastSuccess,
            lastError: 'backup_timeout',
          ),
        );
      }
      return false;
    } catch (error) {
      if (attempted) {
        final latest = await store.readState();
        await store.writeState(
          WebDavBackupScheduleState(
            lastAttempt: latest.lastAttempt,
            lastSuccess: latest.lastSuccess,
            lastError: WebDavBackupSchedule.safeError(error),
          ),
        );
      }
      return false;
    } finally {
      deadline.cancel();
      try {
        try {
          await databaseLease?.release();
        } finally {
          await businessLease?.close();
        }
      } finally {
        try {
          await DataSync.cleanupTemporaryBackupFile(archive);
        } finally {
          IsolateNameServer.removePortNameMapping(_backgroundPortName);
          requests.close();
          _activeCancelToken = null;
          cancelToken.dispose();
          workerFinished.complete();
        }
      }
    }
  }
}
