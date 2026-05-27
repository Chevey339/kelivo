# MCP Client

A Dart plugin for implementing [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) clients. This plugin allows Flutter applications to connect with MCP servers and access data, functionality, and interaction patterns from Large Language Model (LLM) applications in a standardized way.

## Features

- **Multi-revision MCP support** with per-version capability negotiation — see _Protocol Versions_ below
- **Unified transport configuration** — sealed `TransportConfig` for stdio / SSE / Streamable HTTP
- **OAuth 2.1** — built-in authorization for secure HTTP transports
- **Result-typed error handling** — `Result<Client, Error>` from `createAndConnect`, plus `McpError` for spec error codes
- **Core MCP primitives**:
  - **Resources** — server data, URI templates, subscriptions
  - **Tools** — server-side functions, progress tracking, structured output (2025-06-18+)
  - **Prompts** — reusable interaction templates with completion (2025-06-18+)
  - **Roots** — filesystem boundary configuration; the server requests them via `roots/list`
  - **Sampling** — register a host LLM completion handler so the server can drive `sampling/createMessage`
  - **Elicitation** (2025-06-18) — register a user-input handler so the server can collect structured prompts
- **Advanced**:
  - **Deferred Tool Loading** — lightweight metadata + on-demand schema fetch (60–80% token reduction)
  - **Progress notifications** — outbound `notifications/progress` and inbound listener
  - **Cancellation** — `notifyCancelled(requestId, reason)` per spec notification
  - **Resource subscriptions** — `notifications/resources/updated`
  - **Session management** — automatic session validation and reconnection support
- **Cross-platform**: Android, iOS, web, Linux, Windows, macOS (web supports SSE + Streamable HTTP; stdio is native-only)

## Protocol Versions

Implements the Model Context Protocol specification across **four** revisions, with the negotiated version determining which features are advertised and which dispatch paths are taken.

| Version | Notes |
|---|---|
| `2024-11-05` | Original; JSON-RPC batching available |
| `2025-03-26` | Earlier 2025 revision; JSON-RPC batching available |
| `2025-06-18` | Adds elicitation, structured tool output, resource links, OAuth Resource Server, MCP-Protocol-Version header. Removes JSON-RPC batching |
| `2025-11-25` | Adds icons, sampling tool calling (`tools` / `toolChoice`), URL-mode elicitation, OIDC Discovery, Client ID Metadata Documents |

Runtime gates: `McpProtocol.supportsBatching(v)` / `supportsElicitation(v)` / `supportsStructuredToolOutput(v)` / `supportsIconsAndSamplingTools(v)` / `requiresProtocolHeader(v)`.

