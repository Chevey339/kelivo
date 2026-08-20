import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/mimo_claw/provider.dart';
import '../../core/services/mimo_claw/gateway.dart';
import 'mimo_claw_login_page.dart';

/// MiMo Claw 设置页面
///
/// 管理 MiMo Claw 的登录状态、连接状态、会话管理
class MiMoClawSettingsPage extends StatefulWidget {
  final MiMoClawProvider provider;

  const MiMoClawSettingsPage({super.key, required this.provider});

  @override
  State<MiMoClawSettingsPage> createState() => _MiMoClawSettingsPageState();
}

class _MiMoClawSettingsPageState extends State<MiMoClawSettingsPage> {
  ConnectionState _connectionState = ConnectionState.disconnected;
  Stream<ConnectionState>? _stateStream;
  List<SessionInfo> _sessions = [];

  @override
  void initState() {
    super.initState();
    _stateStream = widget.provider.connectionStateStream;
    _stateStream?.listen((state) {
      if (mounted) {
        setState(() => _connectionState = state);
      }
    });

    // 监听会话列表
    widget.provider.events.listen((event) {
      if (event is SessionListEvent && mounted) {
        setState(() => _sessions = event.sessions);
      }
    });

    _connectionState = widget.provider.connectionState;
  }

  Future<void> _login() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            MiMoClawLoginPage(provider: widget.provider),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录成功！')),
      );
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认注销'),
        content: const Text('确定要注销 MiMo Claw 账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              widget.provider.logout();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = widget.provider.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MiMo Claw'),
      ),
      body: ListView(
        children: [
          // 登录状态卡片
          _buildStatusCard(isLoggedIn),

          if (isLoggedIn) ...[
            const Divider(),
            // 连接状态
            _buildConnectionTile(),
            // 会话列表
            if (_sessions.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '会话列表',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ),
              ..._sessions.map((s) => _buildSessionTile(s)),
            ],
            const Divider(),
            // 操作按钮
            _buildActionTile(
              icon: Icons.refresh,
              title: '重新连接',
              onTap: () async {
                await widget.provider.completeLogin(
                  widget.provider.isLoggedIn ? '' : '',
                );
              },
            ),
            _buildActionTile(
              icon: Icons.logout,
              title: '注销账号',
              color: Colors.red,
              onTap: _logout,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isLoggedIn) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 头像
            CircleAvatar(
              radius: 40,
              backgroundColor: isLoggedIn
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.grey[300],
              child: Icon(
                isLoggedIn ? Icons.person : Icons.person_outline,
                size: 40,
                color: isLoggedIn
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            // 昵称
            Text(
              isLoggedIn
                  ? (widget.provider.nickname ?? '已登录')
                  : '未登录',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isLoggedIn && widget.provider.userId != null) ...[
              const SizedBox(height: 4),
              Text(
                'ID: ${widget.provider.userId}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
            const SizedBox(height: 16),
            // 登录/注销按钮
            SizedBox(
              width: double.infinity,
              child: isLoggedIn
                  ? OutlinedButton(
                      onPressed: _logout,
                      child: const Text('注销'),
                    )
                  : FilledButton(
                      onPressed: _login,
                      child: const Text('登录 MiMo Claw'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionTile() {
    final (icon, color, text) = switch (_connectionState) {
      ConnectionState.connected => (
          Icons.check_circle,
          Colors.green,
          '已连接'
        ),
      ConnectionState.connecting => (
          Icons.sync,
          Colors.orange,
          '连接中...'
        ),
      ConnectionState.disconnected => (
          Icons.cloud_off,
          Colors.grey,
          '未连接'
        ),
    };

    return ListTile(
      leading: Icon(icon, color: color),
      title: const Text('连接状态'),
      subtitle: Text(text),
    );
  }

  Widget _buildSessionTile(SessionInfo session) {
    return ListTile(
      leading: const Icon(Icons.chat_bubble_outline),
      title: Text(
        session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(session.model),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        widget.provider.setSessionKey(session.key);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已切换到: ${session.title}')),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
