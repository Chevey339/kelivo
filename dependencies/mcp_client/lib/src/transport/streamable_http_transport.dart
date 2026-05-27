/// Streamable HTTP transport for MCP 2025-03-26
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../../logger.dart';
import '../auth/oauth.dart';
import '../auth/oauth_client.dart';
import '../models/models.dart';
import '../protocol/protocol.dart';
import 'event_source.dart';
import 'transport.dart';

final Logger _logger = Logger('mcp_client.streamable_http_transport');

/// HTTP transport configuration
@immutable
class StreamableHttpTransportConfig {
  /// Base URL for the MCP server
  final String baseUrl;

  /// OAuth configuration (optional)
  final OAuthConfig? oauthConfig;

  /// Additional headers to send with requests
  final Map<String, String> headers;

  /// Request timeout
  final Duration timeout;

  /// SSE read timeout (longer for streaming)
  final Duration sseReadTimeout;

  /// Maximum number of concurrent requests
  final int maxConcurrentRequests;

  /// Whether to use HTTP/2 if available
  final bool useHttp2;

  /// Whether to terminate session on close
  final bool terminateOnClose;

  const StreamableHttpTransportConfig({
    required this.baseUrl,
    this.oauthConfig,
    this.headers = const {},
    this.timeout = const Duration(seconds: 30),
    this.sseReadTimeout = const Duration(minutes: 5),
    this.maxConcurrentRequests = 10,
    this.useHttp2 = true,
    this.terminateOnClose = true,
  });
}

/// Streamable HTTP client transport for MCP
class StreamableHttpClientTransport implements ClientTransport {
  final StreamableHttpTransportConfig config;
  final http.Client _httpClient;
  final HttpOAuthClient? _oauthClient;
  final OAuthTokenManager? _tokenManager;

  final StreamController<dynamic> _messageController =
      StreamController.broadcast();
  final Completer<void> _closeCompleter = Completer<void>();

  bool _isClosed = false;
  final Semaphore _requestSemaphore;
  String? _sessionId;
  String? _protocolVersion;
  final Map<int, Completer<dynamic>> _pendingRequests = {};
  EventSource? _eventSource;
  StreamSubscription? _sseSubscription;
  bool _getStreamActive = false;

  StreamableHttpClientTransport._({
    required this.config,
    required http.Client httpClient,
    HttpOAuthClient? oauthClient,
    OAuthTokenManager? tokenManager,
  }) : _httpClient = httpClient,
       _oauthClient = oauthClient,
       _tokenManager = tokenManager,
       _requestSemaphore = Semaphore(config.maxConcurrentRequests);

  /// Spec 2025-06-18+: record the negotiated MCP protocol version so
  /// every post-handshake HTTP request carries
  /// `MCP-Protocol-Version: <version>`.
  void setProtocolVersion(String version) {
    _protocolVersion = version;
  }

  /// Create a new Streamable HTTP transport
  static Future<StreamableHttpClientTransport> create({
    required String baseUrl,
    OAuthConfig? oauthConfig,
    Map<String, String>? headers,
    Duration? timeout,
    int? maxConcurrentRequests,
    bool? useHttp2,
    http.Client? httpClient,
    bool terminateOnClose = true,  // Default: true for backward compatibility
  }) async {
    final config = StreamableHttpTransportConfig(
      baseUrl: baseUrl,
      oauthConfig: oauthConfig,
      headers: headers ?? const {},
      timeout: timeout ?? const Duration(seconds: 30),
      maxConcurrentRequests: maxConcurrentRequests ?? 10,
      useHttp2: useHttp2 ?? true,
      terminateOnClose: terminateOnClose,
    );

    final client =
        httpClient ??
        (config.useHttp2
            ? http.Client()
            : // Use default client
            http.Client());

    HttpOAuthClient? oauthClient;
    OAuthTokenManager? tokenManager;

    if (oauthConfig != null) {
      oauthClient = HttpOAuthClient(config: oauthConfig, httpClient: client);
      tokenManager = OAuthTokenManager(oauthClient);
    }

    return StreamableHttpClientTransport._(
      config: config,
      httpClient: client,
      oauthClient: oauthClient,
      tokenManager: tokenManager,
    );
  }

  @override
  Stream<dynamic> get onMessage => _messageController.stream;

  @override
  Future<void> get onClose => _closeCompleter.future;

  /// Get the base URL
  String get baseUrl => config.baseUrl;

  /// Get the maximum concurrent requests
  int get maxConcurrentRequests => config.maxConcurrentRequests;

  /// Check if HTTP/2 is enabled
  bool get useHttp2 => config.useHttp2;

  /// Get the OAuth configuration
  OAuthConfig? get oauthConfig => config.oauthConfig;

  /// Get the current session ID
  String? get sessionId => _sessionId;

  /// Send a JSON-RPC message
  @override
  void send(dynamic message) {
    if (_isClosed) return;

    // Check if this is the initialized notification
    if (message is Map &&
        message['method'] == 'notifications/initialized' &&
        !_getStreamActive) {
      _startGetStream();
    }

    _sendRequest(message).catchError((error) {
      _messageController.addError(error);
    });
  }

