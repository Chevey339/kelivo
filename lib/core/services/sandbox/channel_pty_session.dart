import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

/// [PtySession] backed by `pty` / `ptyExit` events on [WorkspaceChannel].
class ChannelPtySession implements PtySession {
  ChannelPtySession({
    required WorkspaceChannel channel,
    required this.sessionId,
  }) : _channel = channel {
    _subscription = channel.events.listen(_onEvent);
  }

  final WorkspaceChannel _channel;
  final String sessionId;
  final StreamController<Uint8List> _output =
      StreamController<Uint8List>.broadcast();
  final Completer<int> _exit = Completer<int>();
  late final StreamSubscription<Map<String, Object?>> _subscription;

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  Future<void> write(Uint8List data) {
    return _channel.ptyWrite(sessionId: sessionId, data: data);
  }

  @override
  Future<void> resize(int cols, int rows) {
    return _channel.ptyResize(sessionId: sessionId, cols: cols, rows: rows);
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Future<void> close() async {
    await _channel.ptyClose(sessionId);
  }

  void _onEvent(Map<String, Object?> event) {
    if (event['sessionId']?.toString() != sessionId) return;
    switch (event['type']) {
      case 'pty':
        if (!_output.isClosed) {
          _output.add(_ptyBytes(event['data']));
        }
      case 'ptyExit':
        final code = _ptyInt(event['exitCode']) ?? -1;
        if (!_exit.isCompleted) {
          _exit.complete(code);
        }
        unawaited(_detach());
    }
  }

  Future<void> _detach() async {
    await _subscription.cancel();
    if (!_output.isClosed) {
      await _output.close();
    }
  }
}

int? _ptyInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

Uint8List _ptyBytes(Object? data) {
  if (data is Uint8List) return data;
  if (data is List<int>) return Uint8List.fromList(data);
  return Uint8List(0);
}
