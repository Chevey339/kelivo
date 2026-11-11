import 'compression_controls.dart';
import 'context_dialog.dart';
import 'context_message_count.dart';
import 'package:flutter/material.dart';

import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'context_usage_header.dart';

/// Bottom sheet for mobile: compress context or clear context.
class ContextManagementSheet extends StatelessWidget {
  const ContextManagementSheet({
    super.key,
    this.onCompress,
    this.onClear,
    this.conversationId,
    this.draftText = '',
    this.onImages,
    this.onOperations,
  });

  final VoidCallback? onCompress;
  final VoidCallback? onClear;

  final String? conversationId;
  final String draftText;
  final VoidCallback? onImages;
  final VoidCallback? onOperations;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bg = context.overlaySurface;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ContextUsageHeader(
                    conversationId: conversationId,
                    draftText: draftText,
                  ),
                  const SizedBox(height: 6),
                  if (conversationId != null)
                    AutoCompressionControl(conversationId: conversationId!),
                  ContextActionRow(
                    icon: Lucide.package2,
                    label: l10n.compressContext,
                    onTap: () {
                      Haptics.light();
                      onCompress?.call();
                    },
                  ),
                  if (onOperations != null)
                    ContextActionRow(
                      icon: Lucide.History,
                      label: l10n.contextOperationsTitle,
                      onTap: onOperations,
                      showChevron: true,
                    ),
                  if (onImages != null)
                    ContextActionRow(
                      icon: Lucide.Image,
                      label: l10n.imageContextTitle,
                      onTap: onImages,
                      showChevron: true,
                    ),
                  ContextActionRow(
                    icon: Lucide.Eraser,
                    label: l10n.bottomToolsSheetClearContext,
                    trailing: ContextMessageCount(
                      conversationId: conversationId,
                    ),
                    onTap: () {
                      Haptics.light();
                      onClear?.call();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
