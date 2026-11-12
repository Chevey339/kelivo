import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';

import 'message_undo_history.dart';
import 'native_message_input.dart';

typedef MessageInputCommand =
    FutureOr<void> Function(String command, TextEditingValue value);

/// Owns input independently of the currently visible editor. Consumers drain
/// before saving/replacing a document; disposal retains accepted work until it
/// reaches the model. A mode change retires input without clearing its history.
class MessageEditingController extends TextEditingController {
  MessageEditingController({
    super.text,
    bool? nativeInputEnabled,
    this.inputChannel = const MethodChannel('kelivo/native_message_input'),
  }) : nativeInputEnabled = nativeInputEnabled ?? Platform.isAndroid {
    if (this.nativeInputEnabled) {
      history = MessageUndoHistory(
        this,
        onTriggered: userEdits.notifyListeners,
      );
    }
  }

  final bool nativeInputEnabled;
  @visibleForTesting
  final MethodChannel inputChannel;
  MessageUndoHistory? history;
  final userEdits = ChangeNotifier();
  NativeMessageInput? _input;
  Future<void>? _retiring;
  Future<void>? _disposal;
  bool _disposing = false;
  bool _retired = false;
  int _pauseRevision = 0;
  int _inputGeneration = 0;
  MessageInputCommand? _ownerCommand;
  FutureOr<void> Function(KeyboardInsertedContent)? _ownerContent;
  String _enter = 'newline';
  List<String> _commands = const ['undo', 'redo', 'paste'];
  static final _workZone = Object();
  final _work = <Future<void>>{};

  bool get isDraining => _retiring != null || _disposing;
  bool get isInputPaused => isDraining || _retired;
  bool get hasNativeInput => _input?.isOpen ?? false;
  bool get needsInputDrain => hasNativeInput || isDraining || _work.isNotEmpty;
  int get inputGeneration => _inputGeneration;
  CodeInputConnectionFactory? get inputConnectionFactory =>
      nativeInputEnabled ? _openConnection : null;

  CodeInputConnection _openConnection(
    DeltaTextInputClient client,
    TextInputConfiguration configuration,
  ) {
    if (isInputPaused) {
      throw StateError('Resume the document before attaching input');
    }
    final input = _input ??= NativeMessageInput(channel: inputChannel)
      ..bindDocument(this);
    _configure(input);
    return input.openConnection(client, configuration);
  }

  /// These callbacks belong to the document owner. They must register durable
  /// work before returning and must not await this document's own input barrier.
  void configureOwner({
    MessageInputCommand? onCommand,
    FutureOr<void> Function(KeyboardInsertedContent)? onContent,
    String enter = 'newline',
    List<String> commands = const ['undo', 'redo', 'paste'],
  }) {
    _ownerCommand = onCommand;
    _ownerContent = onContent;
    _enter = enter;
    _commands = List.of(commands);
    final input = _input;
    if (input != null && !isDraining) _configure(input);
  }

  void _configure(NativeMessageInput input) {
    final ownerCommand = _ownerCommand;
    input.onCommand = (command, snapshot) =>
        _trackWork(() => _executeCommand(command, snapshot, ownerCommand));
    final content = _ownerContent;
    input.onContent = content == null
        ? null
        : (value) => _trackWork(() => content(value));
    unawaited(input.configureHardware(enter: _enter, commands: _commands));
  }

  Future<void> _executeCommand(
    String command,
    TextEditingValue snapshot,
    MessageInputCommand? ownerCommand,
  ) async {
    switch (command) {
      case 'undo':
        history?.undo();
      case 'redo':
        history?.redo();
      default:
        if (ownerCommand != null) {
          await ownerCommand(command, snapshot);
        } else if (command == 'paste') {
          final ClipboardData? data;
          try {
            data = await Clipboard.getData(Clipboard.kTextPlain);
          } on PlatformException {
            // An unavailable clipboard must not invalidate the input session.
            return;
          }
          if (data?.text case final text?) {
            final range = selection.isValid
                ? selection
                : TextSelection.collapsed(offset: this.text.length);
            value = value
                .replaced(range, text)
                .copyWith(composing: TextRange.empty);
          }
        }
    }
  }

  Future<void> performCommand(String command) async {
    if (isInputPaused) throw StateError('The document is paused');
    final input = _input;
    if (input?.isOpen ?? false) {
      await input!.performCommand(command);
    } else {
      final owner = _ownerCommand;
      await _trackWork(() => _executeCommand(command, value, owner));
    }
  }

  Future<void> insertContent(KeyboardInsertedContent content) {
    if (isInputPaused) throw StateError('The document is paused');
    final owner = _ownerContent;
    return owner == null ? Future.value() : _trackWork(() => owner(content));
  }

