/// Streamable HTTP transport for MCP 2025-03-26 and later.
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

@immutable
class StreamableHttpTransportConfig {
  final String baseUrl;
  final OAuthConfig? oauthConfig;
  final Map<String, String> headers;
  final Duration timeout;
  final Duration sseReadTimeout;
  final int maxConcurrentRequests;
  final bool useHttp2;
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

class StreamableHttpClientTransport implements ClientTransport {
  static const Duration _minimumReconnectDelay = Duration(seconds: 1);
  static const Duration _defaultReconnectDelay = Duration(seconds: 1);
  static const Duration _authenticationRetryDelay = Duration(minutes: 5);
  static const Set<String> _reservedHeaders = {
    'accept',
    'content-type',
    'last-event-id',
    'mcp-protocol-version',
    'mcp-session-id',
  };

  final StreamableHttpTransportConfig config;
  final http.Client _httpClient;
  final HttpOAuthClient? _oauthClient;
  final OAuthTokenManager? _tokenManager;
  final StreamController<dynamic> _messageController =
      StreamController<dynamic>.broadcast();
  final Completer<void> _closeCompleter = Completer<void>();
  final Semaphore _requestSemaphore;
  final Set<_PostRequestTask> _postTasks = {};
  final Completer<void> _closedSignal = Completer<void>();

  bool _isClosed = false;
  String _baseUrl;
  Duration _requestTimeout;
  String? _sessionId;
  String? _protocolVersion;
  EventSource? _getEventSource;
  Future<void>? _getTask;
  Completer<void>? _initialGetAttempt;
  String? _getLastEventId;
  Duration _getSseRetry = _defaultReconnectDelay;

  StreamableHttpClientTransport._({
    required this.config,
    required http.Client httpClient,
    HttpOAuthClient? oauthClient,
    OAuthTokenManager? tokenManager,
  }) : _httpClient = httpClient,
       _oauthClient = oauthClient,
       _tokenManager = tokenManager,
       _baseUrl = config.baseUrl,
       _requestTimeout = config.timeout,
       _requestSemaphore = Semaphore(config.maxConcurrentRequests);

