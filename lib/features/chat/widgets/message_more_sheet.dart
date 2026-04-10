import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import '../../../icons/lucide_adapter.dart';
import '../../../core/models/chat_message.dart';
// import '../pages/select_copy_page.dart';
import 'select_copy_sheet.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/menu_anchor.dart';
import '../../../desktop/select_copy_dialog.dart';
import '../../../utils/markdown_preview_html.dart';
import '../../../utils/markdown_media_sanitizer.dart';
import '../../../shared/pages/webview_page.dart';
import '../../../desktop/html_preview_dialog.dart';
import 'dart:convert';

enum MessageMoreAction {
  edit,
  fork,
  deleteCurrentVersion,
  deleteAllVersions,
  share,
}

Future<MessageMoreAction?> showMessageMoreSheet(
  BuildContext context,
  ChatMessage message, {
  required bool canDeleteAllVersions,
}) async {
  final isDesktop =
      defaultTargetPlatform == TargetPlatform.macOS ||
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
      builder: (ctx) => _MessageMoreSheet(
        message: message,
        parentContext: context,
        canDeleteAllVersions: canDeleteAllVersions,
      ),
    );
  }

  // Desktop: show anchored glass menu near the clicked button
  final l10n = AppLocalizations.of(context)!;
  MessageMoreAction? selected;
  Future<void> Function()? afterClose;
  await showDesktopContextMenuAt(
    context,
    globalPosition: DesktopMenuAnchor.positionOrCenter(context),
    items: [
      DesktopContextMenuItem(
        icon: Lucide.TextSelect,
        label: l10n.messageMoreSheetSelectCopy,
        onTap: () {
          afterClose = () async {
            if (!context.mounted) return;
            showSelectCopyDesktopDialog(context, message: message);
          };
        },
      ),
      DesktopContextMenuItem(
        icon: Lucide.BookOpenText,
        label: l10n.messageMoreSheetRenderWebView,
        onTap: () {
          afterClose = () async {
            try {
              final raw = message.content.trim();
              if (raw.isEmpty) return;
              final scheme = Theme.of(context).colorScheme;
              final processed =
                  await MarkdownMediaSanitizer.inlineLocalImagesToBase64(raw);
              final html =
                  await MarkdownPreviewHtmlBuilder.buildFromMarkdownWithColorScheme(
                    scheme,
                    processed,
                  );
              if (!context.mounted) return;
              showHtmlPreviewDesktopDialog(context, html: html);
            } catch (e) {
              if (!context.mounted) return;
              showAppSnackBar(
                context,
                message: e.toString(),
                type: NotificationType.error,
              );
            }
          };
        },
      ),
      if (message.role != 'user')
        DesktopContextMenuItem(
          icon: Lucide.Pencil,
          label: l10n.messageMoreSheetEdit,
          onTap: () {
            selected = MessageMoreAction.edit;
          },
        ),
      DesktopContextMenuItem(
        icon: Lucide.Share,
        label: l10n.messageMoreSheetShare,
        onTap: () {
          selected = MessageMoreAction.share;
        },
      ),
      DesktopContextMenuItem(
        icon: Lucide.GitFork,
        label: l10n.messageMoreSheetCreateBranch,
        onTap: () {
          selected = MessageMoreAction.fork;
        },
      ),
      DesktopContextMenuItem(
        icon: Lucide.Trash2,
        label: l10n.messageMoreSheetDelete,
        danger: true,
        onTap: () {
          selected = MessageMoreAction.deleteCurrentVersion;
        },
      ),
      if (canDeleteAllVersions)
        DesktopContextMenuItem(
          icon: Lucide.Trash,
          label: l10n.messageMoreSheetDeleteAllVersions,
          danger: true,
          onTap: () {
            selected = MessageMoreAction.deleteAllVersions;
          },
        ),
    ],
  );
  if (afterClose != null) {
    await afterClose!();
  }
  return selected;
}

class _MessageMoreSheet extends StatefulWidget {
  const _MessageMoreSheet({
    required this.message,
    required this.parentContext,
    required this.canDeleteAllVersions,
  });
  final ChatMessage message;
  final BuildContext parentContext;
  final bool canDeleteAllVersions;

  @override
  State<_MessageMoreSheet> createState() => _MessageMoreSheetState();
}

class _MessageMoreSheetState extends State<_MessageMoreSheet> {
  // Draggable sheet removed; use auto height with max constraint.

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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
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

    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
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
                    color: cs.onSurface.withValues(alpha: 0.2),
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
                      onTap: () {
                        // Close current sheet, then open iOS-style select-copy sheet
                        Navigator.of(context).pop();
                        // Schedule next frame with parent context to avoid stacking sheets
                        final parentCtx = widget.parentContext;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!parentCtx.mounted) return;
                          showSelectCopySheet(
                            parentCtx,
                            message: widget.message,
                          );
                        });
                      },
                    ),
                    _actionItem(
                      icon: Lucide.BookOpenText,
                      label: l10n.messageMoreSheetRenderWebView,
                      onTap: () async {
                        final parentCtx = widget.parentContext;
                        final navigator = Navigator.of(parentCtx);
                        final scheme = Theme.of(parentCtx).colorScheme;
                        Navigator.of(context).pop();
                        try {
                          final raw = widget.message.content.trim();
                          if (raw.isEmpty) return;
                          final processed =
                              await MarkdownMediaSanitizer.inlineLocalImagesToBase64(
                                raw,
                              );
                          final html =
                              await MarkdownPreviewHtmlBuilder.buildFromMarkdownWithColorScheme(
                                scheme,
                                processed,
                              );
                          final b64 = base64Encode(utf8.encode(html));
                          if (!parentCtx.mounted) return;
                          navigator.push(
                            MaterialPageRoute(
                              builder: (_) => WebViewPage(contentBase64: b64),
                            ),
                          );
                        } catch (e) {
                          if (!parentCtx.mounted) return;
                          showAppSnackBar(
                            parentCtx,
                            message: e.toString(),
                            type: NotificationType.error,
                          );
                        }
                      },
                    ),
                    if (widget.message.role != 'user')
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
                        Navigator.of(
                          context,
                        ).pop(MessageMoreAction.deleteCurrentVersion);
                      },
                    ),
                    if (widget.canDeleteAllVersions)
                      _actionItem(
                        icon: Lucide.Trash,
                        label: l10n.messageMoreSheetDeleteAllVersions,
                        danger: true,
                        onTap: () {
                          Navigator.of(
                            context,
                          ).pop(MessageMoreAction.deleteAllVersions);
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
