import 'dart:async';
import 'dart:convert';

import '../protocol/ui_source_hash.dart';
import '../protocol/ui_validation.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_expression_walk.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_stream_parser.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_evaluator.dart';
import 'ui_resolved_node.dart';
import 'ui_surface_state.dart';

enum SurfacePhase {
  streaming,
  complete,
  completeWithErrors,
  interrupted,
  invalid,
}

enum UiGenerationStatus { generating, complete, interrupted }

enum UiMutationResult { accepted, unchanged, stale, readOnly, invalid }

/// Ephemeral authority for callbacks. Never serialized or stored in the DB.
final class UiRuntimeToken {
  const UiRuntimeToken._(this._instance, this.epoch);
  final Object _instance;
  final int epoch;
}

/// A pending restore must not overwrite even a no-op user choice or an IME
/// draft. Its interaction epoch is separate from actual state save sequencing.
final class UiRestoreToken {
  const UiRestoreToken._(this._runtime, this._sequence, this._interaction);
  final UiRuntimeToken _runtime;
  final int _sequence;
  final int _interaction;
}

/// Immutable references to a coherent input/output batch, also safe to retain
/// after subsequent user input. It is not a model-content serialization.
final class UiSurfaceRead {
  const UiSurfaceRead({
    required this.program,
    required this.phase,
    required this.inputs,
    required this.values,
    required this.nodes,
    required this.state,
    required this.sequence,
  });
  final Map<String, Object?> inputs;
  final UiValidationResult program;
  final SurfacePhase phase;
  final Map<String, UiComputedValue> values;
  final Map<String, UiResolvedNode> nodes;
  final UiSurfaceState state;
  final int sequence;
}

/// Pure in-memory owner. Widgets subscribe by node; the host owns its lifetime,
/// so rebuilding, scrolling away and changing themes cannot reset user inputs.
final class UiSurfaceController {
  UiSurfaceController({required this.owner, bool readOnly = false})
    : _forcedReadOnly = readOnly {
    _parse = _parser.snapshot;
    _state = UiSurfaceState.normalize(_parse.program);
    _recompute();
  }

  final UiSurfaceOwner owner;
  final _parser = UiStreamParser();
  final Object _instance = Object();
  late UiParseSnapshot _parse;
  late UiSurfaceState _state;
  late UiEvaluationBatch _batch;
  Map<String, UiResolvedNode> _nodes = const {};
  UiGenerationStatus _generation = UiGenerationStatus.generating;
  bool _forcedReadOnly;
  bool _saveFailed = false;
  bool _disposed = false;
  Future<void> Function()? _flush;
  int _epoch = 0;
  int _sequence = 0;
  int _interaction = 0;
  String? _sourceHash;
  final _statusListeners = <Object, void Function()>{};
  final _stateListeners = <Object, void Function()>{};
  final _acceptedStateListeners = <Object, void Function()>{};
  final _resetListeners = <Object, void Function()>{};
  final _disposeListeners = <Object, void Function()>{};

  void Function() listenDispose(void Function() listener) =>
      _listen(_disposeListeners, listener);
  final _nodeListeners = <String, Map<Object, void Function()>>{};

  UiParseSnapshot get parsed => _parse;
  UiSurfaceState get state => _state;
  Map<String, UiResolvedNode> get nodes => _nodes;
  int get sequence => _sequence;
  bool get saveFailed => _saveFailed;
  UiRuntimeToken get token => UiRuntimeToken._(_instance, _epoch);
  UiRestoreToken get restoreToken =>
      UiRestoreToken._(token, _sequence, _interaction);
  bool accepts(UiRuntimeToken token) =>
      !_disposed &&
      identical(token._instance, _instance) &&
      token.epoch == _epoch;
  bool get readOnly =>
      _disposed ||
      _forcedReadOnly ||
      !const {
        SurfacePhase.complete,
        SurfacePhase.completeWithErrors,
      }.contains(phase);
  bool get canSnapshot =>
      !_disposed &&
      _parse.closed &&
      !_parse.invalid &&
      _generation == UiGenerationStatus.complete;
  String? get sourceHash => _sourceHash;

  SurfacePhase get phase {
    if (_parse.invalid) return SurfacePhase.invalid;
    if (_generation == UiGenerationStatus.interrupted ||
        (_generation == UiGenerationStatus.complete && !_parse.closed)) {
      return SurfacePhase.interrupted;
    }
    if (_generation == UiGenerationStatus.generating || !_parse.closed) {
      return SurfacePhase.streaming;
    }
    return _parse.program.diagnostics.isNotEmpty ||
            _batch.values.values.any(
              (value) => !value.valid || value.gaps.isNotEmpty,
            ) ||
            _nodes.values.any((node) => !node.valid || node.gaps.isNotEmpty)
        ? SurfacePhase.completeWithErrors
        : SurfacePhase.complete;
  }