  static Future<StreamableHttpClientTransport> create({
    required String baseUrl,
    OAuthConfig? oauthConfig,
    Map<String, String>? headers,
    Duration? timeout,
    int? maxConcurrentRequests,
    bool? useHttp2,
    http.Client? httpClient,
    bool terminateOnClose = true,
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
    final client = httpClient ?? http.Client();
    final oauthClient =
        oauthConfig == null
            ? null
            : HttpOAuthClient(config: oauthConfig, httpClient: client);
    final tokenManager =
        oauthClient == null ? null : OAuthTokenManager(oauthClient);
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

  String get baseUrl => _baseUrl;
  int get maxConcurrentRequests => config.maxConcurrentRequests;
  bool get useHttp2 => config.useHttp2;
  OAuthConfig? get oauthConfig => config.oauthConfig;
  String? get sessionId => _sessionId;

  /// Completes after the first background GET receives headers or fails.
  Future<void> waitForInitialGetAttempt() {
    if (_isClosed && _initialGetAttempt == null) {
      return Future<void>.value();
    }
    _initialGetAttempt ??= Completer<void>();
    return _initialGetAttempt!.future;
  }

  void setRequestTimeout(Duration timeout) {
    if (timeout > Duration.zero) _requestTimeout = timeout;
  }

  void setProtocolVersion(String version) {
    _protocolVersion = version;
  }

  @override
  TransportSendOperation send(dynamic message) {
    if (_isClosed) {
      return TransportSendOperation(
        Future<void>.error(McpError('Transport is closed')),
      );
    }

    if (message is Map && message['method'] == 'notifications/initialized') {
      _startGetStream();
    }

    final requestId =
        message is Map && message['method'] != null && message['id'] is int
            ? message['id'] as int
            : null;
    final task = _PostRequestTask(requestId);
    _postTasks.add(task);
    final done = _sendRequest(message, task).whenComplete(() {
      _postTasks.remove(task);
    });
    return TransportSendOperation(done, cancel: task.cancel);
  }

  Future<void> _sendRequest(dynamic message, _PostRequestTask task) async {
    await _requestSemaphore.acquire();
    try {
      if (_isClosed || task.cancelled) return;
      final sessionIdPresent = _sessionId?.isNotEmpty == true;
      final request = http.AbortableRequest(
        'POST',
        Uri.parse(_baseUrl),
        abortTrigger: task.cancelledFuture,
      )..body = jsonEncode(message);
      request.headers.addAll(
        await _requestHeaders(
          accept: 'application/json, text/event-stream',
          contentType: 'application/json',
          includeSession: true,
        ),
      );

      final response = await _sendWithRedirects(request);
      _captureSessionId(response.headers['mcp-session-id']);

      if (response.statusCode == 202) {
        await _drainResponse(response);
        return;
      }
      if (response.statusCode >= 400) {
        throw await _httpError(
          response,
          sessionIdPresent: sessionIdPresent,
          canRetryRequest: response.statusCode == 404 && sessionIdPresent,
        );
      }

      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (contentType.startsWith('application/json')) {
        final body = await response.stream.bytesToString();
        if (body.isNotEmpty) _dispatchJson(body, task);
        return;
      }
      if (contentType.startsWith('text/event-stream')) {
        bool received;
        try {
          received = await _consumeSse(response.stream, task);
        } catch (_) {
          if (_canResumePost(task)) {
            await _resumePost(task);
            return;
          }
          rethrow;
        }
        if (task.requestId != null && !received && !task.cancelled) {
          if (task.lastEventId == null) {
            throw McpError(
              'POST SSE ended before the final response; result is unknown',
            );
          }
          await _resumePost(task);
        }
        return;
      }

      final body = await response.stream.bytesToString();
      if (body.isNotEmpty) {
        try {
          _dispatchJson(body, task);
        } catch (_) {
          throw McpError('Unexpected HTTP response content type: $contentType');
        }
      }
    } on http.RequestAbortedException {
      if (!task.cancelled) rethrow;
    } finally {
      _requestSemaphore.release();
    }
  }

  bool _canResumePost(_PostRequestTask task) =>
      !_isClosed &&
      !task.cancelled &&
      !task.responseReceived &&
      task.requestId != null &&
      task.lastEventId != null;

  Future<void> _resumePost(_PostRequestTask task) async {
    while (!_isClosed && !task.cancelled && !task.responseReceived) {
      await _waitForRetry(_boundedRetry(task.sseRetry), task.cancelledFuture);
      if (_isClosed || task.cancelled) return;

      final request = http.AbortableRequest(
        'GET',
        Uri.parse(_baseUrl),
        abortTrigger: task.cancelledFuture,
      );
      request.headers.addAll(
        await _requestHeaders(
          accept: 'text/event-stream',
          includeSession: true,
          lastEventId: task.lastEventId,
        ),
      );

      try {
        final response = await _sendWithRedirects(request);
        if (response.statusCode == 200) {
          final received = await _consumeSse(response.stream, task);
          if (received) return;
          continue;
        }

        final error = await _httpError(
          response,
          sessionIdPresent: _sessionId?.isNotEmpty == true,
          canRetryRequest: false,
        );
        if (_isRetryableStatus(error.statusCode)) {
          await _waitForRetry(_httpRetryDelay(error), task.cancelledFuture);
          continue;
        }
        throw error;
      } on http.RequestAbortedException {
        if (!task.cancelled) rethrow;
      } on McpHttpError {
        rethrow;
      } catch (_) {
        await _waitForRetry(_boundedRetry(task.sseRetry), task.cancelledFuture);
      }
    }
  }

  Future<bool> _consumeSse(
    Stream<List<int>> byteStream,
    _PostRequestTask task,
  ) async {
    final parser = SseParser();
    await for (final chunk in byteStream.transform(utf8.decoder)) {
      for (final event in parser.add(chunk)) {
        if (_applyPostEvent(event, task)) return true;
      }
    }
    for (final event in parser.close()) {
      if (_applyPostEvent(event, task)) return true;
    }
    return task.responseReceived;
  }

  bool _applyPostEvent(SseEvent event, _PostRequestTask task) {
    if (event.hasId) {
      task.lastEventId =
          event.id == null || event.id!.isEmpty ? null : event.id;
    }
    if (event.retry != null) task.sseRetry = event.retry!;
    final data = event.data;
    if (data == null || data == '[DONE]') return false;
    try {
      final decoded = jsonDecode(data);
      _messageController.add(decoded);
      if (_isResponseFor(decoded, task.requestId)) {
        task.responseReceived = true;
        return true;
      }
    } catch (_) {
      _logger.debug('Failed to parse SSE data: $data');
    }
    return false;
  }

  void _dispatchJson(String body, _PostRequestTask task) {
    final decoded = jsonDecode(body);
    _messageController.add(decoded);
    if (_isResponseFor(decoded, task.requestId)) {
      task.responseReceived = true;
    }
  }

  bool _isResponseFor(dynamic message, int? requestId) {
    return requestId != null &&
        message is Map &&
        message['id'] == requestId &&
        message['method'] == null &&
        (message.containsKey('result') || message.containsKey('error'));
  }

  void _startGetStream() {
    if (_isClosed || _sessionId == null) {
      _completeInitialGetAttempt();
      return;
    }
    if (_getTask != null) return;
    _initialGetAttempt ??= Completer<void>();
    final task = _runGetStream();
    _getTask = task;
    unawaited(
      task.whenComplete(() {
        if (identical(_getTask, task)) _getTask = null;
        _completeInitialGetAttempt();
      }),
    );
  }

  Future<void> _runGetStream() async {
    while (!_isClosed && _sessionId != null) {
      final done = Completer<void>();
      final eventSource = EventSource();
      _getEventSource = eventSource;
      Object? streamError;
      try {
        await eventSource.connect(
          _baseUrl,
          headers: await _requestHeaders(
            accept: 'text/event-stream',
            includeSession: true,
            lastEventId: _getLastEventId,
          ),
          onMessage: (message) {
            if (!_messageController.isClosed) {
              _messageController.add(message);
            }
          },
          onEvent: (event) {
            if (event.hasId) {
              _getLastEventId =
                  event.id == null || event.id!.isEmpty ? null : event.id;
            }
            if (event.retry != null) _getSseRetry = event.retry!;
          },
          onError: (error) {
            streamError = error;
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );
        _completeInitialGetAttempt();
        await Future.any<void>([done.future, _closedSignal.future]);
      } catch (error) {
        streamError = error;
      } finally {
        if (identical(_getEventSource, eventSource)) {
          _getEventSource = null;
        }
        eventSource.close();
      }
      if (_isClosed) return;

      var delay = _boundedRetry(_getSseRetry);
      final error = streamError;
      if (error is McpHttpError) {
        final backgroundError = McpHttpError(
          statusCode: error.statusCode,
          message: error.message,
          retryAfter: error.retryAfter,
          body: error.body,
          wwwAuthenticate: error.wwwAuthenticate,
          sessionIdPresent: _sessionId?.isNotEmpty == true,
          isBackgroundRequest: true,
        );
        if (!_messageController.isClosed) {
          _messageController.addError(backgroundError);
        }
        _completeInitialGetAttempt();
        if (backgroundError.statusCode == 404 &&
            backgroundError.sessionIdPresent) {
          _failTransport(backgroundError);
          return;
        }
        if (backgroundError.statusCode == 401 ||
            backgroundError.statusCode == 403) {
          delay = _authenticationRetryDelay;
        } else if (_isRetryableStatus(backgroundError.statusCode)) {
          delay = _httpRetryDelay(backgroundError);
        } else {
          return;
        }
      }
      await _waitForRetry(delay, _closedSignal.future);
    }
  }

  Future<Map<String, String>> _requestHeaders({
    required String accept,
    String? contentType,
    required bool includeSession,
    String? lastEventId,
  }) async {
    final headers = <String, String>{};
    for (final entry in config.headers.entries) {
      if (!_reservedHeaders.contains(entry.key.toLowerCase())) {
        headers[entry.key] = entry.value;
      }
    }
    headers['Accept'] = accept;
    if (contentType != null) headers['Content-Type'] = contentType;
    if (includeSession && _sessionId?.isNotEmpty == true) {
      headers['MCP-Session-Id'] = _sessionId!;
    }
    if (_protocolVersion != null &&
        McpProtocol.requiresProtocolHeader(_protocolVersion!)) {
      headers['MCP-Protocol-Version'] = _protocolVersion!;
    }
    if (lastEventId != null) headers['Last-Event-ID'] = lastEventId;
    if (_tokenManager != null) {
      headers['Authorization'] =
          'Bearer ${await _tokenManager.getAccessToken()}';
    }
    return headers;
  }

  Future<http.StreamedResponse> _sendWithRedirects(
    http.Request request, {
    int redirectCount = 0,
  }) async {
    final response = await _httpClient.send(request).timeout(_requestTimeout);
    if (response.statusCode != 307 && response.statusCode != 308) {
      return response;
    }
    final location = response.headers['location'];
    if (location == null || location.trim().isEmpty) return response;
    if (redirectCount >= 5) {
      await _drainResponse(response);
      throw McpError('Too many HTTP redirects while connecting to MCP server');
    }

    final redirectedUri = request.url.resolve(location);
    if (!_isSameOrigin(request.url, redirectedUri)) {
      await _drainResponse(response);
      throw McpError(
        'Refusing cross-origin or protocol-downgrade MCP redirect: '
        '${request.url} -> $redirectedUri',
      );
    }
    await _drainResponse(response);
    _baseUrl = redirectedUri.toString();
    final redirected = http.AbortableRequest(
      request.method,
      redirectedUri,
      abortTrigger:
          request is http.AbortableRequest ? request.abortTrigger : null,
    )..bodyBytes = request.bodyBytes;
    redirected.headers.addAll(request.headers);
    return _sendWithRedirects(redirected, redirectCount: redirectCount + 1);
  }

  bool _isSameOrigin(Uri source, Uri target) =>
      source.scheme.toLowerCase() == target.scheme.toLowerCase() &&
      source.host.toLowerCase() == target.host.toLowerCase() &&
      _effectivePort(source) == _effectivePort(target);

  int _effectivePort(Uri uri) {
    if (uri.hasPort) return uri.port;
    return uri.scheme.toLowerCase() == 'https' ? 443 : 80;
  }

  Future<void> _drainResponse(http.StreamedResponse response) =>
      response.stream.drain<void>().timeout(_requestTimeout);

  Future<McpHttpError> _httpError(
    http.StreamedResponse response, {
    required bool sessionIdPresent,
    required bool canRetryRequest,
  }) async {
    final body = await response.stream.bytesToString();
    return McpHttpError(
      statusCode: response.statusCode,
      message:
          'HTTP ${response.statusCode}: ${response.reasonPhrase}'
          '${body.isEmpty ? '' : ' — $body'}',
      retryAfter: McpHttpError.parseRetryAfter(response.headers['retry-after']),
      body: body,
      wwwAuthenticate:
          response.headers['www-authenticate'] == null
              ? const []
              : [response.headers['www-authenticate']!],
      sessionIdPresent: sessionIdPresent,
      canRetryRequest: canRetryRequest || response.statusCode == 401,
    );
  }

  bool _isRetryableStatus(int statusCode) =>
      statusCode == 408 || statusCode == 429 || statusCode >= 500;

  Duration _httpRetryDelay(McpHttpError error) =>
      _boundedRetry(error.retryAfter ?? _defaultReconnectDelay);

  Duration _boundedRetry(Duration delay) =>
      delay < _minimumReconnectDelay ? _minimumReconnectDelay : delay;

  Future<void> _waitForRetry(Duration delay, Future<void> cancellation) async {
    await Future.any<void>([Future<void>.delayed(delay), cancellation]);
  }

  void _captureSessionId(String? value) {
    if (value != null && value.trim().isNotEmpty) {
      _sessionId = value;
    }
  }

  void _completeInitialGetAttempt() {
    final pending = _initialGetAttempt ??= Completer<void>();
    if (!pending.isCompleted) pending.complete();
  }

  void _failTransport(Object error) {
    if (_isClosed) return;
    _isClosed = true;
    _completeInitialGetAttempt();
    if (!_closedSignal.isCompleted) _closedSignal.complete();
    for (final task in _postTasks.toList()) {
      task.cancel();
    }
    _getEventSource?.close();
    _httpClient.close();
    _oauthClient?.close();
    _tokenManager?.dispose();
    if (!_messageController.isClosed) _messageController.close();
    if (!_closeCompleter.isCompleted) _closeCompleter.completeError(error);
  }

  Future<void> terminateSession() async {
    if (_sessionId?.isNotEmpty != true || _isClosed) return;
    final request = http.Request('DELETE', Uri.parse(_baseUrl));
    request.headers.addAll(
      await _requestHeaders(
        accept: 'application/json, text/event-stream',
        includeSession: true,
      ),
    );
    try {
      final response = await _sendWithRedirects(request);
      await _drainResponse(response);
      if (response.statusCode != 200 &&
          response.statusCode != 204 &&
          response.statusCode != 405) {
        _logger.warning('Session termination failed: ${response.statusCode}');
      }
    } catch (error) {
      _logger.warning('Session termination failed: $error');
    }
  }

  @override
  void close() {
    if (_isClosed) return;
    _completeInitialGetAttempt();
    final termination =
        config.terminateOnClose && _sessionId != null
            ? terminateSession()
            : null;
    _isClosed = true;
    if (!_closedSignal.isCompleted) _closedSignal.complete();
    for (final task in _postTasks.toList()) {
      task.cancel();
    }
    _getEventSource?.close();
    if (termination == null) {
      _closeHttpResources();
    } else {
      unawaited(termination.whenComplete(_closeHttpResources));
    }
    if (!_messageController.isClosed) _messageController.close();
    if (!_closeCompleter.isCompleted) _closeCompleter.complete();
  }

  void _closeHttpResources() {
    _httpClient.close();
    _oauthClient?.close();
    _tokenManager?.dispose();
  }

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
    throw UnimplementedError(
      'OAuth flow requires platform-specific implementation. '
      'Authorization URL: $authUrl',
    );
  }

  void setOAuthToken(OAuthToken token) {
    _tokenManager?.setToken(token);
  }
}

final class _PostRequestTask {
  final int? requestId;
  final Completer<void> _cancelled = Completer<void>();
  bool cancelled = false;
  bool responseReceived = false;
  String? lastEventId;
  Duration sseRetry = const Duration(seconds: 1);

  _PostRequestTask(this.requestId);

  Future<void> get cancelledFuture => _cancelled.future;

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

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
      _waitQueue.removeFirst().complete();
    } else {
      _currentCount++;
    }
  }
}
