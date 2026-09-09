import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/theme/chat_bubble_style.dart';

import 'frosted/frosted_surface.dart';

({ChatMessageBackgroundStyle style, ChatBubbleStyleOverrides overrides})
_chatSurfaceStyleSelection(BuildContext context, {bool isUser = false}) {
  try {
    return context.select<
      SettingsProvider,
      ({ChatMessageBackgroundStyle style, ChatBubbleStyleOverrides overrides})
    >(
      (s) => (
        style: s.chatMessageBackgroundStyle,
        overrides: s.chatBubbleStyleOverridesFor(isUser: isUser),
      ),
    );
  } on ProviderNotFoundException {
    return (
      style: ChatMessageBackgroundStyle.defaultStyle,
      overrides: const ChatBubbleStyleOverrides(),
    );
  }
}

Color chatSurfacePlainTextColor(BuildContext context, {bool isUser = false}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final selection = _chatSurfaceStyleSelection(context, isUser: isUser);
  if (selection.style == ChatMessageBackgroundStyle.defaultStyle) {
    return cs.onSurface;
  }
  return resolveBubbleStyle(
    cs,
    theme.brightness,
    selection.style,
    selection.overrides,
  ).text;
}

Widget buildSharedChatSurface(
  BuildContext context, {
  required Widget child,
  required BorderRadius borderRadius,
  required EdgeInsetsGeometry padding,
  Color? defaultColor,
  bool bareOnDefault = false,
  bool isUser = false,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final selection = _chatSurfaceStyleSelection(context, isUser: isUser);
  final style = selection.style;
  final overrides = selection.overrides;
  final resolved = resolveBubbleStyle(cs, theme.brightness, style, overrides);
  Widget paddedChild = Padding(padding: padding, child: child);
  if (style != ChatMessageBackgroundStyle.defaultStyle &&
      overrides.hasTextOverride(theme.brightness)) {
    paddedChild = DefaultTextStyle.merge(
      style: TextStyle(color: resolved.text),
      child: paddedChild,
    );
  }

  switch (style) {
    case ChatMessageBackgroundStyle.frosted:
      final radius = BorderRadius.circular(resolved.radius);
      return FrostedSurface(
        style: resolved,
        borderRadius: radius,
        isUser: isUser,
        child: paddedChild,
      );
    case ChatMessageBackgroundStyle.solid:
      final radius = BorderRadius.circular(resolved.radius);
      return DecoratedBox(
        decoration: BoxDecoration(
          color: resolved.background,
          borderRadius: radius,
          border: Border.all(
            color: resolved.border,
            width: resolved.borderWidth,
          ),
        ),
        child: paddedChild,
      );
    case ChatMessageBackgroundStyle.defaultStyle:
      if (bareOnDefault) {
        return child;
      }
      if (defaultColor == null) {
        return paddedChild;
      }
      return DecoratedBox(
        decoration: BoxDecoration(
          color: defaultColor,
          borderRadius: borderRadius,
        ),
        child: paddedChild,
      );
  }
}

class ChatSurfaceForegroundPalette {
  const ChatSurfaceForegroundPalette({
    required this.strong,
    required this.medium,
    required this.muted,
    required this.body,
    required this.divider,
    required this.accent,
  });

  final Color strong;
  final Color medium;
  final Color muted;
  final Color body;
  final Color divider;
  final Color accent;

  @override
  bool operator ==(Object other) =>
      other is ChatSurfaceForegroundPalette &&
      other.strong == strong &&
      other.medium == medium &&
      other.muted == muted &&
      other.body == body &&
      other.divider == divider &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(strong, medium, muted, body, divider, accent);
}

class ChatSurfaceTheme extends InheritedWidget {
  const ChatSurfaceTheme({
    super.key,
    required this.palette,
    required super.child,
  });

  final ChatSurfaceForegroundPalette palette;

  static ChatSurfaceForegroundPalette? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ChatSurfaceTheme>()
        ?.palette;
  }

  @override
  bool updateShouldNotify(ChatSurfaceTheme oldWidget) =>
      palette != oldWidget.palette;
}

ChatSurfaceForegroundPalette chatSurfaceForegroundPalette(
  BuildContext context, {
  bool isUser = false,
}) {
  if (!isUser) {
    final inherited = ChatSurfaceTheme.maybeOf(context);
    if (inherited != null) return inherited;
  }
  return computeChatSurfaceForegroundPalette(context, isUser: isUser);
}

ChatSurfaceForegroundPalette computeChatSurfaceForegroundPalette(
  BuildContext context, {
  bool isUser = false,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final selection = _chatSurfaceStyleSelection(context, isUser: isUser);
  if (selection.style == ChatMessageBackgroundStyle.defaultStyle) {
    return ChatSurfaceForegroundPalette(
      strong: cs.secondary,
      medium: cs.secondary.withValues(alpha: 0.9),
      muted: cs.onSurface.withValues(alpha: 0.5),
      body: cs.onSurface.withValues(alpha: 0.7),
      divider: theme.brightness == Brightness.dark
          ? cs.onSurface.withValues(alpha: 0.24)
          : cs.outline.withValues(alpha: 0.15),
      accent: cs.primary,
    );
  }

  final base = resolveBubbleStyle(
    cs,
    theme.brightness,
    selection.style,
    selection.overrides,
  ).text;
  final bool isDark = theme.brightness == Brightness.dark;
  return ChatSurfaceForegroundPalette(
    strong: base.withValues(alpha: isDark ? 0.88 : 0.78),
    medium: base.withValues(alpha: isDark ? 0.76 : 0.66),
    muted: base.withValues(alpha: isDark ? 0.56 : 0.46),
    body: base.withValues(alpha: isDark ? 0.72 : 0.6),
    divider: base.withValues(alpha: isDark ? 0.16 : 0.14),
    accent: base.withValues(alpha: isDark ? 0.84 : 0.74),
  );
}
