import 'dart:async';

import 'package:drift/drift.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import '../host/ui_source_selection.dart';
import '../protocol/ui_source_hash.dart';
import '../protocol/ui_stream_parser.dart';
import '../protocol/ui_validation.dart';
import '../runtime/ui_surface_state.dart';

/// Captured when a runtime attaches. A stale widget cannot acquire the current
/// epoch merely by enqueueing another value after a delete or A -> B -> A edit.
final class UiStateLease {
  UiStateLease._(this.conversationId, this.owner, this.sourceHash);
  final String conversationId, sourceHash;
  final UiSurfaceOwner owner;
  bool _valid = true;
  bool get valid => _valid;
  final _invalidated = <void Function()>{};
  final _saved = <void Function(UiSurfaceSnapshot, bool)>{};

  void Function() listenInvalidated(void Function() listener) {
    _invalidated.add(listener);
    return () => _invalidated.remove(listener);
  }

  void Function() listenSaved(
    void Function(UiSurfaceSnapshot snapshot, bool failed) listener,
  ) {
    _saved.add(listener);
    return () => _saved.remove(listener);
  }

  void _revoke() {
    if (!_valid) return;
    _valid = false;
    for (final listener in List.of(_invalidated)) {
      listener();
    }
    _invalidated.clear();
    _saved.clear();
  }

  void _publish(UiSurfaceSnapshot snapshot, bool failed) {
    for (final listener in List.of(_saved)) {
      listener(snapshot, failed);
    }
  }
}

final class UiStateRead {
  const UiStateRead({
    this.snapshot,
    this.valid = true,
    this.saveFailed = false,
  });
  final UiSurfaceSnapshot? snapshot;
  final bool valid, saveFailed;
}

final class _Pending {
  _Pending(this.lease, this.snapshot, {this.failed = false});
  final UiStateLease lease;
  final UiSurfaceSnapshot snapshot;
  bool failed;
}

final class _WriteContext {
  _WriteContext(this.repository);
  final UiStateRepository repository;
  bool active = true;
  final committed = <void Function()>[];
}

/// Application/repository lifetime, independent of slivers and controller
/// disposal. Source mutations and saves enter the same queue before opening a
/// database transaction; only successful commits publish lease invalidation.
final class UiStateRepository {
  UiStateRepository(
    this._db,
    this._readMessage, {
    Zone? lifetimeZone,
    this.debounce = const Duration(milliseconds: 250),
  }) : _zone = lifetimeZone ?? Zone.current {
    // IO outlives a page/clock scope. Preserve its zone values and error handler,
    // but dispatch queue microtasks independently of a caller's paused clock.
    _queueZone = _zone.fork(
      specification: ZoneSpecification(
        scheduleMicrotask: (_, _, zone, callback) =>
            Zone.root.scheduleMicrotask(zone.bindCallbackGuarded(callback)),
      ),
    );
    _tail = _queueZone.run(() => Future<void>.value());
  }

  final AppDatabase _db;
  final Future<ChatMessage?> Function(String) _readMessage;
  final Zone _zone;
  late final Zone _queueZone;
  final Duration debounce;
  static final Object _contextKey = Object();
  late Future<void> _tail;
  final _leases = <UiSurfaceOwner, UiStateLease>{};
  final _candidates = <UiStateLease>{};
  final _pending = <UiStateLease, _Pending>{};
  Timer? _timer;
  bool _accepting = true;
  bool get accepting => _accepting;
  final _availability = <void Function()>{};

  void Function() listenAvailability(void Function() listener) {
    _availability.add(listener);
    return () => _availability.remove(listener);
  }

  void _setAccepting(bool value) {
    if (_accepting == value) return;
    _accepting = value;
    for (final listener in List.of(_availability)) {
      listener();
    }
  }

  _WriteContext? get _context {
    final current = Zone.current[_contextKey];
    return current is _WriteContext &&
            identical(current.repository, this) &&
            current.active
        ? current
        : null;
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    // Return a future in the caller's error zone, while every queue continuation
    // belongs to the store. Futures with errors cannot cross Dart error zones.
    final result = Completer<T>();
    _queueZone.run(() {
      final next = _tail.then((_) => action());
      _tail = next.then<void>(
        result.complete,
        onError: (Object error, StackTrace stack) =>
            result.completeError(error, stack),
      );
    });
    return result.future;
  }

  Future<T> _inTransaction<T>(
    Future<T> Function() action, {
    _WriteContext? parent,
  }) async {
    final context = _WriteContext(this);
    try {
      final result = await runZoned(
        () => _db.transaction(() async {
          try {
            return await action();
          } finally {
            // COMMIT can await IO after the body ends. Delayed inherited jobs
            // must queue, rather than join a transaction already closing.
            context.active = false;
          }
        }),
        zoneValues: {_contextKey: context},
      );
      if (parent != null) {
        // A failed savepoint discards its publications, even when its caller
        // catches the error and continues the outer transaction.
        parent.committed.addAll(context.committed);
      } else {
        for (final publish in context.committed) {
          publish();
        }
      }
      return result;
    } finally {
      context.active = false;
    }
  }

