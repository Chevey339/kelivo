import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;

import 'recovery_file_discovery.dart';
import 'local_snapshot_schedule.dart';

import '../../database/database_installation_gate.dart';
import 'local_snapshot_store.dart';

/// Where a local copy came from.
enum LocalCopyKind {
  /// Written by the schedule, or by the user asking for one.
  snapshot,

  /// A database family crash recovery moved aside instead of deleting.
  displaced,
}

/// One restorable copy of the database that lives on this device.
///
/// The two kinds differ in shape -- a snapshot is already a backup archive, a
/// displaced copy is a bare database family -- but the screen that lists them
/// offers the same three actions for both, so they are presented as one type.
final class LocalCopy {
  const LocalCopy({
    required this.kind,
    required this.id,
    required this.file,
    required this.createdAt,
    required this.bytes,
    this.conversationCount,
    this.messageCount,
    this.origin,
    this.pinned = false,
    this.appVersion,
    this.discovered = false,
  });

  final LocalCopyKind kind;

  /// Identifies the copy to the store that owns it: a file name for a
  /// snapshot, a stamp for a displaced family.
  final String id;

  final File file;

  /// Null only for a displaced family whose stamp predates the naming.
  final DateTime? createdAt;
  final int bytes;

  /// Unknown for displaced copies: reading them means opening a database of
  /// unknown vintage, which is the conversion's job, not the listing's.
  final int? conversationCount;
  final int? messageCount;

  final LocalSnapshotOrigin? origin;
  final bool pinned;
  final String? appVersion;

  /// Found outside the managed store. It is never pruned, pinned or deleted.
  final bool discovered;

  /// Whether the copy is already a backup archive, or has to be converted
  /// into one before it can be exported or restored.
  bool get isArchive => kind == LocalCopyKind.snapshot;
}

/// Lists and removes every local copy, of either kind.
final class LocalCopyCatalog {
  LocalCopyCatalog({
    required this.appDataDirectory,
    LocalSnapshotStore? store,
    this.additionalRoots = const [],
    this.includeActiveDatabase = false,
  }) : store = store ?? LocalSnapshotStore(appDataDirectory: appDataDirectory);

  final Directory appDataDirectory;
  final List<Directory> additionalRoots;
  final bool includeActiveDatabase;
  final LocalSnapshotStore store;
  bool hadReadErrors = false;

  Future<List<LocalCopy>> list() async {
    hadReadErrors = false;
    final copies = <LocalCopy>[];
    try {
      for (final entry in await store.list()) {
        copies.add(
          LocalCopy(
            kind: LocalCopyKind.snapshot,
            id: entry.id,
            file: entry.file,
            createdAt: entry.createdAt,
            bytes: entry.bytes,
            conversationCount: entry.conversationCount,
            messageCount: entry.messageCount,
            origin: entry.origin,
            pinned: entry.retention.pinned,
            appVersion: entry.appVersion,
          ),
        );
      }
    } catch (_) {
      hadReadErrors = true;
    }
    try {
      for (final copy in await DatabaseInstallationGate.listDisplacedDatabases(
        appDataDirectory: appDataDirectory,
      )) {
        copies.add(
          LocalCopy(
            kind: LocalCopyKind.displaced,
            id: copy.stamp,
            file: copy.file,
            createdAt: copy.displacedAt,
            bytes: copy.bytes,
          ),
        );
      }
    } catch (_) {
      hadReadErrors = true;
    }
    final paths = copies
        .map((copy) => p.normalize(copy.file.absolute.path))
        .toSet();
    for (final file in await RecoveryFileDiscovery.archives(
      appDataDirectory,
      onError: (_) => hadReadErrors = true,
      additionalRoots: additionalRoots,
    )) {
      if (!paths.add(p.normalize(file.absolute.path))) continue;
      Map<String, dynamic>? metadata;
      try {
        final sidecar = File('${file.path}.json');
        if (await sidecar.length() <= 8192) {
          final value = jsonDecode(await sidecar.readAsString());
          if (value is Map<String, dynamic>) metadata = value;
        }
      } catch (_) {
        // The archive remains discoverable without its advisory sidecar.
      }
      final FileStat stat;
      try {
        stat = await file.stat();
      } catch (_) {
        hadReadErrors = true;
        continue;
      }
      if (stat.type != FileSystemEntityType.file) {
        hadReadErrors = true;
        continue;
      }
      int? count(String key) {
        final value = metadata?[key];
        return value is int && value >= 0 ? value : null;
      }

      copies.add(
        LocalCopy(
          kind: LocalCopyKind.snapshot,
          id: file.absolute.path,
          file: file,
          createdAt:
              LocalSnapshotPaths.createdAtFromFileName(p.basename(file.path)) ??
              stat.modified,
          bytes: stat.size,
          conversationCount: count('conversationCount'),
          messageCount: count('messageCount'),
          discovered: true,
        ),
      );
    }
    for (final file in await RecoveryFileDiscovery.databases(
      appDataDirectory,
      includeActiveDatabase: includeActiveDatabase,
      onError: (_) => hadReadErrors = true,
      additionalRoots: additionalRoots,
    )) {
      if (!paths.add(p.normalize(file.absolute.path))) continue;
      final FileStat stat;
      try {
        stat = await file.stat();
      } catch (_) {
        hadReadErrors = true;
        continue;
      }
      if (stat.type != FileSystemEntityType.file) {
        hadReadErrors = true;
        continue;
      }
      copies.add(
        LocalCopy(
          kind: LocalCopyKind.displaced,
          id: file.absolute.path,
          file: file,
          createdAt: stat.modified,
          bytes: stat.size,
          discovered: true,
        ),
      );
    }
    // Undated copies sort last rather than first: an unreadable stamp is not
    // evidence the copy is old.
    copies.sort((a, b) {
      final left = a.createdAt;
      final right = b.createdAt;
      if (left == null && right == null) return a.id.compareTo(b.id);
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return copies;
  }

  Future<int> totalBytes() async {
    var total = 0;
    for (final copy in await list()) {
      total += copy.bytes;
    }
    return total;
  }

  Future<void> delete(LocalCopy copy) {
    if (copy.discovered) throw StateError('recovered_copy_preserved');
    return switch (copy.kind) {
      LocalCopyKind.snapshot => store.delete(copy.id),
      LocalCopyKind.displaced =>
        DatabaseInstallationGate.deleteDisplacedDatabase(
          appDataDirectory: appDataDirectory,
          stamp: copy.id,
        ),
    };
  }
}
