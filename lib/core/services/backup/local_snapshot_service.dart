import 'dart:io';

import 'package:path/path.dart' as p;

import '../../database/app_database.dart';
import '../../models/backup.dart';
import '../storage/device_storage_probe.dart';
import 'backup_cancel_token.dart';
import 'backup_task_progress.dart';
import 'data_sync.dart';
import 'local_snapshot_schedule.dart';
import 'local_snapshot_settings.dart';
import 'local_snapshot_store.dart';

/// The outcome of one scheduled attempt.
sealed class LocalSnapshotRunResult {
  const LocalSnapshotRunResult();
}

final class LocalSnapshotCreated extends LocalSnapshotRunResult {
  const LocalSnapshotCreated({required this.entry, required this.pruned});

  final LocalSnapshotEntry entry;
  final List<LocalSnapshotEntry> pruned;
}

final class LocalSnapshotSkipped extends LocalSnapshotRunResult {
  const LocalSnapshotSkipped(this.reason);

  final LocalSnapshotSkipReason reason;
}

final class LocalSnapshotFailed extends LocalSnapshotRunResult {
  const LocalSnapshotFailed(this.error);

  final Object error;
}

/// Reports a reason the copy should wait, or null to go ahead.
///
/// Injected rather than queried directly so the service stays free of the
/// chat and backup layers it would otherwise have to import.
typedef LocalSnapshotBusyCheck = LocalSnapshotSkipReason? Function();

/// Packs the live database into an archive ready to publish.
///
/// Narrower than a whole [DataSync] on purpose: the scheduling rules below are
/// the part worth testing exhaustively, and they should not need a chat
/// service and a real database to exercise.
typedef LocalSnapshotArchiveBuilder =
    Future<PreparedBackupArchive> Function({
      BackupProgressSink? onProgress,
      BackupCancelToken? cancelToken,
    });

/// Decides when to take a local copy of the database, takes it, and trims the
/// set afterwards.
///
/// Everything expensive happens inside the backup isolate the manual backup
/// already uses, and nothing here runs before the first frame: the launch path
/// must not get slower because this exists.
final class LocalSnapshotService {
  LocalSnapshotService({
    required this.appDataDirectory,
    required this.preferences,
    required LocalSnapshotArchiveBuilder buildArchive,
    LocalSnapshotStore? store,
    this.isBusy,
    Future<int?> Function()? freeBytes,
    // ignore: prefer_initializing_formals
  }) : _buildArchive = buildArchive,
       store = store ?? LocalSnapshotStore(appDataDirectory: appDataDirectory),
       _freeBytes = freeBytes ?? DeviceStorageProbe.freeBytes;

  final Directory appDataDirectory;
  final LocalSnapshotPreferences preferences;
  final LocalSnapshotStore store;
  final LocalSnapshotBusyCheck? isBusy;
  final LocalSnapshotArchiveBuilder _buildArchive;
  final Future<int?> Function() _freeBytes;

  bool _running = false;

  bool get running => _running;

  File get databaseFile =>
      File(p.join(appDataDirectory.path, AppDatabase.databaseFileName));

  /// Takes a copy if one is due. Never throws: a failure here is recorded and
  /// surfaced in settings, and must not disturb whatever the user is doing.
  Future<LocalSnapshotRunResult> runIfDue({DateTime? now}) async {
    try {
      return await _runIfDue(now: now ?? DateTime.now().toUtc());
    } catch (error) {
      return LocalSnapshotFailed(error);
    }
  }

