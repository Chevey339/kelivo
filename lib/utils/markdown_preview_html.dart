import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class MarkdownPreviewHtmlBuilder {
  static Future<String> buildFromMarkdown(BuildContext context, String markdown) async {
    final cs = Theme.of(context).colorScheme;
    // TODO: Handle rootBundle.loadString failures (missing asset / read error) with a safe fallback.
    final template = await rootBundle.loadString('assets/html/mark.html');
    // TODO: Confirm token semantics; BACKGROUND vs SURFACE (and ON_* variants) currently map to the same colors.
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
    // TODO: Fix _toCssHex implementation; output CSS hex as #RRGGBB or #RRGGBBAA (CSS Color Level 4).
    final a = _toHex(_to8Bit(c.a));
    final r = _toHex(_to8Bit(c.r));
    final g = _toHex(_to8Bit(c.g));
    final b = _toHex(_to8Bit(c.b));
    return '#$r$g$b$a';
  }

  static String _toHex(int value) =>
      value.toRadixString(16).padLeft(2, '0').toUpperCase();

  static int _to8Bit(double value) =>
      (value * 255.0).round().clamp(0, 255).toInt();
}

extension Base64X on String {
  String base64EncodeString() => base64Encode(utf8.encode(this));
  String base64DecodeString() => utf8.decode(base64Decode(this));
}

