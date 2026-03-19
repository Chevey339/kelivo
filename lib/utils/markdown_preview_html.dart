import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class MarkdownPreviewHtmlBuilder {
  static Future<String> buildFromMarkdown(
    BuildContext context,
    String markdown,
  ) async {
    return buildFromMarkdownWithColorScheme(
      Theme.of(context).colorScheme,
      markdown,
    );
  }

  static Future<String> buildFromMarkdownWithColorScheme(
    ColorScheme cs,
    String markdown,
  ) async {
    final template = await rootBundle.loadString('assets/html/mark.html');
    return template
        .replaceAll('{{MARKDOWN_BASE64}}', base64Encode(utf8.encode(markdown)))
        .replaceAll('{{BACKGROUND_COLOR}}', _toCssHex(cs.surface))
        .replaceAll('{{ON_BACKGROUND_COLOR}}', _toCssHex(cs.onSurface))
        .replaceAll('{{SURFACE_COLOR}}', _toCssHex(cs.surface))
        .replaceAll('{{ON_SURFACE_COLOR}}', _toCssHex(cs.onSurface))
        .replaceAll(
          '{{SURFACE_VARIANT_COLOR}}',
          _toCssHex(cs.surfaceContainerHighest),
        )
        .replaceAll(
          '{{ON_SURFACE_VARIANT_COLOR}}',
          _toCssHex(cs.onSurfaceVariant),
        )
        .replaceAll('{{PRIMARY_COLOR}}', _toCssHex(cs.primary))
        .replaceAll('{{OUTLINE_COLOR}}', _toCssHex(cs.outline))
        .replaceAll('{{OUTLINE_VARIANT_COLOR}}', _toCssHex(cs.outlineVariant));
  }

  static String _toCssHex(Color c) {
    int to255(double v) => (v * 255.0).round().clamp(0, 255);
    final a = to255(c.a).toRadixString(16).padLeft(2, '0').toUpperCase();
    final r = to255(c.r).toRadixString(16).padLeft(2, '0').toUpperCase();
    final g = to255(c.g).toRadixString(16).padLeft(2, '0').toUpperCase();
    final b = to255(c.b).toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#$r$g$b$a';
  }
}

extension Base64X on String {
  String base64EncodeString() => base64Encode(utf8.encode(this));
  String base64DecodeString() => utf8.decode(base64Decode(this));
}
