import 'dart:async';
import 'dart:isolate';

/// One preview query decodes and matches its pages sequentially. Closing the
/// query also stops a CPU-bound page, even if it has not returned to Dart's
/// event loop yet. No database connection or transaction is sent here.
final class ConversationFindWorker {
  ReceivePort? _port;
  StreamIterator<dynamic>? _replies;
  Isolate? _isolate;
  SendPort? _requests;
  Future<void> _pending = Future.value();
  bool _closed = false;

  bool get isCurrent => !_closed;

  Future<R?> run<Q, R extends Object>(R Function(Q) callback, Q input) {
    final result = _pending.then((_) => _run(callback, input));
    _pending = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) => close(),
    );
    return result;
  }

  Future<R?> _run<Q, R extends Object>(R Function(Q) callback, Q input) async {
    if (_closed) return null;
    if (_requests == null) {
      final port = _port = ReceivePort();
      _replies = StreamIterator(port);
      final child = await Isolate.spawn(
        _serve,
        port.sendPort,
        onError: port.sendPort,
        onExit: port.sendPort,
        debugName: 'minimap search',
      );
      if (_closed) {
        child.kill(priority: Isolate.immediate);
        return null;
      }
      _isolate = child;
      _requests = await _receive<SendPort>();
    }
    if (_closed) return null;
    _requests!.send(_bind(callback, input));
    return _receive<R>();
  }

  // Keep the closure's capture limited to the sendable callback and input.
  static R Function() _bind<Q, R>(R Function(Q) callback, Q input) =>
      () => callback(input);

  static void _serve(SendPort replies) {
    final requests = ReceivePort();
    replies.send(requests.sendPort);
    requests.cast<Object Function()>().listen((job) => replies.send(job()));
  }

  Future<R?> _receive<R extends Object>() async {
    final replies = _replies!;
    final hasReply = await replies.moveNext();
    if (_closed) return null;
    final reply = hasReply ? replies.current : null;
    if (reply is R) return reply;
    if (reply case [final String error, final String stack]) {
      Error.throwWithStackTrace(
        RemoteError(error, stack),
        StackTrace.fromString(stack),
      );
    }
    throw StateError('Minimap search worker exited without a result');
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _port?.close();
  }
}
