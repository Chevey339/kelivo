import 'dart:async';
import 'package:flutter/foundation.dart';
import 'gateway.dart';
import 'auth.dart';

/// MiMo Claw Provider
///
/// 集成 MiMo Claw Gateway 到 Kelivo 的 provider 系统
/// 提供完整的 Agent 能力：工具调用、文件操作、会话管理
class MiMoClawProvider extends ChangeNotifier {
  final MiMoClawGateway _gateway;
  final MiMoClawAuth _auth;

  // 登录状态
  String? _cookies;
  String? _nickname;
  String? _userId;
  bool _isLoggedIn = false;

  // 会话列表
  List<SessionInfo> _sessions = [];

  // 事件订阅
  StreamSubscription? _eventSubscription;
  StreamSubscription? _stateSubscription;

  bool get isLoggedIn => _isLoggedIn;
  String? get nickname => _nickname;
  String? get userId => _userId;
  ConnectionState get connectionState => _gateway.connectionState;
  Stream<ConnectionState> get connectionStateStream =>
      _gateway.connectionStateStream;
  Stream<ClawEvent> get events => _gateway.events;
  List<SessionInfo> get sessions => _sessions;
  String? get cookies => _cookies;

  MiMoClawProvider()
      : _gateway = MiMoClawGateway(),
        _auth = MiMoClawAuth() {
    // 监听连接状态变化
    _stateSubscription = _gateway.connectionStateStream.listen((_) {
      notifyListeners();
    });

    // 监听事件
    _eventSubscription = _gateway.events.listen((event) {
      if (event is SessionListEvent) {
        _sessions = event.sessions;
        notifyListeners();
      }
    });
  }

  /// 获取登录 URL
  String getLoginUrl() => _auth.getLoginUrl();

  /// 完成登录（从 WebView 获取 Cookie）
  Future<bool> completeLogin(String cookies) async {
    try {
      // 验证 Cookie
      final isValid = await _auth.validateCookies(cookies);
      if (!isValid) {
        debugPrint('MiMoClawProvider: Cookie 无效');
        return false;
      }

      // 获取用户信息
      final userInfo = await _auth.getUserInfo(cookies);
      if (userInfo != null) {
        _nickname = userInfo['nickname'] as String?;
        _userId = userInfo['userId'] as String?;
      }

      _cookies = cookies;
      _isLoggedIn = true;
      notifyListeners();

      // 连接 Gateway
      await _gateway.connect(cookies: cookies);

      return true;
    } catch (e) {
      debugPrint('MiMoClawProvider: 登录失败: $e');
      return false;
    }
  }

  /// 发送消息
  Future<void> sendMessage(String message, {String? sessionKey}) async {
    if (!_isLoggedIn) throw Exception('未登录');
    await _gateway.sendChatMessage(message: message, sessionKey: sessionKey);
  }

  /// 中止回复
  Future<void> abortChat({String? sessionKey}) async {
    await _gateway.abortChat(sessionKey: sessionKey);
  }

  /// 切换模型
  Future<void> setModel(String model, {String? sessionKey}) async {
    await _gateway.setSessionModel(model: model, sessionKey: sessionKey);
  }

  /// 获取历史消息
  Future<List<HistoryMessage>> getHistory({String? sessionKey}) async {
    return await _gateway.getChatHistory(sessionKey: sessionKey);
  }

  /// 设置当前会话
  void setSessionKey(String key) {
    _gateway.setSessionKey(key);
    notifyListeners();
  }

  /// 创建新的 dashboard 会话
  String createNewSession() {
    return _gateway.createDashboardSessionKey();
  }

  /// 断开连接
  void disconnect() {
    _gateway.disconnect();
    notifyListeners();
  }

  /// 注销
  void logout() {
    _gateway.disconnect();
    _cookies = null;
    _nickname = null;
    _userId = null;
    _isLoggedIn = false;
    _sessions = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _stateSubscription?.cancel();
    _gateway.dispose();
    super.dispose();
  }
}