For details, see the [Model Context Protocol specification](https://spec.modelcontextprotocol.io).

## Getting Started

### Basic Usage

```dart
import 'package:mcp_client/mcp_client.dart';

void main() async {
  // Create client configuration
  final config = McpClient.simpleConfig(
    name: 'Example Client',
    version: '1.0.0',
    enableDebugLogging: true,
  );

  // Create transport configuration
  final transportConfig = TransportConfig.stdio(
    command: 'npx',
    arguments: ['-y', '@modelcontextprotocol/server-filesystem', '/path/to/allowed/directory'],
  );
  
  // Create and connect client
  final clientResult = await McpClient.createAndConnect(
    config: config,
    transportConfig: transportConfig,
  );
  
  final client = clientResult.fold(
    (c) => c,
    (error) => throw Exception('Failed to connect: $error'),
  );
  
  // List available tools on the server
  final tools = await client.listTools();
  print('Available tools: ${tools.map((t) => t.name).join(', ')}');
  
  // Call a tool
  final result = await client.callTool('calculator', {
    'operation': 'add',
    'a': 5,
    'b': 3,
  });
  print('Result: ${(result.content.first as TextContent).text}');
  
  // Disconnect when done
  client.disconnect();
}
```

## Core Concepts

### Client

The `Client` is your core interface to the MCP protocol. It handles connection management, protocol compliance, and message routing:

```dart
// Method 1: Using unified configuration
final config = McpClient.productionConfig(
  name: 'My App',
  version: '1.0.0',
  capabilities: ClientCapabilities(
    roots: true,
    rootsListChanged: true,
    sampling: true,
  ),
);

final clientResult = await McpClient.createAndConnect(
  config: config,
  transportConfig: transportConfig,
);

// Method 2: Manual client creation
final client = McpClient.createClient(config);
```
### Connection State Monitoring

Monitor the connection state with event streams:

```dart
// Listen for connection events
client.onConnect.listen((serverInfo) {
  _logger.info('Connected to ${serverInfo.name} v${serverInfo.version}');
  _logger.info('Protocol version: ${serverInfo.protocolVersion}');
  // Initialize your application after connection
});

// Listen for disconnection events
client.onDisconnect.listen((reason) {
  _logger.info('Disconnected: $reason');
  
  // Handle different disconnect reasons
  switch (reason) {
    case DisconnectReason.transportError:
      // Attempt reconnection
      break;
    case DisconnectReason.serverDisconnected:
      // Show notification to user
      break;
    case DisconnectReason.clientDisconnected:
      // Normal shutdown
      break;
  }
});

// Listen for error events
client.onError.listen((error) {
  _logger.error('Error: ${error.message}');
  // Log errors or show to user
});

// Clean up resources when done
client.dispose();
```

### Resources

Resources provide access to data from MCP servers. They're similar to GET endpoints in a REST API:

```dart
// List available resources
final resources = await client.listResources();
_logger.debug('Available resources: ${resources.map((r) => r.name).join(', ')}');

// Read a resource
final resourceResult = await client.readResource('file:///path/to/file.txt');
final content = resourceResult.contents.first;
_logger.debug('Resource content: ${content.text}');

// Get a resource using a template
final templateResult = await client.getResourceWithTemplate('file:///{path}', {
  'path': 'example.txt'
});
_logger.debug('Template result: ${templateResult.contents.first.text}');

// Subscribe to resource updates
await client.subscribeResource('file:///path/to/file.txt');
client.onResourceContentUpdated((uri, content) {
  _logger.debug('Resource updated: $uri');
  _logger.debug('New content: ${content.text}');
});

// Unsubscribe when no longer needed
await client.unsubscribeResource('file:///path/to/file.txt');
```

### Tools

Tools allow you to execute functionality exposed by MCP servers:

```dart
// List available tools
final tools = await client.listTools();
_logger.debug('Available tools: ${tools.map((t) => t.name).join(', ')}');

// Call a tool
final result = await client.callTool('search-web', {
  'query': 'Model Context Protocol',
  'maxResults': 5,
});

// Call a tool with progress tracking
final trackingResult = await client.callToolWithTracking('long-running-operation', {
  'parameter': 'value'
});
final operationId = trackingResult.operationId;

// Listen to inbound progress notifications from the server
client.onProgress((requestId, progress, message) {
  _logger.debug('Operation $requestId: $progress% - $message');
});

// Process the result
final content = result.content.first;
if (content is TextContent) {
  _logger.debug('Search results: ${content.text}');
}

// Cancel an in-flight request — emits the spec `notifications/cancelled`
client.notifyCancelled(operationId, reason: 'user requested');
```

### Prompts

Prompts are reusable templates provided by servers that help with common interactions:

```dart
// List available prompts
final prompts = await client.listPrompts();
_logger.debug('Available prompts: ${prompts.map((p) => p.name).join(', ')}');

// Get a prompt result
final promptResult = await client.getPrompt('analyze-code', {
  'code': 'function add(a, b) { return a + b; }',
  'language': 'javascript',
});

// Process the prompt messages
for (final message in promptResult.messages) {
  final content = message.content;
  if (content is TextContent) {
    _logger.debug('${message.role}: ${content.text}');
  }
}
```

### Roots

Roots scope the filesystem the server is allowed to operate on. Per spec, the server requests them from the client via `roots/list` — register them locally:

```dart
// Configure local roots — these are what the client returns when the server asks
client.addRoot(Root(
  uri: 'file:///path/to/allowed/directory',
  name: 'Project Files',
  description: 'Files for the current project',
));

// Inspect the locally-configured roots
_logger.debug('Configured roots: ${client.roots.map((r) => r.name).join(', ')}');

// Remove a root
client.removeRoot('file:///path/to/allowed/directory');

// Override the default `roots/list` response handler if you need custom behavior
client.onListRoots((req) async => ListRootsResult(roots: client.roots));
```

### Sampling

Sampling is **server-initiated** per the MCP spec. Register a handler that fulfils completion requests using your host LLM:

```dart
client.onSamplingRequest((request) async {
  // Forward to your LLM (e.g., via mcp_llm), then return the spec response shape.
  final reply = await myLlm.complete(request.messages);
  return CreateMessageResult(
    model: reply.model,
    role: 'assistant',
    content: TextContent(text: reply.text),
  );
});
```

### Elicitation (2025-06-18)

The server can request structured input from the user via `elicitation/create`. Register a handler:

```dart
client.onElicitationRequest((request) async {
  final answers = await ui.promptUser(request.message, schema: request.requestedSchema);
  return ElicitResult(action: 'accept', content: answers);
});
```

## Transport Layers

MCP Client supports multiple transport types with unified configuration. Each transport automatically supports advanced features like OAuth authentication, compression, and heartbeat monitoring.

### Standard I/O

For command-line tools and direct integrations:

```dart
// Method 1: Using createAndConnect
final config = McpClient.simpleConfig(name: 'STDIO Client', version: '1.0.0');
final transportConfig = TransportConfig.stdio(
  command: 'npx',
  arguments: ['-y', '@modelcontextprotocol/server-filesystem', '/path/to/allowed/directory'],
  workingDirectory: '/path/to/working/directory',
  environment: {'ENV_VAR': 'value'},
);

final clientResult = await McpClient.createAndConnect(
  config: config,
  transportConfig: transportConfig,
);

// Method 2: Manual transport creation
final transportResult = await McpClient.createStdioTransport(
  command: 'npx',
  arguments: ['-y', '@modelcontextprotocol/server-filesystem', '/path/to/allowed/directory'],
);
final transport = transportResult.fold((t) => t, (error) => throw error);
await client.connect(transport);
```

### Server-Sent Events (SSE)

For HTTP-based communication with enhanced features:

```dart
// Basic SSE transport
final transportConfig = TransportConfig.sse(
  serverUrl: 'http://localhost:8080/sse',
  headers: {'User-Agent': 'MCP-Client/1.0'},
);

// SSE with Bearer token authentication
final transportConfig = TransportConfig.sse(
  serverUrl: 'https://secure-api.example.com/sse',
  bearerToken: 'your-bearer-token',
  headers: {'User-Agent': 'MCP-Client/1.0'},
);

// SSE with OAuth authentication
final transportConfig = TransportConfig.sse(
  serverUrl: 'https://api.example.com/sse',
  oauthConfig: OAuthConfig(
    authorizationEndpoint: 'https://auth.example.com/authorize',
    tokenEndpoint: 'https://auth.example.com/token',
    clientId: 'your-client-id',
  ),
);

// SSE with compression
final transportConfig = TransportConfig.sse(
  serverUrl: 'http://localhost:8080/sse',
  enableCompression: true,
  enableGzip: true,
  enableDeflate: true,
);

// SSE with heartbeat monitoring
final transportConfig = TransportConfig.sse(
  serverUrl: 'http://localhost:8080/sse',
  heartbeatInterval: const Duration(seconds: 30),
  maxMissedHeartbeats: 3,
);

final clientResult = await McpClient.createAndConnect(
  config: config,
  transportConfig: transportConfig,
);
```

### Streamable HTTP Transport

For high-performance HTTP/2 communication:

```dart
// Basic HTTP transport
final transportConfig = TransportConfig.streamableHttp(
  baseUrl: 'https://api.example.com',
  headers: {'User-Agent': 'MCP-Client/1.0'},
);

// HTTP with all features
final transportConfig = TransportConfig.streamableHttp(
  baseUrl: 'https://api.example.com',
  headers: {'User-Agent': 'MCP-Client/1.0'},
  timeout: const Duration(seconds: 60),
  maxConcurrentRequests: 20,
  useHttp2: true,
  oauthConfig: OAuthConfig(
    authorizationEndpoint: 'https://auth.example.com/authorize',
    tokenEndpoint: 'https://auth.example.com/token',
    clientId: 'your-client-id',
  ),
  enableCompression: true,
  heartbeatInterval: const Duration(seconds: 60),
);

final clientResult = await McpClient.createAndConnect(
  config: config,
  transportConfig: transportConfig,
);
```

## Logging

The package uses the standard Dart logging package:

```dart
import 'package:logging/logging.dart';

// Set up logging
Logger.root.level = Level.INFO;
Logger.root.onRecord.listen((record) {
  print('${record.level.name}: ${record.time}: ${record.message}');
});

// Create logger for your component
final Logger _logger = Logger('mcp_client.example');

// Log messages at different levels
_logger.fine('Debugging information');
_logger.info('Important information');
_logger.warning('Warning message');
_logger.severe('Error message');

// Enable debug logging in client config
final config = McpClient.simpleConfig(
  name: 'My Client',
  version: '1.0.0',
  enableDebugLogging: true, // This enables detailed transport logging
);
```

## MCP Primitives

The MCP protocol defines three core primitives that clients can interact with:

| Primitive | Control               | Description                                         | Example Use                  |
|-----------|-----------------------|-----------------------------------------------------|------------------------------|
| Prompts   | User-controlled       | Interactive templates invoked by user choice        | Slash commands, menu options |
| Resources | Application-controlled| Contextual data managed by the client application   | File contents, API responses |
| Tools     | Model-controlled      | Functions exposed to the LLM to take actions        | API calls, data updates      |

## Advanced Usage

### Deferred Tool Loading

Reduce token usage by 60-80% when sending tool definitions to LLMs:

```dart
import 'package:mcp_client/mcp_client.dart';

// Create a tool registry for caching
final registry = ToolRegistry();

// Fetch lightweight metadata instead of full schemas
final metadata = await client.listToolsMetadata(registry);

// Send only name + description to LLM (token-efficient)
for (final tool in metadata) {
  print('${tool.name}: ${tool.description}');
}

// Later, get full schema when needed for validation/execution
final fullSchema = registry.getSchema('calculator');
print('Full schema: $fullSchema');

// Invalidate cache when tools change
client.onToolsListChanged(() {
  registry.invalidateAll();
});
```

### Event Handling

Register for server-side notifications:

```dart
// Handle tools list changes
client.onToolsListChanged(() {
  _logger.debug('Tools list has changed');
  client.listTools().then((tools) {
    _logger.debug('New tools: ${tools.map((t) => t.name).join(', ')}');
  });
});

// Handle resources list changes
client.onResourcesListChanged(() {
  _logger.debug('Resources list has changed');
  client.listResources().then((resources) {
    _logger.debug('New resources: ${resources.map((r) => r.name).join(', ')}');
  });
});

// Handle prompts list changes
client.onPromptsListChanged(() {
  _logger.debug('Prompts list has changed');
  client.listPrompts().then((prompts) {
    _logger.debug('New prompts: ${prompts.map((p) => p.name).join(', ')}');
  });
});

// Handle server logging
client.onLogging((level, message, logger, data) {
  _logger.debug('Server log [$level]${logger != null ? " [$logger]" : ""}: $message');
  if (data != null) {
    _logger.debug('Additional data: $data');
  }
});
```

### Error Handling

The library uses Result types for robust error handling:

```dart
// Using createAndConnect with Result handling
final clientResult = await McpClient.createAndConnect(
  config: config,
  transportConfig: transportConfig,
);

final client = clientResult.fold(
  (client) {
    print('Successfully connected');
    return client;
  },
  (error) {
    print('Connection failed: $error');
    throw error;
  },
);

// Transport creation with Result handling
final transportResult = await McpClient.createStdioTransport(
  command: 'npx',
  arguments: ['-y', '@modelcontextprotocol/server-filesystem'],
);

await transportResult.fold(
  (transport) async {
    await client.connect(transport);
    print('Connected successfully');
  },
  (error) {
    print('Transport creation failed: $error');
  },
);

// Traditional try-catch for MCP protocol errors
try {
  await client.callTool('unknown-tool', {});
} on McpError catch (e) {
  print('MCP error (${e.code}): ${e.message}');
} catch (e) {
  print('Unexpected error: $e');
}
```

## Additional Examples

Check out the [example](https://github.com/app-appplayer/mcp_client/tree/main/example) directory for a complete sample application.

## Resources

- [Model Context Protocol documentation](https://modelcontextprotocol.io)
- [Model Context Protocol specification](https://spec.modelcontextprotocol.io)
- [Officially supported servers](https://github.com/modelcontextprotocol/servers)

## Issues and Feedback

Please file any issues, bugs, or feature requests in our [issue tracker](https://github.com/app-appplayer/mcp_client/issues).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.