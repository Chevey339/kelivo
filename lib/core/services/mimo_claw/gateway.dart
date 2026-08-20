import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dio/dio.dart';

/// MiMo Claw WebSocket Gateway 客户端
///
/// 协议: OpenClaw JSON-RPC over WebSocket
/// 流程: getTicket → connect WS → connect.challenge → connect → sessions.subscribe → chat.send
class MiMoClawGateway {
  static const String _tag = 'MiMoClawGateway';
  static const String _restBaseUrl = 'https://aistudio.xiaomimimo.com';
  static const String _wsBaseUrl = 'wss://aistudio.xiaomimimo.com/ws';

  final Dio _dio;

  // 连接状态
  ConnectionState _connectionState = ConnectionState.disconnected;
  ConnectionState get connectionState => _connectionState;
  final _connectionStateController =
      StreamController<ConnectionState>.broadcast();
  Stream<ConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  // 事件流
  final _eventsController = StreamController<ClawEvent>.broadcast();
  Stream<ClawEvent> get events => _eventsController.stream;

  // 内部状态
  WebSocketChannel? _ws;
  String? _ticket;
  String? _connId;
  String _sessionKey = 'agent:main:main';
  final Map<String, Completer<Map<String, dynamic>?>> _pendingRequests = {};
  int _connectionGeneration = 0;
  Completer<void>? _connectionReady;
  StreamSubscription? _wsSubscription;
  String? _cookies;

  MiMoClawGateway({Dio? dio}) : _dio = dio ?? Dio();

  // ── 连接 ──

  Future<void> connect({String? cookies}) async {
    disconnect();
    final generation = ++_connectionGeneration;

    try {
      _updateState(ConnectionState.connecting);
      _cookies = cookies;

      // Step 1: 获取 WebSocket ticket
      _ticket = await _fetchTicket();
      if (generation != _connectionGeneration) return;

      // Step 2: 建立 WebSocket
      _connectionReady = Completer<void>();
      _createWebSocket(_ticket!, generation);

      await _connectionReady!.future.timeout(
        const Duration(seconds: 30),
      );
    } catch (e) {
      debugPrint('$_tag 连接失败: $e');
      if (generation == _connectionGeneration) {
        disconnect();
      }
      rethrow;
    }
  }

  Future<String> _fetchTicket() async {
    try {
      final response = await _dio.get(
        '$_restBaseUrl/open-apis/user/ws/ticket',
        options: Options(
          headers: {
            'Cookie': _cookies ?? '',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14) Chrome/137.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          final ticket = data['data']?['ticket'] ?? data['ticket'];
          if (ticket != null && ticket.toString().isNotEmpty) {
            return ticket.toString();
          }
        }
      }
      throw Exception('获取 ticket 失败: HTTP ${response.statusCode}');
    } catch (e) {
      throw Exception('获取 ticket 异常: $e');
    }
  }

  void _createWebSocket(String ticket, int generation) {
    final wsUrl = '$_wsBaseUrl?ticket=$ticket';
    final ws = WebSocketChannel.connect(
      Uri.parse(wsUrl),
      protocols: [],
    );

    _ws = ws;

    _wsSubscription = ws.stream.listen(
      (data) {
        if (generation == _connectionGeneration) {
          _handleMessage(data.toString(), generation);
        }
      },
      onError: (error) {
        debugPrint('$_tag WebSocket 错误: $error');
        if (generation == _connectionGeneration) {
          _updateState(ConnectionState.disconnected);
          _connectionReady?.completeError(error);
          _failPendingRequests(Exception('WebSocket 错误: $error'));
        }
      },
      onDone: () {
        debugPrint('$_tag WebSocket 已关闭');
        if (generation == _connectionGeneration) {
          _updateState(ConnectionState.disconnected);
          _connectionReady?.completeError(Exception('WebSocket 已关闭'));
          _failPendingRequests(Exception('WebSocket 已关闭'));
        }
      },
    );

    // 发送 connect 请求
    _doConnect(generation);
  }

  // ── 消息处理 ──

