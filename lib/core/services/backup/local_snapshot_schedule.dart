import 'dart:io';

import 'package:path/path.dart' as p;

/// Why a due local copy did not get taken.
///
/// Carried all the way to the settings screen: a copy that silently stops
/// happening is the failure mode this whole mechanism was added to prevent,
/// so every skip has to be nameable.
enum LocalSnapshotSkipReason {
  disabled,
  notDue,

  /// A previous attempt failed and the retry window has not elapsed.
  backoff,

  /// Another snapshot, backup or restore already holds the database.
  busy,

  /// A reply is still streaming; the copy waits rather than competing for I/O.
  generating,

  /// Taking one would leave the device too close to full to be safe.
  insufficientSpace,

  /// Nothing has been written since the last copy.
  unchanged,
}

/// A cheap, exact "did anything change" signal.
///
/// Two `stat` calls, no SQL. Counting rows would mean a full scan of a table
/// that can hold millions of them, on the launch path, for a question that a
/// file's size and mtime already answer. In WAL mode commits land in the -wal
/// sidecar, so it is the half that usually moves.
final class DatabaseChangeFingerprint {
  const DatabaseChangeFingerprint({
    required this.databaseBytes,
    required this.databaseModifiedMicros,
    required this.walBytes,
    required this.walModifiedMicros,
  });

  final int databaseBytes;
  final int databaseModifiedMicros;
  final int walBytes;
  final int walModifiedMicros;

  static Future<DatabaseChangeFingerprint> read(File databaseFile) async {
    final database = await _statOf(databaseFile);
    final wal = await _statOf(File('${databaseFile.path}-wal'));
    return DatabaseChangeFingerprint(
      databaseBytes: database.bytes,
      databaseModifiedMicros: database.modifiedMicros,
      walBytes: wal.bytes,
      walModifiedMicros: wal.modifiedMicros,
    );
  }

  /// Absent is a state, not a failure: a checkpointed database has no -wal
  /// beside it, and two launches that both find none really are unchanged.
  /// Only a stat that could not be taken is unknown, and unknown never
  /// compares equal.
  static const _absent = (bytes: 0, modifiedMicros: 0);
  static const _unknown = (bytes: -1, modifiedMicros: -1);

  static Future<({int bytes, int modifiedMicros})> _statOf(File file) async {
    try {
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) return _absent;
      if (type != FileSystemEntityType.file) return _unknown;
      final stat = await file.stat();
      return (
        bytes: stat.size,
        modifiedMicros: stat.modified.microsecondsSinceEpoch,
      );
    } catch (_) {
      return _unknown;
    }
  }

  String encode() =>
      '$databaseBytes:$databaseModifiedMicros:$walBytes:$walModifiedMicros';

  static DatabaseChangeFingerprint? decode(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 4) return null;
    final numbers = <int>[];
    for (final part in parts) {
      final parsed = int.tryParse(part);
      if (parsed == null) return null;
      numbers.add(parsed);
    }
    return DatabaseChangeFingerprint(
      databaseBytes: numbers[0],
      databaseModifiedMicros: numbers[1],
      walBytes: numbers[2],
      walModifiedMicros: numbers[3],
    );
  }

  /// Deliberately not `==` on an unreadable stat: a negative component means
  /// "could not tell", and two of those in a row must not read as "same".
  bool matches(DatabaseChangeFingerprint? other) {
    if (other == null) return false;
    if (databaseBytes < 0 ||
        walBytes < 0 ||
        databaseModifiedMicros < 0 ||
        walModifiedMicros < 0) {
      return false;
    }
    return databaseBytes == other.databaseBytes &&
        databaseModifiedMicros == other.databaseModifiedMicros &&
        walBytes == other.walBytes &&
        walModifiedMicros == other.walModifiedMicros;
  }
}

/// When the next automatic local copy is allowed to run.
///
/// Time-based only, and evaluated on launch and on resume rather than from a
/// timer or a background task: a scheduled wake-up would have to run the
/// admission path unattended, which is exactly the situation the startup gate
/// is written to distrust.
final class LocalSnapshotSchedule {
  const LocalSnapshotSchedule._();