  void updateSource(
    String source, {
    required bool closed,
    required UiGenerationStatus generation,
  }) {
    _ensureAlive();
    final before = _status;
    final parsed = _parser.update(source, closed: closed);
    final changed = !identical(parsed, _parse);
    _generation = generation;
    if (changed) {
      final reset = parsed.epoch != _parse.epoch;
      final sameSource =
          parsed.closed && _parse.closed && parsed.source == _parse.source;
      _parse = parsed;
      _sourceHash = parsed.closed ? uiSourceHash(parsed.source) : null;
      if (reset) {
        _epoch++;
        if (!sameSource) {
          _sequence++;
          _saveFailed = false;
          _state = UiSurfaceState.normalize(parsed.program);
        }
      }
      _recompute();
      _notifyNodes(_nodeListeners.keys.toSet());
    }
    if (_status != before) {
      if (!changed && readOnly != before.$2) {
        _notifyNodes(_nodeListeners.keys.toSet());
      }
      _notify(_statusListeners);
    }
  }

  void setReadOnly(bool value) {
    _ensureAlive();
    if (_forcedReadOnly == value) return;
    _forcedReadOnly = value;
    _notifyNodes(_nodeListeners.keys.toSet());
    _notify(_statusListeners);
  }

  UiMutationResult setInputs(
    Map<String, Object?> changes, {
    required UiRuntimeToken token,
  }) {
    if (!accepts(token)) return UiMutationResult.stale;
    if (readOnly) return UiMutationResult.readOnly;
    _interaction++;
    try {
      return _acceptState(
        UiSurfaceState.normalize(
          _parse.program,
          inputs: {..._state.inputs, ...changes},
          view: _state.view,
        ),
      );
    } on FormatException {
      return UiMutationResult.invalid;
    }
  }

  UiMutationResult setView(
    String node,
    Map<String, Object?> settings, {
    required UiRuntimeToken token,
  }) {
    if (!accepts(token)) return UiMutationResult.stale;
    if (readOnly) return UiMutationResult.readOnly;
    _interaction++;
    try {
      return _acceptState(
        UiSurfaceState.normalize(
          _parse.program,
          inputs: _state.inputs,
          view: {..._state.view, node: settings},
        ),
      );
    } on FormatException {
      return UiMutationResult.invalid;
    }
  }

  UiMutationResult reset({required UiRuntimeToken token}) {
    if (!accepts(token)) return UiMutationResult.stale;
    if (readOnly) return UiMutationResult.readOnly;
    _interaction++;
    final result = _acceptState(UiSurfaceState.normalize(_parse.program));
    _notify(_resetListeners);
    return result;
  }

  void noteInteraction({required UiRuntimeToken token}) {
    if (accepts(token) && !readOnly) _interaction++;
  }

  UiSurfaceRead captureRead() {
    _ensureAlive();
    return UiSurfaceRead(
      program: _parse.program,
      phase: phase,
      inputs: _batch.inputs,
      values: _batch.values,
      nodes: _nodes,
      state: _state,
      sequence: _sequence,
    );
  }

  UiSurfaceSnapshot captureSnapshot() {
    if (!canSnapshot) throw StateError('Only completed sources can be saved');
    return UiSurfaceSnapshot(
      owner: owner,
      sourceHash: sourceHash!,
      state: _state,
    );
  }

  bool restore(UiSurfaceSnapshot saved, {required UiRestoreToken token}) {
    if (!accepts(token._runtime) ||
        token._sequence != _sequence ||
        token._interaction != _interaction ||
        !canSnapshot ||
        saved.owner != owner ||
        saved.sourceHash != sourceHash) {
      return false;
    }
    try {
      final restored = UiSurfaceState.decode(
        _parse.program,
        saved.state.json,
        stateVersion: saved.stateVersion,
      );
      _acceptState(restored, restored: true);
      return true;
    } on FormatException {
      return false;
    }
  }

  bool setSaveFailed(
    bool value, {
    required UiRuntimeToken token,
    required int sequence,
  }) {
    if (!accepts(token) || sequence != _sequence) return false;
    if (value != _saveFailed) {
      _saveFailed = value;
      _notify(_statusListeners);
    }
    return true;
  }

