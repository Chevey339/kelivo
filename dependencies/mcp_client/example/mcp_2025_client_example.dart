/// MCP 2.0 client showcase: OAuth, Streamable HTTP, enhanced tools,
/// resource templates, progress + cancellation. Targets MCP spec
/// revisions 2024-11-05 / 2025-03-26 / 2025-06-18 / 2025-11-25.
library;

import 'dart:async';
import 'package:mcp_client/mcp_client.dart';

void main() async {
  await runMcp2025ClientExample();
}

Future<void> runMcp2025ClientExample() async {
  print('🚀 Starting MCP 2.0 client showcase...');

  await _demonstrateOAuthAuthentication();
  await _demonstrateStreamableHttpTransport();
  await _demonstrateEnhancedTools();
  await _demonstrateResourceTemplates();
  await _demonstrateProgressAndCancellation();

  print('✅ Showcase complete.');
}

/// Demonstrate OAuth 2.1 authentication
Future<void> _demonstrateOAuthAuthentication() async {
  print('\n🔐 === OAuth 2.1 Authentication Example ===');

  try {
    // Configure OAuth
    final oauthConfig = OAuthConfig(
      authorizationEndpoint: 'https://auth.example.com/oauth2/authorize',
      tokenEndpoint: 'https://auth.example.com/oauth2/token',
      clientId: 'mcp-client-demo',
      clientSecret: 'demo-secret', // For confidential clients
      redirectUri: 'http://localhost:8081/callback',
      scopes: ['mcp:tools', 'mcp:resources', 'mcp:prompts'],
      grantType: OAuthGrantType.authorizationCode,
    );

    // Create OAuth client
    final oauthClient = HttpOAuthClient(config: oauthConfig);

    // Get authorization URL
    final authUrl = await oauthClient.getAuthorizationUrl(
      scopes: ['mcp:tools', 'mcp:resources'],
      state: 'demo-state-123',
    );

    print('📱 Authorization URL: $authUrl');

    // In a real app, you would:
    // 1. Open the URL in a browser
    // 2. Handle the redirect
    // 3. Extract the authorization code
    // 4. Exchange it for a token

    // For demo purposes, simulate token exchange
    try {
      // This would normally use the real authorization code
      print('🔄 Simulating token exchange...');
      print('ℹ️  In production, you would:');
      print('   - Open auth URL in browser');
      print('   - Handle OAuth callback');
      print('   - Exchange auth code for token');
      print('   - Store and manage token lifecycle');
    } catch (e) {
      print('ℹ️  OAuth flow requires real authorization server');
    }

    // Demonstrate token management
    final tokenManager = OAuthTokenManager(oauthClient);

    // Listen for token updates
    tokenManager.onTokenUpdate.listen((token) {
      print('✅ Token updated: expires in ${token.expiresIn} seconds');
    });

    // Listen for authentication errors
    tokenManager.onError.listen((error) {
      print('❌ Auth error: ${error.error} - ${error.errorDescription}');
    });

    print('✅ OAuth configuration completed');
  } catch (e) {
    print('⚠️  OAuth demo completed (requires real auth server): $e');
  }
}

/// Demonstrate Streamable HTTP transport
Future<void> _demonstrateStreamableHttpTransport() async {
  print('\n🌐 === Streamable HTTP Transport Example ===');

  try {
    // Create HTTP transport with OAuth
    final oauthConfig = OAuthConfig(
      authorizationEndpoint: 'https://auth.example.com/oauth2/authorize',
      tokenEndpoint: 'https://auth.example.com/oauth2/token',
      clientId: 'mcp-client',
    );

    final transport = await StreamableHttpClientTransport.create(
      baseUrl: 'http://localhost:8080',
      oauthConfig: oauthConfig,
      headers: {
        'User-Agent': 'MCP-Client-2025/1.0',
        'X-Client-Version': '2025-03-26',
      },
      maxConcurrentRequests: 5,
      useHttp2: true,
    );

    print('✅ HTTP transport created');
    print('📡 Base URL: http://localhost:8080');
    print('🔧 OAuth enabled');

    // Create client
    final client = Client(
      name: 'HTTP Demo Client',
      version: '1.0.0',
      capabilities: ClientCapabilities(
        roots: true,
        rootsListChanged: true,
        sampling: true,
      ),
    );

    // Demonstrate connection with retry
    print('🔄 Attempting connection...');
    try {
      await client.connect(transport);
      print('✅ Connected to HTTP server');
    } catch (e) {
      print('⚠️  HTTP connection demo (server not running): $e');
    }
  } catch (e) {
    print('⚠️  HTTP transport demo completed: $e');
  }
}