  Future<void> _trackWork(FutureOr<void> Function() callback) {
    final operation = _DocumentWork(this);
    final complete = Completer<void>();
    _work.add(complete.future);
    unawaited(complete.future.catchError((Object _) {}));
    unawaited(() async {
      try {
        await runZoned(callback, zoneValues: {_workZone: operation});
        complete.complete();
      } catch (error, stack) {
        complete.completeError(error, stack);
      } finally {
        operation.active = false;
        _work.remove(complete.future);
      }
    }());
    return complete.future;
  }

  bool get _insideWork {
    final operation = Zone.current[_workZone];
    return operation is _DocumentWork &&
        operation.active &&
        identical(operation.document, this);
  }

  void _checkReentry() {
    if (_insideWork) {
      throw StateError(
        'Use the command value instead of awaiting its own document',
      );
    }
  }

  Future<TextEditingValue> flushInput() async {
    _checkReentry();
    if (_retiring case final retiring?) {
      await retiring;
      return value;
    }
    while (_work.isNotEmpty) {
      await Future.wait(List.of(_work));
    }
    final flushed = await _input?.flush() ?? value;
    // A retirement may have started while the flush was in flight. Wait for
    // the model's closing reference to be released as well as the native RPC.
    if (_retiring case final retiring?) {
      await retiring;
      return value;
    }
    return flushed;
  }

  Future<void> retireInput() {
    _checkReentry();
    _pauseRevision++;
    return _retireInput();
  }

  /// A renderer handoff may resume input only if no consumer requested a
  /// lasting pause before or during it (for example Save or draft replacement).
  Future<void> handoffInput() async {
    _checkReentry();
    final resume = !isInputPaused;
    final revision = _pauseRevision;
    await _retireInput();
    if (resume && revision == _pauseRevision && !_disposing) resumeInput();
  }

  Future<void> _retireInput() {
    final existing = _retiring;
    if (existing != null) return existing;
    final input = _input;
    if (input == null && _work.isEmpty) {
      if (nativeInputEnabled && !_retired) {
        _retired = true;
        notifyListeners();
      }
      return Future.value();
    }
    _retired = true;
    final completer = Completer<void>();
    _retiring = completer.future;
    // close detaches synchronously, before a rebuilding renderer can submit
    // another UI edit. The model and owner remain alive through the barrier.
    final closing = input?.close();
    notifyListeners();
    unawaited(() async {
      try {
        await closing;
        while (_work.isNotEmpty) {
          await Future.wait(List.of(_work));
        }
        _input = null;
        _inputGeneration++;
        _retiring = null;
        notifyListeners();
        completer.complete();
      } catch (error, stack) {
        // Retain the model/input on failure instead of discarding accepted work.
        _retiring = null;
        completer.completeError(error, stack);
      }
    }());
    return completer.future;
  }

  /// A completed retirement stays paused through Save/pop animations. Only the
  /// owner that keeps editing (a new draft or renderer handoff) resumes it.
  void resumeInput() {
    if (isDraining || !_retired) return;
    _retired = false;
    notifyListeners();
  }

  void resetHistory() => history?.reset();

  @override
  set value(TextEditingValue next) {
    if (_input?.acceptsModelWrite == false && !_insideWork) {
      throw StateError('Wait for accepted input before replacing the document');
    }
    super.value = next;
  }

  /// Includes the last accepted native edits. Callers that save on teardown
  /// await this future before taking their final persistent snapshot.
  Future<void> disposeAfterInput() => _disposal ??= _finishDisposal();

  Future<void> _finishDisposal() async {
    _disposing = true;
    await retireInput();
    history?.dispose();
    userEdits.dispose();
    super.dispose();
  }

  @override
  void dispose() {
    if (_input == null && _work.isEmpty && !_disposing) {
      _disposing = true;
      history?.dispose();
      userEdits.dispose();
      super.dispose();
      _disposal = Future.value();
      return;
    }
    unawaited(
      disposeAfterInput().catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack),
        );
      }),
    );
  }
}

/// Plain controllers in other editors/tests retain their synchronous behavior.
extension MessageInputLifecycle on TextEditingController {
  Future<TextEditingValue> flushMessageInput() =>
      this is MessageEditingController
      ? (this as MessageEditingController).flushInput()
      : Future.value(value);

  Future<void> retireMessageInput() => this is MessageEditingController
      ? (this as MessageEditingController).retireInput()
      : Future.value();
}

class _DocumentWork {
  _DocumentWork(this.document);
  final MessageEditingController document;
  bool active = true;
}
