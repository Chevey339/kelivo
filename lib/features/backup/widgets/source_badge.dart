import 'package:flutter/material.dart';

import '../../../core/models/unified_thread.dart';

/// A small colored badge showing which chat source a thread comes from.
class SourceBadge extends StatelessWidget {
  final String source;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const SourceBadge({
    super.key,
    required this.source,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = _sourceInfo(source);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  (String, Color) _sourceInfo(String source) {
    switch (source) {
      case 'chatgpt':
        return ('ChatGPT', const Color(0xFF10A37F));
      case 'gemini':
        return ('Gemini', const Color(0xFF4285F4));
      case 'perplexity':
        return ('Perplexity', const Color(0xFF5436DA));
      case 'claude':
        return ('Claude', const Color(0xFFD97706));
      case 'kelivo':
        return ('Kelivo', const Color(0xFF6366F1));
      default:
        return ('Other', Colors.grey);
    }
  }
}