  Future<T> transaction<T>(Future<T> Function() action) {
    final parent = _context;
    return parent == null
        ? _serialize(() => _inTransaction(action))
        : _inTransaction(action, parent: parent);
  }

  void afterCommit(void Function() publish) {
    final context = _context;
    if (context == null) throw StateError('GenUI write outside transaction');
    context.committed.add(publish);
  }

  UiStateLease? attach(
    String conversationId,
    UiSurfaceOwner owner,
    String hash,
  ) {
    if (!_accepting) return null;
    final existing = _leases[owner];
    if (existing != null &&
        existing.valid &&
        existing.conversationId == conversationId &&
        existing.sourceHash == hash) {
      return existing;
    }
    for (final candidate in _candidates) {
      if (candidate.owner == owner &&
          candidate.conversationId == conversationId &&
          candidate.sourceHash == hash) {
        return candidate;
      }
    }
    final lease = UiStateLease._(conversationId, owner, hash);
    if (existing == null) {
      _leases[owner] = lease;
    } else {
      // A retained stale message cannot evict the current owner's dirty value.
      // Candidates are promoted only after transactional source verification.
      _candidates.add(lease);
    }
    return lease;
  }

  bool _owns(UiStateLease lease) =>
      lease.valid && identical(_leases[lease.owner], lease);
  bool _known(UiStateLease lease) =>
      lease.valid && (_owns(lease) || _candidates.contains(lease));
  Iterable<UiStateLease> get _allLeases => [..._leases.values, ..._candidates];

  void _claim(UiStateLease lease) {
    if (!_known(lease) || _owns(lease)) return;
    final previous = _leases[lease.owner];
    if (previous != null) _revokeLease(previous);
    _candidates.remove(lease);
    _leases[lease.owner] = lease;
  }

  bool accept(UiStateLease lease, UiSurfaceSnapshot snapshot) {
    if (!_accepting ||
        !_known(lease) ||
        snapshot.owner != lease.owner ||
        snapshot.sourceHash != lease.sourceHash) {
      return false;
    }
    _pending[lease] = _Pending(
      lease,
      snapshot,
      failed: _pending[lease]?.failed ?? false,
    );
    _timer?.cancel();
    _timer = _zone.createTimer(debounce, flushQuietly);
    return true;
  }

