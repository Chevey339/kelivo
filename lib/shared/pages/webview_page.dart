import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key, this.url, this.contentBase64});
  final String? url;
  final String? contentBase64; // HTML string in Base64

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  String? _title;
  String? _currentUrl;
  bool _isLoading = true;
  int _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  final List<_ConsoleMessage> _console = <_ConsoleMessage>[];

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('Console', onMessageReceived: _onConsoleMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            setState(() {
              _isLoading = p < 100;
              _progress = p;
            });
          },
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) async {
            setState(() {
              _isLoading = false;
              _progress = 100;
              _currentUrl = url;
            });
            await _refreshCanGoStates();
            await _updateTitle();
          },
          onWebResourceError: (err) {
            _pushConsole(
              level: 'error',
              message: 'Web error ${err.errorCode}: ${err.description}',
              source: _currentUrl,
            );
          },
        ),
      );
    // Initial load
    scheduleMicrotask(_initialLoad);
  }

  Future<void> _initialLoad() async {
    if (defaultTargetPlatform == TargetPlatform.linux) {
      // Keep parity with existing Linux limitation: no WebView support
      final l10n = AppLocalizations.of(context)!;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.htmlPreviewNotSupportedOnLinux)),
      );
      Navigator.of(context).maybePop();
      return;
    }
    final url = widget.url?.trim() ?? '';
    if (url.isNotEmpty) {
      await _controller.loadRequest(Uri.parse(url));
    } else {
      final data = widget.contentBase64 ?? '';
      final html = data.isEmpty
          ? '<!doctype html><html><body></body></html>'
          : utf8.decode(base64Decode(data));
      await _controller.loadHtmlString(html);
    }
  }

  void _onConsoleMessage(JavaScriptMessage msg) {
    try {
      final obj = jsonDecode(msg.message) as Map<String, dynamic>;
      _pushConsole(
        level: obj['level']?.toString() ?? 'log',
        message: obj['message']?.toString() ?? '',
        source: obj['source']?.toString(),
        line: (obj['line'] as num?)?.toInt(),
      );
    } catch (_) {
      _pushConsole(level: 'log', message: msg.message);
    }
  }

  void _pushConsole({
    required String level,
    required String message,
    String? source,
    int? line,
  }) {
    setState(() {
      _console.add(
        _ConsoleMessage(
          level: level.toUpperCase(),
          message: message,
          source: source,
          line: line,
        ),
      );
      if (_console.length > 128) {
        _console.removeRange(0, _console.length - 128);
      }
    });
  }

  Future<void> _updateTitle() async {
    try {
      final t = await _controller.runJavaScriptReturningResult(
        'document.title',
      );
      setState(() {
        _title = _stripJsString(t);
      });
    } catch (_) {}
  }

  String? _stripJsString(Object? v) {
    if (v == null) return null;
    var s = '$v';
    if (s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1);
    }
    return s;
  }

  Future<void> _refreshCanGoStates() async {
    try {
      final back = await _controller.canGoBack();
      final fwd = await _controller.canGoForward();
      setState(() {
        _canGoBack = back;
        _canGoForward = fwd;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool contentMode =
        (widget.contentBase64 != null && (widget.contentBase64!.isNotEmpty)) &&
        ((widget.url == null) || widget.url!.isEmpty);
    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_canGoBack) {
          _controller.goBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _title?.isNotEmpty == true ? _title! : (_currentUrl ?? ''),
          ),
          actions: [
            if (!contentMode) ...[
              IconButton(
                tooltip: l10n.messageWebViewRefreshTooltip,
                onPressed: () => _controller.reload(),
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: l10n.messageWebViewForwardTooltip,
                onPressed: _canGoForward ? () => _controller.goForward() : null,
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'open':
                    if (!contentMode) {
                      final url = _currentUrl;
                      if (url != null && url.trim().isNotEmpty) {
                        final uri = Uri.tryParse(url);
                        if (uri != null) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      }
                    }
                    break;
                  case 'console':
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) => _ConsoleSheet(messages: _console),
                    );
                    break;
                }
              },
              itemBuilder: (ctx) => [
                if (!contentMode)
                  PopupMenuItem<String>(
                    value: 'open',
                    child: Text(l10n.messageWebViewOpenInBrowser),
                  ),
                PopupMenuItem<String>(
                  value: 'console',
                  child: Text(l10n.messageWebViewConsoleLogs),
                ),
              ],
            ),
          ],
          leading: IconButton(
            icon: Icon(_canGoBack ? Icons.arrow_back : Icons.close),
            onPressed: () async {
              if (_canGoBack) {
                _controller.goBack();
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
        ),
        body: Column(
          children: [
            if (_isLoading)
              LinearProgressIndicator(
                value: _progress > 0 ? _progress / 100 : null,
              ),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}

class _ConsoleMessage {
  _ConsoleMessage({
    required this.level,
    required this.message,
    this.source,
    this.line,
  });
  final String level;
  final String message;
  final String? source;
  final int? line;
}

class _ConsoleSheet extends StatelessWidget {
  const _ConsoleSheet({required this.messages});
  final List<_ConsoleMessage> messages;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.messageWebViewConsoleLogs,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (messages.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  l10n.messageWebViewNoConsoleMessages,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: messages.length,
                itemBuilder: (ctx, i) {
                  final m = messages[i];
                  Color c;
                  switch (m.level) {
                    case 'ERROR':
                      c = cs.error;
                      break;
                    case 'WARN':
                    case 'WARNING':
                      c = cs.secondary;
                      break;
                    default:
                      c = cs.onSurface;
                      break;
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${m.level}: ${m.message}\nSource: ${m.source ?? ''}${m.line != null ? ':${m.line}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
