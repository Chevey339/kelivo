import 'package:flutter/material.dart';

import '../../core/ast/nodes.dart';
import '../theme/markstream_theme.dart';

TextStyle highlightedTextStyle(TextStyle base, MarkstreamTheme theme) =>
    base.copyWith(
      color: theme.brightness == Brightness.dark
          ? const Color(0xffffedb0)
          : const Color(0xff302600),
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xff665214)
          : const Color(0xffffdf73),
    );

/// The native subset accepts paint/text properties, never browser CSS or URLs.
TextStyle htmlTextStyle(
  HtmlElementNode node,
  TextStyle base,
  MarkstreamTheme theme,
) {
  var style = base;
  void decoration(TextDecoration value) {
    style = style.copyWith(
      decoration: TextDecoration.combine([
        if (style.decoration != null) style.decoration!,
        value,
      ]),
    );
  }

  switch (node.tag) {
    case 'b' || 'strong':
      style = style.copyWith(fontWeight: theme.strongWeight);
    case 'i' || 'em':
      style = style.copyWith(fontStyle: FontStyle.italic);
    case 'u':
      decoration(TextDecoration.underline);
    case 's' || 'del':
      decoration(TextDecoration.lineThrough);
    case 'mark':
      style = highlightedTextStyle(style, theme);
    case 'font':
      style = style.copyWith(color: htmlColor(node.attributes['color']));
  }
  if (node.tag != 'span') return style;
  for (final rule in (node.attributes['style'] ?? '').split(';')) {
    final colon = rule.indexOf(':');
    if (colon < 0) continue;
    final key = rule.substring(0, colon).trim().toLowerCase();
    final value = rule.substring(colon + 1).trim().toLowerCase();
    switch (key) {
      case 'color':
        style = style.copyWith(color: htmlColor(value));
      case 'background-color':
        style = style.copyWith(backgroundColor: htmlColor(value));
      case 'font-weight':
        final weight = int.tryParse(value);
        if (value == 'bold' || value == 'bolder') {
          style = style.copyWith(fontWeight: theme.strongWeight);
        } else if (value == 'normal') {
          style = style.copyWith(fontWeight: FontWeight.normal);
        } else if (weight != null && weight >= 100 && weight <= 900) {
          style = style.copyWith(
            fontWeight: FontWeight.values[(weight ~/ 100) - 1],
          );
        }
      case 'font-style':
        if (value == 'italic' || value == 'oblique')
          style = style.copyWith(fontStyle: FontStyle.italic);
        if (value == 'normal')
          style = style.copyWith(fontStyle: FontStyle.normal);
      case 'text-decoration':
        if (value == 'none')
          style = style.copyWith(decoration: TextDecoration.none);
        if (value.contains('underline')) decoration(TextDecoration.underline);
        if (value.contains('line-through'))
          decoration(TextDecoration.lineThrough);
      case 'font-size':
        final match = RegExp(r'^(\d+(?:\.\d+)?)(px|em|%)$').firstMatch(value);
        if (match != null) {
          final amount = double.parse(match[1]!);
          final size = switch (match[2]) {
            'em' => amount * (base.fontSize ?? 15.5),
            '%' => amount * (base.fontSize ?? 15.5) / 100,
            _ => amount,
          };
          if (size.isFinite && size > 0)
            style = style.copyWith(fontSize: size.clamp(1, 96));
        }
    }
  }
  return style;
}

Color? htmlColor(String? raw) {
  if (raw == null) return null;
  final value = raw.trim().toLowerCase();
  const names = {
    'black': 0xff000000,
    'silver': 0xffc0c0c0,
    'gray': 0xff808080,
    'grey': 0xff808080,
    'white': 0xffffffff,
    'maroon': 0xff800000,
    'red': 0xffff0000,
    'purple': 0xff800080,
    'fuchsia': 0xffff00ff,
    'green': 0xff008000,
    'lime': 0xff00ff00,
    'olive': 0xff808000,
    'yellow': 0xffffff00,
    'navy': 0xff000080,
    'blue': 0xff0000ff,
    'teal': 0xff008080,
    'aqua': 0xff00ffff,
    'orange': 0xffffa500,
    'rebeccapurple': 0xff663399,
    'transparent': 0x00000000,
  };
  if (names[value] case final color?) return Color(color);
  if (RegExp(r'^#[a-f0-9]{3,8}$').hasMatch(value)) {
    var digits = value.substring(1);
    if (digits.length == 3 || digits.length == 4)
      digits = digits.split('').map((c) => '$c$c').join();
    if (digits.length == 6)
      return Color(0xff000000 | int.parse(digits, radix: 16));
    if (digits.length == 8) {
      final rgba = int.parse(digits, radix: 16);
      return Color((rgba & 0xff) << 24 | rgba >> 8);
    }
    return null;
  }
  final match = RegExp(r'^rgba?\(([^()]*)\)$').firstMatch(value);
  if (match == null) return null;
  final parts = match[1]!.split(',').map((p) => p.trim()).toList();
  if (parts.length != 3 && parts.length != 4) return null;
  double? component(String part, double limit) {
    final percent = part.endsWith('%');
    final n = double.tryParse(
      percent ? part.substring(0, part.length - 1) : part,
    );
    if (n == null || !n.isFinite) return null;
    return (percent ? n * limit / 100 : n).clamp(0, limit);
  }

  final r = component(parts[0], 255),
      g = component(parts[1], 255),
      b = component(parts[2], 255);
  final alpha = parts.length == 4 ? component(parts[3], 1) : 1.0;
  if (r == null || g == null || b == null || alpha == null) return null;
  return Color.fromARGB((alpha * 255).round(), r.round(), g.round(), b.round());
}
