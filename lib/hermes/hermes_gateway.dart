import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'hermes_auth.dart';
import 'hermes_config.dart';
import 'hermes_event_bus.dart';
import 'hermes_models.dart';
import 'hermes_rest_client.dart';

/// Connection state of the Hermes WebSocket gateway.
enum HermesConnectionState {
  /// App is initializing — Hive config loading, provider setting up.
  initializing,

  /// Not connected to any backend.
  disconnected,

  /// WebSocket handshake in progress.
  connecting,

  /// Authenticating with the backend.
  authenticating,

  /// Connected and ready to send/receive.
  ready,

  /// Connection failed; an error is stored.
  error,
}

/// Raised when a JSON-RPC call returns an error.
class HermesRpcException implements Exception {
  final int? code;
  final String message;
  const HermesRpcException(this.code, this.message);

  @override
  String toString() => 'HermesRpcException($code): $message';
}

/// Core WebSocket JSON-RPC client for Hermes.
///
/// Manages:
/// - WebSocket lifecycle (connect, disconnect, auto-reconnect)
/// - Auth mode detection & switching (loopback ↔ gated)
/// - JSON-RPC request / response dispatch
/// - Stream event parsing & routing to [HermesEventBus]
/// - Heartbeat ping (every 25s, disconnect after 30s silence)
class HermesGateway {
  final HermesEventBus _eventBus;
  HermesConfig _config;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  HermesConnectionState _state = HermesConnectionState.disconnected;
  HermesBackendBox? _currentBackend;
  HermesAuth? _currentAuth;
  HermesRestClient? _restClient;

  /// REST client for non-WebSocket API calls (e.g. session export, billing).
  HermesRestClient? get restClient => _restClient;

  // Pending RPC futures keyed by request id.
  final _pending = <String, Completer<dynamic>>{};

  // Latest received event time for heartbeat tracking.
  DateTime? _lastEventAt;

  HermesGateway({
    required HermesEventBus eventBus,
    required HermesConfig config,
  }) : _eventBus = eventBus,
       _config = config;

  HermesConnectionState get state => _state;
  HermesBackendBox? get currentBackend => _currentBackend;

  /// Connect to a Hermes backend.
  Future<void> connect(HermesBackendBox backend) async {
    _currentBackend = backend;
    _reconnectAttempt = 0;
    await _doConnect(backend);
  }

