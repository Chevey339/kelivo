import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/theme/chat_bubble_style.dart';

import 'frosted/frosted_surface.dart';
import 'package:Kelivo/shared/markdown/markdown_surface_scope.dart';

({ChatMessageBackgroundStyle style, ChatBubbleStyleOverrides overrides})
_chatSurfaceStyleSelection(BuildContext context, ChatBubbleStyleTarget target) {
  try {
    return context.select<
      SettingsProvider,
      ({ChatMessageBackgroundStyle style, ChatBubbleStyleOverrides overrides})
    >(
      (s) => (
        style: s.chatMessageBackgroundStyle,
        overrides: s.chatBubbleStyleOverridesFor(target),
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
  final selection = _chatSurfaceStyleSelection(
    context,
    isUser ? ChatBubbleStyleTarget.user : ChatBubbleStyleTarget.assistant,
  );
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
  bool bare = false,
  ChatBubbleStyleTarget target = ChatBubbleStyleTarget.assistant,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final selection = _chatSurfaceStyleSelection(context, target);
  final style = selection.style;
  final overrides = selection.overrides;
  final resolved = resolveBubbleStyle(cs, theme.brightness, style, overrides);
  Widget content = bare ? child : Padding(padding: padding, child: child);
  if (style != ChatMessageBackgroundStyle.defaultStyle &&
      overrides.hasTextOverride(theme.brightness)) {
    content = DefaultTextStyle.merge(
      style: TextStyle(color: resolved.text),
      child: content,
    );
  }
  if (bare) return content;

  final customBackgroundArgb = theme.brightness == Brightness.dark
      ? overrides.backgroundArgbDark
      : overrides.backgroundArgbLight;
  // A lightly tinted bubble does not provide the .66 veil assumed by the
  // frosted block tokens. A translucent solid bubble needs the same treatment.
  final surfaceKind = resolved.background.a < .66
      ? MarkdownSurfaceKind.tinted
      : style == ChatMessageBackgroundStyle.solid && resolved.background.a == 1
      ? MarkdownSurfaceKind.solid
      : MarkdownSurfaceKind.frosted;
  switch (style) {
    case ChatMessageBackgroundStyle.frosted:
      final radius = BorderRadius.circular(resolved.radius);
      return FrostedSurface(
        style: resolved,
        borderRadius: radius,
        isUser: target == ChatBubbleStyleTarget.user,
        child: MarkdownSurfaceScope(
          kind: surfaceKind,
          backgroundColor: resolved.background,
          hasCustomBackground: customBackgroundArgb != null,
          child: content,
        ),
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
        child: MarkdownSurfaceScope(
          kind: surfaceKind,
          backgroundColor: resolved.background,
          hasCustomBackground: customBackgroundArgb != null,
          child: content,
        ),
      );
    case ChatMessageBackgroundStyle.defaultStyle:
      if (defaultColor == null) {
        return content;
      }
      return DecoratedBox(
        decoration: BoxDecoration(
          color: defaultColor,
          borderRadius: borderRadius,
        ),
        child: MarkdownSurfaceScope(
          kind: MarkdownSurfaceKind.tinted,
          backgroundColor: defaultColor,
          child: content,
        ),
      );
  }
}

/// Quiet fill used by compact cards and chips inside the chat timeline.
Color chatQuietFill(BuildContext context) {
  final theme = Theme.of(context);
  return theme.colorScheme.onSurface.withValues(
    alpha: theme.brightness == Brightness.dark ? 0.06 : 0.04,
  );
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
  return computeChatSurfaceForegroundPalette(
    context,
    target: isUser
        ? ChatBubbleStyleTarget.user
        : ChatBubbleStyleTarget.assistant,
  );
}

ChatSurfaceForegroundPalette computeChatSurfaceForegroundPalette(
  BuildContext context, {
  ChatBubbleStyleTarget target = ChatBubbleStyleTarget.assistant,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final selection = _chatSurfaceStyleSelection(context, target);
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