  /// Storage is supplied by the host; this controller remains pure Dart.
  void Function() bindFlush(Future<void> Function() flush) {
    _flush = flush;
    return () {
      if (identical(_flush, flush)) _flush = null;
    };
  }

  Future<void> flush() => _flush?.call() ?? Future.value();

  void flushQuietly() {
    unawaited(
      flush().catchError((Object _) {
        // The persistence binding owns the visible failure and retry state.
      }),
    );
  }

  void Function() listenStatus(void Function() listener) =>
      _listen(_statusListeners, listener);
  void Function() listenState(void Function() listener) =>
      _listen(_stateListeners, listener);

  /// Includes an explicit no-op choice/Reset while a restore is pending. Such
  /// a choice must replace the stored value even when the provisional default
  /// on screen already equals the value the user chose.
  void Function() listenAcceptedState(void Function() listener) =>
      _listen(_acceptedStateListeners, listener);
  void Function() listenReset(void Function() listener) =>
      _listen(_resetListeners, listener);
  void Function() listenNode(String name, void Function() listener) =>
      _listen(_nodeListeners.putIfAbsent(name, () => {}), listener);

  UiMutationResult _acceptState(UiSurfaceState next, {bool restored = false}) {
    if (next.json == _state.json) {
      if (!restored) _notify(_acceptedStateListeners);
      return UiMutationResult.unchanged;
    }
    final before = _status;
    final oldView = _state.view;
    _state = next;
    _sequence++;
    final oldNodes = _nodes;
    _recompute(previous: _batch);
    final changed = {
      ..._batch.dirtySymbols,
      for (final entry in _nodes.entries)
        if (!identical(oldNodes[entry.key], entry.value)) entry.key,
    };
    for (final id in {...oldView.keys, ...next.view.keys}) {
      if (jsonEncode(oldView[id]) != jsonEncode(next.view[id])) changed.add(id);
    }
    _notifyNodes(changed);
    if (_status != before) _notify(_statusListeners);
    if (!restored) {
      _notify(_stateListeners);
      _notify(_acceptedStateListeners);
    }
    return UiMutationResult.accepted;
  }

  void _recompute({UiEvaluationBatch? previous}) {
    final oldNodes = _nodes;
    _batch = UiEvaluationBatch(
      _parse.program,
      _state.inputs,
      previous: previous,
    );
    // Resolve once before publishing state. Widget rebuilds never consume budget.
    final dirty = _batch.dirtySymbols;
    final declarations = {
      for (final node
          in _parse.program.declarations.values.whereType<UiNodeDeclaration>())
        node.name: node,
    };
    final order = uiDependencyOrder({
      for (final name in declarations.keys)
        name: _parse.program.dependencies[name] ?? {},
    });
    final nodes = <String, UiResolvedNode>{};
    final recomputed = <String>{};
    for (final name in order.order) {
      final node = declarations[name]!;
      if (previous != null &&
          !dirty.contains(name) &&
          oldNodes[name]?.valid == true &&
          !(_parse.program.dependencies[name] ?? {}).any(recomputed.contains)) {
        nodes[name] = oldNodes[name]!;
      } else {
        nodes[name] = uiResolveNode(node, _batch, nodes);
        recomputed.add(name);
      }
    }
    _nodes = Map.unmodifiable(nodes);
  }

  (SurfacePhase, bool, bool, int) get _status => (
    phase,
    readOnly,
    saveFailed,
    _nodes.values.where((node) => !node.valid && !node.pending).length,
  );
  void _ensureAlive() {
    if (_disposed) throw StateError('Surface has been disposed');
  }

  void Function() _listen(
    Map<Object, void Function()> listeners,
    void Function() listener,
  ) {
    _ensureAlive();
    final key = Object();
    listeners[key] = listener;
    return () => listeners.remove(key);
  }

  void _notify(Map<Object, void Function()> listeners) {
    for (final entry in listeners.entries.toList()) {
      if (listeners.containsKey(entry.key)) entry.value();
    }
  }

  void _notifyNodes(Set<String> names) {
    for (final name in names) {
      final listeners = _nodeListeners[name];
      if (listeners != null) _notify(listeners);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _notify(_disposeListeners);
    _disposeListeners.clear();
    _flush = null;
    _epoch++;
    _nodeListeners.clear();
    _stateListeners.clear();
    _acceptedStateListeners.clear();
    _resetListeners.clear();
    _statusListeners.clear();
  }
}
