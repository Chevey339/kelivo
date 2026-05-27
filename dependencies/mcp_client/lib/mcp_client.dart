import 'package:meta/meta.dart';
import 'package:logging/logging.dart';

import 'src/client/client.dart';
import 'src/transport/transport.dart';
import 'src/transport/streamable_http_transport.dart';
import 'src/transport/sse_auth_transport.dart';
import 'src/transport/sse_compressed_transport.dart';
import 'src/transport/sse_heartbeat_transport.dart';
import 'src/common/result.dart';
import 'src/models/models.dart';
import 'src/auth/oauth.dart';

export 'src/models/models.dart';
export 'src/client/client.dart';
export 'src/transport/transport.dart';
export 'src/transport/streamable_http_transport.dart';
export 'src/transport/sse_auth_transport.dart';
export 'src/transport/sse_compressed_transport.dart';
export 'src/transport/sse_heartbeat_transport.dart';
export 'src/protocol/protocol.dart';
export 'src/auth/oauth.dart';
export 'src/auth/oauth_client.dart';
export 'src/common/result.dart';
export 'src/common/connection_state.dart';
export 'logger.dart';

/// Configuration for creating MCP clients
@immutable
class McpClientConfig {
  /// The name of the client application
  final String name;

  /// The version of the client application
  final String version;

  /// The capabilities supported by the client
  final ClientCapabilities capabilities;

  /// Maximum number of connection retry attempts
  final int maxRetries;

  /// Delay between connection retry attempts
  final Duration retryDelay;

  /// Timeout for individual requests
  final Duration requestTimeout;

  /// Whether to enable debug logging
  final bool enableDebugLogging;

  const McpClientConfig({
    required this.name,
    required this.version,
    this.capabilities = const ClientCapabilities(),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.requestTimeout = const Duration(seconds: 30),
    this.enableDebugLogging = false,
  });