  /// Send HTTP request with proper authentication
  Future<void> _sendRequest(dynamic message) async {
    // Check if transport is closed before sending
    if (_isClosed) {
      _logger.debug('Transport closed, ignoring request');
      return;
    }

    await _requestSemaphore.acquire();

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        // StreamableHTTP standard requires accepting both content types
        'Accept': 'application/json, text/event-stream',
        ...config.headers,
      };

      // Add session ID if available
      if (_sessionId != null) {
        headers['MCP-Session-Id'] = _sessionId!;
      }

      // Spec 2025-06-18+: every post-handshake HTTP request MUST carry
      // the negotiated protocol version. Older revisions ignore this
      // header. Set via [setProtocolVersion] after initialize.
      if (_protocolVersion != null &&
          McpProtocol.requiresProtocolHeader(_protocolVersion!)) {
        headers['MCP-Protocol-Version'] = _protocolVersion!;
      }

      // Add OAuth token if available
      if (_tokenManager != null) {
        try {
          final token = await _tokenManager.getAccessToken();
          headers['Authorization'] = 'Bearer $token';
        } on OAuthError catch (e) {
          if (e.error == 'no_valid_token') {
            // Send 401 to trigger OAuth flow
            _messageController.add({
              'jsonrpc': '2.0',
              'error': {
                'code': -32001,
                'message': 'Authentication required',
                'data': {'oauth_error': e.toJson()},
              },
              if (message is Map && message['id'] != null) 'id': message['id'],
            });
            return;
          }
          rethrow;
        }
      }

      final body = jsonEncode(message);
      final uri = Uri.parse(config.baseUrl);

      // Store request ID if this is a request
      int? requestId;
      if (message is Map && message['id'] != null) {
        requestId = message['id'] as int;
        _pendingRequests[requestId] = Completer<dynamic>();
      }

      // Build a streamed request so SSE responses can be read live.
      //
      // FastMCP routes server-initiated requests
      // (`sampling/createMessage`, `elicitation/create`) on the in-flight
      // POST's SSE response stream — not the standalone GET stream — and
      // those requests fire mid-tool-call. Buffering the body via
      // `httpClient.post(...).bodyBytes` deadlocks: the server holds the
      // SSE response open waiting for our reply to a server-initiated
      // request, but we can't see the request until the stream closes.
      // Streaming the response while it's open lets us dispatch each SSE
      // event the moment it arrives.
      final request = http.Request('POST', uri)
        ..body = body;
      headers.forEach((k, v) => request.headers[k] = v);

      final response =
          await _httpClient.send(request).timeout(config.timeout);

      // Extract session ID from response headers
      final newSessionId = response.headers['mcp-session-id'];
      if (newSessionId != null && newSessionId != _sessionId) {
        _sessionId = newSessionId;
        _logger.debug('Received session ID: $_sessionId');
      }

      if (response.statusCode == 202) {
        // 202 Accepted - no immediate response expected
        _logger.debug('Received 202 Accepted');
        // Drain any stray bytes so the connection can be released.
        await response.stream.drain<void>();
        return;
      }

      if (response.statusCode == 404) {
        // Session terminated
        if (requestId != null) {
          _messageController.add({
            'jsonrpc': '2.0',
            'id': requestId,
            'error': {'code': 32600, 'message': 'Session terminated'},
          });
        }
        await response.stream.drain<void>();
        return;
      }

      if (response.statusCode == 401) {
        // Authentication required - trigger OAuth flow
        _messageController.add({
          'jsonrpc': '2.0',
          'error': {
            'code': -32001,
            'message': 'Authentication required',
            'data': {
              'www_authenticate': response.headers['www-authenticate'],
              'oauth_config_hint': config.oauthConfig?.toJson(),
            },
          },
          if (requestId != null) 'id': requestId,
        });
        await response.stream.drain<void>();
        return;
      }

