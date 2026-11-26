import 'package:flutter/material.dart';

import '../core/providers/settings_provider.dart';

enum ChatBubbleStyleTarget { user, assistant, thinkingToolCard }

/// Optional overrides for frosted/solid chat bubbles.
///
/// Every field is nullable. `null` means keep today's hardcoded default
/// (theme-following colors, 0.8pt border, 16pt corners, sigma 14, etc.).
class ChatBubbleStyleOverrides {
  const ChatBubbleStyleOverrides({
    this.backgroundArgbLight,
    this.backgroundArgbDark,
    this.borderArgbLight,
    this.borderArgbDark,
    this.textArgbLight,
    this.textArgbDark,
    this.borderWidth,
    this.borderOpacity,
    this.cornerRadius,
    this.blurSigma,
    this.frostedOpacity,
    this.solidOpacity,
  });

  // Shared colors (RGB; alpha comes from the opacity fields).
  final int? backgroundArgbLight;
  final int? backgroundArgbDark;
  final int? borderArgbLight;
  final int? borderArgbDark;
  final int? textArgbLight;
  final int? textArgbDark;

  // Shared geometry.
  final double? borderWidth; // null -> 0.8
  final double? borderOpacity; // null -> frosted 0.14 / solid 0.16
  final double? cornerRadius; // null -> 16

  // Per-style.
  final double? blurSigma; // frosted only, null -> 14
  final double? frostedOpacity; // null -> 0.66
  final double? solidOpacity; // null -> 1.0

  bool get isDefault =>
      backgroundArgbLight == null &&
      backgroundArgbDark == null &&
      borderArgbLight == null &&
      borderArgbDark == null &&
      textArgbLight == null &&
      textArgbDark == null &&
      borderWidth == null &&
      borderOpacity == null &&
      cornerRadius == null &&
      blurSigma == null &&
      frostedOpacity == null &&
      solidOpacity == null;

  bool hasTextOverride(Brightness brightness) => brightness == Brightness.dark
      ? textArgbDark != null
      : textArgbLight != null;

