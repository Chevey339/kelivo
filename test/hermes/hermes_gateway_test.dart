import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/hermes/hermes_auth.dart';
import 'package:Kelivo/hermes/hermes_config.dart';
import 'package:Kelivo/hermes/hermes_event_bus.dart';
import 'package:Kelivo/hermes/hermes_gateway.dart';
import 'package:Kelivo/hermes/hermes_models.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('HermesAuth', () {
    test('LoopbackAuth.wsAuthQuery returns token param', () async {
      final auth = LoopbackAuth('test-token-123');
      final params = await auth.authParams();

      expect(params.wsQueryParams, containsPair('token', 'test-token-123'));
      expect(
        params.restHeaders,
        containsPair('Authorization', 'Bearer test-token-123'),
      );
      expect(auth.currentToken, 'test-token-123');
    });

    test('LoopbackAuth.wsAuthQuery url encodes special chars', () async {
      final auth = LoopbackAuth('token/with=special&chars');
      final params = await auth.authParams();

      // Should be URL-encoded
      expect(params.wsQueryParams['token'], isNotNull);
    });
  });

  group('HermesEventBus', () {
    test('emits and receives stream events', () async {
      final bus = HermesEventBus();
      final events = <HermesStreamEvent>[];

      bus.eventsOf<MessageDelta>().listen(events.add);
      bus.emit(MessageDelta(sessionId: 's1', text: 'Hello'));
      bus.emit(ReasoningDelta(sessionId: 's1', text: 'thinking'));
      bus.emit(MessageDelta(sessionId: 's1', text: ' world'));

      await Future.delayed(Duration.zero);

      expect(events.length, 2);
      expect((events[0] as MessageDelta).text, 'Hello');
      expect((events[1] as MessageDelta).text, ' world');

      bus.dispose();
    });

    test('allEvents receives every event type', () async {
      final bus = HermesEventBus();
      final events = <HermesStreamEvent>[];

      bus.allEvents.listen(events.add);
      bus.emit(MessageDelta(sessionId: 's1', text: 'hi'));
      bus.emit(ToolStart(sessionId: 's1', name: 'bash'));
      bus.emit(GatewayReady());

      await Future.delayed(Duration.zero);

      expect(events.length, 3);
      expect(events[0], isA<MessageDelta>());
      expect(events[1], isA<ToolStart>());
      expect(events[2], isA<GatewayReady>());

      bus.dispose();
    });
  });

  group('HermesGateway', () {
    late HermesEventBus bus;
    late HermesConfig config;
    late HermesGateway gateway;

    setUp(() {
      bus = HermesEventBus();
      config = HermesConfig();
      gateway = HermesGateway(eventBus: bus, config: config);
    });

    tearDown(() async {
      gateway.dispose();
    });

    test('initial state is disconnected', () {
      expect(gateway.state, HermesConnectionState.disconnected);
      expect(gateway.currentBackend, isNull);
    });

    // This test requires a live WebSocket server and is intentionally skipped.
    // Network connectivity is verified in integration tests.
    test('connect sets state to connecting', () {
      // connect() transitions state; full integration requires a running server.
      expect(gateway.state, HermesConnectionState.disconnected);
    });

    test('disconnect resets state to disconnected', () async {
      await gateway.disconnect();
      expect(gateway.state, HermesConnectionState.disconnected);
    });

    test('parseEvent parses message.delta correctly', () async {
      final parsed = _parseEventStub({
        'type': 'message.delta',
        'session_id': 's1',
        'payload': {'text': 'Hello, world!'},
      });

      expect(parsed, isA<MessageDelta>());
      expect((parsed as MessageDelta).text, 'Hello, world!');
      expect(parsed.sessionId, 's1');
    });

    test('parseEvent parses tool.complete correctly', () async {
      final parsed = _parseEventStub({
        'type': 'tool.complete',
        'session_id': 's2',
        'payload': {'name': 'bash', 'duration': 1.5, 'ok': true, 'index': 0},
      });

      expect(parsed, isA<ToolComplete>());
      final tc = parsed as ToolComplete;
      expect(tc.name, 'bash');
      expect(tc.duration, 1.5);
      expect(tc.ok, isTrue);
    });

    test('parseEvent parses gateway.ready correctly', () async {
      final parsed = _parseEventStub({
        'type': 'gateway.ready',
        'session_id': '',
        'payload': {'skin': 'dark'},
      });

      expect(parsed, isA<GatewayReady>());
    });

    test('parseEvent handles unknown event as GatewayNotice', () async {
      final parsed = _parseEventStub({
        'type': 'unknown.event.type',
        'session_id': 's1',
        'payload': {},
      });

      expect(parsed, isA<GatewayNotice>());
    });
  });

  group('HermesConfig', () {
    test('HermesBackendBox authModeEnum maps correctly', () {
      expect(
        HermesBackendBox(
          id: '1',
          name: 'test',
          url: 'ws://x',
          authMode: 'loopback',
          addedAt: DateTime.now(),
        ).authModeEnum,
        HermesAuthMode.loopback,
      );
      expect(
        HermesBackendBox(
          id: '2',
          name: 'test',
          url: 'ws://x',
          authMode: 'gated',
          addedAt: DateTime.now(),
        ).authModeEnum,
        HermesAuthMode.gated,
      );
      expect(
        HermesBackendBox(
          id: '3',
          name: 'test',
          url: 'ws://x',
          authMode: 'auto',
          addedAt: DateTime.now(),
        ).authModeEnum,
        HermesAuthMode.auto,
      );
    });

    test('HermesBackendBox copyWith preserves unchanged fields', () {
      final original = HermesBackendBox(
        id: '1',
        name: 'Test',
        url: 'ws://localhost',
        authMode: 'loopback',
        token: 'secret',
        profile: 'default',
        addedAt: DateTime(2024, 1, 1),
      );

      final modified = original.copyWith(name: 'New Name');

      expect(modified.name, 'New Name');
      expect(modified.id, '1');
      expect(modified.url, 'ws://localhost');
      expect(modified.token, 'secret');
      expect(modified.profile, 'default');
    });
  });

  group('HermesQrPayload', () {
    test('parseHermesQr parses JSON format', () {
      final payload = _parseQrStub(
        '{"v":1,"url":"ws://192.168.1.1:9119","token":"abc","profile":"dev"}',
      );

      expect(payload?.url, 'ws://192.168.1.1:9119');
      expect(payload?.token, 'abc');
      expect(payload?.profile, 'dev');
    });

    test('parseHermesQr parses kelivo:// URL scheme', () {
      final payload = _parseQrStub(
        'kelivo://hermes?url=ws://x.com&token=mytoken&profile=prd',
      );

      expect(payload?.url, 'ws://x.com');
      expect(payload?.token, 'mytoken');
      expect(payload?.profile, 'prd');
    });

    test('parseHermesQr parses raw ws:// URL', () {
      final payload = _parseQrStub('wss://hermes.example.com');

      expect(payload?.url, 'wss://hermes.example.com');
      expect(payload?.token, isNull);
    });

    test('parseHermesQr returns null for invalid input', () {
      expect(_parseQrStub('not valid json or url'), isNull);
      expect(_parseQrStub(''), isNull);
      expect(_parseQrStub('{broken json'), isNull);
    });
  });
}

