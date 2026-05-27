import 'dart:async';

import 'package:mcp_client/mcp_client.dart';
import 'package:test/test.dart';

import 'mock_transport.dart';

void main() {
  group('MCP Client Tests - 2025-03-26 Protocol', () {
    late Client client;
    late MockTransport mockTransport;

    setUp(() {
      // Create client with McpClient factory
      final config = McpClient.simpleConfig(
        name: 'Test Client',
        version: '1.0.0',
        enableDebugLogging: false,
      );

      client = McpClient.createClient(config);

      // Create mock transport
      mockTransport = MockTransport();
    });

    tearDown(() {
      client.disconnect();
    });

    test('Client initializes with 2025-03-26 protocol', () async {
      // Setup mock response for initialization
      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 1,
        'result': {
          'protocolVersion': McpProtocol.v2025_03_26,
          'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
          'capabilities': {
            'tools': {
              'listChanged': true,
              'cancellation': true,
              'progress': true,
            },
            'resources': {'listChanged': true, 'subscribe': true},
            'prompts': {'listChanged': true},
            'sampling': {},
          },
        },
      });

      // Connect to mock transport
      await client.connect(mockTransport);

      // Verify that initialization message was sent
      expect(
        mockTransport.sentMessages.length,
        2,
      ); // initialize + initialized notification

      final initMessage = mockTransport.sentMessages[0];
      expect(initMessage['method'], equals(McpProtocol.methodInitialize));
      expect(
        initMessage['params']['clientInfo']['name'],
        equals('Test Client'),
      );
      // Client always proposes the latest supported revision; server
      // negotiates down if needed. This assertion just verifies the client
      // sent SOME spec-listed version.
      expect(
        McpProtocol.supportedVersions,
        contains(initMessage['params']['protocolVersion']),
      );

      // Verify that server capabilities were received
      expect(client.serverCapabilities?.tools, isTrue);
      expect(client.serverCapabilities?.resources, isTrue);
      expect(client.serverCapabilities?.prompts, isTrue);
      expect(client.serverCapabilities?.sampling, isTrue);

      // Verify server info
      expect(client.serverInfo?['name'], equals('Mock Server'));
    });

    test('McpClient factory passes request timeout to Client', () {
      final config = McpClient.simpleConfig(
        name: 'Timeout Client',
        version: '1.0.0',
        requestTimeout: const Duration(seconds: 7),
      );

      final timeoutClient = McpClient.createClient(config);

      expect(timeoutClient.requestTimeout, const Duration(seconds: 7));
    });

    test('Client handles protocol version negotiation', () async {
      // Server responds with older protocol version
      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 1,
        'result': {
          'protocolVersion': McpProtocol.v2024_11_05,
          'serverInfo': {'name': 'Legacy Server', 'version': '0.9.0'},
          'capabilities': {'tools': {}, 'resources': {}},
        },
      });

      // Connect to mock transport
      await client.connect(mockTransport);

      // Client should accept older protocol version
      expect(client.isConnected, isTrue);
      expect(client.serverInfo?['name'], equals('Legacy Server'));
    });

    test('Client can list tools with enhanced features', () async {
      // Setup mock responses
      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 1,
        'result': {
          'protocolVersion': McpProtocol.v2025_03_26,
          'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
          'capabilities': {
            'tools': {
              'listChanged': true,
              'cancellation': true,
              'progress': true,
            },
          },
        },
      });

      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 2,
        'result': {
          'tools': [
            {
              'name': 'calculator',
              'description': 'Perform basic calculations',
              'supportsProgress': true,
              'supportsCancellation': true,
              'inputSchema': {
                'type': 'object',
                'properties': {
                  'operation': {'type': 'string'},
                  'a': {'type': 'number'},
                  'b': {'type': 'number'},
                },
                'required': ['operation', 'a', 'b'],
              },
            },
          ],
        },
      });

      // Connect to mock transport
      await client.connect(mockTransport);

      // List tools
      final tools = await client.listTools();

      // Verify tools list request was sent
      expect(
        mockTransport.sentMessages.length,
        3,
      ); // initialize + initialized + listTools
      expect(
        mockTransport.sentMessages[2]['method'],
        equals(McpProtocol.methodListTools),
      );

      // Verify enhanced tool features
      expect(tools.length, equals(1));
      expect(tools[0].name, equals('calculator'));
      expect(tools[0].supportsProgress, isTrue);
      expect(tools[0].supportsCancellation, isTrue);
    });

    test('Client can call tool with progress tracking', () async {
      // Setup mock responses
      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 1,
        'result': {
          'protocolVersion': McpProtocol.v2025_03_26,
          'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
          'capabilities': {
            'tools': {'progress': true},
          },
        },
      });

      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 2,
        'result': {
          'operationId': 'op-123',
          'content': [
            {'type': 'text', 'text': 'Processing...'},
          ],
        },
      });

      // Connect to mock transport
      await client.connect(mockTransport);

      // Call tool with tracking
      final tracking = await client.callToolWithTracking('long-running-tool', {
        'data': 'test',
      }, trackProgress: true);

      // Verify tool call request was sent
      expect(mockTransport.sentMessages.length, 3);
      expect(
        mockTransport.sentMessages[2]['method'],
        equals(McpProtocol.methodCallTool),
      );
      expect(mockTransport.sentMessages[2]['params']['trackProgress'], isTrue);

      // Verify operation ID was received
      expect(tracking.operationId, equals('op-123'));
      expect(tracking.result.content.length, equals(1));
    });

    test('Client handles enhanced Content types', () async {
      // Setup mock responses
      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 1,
        'result': {
          'protocolVersion': McpProtocol.v2025_03_26,
          'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
          'capabilities': {'tools': {}},
        },
      });

      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 2,
        'result': {
          'content': [
            {
              'type': 'text',
              'text': 'Hello',
              'annotations': {'priority': 'high', 'language': 'en'},
            },
            {
              'type': 'image',
              'data': 'base64data',
              'mimeType': 'image/png',
              'annotations': {'alt': 'Test image'},
            },
            {
              'type': 'resource',
              'uri': 'file:///test.txt',
              'mimeType': 'text/plain',
              'text': 'Resource content',
            },
          ],
        },
      });

      // Connect to mock transport
      await client.connect(mockTransport);

      // Call tool
      final result = await client.callTool('content-test', {});

      // Verify different content types
      expect(result.content.length, equals(3));

      // Text content with annotations
      final textContent = result.content[0] as TextContent;
      expect(textContent.text, equals('Hello'));
      expect(textContent.annotations?['priority'], equals('high'));

      // Image content
      final imageContent = result.content[1] as ImageContent;
      expect(imageContent.data, equals('base64data'));
      expect(imageContent.mimeType, equals('image/png'));
      expect(imageContent.annotations?['alt'], equals('Test image'));

      // Resource content
      final resourceContent = result.content[2] as ResourceContent;
      expect(resourceContent.uri, equals('file:///test.txt'));
      expect(resourceContent.text, equals('Resource content'));
    });

    test('Client cancels via spec notifications/cancelled (no id)', () async {
      // Setup mock responses
      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 1,
        'result': {
          'protocolVersion': McpProtocol.v2025_03_26,
          'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
          'capabilities': {
            'tools': {'cancellation': true},
          },
        },
      });

      // Connect to mock transport
      await client.connect(mockTransport);

      // Cancel an in-flight server-side request via the spec notification.
      client.notifyCancelled('op-123', reason: 'user aborted');

      // Verify cancellation NOTIFICATION was sent (no id, no result expected).
      expect(mockTransport.sentMessages.length, 3);
      final cancelMsg = mockTransport.sentMessages[2];
      expect(cancelMsg['method'], equals('notifications/cancelled'));
      expect(
        cancelMsg.containsKey('id'),
        isFalse,
        reason: 'cancellation is a notification, not a request',
      );
      expect(cancelMsg['params']['requestId'], equals('op-123'));
      expect(cancelMsg['params']['reason'], equals('user aborted'));
    });

    test('Client handles progress notifications', () async {
      // Setup mock responses
      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 1,
        'result': {
          'protocolVersion': McpProtocol.v2025_03_26,
          'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
          'capabilities': {},
        },
      });

      // Prepare to listen for progress
      final progressReceived = Completer<bool>();
      String? receivedRequestId;
      double? receivedProgress;
      String? receivedMessage;

      client.onProgress((requestId, progress, message) {
        receivedRequestId = requestId;
        receivedProgress = progress;
        receivedMessage = message;
        progressReceived.complete(true);
      });

      // Connect to mock transport
      await client.connect(mockTransport);

      // Send mock progress notification
      mockTransport.sendMockNotification({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'method': McpProtocol.methodProgress,
        'params': {
          'requestId': 'req-123',
          'progress': 0.75,
          'message': '75% complete',
        },
      });

      // Verify progress notification was received
      await progressReceived.future.timeout(const Duration(seconds: 1));
      expect(receivedRequestId, equals('req-123'));
      expect(receivedProgress, equals(0.75));
      expect(receivedMessage, equals('75% complete'));
    });

    test('Client handles resource subscriptions', () async {
      // Setup mock responses
      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 1,
        'result': {
          'protocolVersion': McpProtocol.v2025_03_26,
          'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
          'capabilities': {
            'resources': {'subscribe': true},
          },
        },
      });

      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 2,
        'result': {},
      });

      // Connect to mock transport
      await client.connect(mockTransport);

      // Subscribe to resource
      await client.subscribeResource('file:///test.txt');

      // Verify subscription request was sent
      expect(mockTransport.sentMessages.length, 3);
      expect(
        mockTransport.sentMessages[2]['method'],
        equals('resources/subscribe'),
      );
      expect(
        mockTransport.sentMessages[2]['params']['uri'],
        equals('file:///test.txt'),
      );
    });

    test('Client handles resource update notifications', () async {
      // Setup mock responses
      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 1,
        'result': {
          'protocolVersion': McpProtocol.v2025_03_26,
          'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
          'capabilities': {'resources': {}},
        },
      });

      // Prepare to listen for resource updates
      final updateReceived = Completer<bool>();
      String? receivedUri;
      ResourceContentInfo? receivedContent;

      client.onResourceContentUpdated((uri, content) {
        receivedUri = uri;
        receivedContent = content;
        updateReceived.complete(true);
      });

      // Connect to mock transport
      await client.connect(mockTransport);

      // Send mock resource update notification
      mockTransport.sendMockNotification({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'method': McpProtocol.methodResourceUpdated,
        'params': {
          'uri': 'file:///test.txt',
          'content': {
            'uri': 'file:///test.txt',
            'mimeType': 'text/plain',
            'text': 'Updated content',
          },
        },
      });

      // Verify update notification was received
      await updateReceived.future.timeout(const Duration(seconds: 1));
      expect(receivedUri, equals('file:///test.txt'));
      expect(receivedContent?.text, equals('Updated content'));
    });

    test('Client validates protocol errors', () async {
      // Setup mock error response
      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 1,
        'result': {
          'protocolVersion': McpProtocol.v2025_03_26,
          'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
          'capabilities': {'tools': {}},
        },
      });

      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 2,
        'error': {
          'code': McpProtocol.errorToolNotFound,
          'message': 'Tool not found: unknown-tool',
        },
      });

      // Connect to mock transport
      await client.connect(mockTransport);

      // Call unknown tool and expect error
      try {
        await client.callTool('unknown-tool', {});
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<McpError>());
        final mcpError = e as McpError;
        expect(mcpError.code, equals(McpProtocol.errorToolNotFound));
        expect(mcpError.message, contains('Tool not found'));
      }
    });

    test(
      'Client handles server-initiated sampling/createMessage request',
      () async {
        // Setup mock initialize response
        mockTransport.queueResponse({
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 1,
          'result': {
            'protocolVersion': McpProtocol.v2025_06_18,
            'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
            'capabilities': {'sampling': {}},
          },
        });

        CreateMessageRequest? receivedRequest;
        client.onSamplingRequest((request) async {
          receivedRequest = request;
          return CreateMessageResult(
            role: 'assistant',
            content: const TextContent(text: 'Hello! How can I help you?'),
            model: 'test-model',
            stopReason: 'end_turn',
          );
        });

        await client.connect(mockTransport);

        // Server pushes a sampling/createMessage request to the client.
        mockTransport.simulateMessage({
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 'srv-1',
          'method': 'sampling/createMessage',
          'params': {
            'messages': [
              {
                'role': 'user',
                'content': {'type': 'text', 'text': 'Hello'},
              },
            ],
            'maxTokens': 100,
            'systemPrompt': 'You are a helpful assistant',
          },
        });
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Client handler ran with the parsed request.
        expect(receivedRequest, isNotNull);
        expect(receivedRequest!.maxTokens, 100);
        expect(receivedRequest!.systemPrompt, 'You are a helpful assistant');

        // Client emitted a JSON-RPC response with the matching id.
        final responseMsg = mockTransport.sentMessages.firstWhere(
          (m) => m['id'] == 'srv-1',
          orElse: () => <String, dynamic>{},
        );
        expect(
          responseMsg.isNotEmpty,
          isTrue,
          reason: 'response for srv-1 should have been sent',
        );
        expect(responseMsg['result']['role'], equals('assistant'));
        expect(responseMsg['result']['model'], equals('test-model'));
      },
    );

    test('Unified transport configuration - basic SSE', () async {
      final transportConfig = TransportConfig.sse(
        serverUrl: 'http://localhost:3000/sse',
        headers: {'User-Agent': 'Test'},
      );

      // Verify it's the correct type and has expected properties
      expect(transportConfig, isA<SseTransportConfig>());
      final sseConfig = transportConfig as SseTransportConfig;
      expect(sseConfig.serverUrl, equals('http://localhost:3000/sse'));
      expect(sseConfig.headers?['User-Agent'], equals('Test'));
      expect(sseConfig.enableCompression, isFalse);
      expect(sseConfig.heartbeatInterval, isNull);
      expect(sseConfig.bearerToken, isNull);
    });

    test('Unified transport configuration - SSE with OAuth', () async {
      final transportConfig = TransportConfig.sse(
        serverUrl: 'https://api.example.com/sse',
        bearerToken: 'test-token',
        headers: {'User-Agent': 'Test'},
      );

      // Verify OAuth configuration
      expect(transportConfig, isA<SseTransportConfig>());
      final sseConfig = transportConfig as SseTransportConfig;
      expect(sseConfig.serverUrl, equals('https://api.example.com/sse'));
      expect(sseConfig.bearerToken, equals('test-token'));
      expect(sseConfig.headers?['User-Agent'], equals('Test'));
    });

    test('Unified transport configuration - SSE with compression', () async {
      final transportConfig = TransportConfig.sse(
        serverUrl: 'http://localhost:3000/sse',
        enableCompression: true,
        enableGzip: true,
        enableDeflate: true,
      );

      // Verify compression configuration
      expect(transportConfig, isA<SseTransportConfig>());
      final sseConfig = transportConfig as SseTransportConfig;
      expect(sseConfig.serverUrl, equals('http://localhost:3000/sse'));
      expect(sseConfig.enableCompression, isTrue);
      expect(sseConfig.enableGzip, isTrue);
      expect(sseConfig.enableDeflate, isTrue);
    });

    test('Unified transport configuration - SSE with heartbeat', () async {
      final transportConfig = TransportConfig.sse(
        serverUrl: 'http://localhost:3000/sse',
        heartbeatInterval: const Duration(seconds: 30),
        maxMissedHeartbeats: 3,
      );

      // Verify heartbeat configuration
      expect(transportConfig, isA<SseTransportConfig>());
      final sseConfig = transportConfig as SseTransportConfig;
      expect(sseConfig.serverUrl, equals('http://localhost:3000/sse'));
      expect(sseConfig.heartbeatInterval, equals(const Duration(seconds: 30)));
      expect(sseConfig.maxMissedHeartbeats, equals(3));
    });

    test('Unified transport configuration - HTTP with all features', () async {
      final oauthConfig = OAuthConfig(
        authorizationEndpoint: 'https://auth.example.com/authorize',
        tokenEndpoint: 'https://auth.example.com/token',
        clientId: 'test-client',
      );

      final transportConfig = TransportConfig.streamableHttp(
        baseUrl: 'https://api.example.com',
        oauthConfig: oauthConfig,
        enableCompression: true,
        heartbeatInterval: const Duration(seconds: 60),
        useHttp2: true,
        maxConcurrentRequests: 20,
      );

      // Verify HTTP configuration with all features
      expect(transportConfig, isA<StreamableHttpTransportConfig>());
      final httpConfig = transportConfig as StreamableHttpTransportConfig;
      expect(httpConfig.baseUrl, equals('https://api.example.com'));
      expect(httpConfig.oauthConfig, equals(oauthConfig));
      expect(httpConfig.enableCompression, isTrue);
      expect(httpConfig.heartbeatInterval, equals(const Duration(seconds: 60)));
      expect(httpConfig.useHttp2, isTrue);
      expect(httpConfig.maxConcurrentRequests, equals(20));
    });

    test('Transport feature priority - OAuth takes precedence', () async {
      final transportConfig = TransportConfig.sse(
        serverUrl: 'https://api.example.com/sse',
        bearerToken: 'test-token', // OAuth feature
        enableCompression: true, // Compression feature
        heartbeatInterval: const Duration(seconds: 30), // Heartbeat feature
      );

      // Verify all features are stored correctly
      expect(transportConfig, isA<SseTransportConfig>());
      final sseConfig = transportConfig as SseTransportConfig;
      expect(sseConfig.bearerToken, equals('test-token'));
      expect(sseConfig.enableCompression, isTrue);
      expect(sseConfig.heartbeatInterval, equals(const Duration(seconds: 30)));

      // When createAndConnect is called, it should use SseAuthClientTransport
      // due to OAuth taking priority in _createUnifiedSseTransport
    });

    test('Client event streams work correctly', () async {
      // Setup event listeners
      final connectEvents = <ServerInfo>[];
      final disconnectEvents = <DisconnectReason>[];
      final errorEvents = <McpError>[];

      client.onConnect.listen(connectEvents.add);
      client.onDisconnect.listen(disconnectEvents.add);
      client.onError.listen(errorEvents.add);

      // Setup mock response
      mockTransport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 1,
        'result': {
          'protocolVersion': McpProtocol.v2025_03_26,
          'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
          'capabilities': {},
        },
      });

      // Connect
      await client.connect(mockTransport);

      // Wait for async events to propagate
      await Future.delayed(const Duration(milliseconds: 10));

      // Verify connect event
      expect(connectEvents.length, equals(1));
      expect(connectEvents[0].name, equals('Mock Server'));
      // Negotiated version is whatever the mock server advertised
      // (test default = v2025_03_26 in this fixture, but the assertion
      // is just that the field was populated).
      expect(connectEvents[0].protocolVersion, isNotEmpty);

      // Disconnect
      client.disconnect();

      // Wait for async events to propagate
      await Future.delayed(const Duration(milliseconds: 10));

      // Verify disconnect event
      expect(disconnectEvents.length, equals(1));
      expect(disconnectEvents[0], equals(DisconnectReason.clientDisconnected));
    });
  });
}