  void flushQuietly() {
    unawaited(
      flush().catchError((Object _) {
        // Failure remains on the pending snapshot and its visible status. The
        // next explicit flush/retry still receives the error; no snackbar.
      }),
    );
  }

  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    return _serialize(() async {
      Object? firstError;
      StackTrace? firstStack;
      for (final pending in List.of(_pending.values)) {
        if (!identical(_pending[pending.lease], pending)) continue;
        try {
          await _inTransaction(() => _save(pending));
          if (identical(_pending[pending.lease], pending)) {
            _pending.remove(pending.lease);
            if (_known(pending.lease)) {
              pending.lease._publish(pending.snapshot, false);
            }
          }
        } catch (error, stack) {
          if (identical(_pending[pending.lease], pending) &&
              _known(pending.lease)) {
            pending.failed = true;
            pending.lease._publish(pending.snapshot, true);
          }
          firstError ??= error;
          firstStack ??= stack;
        }
      }
      if (firstError != null) {
        Error.throwWithStackTrace(firstError, firstStack!);
      }
    });
  }

  Future<UiValidationResult?> _program(UiStateLease lease) async {
    if (!_known(lease)) return null;
    final message = await _readMessage(lease.owner.revisionId);
    if (!_known(lease) ||
        message == null ||
        message.conversationId != lease.conversationId ||
        message.isStreaming ||
        message.generationState != GenerationRunState.completed) {
      return null;
    }
    for (final fence in uiEligibleFences(message)) {
      if (fence.surfaceKey != lease.owner.surfaceKey || !fence.node.closed) {
        continue;
      }
      final parsed = UiStreamParser().update(fence.body, closed: true);
      if (!parsed.invalid && uiSourceHash(parsed.source) == lease.sourceHash) {
        afterCommit(() => _claim(lease));
        return parsed.program;
      }
      return null;
    }
    return null;
  }

  Future<GenUiSurfaceStateRow?> _row(UiStateLease lease) async {
    final table = _db.genUiSurfaceStateRows;
    final row =
        await (_db.select(table)..where(
              (t) =>
                  t.revisionId.equals(lease.owner.revisionId) &
                  t.surfaceKey.equals(lease.owner.surfaceKey),
            ))
            .getSingleOrNull();
    if (row != null && row.sourceHash != lease.sourceHash) {
      await (_db.delete(table)..where(
            (t) =>
                t.revisionId.equals(lease.owner.revisionId) &
                t.surfaceKey.equals(lease.owner.surfaceKey),
          ))
          .go();
      return null;
    }
    return row;
  }

  Future<UiStateRead> load(UiStateLease lease) => _serialize(
    () => _inTransaction(() async {
      final program = await _program(lease);
      if (program == null) {
        afterCommit(() => _revokeLease(lease));
        return const UiStateRead(valid: false);
      }
      // A quick leave/reopen sees the latest accepted value, including a failed
      // save, rather than restoring older durable data over the user's changes.
      final pending = _pending[lease];
      if (pending != null && identical(pending.lease, lease)) {
        return UiStateRead(
          snapshot: pending.snapshot,
          saveFailed: pending.failed,
        );
      }
      final row = await _row(lease);
      if (row == null) return const UiStateRead();
      return UiStateRead(
        snapshot: UiSurfaceSnapshot(
          owner: lease.owner,
          sourceHash: lease.sourceHash,
          state: UiSurfaceState.decode(
            program,
            row.stateJson,
            stateVersion: row.stateVersion,
          ),
        ),
      );
    }),
  );

  Future<void> _save(_Pending pending) async {
    final lease = pending.lease;
    final program = await _program(lease);
    if (program == null) {
      afterCommit(() => _revokeLease(lease));
      return;
    }
    final state = UiSurfaceState.decode(
      program,
      pending.snapshot.state.json,
      stateVersion: pending.snapshot.stateVersion,
    );
    final row = await _row(lease);
    if ((row == null && state.isDefault) ||
        (row?.stateVersion == UiSurfaceState.version &&
            row?.stateJson == state.json)) {
      return;
    }
    final now = DateTime.now().toUtc();
    await _db
        .into(_db.genUiSurfaceStateRows)
        .insert(
          GenUiSurfaceStateRowsCompanion.insert(
            revisionId: lease.owner.revisionId,
            surfaceKey: lease.owner.surfaceKey,
            sourceHash: lease.sourceHash,
            stateVersion: const Value(UiSurfaceState.version),
            stateJson: Value(state.json),
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => GenUiSurfaceStateRowsCompanion(
              stateVersion: const Value(UiSurfaceState.version),
              stateJson: Value(state.json),
              updatedAt: Value(now),
            ),
          ),
        );
  }

  /// Called with the actual ordered parts written in the current transaction.
  Future<void> reconcileSource(ChatMessage message) async {
    final rows = await (_db.select(
      _db.genUiSurfaceStateRows,
    )..where((t) => t.revisionId.equals(message.id))).get();
    if (rows.isEmpty &&
        !_allLeases.any((lease) => lease.owner.revisionId == message.id)) {
      return;
    }
    final hashes = <String, String>{};
    for (final fence in uiEligibleFences(message)) {
      if (!fence.node.closed) continue;
      final parsed = UiStreamParser().update(fence.body, closed: true);
      if (!parsed.invalid) {
        hashes[fence.surfaceKey] = uiSourceHash(parsed.source);
      }
    }
    for (final row in rows) {
      if (hashes[row.surfaceKey] != row.sourceHash) {
        await (_db.delete(_db.genUiSurfaceStateRows)..where(
              (t) =>
                  t.revisionId.equals(message.id) &
                  t.surfaceKey.equals(row.surfaceKey),
            ))
            .go();
      }
    }
    afterCommit(() {
      for (final lease in List.of(_allLeases)) {
        if (lease.owner.revisionId == message.id &&
            (lease.conversationId != message.conversationId ||
                hashes[lease.owner.surfaceKey] != lease.sourceHash)) {
          _revokeLease(lease);
        }
      }
    });
  }

  /// Replacement imports may cascade away revisions absent from their batch.
  /// Match both conversation owners and explicit revision IDs after commit.
  void invalidateAfterCommit({
    Set<String> conversations = const {},
    Set<String> revisions = const {},
    bool all = false,
  }) {
    afterCommit(() {
      for (final lease in List.of(_allLeases)) {
        if (all ||
            conversations.contains(lease.conversationId) ||
            revisions.contains(lease.owner.revisionId)) {
          _revokeLease(lease);
        }
      }
    });
  }

  void _revokeLease(UiStateLease lease) {
    if (!_known(lease)) return;
    _pending.remove(lease);
    if (identical(_leases[lease.owner], lease)) _leases.remove(lease.owner);
    _candidates.remove(lease);
    lease._revoke();
  }

  /// Enter only after restore validation, immediately before database cutover.
  /// A failure keeps every dirty snapshot and restores acceptance on this DB.
  Future<void> pauseAndDrain() async {
    _setAccepting(false);
    try {
      await flush();
      await _tail;
    } catch (_) {
      resume();
      rethrow;
    }
  }

  void resume() => _setAccepting(true);

  void discardAfterCutover() {
    _setAccepting(false);
    _timer?.cancel();
    for (final lease in List.of(_allLeases)) {
      _revokeLease(lease);
    }
  }
}
