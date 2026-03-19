import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

/// A single-emoji Text widget with cross‑platform alignment tweaks.
class EmojiText extends StatelessWidget {
  const EmojiText(
    this.text, {
    super.key,
    this.fontSize = 20,
    this.figmaLineHeight,
    this.lineHeight,
    this.textAlign = TextAlign.center,
    this.optimizeEmojiAlign = true,
    this.nudge,
  });

  final String text;
  final double fontSize;
  final double? figmaLineHeight;
  final double? lineHeight;
  final TextAlign textAlign;
  final bool optimizeEmojiAlign;
  final Offset? nudge; // optional explicit offset override

  @override
  Widget build(BuildContext context) {
    // Ensure we render at most one grapheme (ZWJ sequences remain intact)
    final String glyph = text.characters.take(1).toString();

    // Optional platform-specific scaling for Windows to reduce line jitter
    final bool isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    const double winScale = 0.9;
    final double scaleFactor = isWindows ? winScale : 1.0;
    double fs = fontSize * scaleFactor;

    // Compute effective height from figmaLineHeight or explicit lineHeight
    double? effectiveHeight;
    if (figmaLineHeight != null && figmaLineHeight! > 0) {
      // Height is ratio of line px to current font size
      effectiveHeight = figmaLineHeight! / fs;
    } else if (lineHeight != null && lineHeight! > 0) {
      // Keep visual line height stable when scaling font
      effectiveHeight = (lineHeight! / scaleFactor) / fs;
    } else if (optimizeEmojiAlign) {
      // Default to 1.0 for stable, compact single-emoji rows
      effectiveHeight = 1.0;
    }

    // Common fallback families to improve emoji availability.
    // These only take effect if present on the system.
    const List<String> fallback = <String>[
      'Apple Color Emoji',
      'Segoe UI Emoji',
      'Noto Color Emoji',
      'Twemoji Mozilla',
      'EmojiOne Color',
    ];

    final TextStyle base = DefaultTextStyle.of(context).style;
    final TextStyle style = base.copyWith(
      fontSize: fs,
      height: effectiveHeight,
      // Encourage even leading distribution for better visual centering
      leadingDistribution: optimizeEmojiAlign
          ? TextLeadingDistribution.even
          : null,
      fontFamilyFallback: fallback,
      decoration: TextDecoration.none,
    );

    // Platform-directed micro-nudge to counter platform font bearings.
    double dx = 0, dy = 0;
    if (optimizeEmojiAlign) {
      if (nudge != null) {
        dx = nudge!.dx;
        dy = nudge!.dy;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS
        dx = fs * 0.04; // ~5% right
        dy = fs * -0.075; // ~1.2% up
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        // macOS
        dx = fs * 0.08; // ~3.5% right
        dy = fs * -0.008; // ~0.8% up
      } else if (isWindows) {
        // Windows (Segoe UI Emoji)
        dx = fs * 0.015; // slight right
        dy = 0;
      } else {
        // Linux/others (Noto, etc.)
        dx = fs * 0.012; // tiny right
        dy = 0;
      }
    }

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Text(
        glyph,
        textAlign: textAlign,
        style: style,
        // Use StrutStyle to stabilize line metrics across platforms
        strutStyle: StrutStyle(
          forceStrutHeight: true,
          height: style.height,
          leading: 0,
          fontSize: style.fontSize,
          fontFamily: style.fontFamily,
          fontFamilyFallback: style.fontFamilyFallback,
        ),
      ),
    );
  }
}
