import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart' show TextEditingController;
import 'package:dart_quill_delta/dart_quill_delta.dart' as quill;
import 'package:re_editor/re_editor.dart';
import 'compact_edit.dart';
import 'text_changes.dart';

/// An Android document with compact, versioned edits.
/// App commands use ordered compare-and-apply with concurrent transforms.
/// The document outlives individual IME attachments and drains before close.
class NativeMessageInput with TextInputControl {
  NativeMessageInput({
    this.channel = const MethodChannel('kelivo/native_message_input'),
  }) {
    _router = _InputRouter.forChannel(channel);
  }

  Future<Object?> _handle(MethodCall call) async {
    if (call.method == 'event') {
      receive(Map<Object?, Object?>.from(call.arguments as Map));
    } else if (call.method == 'navigate') {
      final request = Map<Object?, Object?>.from(call.arguments as Map);
      if (request['session'] != session ||
          request['revision'] != revision ||
          nativeValue == null) {
        throw StateError('Navigation does not match the document revision');
      }
      refreshNavigationLayout();
      final layout = _layout;
      if (layout == null) throw StateError('No retained navigation layout');
      final target = layout.resolve(
        nativeValue!.copyWith(
          selection: TextSelection(
            baseOffset: request['base'] as int,
            extentOffset: request['extent'] as int,
            affinity: nativeValue!.selection.affinity,
          ),
        ),
        request['up'] as bool,
        request['extend'] as bool,
        lineEdge: request['lineEdge'] == true,
      );
      return {
        'base': target.baseOffset,
        'extent': target.extentOffset,
        'affinity': target.affinity.name,
      };
    } else if (call.method == 'command') {
      final args = call.arguments as Map;
      await _dispatchCommand(
        args['command'] as String,
        args['request'] as int?,
      );
    } else if (call.method == 'action') {
      final action = switch ((call.arguments as Map)['action'] as int) {
        2 => TextInputAction.go,
        3 => TextInputAction.search,
        4 => TextInputAction.send,
        5 => TextInputAction.next,
        6 => TextInputAction.done,
        7 => TextInputAction.previous,
        _ => TextInputAction.unspecified,
      };
      final active = client;
      if (action == TextInputAction.send && onCommand != null) {
        await _dispatchCommand('submit', null);
      } else if (active != null) {
        active.performAction(action);
      } else {
        _detachedCallbacks?.onSubmitted?.call(_projectedValue!.text);
      }
    } else if (call.method == 'content') {
      final value = call.arguments as Map;
      final content = KeyboardInsertedContent(
        mimeType: value['mimeType'] as String,
        uri: value['uri'] as String,
        data: value['data'] as Uint8List,
      );
      final active = client;
      if (onContent != null) {
        await _runOwnerOperation(() => onContent!(content));
      } else if (active != null) {
        active.insertContent(content);
      } else {
        // The native document already accepted and MIME-checked this event.
        // An internal renderer handoff must not silently revoke acceptance.
        _detachedCallbacks?.onContentInserted?.call(content);
      }
    } else if (call.method == 'failure') {
      _fail((call.arguments as Map)['error'].toString());
    }
    return null;
  }

  final MethodChannel channel;
  TextInputClient? client;
  CodeDocumentCallbacks? _detachedCallbacks;
  TextInputConfiguration? _configuration;
  TextEditingValue? nativeValue;
  int revision = 0;
  late final _InputRouter _router;
  CodeNavigationLayout? _layout;
  Completer<void> _changed = Completer<void>();
  Future<TextEditingValue>? _closeFuture;
  Future<TextEditingValue>? _flushFuture;
  bool _closed = false;
  bool _closing = false;
  TextEditingValue? get value => _projectedValue;
  bool get isOpen => nativeValue != null && !_closed;
  bool get isClosing => _closing;
  bool get acceptsModelWrite =>
      !_closing || _receiving || _insideOwnerOperation;
  TextEditingController? _document;

