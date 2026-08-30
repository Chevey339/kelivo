import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../storage/device_storage_probe.dart';
import 'local_snapshot_retention.dart';
import 'local_snapshot_schedule.dart';
import 'restore_durability.dart';

/// Why a local copy exists. Shown to the user, and consulted by pruning.
enum LocalSnapshotOrigin {
  /// Taken by the schedule.
  automatic,

  /// Taken because the user asked for one.
  manual,

  /// Taken immediately before a restore, so the restore itself is undoable.
  beforeRestore,
}

/// One local copy on disk: a standard backup archive plus what the app knows
/// about it that the archive itself does not record.
final class LocalSnapshotEntry {
  const LocalSnapshotEntry({
    required this.file,
    required this.createdAt,
    required this.bytes,
    required this.origin,
    required this.pinned,
    required this.conversationCount,
    required this.messageCount,
    this.appVersion,
  });

  final File file;
  final DateTime createdAt;
  final int bytes;
  final LocalSnapshotOrigin origin;
  final bool pinned;
  final int conversationCount;
  final int messageCount;
  final String? appVersion;

  String get id => p.basename(file.path);

  /// A copy taken before a restore is the only way back from that restore, so
  /// it is created already pinned. The flag is not re-derived from [origin]
  /// here: doing that would make the pin permanent and the unpin control inert,
  /// and every restore would leave behind one more copy that retention is
  /// forbidden to reclaim.
  SnapshotRetentionEntry get retention => SnapshotRetentionEntry(
    id: id,
    createdAt: createdAt,
    bytes: bytes,
    messageCount: messageCount,
    pinned: pinned,
  );
}

/// Owns `<appData>/snapshots/`.
///
/// Publishing is write-then-rename, and pruning only ever runs after the new
/// copy is durable and readable: the whole point of the directory is to hold
/// the copy that survives when the live database does not, so a half-written
/// one must never be able to displace a whole one.
final class LocalSnapshotStore {
  LocalSnapshotStore({
    required this.appDataDirectory,
    RestoreDurability? durability,
  }) : durability = durability ?? RestorePlatformDurability();

  final Directory appDataDirectory;
  final RestoreDurability durability;

  static const _metadataVersion = 1;

  Directory get directory => LocalSnapshotPaths.directoryIn(appDataDirectory);

