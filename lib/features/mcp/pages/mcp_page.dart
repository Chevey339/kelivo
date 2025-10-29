import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../theme/design_tokens.dart';
import '../widgets/mcp_server_edit_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../core/services/haptics.dart';

class McpPage extends StatelessWidget {
  const McpPage({super.key, this.embedded = false});

  /// Whether this page is embedded in a desktop settings layout (no Scaffold/AppBar)
  final bool embedded;

  Color _statusColor(BuildContext context, McpStatus s) {
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case McpStatus.connected:
        return Colors.green;
      case McpStatus.connecting:
        return cs.primary;
      case McpStatus.error:
      case McpStatus.idle:
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final mcp = context.watch<McpProvider>();
    final servers = mcp.servers.toList();

    Widget tag(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.green.withOpacity(0.4)),
          ),
          child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
        );

    Future<void> _showErrorDetails(String serverId, String? message, String name) async {
      final cs = Theme.of(context).colorScheme;
      final l10n = AppLocalizations.of(context)!;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.mcpPageErrorDialogTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(name, style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF7F7F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                    ),
                    child: Text(message?.isNotEmpty == true ? message! : l10n.mcpPageErrorNoDetails),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(ctx).maybePop(),
                          icon: Icon(Lucide.X, size: 16, color: cs.primary),
                          label: Text(l10n.mcpPageClose, style: TextStyle(color: cs.primary)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white10
                                : const Color(0xFFF2F3F5),
                            side: BorderSide(color: cs.outlineVariant.withOpacity(0.35)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await ctx.read<McpProvider>().reconnect(serverId);
                            if (context.mounted) Navigator.of(ctx).pop();
                          },
                          icon: const Icon(Lucide.RefreshCw, size: 18),
                          label: Text(l10n.mcpPageReconnect),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    final bodyContent = servers.isEmpty
        ? Center(
            child: Text(
              l10n.mcpPageNoServers,
              style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
            ),
          )
        : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: servers.length,
              itemBuilder: (context, index) {
                final s = servers[index];
                final st = mcp.statusFor(s.id);
                final err = mcp.errorFor(s.id);

                Widget tagStyled(String text, {Color? color}) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (color ?? cs.primary).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: (color ?? cs.primary).withOpacity(0.35)),
                      ),
                      child: Text(text, style: TextStyle(fontSize: 11, color: color ?? cs.primary, fontWeight: FontWeight.w700)),
                    );

                final isDark = Theme.of(context).brightness == Brightness.dark;
                final row = _TactileRow(
                  pressedScale: 1.00,
                  haptics: false,
                  onTap: () async { await showMcpServerEditSheet(context, serverId: s.id); },
                  builder: (pressed) {
                    final base = cs.onSurface.withOpacity(0.9);
                    return _AnimatedPressColor(
                      pressed: pressed,
                      base: base,
                      builder: (c) {
                        final overlay = pressed ? (isDark ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.05)) : Colors.transparent;
                        return Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.white.withOpacity(0.96),
                            // Soften the list card corners a bit
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.1 : 0.08), width: 0.6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(Lucide.Terminal, size: 20, color: cs.primary),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: st == McpStatus.connecting
                                      ? SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                                          ),
                                        )
                                      : Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: s.enabled ? _statusColor(context, st) : cs.outline,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: cs.surface, width: 1.5),
                                          ),
                                        ),
                                ),
                                if (overlay != Colors.transparent)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(color: overlay, borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    style: TextStyle(fontWeight: FontWeight.w700, color: c),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      tagStyled(st == McpStatus.connected
                                          ? l10n.mcpPageStatusConnected
                                          : (st == McpStatus.connecting ? l10n.mcpPageStatusConnecting : l10n.mcpPageStatusDisconnected),
                                          color: st == McpStatus.connected
                                              ? Colors.green
                                              : (st == McpStatus.connecting ? cs.primary : Colors.redAccent)),
                                      tagStyled(s.transport == McpTransportType.sse ? 'SSE' : 'HTTP'),
                                      tagStyled(l10n.mcpPageToolsCount(s.tools.where((t) => t.enabled).length, s.tools.length)),
                                      if (!s.enabled) tagStyled(l10n.mcpPageStatusDisabled, color: cs.onSurface.withOpacity(0.7)),
                                    ],
                                  ),
                                  if (st == McpStatus.error && (err?.isNotEmpty ?? false)) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Lucide.MessageCircleWarning, size: 14, color: Colors.red),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            l10n.mcpPageConnectionFailed,
                                            style: const TextStyle(fontSize: 12, color: Colors.red),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => _showErrorDetails(s.id, err, s.name),
                                          child: Text(l10n.mcpPageDetails),
                                        ),
                          ],
                          ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Lucide.ChevronRight, size: 16, color: c),
                          ],
                          ),
                          ),
                        );
                      },
                    );
                  },
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Slidable(
                    key: ValueKey('mcp-${s.id}'),
                    endActionPane: ActionPane(
                      motion: const StretchMotion(),
                      extentRatio: 0.42,
                      children: [
                        CustomSlidableAction(
                          autoClose: true,
                          backgroundColor: Colors.transparent,
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark ? cs.error.withOpacity(0.22) : cs.error.withOpacity(0.14),
                              // Match list card radius for consistency
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.error.withOpacity(0.35)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Lucide.Trash2, color: cs.error, size: 18),
                                  const SizedBox(width: 6),
                                  Text(l10n.mcpPageDelete, style: TextStyle(color: cs.error, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                          onPressed: (_) async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (dctx) => AlertDialog(
                                backgroundColor: cs.surface,
                                title: Text(l10n.mcpPageConfirmDeleteTitle),
                                content: Text(l10n.mcpPageConfirmDeleteContent),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: Text(l10n.mcpPageCancel)),
                                  TextButton(onPressed: () => Navigator.of(dctx).pop(true), child: Text(l10n.mcpPageDelete)),
                                ],
                              ),
                            );
                            if (ok != true) return;
                            final prov = context.read<McpProvider>();
                            final prev = prov.getById(s.id);
                            await prov.removeServer(s.id);
                            if (!context.mounted) return;
                            showAppSnackBar(
                              context,
                              message: l10n.mcpPageServerDeleted,
                              type: NotificationType.info,
                              actionLabel: l10n.mcpPageUndo,
                              onAction: () {
                                if (prev == null) return;
                                Future(() async {
                                  final newId = await prov.addServer(
                                    enabled: prev.enabled,
                                    name: prev.name,
                                    transport: prev.transport,
                                    url: prev.url,
                                    headers: prev.headers,
                                  );
                                  // Try to refresh tools when back online
                                  try { await prov.refreshTools(newId); } catch (_) {}
                                });
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    child: row,
                  ),
                );
              },
            );

    // If embedded, return body content directly without Scaffold
    if (embedded) {
      return bodyContent;
    }

    // Otherwise, return full page with Scaffold and AppBar
    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.mcpPageBackTooltip,
          child: _TactileIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: const Text('MCP'),
        actions: [
          Tooltip(
            message: l10n.mcpPageAddMcpTooltip,
            child: _TactileIconButton(
              icon: Lucide.Plus,
              color: cs.onSurface,
              size: 22,
              onTap: () async { await showMcpServerEditSheet(context); },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: bodyContent,
    );
  }
}

