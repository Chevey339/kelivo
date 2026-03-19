import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../l10n/app_localizations.dart';

class HtmlPreviewPage extends StatefulWidget {
  const HtmlPreviewPage({super.key, required this.html});
  final String html;

  @override
  State<HtmlPreviewPage> createState() => _HtmlPreviewPageState();
}

class _HtmlPreviewPageState extends State<HtmlPreviewPage> {
  late final WebViewController _controller;
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safe place to access Theme.of(context)
    if (!_didInit) {
      _didInit = true;
      _loadHtml();
    } else {
      // Reload on theme changes
      _loadHtml();
    }
  }

  Future<void> _loadHtml() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final html = _wrapIfNeeded(widget.html, isDark: isDark);
    await _controller.loadHtmlString(html);
  }

  String _wrapIfNeeded(String input, {required bool isDark}) {
    final hasHtmlTag = input.toLowerCase().contains('<html');
    final hasBodyTag = input.toLowerCase().contains('<body');
    if (hasHtmlTag && hasBodyTag) return input;
    final bg = isDark ? '#111111' : '#ffffff';
    final fg = isDark ? '#eaeaea' : '#222222';
    return '''<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
      html, body { background: $bg; color: $fg; margin: 0; padding: 0; }
      .container { padding: 12px; }
      img, video, canvas, iframe { max-width: 100%; height: auto; }
      pre, code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; }
    </style>
  </head>
  <body>
    <div class="container">
      $input
    </div>
  </body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.assistantEditPreviewTitle)),
      body: SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }
}