/// Demonstrate enhanced tool usage with annotations
Future<void> _demonstrateEnhancedTools() async {
  print('\n🔧 === Enhanced Tools Example ===');

  try {
    // Create client for tool demonstration
    final client = Client(name: 'Tools Demo Client', version: '1.0.0');

    // Mock transport with tool responses
    final mockTransport = MockToolTransport();

    try {
      await client.connect(mockTransport);
      print('✅ Connected for tools demo');

      // List tools with enhanced information
      print('\n📋 Listing enhanced tools...');
      final tools = await client.listTools();

      for (final tool in tools) {
        print('\n🔧 Tool: ${tool.name}');
        print('   Description: ${tool.description}');

        print('   Input Schema: ${tool.inputSchema}');
      }

      // Call tool
      print('\n⚡ Calling tool...');
      final result = await client.callTool('process_data', {'items': 100});

      print('   Result: ${result.content.length} content items');

      // Note: Progress tracking and cancellation are handled via notifications
      print('\n📊 Progress tracking is handled via protocol notifications');
    } catch (e) {
      print('ℹ️  Tools demo completed (mock responses): $e');
    }
  } catch (e) {
    print('⚠️  Enhanced tools demo completed: $e');
  }
}

/// Demonstrate resource templates
Future<void> _demonstrateResourceTemplates() async {
  print('\n📁 === Resource Templates Example ===');

  try {
    final client = Client(name: 'Resources Demo Client', version: '1.0.0');

    final mockTransport = MockResourceTransport();

    try {
      await client.connect(mockTransport);

      // List resource templates
      print('📋 Listing resource templates...');
      final templates = await client.listResourceTemplates();

      for (final template in templates) {
        print('\n📂 Template: ${template.name}');
        print('   URI Template: ${template.uriTemplate}');
        print('   Description: ${template.description}');
        print('   MIME Type: ${template.mimeType}');
      }

      // Read resources using template URIs
      print('\n🔍 Accessing resource...');
      final result = await client.readResource('file:///example.txt');

      print('✅ Resource accessed:');
      for (final content in result.contents) {
        print('   URI: ${content.uri}');
        print('   Type: ${content.mimeType}');
        print('   Content length: ${content.text?.length ?? 0} chars');
      }

      // Note: Resource subscriptions are handled via notifications
      print('\n🔔 Resource notifications would be handled via:');
      print('   - onResourceUpdated callbacks');
      print('   - Resource list changed notifications');
    } catch (e) {
      print('ℹ️  Resources demo completed (mock responses): $e');
    }
  } catch (e) {
    print('⚠️  Resource templates demo completed: $e');
  }
}

/// Demonstrate progress reporting and cancellation
Future<void> _demonstrateProgressAndCancellation() async {
  print('\n📊 === Progress & Cancellation Example ===');

  try {
    final client = Client(name: 'Progress Demo Client', version: '1.0.0');

    // Mock transport that simulates progress
    final mockTransport = MockProgressTransport();

    try {
      await client.connect(mockTransport);

      print('🚀 Starting long-running operation...');

      // Start operation
      final resultFuture = client.callTool(
        'long_operation',
        {'duration': 5000}, // 5 second operation
      );

      // Simulate progress display
      final progressTimer = Timer.periodic(const Duration(milliseconds: 500), (
        timer,
      ) {
        if (timer.tick >= 10) {
          timer.cancel();
          print('✅ Timer completed');
        } else {
          final percentage = (timer.tick * 10).toStringAsFixed(0);
          print('📈 Progress: $percentage%');
        }
      });

      // Wait for operation
      final result = await resultFuture;
      progressTimer.cancel();

      print('✅ Operation completed');
      print('   Result: ${result.content.length} content items');
    } catch (e) {
      print('ℹ️  Progress demo completed (mock responses): $e');
    }
  } catch (e) {
    print('⚠️  Progress & cancellation demo completed: $e');
  }
}

