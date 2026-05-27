import 'package:mcp_client/mcp_client.dart';
import 'package:test/test.dart';

import 'mock_transport.dart';

void main() {
  group('MCP Client 2025-03-26 New Features Tests', () {
    late Client client;
    late MockTransport mockTransport;

    setUp(() {
      // Use McpClient factory for consistency
      final config = McpClient.productionConfig(
        name: 'Test Client 2025',
        version: '1.0.0',
        capabilities: const ClientCapabilities(
          roots: true,
          rootsListChanged: true,
          sampling: true,
        ),
      );

      client = McpClient.createClient(config);
      mockTransport = MockTransport();
    });

    tearDown(() {
      client.disconnect();
    });

    group('OAuth Authentication Tests', () {
      test('OAuth client configuration', () {
        final config = OAuthConfig(
          authorizationEndpoint: 'https://auth.example.com/authorize',
          tokenEndpoint: 'https://auth.example.com/token',
          clientId: 'test-client',
          clientSecret: 'test-secret',
          redirectUri: 'http://localhost:8080/callback',
          scopes: ['mcp:tools', 'mcp:resources'],
          grantType: OAuthGrantType.authorizationCode,
        );

        expect(config.clientId, equals('test-client'));
        expect(config.scopes, contains('mcp:tools'));
        expect(config.grantType, equals(OAuthGrantType.authorizationCode));
      });

      test('OAuth client can generate authorization URL', () async {
        final config = OAuthConfig(
          authorizationEndpoint: 'https://auth.example.com/authorize',
          tokenEndpoint: 'https://auth.example.com/token',
          clientId: 'test-client',
          redirectUri: 'http://localhost:8080/callback',
        );

        final oauthClient = HttpOAuthClient(config: config);
        final authUrl = await oauthClient.getAuthorizationUrl(
          scopes: ['mcp:tools'],
          state: 'test-state',
        );

        expect(authUrl, contains('client_id=test-client'));
        expect(authUrl, contains('redirect_uri='));
        expect(authUrl, contains('state=test-state'));
        expect(authUrl, contains('response_type=code'));
      });

      test('OAuth token manager handles token lifecycle', () async {
        final config = OAuthConfig(
          authorizationEndpoint: 'https://auth.example.com/authorize',
          tokenEndpoint: 'https://auth.example.com/token',
          clientId: 'test-client',
        );

        final oauthClient = HttpOAuthClient(config: config);
        final tokenManager = OAuthTokenManager(oauthClient);

        // Listen for token updates
        final tokenUpdates = <OAuthToken>[];
        tokenManager.onTokenUpdate.listen(tokenUpdates.add);

        // Listen for errors
        final errors = <OAuthError>[];
        tokenManager.onError.listen(errors.add);

        // Verify token manager is initialized
        expect(tokenManager.isAuthenticated, isFalse);
        expect(tokenManager.currentToken, isNull);
      });
    });

    group('Streamable HTTP Transport Tests', () {
      test('Streamable HTTP transport configuration', () async {
        final transport = await StreamableHttpClientTransport.create(
          baseUrl: 'http://localhost:8080',
          headers: {
            'User-Agent': 'MCP-Test/1.0',
            'X-Custom-Header': 'test-value',
          },
          maxConcurrentRequests: 10,
          useHttp2: true,
        );

        expect(transport.baseUrl, equals('http://localhost:8080'));
        expect(transport.maxConcurrentRequests, equals(10));
        expect(transport.useHttp2, isTrue);
      });

      test('Streamable HTTP transport with OAuth', () async {
        final oauthConfig = OAuthConfig(
          authorizationEndpoint: 'https://auth.example.com/authorize',
          tokenEndpoint: 'https://auth.example.com/token',
          clientId: 'test-client',
        );

        final transport = await StreamableHttpClientTransport.create(
          baseUrl: 'http://localhost:8080',
          oauthConfig: oauthConfig,
        );

        expect(transport.oauthConfig, isNotNull);
        expect(transport.oauthConfig!.clientId, equals('test-client'));
      });
    });

    // JSON-RPC batching was removed in MCP 2025-06-18 (PR #416). The
    // `BatchingClientTransport` and `BatchUtils` helpers were dropped in
    // 2.0; older negotiated revisions on the server side still accept
    // batches but the client no longer constructs them.

    group('Enhanced Tool Features Tests', () {
      test('Tool annotations are preserved', () async {
        mockTransport.queueResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'protocolVersion': '2025-03-26',
            'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
            'capabilities': {'tools': {}},
          },
        });

        mockTransport.queueResponse({
          'jsonrpc': '2.0',
          'id': 2,
          'result': {
            'tools': [
              {
                'name': 'advanced_tool',
                'description': 'Tool with annotations',
                'supportsProgress': true,
                'supportsCancellation': true,
                'metadata': {
                  'category': 'data_processing',
                  'priority': 'high',
                  'estimatedDuration': 300,
                  'readOnly': false,
                  'destructive': false,
                  'requiresAuth': true,
                },
                'inputSchema': {'type': 'object'},
              },
            ],
          },
        });

        await client.connect(mockTransport);
        final tools = await client.listTools();

        expect(tools.length, equals(1));
        final tool = tools[0];
        expect(tool.supportsProgress, isTrue);
        expect(tool.supportsCancellation, isTrue);
        expect(tool.metadata?['category'], equals('data_processing'));
        expect(tool.metadata?['priority'], equals('high'));
        expect(tool.metadata?['estimatedDuration'], equals(300));
      });

      test('Progress tracking with operation ID', () async {
        mockTransport.queueResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'protocolVersion': '2025-03-26',
            'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
            'capabilities': {
              'tools': {'progress': true},
            },
          },
        });

        mockTransport.queueResponse({
          'jsonrpc': '2.0',
          'id': 2,
          'result': {
            'operationId': 'op-456',
            'content': [
              {'type': 'text', 'text': 'Started'},
            ],
          },
        });

        await client.connect(mockTransport);
        final tracking = await client.callToolWithTracking('progress_tool', {
          'data': 'test',
        }, trackProgress: true);

        expect(tracking.operationId, equals('op-456'));
        expect(tracking.result.content.length, equals(1));
      });
    });

    group('Resource Templates Tests', () {
      test('List resource templates', () async {
        mockTransport.queueResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'protocolVersion': '2025-03-26',
            'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
            'capabilities': {'resources': {}},
          },
        });

        mockTransport.queueResponse({
          'jsonrpc': '2.0',
          'id': 2,
          'result': {
            'resourceTemplates': [
              {
                'uriTemplate': 'file:///{path}',
                'name': 'File System',
                'description': 'Access local files',
                'mimeType': 'text/plain',
              },
              {
                'uriTemplate': 'api://v1/{endpoint}/{id}',
                'name': 'API Resources',
                'description': 'Access API endpoints',
                'mimeType': 'application/json',
              },
            ],
          },
        });

        await client.connect(mockTransport);
        final templates = await client.listResourceTemplates();

        expect(templates.length, equals(2));
        expect(templates[0].uriTemplate, equals('file:///{path}'));
        expect(templates[1].uriTemplate, equals('api://v1/{endpoint}/{id}'));
      });

      test('Access resource using template', () async {
        mockTransport.queueResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'protocolVersion': '2025-03-26',
            'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
            'capabilities': {'resources': {}},
          },
        });

        mockTransport.queueResponse({
          'jsonrpc': '2.0',
          'id': 2,
          'result': {
            'contents': [
              {
                'uri': 'file:///test/document.txt',
                'mimeType': 'text/plain',
                'text': 'Document content',
              },
            ],
          },
        });

        await client.connect(mockTransport);
        final result = await client.getResourceWithTemplate('file:///{path}', {
          'path': 'test/document.txt',
        });

        expect(result.contents.length, equals(1));
        expect(result.contents[0].uri, equals('file:///test/document.txt'));
      });
    });

    group('Connection State Management Tests', () {
      test('Connection state transitions', () async {
        // Mock a connection state observable (simplified)
        mockTransport.queueResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'protocolVersion': '2025-03-26',
            'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
            'capabilities': {},
          },
        });

        await client.connect(mockTransport);
        expect(client.isConnected, isTrue);

        client.disconnect();
        expect(client.isConnected, isFalse);
      });

      test('Retry connection with backoff', () async {
        int attemptCount = 0;
        bool shouldFail = true;

        final retryTransport = MockTransport();

        // Set up the mock to fail first 2 times, succeed on 3rd
        retryTransport.onSend = (message) {
          attemptCount++;

          // For the first 2 attempts, throw an error during transport setup
          if (attemptCount <= 2 && shouldFail) {
            throw McpError('Transport setup failed - attempt $attemptCount');
          }

          // On 3rd attempt, allow normal processing
          if (message is Map<String, dynamic> &&
              message['method'] == 'initialize') {
            retryTransport.queueResponse({
              'jsonrpc': '2.0',
              'id': message['id'],
              'result': {
                'protocolVersion': '2025-03-26',
                'serverInfo': {'name': 'Test Server', 'version': '1.0.0'},
                'capabilities': {},
              },
            });
          }
        };

        // First test - transport fails completely after all retries
        Exception? lastError;
        try {
          await client.connectWithRetry(
            retryTransport,
            maxRetries: 2, // Only 2 retries, so it should fail
            delay: const Duration(milliseconds: 10),
          );
        } catch (e) {
          lastError = e as Exception;
        }

        expect(lastError, isNotNull);
        expect(
          lastError.toString(),
          contains('Failed to connect after 2 attempts'),
        );
        expect(client.isConnected, isFalse);

        // Reset for successful test
        attemptCount = 0;
        shouldFail = false;

        // Create a new client for clean state
        final successConfig = McpClient.simpleConfig(
          name: 'Test Client Success',
          version: '1.0.0',
        );
        final successClient = McpClient.createClient(successConfig);

        final successTransport = MockTransport();
        successTransport.queueResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'protocolVersion': '2025-03-26',
            'serverInfo': {'name': 'Success Server', 'version': '1.0.0'},
            'capabilities': {},
          },
        });

        await successClient.connectWithRetry(
          successTransport,
          maxRetries: 3,
          delay: const Duration(milliseconds: 10),
        );

        expect(successClient.isConnected, isTrue);
        successClient.disconnect();
      });
    });

    group('Modern Dart Pattern Tests', () {
      test('Result pattern for error handling', () {
        // Test Success case
        final success = Result<int, String>.success(42);
        expect(success.isSuccess, isTrue);
        expect(success.isFailure, isFalse);
        expect(success.getOrNull(), equals(42));
        expect(success.errorOrNull(), isNull);

        // Test Failure case
        final failure = Result<int, String>.failure('Error occurred');
        expect(failure.isSuccess, isFalse);
        expect(failure.isFailure, isTrue);
        expect(failure.getOrNull(), isNull);
        expect(failure.errorOrNull(), equals('Error occurred'));

        // Test fold method
        final successResult = success.fold(
          (value) => 'Success: $value',
          (error) => 'Error: $error',
        );
        expect(successResult, equals('Success: 42'));

        final failureResult = failure.fold(
          (value) => 'Success: $value',
          (error) => 'Error: $error',
        );
        expect(failureResult, equals('Error: Error occurred'));
      });

      test('Sealed class pattern for connection states', () {
        const disconnected = Disconnected();
        const connecting = Connecting();
        const serverInfo = ServerInfo(
          name: 'Test Server',
          version: '1.0.0',
          protocolVersion: '2025-03-26',
        );
        const connected = Connected(serverInfo);
        const disconnecting = Disconnecting();
        const error = ConnectionError(McpError('Connection failed'), null);

        // Pattern matching simulation
        String getStateMessage(ConnectionState state) {
          return switch (state) {
            Disconnected() => 'Not connected',
            Connecting() => 'Establishing connection...',
            Connected(serverInfo: final info) => 'Connected to ${info.name}',
            Disconnecting() => 'Disconnecting...',
            ConnectionError(error: final err) =>
              'Error: ${err is McpError ? err.message : err}',
          };
        }

        expect(getStateMessage(disconnected), equals('Not connected'));
        expect(
          getStateMessage(connecting),
          equals('Establishing connection...'),
        );
        expect(getStateMessage(connected), equals('Connected to Test Server'));
        expect(getStateMessage(disconnecting), equals('Disconnecting...'));
        expect(getStateMessage(error), equals('Error: Connection failed'));
      });

      test('Immutable models with const constructors', () {
        const content1 = TextContent(
          text: 'Hello',
          annotations: {'lang': 'en'},
        );
        const content2 = TextContent(
          text: 'Hello',
          annotations: {'lang': 'en'},
        );

        // Const objects are identical
        expect(identical(content1, content2), isTrue);

        // Verify immutability through JSON round-trip
        final json = content1.toJson();
        final decoded = TextContent.fromJson(json);
        expect(decoded.text, equals(content1.text));
        expect(decoded.annotations, equals(content1.annotations));
      });
    });

    // The non-spec `health/check` JSON-RPC method was removed in 2.0.
    // Servers now expose health on a transport-specific path (e.g. an
    // HTTP `/health` endpoint) — testing that is out of scope for the
    // protocol client.

    group('Logging Integration Tests', () {
      test('Set logging level', () async {
        mockTransport.queueResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'protocolVersion': '2025-03-26',
            'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
            'capabilities': {'logging': {}},
          },
        });

        mockTransport.queueResponse({'jsonrpc': '2.0', 'id': 2, 'result': {}});

        await client.connect(mockTransport);
        await client.setLoggingLevel(McpLogLevel.debug);

        final setLevelMessage = mockTransport.sentMessages[2];
        // Spec method name is camelCase per MCP standard.
        expect(setLevelMessage['method'], equals('logging/setLevel'));
        expect(setLevelMessage['params']!['level'], equals('debug'));
      });
    });
  });
}