  ChatBubbleStyleOverrides copyWith({
    int? Function()? backgroundArgbLight,
    int? Function()? backgroundArgbDark,
    int? Function()? borderArgbLight,
    int? Function()? borderArgbDark,
    int? Function()? textArgbLight,
    int? Function()? textArgbDark,
    double? Function()? borderWidth,
    double? Function()? borderOpacity,
    double? Function()? cornerRadius,
    double? Function()? blurSigma,
    double? Function()? frostedOpacity,
    double? Function()? solidOpacity,
  }) {
    return ChatBubbleStyleOverrides(
      backgroundArgbLight: backgroundArgbLight != null
          ? backgroundArgbLight()
          : this.backgroundArgbLight,
      backgroundArgbDark: backgroundArgbDark != null
          ? backgroundArgbDark()
          : this.backgroundArgbDark,
      borderArgbLight: borderArgbLight != null
          ? borderArgbLight()
          : this.borderArgbLight,
      borderArgbDark: borderArgbDark != null
          ? borderArgbDark()
          : this.borderArgbDark,
      textArgbLight: textArgbLight != null
          ? textArgbLight()
          : this.textArgbLight,
      textArgbDark: textArgbDark != null ? textArgbDark() : this.textArgbDark,
      borderWidth: borderWidth != null ? borderWidth() : this.borderWidth,
      borderOpacity: borderOpacity != null
          ? borderOpacity()
          : this.borderOpacity,
      cornerRadius: cornerRadius != null ? cornerRadius() : this.cornerRadius,
      blurSigma: blurSigma != null ? blurSigma() : this.blurSigma,
      frostedOpacity: frostedOpacity != null
          ? frostedOpacity()
          : this.frostedOpacity,
      solidOpacity: solidOpacity != null ? solidOpacity() : this.solidOpacity,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (backgroundArgbLight != null) 'backgroundArgbLight': backgroundArgbLight,
    if (backgroundArgbDark != null) 'backgroundArgbDark': backgroundArgbDark,
    if (borderArgbLight != null) 'borderArgbLight': borderArgbLight,
    if (borderArgbDark != null) 'borderArgbDark': borderArgbDark,
    if (textArgbLight != null) 'textArgbLight': textArgbLight,
    if (textArgbDark != null) 'textArgbDark': textArgbDark,
    if (borderWidth != null) 'borderWidth': borderWidth,
    if (borderOpacity != null) 'borderOpacity': borderOpacity,
    if (cornerRadius != null) 'cornerRadius': cornerRadius,
    if (blurSigma != null) 'blurSigma': blurSigma,
    if (frostedOpacity != null) 'frostedOpacity': frostedOpacity,
    if (solidOpacity != null) 'solidOpacity': solidOpacity,
  };

  factory ChatBubbleStyleOverrides.fromJson(Map<String, dynamic> json) {
    return ChatBubbleStyleOverrides(
      backgroundArgbLight: _asInt(json['backgroundArgbLight']),
      backgroundArgbDark: _asInt(json['backgroundArgbDark']),
      borderArgbLight: _asInt(json['borderArgbLight']),
      borderArgbDark: _asInt(json['borderArgbDark']),
      textArgbLight: _asInt(json['textArgbLight']),
      textArgbDark: _asInt(json['textArgbDark']),
      borderWidth: _asDouble(json['borderWidth']),
      borderOpacity: _asDouble(json['borderOpacity']),
      cornerRadius: _asDouble(json['cornerRadius']),
      blurSigma: _asDouble(json['blurSigma']),
      frostedOpacity: _asDouble(json['frostedOpacity']),
      solidOpacity: _asDouble(json['solidOpacity']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChatBubbleStyleOverrides &&
      other.backgroundArgbLight == backgroundArgbLight &&
      other.backgroundArgbDark == backgroundArgbDark &&
      other.borderArgbLight == borderArgbLight &&
      other.borderArgbDark == borderArgbDark &&
      other.textArgbLight == textArgbLight &&
      other.textArgbDark == textArgbDark &&
      other.borderWidth == borderWidth &&
      other.borderOpacity == borderOpacity &&
      other.cornerRadius == cornerRadius &&
      other.blurSigma == blurSigma &&
      other.frostedOpacity == frostedOpacity &&
      other.solidOpacity == solidOpacity;

  @override
  int get hashCode => Object.hash(
    backgroundArgbLight,
    backgroundArgbDark,
    borderArgbLight,
    borderArgbDark,
    textArgbLight,
    textArgbDark,
    borderWidth,
    borderOpacity,
    cornerRadius,
    blurSigma,
    frostedOpacity,
    solidOpacity,
  );
}

class ResolvedBubbleStyle {
  const ResolvedBubbleStyle({
    required this.background,
    required this.border,
    required this.text,
    required this.borderWidth,
    required this.radius,
    required this.blurSigma,
  });

  final Color background;
  final Color border;
  final Color text;
  final double borderWidth;
  final double radius;
  final double blurSigma;
}

/// Resolve overrides + theme + style into the values the chat surface paints.
///
/// Fallbacks match the previous hardcoded frosted/solid branch so leaving
/// every field `null` preserves current pixels.
ResolvedBubbleStyle resolveBubbleStyle(
  ColorScheme cs,
  Brightness brightness,
  ChatMessageBackgroundStyle style,
  ChatBubbleStyleOverrides overrides,
) {
  final isDark = brightness == Brightness.dark;
  final bgArgb = isDark
      ? overrides.backgroundArgbDark
      : overrides.backgroundArgbLight;
  final borderArgb = isDark
      ? overrides.borderArgbDark
      : overrides.borderArgbLight;
  final textArgb = isDark ? overrides.textArgbDark : overrides.textArgbLight;

  final opacity = switch (style) {
    ChatMessageBackgroundStyle.frosted => overrides.frostedOpacity ?? 0.66,
    ChatMessageBackgroundStyle.solid => overrides.solidOpacity ?? 1.0,
    ChatMessageBackgroundStyle.defaultStyle => overrides.solidOpacity ?? 1.0,
  };
  final borderOpacity =
      overrides.borderOpacity ??
      (style == ChatMessageBackgroundStyle.frosted ? 0.14 : 0.16);

  return ResolvedBubbleStyle(
    background: (bgArgb != null ? Color(bgArgb) : cs.surfaceContainerHigh)
        .withValues(alpha: opacity),
    border: (borderArgb != null ? Color(borderArgb) : cs.outlineVariant)
        .withValues(alpha: borderOpacity),
    text: textArgb != null ? Color(textArgb) : cs.onSurface,
    borderWidth: overrides.borderWidth ?? 0.8,
    radius: overrides.cornerRadius ?? 16,
    blurSigma: overrides.blurSigma ?? 14,
  );
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}