  /// Interval when the user has not chosen one.
  ///
  /// The database is pure text -- assets live on disk as files -- so a heavy
  /// user's can reach a gigabyte or more, where one copy costs minutes of CPU
  /// and a comparable amount of flash writes. Large databases get a longer
  /// default rather than a worse experience.
  static Duration defaultIntervalFor(int databaseBytes) {
    if (databaseBytes >= 1024 * 1024 * 1024) return const Duration(days: 7);
    if (databaseBytes >= 200 * 1024 * 1024) return const Duration(days: 3);
    return const Duration(days: 1);
  }

  /// How long after this feature first sees an install before it takes its
  /// very first copy. Keeps the one-off cost off the launch that follows an
  /// app update, when migrations and the first screen are already competing
  /// for the same disk.
  static const initialGrace = Duration(minutes: 10);

  /// Minimum gap after a failure. Without it a database that fails the same
  /// way every time would re-run a full vacuum on every resume.
  static const failureBackoff = Duration(hours: 1);

  /// Free space that must remain after a copy is written.
  ///
  /// A nearly full device is how a healthy database becomes a corrupt one, so
  /// the mechanism has to refuse to be the thing that fills it.
  static const freeSpaceFloor = 2 * 1024 * 1024 * 1024;

  /// Rough peak cost of taking one: the vacuumed intermediate is the size of
  /// the database, and the compressed result is kept alongside it briefly.
  static int estimatedSpaceRequired(int databaseBytes) =>
      (databaseBytes * 1.2).round() + (databaseBytes ~/ 3);

  static LocalSnapshotSkipReason? dueSkipReason({
    required DateTime now,
    required bool enabled,
    required Duration interval,
    DateTime? lastSuccessAt,
    DateTime? lastFailureAt,
    Duration backoff = failureBackoff,
  }) {
    if (!enabled) return LocalSnapshotSkipReason.disabled;
    if (lastFailureAt != null &&
        !lastFailureAt.isAfter(now) &&
        now.difference(lastFailureAt) < backoff) {
      return LocalSnapshotSkipReason.backoff;
    }
    if (lastSuccessAt == null) return null;
    // A clock moved backwards must not park the schedule in the future.
    if (lastSuccessAt.isAfter(now)) return null;
    if (now.difference(lastSuccessAt) < interval) {
      return LocalSnapshotSkipReason.notDue;
    }
    return null;
  }
}

/// Where the copies live, and what their names mean.
final class LocalSnapshotPaths {
  const LocalSnapshotPaths._();

  /// Kept inside the app data directory rather than somewhere hidden: the
  /// startup gate reads that directory for proof the install has been used,
  /// so a copy sitting there is one more reason an unattended rebuild can
  /// never fire. On iOS it also means a user can retrieve one by hand.
  static const directoryName = 'snapshots';

  static const filePrefix = 'kelivo-snapshot-';
  static const fileSuffix = '.zip';
  static const metadataSuffix = '.json';

  /// Written first, renamed into place only once durable. Anything still
  /// carrying this prefix is the debris of an interrupted attempt.
  static const temporaryPrefix = '.incomplete-';

  static Directory directoryIn(Directory appDataDirectory) =>
      Directory(p.join(appDataDirectory.path, directoryName));

  /// Sorts chronologically as text, which keeps listing free of parsing.
  static String fileNameFor(DateTime createdAtUtc) {
    final stamp = createdAtUtc
        .toUtc()
        .microsecondsSinceEpoch
        .toString()
        .padLeft(16, '0');
    return '$filePrefix$stamp$fileSuffix';
  }

  static DateTime? createdAtFromFileName(String fileName) {
    if (!fileName.startsWith(filePrefix) || !fileName.endsWith(fileSuffix)) {
      return null;
    }
    final stamp = fileName.substring(
      filePrefix.length,
      fileName.length - fileSuffix.length,
    );
    final micros = int.tryParse(stamp);
    if (micros == null || micros < 0) return null;
    return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
  }
}