      if (response.statusCode >= 400) {
        // Buffer the error body for the exception message.
        final errorBody = await response.stream.bytesToString();
        throw McpError(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}'
          '${errorBody.isEmpty ? '' : ' — $errorBody'}',
        );
      }

      // Check content type
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';

      if (contentType.startsWith('application/json')) {
        // Direct JSON response - read the entire body, decode as UTF-8.
        final responseBody = await response.stream.bytesToString();
        if (responseBody.isNotEmpty) {
          final responseMessage = jsonDecode(responseBody);
          _messageController.add(responseMessage);
        }
      } else if (contentType.startsWith('text/event-stream')) {
        // SSE response — process each event as it arrives so
        // server-initiated requests embedded in this stream don't have
        // to wait for the whole tool call to finish.
        await _handleStreamedSseResponse(response, requestId);
      } else {
        _logger.warning('Unexpected content type: $contentType');
        // Try to parse as JSON anyway - read full body
        final responseBody = await response.stream.bytesToString();
        if (responseBody.isNotEmpty) {
          try {
            final responseMessage = jsonDecode(responseBody);
            _messageController.add(responseMessage);
          } catch (e) {
            _logger.error('Failed to parse response: $e');
          }
        }
      }
    } finally {
      _requestSemaphore.release();
    }
  }

  /// Handle a streamed SSE response from a POST request, dispatching
  /// each event as it arrives. Required for cases where the server
  /// embeds server-initiated requests (`sampling/createMessage`,
  /// `elicitation/create`) in the response stream and waits for the
  /// client's reply before producing the final tool result — buffering
  /// the body would deadlock.
  Future<void> _handleStreamedSseResponse(
    http.StreamedResponse response,
    int? requestId,
  ) async {
    _logger.debug('Handling streamed SSE response');
    final lineStream = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty || data == '[DONE]') continue;
      try {
        final decoded = jsonDecode(data);
        _messageController.add(decoded);
      } catch (e) {
        _logger.debug('Failed to parse SSE data: $data');
      }
    }
  }

  /// Start GET stream for server-initiated messages
  void _startGetStream() {
    if (_getStreamActive || _sessionId == null) return;

    _getStreamActive = true;
    _logger.debug('Starting GET stream for session: $_sessionId');

    _establishGetStream().catchError((error) {
      _logger.error('GET stream error: $error');
      _getStreamActive = false;
    });
  }

  /// Establish SSE GET stream
  Future<void> _establishGetStream() async {
    try {
      final uri = Uri.parse(config.baseUrl);
      
      // Set up headers
      final headers = <String, String>{
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        ...config.headers,
      };
      
      if (_sessionId != null) {
        headers['MCP-Session-Id'] = _sessionId!;
      }

      // Add OAuth token if available
      if (_tokenManager != null) {
        try {
          final token = await _tokenManager.getAccessToken();
          headers['Authorization'] = 'Bearer $token';
        } catch (e) {
          _logger.debug('Failed to add OAuth token to GET stream: $e');
        }
      }

      // Create EventSource instance
      _eventSource = EventSource();
      
      // Connect to SSE endpoint
      await _eventSource!.connect(
        uri.toString(),
        headers: headers,
        onOpen: (_) {
          _logger.debug('GET SSE connection established');
        },
        onMessage: (data) {
          if (data is Map) {
            _logger.debug('Received SSE message: $data');
            _messageController.add(data);
          } else if (data is String) {
            try {
              final message = jsonDecode(data);
              _logger.debug('Received SSE message: $message');
              _messageController.add(message);
            } catch (e) {
              _logger.debug('Failed to parse SSE message: $data');
            }
          }
        },
        onError: (error) {
          _logger.error('GET stream error: $error');
          _getStreamActive = false;
        },
      );
    } catch (e) {
      _logger.error('Failed to establish GET stream: $e');
      _getStreamActive = false;
      rethrow;
    }
  }


  @override
  void close() {
    if (_isClosed) return;
    _isClosed = true;

    // Terminate session if configured
    if (config.terminateOnClose && _sessionId != null) {
      _terminateSession().catchError((error) {
        _logger.debug('Failed to terminate session: $error');
      });
    }

    // Close GET stream
    _sseSubscription?.cancel();
    _eventSource?.close();

    // Clear pending requests without completing them with error
    // to avoid unhandled exceptions during shutdown
    _pendingRequests.clear();

    _messageController.close();
    _httpClient.close();
    _oauthClient?.close();
    _tokenManager?.dispose();

    if (!_closeCompleter.isCompleted) {
      _closeCompleter.complete();
    }
  }

  /// Terminate the session
  Future<void> _terminateSession() async {
    if (_sessionId == null) return;

    try {
      final headers = <String, String>{
        'MCP-Session-Id': _sessionId!,
        ...config.headers,
      };

      final uri = Uri.parse(config.baseUrl);
      final response = await _httpClient
          .delete(uri, headers: headers)
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 405) {
        _logger.debug('Server does not allow session termination');
      } else if (response.statusCode != 200 && response.statusCode != 204) {
        _logger.warning('Session termination failed: ${response.statusCode}');
      }
    } catch (e) {
      _logger.warning('Session termination failed: $e');
    }
  }

  /// Initiate OAuth authentication flow
  Future<OAuthToken> authenticateWithOAuth({
    required List<String> scopes,
    String? state,
  }) async {
    if (_oauthClient == null) {
      throw StateError('OAuth not configured for this transport');
    }

    final authUrl = await _oauthClient.getAuthorizationUrl(
      scopes: scopes,
      state: state,
    );

    // In a real implementation, you would:
    // 1. Open the auth URL in a browser
    // 2. Handle the redirect
    // 3. Extract the authorization code
    // 4. Exchange it for a token

    throw UnimplementedError(
      'OAuth flow requires platform-specific implementation. '
      'Authorization URL: $authUrl',
    );
  }

  /// Set OAuth token manually
  void setOAuthToken(OAuthToken token) {
    _tokenManager?.setToken(token);
  }
}

/// Semaphore for controlling concurrent requests
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}
