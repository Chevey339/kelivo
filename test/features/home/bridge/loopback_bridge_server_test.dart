import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/features/home/bridge/kelivo_bridge_facade.dart';
import 'package:Kelivo/features/home/bridge/loopback_bridge_server.dart';
import 'package:Kelivo/features/home/bridge/room_turn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const secret = 'local-test-secret';

  test('server binds loopback and rejects unauthenticated requests', () async {
    final server = LoopbackBridgeServer(
      facade: _TestBridgeApi(),
      secret: secret,
      port: 0,
    );
    final port = await server.start();
    try {
      final unauthorized = await _request(port, 'GET', '/bridge/v1/health');
      expect(unauthorized.statusCode, HttpStatus.unauthorized);

      final health = await _request(
        port,
        'GET',
        '/bridge/v1/health',
        secret: secret,
      );
      expect(health.statusCode, HttpStatus.ok);
      expect(health.json['protocol_version'], 'KELIVO_NATIVE_BRIDGE_P0');
    } finally {
      await server.stop();
    }
  });

  test('turn endpoint returns only after facade terminal result', () async {
    final terminal = Completer<BridgeSendTurnResult>();
    final api = _TestBridgeApi(send: (_) => terminal.future);
    final server = LoopbackBridgeServer(facade: api, secret: secret, port: 0);
    final port = await server.start();
    try {
      var responseCompleted = false;
      final responseFuture = _request(
        port,
        'POST',
        '/bridge/v1/turns',
        secret: secret,
        body: _turnBody(),
      ).whenComplete(() => responseCompleted = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(responseCompleted, isFalse);
      terminal.complete(
        const BridgeSendTurnResult(
          status: BridgeSendTurnStatus.completed,
          roomEventId: 'event-1',
          conversationId: 'conversation-1',
          nativeUserMessageId: 'user-1',
          nativeAssistantMessageId: 'assistant-1',
          generationRunId: 'run-1',
          assistantContent: 'final answer',
          deduplicated: false,
        ),
      );

      final response = await responseFuture;
      expect(response.statusCode, HttpStatus.ok);
      expect(response.json['status'], 'completed');
      expect(response.json['assistant_content'], 'final answer');
      expect(api.sendCount, 1);
    } finally {
      await server.stop();
    }
  });

  test('oversized request is rejected before facade dispatch', () async {
    final api = _TestBridgeApi();
    final server = LoopbackBridgeServer(
      facade: api,
      secret: secret,
      port: 0,
      maxBodyBytes: 32,
    );
    final port = await server.start();
    try {
      final response = await _request(
        port,
        'POST',
        '/bridge/v1/turns',
        secret: secret,
        body: <String, Object?>{'payload': 'x' * 128},
      );
      expect(response.statusCode, HttpStatus.requestEntityTooLarge);
      expect(api.sendCount, 0);
    } finally {
      await server.stop();
    }
  });

  test('transport restart preserves facade deduplication result', () async {
    var apiCallIsDuplicate = false;
    final api = _TestBridgeApi(
      send: (request) async => BridgeSendTurnResult(
        status: BridgeSendTurnStatus.completed,
        roomEventId: request.roomTurn.roomEventId,
        conversationId: request.conversationId,
        nativeUserMessageId: 'user-1',
        nativeAssistantMessageId: 'assistant-1',
        generationRunId: 'run-1',
        assistantContent: 'same final answer',
        deduplicated: apiCallIsDuplicate,
      ),
    );
    var server = LoopbackBridgeServer(facade: api, secret: secret, port: 0);
    var port = await server.start();
    try {
      final first = await _request(
        port,
        'POST',
        '/bridge/v1/turns',
        secret: secret,
        body: _turnBody(),
      );
      expect(first.json['deduplicated'], isFalse);
      await server.stop();

      apiCallIsDuplicate = true;
      server = LoopbackBridgeServer(facade: api, secret: secret, port: 0);
      port = await server.start();
      final duplicate = await _request(
        port,
        'POST',
        '/bridge/v1/turns',
        secret: secret,
        body: _turnBody(),
      );
      expect(duplicate.json['deduplicated'], isTrue);
      expect(duplicate.json['native_user_message_id'], 'user-1');
      expect(api.sendCount, 2);
    } finally {
      await server.stop();
    }
  });
}

Map<String, Object?> _turnBody() => <String, Object?>{
  'conversation_id': 'conversation-1',
  'idempotency_key': 'delivery-1',
  'room_event': <String, Object?>{
    'room_event_id': 'event-1',
    'room_id': 'room-1',
    'origin_system': 'test-harness',
    'origin_instance_id': 'harness-1',
    'sender': <String, Object?>{
      'id': 'human-1',
      'display_name': 'Human',
      'kind': 'human',
    },
    'created_at': '2026-08-30T12:34:56Z',
    'content': 'hello',
    'addressed_to_agent': true,
  },
};

Future<_HttpResult> _request(
  int port,
  String method,
  String path, {
  String? secret,
  Map<String, Object?>? body,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:$port$path'),
    );
    if (secret != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $secret');
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    return _HttpResult(
      response.statusCode,
      Map<String, Object?>.from(jsonDecode(text)),
    );
  } finally {
    client.close(force: true);
  }
}

final class _HttpResult {
  const _HttpResult(this.statusCode, this.json);

  final int statusCode;
  final Map<String, Object?> json;
}

final class _TestBridgeApi implements KelivoBridgeApi {
  _TestBridgeApi({this.send});

  final Future<BridgeSendTurnResult> Function(BridgeSendTurnRequest request)?
  send;
  int sendCount = 0;

  @override
  Future<BridgeHealth> health() async => const BridgeHealth(
    ready: true,
    protocolVersion: 'KELIVO_NATIVE_BRIDGE_P0',
  );

  @override
  Future<BridgeMessagePage?> getMessages(
    String conversationId, {
    String? after,
  }) async => const BridgeMessagePage(messages: [], nextAfter: null);

  @override
  Future<BridgeSession?> getSession(String conversationId) async =>
      BridgeSession(
        conversationId: conversationId,
        active: true,
        persisted: true,
        assistantId: null,
        branchRevision: const {},
      );

  @override
  Future<BridgeSendTurnResult> sendTurn(BridgeSendTurnRequest request) async {
    sendCount += 1;
    final callback = send;
    if (callback != null) return callback(request);
    return BridgeSendTurnResult(
      status: BridgeSendTurnStatus.completed,
      roomEventId: request.roomTurn.roomEventId,
      conversationId: request.conversationId,
      nativeUserMessageId: 'user-1',
      nativeAssistantMessageId: 'assistant-1',
      generationRunId: 'run-1',
      assistantContent: 'done',
      deduplicated: false,
    );
  }
}