  void _handleMessage(String text, int generation) {
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      final type = json['type'] as String? ?? '';
      final event = json['event'] as String? ?? '';

      debugPrint('$_tag WS消息: type=$type event=$event');

      switch (type) {
        case 'event':
          _handleEvent(json, generation);
          break;
        case 'res':
          _handleResponse(json);
          break;
        default:
          debugPrint('$_tag 未知消息类型: $type');
      }
    } catch (e) {
      debugPrint('$_tag 解析消息失败: $e');
    }
  }

  void _handleEvent(Map<String, dynamic> json, int generation) {
    final event = json['event'] as String? ?? '';
    final payload = json['payload'] as Map<String, dynamic>?;

    switch (event) {
      case 'connect.challenge':
        _doConnect(generation);
        break;

      case 'agent':
        _handleAgentEvent(payload);
        break;

      case 'chat':
        _handleChatEvent(payload);
        break;

      case 'session.message':
        _handleSessionMessage(payload);
        break;

      case 'session.tool':
        _handleToolEvent(payload);
        break;

      case 'sessions.changed':
        debugPrint('$_tag sessions.changed');
        break;

      case 'health':
      case 'tick':
      case 'heartbeat':
        // 周期性心跳，忽略
        break;

      default:
        debugPrint('$_tag 事件: $event');
    }
  }

  void _handleAgentEvent(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final stream = payload['stream'] as String? ?? '';

    switch (stream) {
      case 'lifecycle':
        final phase = payload['data']?['phase'] as String? ?? '';
        debugPrint('$_tag agent lifecycle: $phase');
        break;

      case 'assistant':
        final data = payload['data'] as Map<String, dynamic>?;
        final delta = data?['delta'] as String? ?? '';
        if (delta.isNotEmpty) {
          final sessionKey = _extractSessionKey(payload);
          _eventsController.add(
            AgentEvent(sessionKey: sessionKey, delta: delta),
          );
        }
        break;
    }
  }

  void _handleChatEvent(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final state = payload['state'] as String? ?? '';

    switch (state) {
      case 'delta':
        final deltaText = payload['deltaText'] as String? ?? '';
        if (deltaText.isNotEmpty) {
          final sessionKey = _extractSessionKey(payload);
          _eventsController.add(
            ChatEvent(sessionKey: sessionKey, delta: deltaText),
          );
        }
        break;

      case 'final':
        final sessionKey = _extractSessionKey(payload);
        _eventsController.add(
          ChatEvent(sessionKey: sessionKey, isFinal: true),
        );
        break;
    }
  }

  void _handleSessionMessage(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final sessionKey = _extractSessionKey(payload);
    final message = payload['message'] as Map<String, dynamic>?;
    final content = message?['content'] as List?;

    if (content == null) return;

    final blocks = <ContentBlock>[];
    for (final block in content) {
      if (block is Map) {
        final type = block['type'] as String? ?? '';
        switch (type) {
          case 'thinking':
            blocks.add(ThinkingBlock(block['thinking'] as String? ?? ''));
            break;
          case 'text':
            blocks.add(TextBlock(block['text'] as String? ?? ''));
            break;
          case 'tool':
          case 'tool_use':
          case 'toolUse':
            blocks.add(ToolBlock(
              name: block['name'] as String? ?? block['toolName'] as String? ?? '工具调用',
              status: block['status'] as String? ?? block['state'] as String? ?? '执行中',
            ));
            break;
        }
      }
    }

    _eventsController.add(
      SessionMessageEvent(sessionKey: sessionKey, blocks: blocks),
    );
  }

  void _handleToolEvent(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final sessionKey = _extractSessionKey(payload);
    final tool = payload['tool'] as Map<String, dynamic>? ?? payload;
    final name = (tool['name'] as String?)?.takeIfNotEmpty() ??
        (tool['toolName'] as String?)?.takeIfNotEmpty() ??
        '工具调用';
    final status = (tool['status'] as String?)?.takeIfNotEmpty() ??
        (tool['state'] as String?)?.takeIfNotEmpty() ??
        '执行中';

    _eventsController.add(
      ToolEvent(sessionKey: sessionKey, name: name, status: status),
    );
  }

  String? _extractSessionKey(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    return (payload['sessionKey'] as String?)?.takeIfNotEmpty() ??
        (payload['data'] as Map<String, dynamic>?)?['sessionKey'] as String? ??
        (payload['message'] as Map<String, dynamic>?)?['sessionKey'] as String?;
  }

  void _handleResponse(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final ok = json['ok'] as bool? ?? false;
    final payload = json['payload'] as Map<String, dynamic>?;
    final error = json['error'] as String? ?? json['message'] as String? ?? '';

    debugPrint('$_tag RPC 响应: id=$id ok=$ok');

    final deferred = _pendingRequests.remove(id);
    if (deferred != null) {
      if (ok) {
        deferred.complete(payload ?? {});
      } else {
        deferred.completeError(Exception('RPC 错误: $error'));
      }
    }
  }

  // ── RPC 请求 ──

  Future<void> _doConnect(int generation) async {
    final id = _uuid();
    final params = {
      'minProtocol': 3,
      'maxProtocol': 4,
      'client': {
        'id': 'cli',
        'version': 'kelivo-mimo-claw',
        'platform': 'Flutter',
        'mode': 'cli',
      },
      'role': 'operator',
      'scopes': [
        'operator.admin',
        'operator.read',
        'operator.write',
        'operator.approvals',
        'operator.pairing',
      ],
      'caps': ['tool-events'],
      'userAgent':
          'Mozilla/5.0 (Linux; Android 14) Chrome/137.0.0.0 Mobile Safari/537.36',
      'locale': 'zh-CN',
    };

    final result = await _sendRpc(id, 'connect', params);
    if (generation != _connectionGeneration) return;

    if (result != null) {
      _connId = result['server']?['connId'] as String?;
      debugPrint('$_tag Gateway connect 握手成功');
      _updateState(ConnectionState.connected);
      _connectionReady?.complete();

      // 订阅 sessions
      _subscribeSessions();
      _listSessions();
    }
  }

  Future<void> _subscribeSessions() async {
    final id = _uuid();
    await _sendRpc(id, 'sessions.subscribe', {});
  }

  Future<void> _listSessions() async {
    final id = _uuid();
    final params = {
      'includeGlobal': true,
      'includeUnknown': false,
      'limit': 120,
    };

    final result = await _sendRpc(id, 'sessions.list', params);
    if (result != null) {
      final sessions = result['sessions'] as List? ?? [];
      final sessionList = <SessionInfo>[];
      for (final s in sessions) {
        if (s is Map) {
          sessionList.add(SessionInfo(
            key: s['key'] as String? ?? '',
            sessionId: s['sessionId'] as String? ?? '',
            title: _extractTitle(s),
            model: s['model'] as String? ?? 'mimo-v2.5-pro',
            updatedAt: s['updatedAt'] as int? ?? 0,
          ));
        }
      }
      _eventsController.add(SessionListEvent(sessions: sessionList));
    }
  }

  String _extractTitle(Map<String, dynamic> session) {
    final key = session['key'] as String? ?? '';
    if (key.contains('dashboard:')) {
      final part = key.split('dashboard:').last;
      return part.length > 8 ? part.substring(0, 8) : part;
    }
    if (key.contains('cron:')) return '定时任务';
    if (key == 'agent:main:main') return '主会话';
    return '对话 ${key.length > 8 ? key.substring(key.length - 8) : key}';
  }

  /// 发送聊天消息
  Future<void> sendChatMessage({
    required String message,
    String? sessionKey,
  }) async {
    final requestId = _uuid();
    final params = {
      'sessionKey': sessionKey ?? _sessionKey,
      'message': message,
      'deliver': false,
      'idempotencyKey': requestId,
    };

    await _sendRpc(requestId, 'chat.send', params, timeoutMs: 10000);
  }

  /// 中止当前回复
  Future<void> abortChat({String? sessionKey}) async {
    final id = _uuid();
    await _sendRpc(id, 'chat.abort', {
      'sessionKey': sessionKey ?? _sessionKey,
    });
  }

  /// 更新会话模型
  Future<void> setSessionModel({
    String? sessionKey,
    required String model,
  }) async {
    final id1 = _uuid();
    final getResult = await _sendRpc(id1, 'config.get', {});
    if (getResult == null) return;

    final baseHash = getResult['baseHash'] as String? ?? '';
    final id2 = _uuid();
    final raw = jsonEncode({
      'sessions': {
        sessionKey ?? _sessionKey: {'model': model},
      },
    });

    await _sendRpc(id2, 'config.patch', {
      'raw': raw,
      if (baseHash.isNotEmpty) 'baseHash': baseHash,
    });
  }

  /// 获取聊天历史
  Future<List<HistoryMessage>> getChatHistory({
    String? sessionKey,
    int limit = 200,
  }) async {
    final id = _uuid();
    final result = await _sendRpc(id, 'chat.history', {
      'sessionKey': sessionKey ?? _sessionKey,
      'limit': limit,
    });

    if (result == null) return [];

    final messages = result['messages'] as List? ?? [];
    final list = <HistoryMessage>[];

    for (final msg in messages) {
      if (msg is! Map) continue;
      final role = msg['role'] as String? ?? 'user';
      final content = msg['content'];
      var thinking = '';
      final tools = <HistoryToolCall>[];
      var contentStr = '';

      if (content is List) {
        final parts = <String>[];
        for (final block in content) {
          if (block is Map) {
            switch (block['type']) {
              case 'text':
                parts.add(block['text'] as String? ?? '');
                break;
              case 'thinking':
                thinking += block['thinking'] as String? ?? '';
                break;
              case 'tool':
              case 'tool_use':
              case 'toolUse':
                tools.add(HistoryToolCall(
                  name: block['name'] as String? ?? block['toolName'] as String? ?? '工具调用',
                  status: block['status'] as String? ?? block['state'] as String? ?? '已完成',
                ));
                break;
            }
          }
        }
        contentStr = parts.join('');
      } else if (content is String) {
        contentStr = content;
      } else {
        contentStr = content?.toString() ?? '';
      }

      list.add(HistoryMessage(
        role: role,
        content: contentStr,
        thinking: thinking,
        tools: tools,
      ));
    }

    return list;
  }

  // ── RPC 核心 ──

  Future<Map<String, dynamic>?> _sendRpc(
    String id,
    String method,
    Map<String, dynamic> params, {
    int timeoutMs = 30000,
  }) async {
    final deferred = Completer<Map<String, dynamic>?>();
    _pendingRequests[id] = deferred;

    final request = {
      'type': 'req',
      'id': id,
      'method': method,
      'params': params,
    };

    try {
      _ws?.sink.add(jsonEncode(request));
      return await deferred.future.timeout(
        Duration(milliseconds: timeoutMs),
      );
    } on TimeoutException {
      _pendingRequests.remove(id);
      return null;
    } catch (e) {
      _pendingRequests.remove(id);
      rethrow;
    }
  }

  // ── 会话切换 ──

  void setSessionKey(String key) {
    _sessionKey = key;
  }

  String createDashboardSessionKey() =>
      'agent:main:dashboard:${_uuid()}';

  // ── 断开 ──

  void disconnect() {
    _connectionGeneration++;
    _wsSubscription?.cancel();
    _ws?.sink.close(1000, '用户断开');
    _ws = null;
    _connectionReady?.completeError(Exception('连接已断开'));
    _connectionReady = null;
    _ticket = null;
    _connId = null;
    _sessionKey = 'agent:main:main';
    _failPendingRequests(Exception('连接已断开'));
    _updateState(ConnectionState.disconnected);
  }

  void _failPendingRequests(Exception cause) {
    for (final deferred in _pendingRequests.values) {
      if (!deferred.isCompleted) {
        deferred.completeError(cause);
      }
    }
    _pendingRequests.clear();
  }

  void _updateState(ConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  void dispose() {
    disconnect();
    _connectionStateController.close();
    _eventsController.close();
  }

  String _uuid() {
    return '${DateTime.now().microsecondsSinceEpoch}_${_connectionGeneration}_${_pendingRequests.length}';
  }
}

