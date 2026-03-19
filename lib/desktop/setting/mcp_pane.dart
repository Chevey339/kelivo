import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../core/providers/mcp_provider.dart';
import '../../shared/widgets/snackbar.dart';
import 'mcp_edit_dialog.dart' show showDesktopMcpEditDialog;
import 'mcp_json_edit_dialog.dart' show showDesktopMcpJsonEditDialog;
import 'mcp_timeout_dialog.dart' show showDesktopMcpTimeoutDialog;

class DesktopMcpPane extends StatelessWidget {
  const DesktopMcpPane({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final mcp = context.watch<McpProvider>();
    final servers = mcp.servers;

    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.mcpAssistantSheetTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurface.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ),
                      Tooltip(
                        message: l10n.mcpTimeoutSettingsTooltip,
                        child: _SmallIconBtn(
                          icon: lucide.Lucide.Timer,
                          onTap: () async {
                            await showDesktopMcpTimeoutDialog(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      _SmallIconBtn(
                        icon: lucide.Lucide.Edit,
                        onTap: () async {
                          await showDesktopMcpJsonEditDialog(context);
                        },
                      ),
                      const SizedBox(width: 6),
                      _SmallIconBtn(
                        icon: lucide.Lucide.Plus,
                        onTap: () async {
                          await showDesktopMcpEditDialog(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              if (servers.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.mcpPageNoServers,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                )
              else
                SliverReorderableList(
                  itemCount: servers.length,
                  itemBuilder: (context, index) {
                    final s = servers[index];
                    final status = mcp.statusFor(s.id);
                    final error = mcp.errorFor(s.id);
                    return KeyedSubtree(
                      key: ValueKey('desktop-mcp-${s.id}'),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ReorderableDragStartListener(
                          index: index,
                          child: _ServerCard(
                            name: s.name,
                            enabled: s.enabled,
                            transport: s.transport,
                            toolsEnabled: s.tools
                                .where((t) => t.enabled)
                                .length,
                            toolsTotal: s.tools.length,
                            status: status,
                            showError:
                                status == McpStatus.error &&
                                (error?.isNotEmpty ?? false),
                            onTap: () async {
                              await showDesktopMcpEditDialog(
                                context,
                                serverId: s.id,
                              );
                            },
                            onReconnect: () async {
                              await context.read<McpProvider>().reconnect(s.id);
                            },
                            onDelete: () async {
                              final mcpProvider = context.read<McpProvider>();
                              final ok = await _confirmDelete(context);
                              if (ok == true) {
                                await mcpProvider.removeServer(s.id);
                                if (context.mounted) {
                                  showAppSnackBar(
                                    context,
                                    message: l10n.mcpPageServerDeleted,
                                  );
                                }
                              }
                            },
                            onDetails: () async {
                              await _showErrorDetails(
                                context,
                                name: s.name,
                                message: error,
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex -= 1;
                    await context.read<McpProvider>().reorderServers(
                      oldIndex,
                      newIndex,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerCard extends StatefulWidget {
  const _ServerCard({
    required this.name,
    required this.enabled,
    required this.transport,
    required this.toolsEnabled,
    required this.toolsTotal,
    required this.status,
    required this.onTap,
    required this.onReconnect,
    required this.onDelete,
    required this.onDetails,
    required this.showError,
  });
  final String name;
  final bool enabled;
  final McpTransportType transport;
  final int toolsEnabled;
  final int toolsTotal;
  final McpStatus status;
  final VoidCallback onTap;
  final VoidCallback onReconnect;
  final VoidCallback onDelete;
  final VoidCallback onDetails;
  final bool showError;

  @override
  State<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<_ServerCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final baseBg = isDark
        ? Colors.white10
        : Colors.white.withValues(alpha: 0.96);
    final borderColor = _hover
        ? cs.primary.withValues(alpha: isDark ? 0.35 : 0.45)
        : cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.08);

    Color statusColor;
    String statusText;
    switch (widget.status) {
      case McpStatus.connected:
        statusColor = Colors.green;
        statusText = l10n.mcpPageStatusConnected;
        break;
      case McpStatus.connecting:
        statusColor = cs.primary;
        statusText = l10n.mcpPageStatusConnecting;
        break;
      case McpStatus.error:
      case McpStatus.idle:
        statusColor = Colors.redAccent;
        statusText = l10n.mcpPageStatusDisconnected;
        break;
    }

    Widget tag(String text, {Color? color}) {
      final c = color ?? cs.primary;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700),
        ),
      );
    }

    String transportText;
    switch (widget.transport) {
      case McpTransportType.sse:
        transportText = 'SSE';
        break;
      case McpTransportType.http:
        transportText = 'HTTP';
        break;
      case McpTransportType.stdio:
        transportText = AppLocalizations.of(context)!.mcpTransportTagStdio;
        break;
      case McpTransportType.inmemory:
        transportText = AppLocalizations.of(context)!.mcpTransportTagInmemory;
        break;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: baseBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minHeight: 64),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      lucide.Lucide.Terminal,
                      size: 18,
                      color: cs.primary,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: widget.status == McpStatus.connecting
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                cs.primary,
                              ),
                            ),
                          )
                        : Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: widget.enabled ? statusColor : cs.outline,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).scaffoldBackgroundColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        tag(statusText, color: statusColor),
                        tag(transportText),
                        tag(
                          AppLocalizations.of(context)!.mcpPageToolsCount(
                            widget.toolsEnabled,
                            widget.toolsTotal,
                          ),
                        ),
                        if (!widget.enabled)
                          tag(
                            l10n.mcpPageStatusDisabled,
                            color: cs.onSurface.withValues(alpha: 0.7),
                          ),
                      ],
                    ),
                    if (widget.showError) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            lucide.Lucide.MessageCircleWarning,
                            size: 14,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.mcpPageConnectionFailed,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onDetails,
                            style: ButtonStyle(
                              splashFactory: NoSplash.splashFactory,
                              overlayColor: const WidgetStatePropertyAll(
                                Colors.transparent,
                              ),
                            ),
                            child: Text(l10n.mcpPageDetails),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SmallIconBtn(icon: lucide.Lucide.Settings2, onTap: widget.onTap),
              const SizedBox(width: 6),
              _SmallIconBtn(
                icon: lucide.Lucide.RefreshCw,
                onTap: widget.onReconnect,
              ),
              const SizedBox(width: 6),
              _SmallIconBtn(icon: lucide.Lucide.Trash2, onTap: widget.onDelete),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallIconBtn extends StatefulWidget {
  const _SmallIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  State<_SmallIconBtn> createState() => _SmallIconBtnState();
}

class _SmallIconBtnState extends State<_SmallIconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 18, color: cs.onSurface),
        ),
      ),
    );
  }
}

Future<void> _showErrorDetails(
  BuildContext context, {
  required String name,
  String? message,
}) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.mcpPageErrorDialogTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SmallIconBtn(
                      icon: lucide.Lucide.X,
                      onTap: () => Navigator.of(ctx).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white10
                        : const Color(0xFFF7F7F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      (message?.isNotEmpty == true
                          ? message!
                          : l10n.mcpPageErrorNoDetails),
                      style:
                          (Theme.of(ctx).textTheme.bodyMedium ??
                                  const TextStyle())
                              .copyWith(fontSize: 13.0, height: 1.35),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).maybePop(),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(l10n.mcpPageClose),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<bool?> _confirmDelete(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.mcpPageConfirmDeleteTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.mcpPageConfirmDeleteContent,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Builder(
                      builder: (context) {
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        return TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: ButtonStyle(
                            splashFactory: NoSplash.splashFactory,
                            overlayColor: const WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
                            minimumSize: const WidgetStatePropertyAll(
                              Size(88, 36),
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.hovered)) {
                                return isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05);
                              }
                              return Colors.transparent;
                            }),
                          ),
                          child: Text(l10n.mcpPageCancel),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style:
                          FilledButton.styleFrom(
                            backgroundColor: cs.error,
                            foregroundColor: cs.onError,
                          ).copyWith(
                            splashFactory: NoSplash.splashFactory,
                            overlayColor: const WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
                            minimumSize: const WidgetStatePropertyAll(
                              Size(88, 36),
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.hovered)) {
                                return Color.lerp(cs.error, Colors.white, 0.08);
                              }
                              return cs.error;
                            }),
                          ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(l10n.mcpPageDelete),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