  Future<LocalSnapshotRunResult> _runIfDue({required DateTime now}) async {
    if (_running) {
      return const LocalSnapshotSkipped(LocalSnapshotSkipReason.busy);
    }

    final settings = preferences.readSettings();
    if (!settings.enabled) {
      return const LocalSnapshotSkipped(LocalSnapshotSkipReason.disabled);
    }
    final state = preferences.readState();
    final databaseBytes = await _databaseBytes();

    // Ordered by cost: nothing below is allowed to touch the database until
    // the cheap answers have all said "yes".
    final dueSkip = LocalSnapshotSchedule.dueSkipReason(
      now: now,
      enabled: settings.enabled,
      interval: settings.intervalFor(databaseBytes),
      lastSuccessAt: state.lastSuccessAt,
      lastFailureAt: state.lastFailureAt,
      backoff: state.failureBackoff,
    );
    if (dueSkip != null) return LocalSnapshotSkipped(dueSkip);

    // Everyone upgrading to a build with this feature has no recorded copy, so
    // without a grace period every one of them would pay a full vacuum and
    // pack eight seconds into the first launch -- minutes of it on a large
    // database, at the moment the app is busiest. The copy is not skipped,
    // only moved off the launch the user just triggered.
    final firstObserved = state.firstObservedAt;
    if (firstObserved == null) {
      await preferences.recordFirstObserved(now);
      return const LocalSnapshotSkipped(LocalSnapshotSkipReason.notDue);
    }
    if (state.lastSuccessAt == null &&
        !firstObserved.isAfter(now) &&
        now.difference(firstObserved) < LocalSnapshotSchedule.initialGrace) {
      return const LocalSnapshotSkipped(LocalSnapshotSkipReason.notDue);
    }

    final busy = isBusy?.call();
    if (busy != null) {
      await preferences.recordSkip(busy);
      return LocalSnapshotSkipped(busy);
    }

    final fingerprint = await DatabaseChangeFingerprint.read(databaseFile);
    if (fingerprint.matches(state.fingerprint)) {
      // Writing another identical copy would not add a copy -- it would
      // replace the oldest one with a duplicate of the newest, collapsing the
      // time depth the slots exist to provide.
      await preferences.recordUnchanged(fingerprint);
      return const LocalSnapshotSkipped(LocalSnapshotSkipReason.unchanged);
    }

    final free = await _freeBytes();
    if (free != null &&
        free - LocalSnapshotSchedule.estimatedSpaceRequired(databaseBytes) <
            LocalSnapshotSchedule.freeSpaceFloor) {
      await preferences.recordSkip(LocalSnapshotSkipReason.insufficientSpace);
      return const LocalSnapshotSkipped(
        LocalSnapshotSkipReason.insufficientSpace,
      );
    }

    try {
      final entry = await take(origin: LocalSnapshotOrigin.automatic, now: now);
      final pruned = await store.prune(settings.retention, now: now);
      // Deliberately the fingerprint from before the copy, not after: the copy
      // holds the state the database was in when it started, so anything
      // written while it ran must still read as a change next time. Recording
      // the later state would let those writes fall through the "unchanged"
      // gate and never be copied at all.
      await preferences.recordSuccess(at: now, fingerprint: fingerprint);
      return LocalSnapshotCreated(entry: entry, pruned: pruned);
    } on StateError catch (error) {
      if (error.message == 'local_snapshot_running') {
        // Raced with a copy the user asked for. Not a failure, and it must not
        // count towards the backoff that exists for real ones.
        return const LocalSnapshotSkipped(LocalSnapshotSkipReason.busy);
      }
      await preferences.recordFailure(
        at: now,
        message: error.toString(),
        previousStreak: state.failureStreak,
      );
      return LocalSnapshotFailed(error);
    } catch (error) {
      await preferences.recordFailure(
        at: now,
        message: error.toString(),
        previousStreak: state.failureStreak,
      );
      return LocalSnapshotFailed(error);
    }
  }

  /// Packs the live database and publishes it into the store.
  ///
  /// Throws on failure so callers that asked for a copy explicitly can say so.
  Future<LocalSnapshotEntry> take({
    required LocalSnapshotOrigin origin,
    bool pinned = false,
    DateTime? now,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    if (_running) throw StateError('local_snapshot_running');
    _running = true;
    try {
      await store.sweepIncomplete();
      final prepared = await _buildArchive(
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      try {
        return await store.publish(
          prepared: prepared.file,
          createdAtUtc: (now ?? DateTime.now()).toUtc(),
          origin: origin,
          pinned: pinned,
          conversationCount: prepared.info?.conversationCount ?? 0,
          messageCount: prepared.info?.messageCount ?? 0,
          appVersion: prepared.appVersion,
        );
      } finally {
        await DataSync.cleanupTemporaryBackupFile(prepared.file);
      }
    } finally {
      _running = false;
    }
  }

  /// Trims the set to the current policy without taking a new copy.
  Future<List<LocalSnapshotEntry>> pruneNow({DateTime? now}) =>
      store.prune(preferences.readSettings().retention, now: now);

  Future<int> _databaseBytes() async {
    try {
      final stat = await databaseFile.stat();
      if (stat.type != FileSystemEntityType.file) return 0;
      return stat.size;
    } catch (_) {
      return 0;
    }
  }

  /// The archive shape local copies use: everything the database holds, and
  /// none of the assets that sit beside it.
  static const archiveConfig = WebDavConfig(
    includeChats: true,
    includeFiles: false,
  );
}
