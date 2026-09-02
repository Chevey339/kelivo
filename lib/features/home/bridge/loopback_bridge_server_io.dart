import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'kelivo_bridge_facade.dart';
import 'room_turn.dart';

final class LoopbackBridgeServer {
  factory LoopbackBridgeServer({
    required KelivoBridgeApi facade,
    required String secret,
    int port = 0,
    int maxBodyBytes = 1 << 20,
  }) => LoopbackBridgeServer._(facade, secret, port, maxBodyBytes);

  LoopbackBridgeServer._(
    this._facade,
    this._secret,
    this._port,
    this._maxBodyBytes,
  ) {
    if (_secret.isEmpty) throw ArgumentError.value(_secret, 'secret');
    RangeError.checkValueInInterval(_port, 0, 65535, 'port');
    RangeError.checkValueInInterval(_maxBodyBytes, 1, 16 << 20, 'maxBodyBytes');
  }

  final KelivoBridgeApi _facade;
  final String _secret;
  final int _port;
  final int _maxBodyBytes;
  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;

  int? get boundPort => _server?.port;

  Future<int> start() async {
    final existing = _server;
    if (existing != null) return existing.port;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      throw UnsupportedError('desktop_bridge_only');
    }
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      _port,
      shared: false,
    );
    if (server.address.address != InternetAddress.loopbackIPv4.address) {
      await server.close(force: true);
      throw StateError('bridge_non_loopback_bind');
    }
    _server = server;
    _subscription = server.listen(
      (request) => unawaited(_handle(request)),
      onError: (_) {},
      cancelOnError: false,
    );
    return server.port;
  }

  Future<void> stop() async {
    final subscription = _subscription;
    final server = _server;
    _subscription = null;
    _server = null;
    await subscription?.cancel();
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (!_authorized(request)) {
        await _json(
          request.response,
          HttpStatus.unauthorized,
          <String, Object?>{'error_code': 'UNAUTHORIZED'},
        );
        return;
      }
      final segments = request.uri.pathSegments;
      if (request.method == 'GET' &&
          _sameSegments(segments, const ['bridge', 'v1', 'health'])) {
        await _json(
          request.response,
          HttpStatus.ok,
          (await _facade.health()).toJson(),
        );
        return;
      }
      if (request.method == 'POST' &&
          _sameSegments(segments, const ['bridge', 'v1', 'turns'])) {
        final body = await _readJsonObject(request);
        final result = await _facade.sendTurn(
          BridgeSendTurnRequest.fromJson(body),
        );
        final statusCode = switch (result.status) {
          BridgeSendTurnStatus.busy ||
          BridgeSendTurnStatus.idempotencyConflict => HttpStatus.conflict,
          BridgeSendTurnStatus.failed
              when result.errorCode == 'NOT_ACTIVE_CONVERSATION' ||
                  result.errorCode == 'UNSUPPORTED_TEMPORARY_CONVERSATION' =>
            HttpStatus.unprocessableEntity,
          _ => HttpStatus.ok,
        };
        await _json(request.response, statusCode, result.toJson());
        return;
      }
      if (segments.length == 4 &&
          segments[0] == 'bridge' &&
          segments[1] == 'v1' &&
          segments[2] == 'conversations' &&
          request.method == 'GET') {
        final session = await _facade.getSession(segments[3]);
        if (session == null) {
          await _notFound(request.response);
        } else {
          await _json(request.response, HttpStatus.ok, session.toJson());
        }
        return;
      }
      if (segments.length == 5 &&
          segments[0] == 'bridge' &&
          segments[1] == 'v1' &&
          segments[2] == 'conversations' &&
          segments[4] == 'messages' &&
          request.method == 'GET') {
        final page = await _facade.getMessages(
          segments[3],
          after: request.uri.queryParameters['after'],
        );
        if (page == null) {
          await _notFound(request.response);
        } else {
          await _json(request.response, HttpStatus.ok, <String, Object?>{
            'messages': [
              for (final message in page.messages)
                <String, Object?>{
                  'id': message.id,
                  'conversation_id': message.conversationId,
                  'role': message.role,
                  'content': message.content,
                  'created_at': message.timestamp.toUtc().toIso8601String(),
                  'is_streaming': message.isStreaming,
                  'group_id': message.groupId,
                  'version': message.version,
                },
            ],
            'next_after': page.nextAfter,
          });
        }
        return;
      }
      await _notFound(request.response);
    } on _BodyTooLarge {
      await _json(
        request.response,
        HttpStatus.requestEntityTooLarge,
        <String, Object?>{'error_code': 'BODY_TOO_LARGE'},
      );
    } on FormatException catch (error) {
      await _json(request.response, HttpStatus.badRequest, <String, Object?>{
        'error_code': 'INVALID_REQUEST',
        'detail': error.message,
      });
    } catch (_) {
      await _json(
        request.response,
        HttpStatus.internalServerError,
        <String, Object?>{'error_code': 'BRIDGE_INTERNAL_ERROR'},
      );
    }
  }

  bool _authorized(HttpRequest request) {
    final bearer = request.headers.value(HttpHeaders.authorizationHeader);
    final candidate = bearer?.startsWith('Bearer ') == true
        ? bearer!.substring('Bearer '.length)
        : request.headers.value('x-kelivo-bridge-secret');
    if (candidate == null) return false;
    final expectedBytes = utf8.encode(_secret);
    final candidateBytes = utf8.encode(candidate);
    var mismatch = expectedBytes.length ^ candidateBytes.length;
    final length = expectedBytes.length > candidateBytes.length
        ? expectedBytes.length
        : candidateBytes.length;
    for (var i = 0; i < length; i++) {
      final expected = i < expectedBytes.length ? expectedBytes[i] : 0;
      final actual = i < candidateBytes.length ? candidateBytes[i] : 0;
      mismatch |= expected ^ actual;
    }
    return mismatch == 0;
  }

  Future<Map<String, Object?>> _readJsonObject(HttpRequest request) async {
    final declaredLength = request.contentLength;
    if (declaredLength > _maxBodyBytes) {
      await request.drain<void>();
      throw const _BodyTooLarge();
    }
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    var tooLarge = false;
    await for (final chunk in request) {
      length += chunk.length;
      if (length > _maxBodyBytes) {
        tooLarge = true;
      } else if (!tooLarge) {
        bytes.add(chunk);
      }
    }
    if (tooLarge) throw const _BodyTooLarge();
    final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (decoded is! Map) throw const FormatException('invalid_json_object');
    return Map<String, Object?>.from(decoded);
  }

  static bool _sameSegments(List<String> actual, List<String> expected) {
    if (actual.length != expected.length) return false;
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != expected[i]) return false;
    }
    return true;
  }

  static Future<void> _notFound(HttpResponse response) => _json(
    response,
    HttpStatus.notFound,
    <String, Object?>{'error_code': 'NOT_FOUND'},
  );

  static Future<void> _json(
    HttpResponse response,
    int statusCode,
    Map<String, Object?> body,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}

final class _BodyTooLarge implements Exception {
  const _BodyTooLarge();
}