/// Mock transport for tool demonstration
class MockToolTransport implements ClientTransport {
  final StreamController<dynamic> _messageController =
      StreamController.broadcast();
  final _closeCompleter = Completer<void>();

  @override
  Stream<dynamic> get onMessage => _messageController.stream;

  @override
  Future<void> get onClose => _closeCompleter.future;

  @override
  void send(dynamic message) {
    final method = message['method'] as String;
    final id = message['id'];

    switch (method) {
      case 'initialize':
        _messageController.add({
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'protocolVersion': '2025-03-26',
            'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
            'capabilities': {'tools': {}},
          },
        });
        break;

      case 'tools/list':
        _messageController.add({
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'tools': [
              {
                'name': 'process_data',
                'description': 'Process data with progress tracking',
                'inputSchema': {
                  'type': 'object',
                  'properties': {
                    'items': {'type': 'integer'},
                  },
                },
              },
            ],
          },
        });
        break;

      case 'tools/call':
        _messageController.add({
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'content': [
              {'type': 'text', 'text': 'Processing completed successfully'},
            ],
          },
        });
        break;
    }
  }

  @override
  void close() {
    if (!_closeCompleter.isCompleted) {
      _closeCompleter.complete();
    }
    _messageController.close();
  }
}

/// Mock transport for resource demonstration
class MockResourceTransport implements ClientTransport {
  final StreamController<dynamic> _messageController =
      StreamController.broadcast();
  final _closeCompleter = Completer<void>();

  @override
  Stream<dynamic> get onMessage => _messageController.stream;

  @override
  Future<void> get onClose => _closeCompleter.future;

  @override
  void send(dynamic message) {
    final method = message['method'] as String;
    final id = message['id'];

    switch (method) {
      case 'initialize':
        _messageController.add({
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'protocolVersion': '2025-03-26',
            'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
            'capabilities': {
              'resources': {'subscribe': true},
            },
          },
        });
        break;

      case 'resources/templates/list':
        _messageController.add({
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'resourceTemplates': [
              {
                'uriTemplate': 'file:///{path}',
                'name': 'File System',
                'description': 'Access local files',
                'mimeType': 'text/plain',
              },
              {
                'uriTemplate': 'api://v1/{endpoint}',
                'name': 'API Access',
                'description': 'Access API endpoints',
                'mimeType': 'application/json',
              },
            ],
          },
        });
        break;

      case 'resources/read':
        _messageController.add({
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'contents': [
              {
                'uri': 'file:///example.txt',
                'mimeType': 'text/plain',
                'text':
                    'This is example file content from the resource template.',
              },
            ],
          },
        });
        break;
    }
  }

  @override
  void close() {
    if (!_closeCompleter.isCompleted) {
      _closeCompleter.complete();
    }
    _messageController.close();
  }
}

/// Mock transport for progress demonstration
class MockProgressTransport implements ClientTransport {
  final StreamController<dynamic> _messageController =
      StreamController.broadcast();
  final _closeCompleter = Completer<void>();

  @override
  Stream<dynamic> get onMessage => _messageController.stream;

  @override
  Future<void> get onClose => _closeCompleter.future;

  @override
  void send(dynamic message) {
    final method = message['method'] as String;
    final id = message['id'];

    switch (method) {
      case 'initialize':
        _messageController.add({
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'protocolVersion': '2025-03-26',
            'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
            'capabilities': {'tools': {}},
          },
        });
        break;

      case 'tools/call':
        // Send initial response
        _messageController.add({
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'content': [
              {'type': 'text', 'text': 'Long operation completed'},
            ],
          },
        });

        // Simulate progress notifications
        Timer.periodic(const Duration(milliseconds: 200), (timer) {
          if (timer.tick > 5) {
            timer.cancel();
            return;
          }

          final progress = timer.tick / 5.0;
          _messageController.add({
            'jsonrpc': '2.0',
            'method': 'notifications/progress',
            'params': {
              'requestId': id,
              'progress': progress,
              'message': 'Step ${timer.tick} of 5 completed',
            },
          });
        });
        break;
    }
  }

  @override
  void close() {
    if (!_closeCompleter.isCompleted) {
      _closeCompleter.complete();
    }
    _messageController.close();
  }
}