  /// Disconnect and stop all auto-reconnect attempts.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    await _wsSub?.cancel();
    await _ws?.sink.close();
    _ws = null;
    _state = HermesConnectionState.disconnected;
    _pending.forEach((_, c) => c.completeError('disconnected'));
    _pending.clear();
  }

  /// Send a JSON-RPC request and wait for a response.
  Future<dynamic> sendRpc(String method, [Map<String, dynamic>? params]) async {
    if (_state != HermesConnectionState.ready) {
      throw StateError('Cannot send RPC while not in ready state: $_state');
    }

    final id = _makeId();
    final payload = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    };

    final completer = Completer<dynamic>();
    _pending[id] = completer;

    _ws!.sink.add(jsonEncode(payload));

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('RPC $method timed out');
      },
    );
  }

  // ── Internal ──────────────────────────────────────────────────

  Future<void> _doConnect(HermesBackendBox backend) async {
    _state = HermesConnectionState.connecting;

    // Build auth — try loopback first, then gated
    HermesAuth auth;
    final effectiveMode = backend.authModeEnum;

    if (effectiveMode == HermesAuthMode.gated) {
      auth = GatedAuth(baseUrl: _restBase(backend.url));
    } else if (effectiveMode == HermesAuthMode.loopback) {
      if (backend.token == null) {
        throw const HermesAuthException('loopback mode requires a token');
      }
      auth = LoopbackAuth(backend.token!);
    } else {
      // Auto: try loopback first
      _state = HermesConnectionState.authenticating;
      try {
        if (backend.token != null) {
          auth = LoopbackAuth(backend.token!);
          await _wsConnect(backend, auth);
          return;
        }
      } catch (_) {
        // loopback failed, try gated
      }
      auth = GatedAuth(baseUrl: _restBase(backend.url));
    }

    await _wsConnect(backend, auth);
  }

  Future<void> _wsConnect(HermesBackendBox backend, HermesAuth auth) async {
    _currentAuth = auth;
    _restClient = HermesRestClient(auth: auth, baseUrl: _restBase(backend.url));
    _state = HermesConnectionState.authenticating;

    final params = await auth.authParams();
    final query = params.wsQueryParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    final wsUrl = '${backend.url}/api/ws${query.isNotEmpty ? '?$query' : ''}';

    try {
      _ws = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsSub = _ws!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );
    } catch (e) {
      _scheduleReconnect(backend);
      rethrow;
    }
  }

  void _onMessage(dynamic raw) {
    _lastEventAt = DateTime.now();

    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    // Handle JSON-RPC response
    final id = msg['id'] as String?;
    if (id != null && msg.containsKey('result')) {
      final completer = _pending.remove(id);
      if (completer != null) {
        completer.complete(msg['result']);
      }
      return;
    }
    if (id != null && msg.containsKey('error')) {
      final err = msg['error'] as Map<String, dynamic>;
      final completer = _pending.remove(id);
      if (completer != null) {
        completer.completeError(
          HermesRpcException(
            err['code'] as int? ?? -1,
            err['message'] as String? ?? '',
          ),
        );
      }
      return;
    }

    // Handle event
    if (msg['method'] == 'event') {
      final params = msg['params'] as Map<String, dynamic>?;
      if (params != null) {
        final event = _parseEvent(params);
        if (event != null) {
          _eventBus.emit(event);

          if (event is GatewayReady) {
            _state = HermesConnectionState.ready;
            _reconnectAttempt = 0;
            _startHeartbeat();
          }
        }
      }
    }

    // Handle pong (our heartbeat)
    if (msg['method'] == 'pong') {
      // heartbeat acknowledged
    }
  }

  HermesStreamEvent? _parseEvent(Map<String, dynamic> params) {
    final type = params['type'] as String? ?? '';
    final sid = params['session_id'] as String? ?? '';
    final payload = (params['payload'] ?? {}) as Map<String, dynamic>;

    switch (type) {
      case 'message.start':
        return MessageStart(sessionId: sid);
      case 'message.delta':
        return MessageDelta(
          sessionId: sid,
          text: payload['text'] as String? ?? '',
        );
      case 'message.complete':
        return MessageComplete(
          sessionId: sid,
          text: payload['text'] as String?,
          payload: payload,
        );

      case 'reasoning.delta':
        return ReasoningDelta(
          sessionId: sid,
          text: payload['text'] as String? ?? '',
        );
      case 'reasoning.available':
        return ReasoningAvailable(sessionId: sid);

      case 'thinking.delta':
        return ThinkingDelta(
          sessionId: sid,
          text: payload['text'] as String? ?? '',
        );

      case 'tool.start':
        return ToolStart(
          sessionId: sid,
          name: payload['name'] as String? ?? '',
          preview: payload['preview'] as String?,
          args: payload['args'] as Map<String, dynamic>?,
          index: (payload['index'] as num?)?.toInt() ?? 0,
        );
      case 'tool.progress':
        return ToolProgress(
          sessionId: sid,
          name: payload['name'] as String? ?? '',
          content: payload['content'] as String?,
        );
      case 'tool.generating':
        return ToolGenerating(
          sessionId: sid,
          name: payload['name'] as String? ?? '',
        );
      case 'tool.complete':
        return ToolComplete(
          sessionId: sid,
          name: payload['name'] as String? ?? '',
          duration: (payload['duration'] as num?)?.toDouble() ?? 0.0,
          ok: payload['ok'] as bool? ?? true,
          openTool: payload['open_tool'] as Map<String, dynamic>?,
          index: (payload['index'] as num?)?.toInt() ?? 0,
        );

      case 'gateway.ready':
        return GatewayReady(skin: payload['skin']?.toString());
      case 'gateway.notice':
        return GatewayNotice(
          kind: payload['kind'] as String? ?? '',
          text: payload['text'] as String?,
          extra: payload['extra'] as Map<String, dynamic>?,
        );
      case 'status.update':
        return StatusUpdate(
          sessionId: sid,
          kind: payload['kind'] as String? ?? '',
          text: payload['text'] as String?,
        );
      case 'approval.request':
        return ApprovalRequest(sessionId: sid, payload: payload);
      case 'clarify.request':
        return ClarifyRequest(sessionId: sid, payload: payload);
      case 'sudo.request':
        return SudoRequest(sessionId: sid, payload: payload);
      case 'secret.request':
        return SecretRequest(sessionId: sid, payload: payload);
      case 'session.info':
        return SessionInfo(sessionId: sid, info: payload);
      case 'error':
        return HermesError(
          sessionId: sid,
          message: payload['message'] as String? ?? '',
        );
      case 'skin.changed':
        return SkinChanged(
          skin: payload['skin'] as Map<String, dynamic>? ?? {},
        );
      case 'commentary':
        return Commentary(
          sessionId: sid,
          text: payload['text'] as String? ?? '',
        );

      case 'handoff.requested':
        return HandoffRequested.fromJson({'session_id': sid, ...payload});
      case 'handoff.completed':
        return HandoffCompleted.fromJson({'session_id': sid, ...payload});
      case 'handoff.failed':
        return HandoffFailed.fromJson({'session_id': sid, ...payload});

      case 'preview.restart.progress':
        return PreviewRestartProgress(
          sessionId: sid,
          taskId: payload['task_id'] as String? ?? '',
          level: (payload['level'] as num?)?.toInt() ?? 0,
          text: payload['text'] as String?,
        );
      case 'preview.restart.complete':
        return PreviewRestartComplete(
          sessionId: sid,
          taskId: payload['task_id'] as String? ?? '',
          text: payload['text'] as String?,
        );

      case 'terminal.output':
        return TerminalOutput(
          sessionId: sid,
          text: payload['text'] as String? ?? '',
          isError: payload['is_error'] as bool? ?? false,
        );
      case 'terminal.read':
        return TerminalReadRequest(
          sessionId: sid,
          prompt: payload['prompt'] as String? ?? '',
        );
      case 'terminal.closed':
        return TerminalClosed(
          sessionId: sid,
          exitCode: (payload['exit_code'] as num?)?.toInt(),
        );

      default:
        // Unknown event — emit as generic notice
        return GatewayNotice(kind: 'unknown', text: type);
    }
  }

  void _onError(Object error) {
    _scheduleReconnect(_currentBackend!);
  }

  void _onDone() {
    _heartbeatTimer?.cancel();
    if (_state != HermesConnectionState.disconnected) {
      _scheduleReconnect(_currentBackend!);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _lastEventAt = DateTime.now();

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_state != HermesConnectionState.ready) return;

      final sinceLast = _lastEventAt != null
          ? DateTime.now().difference(_lastEventAt!).inSeconds
          : 30;

      if (sinceLast >= 30) {
        // Stale connection — force reconnect
        _ws?.sink.close();
        return;
      }

      // Send ping
      _ws?.sink.add('{"jsonrpc":"2.0","method":"ping"}');
    });
  }

  void _scheduleReconnect(HermesBackendBox backend) {
    if (_state == HermesConnectionState.disconnected) return;

    _heartbeatTimer?.cancel();
    _wsSub?.cancel();
    _ws = null;
    _state = HermesConnectionState.error;

    // Exponential backoff: 1, 2, 4, 8, 16, 30s (capped)
    _reconnectAttempt++;
    final delay = min(30.0, pow(2, _reconnectAttempt - 1).toDouble());

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay.toInt()), () {
      _doConnect(backend);
    });
  }

  String _makeId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_pending.length}';

  String _restBase(String wsUrl) {
    // Strip /api/ws suffix if present
    return wsUrl.replaceAll(RegExp(r'/api/ws$'), '');
  }

  /// Dispose all resources.
  void dispose() {
    disconnect();
    _eventBus.dispose();
  }

  // ── Terminal ──────────────────────────────────────────────────────

  /// Send user input from terminal to the backend.
  Future<void> terminalReadRespond(String sessionId, String data) async {
    await sendRpc('terminal.read_respond', {
      'session_id': sessionId,
      'data': data,
    });
  }

  /// Notify backend of terminal resize.
  Future<void> terminalResize(String sessionId, int width, int height) async {
    await sendRpc('terminal.resize', {
      'session_id': sessionId,
      'width': width,
      'height': height,
    });
  }
}
