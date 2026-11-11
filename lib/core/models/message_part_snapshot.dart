import 'dart:collection';

import 'message_part.dart';

/// Immutable parts with a bounded, payload-free change journal. Consumers can
/// invalidate explicit ordinals without hashing every completed tool. Keeping
/// an old snapshot never retains the intervening message snapshots.
class MessagePartSnapshot extends UnmodifiableListView<MessagePart> {
  MessagePartSnapshot._(
    List<MessagePart> parts,
    this._owner,
    this.revision,
    this.structureRevision,
    this.toolsRevision,
  ) : super(List<MessagePart>.of(parts, growable: false));

  final MessagePartSnapshotBuilder _owner;
  final int revision;
  final int structureRevision;
  final int toolsRevision;
  bool get arrivalOrdered => _owner.arrivalOrdered;

  /// Opaque identity shared by this source's snapshots. This token exposes no
  /// mutable builder API and must only be used to scope derived caches.
  Object get sourceIdentity => _owner._sourceIdentity;

  /// Null means an unrelated source or an expired journal: rebuild once.
  Set<int>? changesSince(MessagePartSnapshot previous) {
    if (!identical(_owner, previous._owner)) return null;
    if (revision == previous.revision) return const {};
    if (revision < previous.revision ||
        _owner._journal.isEmpty ||
        previous.revision < _owner._journal.keys.first - 1) {
      return null;
    }
    return {
      for (final entry in _owner._journal.entries)
        if (entry.key > previous.revision && entry.key <= revision)
          ...entry.value,
    };
  }
}

class MessagePartSnapshotBuilder {
  MessagePartSnapshotBuilder({this.arrivalOrdered = false});
  final bool arrivalOrdered;
  final _sourceIdentity = Object();
  static const _journalLimit = 64;
  final _journal = <int, Set<int>>{};
  // A weak reference avoids an old snapshot keeping the newest payload alive.
  WeakReference<MessagePartSnapshot>? _previous;
  int _revision = 0;
  int _structureRevision = 0;
  int _toolsRevision = 0;

  MessagePartSnapshot update(List<MessagePart> parts, {Set<int>? changed}) {
    final previous = _previous?.target;
    final indices = <int>{};
    var structureChanged = previous == null || previous.length != parts.length;
    var toolsChanged = previous == null;
    final candidates = _revision == 0
        ? const <int>[]
        : previous == null || changed == null
        ? Iterable<int>.generate(parts.length)
        : changed;
    for (final index in candidates) {
      if (index >= parts.length) continue;
      final part = parts[index];
      final old = previous != null && index < previous.length
          ? previous[index]
          : null;
      if (old == part) continue;
      indices.add(index);
      structureChanged |= old?.kind != part.kind;
      toolsChanged |= old is ToolCallPart || part is ToolCallPart;
    }
    if (previous != null && previous.length > parts.length) {
      for (var i = parts.length; i < previous.length; i++) {
        indices.add(i);
        toolsChanged |= previous[i] is ToolCallPart;
      }
    }
    if (previous != null && indices.isEmpty && !structureChanged) {
      return previous;
    }
    if (structureChanged) _structureRevision++;
    if (toolsChanged) _toolsRevision++;
    _journal[++_revision] = Set.unmodifiable(indices);
    while (_journal.length > _journalLimit) {
      _journal.remove(_journal.keys.first);
    }
    final snapshot = MessagePartSnapshot._(
      parts,
      this,
      _revision,
      _structureRevision,
      _toolsRevision,
    );
    _previous = WeakReference(snapshot);
    return snapshot;
  }
}