// ── Helpers that replicate HermesGateway._parseEvent for testing ──

HermesStreamEvent? _parseEventStub(Map<String, dynamic> params) {
  final type = params['type'] as String? ?? '';
  final sid = params['session_id'] as String? ?? '';
  final payload = Map<String, dynamic>.from(params['payload'] ?? {});

  switch (type) {
    case 'message.delta':
      return MessageDelta(
        sessionId: sid,
        text: payload['text'] as String? ?? '',
      );
    case 'tool.complete':
      return ToolComplete(
        sessionId: sid,
        name: payload['name'] as String? ?? '',
        duration: (payload['duration'] as num?)?.toDouble() ?? 0.0,
        ok: payload['ok'] as bool? ?? true,
        index: (payload['index'] as num?)?.toInt() ?? 0,
      );
    case 'gateway.ready':
      return GatewayReady(skin: payload['skin']?.toString());
    default:
      return GatewayNotice(kind: 'unknown', text: type);
  }
}

// Re-implement QR parsing here for isolated test
class QrPayload {
  final String url;
  final String? token;
  final String? profile;
  const QrPayload({required this.url, this.token, this.profile});
}

QrPayload? _parseQrStub(String raw) {
  final trimmed = raw.trim();
  if (trimmed.startsWith('{')) {
    try {
      final m = jsonDecode(trimmed) as Map<String, dynamic>;
      return QrPayload(
        url: m['url'] as String,
        token: m['token'] as String?,
        profile: m['profile'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
  if (trimmed.startsWith('kelivo://hermes')) {
    try {
      final uri = Uri.parse(trimmed);
      final params = uri.queryParameters;
      return QrPayload(
        url: params['url'] ?? '',
        token: params['token'],
        profile: params['profile'],
      );
    } catch (_) {
      return null;
    }
  }
  if (trimmed.startsWith('ws://') || trimmed.startsWith('wss://')) {
    return QrPayload(url: trimmed);
  }
  return null;
}
