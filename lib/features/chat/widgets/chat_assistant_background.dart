import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../utils/sandbox_path_resolver.dart';

/// Shared assistant wallpaper + surface-mask gradient for chat surfaces.
///
/// Mobile uses a 0.20→0.50 mask multiplied by
/// [SettingsProvider.chatBackgroundMaskStrength]. Desktop keeps a fixed
/// 0.08→0.36 mask (`applyMaskStrength: false`) so the look stays byte-identical.
class ChatAssistantBackground extends StatelessWidget {
  const ChatAssistantBackground({
    super.key,
    this.desktop = false,
    this.includeSurfaceFill = false,
    this.expand = true,
    this.applyMaskStrength = true,
  });

  /// Desktop chat uses a lighter mask so the wallpaper stays more visible.
  final bool desktop;

  /// Desktop layout paints [ColorScheme.surface] under the wallpaper.
  final bool includeSurfaceFill;

  /// When false, an empty background is [SizedBox.shrink] (home mobile body).
  final bool expand;

  /// When false, ignore [SettingsProvider.chatBackgroundMaskStrength].
  final bool applyMaskStrength;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = context.watch<AssistantProvider>().currentAssistant?.background;
    final maskStrength = applyMaskStrength
        ? context.watch<SettingsProvider>().chatBackgroundMaskStrength
        : 1.0;
    final empty = expand ? const SizedBox.expand() : const SizedBox.shrink();

    if (bg == null || bg.trim().isEmpty) {
      return includeSurfaceFill ? ColoredBox(color: cs.surface) : empty;
    }

    ImageProvider? provider;
    Widget? imageWidget;
    if (bg.startsWith('http')) {
      if (includeSurfaceFill) {
        imageWidget = Image.network(
          bg,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } else {
        provider = NetworkImage(bg);
      }
    } else {
      try {
        final localPath = SandboxPathResolver.fix(bg);
        final file = File(localPath);
        if (!file.existsSync()) {
          return includeSurfaceFill ? ColoredBox(color: cs.surface) : empty;
        }
        if (includeSurfaceFill) {
          imageWidget = Image(image: FileImage(file), fit: BoxFit.cover);
        } else {
          provider = FileImage(file);
        }
      } catch (_) {
        return includeSurfaceFill ? ColoredBox(color: cs.surface) : empty;
      }
    }

    final topAlpha = ((desktop ? 0.08 : 0.20) * maskStrength).clamp(0.0, 1.0);
    final bottomAlpha = ((desktop ? 0.36 : 0.50) * maskStrength).clamp(
      0.0,
      1.0,
    );
    final mask = IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.surface.withValues(alpha: topAlpha),
              cs.surface.withValues(alpha: bottomAlpha),
            ],
          ),
        ),
      ),
    );

    if (includeSurfaceFill) {
      return IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: cs.surface),
            if (imageWidget != null) Opacity(opacity: 0.9, child: imageWidget),
            mask,
          ],
        ),
      );
    }

    final wallpaper = DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: provider!,
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            cs.shadow.withValues(alpha: 0.04),
            BlendMode.srcATop,
          ),
        ),
      ),
    );

    if (expand) {
      return Stack(fit: StackFit.expand, children: [wallpaper, mask]);
    }

    return Stack(
      children: [
        Positioned.fill(child: wallpaper),
        Positioned.fill(child: mask),
      ],
    );
  }
}
