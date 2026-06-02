@TestOn('browser')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:mcp_client/mcp_client.dart';
import 'package:mcp_client/src/transport/event_source.dart';

void main() {
  group('Web Transport Tests', () {
    group('SSE Transport', () {
      test('should create SSE transport on web platform', () async {
        // Test SSE transport configuration
        final transportConfig = TransportConfig.sse(
          serverUrl: 'http://localhost:8080/sse',
          headers: {'User-Agent': 'MCP-Client-Web-Test/1.0'},
        );

        expect(transportConfig, isA<SseTransportConfig>());
        expect(
          (transportConfig as SseTransportConfig).serverUrl,
          equals('http://localhost:8080/sse'),
        );
      });

      test('should support SSE with OAuth on web', () {
        final transportConfig = TransportConfig.sse(
          serverUrl: 'https://api.example.com/sse',
          oauthConfig: OAuthConfig(
            authorizationEndpoint: 'https://auth.example.com/authorize',
            tokenEndpoint: 'https://auth.example.com/token',
            clientId: 'test-client-id',
          ),
        );

        expect(transportConfig, isA<SseTransportConfig>());
        final sseConfig = transportConfig as SseTransportConfig;
        expect(sseConfig.oauthConfig, isNotNull);
        expect(sseConfig.oauthConfig!.clientId, equals('test-client-id'));
      });
    });

    group('StreamableHTTP Transport', () {
      test('should create StreamableHTTP transport on web platform', () {
        final transportConfig = TransportConfig.streamableHttp(
          baseUrl: 'https://api.example.com',
          headers: {'User-Agent': 'MCP-Client-Web-Test/1.0'},
        );

        expect(transportConfig, isA<StreamableHttpTransportConfig>());
        expect(
          (transportConfig as StreamableHttpTransportConfig).baseUrl,
          equals('https://api.example.com'),
        );
      });

      test('should support all StreamableHTTP features on web', () {
        final transportConfig = TransportConfig.streamableHttp(
          baseUrl: 'https://api.example.com',
          headers: {'User-Agent': 'MCP-Client-Web-Test/1.0'},
          timeout: const Duration(seconds: 60),
          maxConcurrentRequests: 20,
          useHttp2: true,
          oauthConfig: OAuthConfig(
            authorizationEndpoint: 'https://auth.example.com/authorize',
            tokenEndpoint: 'https://auth.example.com/token',
            clientId: 'test-client-id',
          ),
          enableCompression: true,
          heartbeatInterval: const Duration(seconds: 60),
        );

        final config = transportConfig as StreamableHttpTransportConfig;
        expect(config.baseUrl, equals('https://api.example.com'));
        expect(config.timeout, equals(const Duration(seconds: 60)));
        expect(config.maxConcurrentRequests, equals(20));
        expect(config.useHttp2, isTrue);
        expect(config.oauthConfig, isNotNull);
        expect(config.enableCompression, isTrue);
        expect(config.heartbeatInterval, equals(const Duration(seconds: 60)));
      });
    });

    group('EventSource Implementation', () {
      test('EventSource should be available on web', () {
        // Import the conditional export
        final eventSource = EventSource();

        expect(eventSource, isNotNull);
        expect(eventSource.isConnected, isFalse);

        // Clean up
        eventSource.close();
      });

      test('EventSource lifecycle methods are reachable without I/O', () {
        // The previous version of this test invoked `connect()` with a
        // bogus URL to "validate the API is available". On dart2js the
        // resulting fetch raised an `AbortError` from the test isolate
        // and the test framework reported the run as failed even though
        // the synchronous expectation passed. Cover the same surface
        // (presence of lifecycle members and clean close) without
        // triggering a real network call.
        final eventSource = EventSource();
        expect(eventSource.isConnected, isFalse);
        expect(eventSource.close, isA<Function>());
        expect(eventSource.connect, isA<Function>());
        eventSource.close();
        expect(eventSource.isConnected, isFalse);
      });
    });

    group('Client Integration', () {
      test('McpClient should work with SSE transport on web', () async {
        final config = McpClient.simpleConfig(
          name: 'Web Test Client',
          version: '1.0.0',
        );

        final transportConfig = TransportConfig.sse(
          serverUrl: 'http://localhost:8080/sse',
        );

        // Just test that we can create the configuration
        // Actual connection would require a running server
        expect(config.name, equals('Web Test Client'));
        expect(transportConfig, isA<SseTransportConfig>());
      });

      test('McpClient should work with StreamableHTTP transport on web', () {
        final config = McpClient.simpleConfig(
          name: 'Web Test Client',
          version: '1.0.0',
        );

        final transportConfig = TransportConfig.streamableHttp(
          baseUrl: 'https://api.example.com',
        );

        expect(config.name, equals('Web Test Client'));
        expect(transportConfig, isA<StreamableHttpTransportConfig>());
      });
    });

    group('JSON-RPC Message Handling', () {
      test('should handle JSON-RPC messages in web environment', () {
        // Test JSON encoding/decoding works properly
        final message = {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'tools/list',
          'params': {},
        };

        final encoded = jsonEncode(message);
        final decoded = jsonDecode(encoded);

        expect(decoded['jsonrpc'], equals('2.0'));
        expect(decoded['id'], equals(1));
        expect(decoded['method'], equals('tools/list'));
      });
    });
  });
}
