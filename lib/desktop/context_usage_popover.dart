import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/home/services/context_usage_service.dart';
import '../icons/lucide_adapter.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/context_usage_details.dart';
import '../shared/widgets/ios_tactile.dart';
import '../theme/app_font_weights.dart';
import 'desktop_glass_popover.dart';
import 'model_spec_edit_dialog.dart';

const Key contextUsagePopoverKey = ValueKey<String>('context-usage-popover');

Future<void> showContextUsagePopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  required String conversationId,
  required String draftText,
}) async {
  final keyContext = anchorKey.currentContext;
  if (keyContext == null) return;

  final box = keyContext.findRenderObject() as RenderBox?;
  if (box == null) return;
  final offset = box.localToGlobal(Offset.zero);
  final size = box.size;
  final anchorRect = Rect.fromLTWH(
    offset.dx,
    offset.dy,
    size.width,
    size.height,
  );

  final usage = context.read<ContextUsageService>();
  unawaited(usage.refresh(conversationId, draftText: draftText));

  var requestSetWindow = false;
  await showDesktopGlassPopover(
    context,
    anchorRect: anchorRect,
    width: (size.width - 16).clamp(260.0, 720.0),
    builder: (ctx, handle) => _ContextUsagePopoverContent(
      conversationId: conversationId,
      onRequestSetWindow: () async {
        requestSetWindow = true;
        await handle.close();
      },
    ),
  );
  if (!context.mounted || !requestSetWindow) return;

  final snap = usage.snapshot(conversationId) ?? usage.current;
  if (snap == null || snap.providerKey.isEmpty || snap.modelId.isEmpty) {
    return;
  }
  final saved = await showDesktopModelSpecEditDialog(
    context,
    providerKey: snap.providerKey,
    modelKey: snap.modelId,
  );
  if (saved == true && context.mounted) {
    await usage.refresh(conversationId, force: true);
  }
}

class _ContextUsagePopoverContent extends StatelessWidget {
  const _ContextUsagePopoverContent({
    required this.conversationId,
    required this.onRequestSetWindow,
  });

  final String conversationId;
  final Future<void> Function() onRequestSetWindow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final usage = context.watch<ContextUsageService>();
    final snapshot = usage.snapshot(conversationId) ?? usage.current;
    final showSetWindow =
        snapshot != null &&
        snapshot.contextWindow == null &&
        snapshot.providerKey.isNotEmpty &&
        snapshot.modelId.isNotEmpty;

    return ConstrainedBox(
      key: contextUsagePopoverKey,
      constraints: const BoxConstraints(maxHeight: 420),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContextUsageBreakdown(
              snapshot: snapshot,
              headerTrailing: IosIconButton(
                tooltip: l10n.contextUsageRefresh,
                semanticLabel: l10n.contextUsageRefresh,
                icon: Lucide.RefreshCw,
                size: 16,
                onTap: () => usage.refresh(conversationId, force: true),
              ),
            ),
            if (showSetWindow) ...[
              const SizedBox(height: 8),
              _ActionRow(
                key: const ValueKey('context-usage-set-window'),
                icon: Lucide.Settings2,
                label: l10n.contextUsageSetWindow,
                onTap: () => unawaited(onRequestSetWindow()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatefulWidget {
  const _ActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? cs.onSurface.withValues(alpha: isDark ? 0.12 : 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: cs.onSurface),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFontWeights.regular,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