// --- iOS-style tactile helpers ---

class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({required this.icon, required this.color, required this.onTap, this.onLongPress, this.semanticLabel, this.size = 22, this.haptics = true});
  final IconData icon; final Color color; final VoidCallback onTap; final VoidCallback? onLongPress; final String? semanticLabel; final double size; final bool haptics;
  @override State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color; final pressColor = base.withOpacity(0.7);
    final icon = Icon(widget.icon, size: widget.size, color: _pressed ? pressColor : base, semanticLabel: widget.semanticLabel);
    return Semantics(
      button: true, label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () { if (widget.haptics) Haptics.light(); widget.onTap(); },
        onLongPress: widget.onLongPress == null ? null : () { if (widget.haptics) Haptics.light(); widget.onLongPress!.call(); },
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), child: icon),
      ),
    );
  }
}

class _TactileRow extends StatefulWidget {
  const _TactileRow({required this.builder, this.onTap, this.pressedScale = 1.00, this.haptics = true});
  final Widget Function(bool pressed) builder; final VoidCallback? onTap; final double pressedScale; final bool haptics;
  @override State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false; void _set(bool v){ if(_pressed!=v) setState(()=>_pressed=v);} 
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap==null?null:(_)=>_set(true),
      onTapUp: widget.onTap==null?null:(_)=>_set(false),
      onTapCancel: widget.onTap==null?null:()=>_set(false),
      onTap: widget.onTap==null?null:(){
        if(widget.haptics && context.read<SettingsProvider>().hapticsOnListItemTap) Haptics.soft();
        widget.onTap!.call();
      },
      child: widget.builder(_pressed),
    );
  }
}

class _AnimatedPressColor extends StatelessWidget {
  const _AnimatedPressColor({required this.pressed, required this.base, required this.builder});
  final bool pressed; final Color base; final Widget Function(Color c) builder;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final target = pressed ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base) : base;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target), duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic,
      builder: (context, color, _) => builder(color ?? base),
    );
  }
}
