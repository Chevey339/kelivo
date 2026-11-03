import '../features/chat/widgets/image_context_panel.dart';
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
  ValueChanged<String>? onAttachImage,
  Future<void> Function()? onOperations,
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
  var requestImages = false;
  var requestOperations = false;
  await showDesktopGlassPopover(
    context,
    anchorRect: anchorRect,
    width: (size.width - 16).clamp(260.0, 720.0),
    builder: (ctx, handle) => _ContextUsagePopoverContent(
      conversationId: conversationId,
      onOperations: onOperations == null
          ? null
          : () async {
              requestOperations = true;
              await handle.close();
            },
      onImages: () async {
        requestImages = true;
        await handle.close();
      },
      onRequestSetWindow: () async {
        requestSetWindow = true;
        await handle.close();
      },
    ),
  );
  if (!context.mounted) return;
  if (requestOperations) {
    await onOperations!();
    return;
  }
  if (requestImages) {
    await showImageContextPanel(
      context,
      conversationId,
      onAttach: onAttachImage,
    );
    return;
  }
  if (!requestSetWindow) return;

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
    required this.onImages,
    this.onOperations,
  });

  final String conversationId;
  final Future<void> Function() onImages;
  final Future<void> Function()? onOperations;
  final Future<void> Function() onRequestSetWindow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final usage = context.watch<ContextUsageService>();
    final snapshot = usage.snapshot(conversationId) ?? usage.current;
    final refreshLabel = snapshot?.state == ContextUsageState.failed
        ? l10n.retry
        : l10n.contextUsageRefresh;
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
                tooltip: refreshLabel,
                semanticLabel: refreshLabel,
                icon: Lucide.RefreshCw,
                size: 16,
                onTap: () => usage.refresh(conversationId, force: true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(
                height: 1,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            if (onOperations != null) ...[
              _ActionRow(
                icon: Lucide.History,
                label: l10n.contextOperationsTitle,
                description: l10n.contextOperationsDescription,
                onTap: () => unawaited(onOperations!()),
              ),
              const SizedBox(height: 8),
            ],
            _ActionRow(
              icon: Lucide.Image,
              label: l10n.imageContextTitle,
              description: l10n.imageContextEntryDescription,
              onTap: () => unawaited(onImages()),
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.description,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IosCardPress(
      onTap: onTap,
      focusable: true,
      haptics: false,
      baseColor: cs.onSurface.withValues(alpha: 0.035),
      borderRadius: BorderRadius.circular(10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: description == null ? 22 : 38),
        child: Row(
          children: [
            Icon(icon, size: 17, color: cs.onSurface.withValues(alpha: 0.7)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppFontWeights.medium,
                      color: cs.onSurface,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Lucide.ChevronRight,
              size: 14,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
