import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// TLS with the original hostname and a cancelable, already validated TCP peer.
Future<ConnectionTask<Socket>> startPinnedTlsSocket(
  InternetAddress address,
  int port,
  String hostname,
) async {
  final tcp = await RawSocket.startConnect(address, port);
  RawSocket? pending;
  final cancelled = Completer<Socket>();
  final secure = tcp.socket.then((socket) async {
    pending = socket;
    try {
      if (cancelled.isCompleted) {
        throw const SocketException('TLS connection cancelled');
      }
      final tls = await RawSecureSocket.secure(socket, host: hostname);
      if (cancelled.isCompleted) {
        unawaited(tls.close());
        throw const SocketException('TLS connection cancelled');
      }
      return _TlsSocket(socket, tls);
    } catch (_) {
      unawaited(socket.close());
      rethrow;
    }
  });
  return ConnectionTask.fromSocket(Future.any([secure, cancelled.future]), () {
    if (cancelled.isCompleted) return;
    cancelled.completeError(const SocketException('TLS connection cancelled'));
    tcp.cancel();
    // SecureSocket.startConnect can cancel TCP setup but no longer owns a
    // cancelable connection task once the TLS handshake has started.
    final socket = pending;
    if (socket != null) unawaited(socket.close());
  });
}

/// Adapts a handshaken raw TLS stream for dart:io's HTTP parser and writer.
final class _TlsSocket extends StreamView<Uint8List> implements Socket {
  _TlsSocket(RawSocket tcp, RawSecureSocket raw)
    : this._(tcp, raw, StreamController());

  _TlsSocket._(this._tcp, this._raw, this._input) : super(_input.stream) {
    _raw
      ..readEventsEnabled = false
      ..writeEventsEnabled = false;
    _input
      ..onListen = _enableRead
      ..onResume = _enableRead
      ..onPause = _disableRead
      ..onCancel = _disableRead;
    _raw.listen(
      _onEvent,
      onError: (Object error, StackTrace stack) {
        if (!_input.isClosed) _input.addError(error, stack);
        destroy();
      },
      onDone: destroy,
    );
  }

  final RawSocket _tcp;
  final RawSecureSocket _raw;
  final StreamController<Uint8List> _input;
  late final IOSink _output = IOSink(_TlsWriter(this));
  Completer<void>? _writable;
  bool _closed = false;

  void _enableRead() {
    if (!_closed) _raw.readEventsEnabled = true;
  }

  void _disableRead() {
    if (!_closed) _raw.readEventsEnabled = false;
  }

  void _onEvent(RawSocketEvent event) {
    if (_closed) return;
    if (event == RawSocketEvent.read) {
      if (_input.isClosed) return;
      final data = _raw.read();
      if (data != null) _input.add(data);
    } else if (event == RawSocketEvent.write) {
      _wakeWriter();
    } else if (event == RawSocketEvent.readClosed) {
      unawaited(_input.close());
    } else if (event == RawSocketEvent.closed) {
      destroy();
    }
  }

  void _wakeWriter() {
    final waiting = _writable;
    _writable = null;
    waiting?.complete();
  }

  Future<void> _send(List<int> bytes) async {
    var offset = 0;
    while (offset < bytes.length) {
      if (_closed) throw const SocketException('TLS connection closed');
      offset += _raw.write(bytes, offset);
      if (offset < bytes.length) {
        final ready = _writable = Completer<void>();
        _raw.writeEventsEnabled = true;
        await ready.future;
      }
    }
  }

  @override
  void destroy() {
    if (_closed) return;
    _closed = true;
    _wakeWriter();
    unawaited(_raw.close());
    unawaited(_tcp.close());
    unawaited(_input.close());
  }

  @override
  InternetAddress get address => _raw.address;
  @override
  InternetAddress get remoteAddress => _raw.remoteAddress;
  @override
  int get port => _raw.port;
  @override
  int get remotePort => _raw.remotePort;
  @override
  bool setOption(SocketOption option, bool enabled) =>
      _raw.setOption(option, enabled);
  @override
  Uint8List getRawOption(RawSocketOption option) => _raw.getRawOption(option);
  @override
  void setRawOption(RawSocketOption option) => _raw.setRawOption(option);
  @override
  Encoding get encoding => _output.encoding;
  @override
  set encoding(Encoding value) => _output.encoding = value;
  @override
  void add(List<int> data) => _output.add(data);
  @override
  Future<void> addStream(Stream<List<int>> stream) => _output.addStream(stream);
  @override
  Future<void> flush() => _output.flush();
  @override
  Future<void> close() => _output.close();
  @override
  Future<void> get done => _output.done;
  @override
  void write(Object? object) => _output.write(object);
  @override
  void writeln([Object? object = '']) => _output.writeln(object);
  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _output.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => _output.writeCharCode(charCode);
  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      throw UnsupportedError('Cannot send errors on a socket');

  // Socket has a private detach method. This adapter already owns TLS.
  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _TlsWriter implements StreamConsumer<List<int>> {
  _TlsWriter(this.socket);

  final _TlsSocket socket;

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      await socket._send(chunk);
    }
  }

  @override
  Future<void> close() async {
    if (!socket._closed) socket._raw.shutdown(SocketDirection.send);
  }
}
