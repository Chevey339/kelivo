import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../database/business_preferences.dart';
import '../database/business_repository.dart';
import '../services/backup/backup_cancel_token.dart';
import '../services/backup/backup_task_progress.dart';
import '../services/backup/data_sync.dart';
import '../services/backup/local_copy_catalog.dart';
import '../services/backup/local_snapshot_schedule.dart';
import '../services/backup/local_snapshot_service.dart';
import '../services/backup/local_snapshot_settings.dart';
import '../services/backup/local_snapshot_store.dart';
import '../services/chat/chat_service.dart';
import '../services/storage/device_storage_probe.dart';

/// An archive ready to be exported or restored, and whether it was made on
/// the spot and therefore has to be cleaned up afterwards.
typedef MaterializedLocalCopy = ({File file, bool temporary});

/// Screen-facing state for the local copies of the database.
class LocalSnapshotProvider extends ChangeNotifier {
  LocalSnapshotProvider({
    required this.appDataDirectory,
    required ChatService chatService,
    required BusinessRepository businessRepository,
    required BusinessPreferences businessPreferences,
    LocalSnapshotBusyCheck? isBusy,
    bool autoLoad = true,
  }) : _dataSync = DataSync(
         chatService: chatService,
         businessRepository: businessRepository,
         businessPreferences: businessPreferences,
       ),
       _preferences = LocalSnapshotPreferences(businessPreferences) {
    _store = LocalSnapshotStore(appDataDirectory: appDataDirectory);
    _catalog = LocalCopyCatalog(
      appDataDirectory: appDataDirectory,
      store: _store,
    );
    _service = LocalSnapshotService(
      appDataDirectory: appDataDirectory,
      preferences: _preferences,
      store: _store,
      buildArchive: _dataSync.prepareLocalSnapshotArchive,
      isBusy: isBusy,
    );
    _settings = _preferences.readSettings();
    _state = _preferences.readState();
    if (autoLoad) unawaited(refresh());
  }

  final Directory appDataDirectory;
  final DataSync _dataSync;
  final LocalSnapshotPreferences _preferences;
  late final LocalSnapshotStore _store;
  late final LocalCopyCatalog _catalog;
  late final LocalSnapshotService _service;

  LocalSnapshotSettings _settings = const LocalSnapshotSettings();
  LocalSnapshotState _state = const LocalSnapshotState();
  List<LocalCopy> _copies = const <LocalCopy>[];
  bool _loading = false;
  bool _working = false;

  LocalSnapshotSettings get settings => _settings;
  LocalSnapshotState get state => _state;
  List<LocalCopy> get copies => _copies;
  bool get loading => _loading;
  bool get working => _working || _service.running;
  LocalSnapshotService get service => _service;

  int get totalBytes => _copies.fold<int>(0, (sum, copy) => sum + copy.bytes);

