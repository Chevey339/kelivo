import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/mcp_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import 'mcp_server_avatar.dart';
import 'mcp_oauth_progress.dart';

/// Compact presentation shared by the mobile list and desktop settings pane.
/// Selection stays owned by the list; this widget only renders its state.
class McpServerCard extends StatelessWidget {
  const McpServerCard({
    super.key,
    required this.server,
    required this.status,
    required this.onTap,
    this.error,
    this.onDetails,
    this.onAuthorize,
    this.onEnabledChanged,
    this.selectionMode = false,
    this.selected = false,
    this.actions = const [],
    this.onLongPress,
    this.onMore,
  });

  final McpServerConfig server;
  final McpStatus status;
  final VoidCallback onTap;
  final String? error;
  final VoidCallback? onDetails;
  final VoidCallback? onAuthorize;
  final ValueChanged<bool>? onEnabledChanged;
  final bool selectionMode;
  final bool selected;
  final List<Widget> actions;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context)!;
    final statusText = !server.enabled
        ? l10n.mcpPageStatusDisabled
        : switch (status) {
            McpStatus.connected => l10n.mcpPageStatusConnected,
            McpStatus.connecting => l10n.mcpPageStatusConnecting,
            McpStatus.authorizing => l10n.mcpPageStatusAuthorizing,
            McpStatus.needsAuthorization =>
              l10n.mcpPageStatusAuthorizationRequired,
            McpStatus.error => l10n.mcpPageStatusFailed,
            McpStatus.idle => l10n.mcpPageStatusDisconnected,
          };
    final transport = switch (server.transport) {
      McpTransportType.sse => l10n.mcpTransportTagSse,
      McpTransportType.http => l10n.mcpTransportTagHttp,
      McpTransportType.stdio => l10n.mcpTransportTagStdio,
      McpTransportType.inmemory => l10n.mcpTransportTagInmemory,
    };
    final connecting =
        server.enabled &&
        (status == McpStatus.connecting || status == McpStatus.authorizing);
    final tools = l10n.mcpPageCardToolsShort(
      server.tools.where((tool) => tool.enabled).length,
      server.tools.length,
    );
    final background = selected && selectionMode
        ? Color.alphaBlend(
            cs.primary.withValues(alpha: .10),
            colors.surfaceCard,
          )
        : colors.surfaceCard;
    final secondary = server.enabled
        ? mcpReadableColor(
            cs.onSurface.withValues(alpha: .6),
            background,
            cs.onSurface,
          )
        : cs.onSurface.withValues(alpha: .55);
    final stateColor = server.enabled
        ? mcpStatusColor(context, status)
        : secondary;
    final showError =
        server.enabled &&
        (status == McpStatus.error || status == McpStatus.needsAuthorization) &&
        (error?.trim().isNotEmpty ?? false);
    final summary = '$statusText · $transport${connecting ? '' : ' · $tools'}';
    void activate() {
      if (context.read<SettingsProvider?>()?.hapticsOnListItemTap ?? false) {
        Haptics.soft();
      }
      onTap();
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      enabled: true,
      checked: selectionMode ? selected : null,
      label:
          '${selectionMode ? l10n.mcpPageSelectServer(server.name) : server.name}, $summary',
      onTap: activate,
      onLongPress: onLongPress,
      child: _TactileRow(
        onTap: activate,
        onLongPress: onLongPress,
        builder: (pressed, focused) => _AnimatedPressColor(
          pressed: pressed,
          base: cs.onSurface.withValues(alpha: server.enabled ? 1 : .55),
          builder: (foreground) => Container(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selectionMode && selected || focused
                    ? cs.primary.withValues(alpha: .45)
                    : Colors.transparent,
                width: .6,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutCubic,
                      child: selectionMode
                          ? SizedBox(
                              width: 34,
                              height: 44,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selected
                                        ? cs.primary
                                        : Colors.transparent,
                                    border: selected
                                        ? null
                                        : Border.all(
                                            width: 1.6,
                                            color: cs.onSurface.withValues(
                                              alpha: .3,
                                            ),
                                          ),
                                  ),
                                  child: selected
                                      ? Icon(
                                          Lucide.Check,
                                          size: 14,
                                          color: cs.onPrimary,
                                        )
                                      : null,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: McpServerAvatar(
                        server: server,
                        size: 36,
                        radius: 10,
                        status: status,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExcludeSemantics(
                              child: Text(
                                server.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.2,
                                  fontWeight: AppFontWeights.medium,
                                  color: foreground,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            ExcludeSemantics(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: statusText,
                                      style: TextStyle(color: stateColor),
                                    ),
                                    TextSpan(
                                      text:
                                          ' · $transport${connecting ? '' : ' · $tools'}',
                                    ),
                                  ],
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!selectionMode) ...[
                      const SizedBox(width: 8),
                      ...actions,
                      if (onMore != null)
                        IosIconButton(
                          icon: Lucide.Ellipsis,
                          size: 18,
                          minSize: 44,
                          color: secondary,
                          tooltip: l10n.chatMessageWidgetMoreTooltip,
                          onTap: onMore,
                        ),
                      if (onEnabledChanged != null)
                        FocusableActionDetector(
                          mouseCursor: SystemMouseCursors.click,
                          shortcuts: const {
                            SingleActivator(LogicalKeyboardKey.space):
                                ActivateIntent(),
                            SingleActivator(LogicalKeyboardKey.enter):
                                ActivateIntent(),
                          },
                          actions: {
                            ActivateIntent: CallbackAction<ActivateIntent>(
                              onInvoke: (_) {
                                onEnabledChanged!(!server.enabled);
                                return null;
                              },
                            ),
                          },
                          child: IosSwitch(
                            value: server.enabled,
                            onChanged: onEnabledChanged,
                            semanticLabel: server.name,
                            width: 36,
                            height: 22,
                          ),
                        )
                      else if (onMore == null)
                        ExcludeSemantics(
                          child: Icon(
                            Lucide.ChevronRight,
                            size: 16,
                            color: cs.onSurface.withValues(
                              alpha: server.enabled ? .4 : .22,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
                if (showError ||
                    (server.enabled && status == McpStatus.needsAuthorization))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _McpErrorLine(
                      error: showError ? error!.trim().split('\n').first : null,
                      secondary: secondary,
                      warning: status == McpStatus.needsAuthorization,
                      onDetails: onDetails,
                      onAuthorize: status == McpStatus.needsAuthorization
                          ? onAuthorize
                          : null,
                    ),
                  ),
                if (server.enabled) McpOAuthProgress(serverId: server.id),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A flat footer. Only narrow, enlarged-text layouts wrap the actions.
class _McpErrorLine extends StatelessWidget {
  const _McpErrorLine({
    required this.error,
    required this.secondary,
    required this.warning,
    this.onDetails,
    this.onAuthorize,
  });
  final String? error;
  final Color secondary;
  final bool warning;
  final VoidCallback? onDetails;
  final VoidCallback? onAuthorize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final style = DefaultTextStyle.of(
      context,
    ).style.merge(TextStyle(fontSize: 12, fontWeight: AppFontWeights.medium));
    double labelWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final actionWidth =
        (error == null
            ? 0
            : (labelWidth(l10n.mcpPageDetails) + 16).clamp(
                44,
                double.infinity,
              )) +
        (onAuthorize == null
            ? 0
            : (labelWidth(l10n.mcpPageOAuthSignIn) + 31).clamp(
                44,
                double.infinity,
              ));
    final actions = <Widget>[
      if (error != null)
        IosTextButton(
          label: l10n.mcpPageDetails,
          fontSize: 12,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          onPressed: onDetails,
        ),
      if (onAuthorize != null)
        IosTextButton(
          label: l10n.mcpPageOAuthSignIn,
          icon: Lucide.KeyRound,
          fontSize: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          onPressed: onAuthorize,
        ),
    ];
    final summary = <Widget>[
      Icon(
        Lucide.MessageCircleWarning,
        size: 13,
        color: warning ? context.appColors.warning : cs.error,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          error ?? '',
          maxLines: scaler.scale(12) > 12 ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, height: 1.4, color: secondary),
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (actionWidth + (error == null ? 0 : 100) > constraints.maxWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) Row(children: summary),
              Wrap(alignment: WrapAlignment.end, children: actions),
            ],
          );
        }
        return Row(
          children: [
            if (error != null) ...summary else const Spacer(),
            ...actions,
          ],
        );
      },
    );
  }
}

// Preserve the list's press-color feedback, with keyboard activation as well.
class _TactileRow extends StatefulWidget {
  const _TactileRow({
    required this.builder,
    required this.onTap,
    this.onLongPress,
  });
  final Widget Function(bool pressed, bool focused) builder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false;
  bool _focused = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    mouseCursor: SystemMouseCursors.click,
    onShowFocusHighlight: (value) => setState(() => _focused = value),
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    },
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onTap();
          return null;
        },
      ),
    },
    child: GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: widget.builder(_pressed, _focused),
    ),
  );
}

class _AnimatedPressColor extends StatelessWidget {
  const _AnimatedPressColor({
    required this.pressed,
    required this.base,
    required this.builder,
  });
  final bool pressed;
  final Color base;
  final Widget Function(Color color) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Color?>(
    tween: ColorTween(
      end: pressed
          ? Color.lerp(base, Theme.of(context).colorScheme.surface, .55)
          : base,
    ),
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    builder: (context, color, _) => builder(color ?? base),
  );
}
