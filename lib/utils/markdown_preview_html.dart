import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class MarkdownPreviewHtmlBuilder {
  static const String _fallbackTemplate = '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    :root {
      color-scheme: light dark;
    }
    body {
      margin: 0;
      padding: 16px;
      background: {{BACKGROUND_COLOR}};
      color: {{ON_BACKGROUND_COLOR}};
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
      line-height: 1.5;
      white-space: pre-wrap;
      word-break: break-word;
    }
    pre {
      margin: 0;
      font-family: inherit;
    }
  </style>
</head>
<body>
  <pre id="content"></pre>
  <script>
    (function () {
      var b64 = '{{MARKDOWN_BASE64}}';
      function b64ToUtf8(value) {
        try {
          return decodeURIComponent(escape(atob(value)));
        } catch (e) {
          try { return atob(value); } catch (_) { return ''; }
        }
      }
      var text = b64ToUtf8(b64);
      var el = document.getElementById('content');
      if (el) el.textContent = text;
    })();
  </script>
</body>
</html>
''';

  static Future<String> buildFromMarkdown(BuildContext context, String markdown) async {
    final cs = Theme.of(context).colorScheme;
    String template;
    try {
      template = await rootBundle.loadString('assets/html/mark.html');
    } catch (e, s) {
      debugPrint('Failed to load markdown HTML template: $e');
      debugPrintStack(stackTrace: s);
      template = _fallbackTemplate;
    }
    // TODO: Decide token semantics (BACKGROUND vs SURFACE, and ON_* variants). If undecided, track via a GitHub issue and reference it here.
    return template
        .replaceAll('{{MARKDOWN_BASE64}}', base64Encode(utf8.encode(markdown)))
        .replaceAll('{{BACKGROUND_COLOR}}', _toCssHex(cs.surface))
        .replaceAll('{{ON_BACKGROUND_COLOR}}', _toCssHex(cs.onSurface))
        .replaceAll('{{SURFACE_COLOR}}', _toCssHex(cs.surface))
        .replaceAll('{{ON_SURFACE_COLOR}}', _toCssHex(cs.onSurface))
        .replaceAll('{{SURFACE_VARIANT_COLOR}}', _toCssHex(cs.surfaceContainerHighest))
        .replaceAll('{{ON_SURFACE_VARIANT_COLOR}}', _toCssHex(cs.onSurfaceVariant))
        .replaceAll('{{PRIMARY_COLOR}}', _toCssHex(cs.primary))
        .replaceAll('{{OUTLINE_COLOR}}', _toCssHex(cs.outline))
        .replaceAll('{{OUTLINE_VARIANT_COLOR}}', _toCssHex(cs.outlineVariant));
  }

  static String _toCssHex(Color c) {
    final r = _toHex(_to8Bit(c.r));
    final g = _toHex(_to8Bit(c.g));
    final b = _toHex(_to8Bit(c.b));
    final a = _to8Bit(c.a);
    if (a == 0xFF) {
      return '#$r$g$b';
    }
    final aHex = _toHex(a);
    return '#$r$g$b$aHex';
  }

  static int _to8Bit(double value) =>
      (value * 255.0).round().clamp(0, 255).toInt();

  static String _toHex(int value) =>
      value.toRadixString(16).padLeft(2, '0').toUpperCase();

}

extension Base64X on String {
  String base64EncodeString() => base64Encode(utf8.encode(this));
  String base64DecodeString() => utf8.decode(base64Decode(this));
}

