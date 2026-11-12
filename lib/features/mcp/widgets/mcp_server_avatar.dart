import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/mcp_provider.dart';
import '../../../core/models/mcp_presentation.dart';
import '../../../core/services/mcp/mcp_icon_cache.dart';
import '../../../theme/app_semantic_colors.dart';
import 'mcp_resolved_icon.dart';

/// Optional app-level icon override. Returning null uses the normal custom,
/// server-declared, favicon, and bundled-mark resolution chain.
typedef McpIconResolver =
    Widget? Function(
      BuildContext context,
      McpServerConfig server,
      double size,
      Color foreground,
    );

/// Keeps semantic colors readable on the actual card, including custom palettes.
/// The adjustment is local to MCP presentation; global theme tokens stay intact.
Color mcpReadableColor(
  Color foreground,
  Color background,
  Color onSurface, {
  double minimum = 4.5,
}) {
  final backgroundLuminance = background.computeLuminance();
  double contrast(Color color) {
    final a = Color.alphaBlend(color, background).computeLuminance();
    final b = backgroundLuminance;
    return (math.max(a, b) + .05) / (math.min(a, b) + .05);
  }

  if (contrast(foreground) >= minimum) return foreground;
  for (var step = 1; step <= 20; step++) {
    final color = Color.lerp(foreground, onSurface, step / 20)!;
    if (contrast(color) >= minimum) return color;
  }
  return onSurface;
}

Color mcpStatusColor(BuildContext context, McpStatus status) {
  final cs = Theme.of(context).colorScheme;
  final colors = context.appColors;
  final color = switch (status) {
    McpStatus.connected => colors.success,
    McpStatus.connecting || McpStatus.authorizing => cs.primary,
    McpStatus.needsAuthorization => colors.warning,
    McpStatus.error => cs.error,
    McpStatus.idle => cs.onSurface.withValues(alpha: .6),
  };
  return mcpReadableColor(color, colors.surfaceCard, cs.onSurface, minimum: 3);
}

class McpServerAvatar extends StatelessWidget {
  const McpServerAvatar({
    super.key,
    required this.server,
    required this.size,
    required this.radius,
    this.status,
    this.resolver,
    this.customIcon,
    this.useCustomIcon = false,
    this.showBackground = true,
  });

  final McpServerConfig server;
  final double size;
  final double radius;
  final McpStatus? status;
  final McpIconResolver? resolver;
  final McpServerIcon? customIcon;
  final bool useCustomIcon;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final foreground = cs.primary.withValues(alpha: server.enabled ? 1 : .55);
    final resolve = resolver ?? context.watch<McpIconResolver?>();
    final icon = resolve?.call(context, server, size, foreground);
    final mcp = context.watch<McpProvider?>();
    final themeName = Theme.of(context).brightness.name;
    final declarations = mcp?.declaredIconsFor(server.id) ?? const [];
    final sources = <String>[
      for (final declaration in declarations)
        if ((declaration['theme'] == null ||
                declaration['theme'] == themeName) &&
            McpIconCache.acceptsDeclaredSource(
              declaration['src'] as String,
              server.url,
            ))
          declaration['src'] as String,
      if (McpIconCache.faviconFor(server.url) case final favicon?)
        favicon.toString(),
    ];
    final fallback = SvgPicture.asset(
      'assets/icons/mcp.svg',
      width: size * (showBackground ? .55 : 1),
      height: size * (showBackground ? .55 : 1),
      // Bake the color into the cached picture, avoiding one filter per row.
      theme: SvgTheme(currentColor: foreground),
      clipBehavior: Clip.none,
    );
    final resolvedCustomIcon = useCustomIcon
        ? customIcon
        : mcp?.presentationFor(server.id).icon;
    final connecting =
        server.enabled &&
        (status == McpStatus.connecting || status == McpStatus.authorizing);
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: showBackground
                ? BoxDecoration(
                    color: colors.surfaceFill,
                    borderRadius: BorderRadius.circular(radius),
                  )
                : null,
            child:
                icon ??
                (resolvedCustomIcon == null && sources.isEmpty
                    ? fallback
                    : McpResolvedIcon(
                        icon: resolvedCustomIcon,
                        sources: sources,
                        size: size,
                        inset: showBackground,
                        color: foreground,
                        fallback: fallback,
                      )),
          ),
          if (status != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: connecting ? 14 : 11,
                height: connecting ? 14 : 11,
                decoration: BoxDecoration(
                  color: connecting
                      ? colors.surfaceCard
                      : server.enabled
                      ? mcpStatusColor(context, status!)
                      : cs.outline,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surfaceCard, width: 2),
                ),
                child: connecting
                    ? CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