  /// Creates a copy of this config with the given fields replaced
  McpClientConfig copyWith({
    String? name,
    String? version,
    ClientCapabilities? capabilities,
    int? maxRetries,
    Duration? retryDelay,
    Duration? requestTimeout,
    bool? enableDebugLogging,
  }) {
    return McpClientConfig(
      name: name ?? this.name,
      version: version ?? this.version,
      capabilities: capabilities ?? this.capabilities,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      enableDebugLogging: enableDebugLogging ?? this.enableDebugLogging,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is McpClientConfig &&
          name == other.name &&
          version == other.version &&
          capabilities == other.capabilities &&
          maxRetries == other.maxRetries &&
          retryDelay == other.retryDelay &&
          requestTimeout == other.requestTimeout &&
          enableDebugLogging == other.enableDebugLogging;

  @override
  int get hashCode => Object.hash(
    name,
    version,
    capabilities,
    maxRetries,
    retryDelay,
    requestTimeout,
    enableDebugLogging,
  );

  @override
  String toString() =>
      'McpClientConfig('
      'name: $name, '
      'version: $version, '
      'capabilities: $capabilities, '
      'maxRetries: $maxRetries, '
      'retryDelay: $retryDelay, '
      'requestTimeout: $requestTimeout, '
      'enableDebugLogging: $enableDebugLogging)';
}

/// Configuration for transport connections
@immutable
sealed class TransportConfig {
  const TransportConfig();

  /// Configuration for STDIO transport
  const factory TransportConfig.stdio({
    required String command,
    List<String> arguments,
    String? workingDirectory,
    Map<String, String>? environment,
  }) = StdioTransportConfig;

  /// Configuration for SSE transport with all features
  const factory TransportConfig.sse({
    required String serverUrl,
    Map<String, String>? headers,
    Duration? connectionTimeout,
    Duration? heartbeatInterval,
    OAuthConfig? oauthConfig,
    OAuthToken? oauthToken,
    String? bearerToken,
    bool enableCompression,
    bool enableGzip,
    bool enableDeflate,
    int compressionLevel,
    int maxMissedHeartbeats,
  }) = SseTransportConfig;

  /// Configuration for Streamable HTTP transport with all features
  const factory TransportConfig.streamableHttp({
    required String baseUrl,
    Map<String, String>? headers,
    Duration? timeout,
    int? maxConcurrentRequests,
    bool? useHttp2,
    OAuthConfig? oauthConfig,
    bool enableCompression,
    Duration? heartbeatInterval,
    int maxMissedHeartbeats,
    bool
    terminateOnClose, // Whether to send DELETE on disconnect (default: true)
  }) = StreamableHttpTransportConfig;
}

@immutable
final class StdioTransportConfig extends TransportConfig {
  final String command;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String>? environment;

  const StdioTransportConfig({
    required this.command,
    this.arguments = const [],
    this.workingDirectory,
    this.environment,
  });
}

@immutable
final class SseTransportConfig extends TransportConfig {
  final String serverUrl;
  final Map<String, String>? headers;
  final Duration? connectionTimeout;
  final Duration? heartbeatInterval;
  final OAuthConfig? oauthConfig;
  final OAuthToken? oauthToken;
  final String? bearerToken;
  final bool enableCompression;
  final bool enableGzip;
  final bool enableDeflate;
  final int compressionLevel;
  final int maxMissedHeartbeats;

  const SseTransportConfig({
    required this.serverUrl,
    this.headers,
    this.connectionTimeout,
    this.heartbeatInterval,
    this.oauthConfig,
    this.oauthToken,
    this.bearerToken,
    this.enableCompression = false,
    this.enableGzip = true,
    this.enableDeflate = true,
    this.compressionLevel = 6,
    this.maxMissedHeartbeats = 3,
  });
}

@immutable
final class StreamableHttpTransportConfig extends TransportConfig {
  final String baseUrl;
  final Map<String, String>? headers;
  final Duration? timeout;
  final int? maxConcurrentRequests;
  final bool? useHttp2;
  final OAuthConfig? oauthConfig;
  final bool enableCompression;
  final Duration? heartbeatInterval;
  final int maxMissedHeartbeats;
  final bool terminateOnClose;

  const StreamableHttpTransportConfig({
    required this.baseUrl,
    this.headers,
    this.timeout,
    this.maxConcurrentRequests,
    this.useHttp2,
    this.oauthConfig,
    this.enableCompression = false,
    this.heartbeatInterval,
    this.maxMissedHeartbeats = 3,
    this.terminateOnClose = true, // Default: true for backward compatibility
  });
}

typedef MCPClient = McpClient;

/// Modern MCP Client factory with enhanced error handling and configuration
@immutable
class McpClient {
  const McpClient._();

  /// Create a new MCP client with the specified configuration
  static Client createClient(McpClientConfig config) {
    if (config.enableDebugLogging) {
      Logger.root.level = Level.FINE;
    }

    return Client(
      name: config.name,
      version: config.version,
      capabilities: config.capabilities,
      requestTimeout: config.requestTimeout,
    );
  }

  /// Create and connect a client using the provided configuration
  static Future<Result<Client, Exception>> createAndConnect({
    required McpClientConfig config,
    required TransportConfig transportConfig,
  }) async {
    return Results.catchingAsync(() async {
      final client = createClient(config);
      final transport = await _createTransport(transportConfig);

      await client.connectWithRetry(
        transport,
        maxRetries: config.maxRetries,
        delay: config.retryDelay,
      );

      return client;
    });
  }

  /// Create a transport from the given configuration
  static Future<ClientTransport> _createTransport(TransportConfig config) {
    return switch (config) {
      StdioTransportConfig(
        command: final command,
        arguments: final arguments,
        workingDirectory: final workingDirectory,
        environment: final environment,
      ) =>
        StdioClientTransport.create(
          command: command,
          arguments: arguments,
          workingDirectory: workingDirectory,
          environment: environment,
        ),
      SseTransportConfig(
        serverUrl: final serverUrl,
        headers: final headers,
        oauthConfig: final oauthConfig,
        oauthToken: final oauthToken,
        bearerToken: final bearerToken,
        enableCompression: final enableCompression,
        heartbeatInterval: final heartbeatInterval,
        maxMissedHeartbeats: final maxMissedHeartbeats,
      ) =>
        _createUnifiedSseTransport(
          serverUrl: serverUrl,
          headers: headers,
          oauthConfig: oauthConfig,
          oauthToken: oauthToken,
          bearerToken: bearerToken,
          enableCompression: enableCompression,
          heartbeatInterval: heartbeatInterval,
          maxMissedHeartbeats: maxMissedHeartbeats,
        ),
      StreamableHttpTransportConfig(
        baseUrl: final baseUrl,
        headers: final headers,
        timeout: final timeout,
        maxConcurrentRequests: final maxConcurrentRequests,
        useHttp2: final useHttp2,
        oauthConfig: final oauthConfig,
        enableCompression: final _,
        heartbeatInterval: final _,
        maxMissedHeartbeats: final _,
        terminateOnClose: final terminateOnClose,
      ) =>
        StreamableHttpClientTransport.create(
          baseUrl: baseUrl,
          headers: headers,
          timeout: timeout,
          maxConcurrentRequests: maxConcurrentRequests,
          useHttp2: useHttp2,
          oauthConfig: oauthConfig,
          terminateOnClose: terminateOnClose,
        ),
    };
  }

  /// Create a unified SSE transport with all features
  static Future<ClientTransport> _createUnifiedSseTransport({
    required String serverUrl,
    Map<String, String>? headers,
    OAuthConfig? oauthConfig,
    OAuthToken? oauthToken,
    String? bearerToken,
    bool enableCompression = false,
    Duration? heartbeatInterval,
    int maxMissedHeartbeats = 3,
  }) async {
    // Determine which SSE transport to use based on features
    if (oauthConfig != null || oauthToken != null || bearerToken != null) {
      // Use OAuth-enabled SSE transport
      return await SseAuthClientTransport.create(
        serverUrl: serverUrl,
        headers: headers,
        oauthToken: oauthToken,
        bearerToken: bearerToken,
      );
    } else if (enableCompression) {
      // Use compression-enabled SSE transport
      return await SseCompressedClientTransport.create(
        serverUrl: serverUrl,
        headers: headers,
        supportedCompressions: [CompressionType.gzip, CompressionType.deflate],
      );
    } else if (heartbeatInterval != null) {
      // Use heartbeat-enabled SSE transport
      return await SseHeartbeatClientTransport.create(
        serverUrl: serverUrl,
        headers: headers,
        heartbeatConfig: HeartbeatConfig(
          interval: heartbeatInterval,
          maxMissedBeats: maxMissedHeartbeats,
        ),
      );
    } else {
      // Use basic SSE transport
      return await SseClientTransport.create(
        serverUrl: serverUrl,
        headers: headers,
      );
    }
  }

  /// Create a stdio transport with the given configuration
  static Future<Result<StdioClientTransport, Exception>> createStdioTransport({
    required String command,
    List<String> arguments = const [],
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    return Results.catchingAsync(
      () => StdioClientTransport.create(
        command: command,
        arguments: arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      ),
    );
  }

  /// Create an SSE transport with the given configuration
  static Future<Result<SseClientTransport, Exception>> createSseTransport({
    required String serverUrl,
    Map<String, String>? headers,
  }) {
    return Results.catchingAsync(
      () => SseClientTransport.create(serverUrl: serverUrl, headers: headers),
    );
  }

  /// Create a Streamable HTTP transport with the given configuration
  static Future<Result<StreamableHttpClientTransport, Exception>>
  createStreamableHttpTransport({
    required String baseUrl,
    Map<String, String>? headers,
    Duration? timeout,
    int? maxConcurrentRequests,
    bool? useHttp2,
  }) {
    return Results.catchingAsync(
      () => StreamableHttpClientTransport.create(
        baseUrl: baseUrl,
        headers: headers,
        timeout: timeout,
        maxConcurrentRequests: maxConcurrentRequests,
        useHttp2: useHttp2,
      ),
    );
  }

  /// Helper method to create a simple client configuration
  static McpClientConfig simpleConfig({
    required String name,
    required String version,
    bool enableDebugLogging = false,
    Duration? requestTimeout,
  }) {
    return McpClientConfig(
      name: name,
      version: version,
      enableDebugLogging: enableDebugLogging,
      requestTimeout: requestTimeout ?? const Duration(seconds: 30),
    );
  }

  /// Helper method to create a production-ready client configuration
  static McpClientConfig productionConfig({
    required String name,
    required String version,
    ClientCapabilities? capabilities,
  }) {
    return McpClientConfig(
      name: name,
      version: version,
      capabilities: capabilities ?? const ClientCapabilities(),
      maxRetries: 5,
      retryDelay: const Duration(seconds: 1),
      requestTimeout: const Duration(seconds: 60),
      enableDebugLogging: false,
    );
  }
}