// ── 扩展 ──

extension _StringExtension on String {
  String? takeIfNotEmpty() => isEmpty ? null : this;
}

// ── 数据模型 ──

enum ConnectionState {
  disconnected,
  connecting,
  connected,
}

// 事件类型
abstract class ClawEvent {
  final String? sessionKey;
  ClawEvent({this.sessionKey});
}

class AgentEvent extends ClawEvent {
  final String delta;
  AgentEvent({String? sessionKey, required this.delta})
      : super(sessionKey: sessionKey);
}

class ChatEvent extends ClawEvent {
  final String delta;
  final bool isFinal;
  ChatEvent({String? sessionKey, this.delta = '', this.isFinal = false})
      : super(sessionKey: sessionKey);
}

class SessionMessageEvent extends ClawEvent {
  final List<ContentBlock> blocks;
  SessionMessageEvent({String? sessionKey, required this.blocks})
      : super(sessionKey: sessionKey);
}

class ToolEvent extends ClawEvent {
  final String name;
  final String status;
  ToolEvent({String? sessionKey, required this.name, required this.status})
      : super(sessionKey: sessionKey);
}

class SessionListEvent extends ClawEvent {
  final List<SessionInfo> sessions;
  SessionListEvent({required this.sessions}) : super();
}

// 内容块
abstract class ContentBlock {}

class ThinkingBlock extends ContentBlock {
  final String text;
  ThinkingBlock(this.text);
}

class TextBlock extends ContentBlock {
  final String text;
  TextBlock(this.text);
}

class ToolBlock extends ContentBlock {
  final String name;
  final String status;
  ToolBlock({required this.name, required this.status});
}

// 会话信息
class SessionInfo {
  final String key;
  final String sessionId;
  final String title;
  final String model;
  final int updatedAt;

  SessionInfo({
    required this.key,
    required this.sessionId,
    required this.title,
    required this.model,
    required this.updatedAt,
  });
}

// 历史消息
class HistoryMessage {
  final String role;
  final String content;
  final String thinking;
  final List<HistoryToolCall> tools;

  HistoryMessage({
    required this.role,
    required this.content,
    this.thinking = '',
    this.tools = const [],
  });
}

class HistoryToolCall {
  final String name;
  final String status;
  HistoryToolCall({required this.name, required this.status});
}
