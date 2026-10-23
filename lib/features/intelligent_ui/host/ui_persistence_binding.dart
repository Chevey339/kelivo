import 'dart:async';
import '../runtime/ui_surface_controller.dart';
import '../storage/ui_state_repository.dart';

/// Connects one in-memory runtime to an application-owned save queue. Restores
/// never echo into persistence, and a user's edit/IME gesture beats a late load.
final class UiPersistenceBinding {
  UiPersistenceBinding(this.controller, this.store, this.conversationId) {
    _subscriptions.addAll([
      controller.listenStatus(_sync),
      controller.listenNode('root', _sync),
      controller.listenAcceptedState(_changed),
      controller.bindFlush(flush),
      store.listenAvailability(_availabilityChanged),
    ]);
    _sync();
  }

  final UiSurfaceController controller;
  final UiStateRepository store;
  final String conversationId;
  final _subscriptions = <void Function()>[];
  final _leaseSubscriptions = <void Function()>[];
  UiStateLease? _lease;
  UiRuntimeToken? _runtime;
  UiRestoreToken? _restoreToken;
  (int, String)? _identity;
  Future<void>? _load;
  bool _loadFailed = false;
  bool _edited = false;
  bool _disposed = false;
  bool get revoked => _lease != null && !_lease!.valid;

  void _availabilityChanged() {
    if (_disposed) return;
    if (!store.accepting) {
      controller.setReadOnly(true);
      return;
    }
    if (!revoked) controller.setReadOnly(false);
    _sync();
  }

  void _sync() {
    if (_disposed || !controller.canSnapshot) return;
    if (!store.accepting) {
      controller.setReadOnly(true);
      return;
    }
    final identity = (controller.token.epoch, controller.sourceHash!);
    if (_identity == identity) return;
    _identity = identity;
    _runtime = controller.token;
    _restoreToken = controller.restoreToken;
    _edited = false;
    _loadFailed = false;
    for (final stop in _leaseSubscriptions) {
      stop();
    }
    _leaseSubscriptions.clear();
    controller.setReadOnly(false);
    final lease = store.attach(conversationId, controller.owner, identity.$2);
    _lease = lease;
    if (lease == null) return;
    final runtime = _runtime!;
    _leaseSubscriptions.addAll([
      lease.listenInvalidated(() {
        if (!_disposed && controller.accepts(runtime)) {
          controller.setReadOnly(true);
        }
      }),
      lease.listenSaved((snapshot, failed) {
        if (!_disposed &&
            controller.accepts(runtime) &&
            controller.sourceHash == snapshot.sourceHash &&
            controller.state.json == snapshot.state.json) {
          controller.setSaveFailed(
            failed,
            token: runtime,
            sequence: controller.sequence,
          );
        }
      }),
    ]);
    _load = _restore(lease, runtime, _restoreToken!);
    unawaited(_load!.catchError((Object _) {}));
  }

  Future<void> _restore(
    UiStateLease lease,
    UiRuntimeToken runtime,
    UiRestoreToken restore,
  ) async {
    final sequence = controller.sequence;
    try {
      final saved = await store.load(lease);
      if (_disposed ||
          !lease.valid ||
          !identical(_lease, lease) ||
          !controller.accepts(runtime)) {
        return;
      }
      _loadFailed = false;
      if (!saved.valid) return;
      final snapshot = saved.snapshot;
      if (snapshot == null || controller.restore(snapshot, token: restore)) {
        controller.setSaveFailed(
          saved.saveFailed,
          token: runtime,
          sequence: controller.sequence,
        );
      }
    } catch (_) {
      if (!_disposed &&
          identical(_lease, lease) &&
          controller.accepts(runtime)) {
        _loadFailed = true;
        controller.setSaveFailed(true, token: runtime, sequence: sequence);
      }
      rethrow;
    }
  }

  void _changed() {
    final lease = _lease;
    if (_disposed ||
        lease == null ||
        !controller.canSnapshot ||
        !controller.accepts(_runtime!)) {
      return;
    }
    _edited = true;
    store.accept(lease, controller.captureSnapshot());
  }

  Future<void> flush() async {
    try {
      await _load;
    } catch (_) {
      // Retry loading unchanged state; an explicit user edit is a new snapshot.
    }
    final lease = _lease;
    if (!_disposed && _loadFailed && !_edited && lease != null) {
      _load = _restore(lease, _runtime!, _restoreToken!);
      await _load;
    }
    await store.flush();
  }

  void dispose() {
    _disposed = true;
    for (final stop in [..._subscriptions, ..._leaseSubscriptions]) {
      stop();
    }
    _subscriptions.clear();
    _leaseSubscriptions.clear();
  }
}
