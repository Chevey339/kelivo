import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:intl/intl.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/models/chat_message.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/model_provider.dart';
// import '../pages/select_copy_page.dart';
import 'select_copy_sheet.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/menu_anchor.dart';

enum MessageMoreAction { edit, fork, delete, share }

Future<MessageMoreAction?> showMessageMoreSheet(BuildContext context, ChatMessage message) async {
  final isDesktop = defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
  if (!isDesktop) {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<MessageMoreAction?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MessageMoreSheet(message: message, parentContext: context),
    );
  }

  // Desktop: show anchored glass menu near the clicked button
  final l10n = AppLocalizations.of(context)!;
  MessageMoreAction? selected;
  await showDesktopContextMenuAt(
    context,
    globalPosition: DesktopMenuAnchor.positionOrCenter(context),
    items: [
      DesktopContextMenuItem(
        icon: Lucide.TextSelect,
        label: l10n.messageMoreSheetSelectCopy,
        onTap: () {
          // Open the select-copy sheet after closing menu (keep behavior)
          Future.delayed(const Duration(milliseconds: 40), () {
            showSelectCopySheet(context, message: message);
          });
        },
      ),
      DesktopContextMenuItem(
        icon: Lucide.BookOpenText,
        label: l10n.messageMoreSheetRenderWebView,
        onTap: () {
          showAppSnackBar(
            context,
            message: l10n.messageMoreSheetNotImplemented,
            type: NotificationType.warning,
            duration: const Duration(seconds: 3),
          );
        },
      ),
      DesktopContextMenuItem(
        icon: Lucide.Pencil,
        label: l10n.messageMoreSheetEdit,
        onTap: () { selected = MessageMoreAction.edit; },
      ),
      DesktopContextMenuItem(
        icon: Lucide.Share,
        label: l10n.messageMoreSheetShare,
        onTap: () { selected = MessageMoreAction.share; },
      ),
      DesktopContextMenuItem(
        icon: Lucide.GitFork,
        label: l10n.messageMoreSheetCreateBranch,
        onTap: () { selected = MessageMoreAction.fork; },
      ),
      DesktopContextMenuItem(
        icon: Lucide.Trash2,
        label: l10n.messageMoreSheetDelete,
        danger: true,
        onTap: () { selected = MessageMoreAction.delete; },
      ),
    ],
  );
  return selected;
}

class _MessageMoreSheet extends StatefulWidget {
  const _MessageMoreSheet({required this.message, required this.parentContext});
  final ChatMessage message;
  final BuildContext parentContext;

  @override
  State<_MessageMoreSheet> createState() => _MessageMoreSheetState();
}

class _MessageMoreSheetState extends State<_MessageMoreSheet> {
  // Draggable sheet removed; use auto height with max constraint.

  String _formatTime(BuildContext context, DateTime time) {
    final locale = Localizations.localeOf(context);
    final fmt = locale.languageCode == 'zh' ? DateFormat('yyyy年M月d日 HH:mm:ss') : DateFormat('yyyy-MM-dd HH:mm:ss');
    return fmt.format(time);
  }

  String? _modelDisplayName(BuildContext context) {
    final msg = widget.message;
    if (msg.role != 'assistant') return null;
    if (msg.providerId == null || msg.modelId == null) return null;
    final settings = context.read<SettingsProvider>();
    final modelId = msg.modelId!;
    String? name;
    if (msg.providerId!.isNotEmpty) {
      try {
        final cfg = settings.getProviderConfig(msg.providerId!);
        final ov = cfg.modelOverrides[modelId] as Map?;
        final overrideName = (ov?['name'] as String?)?.trim();
        if (overrideName != null && overrideName.isNotEmpty) {
          name = overrideName;
        }
      } catch (_) {
        // Ignore lookup issues; fall back to inference below.
      }
    }

    final inferred = ModelRegistry.infer(ModelInfo(id: modelId, displayName: modelId));
    final fallback = inferred.displayName.trim();
    return name ?? (fallback.isNotEmpty ? fallback : modelId);
  }

  Widget _actionItem({
    required IconData icon,
    required String label,
    Color? iconColor,
    bool danger = false,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final fg = danger ? Colors.red.shade600 : cs.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: 48,
        child: IosCardPress(
          borderRadius: BorderRadius.circular(14),
          baseColor: cs.surface,
          duration: const Duration(milliseconds: 260),
          onTap: () {
            Haptics.light();
            if (onTap != null) {
              onTap();
            } else {
              Navigator.of(context).maybePop();
            }
          },
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    // Footer metadata (time/model) removed per iOS-style spec

    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              // No title per design; keep content close to handle
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _actionItem(
                      icon: Lucide.TextSelect,
                      label: l10n.messageMoreSheetSelectCopy,
                      onTap: () async {
                        // Close current sheet, then open iOS-style select-copy sheet
                        Navigator.of(context).pop();
                        // Schedule next frame with parent context to avoid stacking sheets
                        Future.delayed(const Duration(milliseconds: 40), () {
                          showSelectCopySheet(widget.parentContext, message: widget.message);
                        });
                      },
                    ),
                    _actionItem(
                      icon: Lucide.BookOpenText,
                      label: l10n.messageMoreSheetRenderWebView,
                      onTap: () {
                        Navigator.of(context).pop();
                        showAppSnackBar(
                          context,
                          message: l10n.messageMoreSheetNotImplemented,
                          type: NotificationType.warning,
                          duration: const Duration(seconds: 3),
                        );
                      },
                    ),
                    _actionItem(
                      icon: Lucide.Pencil,
                      label: l10n.messageMoreSheetEdit,
                      onTap: () {
                        Navigator.of(context).pop(MessageMoreAction.edit);
                      },
                    ),
                    _actionItem(
                      icon: Lucide.Share,
                      label: l10n.messageMoreSheetShare,
                      onTap: () {
                        Navigator.of(context).pop(MessageMoreAction.share);
                      },
                    ),
                    _actionItem(
                      icon: Lucide.GitFork,
                      label: l10n.messageMoreSheetCreateBranch,
                      onTap: () {
                        Navigator.of(context).pop(MessageMoreAction.fork);
                      },
                    ),
                    _actionItem(
                      icon: Lucide.Trash2,
                      label: l10n.messageMoreSheetDelete,
                      danger: true,
                      onTap: () {
                        Navigator.of(context).pop(MessageMoreAction.delete);
                      },
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
