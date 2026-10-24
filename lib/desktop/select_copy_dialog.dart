import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import '../features/intelligent_ui/widgets/genui_clipboard.dart';
import '../shared/widgets/ios_tactile.dart';
import '../features/intelligent_ui/host/ui_copy_actions.dart';
import 'package:flutter/material.dart';
import '../core/models/chat_message.dart';
import '../l10n/app_localizations.dart';
import '../icons/lucide_adapter.dart';

import '../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

Future<void> showSelectCopyDesktopDialog(
  BuildContext context, {
  required ChatMessage message,
}) async {
  final projection = await readUiMessageText(context, message);
  if (projection == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _SelectCopyDesktopDialog(
      message: message,
      content: projection.copyText,
    ),
  );
}

class _SelectCopyDesktopDialog extends StatelessWidget {
  const _SelectCopyDesktopDialog({
    required this.message,
    required this.content,
  });
  final String content;
  final ChatMessage message;

  Future<void> _copyAll(BuildContext context) => copyGenUiText(
    context,
    content,
    successMessage: AppLocalizations.of(context)!.selectCopyPageCopiedAll,
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 420,
          maxWidth: 720,
          maxHeight: 640,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: context.overlaySurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Text(
                        l10n.selectCopyPageTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: AppFontWeights.emphasis,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _copyAll(context),
                        icon: Icon(Lucide.Copy, size: 18, color: cs.primary),
                        label: Text(
                          l10n.selectCopyPageCopyAll,
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: AppFontWeights.semibold,
                          ),
                        ),
                      ),
                      IosIconButton(
                        icon: Lucide.Code,
                        tooltip: l10n.genuiCopySourceMarkdown,
                        minSize: 44,
                        onTap: () => copyUiMessageSource(context, message),
                      ),
                      IconButton(
                        tooltip: l10n.mcpPageClose,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          Lucide.X,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.18),
                          width: 0.6,
                        ),
                      ),
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: AppSelectionArea(
                            copyByteLimit: UiBudgets.copyBytes,
                            child: Text(
                              content,
                              style: TextStyle(fontSize: 15, height: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
