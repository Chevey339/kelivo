import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/services/mimo_claw/provider.dart';

/// MiMo Claw 登录页面
///
/// 使用 WebView 加载小米账号 SSO 登录，
/// 登录成功后从 Cookie 中提取 ph 值
class MiMoClawLoginPage extends StatefulWidget {
  final MiMoClawProvider provider;

  const MiMoClawLoginPage({super.key, required this.provider});

  @override
  State<MiMoClawLoginPage> createState() => _MiMoClawLoginPageState();
}

class _MiMoClawLoginPageState extends State<MiMoClawLoginPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _error = null;
            });
          },
          onPageFinished: (url) async {
            setState(() => _isLoading = false);
            await _checkLoginStatus(url);
          },
          onNavigationRequest: (request) async {
            // 检查是否是登录成功的回调
            if (request.url.contains('aistudio.xiaomimimo.com/sts') ||
                request.url.contains('aistudio.xiaomimimo.com/')) {
              await _checkLoginStatus(request.url);
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.provider.getLoginUrl()));
  }

  Future<void> _checkLoginStatus(String url) async {
    try {
      // 从 WebView 获取 Cookie
      final cookies = await _controller
          .runJavaScriptReturningResult('document.cookie') as String;

      if (cookies.isEmpty) return;

      // 提取 ph 值
      final ph = widget.provider.getLoginUrl().isNotEmpty
          ? _extractPhFromCookieString(cookies)
          : null;

      if (ph == null || ph.isEmpty) return;

      // 构建完整的 Cookie 字符串
      final fullCookies = 'xiaomichatbot_ph=$ph';

      // 尝试登录
      final success = await widget.provider.completeLogin(fullCookies);

      if (success && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('检查登录状态失败: $e');
    }
  }

  String? _extractPhFromCookieString(String cookieStr) {
    // 从 JavaScript 返回的 cookie 字符串中提取 ph
    final parts = cookieStr.split(';');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.startsWith('xiaomichatbot_ph=')) {
        return trimmed
            .substring('xiaomichatbot_ph='.length)
            .replaceAll('"', '');
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录 MiMo Claw'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (_error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _controller.loadRequest(
                        Uri.parse(widget.provider.getLoginUrl()),
                      );
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