  int get snapshotCount =>
      _copies.where((copy) => copy.kind == LocalCopyKind.snapshot).length;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      _settings = _preferences.readSettings();
      _state = _preferences.readState();
      _copies = await _catalog.list();
    } catch (_) {
      _copies = const <LocalCopy>[];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Re-reads the recorded outcome without relisting the directory.
  void refreshState() {
    _state = _preferences.readState();
    notifyListeners();
  }

  Future<void> updateSettings(LocalSnapshotSettings next) async {
    _settings = next;
    notifyListeners();
    await _preferences.writeSettings(next);
    _settings = _preferences.readSettings();
    // A tighter policy should take effect now rather than at the next copy,
    // but only ever through the same rules the schedule uses.
    try {
      await _service.pruneNow();
    } catch (_) {}
    await refresh();
  }

  /// Takes a copy because the user asked for one.
  ///
  /// [prune] is off for the copy taken before a restore: trimming there could
  /// remove the very copy the restore is about to read, since an old copy the
  /// user chose deliberately is exactly the kind retention would drop.
  Future<LocalSnapshotEntry> takeNow({
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
    LocalSnapshotOrigin origin = LocalSnapshotOrigin.manual,
    bool pinned = false,
    bool prune = true,
  }) async {
    _working = true;
    notifyListeners();
    try {
      final entry = await _service.take(
        origin: origin,
        pinned: pinned,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      if (prune) await _service.pruneNow();
      return entry;
    } finally {
      _working = false;
      await refresh();
    }
  }

  /// Restores a prepared archive over the live data.
  ///
  /// Deliberately not routed through [BackupProvider], whose selection comes
  /// from the user's remote-backup settings: someone who turned chats off for
  /// WebDAV would otherwise be unable to restore a local copy at all. A local
  /// copy always carries the whole database and never carries assets, so the
  /// selection is fixed.
  Future<void> restoreArchive(
    File archive, {
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
    bool allowUnverifiedForwardCompatible = false,
  }) => whileHoldingCopies(
    () => _dataSync.restoreFromLocalFile(
      archive,
      LocalSnapshotService.archiveConfig,
      onProgress: onProgress,
      cancelToken: cancelToken,
      allowUnverifiedForwardCompatible: allowUnverifiedForwardCompatible,
    ),
  );

  int get skippedConversations =>
      _dataSync.lastMergeReport?.skippedConversations ?? 0;

  /// Runs the schedule. Used by the launch and resume hooks.
  Future<LocalSnapshotRunResult> runIfDue() async {
    // A restore or an export is reading one of these copies by path, and the
    // schedule's own pruning is free to delete exactly the kind of old copy a
    // user reaches for deliberately. The service cannot see this state -- its
    // busy check is injected and would have to reach back into this provider
    // -- so the guard belongs here, at the one place that starts a run.
    if (_working) {
      return const LocalSnapshotSkipped(LocalSnapshotSkipReason.busy);
    }
    final result = await _service.runIfDue();
    _state = _preferences.readState();
    if (result is LocalSnapshotCreated) {
      await refresh();
    } else {
      notifyListeners();
    }
    return result;
  }

  /// Produces a backup archive for [copy].
  ///
  /// A snapshot already is one. A displaced database family is converted into
  /// one here, so exporting and restoring it both reduce to the paths an
  /// ordinary backup already uses.
  Future<MaterializedLocalCopy> materialize(
    LocalCopy copy, {
    bool allowForwardCompatible = false,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    if (copy.isArchive) return (file: copy.file, temporary: false);
    _working = true;
    notifyListeners();
    try {
      final archive = await _dataSync.prepareBackupFileFromDatabase(
        copy.file,
        allowForwardCompatible: allowForwardCompatible,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      return (file: archive, temporary: true);
    } finally {
      _working = false;
      notifyListeners();
    }
  }

  /// Marks the provider busy for as long as [action] is reading a copy.
  ///
  /// Anything that hands a copy's path to another process -- a restore, the
  /// system file picker -- has to hold this, or the schedule may delete the
  /// file out from under it between two opens.
  Future<T> whileHoldingCopies<T>(Future<T> Function() action) async {
    _working = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _working = false;
      notifyListeners();
    }
  }

  Future<void> releaseMaterialized(MaterializedLocalCopy materialized) async {
    if (!materialized.temporary) return;
    await DataSync.cleanupTemporaryBackupFile(materialized.file);
  }

  Future<void> delete(LocalCopy copy) async {
    await _catalog.delete(copy);
    await refresh();
  }

  Future<void> setPinned(LocalCopy copy, bool pinned) async {
    if (copy.kind != LocalCopyKind.snapshot) return;
    await _store.setPinned(copy.id, pinned);
    await refresh();
  }

  /// A file name a person can recognise once it leaves the app.
  String exportFileNameFor(LocalCopy copy) {
    final at = (copy.createdAt ?? DateTime.now()).toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${at.year}${two(at.month)}${two(at.day)}'
        '-${two(at.hour)}${two(at.minute)}${two(at.second)}';
    final kind = copy.kind == LocalCopyKind.snapshot ? 'snapshot' : 'recovered';
    return 'kelivo-$kind-$stamp.zip';
  }

  /// The interval currently in force, resolving the automatic setting against
  /// the database's real size.
  Future<Duration> effectiveInterval() async {
    var bytes = 0;
    try {
      final stat = await _service.databaseFile.stat();
      if (stat.type == FileSystemEntityType.file) bytes = stat.size;
    } catch (_) {}
    return _settings.intervalFor(bytes);
  }

  /// Free space as the platform reports it, or null where it does not.
  Future<int?> freeBytes() => DeviceStorageProbe.freeBytes();
}
