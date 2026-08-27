import 'package:flutter/material.dart';

import '../../core/models/memory_entry.dart';
import '../../core/services/memory/memory_trace.dart';
import '../../features/settings/pages/legacy_memory_page.dart';
import '../../features/settings/pages/memory_about_page.dart';
import '../../features/settings/pages/memory_entries_page.dart';
import '../../features/settings/pages/memory_settings_page.dart';
import '../../features/settings/pages/memory_trace_page.dart';
import '../../features/settings/pages/user_profile_page.dart';
import '../../features/settings/widgets/memory_ui.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/ios_form_text_field.dart';
import '../../shared/widgets/ios_tactile.dart';
import '../../shared/widgets/ios_tile_button.dart';
import '../../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

/// Shared chrome for memory-related desktop dialogs (matches MCP / assistant
/// dialog shells: surface Dialog + title row + close).
///
/// Uses a fixed-height pane shell (`Expanded` body) — good for list / settings
/// pages. For compact input forms prefer [showDesktopMemoryFormDialog].
Future<T?> showDesktopMemoryDialog<T>(
  BuildContext context, {
  required String title,
  required Widget body,
  List<Widget> Function(BuildContext dialogContext)? headerActionsBuilder,
  double maxWidth = 860,
  double maxHeight = 640,
}) {
  final cs = Theme.of(context).colorScheme;
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final actions = headerActionsBuilder?.call(ctx) ?? const <Widget>[];
      return Dialog(
        backgroundColor: context.overlaySurface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: AppFontWeights.emphasis,
                          ),
                        ),
                      ),
                      ...actions,
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          ctx,
                        ).closeButtonTooltip,
                        icon: const Icon(Lucide.X, size: 18),
                        color: cs.onSurface,
                        onPressed: () => Navigator.of(ctx).maybePop(),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: cs.outlineVariant.withValues(alpha: 0.12),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    },
  );
}

/// Compact, screen-centered form dialog.
///
/// Shrinks to content height (up to [maxHeight]) so short editors stay visually
/// centered — unlike bottom sheets or fixed-height pane shells that pin content
/// toward the bottom of the window.
Future<T?> showDesktopMemoryFormDialog<T>(
  BuildContext context, {
  required String title,
  required Widget body,
  List<Widget> Function(BuildContext dialogContext)? headerActionsBuilder,
  Widget? footer,
  double maxWidth = 520,
  double maxHeightFactor = 0.85,
}) {
  final cs = Theme.of(context).colorScheme;
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final actions = headerActionsBuilder?.call(ctx) ?? const <Widget>[];
      final maxHeight = MediaQuery.sizeOf(ctx).height * maxHeightFactor;
      final maxBodyHeight = maxHeight - 44 - 1 - (footer != null ? 72 : 16);
      return Dialog(
        backgroundColor: context.overlaySurface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: AppFontWeights.emphasis,
                          ),
                        ),
                      ),
                      ...actions,
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          ctx,
                        ).closeButtonTooltip,
                        icon: const Icon(Lucide.X, size: 18),
                        color: cs.onSurface,
                        onPressed: () => Navigator.of(ctx).maybePop(),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: cs.outlineVariant.withValues(alpha: 0.12),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxBodyHeight.clamp(120.0, maxHeight),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: body,
                ),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: footer,
                )
              else
                const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showDesktopMemorySettingsDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDesktopMemoryDialog<void>(
    context,
    title: l10n.memorySettingsPageTitle,
    body: const MemorySettingsContent(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
    ),
  );
}

Future<void> showDesktopMemoryEntriesDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDesktopMemoryDialog<void>(
    context,
    title: l10n.memoryEntriesPageTitle,
    body: const MemoryEntriesContent(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
    ),
  );
}

Future<void> showDesktopUserProfileMemoryDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDesktopMemoryDialog<void>(
    context,
    title: l10n.userProfilePageTitle,
    body: const UserProfileContent(padding: EdgeInsets.fromLTRB(20, 8, 20, 24)),
  );
}

Future<void> showDesktopLegacyMemoryDialog(
  BuildContext context, {
  String? assistantId,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showDesktopMemoryDialog<void>(
    context,
    title: l10n.legacyMemoryPageTitle,
    headerActionsBuilder: (dialogContext) {
      final cs = Theme.of(dialogContext).colorScheme;
      return [
        Tooltip(
          message: l10n.legacyMemoryExport,
          child: IosIconButton(
            icon: Lucide.Share2,
            color: cs.onSurface,
            size: 18,
            minSize: 36,
            onTap: () => LegacyMemoryContent.exportAll(
              dialogContext,
              assistantId: assistantId,
            ),
          ),
        ),
        Tooltip(
          message: l10n.legacyMemoryMigrate,
          child: IosIconButton(
            icon: Lucide.Import,
            color: cs.primary,
            size: 18,
            minSize: 36,
            semanticLabel: l10n.legacyMemoryMigrate,
            onTap: () => LegacyMemoryContent.showMigration(
              dialogContext,
              assistantId: assistantId,
            ),
          ),
        ),
      ];
    },
    body: LegacyMemoryContent(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      assistantId: assistantId,
    ),
  );
}

Future<void> showDesktopMemoryTraceDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDesktopMemoryDialog<void>(
    context,
    title: l10n.memoryTracePageTitle,
    body: const MemoryTraceContent(padding: EdgeInsets.fromLTRB(20, 8, 20, 24)),
  );
}

Future<void> showDesktopMemoryAboutDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDesktopMemoryDialog<void>(
    context,
    title: l10n.memorySettingsAboutTitle,
    maxWidth: 560,
    maxHeight: 520,
    body: const MemoryAboutContent(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
    ),
  );
}

Future<void> showDesktopMemoryTraceDetailDialog(
  BuildContext context, {
  required MemoryTrace trace,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showDesktopMemoryDialog<void>(
    context,
    title: l10n.memoryTraceDetailTitle,
    body: MemoryTraceDetailContent(
      trace: trace,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    ),
  );
}

/// Desktop add/edit memory entry — delegates to [showMemoryEntryEditor], which
/// already presents a centered Dialog on desktop targets.
Future<void> showDesktopMemoryEntryEditor(
  BuildContext context, {
  MemoryEntry? existing,
  String? defaultAssistantId,
  bool allowAssistantPicker = false,
}) {
  return showMemoryEntryEditor(
    context,
    existing: existing,
    defaultAssistantId: defaultAssistantId,
    allowAssistantPicker: allowAssistantPicker,
  );
}

/// Desktop option picker — delegates to [showMemoryOptionPicker].
Future<T?> showDesktopMemoryOptionPicker<T>(
  BuildContext context, {
  required String title,
  required List<MemoryPickerOption<T>> options,
  required T selected,
}) {
  return showMemoryOptionPicker<T>(
    context,
    title: title,
    options: options,
    selected: selected,
  );
}

/// Desktop text / number input — centered form dialog (not a bottom sheet).
Future<String?> showDesktopMemoryTextInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String initialValue,
  String? hintText,
  String? description,
  int minLines = 3,
  int maxLines = 10,
  TextInputType? keyboardType,
  bool allowEmpty = false,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _DesktopMemoryTextInputDialog(
      title: title,
      label: label,
      initialValue: initialValue,
      hintText: hintText,
      description: description,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      allowEmpty: allowEmpty,
    ),
  );
}

class _DesktopMemoryTextInputDialog extends StatefulWidget {
  const _DesktopMemoryTextInputDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.minLines,
    required this.maxLines,
    required this.allowEmpty,
    this.hintText,
    this.description,
    this.keyboardType,
  });

  final String title;
  final String label;
  final String initialValue;
  final String? hintText;
  final String? description;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool allowEmpty;

  @override
  State<_DesktopMemoryTextInputDialog> createState() =>
      _DesktopMemoryTextInputDialogState();
}

class _DesktopMemoryTextInputDialogState
    extends State<_DesktopMemoryTextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    final maxBodyHeight = maxHeight - 44 - 1 - 72;
    return Dialog(
      backgroundColor: context.overlaySurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: AppFontWeights.emphasis,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      icon: const Icon(Lucide.X, size: 18),
                      color: cs.onSurface,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: 0.12),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxBodyHeight.clamp(120.0, maxHeight),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MemorySectionCard(
                      children: [
                        IosFormTextField(
                          label: widget.label,
                          controller: _controller,
                          hintText: widget.hintText,
                          minLines: widget.minLines,
                          maxLines: widget.maxLines,
                          inlineLabel: false,
                          autofocus: true,
                          textAlign: TextAlign.start,
                          keyboardType: widget.keyboardType,
                        ),
                      ],
                    ),
                    if (widget.description != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          widget.description!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: cs.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  final enabled =
                      widget.allowEmpty || value.text.trim().isNotEmpty;
                  return Row(
                    children: [
                      Expanded(
                        child: IosTileButton(
                          label: l10n.homePageCancel,
                          icon: Lucide.X,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: IosTileButton(
                          label: l10n.userProfileSave,
                          icon: Lucide.Check,
                          enabled: enabled,
                          backgroundColor: cs.primary,
                          onTap: enabled
                              ? () => Navigator.of(
                                  context,
                                ).pop(_controller.text.trim())
                              : () {},
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Desktop confirm dialog (replaces mobile custom bottom sheets).
Future<bool> showDesktopMemoryConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  Color? confirmColor,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final localCs = Theme.of(ctx).colorScheme;
      return Dialog(
        backgroundColor: localCs.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: AppFontWeights.emphasis,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          ctx,
                        ).closeButtonTooltip,
                        icon: const Icon(Lucide.X, size: 18),
                        color: localCs.onSurface,
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: localCs.onSurface.withValues(alpha: 0.66),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: IosTileButton(
                        label: l10n.memoryTraceCancel,
                        icon: Lucide.X,
                        onTap: () => Navigator.of(ctx).pop(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: IosTileButton(
                        label: confirmLabel,
                        icon: Lucide.Trash2,
                        backgroundColor: confirmColor ?? cs.error,
                        onTap: () => Navigator.of(ctx).pop(true),
                      ),
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
  return result == true;
}
