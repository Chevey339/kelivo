// Per-version protocol compliance matrix for mcp_client.
//
// Pairs with the mcp_server matrix. Verifies the protocol registry,
// capability gates, default-version selection, and that the new
// server-initiated request handlers (sampling / elicitation / roots)
// register and dispatch correctly.

import 'package:mcp_client/mcp_client.dart';
import 'package:test/test.dart';

import 'mock_transport.dart';

void main() {
  group('Protocol version registry', () {
    test('all four MCP revisions are listed (newest first)', () {
      expect(
        McpProtocol.supportedVersions,
        equals(<String>[
          McpProtocol.v2025_11_25,
          McpProtocol.v2025_06_18,
          McpProtocol.v2025_03_26,
          McpProtocol.v2024_11_05,
        ]),
      );
    });

    test('defaultVersion tracks latest (2025-11-25)', () {
      expect(McpProtocol.defaultVersion, equals(McpProtocol.v2025_11_25));
    });
  });

  group('Per-version capability gates', () {
    test('JSON-RPC batching only on legacy revisions (≤ 2025-03-26)', () {
      expect(McpProtocol.supportsBatching(McpProtocol.v2024_11_05), isTrue);
      expect(McpProtocol.supportsBatching(McpProtocol.v2025_03_26), isTrue);
      expect(McpProtocol.supportsBatching(McpProtocol.v2025_06_18), isFalse);
      expect(McpProtocol.supportsBatching(McpProtocol.v2025_11_25), isFalse);
    });

    test('Elicitation introduced at 2025-06-18', () {
      expect(McpProtocol.supportsElicitation(McpProtocol.v2024_11_05), isFalse);
      expect(McpProtocol.supportsElicitation(McpProtocol.v2025_03_26), isFalse);
      expect(McpProtocol.supportsElicitation(McpProtocol.v2025_06_18), isTrue);
      expect(McpProtocol.supportsElicitation(McpProtocol.v2025_11_25), isTrue);
    });

    test('MCP-Protocol-Version HTTP header required at 2025-06-18+', () {
      expect(
        McpProtocol.requiresProtocolHeader(McpProtocol.v2024_11_05),
        isFalse,
      );
      expect(
        McpProtocol.requiresProtocolHeader(McpProtocol.v2025_03_26),
        isFalse,
      );
      expect(
        McpProtocol.requiresProtocolHeader(McpProtocol.v2025_06_18),
        isTrue,
      );
      expect(
        McpProtocol.requiresProtocolHeader(McpProtocol.v2025_11_25),
        isTrue,
      );
    });
  });

  group('ClientCapabilities serialization', () {
    test('elicitation capability serializes when set', () {
      const caps = ClientCapabilities(
        roots: true,
        rootsListChanged: true,
        sampling: true,
        elicitation: true,
      );
      final json = caps.toJson();
      expect(json['roots'], isA<Map<String, dynamic>>());
      expect((json['roots'] as Map)['listChanged'], isTrue);
      expect(json['sampling'], isA<Map>());
      expect(json['elicitation'], isA<Map>());
    });

    test('elicitation capability omitted when unset', () {
      const caps = ClientCapabilities();
      expect(caps.toJson().containsKey('elicitation'), isFalse);
    });
  });

  group('Server-initiated request dispatch', () {
    late Client client;
    late MockTransport transport;

    setUp(() {
      client = Client(name: 'test-client', version: '1.0.0');
      transport = MockTransport();
      transport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 1,
        'result': {
          'protocolVersion': McpProtocol.v2025_06_18,
          'serverInfo': {'name': 'mock', 'version': '1.0.0'},
          'capabilities': {},
        },
      });
    });

    test(
      'sampling/createMessage routes to onSamplingRequest handler',
      () async {
        var called = 0;
        client.onSamplingRequest((req) async {
          called++;
          return CreateMessageResult(
            role: 'assistant',
            content: const TextContent(text: 'pong'),
            model: 'm',
          );
        });
        await client.connect(transport);
        transport.simulateMessage({
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 'srv-7',
          'method': 'sampling/createMessage',
          'params': {
            'messages': [
              {
                'role': 'user',
                'content': {'type': 'text', 'text': 'ping'},
              },
            ],
            'maxTokens': 10,
          },
        });
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(called, 1);
        final response = transport.sentMessages.firstWhere(
          (m) => m['id'] == 'srv-7',
          orElse: () => {},
        );
        expect(response['result']?['model'], equals('m'));
      },
    );

    test('roots/list returns locally registered roots by default', () async {
      client.addRoot(const Root(uri: 'file:///workspace', name: 'Workspace'));
      await client.connect(transport);
      transport.simulateMessage({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 'srv-8',
        'method': 'roots/list',
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final response = transport.sentMessages.firstWhere(
        (m) => m['id'] == 'srv-8',
        orElse: () => {},
      );
      final roots = response['result']?['roots'] as List?;
      expect(roots, hasLength(1));
      expect(roots?.first['uri'], equals('file:///workspace'));
    });

    test('elicitation/create routes to onElicitationRequest handler', () async {
      Map<String, dynamic>? receivedParams;
      client.onElicitationRequest((params) async {
        receivedParams = params;
        return {
          'action': 'accept',
          'content': {'name': 'octocat'},
        };
      });
      await client.connect(transport);
      transport.simulateMessage({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 'srv-9',
        'method': 'elicitation/create',
        'params': {
          'message': 'Your name?',
          'requestedSchema': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
            },
          },
        },
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(receivedParams?['message'], equals('Your name?'));
      final response = transport.sentMessages.firstWhere(
        (m) => m['id'] == 'srv-9',
        orElse: () => {},
      );
      expect(response['result']?['action'], equals('accept'));
    });

    test(
      'unknown server-initiated method returns method-not-found error',
      () async {
        await client.connect(transport);
        transport.simulateMessage({
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 'srv-10',
          'method': 'totally/unknown',
        });
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final response = transport.sentMessages.firstWhere(
          (m) => m['id'] == 'srv-10',
          orElse: () => {},
        );
        expect(
          response['error']?['code'],
          equals(McpProtocol.errorMethodNotFound),
        );
      },
    );
  });

  group('Spec notifications emitted by client', () {
    late Client client;
    late MockTransport transport;

    setUp(() async {
      client = Client(name: 'test-client', version: '1.0.0');
      transport = MockTransport();
      transport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 1,
        'result': {
          'protocolVersion': McpProtocol.v2025_06_18,
          'serverInfo': {'name': 'mock', 'version': '1.0.0'},
          'capabilities': {},
        },
      });
      await client.connect(transport);
    });

    test('notifyCancelled sends notifications/cancelled with requestId', () {
      client.notifyCancelled('req-1', reason: 'user');
      final msg = transport.sentMessages.last;
      expect(msg['method'], equals('notifications/cancelled'));
      expect(msg.containsKey('id'), isFalse);
      expect(msg['params']['requestId'], equals('req-1'));
      expect(msg['params']['reason'], equals('user'));
    });

    test('notifyProgress sends notifications/progress with progressToken', () {
      client.notifyProgress('tok', 0.5, total: 1.0, message: 'half');
      final msg = transport.sentMessages.last;
      expect(msg['method'], equals('notifications/progress'));
      expect(msg.containsKey('id'), isFalse);
      expect(msg['params']['progressToken'], equals('tok'));
      expect(msg['params']['progress'], equals(0.5));
      expect(msg['params']['total'], equals(1.0));
    });
  });
}
