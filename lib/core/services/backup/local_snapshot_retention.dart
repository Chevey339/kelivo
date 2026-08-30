import 'dart:math' as math;

/// One local copy of the database, as the retention rules see it.
///
/// Deliberately free of `File`: the rules below decide what may be deleted
/// from metadata alone, so they stay testable without a filesystem and cannot
/// accidentally depend on anything the caller has not already established.
final class SnapshotRetentionEntry {
  const SnapshotRetentionEntry({
    required this.id,
    required this.createdAt,
    required this.bytes,
    required this.messageCount,
    this.pinned = false,
  });

  final String id;
  final DateTime createdAt;
  final int bytes;

  /// Messages the copy holds. Drives the guards that stop an empty -- or
  /// suddenly much smaller -- copy from evicting a fuller one.
  final int messageCount;

  /// Never removed automatically: taken right before a restore, or kept by
  /// the user on purpose.
  final bool pinned;

  bool get hasContent => messageCount > 0;
}

/// How many local copies survive, and which ones.
///
/// Slots give the set time depth: keeping "the newest N" alone means a day of
/// heavy use rotates out every older copy, and damage that went unnoticed for
/// a week becomes unrecoverable. The weekly and monthly slots cost one file
/// each and buy back that depth.
final class LocalSnapshotRetentionPolicy {
  const LocalSnapshotRetentionPolicy({
    this.keepRecent = 3,
    this.keepWeekly = true,
    this.keepMonthly = true,
    this.maximumTotalBytes = 0,
  }) : assert(keepRecent >= 1);

  /// The shape the app ships with: yesterday, the day before, the day before
  /// that, one from last week, one from last month.
  static const gfsLite = LocalSnapshotRetentionPolicy();

  final int keepRecent;
  final bool keepWeekly;
  final bool keepMonthly;

  /// Ceiling on the whole set. Zero means the slots alone bound it.
  final int maximumTotalBytes;

  static const weeklyAge = Duration(days: 7);
  static const monthlyAge = Duration(days: 30);

  /// How long a copy taken before a large content drop stays protected. The
  /// window has to end: a user who really did delete their chats should not
  /// have a copy of them kept forever.
  static const dropGuardWindow = Duration(days: 90);

  /// A later copy holding less than this share of the high-water copy reads
  /// as a loss rather than as ordinary editing.
  static const dropGuardRatio = 0.5;

  /// The copies automatic pruning may remove, oldest first.
  ///
  /// Every rule here can only ever move an entry from "delete" to "keep".
  /// That asymmetry is the point: the cost of keeping one file too many is
  /// disk space, and the cost of deleting one file too few is the incident
  /// this whole mechanism exists to prevent.
  List<SnapshotRetentionEntry> selectForDeletion(
    Iterable<SnapshotRetentionEntry> entries, {
    required DateTime now,
  }) {
    final ordered = entries.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (ordered.length <= 1) return const <SnapshotRetentionEntry>[];

    final protected = _protectedIds(ordered, now: now);
    final retained = <String>{...protected, ..._slotIds(ordered, now: now)};

    final deletions = <SnapshotRetentionEntry>[
      for (final entry in ordered.reversed)
        if (!retained.contains(entry.id)) entry,
    ];

    if (maximumTotalBytes <= 0) return deletions;

    // Over budget: give up slots too, oldest first, but never anything
    // protected. Running over the ceiling is better than losing the last
    // copy that still has the user's data in it.
    final deleted = deletions.map((entry) => entry.id).toSet();
    var total = ordered
        .where((entry) => !deleted.contains(entry.id))
        .fold<int>(0, (sum, entry) => sum + entry.bytes);
    for (final entry in ordered.reversed) {
      if (total <= maximumTotalBytes) break;
      if (deleted.contains(entry.id) || protected.contains(entry.id)) continue;
      deletions.add(entry);
      deleted.add(entry.id);
      total -= entry.bytes;
    }
    return deletions;
  }

  /// Entries no policy setting may drop, however tight the budget.
  Set<String> _protectedIds(
    List<SnapshotRetentionEntry> ordered, {
    required DateTime now,
  }) {
    final protected = <String>{ordered.first.id};
    for (final entry in ordered) {
      if (entry.pinned) protected.add(entry.id);
    }
    // An empty copy must never be able to evict one that still holds data --
    // the shape of a silent wipe is a fresh, valid, empty database.
    for (final entry in ordered) {
      if (entry.hasContent) {
        protected.add(entry.id);
        break;
      }
    }
    final highWater = _highWaterGuard(ordered, now: now);
    if (highWater != null) protected.add(highWater.id);
    return protected;
  }

  /// The fullest copy, while something newer suggests the data shrank.
  ///
  /// Covers the case the "empty" guard above misses: a database that lost most
  /// of its rows rather than all of them, where every later copy is still
  /// non-empty and would otherwise rotate the evidence away.
  SnapshotRetentionEntry? _highWaterGuard(
    List<SnapshotRetentionEntry> ordered, {
    required DateTime now,
  }) {
    SnapshotRetentionEntry? highWater;
    for (final entry in ordered) {
      if (highWater == null || entry.messageCount > highWater.messageCount) {
        highWater = entry;
      }
    }
    if (highWater == null || !highWater.hasContent) return null;
    if (identical(highWater, ordered.first)) return null;
    if (now.difference(highWater.createdAt) > dropGuardWindow) return null;
    final floor = highWater.messageCount * dropGuardRatio;
    for (final entry in ordered) {
      if (!entry.createdAt.isAfter(highWater.createdAt)) break;
      if (entry.messageCount < floor) return highWater;
    }
    return null;
  }

  /// The recent, weekly and monthly slots.
  Set<String> _slotIds(
    List<SnapshotRetentionEntry> ordered, {
    required DateTime now,
  }) {
    final slots = <String>{
      for (final entry in ordered.take(math.max(1, keepRecent))) entry.id,
    };
    if (keepWeekly) {
      final weekly = _oldestSlot(ordered, now: now, minimumAge: weeklyAge);
      if (weekly != null) slots.add(weekly.id);
    }
    if (keepMonthly) {
      final monthly = _oldestSlot(ordered, now: now, minimumAge: monthlyAge);
      if (monthly != null) slots.add(monthly.id);
    }
    return slots;
  }

  /// The newest entry that has already aged past [minimumAge].
  ///
  /// Newest rather than oldest: the slot should hold the most recent copy
  /// that still satisfies the depth it stands for, so the set keeps sliding
  /// forward instead of pinning one file the day it first qualifies.
  SnapshotRetentionEntry? _oldestSlot(
    List<SnapshotRetentionEntry> ordered, {
    required DateTime now,
    required Duration minimumAge,
  }) {
    for (final entry in ordered) {
      if (now.difference(entry.createdAt) >= minimumAge) return entry;
    }
    return null;
  }
}