  /// Owned by the document, not its current renderer. Futures cover mutations
  /// and asset registration that close must retain, not a later network send.
  /// Use the supplied snapshot; awaiting this input's flush/close would wait
  /// on the operation itself and is rejected explicitly.
  FutureOr<void> Function(String command, TextEditingValue snapshot)? onCommand;
  FutureOr<void> Function(KeyboardInsertedContent content)? onContent;
  static final _commandZone = Object();
  int _commandsExecuting = 0;
  Map<String, Object> _hardware = const {
    'enter': 'newline',
    'commands': <String>[],
  };
  int _nextCommand = 0;
  final _commands = <int, Completer<void>>{};

  Future<void> _dispatchCommand(String name, int? request) async {
    final snapshot = _projectedValue ?? _document!.value;
    await _runOwnerOperation(() => onCommand!(name, snapshot));
    if (request != null) _commands.remove(request)?.complete();
    _signal();
  }

  Future<void> _runOwnerOperation(FutureOr<void> Function() work) async {
    final operation = _OwnerOperation(this);
    _commandsExecuting++;
    try {
      await runZoned(work, zoneValues: {_commandZone: operation});
    } catch (error) {
      _fail('owner operation: $error');
      rethrow;
    } finally {
      operation.active = false;
      _commandsExecuting--;
      _signal();
    }
  }

  bool get _insideOwnerOperation {
    final operation = Zone.current[_commandZone];
    return operation is _OwnerOperation &&
        operation.active &&
        identical(operation.input, this);
  }

  void _checkCommandReentry() {
    if (_insideOwnerOperation) {
      throw StateError(
        'Use the ordered command snapshot instead of waiting on its own input barrier',
      );
    }
  }

  Future<void> configureHardware({
    required String enter,
    required List<String> commands,
  }) async {
    if (_hardware['enter'] == enter &&
        listEquals(_hardware['commands'] as List<String>, commands)) {
      return;
    }
    _hardware = {'enter': enter, 'commands': commands};
    if (nativeValue != null && !_closed) {
      await command('hardware', {'configuration': _hardware});
    }
  }

  /// Completes when the owner finishes its document mutation/registration.
  /// The owner registers pending clipboard work synchronously before awaiting
  /// it, so a following Send can observe it and keep the draft intact.
  Future<void> performCommand(String name) async {
    if (_closing || _closed) throw StateError('Document is closing');
    if (nativeValue == null) {
      await _dispatchCommand(name, null);
      return;
    }
    final request = ++_nextCommand;
    final delivered = Completer<void>();
    _commands[request] = delivered;
    // Observe errors immediately, including before the native RPC returns.
    final observed = delivered.future;
    unawaited(observed.catchError((Object _) {}));
    try {
      await channel.invokeMethod<void>('command', {
        'session': session,
        'command': name,
        'request': request,
      });
      await observed;
    } catch (error) {
      _fail('command $name: $error');
      rethrow;
    } finally {
      _commands.remove(request);
      _signal();
    }
  }

  void bindDocument(TextEditingController controller) {
    if (identical(_document, controller)) return;
    if (_document != null && nativeValue != null && !_closed) {
      throw StateError(
        'Close the previous document before replacing its model',
      );
    }
    unbindDocument();
    if (_closed) {
      // A paragraph editor can keep changing this model after the native
      // document was retired. A later barrier/attachment starts from that
      // current model, never the previous document's final snapshot.
      nativeValue = _projectedValue = null;
      _closeFuture = null;
      _closed = _closing = false;
    }
    _document = controller;
    controller.addListener(_modelChanged);
  }

  void unbindDocument() {
    _document?.removeListener(_modelChanged);
    _document = null;
  }

  void _modelChanged() {
    if (_receiving || nativeValue == null || _closed) return;
    var next = _document!.value;
    if (!next.selection.isValid) {
      next = next.copyWith(
        selection: TextSelection.collapsed(offset: next.text.length),
      );
    }
    if (next != _projectedValue) setEditingState(next);
  }

