import 'dart:async';

import 'package:flutter/services.dart';

import '../models/terminal_runtime_state.dart';

class TerminalNativeBridgeException implements Exception {
  const TerminalNativeBridgeException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  factory TerminalNativeBridgeException.fromPlatformException(
    PlatformException error,
  ) {
    return TerminalNativeBridgeException(
      code: error.code,
      message: error.message ?? error.code,
    );
  }

  @override
  String toString() => 'TerminalNativeBridgeException($code, $message)';
}

class TerminalNativeBridge {
  TerminalNativeBridge({
    MethodChannel methodChannel = const MethodChannel('kelivo.terminal/ios'),
  }) : _methodChannel = methodChannel;

  final MethodChannel _methodChannel;

  Future<TerminalRuntimeState> getRuntimeStatus() async {
    try {
      final payload = await _methodChannel.invokeMapMethod<Object?, Object?>(
        'getRuntimeStatus',
        const <String, Object?>{},
      );
      if (payload == null) {
        throw const TerminalNativeBridgeException(
          code: 'empty_status',
          message: 'Native terminal status response was empty.',
        );
      }
      return TerminalRuntimeState.fromMap(payload);
    } on PlatformException catch (error) {
      throw TerminalNativeBridgeException.fromPlatformException(error);
    }
  }

  Future<void> installRuntime({required String manifestUrl}) async {
    try {
      await _methodChannel.invokeMethod<Object?>('installRuntime', {
        'manifestUrl': manifestUrl,
      });
    } on PlatformException catch (error) {
      throw TerminalNativeBridgeException.fromPlatformException(error);
    }
  }

  Future<String> getDiagnosticLog() async {
    try {
      final payload = await _methodChannel.invokeMapMethod<Object?, Object?>(
        'getDiagnosticLog',
        const <String, Object?>{},
      );
      return payload?['text']?.toString() ?? '';
    } on PlatformException catch (error) {
      throw TerminalNativeBridgeException.fromPlatformException(error);
    }
  }

  Future<void> appendDiagnostic(String message) async {
    try {
      await _methodChannel.invokeMethod<Object?>('appendDiagnostic', {
        'message': message,
      });
    } on PlatformException {
      // Diagnostic logging must never block the user action it is observing.
    }
  }

  Future<List<Map<Object?, Object?>>> drainEvents() async {
    try {
      final payload = await _methodChannel.invokeListMethod<Object?>(
        'drainEvents',
        const <String, Object?>{},
      );
      if (payload == null) return const [];
      return payload.whereType<Map<Object?, Object?>>().toList(growable: false);
    } on PlatformException catch (error) {
      throw TerminalNativeBridgeException.fromPlatformException(error);
    }
  }

  Future<void> startSession({
    required String sessionId,
    required int cols,
    required int rows,
  }) async {
    try {
      await _methodChannel.invokeMethod<Object?>('startSession', {
        'sessionId': sessionId,
        'cols': cols,
        'rows': rows,
        'cwd': '/home/kelivo',
        'env': const <String, String>{
          'TERM': 'xterm-256color',
          'LANG': 'en_US.UTF-8',
        },
      });
    } on PlatformException catch (error) {
      throw TerminalNativeBridgeException.fromPlatformException(error);
    }
  }

  Future<void> writeSession({
    required String sessionId,
    required String data,
  }) async {
    try {
      await _methodChannel.invokeMethod<Object?>('writeSession', {
        'sessionId': sessionId,
        'data': data,
      });
    } on PlatformException catch (error) {
      throw TerminalNativeBridgeException.fromPlatformException(error);
    }
  }

  Future<void> resizeSession({
    required String sessionId,
    required int cols,
    required int rows,
  }) async {
    try {
      await _methodChannel.invokeMethod<Object?>('resizeSession', {
        'sessionId': sessionId,
        'cols': cols,
        'rows': rows,
      });
    } on PlatformException catch (error) {
      throw TerminalNativeBridgeException.fromPlatformException(error);
    }
  }

  Future<void> stopSession({required String sessionId}) async {
    try {
      await _methodChannel.invokeMethod<Object?>('stopSession', {
        'sessionId': sessionId,
      });
    } on PlatformException catch (error) {
      throw TerminalNativeBridgeException.fromPlatformException(error);
    }
  }
}