  Future<Directory> ensureDirectory() async {
    final target = directory;
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      await target.create(recursive: true);
      await durability.restrictDirectory(target);
      await durability.syncDirectory(appDataDirectory);
    }
    // Re-applied rather than set once at creation: a directory that predates
    // this call -- or that a restore recreated -- must not silently start
    // being uploaded again.
    await DeviceStorageProbe.excludeFromCloudBackup(target.path);
    return target;
  }

  Future<List<LocalSnapshotEntry>> list() async {
    final target = directory;
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return const <LocalSnapshotEntry>[];
    }
    final entries = <LocalSnapshotEntry>[];
    await for (final entity in target.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      final createdAt = LocalSnapshotPaths.createdAtFromFileName(name);
      if (createdAt == null) continue;
      final entry = await _readEntry(entity, createdAt);
      if (entry != null) entries.add(entry);
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<int> totalBytes() async {
    var total = 0;
    for (final entry in await list()) {
      total += entry.bytes;
    }
    return total;
  }

  /// Moves a freshly packed archive into the store and publishes it.
  ///
  /// [prepared] is consumed: on success it no longer exists at its old path,
  /// and on failure it is left alone for the caller to clean up.
  Future<LocalSnapshotEntry> publish({
    required File prepared,
    required DateTime createdAtUtc,
    required LocalSnapshotOrigin origin,
    required int conversationCount,
    required int messageCount,
    String? appVersion,
    bool pinned = false,
  }) async {
    final target = await ensureDirectory();
    final fileName = LocalSnapshotPaths.fileNameFor(createdAtUtc);
    final staged = File(
      p.join(target.path, '${LocalSnapshotPaths.temporaryPrefix}$fileName'),
    );
    final published = File(p.join(target.path, fileName));
    if (await FileSystemEntity.type(published.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('local_snapshot_exists');
    }

    await _deleteQuietly(staged);
    await _moveInto(prepared, staged);
    try {
      await durability.restrictFile(staged);
      await durability.syncFile(staged, fullBarrier: true);
      final bytes = await staged.length();
      if (bytes <= 0) throw StateError('local_snapshot_empty');

      // The sidecar goes down before the archive takes its final name, so a
      // published archive always has its metadata beside it.
      await _writeMetadata(
        fileName: fileName,
        createdAtUtc: createdAtUtc,
        origin: origin,
        pinned: pinned,
        bytes: bytes,
        conversationCount: conversationCount,
        messageCount: messageCount,
        appVersion: appVersion,
      );
      await durability.renameAndSync(
        source: staged,
        targetPath: published.path,
      );
      return LocalSnapshotEntry(
        file: published,
        createdAt: createdAtUtc,
        bytes: bytes,
        origin: origin,
        pinned: pinned,
        conversationCount: conversationCount,
        messageCount: messageCount,
        appVersion: appVersion,
      );
    } catch (_) {
      await _deleteQuietly(staged);
      await _deleteQuietly(_metadataFileFor(fileName));
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    if (LocalSnapshotPaths.createdAtFromFileName(id) == null) {
      throw ArgumentError.value(id, 'id');
    }
    final archive = File(p.join(directory.path, id));
    // Metadata first: a sidecar left beside a missing archive is invisible to
    // [list], so failing the other way round would strand it forever.
    await _deleteQuietly(_metadataFileFor(id));
    await _deleteQuietly(archive);
    if (await FileSystemEntity.type(archive.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      // The caller is either a user pressing Delete or pruning that reports
      // what it removed. Neither may claim a file went when it did not.
      throw FileSystemException('local_snapshot_not_deleted', archive.path);
    }
  }

  Future<void> setPinned(String id, bool pinned) async {
    final entries = await list();
    final entry = entries.where((candidate) => candidate.id == id).firstOrNull;
    if (entry == null) return;
    await _writeMetadata(
      fileName: entry.id,
      createdAtUtc: entry.createdAt,
      origin: entry.origin,
      pinned: pinned,
      bytes: entry.bytes,
      conversationCount: entry.conversationCount,
      messageCount: entry.messageCount,
      appVersion: entry.appVersion,
    );
  }

  /// Applies [policy] and removes what it selects. Returns what went.
  Future<List<LocalSnapshotEntry>> prune(
    LocalSnapshotRetentionPolicy policy, {
    DateTime? now,
  }) async {
    final entries = await list();
    if (entries.length <= 1) return const <LocalSnapshotEntry>[];
    final byId = {for (final entry in entries) entry.id: entry};
    final selected = policy.selectForDeletion(
      entries.map((entry) => entry.retention),
      now: now ?? DateTime.now().toUtc(),
    );
    final removed = <LocalSnapshotEntry>[];
    for (final candidate in selected) {
      final entry = byId[candidate.id];
      if (entry == null) continue;
      try {
        await delete(entry.id);
        removed.add(entry);
      } catch (_) {
        // One stubborn file must not stop the rest from being trimmed.
      }
    }
    return removed;
  }

  /// Clears the debris of an attempt that was interrupted before publishing.
  ///
  /// Two shapes of debris: a staged archive that never got its final name, and
  /// a sidecar whose archive never arrived -- the metadata is written before
  /// the rename, so a crash in that window leaves one behind that [list] can
  /// never see and therefore never clean up.
  Future<void> sweepIncomplete() async {
    final target = directory;
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return;
    }
    await for (final entity in target.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith(LocalSnapshotPaths.temporaryPrefix)) {
        await _deleteQuietly(entity);
        continue;
      }
      if (!name.endsWith(LocalSnapshotPaths.metadataSuffix)) continue;
      final archiveName = name.substring(
        0,
        name.length - LocalSnapshotPaths.metadataSuffix.length,
      );
      if (LocalSnapshotPaths.createdAtFromFileName(archiveName) == null) {
        continue;
      }
      final archive = File(p.join(target.path, archiveName));
      if (await FileSystemEntity.type(archive.path, followLinks: false) ==
          FileSystemEntityType.notFound) {
        await _deleteQuietly(entity);
      }
    }
  }

  File _metadataFileFor(String fileName) => File(
    p.join(directory.path, '$fileName${LocalSnapshotPaths.metadataSuffix}'),
  );

  Future<void> _writeMetadata({
    required String fileName,
    required DateTime createdAtUtc,
    required LocalSnapshotOrigin origin,
    required bool pinned,
    required int bytes,
    required int conversationCount,
    required int messageCount,
    String? appVersion,
  }) async {
    final file = _metadataFileFor(fileName);
    await file.writeAsString(
      jsonEncode({
        'version': _metadataVersion,
        'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
        'origin': origin.name,
        'pinned': pinned,
        'bytes': bytes,
        'conversationCount': conversationCount,
        'messageCount': messageCount,
        if (appVersion != null) 'appVersion': appVersion,
      }),
      flush: true,
    );
    await durability.restrictFile(file);
    await durability.syncFile(file);
  }

  /// Reads one archive's metadata.
  ///
  /// A missing or unreadable sidecar does not hide the archive: it is still
  /// the user's data and still restorable. It degrades to "unknown content",
  /// which pruning then treats as worth keeping.
  Future<LocalSnapshotEntry?> _readEntry(File file, DateTime createdAt) async {
    final int bytes;
    try {
      bytes = await file.length();
    } catch (_) {
      return null;
    }
    if (bytes <= 0) return null;

    Map<String, dynamic>? metadata;
    try {
      final sidecar = _metadataFileFor(p.basename(file.path));
      if (await sidecar.exists()) {
        final decoded = jsonDecode(await sidecar.readAsString());
        if (decoded is Map<String, dynamic>) metadata = decoded;
      }
    } catch (_) {
      metadata = null;
    }

    final originName = metadata?['origin'];
    return LocalSnapshotEntry(
      file: file,
      createdAt: createdAt,
      bytes: bytes,
      origin:
          LocalSnapshotOrigin.values
              .where((value) => value.name == originName)
              .firstOrNull ??
          LocalSnapshotOrigin.automatic,
      pinned: metadata?['pinned'] == true,
      conversationCount: _asCount(metadata?['conversationCount']),
      messageCount: _asCount(metadata?['messageCount']),
      appVersion: metadata?['appVersion'] is String
          ? metadata!['appVersion'] as String
          : null,
    );
  }

  /// Unknown counts read as 1, not 0: zero is the value that lets pruning
  /// treat a copy as empty and therefore expendable, and "we lost the sidecar"
  /// is not evidence the archive is empty.
  static int _asCount(Object? value) {
    if (value is int && value >= 0) return value;
    return 1;
  }

  Future<void> _moveInto(File source, File target) async {
    try {
      await source.rename(target.path);
      return;
    } on FileSystemException {
      // Temp and app data can sit on different volumes on desktop, where
      // rename cannot cross the boundary.
    }
    await source.copy(target.path);
    await _deleteQuietly(source);
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