  int _nextRequest = 0;
  int? _inFlightRequest;
  int _retryAfterRevision = 0;
  final _pending = <_AppEdit>[];
  TextEditingValue? _projectedValue;
  String session = '';
  bool _receiving = false;
  Timer? _showTimer;
  final failures = <String>[];
  final _failureWaiters = <void Function(StateError)>[];
  void Function()? onChange;

  CodeInputConnection openConnection(
    DeltaTextInputClient client,
    TextInputConfiguration configuration,
  ) {
    attach(client, configuration);
    return _MirrorCodeConnection(this, client);
  }

  Future<void> command(
    String method, [
    Map<String, Object?> values = const {},
  ]) async {
    try {
      await channel.invokeMethod<void>(method, {'session': session, ...values});
    } catch (error) {
      _fail('$method: $error');
    }
  }

  @override
  void attach(TextInputClient client, TextInputConfiguration configuration) {
    if (_closing && !_closed) {
      throw StateError('Wait for document close before opening a new document');
    }
    _showTimer?.cancel();
    this.client = client;
    final previousConfiguration = _configuration;
    _configuration = configuration;
    _router.foreground = this;
    if (nativeValue == null || _closed) {
      session = _router.register(this);
      revision = 0;
      nativeValue = _projectedValue = null;
      _pending.clear();
      _inFlightRequest = null;
      _retryAfterRevision = 0;
      _closed = _closing = false;
      _closeFuture = null;
    }
    if (nativeValue != null && configuration != previousConfiguration) {
      unawaited(
        command('configure', {'configuration': configuration.toJson()}),
      );
    }
    refreshNavigationLayout();
  }

  @override
  void updateConfig(TextInputConfiguration configuration) {
    if (_configuration == configuration) return;
    _configuration = configuration;
    if (nativeValue != null && !_closed && !_closing) {
      unawaited(
        command('configure', {'configuration': configuration.toJson()}),
      );
    }
  }

  void refreshNavigationLayout() {
    final active = client;
    if (active is! CodeNavigationInputClient) return;
    final next = (active as CodeNavigationInputClient)
        .captureNavigationLayout();
    if (next == null) return;
    if (_layout?.sameConfiguration(next) == true) {
      next.dispose();
    } else {
      _layout?.dispose();
      _layout = next;
    }
  }

  @override
  void detach(TextInputClient client) {
    if (!identical(this.client, client)) return;
    refreshNavigationLayout();
    _captureDocumentCallbacks();
    _showTimer?.cancel();
    this.client = null;
    // Ending an IME attachment is not destruction of its document. Accepted
    // edits still update the independent value and the surviving app model.
    unawaited(command('endInput'));
  }

  void _captureDocumentCallbacks() {
    final active = client;
    if (active is CodeDocumentInputClient) {
      _detachedCallbacks = (active as CodeDocumentInputClient)
          .captureDocumentCallbacks();
    }
  }

  void _signal() {
    final previous = _changed;
    _changed = Completer<void>();
    previous.complete();
  }

  void _fail(String message) {
    failures.add(message);
    for (final command in _commands.values) {
      if (!command.isCompleted) command.completeError(StateError(message));
    }
    for (final waiter in [..._failureWaiters]) {
      waiter(StateError(message));
    }
    _signal();
    onChange?.call();
  }

  Future<void> _waitUntil(bool Function() condition) async {
    while (true) {
      if (failures.isNotEmpty) throw StateError(failures.last);
      if (condition()) return;
      await _changed.future;
    }
  }

  Future<int> _nativeBarrier(String method) async {
    if (failures.isNotEmpty) throw StateError(failures.last);
    final interrupted = Completer<int>();
    void fail(StateError error) {
      if (!interrupted.isCompleted) interrupted.completeError(error);
    }

    _failureWaiters.add(fail);
    try {
      final reply = channel
          .invokeMapMethod<Object?, Object?>(method, {'session': session})
          .then((result) => result!['revision'] as int);
      return await Future.any([reply, interrupted.future]);
    } finally {
      _failureWaiters.remove(fail);
    }
  }

  /// A point-in-time editing barrier for send/save/navigation consumers.
  Future<TextEditingValue> flush() {
    _checkCommandReentry();
    return _closeFuture ??
        (_flushFuture ??= _flushDocument().whenComplete(
          () => _flushFuture = null,
        ));
  }

  Future<TextEditingValue> _flushDocument() async {
    await _waitUntil(() => _commandsExecuting == 0 && _commands.isEmpty);
    if (_closed || nativeValue == null) {
      return _projectedValue ?? _document?.value ?? TextEditingValue.empty;
    }
    while (true) {
      await _waitUntil(
        () =>
            _pending.isEmpty &&
            _inFlightRequest == null &&
            _commands.isEmpty &&
            _commandsExecuting == 0,
      );
      final barrier = await _nativeBarrier('flush');
      await _waitUntil(() => revision >= barrier);
      if (_pending.isEmpty &&
          _inFlightRequest == null &&
          _commands.isEmpty &&
          _commandsExecuting == 0) {
        return _projectedValue!;
      }
    }
  }

  /// Retains the model and navigation settings until every accepted edit has
  /// been delivered. Callers that consume/dispose their document await this.
  Future<TextEditingValue> close() {
    _checkCommandReentry();
    return _closeFuture ??= _finishClose().catchError((
      Object error,
      StackTrace stack,
    ) {
      _closing = false;
      _closeFuture = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<TextEditingValue> _finishClose() async {
    _showTimer?.cancel();
    _captureDocumentCallbacks();
    final active = client;
    if (active != null) detach(active);
    _closing = true;
    await _waitUntil(() => _commandsExecuting == 0 && _commands.isEmpty);
    if (nativeValue == null) {
      final finalValue =
          _projectedValue ?? _document?.value ?? TextEditingValue.empty;
      _closed = true;
      client = null;
      _detachedCallbacks = null;
      _layout?.dispose();
      _layout = null;
      _router.remove(session);
      unbindDocument();
      return finalValue;
    }
    if (_flushFuture != null) await _flushFuture;
    await _flushDocument();
    final barrier = await _nativeBarrier('close');
    await _waitUntil(() => revision >= barrier);
    _closed = true;
    client = null;
    _detachedCallbacks = null;
    _layout?.dispose();
    _layout = null;
    _router.remove(session);
    unbindDocument();
    return _projectedValue!;
  }

  @override
  void show() {
    _showTimer?.cancel();
    // EditableText queues its retiring connection's hide in a microtask. Show
    // the replacement after those microtasks; a later hide/close cancels this.
    _showTimer = Timer(Duration.zero, () {
      _showTimer = null;
      if (client != null) unawaited(command('show'));
    });
  }

  @override
  void hide() {
    _showTimer?.cancel();
    unawaited(command('hide'));
  }

  @override
  void setEditingState(TextEditingValue value) {
    if (_receiving) return;
    if (_closed ||
        (_closing && (_commandsExecuting == 0 || !_insideOwnerOperation))) {
      throw StateError('Cannot edit a closing document');
    }
    final previous = _projectedValue;
    if (previous == null) {
      nativeValue = _projectedValue = value;
      unawaited(
        command('open', {
          'configuration': _configuration!.toJson(),
          'hardware': _hardware,
          'text': value.text,
          'base': value.selection.baseOffset,
          'extent': value.selection.extentOffset,
        }),
      );
      return;
    }
    if (value == previous) return;
    _layout?.invalidate();
    _pending.add(
      _AppEdit(
        ++_nextRequest,
        TextChanges.diff(previous, value),
        value.selection,
        value.composing,
      ),
    );
    _projectedValue = value;
    _sendNextEdit();
  }

  void _sendNextEdit() {
    if (_pending.isEmpty ||
        _inFlightRequest != null ||
        revision < _retryAfterRevision) {
      return;
    }
    final edit = _pending.first;
    final editSession = session;
    _inFlightRequest = edit.id;
    unawaited(
      channel
          .invokeMapMethod<Object?, Object?>('edit', {
            'session': editSession,
            'revision': revision,
            'request': edit.id,
            'patches': TextChanges.patches(edit.change),
            'selection': [
              edit.selection.baseOffset,
              edit.selection.extentOffset,
            ],
            'composing': [edit.composing.start, edit.composing.end],
          })
          .then((result) {
            if (session != editSession || _inFlightRequest != edit.id) return;
            if (result?['applied'] == false) {
              _inFlightRequest = null;
              _retryAfterRevision = result!['revision'] as int;
              _sendNextEdit();
            }
            // Successful commands are removed by their ordered event, not by the
            // RPC response, so later local edits always use the confirmed revision.
          })
          .catchError((Object error) {
            if (session != editSession) return;
            _fail('edit: $error');
          }),
    );
  }

  TextEditingDelta _delta(
    TextEditingValue before,
    List<Object?> patches,
    TextSelection selection,
    TextRange composing,
  ) {
    final edit = CompactEdit.coalesce(before.text, patches);
    if (edit == null) {
      return TextEditingDeltaNonTextUpdate(
        oldText: before.text,
        selection: selection,
        composing: composing,
      );
    }
    if (edit.start == edit.end) {
      return TextEditingDeltaInsertion(
        oldText: before.text,
        textInserted: edit.text,
        insertionOffset: edit.start,
        selection: selection,
        composing: composing,
      );
    }
    if (edit.text.isEmpty) {
      return TextEditingDeltaDeletion(
        oldText: before.text,
        deletedRange: TextRange(start: edit.start, end: edit.end),
        selection: selection,
        composing: composing,
      );
    }
    return TextEditingDeltaReplacement(
      oldText: before.text,
      replacementText: edit.text,
      replacedRange: TextRange(start: edit.start, end: edit.end),
      selection: selection,
      composing: composing,
    );
  }

  void _deliver(TextEditingDelta delta, TextEditingValue before) {
    final active = client;
    if (active is DeltaTextInputClient) {
      active.updateEditingValueWithDeltas([delta]);
    } else if (active != null) {
      active.updateEditingValue(delta.apply(before));
    } else {
      if (_document != null) _document!.value = delta.apply(before);
    }
  }

  void receive(Map<Object?, Object?> event) {
    if (event['session'] != session || _closed) return;
    final from = (event['from'] as num).toInt();
    final to = (event['to'] as num).toInt();
    if (to <= revision) return;
    if (from != revision || to != from + 1) {
      _fail('Non-contiguous revision: local=$revision incoming=$from..$to');
      return;
    }
    final appRequest = event['appRequest'];
    final acknowledgedSelection =
        appRequest != null &&
            _pending.isNotEmpty &&
            _pending.first.id == appRequest
        ? _pending.first.selection
        : null;
    final s = event['selection'] as List;
    final c = event['composing'] as List;
    final selection = TextSelection(
      baseOffset: (s[0] as num).toInt(),
      extentOffset: (s[1] as num).toInt(),
      affinity: event['affinity'] == 'upstream'
          ? TextAffinity.upstream
          : event['affinity'] == 'downstream'
          ? TextAffinity.downstream
          : acknowledgedSelection?.affinity ?? TextAffinity.downstream,
    );
    final composing = TextRange(
      start: (c[0] as num).toInt(),
      end: (c[1] as num).toInt(),
    );
    final before = nativeValue!;
    final patches = event['patches'] as List;
    final nativeDelta = _delta(before, patches, selection, composing);
    _receiving = true;
    try {
      if (_pending.isEmpty) {
        // Keep the normal typing path to one full-string application.
        if (client == null) {
          nativeValue = nativeDelta.apply(before);
          if (_document != null) _document!.value = nativeValue!;
        } else {
          _deliver(nativeDelta, before);
          nativeValue = client!.currentTextEditingValue!.copyWith(
            selection: selection,
            composing: composing,
          );
        }
        _projectedValue = nativeValue;
      } else {
        final previousProjection = _projectedValue!;
        nativeValue = nativeDelta.apply(before);
        if (appRequest != null) {
          if (_pending.first.id != appRequest ||
              _inFlightRequest != appRequest) {
            throw StateError('Out-of-order app edit acknowledgement');
          }
          _pending.removeAt(0);
          _inFlightRequest = null;
        } else {
          var remote = TextChanges.fromPatches(patches);
          for (final pending in _pending) {
            final local = pending.change;
            pending.change = remote.transform(local, true);
            remote = local.transform(remote, false);
            pending.selection = TextChanges.mapSelection(
              pending.selection,
              remote,
            );
            pending.composing = TextChanges.mapComposing(
              pending.composing,
              remote,
            );
          }
        }
        var combined = quill.Delta();
        for (final pending in _pending) {
          combined = combined.compose(pending.change);
        }
        final projected = _pending.isEmpty
            ? nativeValue!
            : TextEditingValue(
                text: TextChanges.apply(nativeValue!.text, combined),
                selection: _pending.last.selection,
                composing: _pending.last.composing,
              );
        if (projected != previousProjection) {
          final visibleChange = TextChanges.diff(previousProjection, projected);
          _deliver(
            _delta(
              previousProjection,
              TextChanges.patches(visibleChange),
              projected.selection,
              projected.composing,
            ),
            previousProjection,
          );
        }
        _projectedValue = projected;
      }
      revision = to;
      if (patches.isNotEmpty) _layout?.invalidate();
    } finally {
      _receiving = false;
    }
    _signal();
    _sendNextEdit();
    onChange?.call();
  }
}

class _MirrorCodeConnection implements CodeInputConnection {
  _MirrorCodeConnection(this.owner, this.client);
  final NativeMessageInput owner;
  final DeltaTextInputClient client;
  bool _attached = true;
  @override
  bool get attached => _attached && identical(owner.client, client);
  @override
  void setEditingState(TextEditingValue value) => owner.setEditingState(value);
  @override
  void updateConfig(TextInputConfiguration configuration) =>
      owner.updateConfig(configuration);
  @override
  void setComposingRect(Rect rect) => owner.setComposingRect(rect);
  @override
  void setCaretRect(Rect rect) => owner.setCaretRect(rect);
  @override
  void setEditableSizeAndTransform(Size size, Matrix4 transform) {
    owner.refreshNavigationLayout();
    owner.setEditableSizeAndTransform(size, transform);
  }

  @override
  void show() => owner.show();
  @override
  void close() {
    _attached = false;
    owner.detach(client);
  }
}

class _AppEdit {
  _AppEdit(this.id, this.change, this.selection, this.composing);
  final int id;
  quill.Delta change;
  TextSelection selection;
  TextRange composing;
}

class _InputRouter {
  _InputRouter(this.channel) {
    channel.setMethodCallHandler((call) {
      final args = call.arguments;
      final target = args is Map ? controls[args['session']] : foreground;
      if (target == null) throw StateError('Unknown native document');
      return target._handle(call);
    });
  }
  static final _routers = <(String, BinaryMessenger), _InputRouter>{};
  static int _nextSession = 0;
  static _InputRouter forChannel(MethodChannel channel) => _routers.putIfAbsent(
    (channel.name, channel.binaryMessenger),
    () => _InputRouter(channel),
  );
  final MethodChannel channel;
  final controls = <String, NativeMessageInput>{};
  NativeMessageInput? foreground;
  String register(NativeMessageInput control) {
    final id = 'document-${++_nextSession}';
    controls[id] = control;
    return id;
  }

  void remove(String id) {
    final removed = controls.remove(id);
    if (identical(removed, foreground)) foreground = null;
  }
}

class _OwnerOperation {
  _OwnerOperation(this.input);
  final NativeMessageInput input;
  bool active = true;
}
