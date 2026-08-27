import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

import '../../../core/models/assistant.dart';
import '../../../core/models/memory_entry.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/memory_provider_v2.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../utils/platform_utils.dart';

final DateFormat memoryEntryDateFormat = DateFormat('yyyy-MM-dd');

String memoryTypeLabel(AppLocalizations l10n, MemoryType type) {
  switch (type) {
    case MemoryType.identity:
      return l10n.memoryEntryTypeIdentity;
    case MemoryType.workflow:
      return l10n.memoryEntryTypeWorkflow;
    case MemoryType.voice:
      return l10n.memoryEntryTypeVoice;
    case MemoryType.instruction:
      return l10n.memoryEntryTypeInstruction;
  }
}

String memorySourceLabel(AppLocalizations l10n, MemorySource source) {
  switch (source) {
    case MemorySource.manual:
      return l10n.memoryEntrySourceManual;
    case MemorySource.tool:
      return l10n.memoryEntrySourceTool;
    case MemorySource.extracted:
      return l10n.memoryEntrySourceExtracted;
    case MemorySource.distilled:
      return l10n.memoryEntrySourceDistilled;
  }
}

Color memoryTypeColor(ColorScheme cs, MemoryType type) {
  switch (type) {
    case MemoryType.identity:
      return cs.primary;
    case MemoryType.workflow:
      return cs.tertiary;
    case MemoryType.voice:
      return cs.secondary;
    case MemoryType.instruction:
      return cs.error;
  }
}

String memoryScopeLabel(
  AppLocalizations l10n,
  MemoryEntry entry, {
  String? assistantName,
  bool useThisAssistant = false,
}) {
  if (entry.scope == MemoryScope.global) {
    return l10n.memoryEntryScopeGlobal;
  }
  if (useThisAssistant || assistantName == null || assistantName.isEmpty) {
    return l10n.memoryEntryScopeAssistant;
  }
  return l10n.memoryEntryScopeAssistantNamed(assistantName);
}

/// Compact info icon: tap or long-press shows [message], matching the
/// legacy-memory toggle on the assistant Memory tab.
class MemoryTipIcon extends StatefulWidget {
  const MemoryTipIcon({super.key, required this.message});

  final String message;

  @override
  State<MemoryTipIcon> createState() => _MemoryTipIconState();
}

class _MemoryTipIconState extends State<MemoryTipIcon> {
  final _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      key: _tooltipKey,
      message: widget.message,
      triggerMode: TooltipTriggerMode.tap,
      waitDuration: const Duration(milliseconds: 250),
      showDuration: const Duration(seconds: 8),
      preferBelow: true,
      constraints: const BoxConstraints(maxWidth: 280),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _tooltipKey.currentState?.ensureTooltipVisible(),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: Icon(
              Lucide.BadgeInfo,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.45),
              semanticLabel: widget.message,
            ),
          ),
        ),
      ),
    );
  }
}

/// Human-readable label for a pipeline / tool outcome code.
///
/// Known codes map to l10n strings. Prefixed codes such as
/// `gate_request_failed:…` match by prefix. Unknown codes are returned as-is.
String memoryOutcomeLabel(AppLocalizations l10n, String code) {
  final key = _memoryOutcomeKey(code);
  return switch (key) {
    'temporary_conversation' => l10n.memoryOutcomeTemporaryConversation,
    'memory_disabled' => l10n.memoryOutcomeMemoryDisabled,
    'auto_organize_off' => l10n.memoryOutcomeAutoOrganizeOff,
    'streaming' => l10n.memoryOutcomeStreaming,
    'below_threshold' => l10n.memoryOutcomeBelowThreshold,
    'empty_window' => l10n.memoryOutcomeEmptyWindow,
    'memory_model_unset' => l10n.memoryOutcomeMemoryModelUnset,
    'memory_model_missing' => l10n.memoryOutcomeMemoryModelMissing,
    'assistant_missing' => l10n.memoryOutcomeAssistantMissing,
    'conversation_missing' => l10n.memoryOutcomeConversationMissing,
    'queue_overflow' => l10n.memoryOutcomeQueueOverflow,
    'gate_request_failed' => l10n.memoryOutcomeGateRequestFailed,
    'gate_parse_failed' => l10n.memoryOutcomeGateParseFailed,
    'extract_request_failed' => l10n.memoryOutcomeExtractRequestFailed,
    'extract_parse_failed' => l10n.memoryOutcomeExtractParseFailed,
    'distill_failed' => l10n.memoryOutcomeDistillFailed,
    'memory_execution_error' => l10n.memoryOutcomeMemoryExecutionError,
    'unsupported_tool' => l10n.memoryOutcomeUnsupportedTool,
    'invalid_memory_type' => l10n.memoryOutcomeInvalidMemoryType,
    'invalid_memory_content' => l10n.memoryOutcomeInvalidMemoryContent,
    'invalid_query' => l10n.memoryOutcomeInvalidQuery,
    'invalid_memory_id' => l10n.memoryOutcomeInvalidMemoryId,
    'memory_not_found' => l10n.memoryOutcomeMemoryNotFound,
    'invalid_profile_fields' => l10n.memoryOutcomeInvalidProfileFields,
    'chat_search_unavailable' => l10n.memoryOutcomeChatSearchUnavailable,
    _ => code,
  };
}

String _memoryOutcomeKey(String code) {
  final colon = code.indexOf(':');
  return colon < 0 ? code : code.substring(0, colon);
}

Future<bool> confirmHardDeleteMemory(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.memoryEntryDeleteConfirmTitle),
      content: Text(l10n.memoryEntryDeleteConfirmContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.homePageCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: Text(l10n.memoryEntryActionDelete),
        ),
      ],
    ),
  );
  return result == true;
}

Future<bool> confirmBatchHardDelete(
  BuildContext context, {
  required int count,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.memoryEntryBatchDeleteConfirmTitle(count)),
      content: Text(l10n.memoryEntryBatchDeleteConfirmContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.homePageCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: Text(l10n.memoryEntryActionDelete),
        ),
      ],
    ),
  );
  return result == true;
}

Future<bool> confirmOrphanCleanup(
  BuildContext context, {
  required int count,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.memoryOrphanConfirmTitle),
      content: Text(l10n.memoryOrphanConfirmContent(count)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.homePageCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: Text(l10n.memoryOrphanCleanupButton),
        ),
      ],
    ),
  );
  return result == true;
}

Future<bool> confirmScopeSwitch(
  BuildContext context, {
  required bool toGlobal,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.memoryEntrySwitchScopeConfirmTitle),
      content: Text(
        toGlobal
            ? l10n.memoryEntrySwitchScopeToGlobal
            : l10n.memoryEntrySwitchScopeToAssistant,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.homePageCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.memoryEntryActionSwitchScope),
        ),
      ],
    ),
  );
  return result == true;
}

/// Soft info banner used for tips / about copy on memory surfaces.
class MemoryInfoBanner extends StatelessWidget {
  const MemoryInfoBanner({
    super.key,
    required this.body,
    this.title,
    this.icon = Lucide.BadgeInfo,
  });

  final String body;
  final String? title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: isDark ? 0.20 : 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.10),
          width: 0.6,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 13,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  body,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.72),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal scroller with edge fades so overflow is discoverable.
class MemoryFadingHorizontalScroll extends StatefulWidget {
  const MemoryFadingHorizontalScroll({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  State<MemoryFadingHorizontalScroll> createState() =>
      _MemoryFadingHorizontalScrollState();
}

class _MemoryFadingHorizontalScrollState
    extends State<MemoryFadingHorizontalScroll> {
  final ScrollController _controller = ScrollController();
  bool _showStartFade = false;
  bool _showEndFade = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncFades);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFades());
  }

  @override
  void dispose() {
    _controller.removeListener(_syncFades);
    _controller.dispose();
    super.dispose();
  }

  void _syncFades() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final overflow = pos.maxScrollExtent > 0.5;
    final showStart = overflow && pos.pixels > 0.5;
    final showEnd = overflow && pos.pixels < pos.maxScrollExtent - 0.5;
    if (showStart == _showStartFade && showEnd == _showEndFade) return;
    setState(() {
      _showStartFade = showStart;
      _showEndFade = showEnd;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _syncFades();
        return false;
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _showStartFade ? Colors.transparent : Colors.white,
                  Colors.white,
                  Colors.white,
                  _showEndFade ? Colors.transparent : Colors.white,
                ],
                stops: const [0.0, 0.1, 0.9, 1.0],
              ).createShader(bounds);
            },
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: widget.padding,
              child: widget.child,
            ),
          ),
          if (_showEndFade)
            PositionedDirectional(
              end: 2,
              child: IgnorePointer(
                child: Icon(
                  Lucide.ChevronRight,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.34),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// iOS-style grouped card used by every memory surface.
class MemorySectionCard extends StatelessWidget {
  const MemorySectionCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SectionCard(padding: padding, children: children);
  }
}

/// Section header above a [MemorySectionCard].
class MemorySectionLabel extends StatelessWidget {
  const MemorySectionLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: AppFontWeights.semibold,
          color: cs.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

/// Tappable "title + subtitle + chevron" row, matching the settings pages.
class MemoryNavRow extends StatelessWidget {
  const MemoryNavRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IosCardPress(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      padding: EdgeInsets.zero,
      baseColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: cs.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Lucide.ChevronRight,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selectable pill used instead of Material's `ChoiceChip`.
class MemorySelectChip extends StatelessWidget {
  const MemorySelectChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.emphasized = false,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool emphasized;
  final IconData? icon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = selected
        ? cs.primary.withValues(alpha: isDark ? 0.22 : 0.12)
        : (emphasized
              ? cs.primary.withValues(alpha: isDark ? 0.16 : 0.10)
              : context.appColors.surfaceFill);
    final borderColor = selected
        ? cs.primary.withValues(alpha: 0.38)
        : (emphasized
              ? cs.primary.withValues(alpha: isDark ? 0.24 : 0.18)
              : cs.outlineVariant.withValues(alpha: isDark ? 0.18 : 0.14));
    final foreground = selected || emphasized
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.8);

    return IosCardPress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      baseColor: background,
      border: Border.all(color: borderColor),
      pressedScale: 0.985,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: AppFontWeights.semibold,
              color: foreground,
              height: 1.0,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 4),
            Icon(trailingIcon, size: 14, color: foreground),
          ],
        ],
      ),
    );
  }
}

/// Rounded search box matching the app's filled-field styling.
class MemorySearchField extends StatelessWidget {
  const MemorySearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Desktop: prefixIcon + symmetric contentPadding (providers search pattern).
    if (PlatformUtils.isDesktopTarget) {
      return ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasText = value.text.isNotEmpty;
          return TextField(
            controller: controller,
            onChanged: onChanged,
            textAlignVertical: TextAlignVertical.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: AppFontWeights.medium,
              color: cs.onSurface.withValues(alpha: 0.92),
            ),
            cursorColor: cs.primary,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontSize: 15,
                fontWeight: AppFontWeights.medium,
                color: cs.onSurface.withValues(alpha: isDark ? 0.42 : 0.46),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              prefixIcon: Icon(
                Lucide.Search,
                size: 18,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              suffixIcon: hasText
                  ? IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged?.call('');
                      },
                      icon: Icon(
                        Lucide.X,
                        size: 16,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                      tooltip: l10n.memoryUiSearchClear,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              filled: true,
              fillColor: context.appColors.surfaceFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          );
        },
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      decoration: BoxDecoration(
        color: context.appColors.surfaceFill,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(
            Lucide.Search,
            size: 18,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: AppFontWeights.medium,
                color: cs.onSurface.withValues(alpha: 0.92),
                height: 1.15,
              ),
              decoration: InputDecoration(
                isDense: true,
                isCollapsed: true,
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFontWeights.medium,
                  color: cs.onSurface.withValues(alpha: isDark ? 0.42 : 0.46),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox(width: 4);
              return IosIconButton(
                icon: Lucide.X,
                size: 16,
                padding: const EdgeInsets.all(4),
                color: cs.onSurface.withValues(alpha: 0.55),
                semanticLabel: l10n.memoryUiSearchClear,
                onTap: () {
                  controller.clear();
                  onChanged?.call('');
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class MemoryPickerOption<T> {
  const MemoryPickerOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;
  final String? subtitle;
}

/// Option picker: centered Dialog on desktop, bottom sheet on mobile.
Future<T?> showMemoryOptionPicker<T>(
  BuildContext context, {
  required String title,
  required List<MemoryPickerOption<T>> options,
  required T selected,
}) {

  Widget optionsCard(BuildContext ctx) {
    final localCs = Theme.of(ctx).colorScheme;
    return MemorySectionCard(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          _MemoryOptionRow<T>(
            label: options[i].label,
            subtitle: options[i].subtitle,
            selected: options[i].value == selected,
            onTap: () => Navigator.of(ctx).pop(options[i].value),
          ),
          if (i != options.length - 1)
            Divider(
              height: 6,
              thickness: 0.6,
              indent: 12,
              endIndent: 12,
              color: localCs.outlineVariant.withValues(alpha: 0.18),
            ),
        ],
      ],
    );
  }

  if (PlatformUtils.isDesktopTarget) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final localCs = Theme.of(ctx).colorScheme;
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.7;
        return Dialog(
          backgroundColor: context.overlaySurface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
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
                        IconButton(
                          tooltip: MaterialLocalizations.of(
                            ctx,
                          ).closeButtonTooltip,
                          icon: const Icon(Lucide.X, size: 18),
                          color: localCs.onSurface,
                          onPressed: () => Navigator.of(ctx).maybePop(),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: localCs.outlineVariant.withValues(alpha: 0.12),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight - 56),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: optionsCard(ctx),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: context.overlaySurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final localCs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: localCs.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: AppFontWeights.emphasis,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(child: SingleChildScrollView(child: optionsCard(ctx))),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _MemoryOptionRow<T> extends StatelessWidget {
  const _MemoryOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    return IosCardPress(
      onTap: onTap,
      baseColor: Colors.transparent,
      borderRadius: BorderRadius.zero,
      pressedBlendStrength: 0.08,
      pressedScale: 1.0,
      haptics: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: hasSubtitle
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: AppFontWeights.semibold,
                            color: cs.onSurface.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: AppFontWeights.semibold,
                        color: cs.onSurface.withValues(alpha: 0.9),
                      ),
                    ),
            ),
            if (selected) Icon(Lucide.Check, size: 18, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

/// Cancel / confirm footer shared by the memory bottom sheets.
class MemorySheetActions extends StatelessWidget {
  const MemorySheetActions({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    required this.confirmLabel,
    this.confirmEnabled = true,
    this.extraAction,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String confirmLabel;
  final bool confirmEnabled;
  final Widget? extraAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (extraAction != null) ...[
          Expanded(child: extraAction!),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: IosTileButton(
            label: l10n.homePageCancel,
            icon: Lucide.X,
            onTap: onCancel,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: IosTileButton(
            label: confirmLabel,
            icon: Lucide.Check,
            enabled: confirmEnabled,
            backgroundColor: cs.primary,
            onTap: onConfirm,
          ),
        ),
      ],
    );
  }
}

/// Opens the add/edit memory editor.
///
/// Desktop: centered [Dialog]. Mobile: modal bottom sheet.
/// The form owns its [TextEditingController] inside a [State], so the
/// controller stays alive for the whole exit transition.
Future<void> showMemoryEntryEditor(
  BuildContext context, {
  MemoryEntry? existing,
  String? defaultAssistantId,
  MemoryScope defaultScope = MemoryScope.global,
  bool allowAssistantPicker = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  final title = existing == null
      ? l10n.memoryEntryCreateTitle
      : l10n.memoryEntryEditTitle;

  MemoryEntryEditForm buildForm({required bool desktop}) => MemoryEntryEditForm(
    title: title,
    existing: existing,
    defaultAssistantId: defaultAssistantId,
    defaultScope: defaultScope,
    allowAssistantPicker: allowAssistantPicker,
    desktop: desktop,
  );

  if (PlatformUtils.isDesktopTarget) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.85;
        return Dialog(
          backgroundColor: context.overlaySurface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
            child: buildForm(desktop: true),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => buildForm(desktop: false),
  );
}

class MemoryEntryEditForm extends StatefulWidget {
  const MemoryEntryEditForm({
    super.key,
    required this.title,
    this.existing,
    this.defaultAssistantId,
    this.defaultScope = MemoryScope.global,
    this.allowAssistantPicker = false,
    this.desktop = false,
  });

  final String title;
  final MemoryEntry? existing;
  final String? defaultAssistantId;
  final MemoryScope defaultScope;
  final bool allowAssistantPicker;

  /// When true, render a compact dialog body (no sheet drag handle / inset).
  final bool desktop;

  @override
  State<MemoryEntryEditForm> createState() => _MemoryEntryEditFormState();
}

class _MemoryEntryEditFormState extends State<MemoryEntryEditForm> {
  late final TextEditingController _content;
  late MemoryType _type;
  late MemoryScope _scope;
  String? _assistantId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _content = TextEditingController(text: existing?.content ?? '');
    _type = existing?.type ?? MemoryType.identity;
    _scope = existing?.scope ?? widget.defaultScope;
    _assistantId = existing?.assistantId ?? widget.defaultAssistantId;
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  String? _resolvedAssistantId(List<Assistant> assistants) {
    if (_scope != MemoryScope.assistant) return null;
    final current = _assistantId;
    if (current != null && current.isNotEmpty) return current;
    if (!widget.allowAssistantPicker) return widget.defaultAssistantId;
    return assistants.isEmpty ? null : assistants.first.id;
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _content.text.trim();
    if (text.isEmpty) return;
    final navigator = Navigator.of(context);
    final mp = context.read<MemoryProviderV2>();
    final assistants = context.read<AssistantProvider>().assistants;
    final assistantId = _resolvedAssistantId(assistants);
    if (_scope == MemoryScope.assistant &&
        (assistantId == null || assistantId.isEmpty)) {
      return;
    }
    setState(() => _saving = true);
    final existing = widget.existing;
    final nextType = _type;
    final nextScope = _scope;
    try {
      if (existing == null) {
        await mp.create(
          scope: nextScope,
          assistantId: assistantId,
          type: nextType,
          content: text,
          source: MemorySource.manual,
        );
      } else {
        final scopeKindChanged = nextScope != existing.scope;
        final assistantRetargeted =
            nextScope == MemoryScope.assistant &&
            existing.assistantId != assistantId;
        final shouldUpdateScope = scopeKindChanged || assistantRetargeted;
        if (scopeKindChanged) {
          if (!context.mounted) return;
          final confirmed = await confirmScopeSwitch(
            context,
            toGlobal: nextScope == MemoryScope.global,
          );
          if (!confirmed) return;
        }
        // Writes are independent of the sheet/dialog staying open.
        if (text != existing.content) {
          await mp.updateContent(existing.id, text);
        }
        if (nextType != existing.type) {
          await mp.updateType(existing.id, nextType);
        }
        if (shouldUpdateScope) {
          await mp.updateScope(
            existing.id,
            scope: nextScope,
            assistantId: assistantId,
          );
        }
      }
      if (mounted) navigator.maybePop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Widget> _formFields(AppLocalizations l10n, List<Assistant> assistants) {
    return [
      MemorySectionCard(
        children: [
          IosFormTextField(
            // Title already names the sheet; omit redundant label.
            label: '',
            controller: _content,
            hintText: l10n.memoryEntryContentHint,
            minLines: 4,
            maxLines: 10,
            inlineLabel: false,
            autofocus: true,
            textAlign: TextAlign.start,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
          ),
        ],
      ),
      const SizedBox(height: 16),
      MemorySectionLabel(text: l10n.memoryEntryTypeLabel),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in MemoryType.values)
            MemorySelectChip(
              label: memoryTypeLabel(l10n, t),
              selected: _type == t,
              onTap: () => setState(() => _type = t),
            ),
        ],
      ),
      const SizedBox(height: 16),
      MemorySectionLabel(text: l10n.memoryEntryScopeLabel),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          MemorySelectChip(
            label: l10n.memoryEntryScopeGlobal,
            selected: _scope == MemoryScope.global,
            onTap: () => setState(() => _scope = MemoryScope.global),
          ),
          MemorySelectChip(
            label: l10n.memoryEntryScopeAssistant,
            selected: _scope == MemoryScope.assistant,
            onTap: () => setState(() => _scope = MemoryScope.assistant),
          ),
        ],
      ),
      if (widget.allowAssistantPicker && _scope == MemoryScope.assistant) ...[
        const SizedBox(height: 16),
        MemorySectionLabel(text: l10n.memoryUiAssistantLabel),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in assistants)
              MemorySelectChip(
                label: a.name,
                selected: _resolvedAssistantId(assistants) == a.id,
                onTap: () => setState(() => _assistantId = a.id),
              ),
          ],
        ),
      ],
    ];
  }

  Widget _actions(AppLocalizations l10n) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _content,
      builder: (context, value, _) => MemorySheetActions(
        confirmLabel: l10n.userProfileSave,
        confirmEnabled: value.text.trim().isNotEmpty && !_saving,
        onCancel: () => Navigator.of(context).maybePop(),
        onConfirm: _save,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final assistants = context.watch<AssistantProvider>().assistants;

    if (widget.desktop) {
      // Compact, height-hugging dialog body — stays visually centered.
      // Cap the scroll area explicitly (avoid Flexible + mainAxisSize.min
      // collapsing to zero height).
      final maxBodyHeight = MediaQuery.sizeOf(context).height * 0.55;
      return Column(
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
            constraints: BoxConstraints(maxHeight: maxBodyHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _formFields(l10n, assistants),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: _actions(l10n),
          ),
        ],
      );
    }

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  children: _formFields(l10n, assistants),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _actions(l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MemoryBadge extends StatelessWidget {
  const MemoryBadge({
    super.key,
    required this.label,
    required this.color,
    this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: AppFontWeights.semibold,
          color: color,
          height: 1.1,
        ),
      ),
    );
    if (onTap == null) return child;
    return IosCardPress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      padding: EdgeInsets.zero,
      baseColor: Colors.transparent,
      child: child,
    );
  }
}

class MemoryEntryCard extends StatelessWidget {
  const MemoryEntryCard({
    super.key,
    required this.entry,
    this.assistantName,
    this.useThisAssistantLabel = false,
    this.selectable = false,
    this.selected = false,
    this.onSelectedChanged,
    this.scopeToggleAssistantId,
    this.onEdit,
  });

  final MemoryEntry entry;
  final String? assistantName;
  final bool useThisAssistantLabel;
  final bool selectable;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;

  /// When non-null, scope badge toggles between global and this assistant.
  final String? scopeToggleAssistantId;
  final VoidCallback? onEdit;

  Future<void> _archive(BuildContext context) async {
    await context.read<MemoryProviderV2>().archive(entry.id);
  }

  Future<void> _restore(BuildContext context) async {
    await context.read<MemoryProviderV2>().restore(entry.id);
  }

  Future<void> _hardDelete(BuildContext context) async {
    if (!await confirmHardDeleteMemory(context)) return;
    if (!context.mounted) return;
    await context.read<MemoryProviderV2>().hardDelete(entry.id);
  }

  Future<void> _toggleScope(BuildContext context) async {
    final assistantId = scopeToggleAssistantId;
    if (assistantId == null) return;
    final toGlobal = entry.scope == MemoryScope.assistant;
    if (!await confirmScopeSwitch(context, toGlobal: toGlobal)) return;
    if (!context.mounted) return;
    final mp = context.read<MemoryProviderV2>();
    if (toGlobal) {
      await mp.updateScope(entry.id, scope: MemoryScope.global);
    } else {
      await mp.updateScope(
        entry.id,
        scope: MemoryScope.assistant,
        assistantId: assistantId,
      );
    }
  }

  Future<void> _showContextMenu(BuildContext context, Offset global) async {
    final l10n = AppLocalizations.of(context)!;
    final items = <DesktopContextMenuItem>[
      if (entry.status == MemoryStatus.active)
        DesktopContextMenuItem(
          icon: Lucide.Bookmark,
          label: l10n.memoryEntryActionArchive,
          onTap: () => _archive(context),
        )
      else
        DesktopContextMenuItem(
          icon: Lucide.RotateCcw,
          label: l10n.memoryEntryActionRestore,
          onTap: () => _restore(context),
        ),
      DesktopContextMenuItem(
        icon: Lucide.Trash2,
        label: l10n.memoryEntryActionDelete,
        danger: true,
        onTap: () => _hardDelete(context),
      ),
    ];
    await showDesktopContextMenuAt(
      context,
      globalPosition: global,
      items: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final typeColor = memoryTypeColor(cs, entry.type);
    final scopeColor = entry.scope == MemoryScope.global
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.65);
    final date = memoryEntryDateFormat.format(entry.updatedAt.toLocal());
    final meta =
        '${l10n.memoryEntryUpdatedAt(date)} · ${memorySourceLabel(l10n, entry.source)}';

    final card = Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: context.appColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.45)
                : context.appColors.hairline,
            width: 0.6,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selectable) ...[
                    IosCheckbox(
                      value: selected,
                      size: 20,
                      hitTestSize: 24,
                      borderWidth: 1.6,
                      activeColor: cs.primary,
                      borderColor: cs.primary.withValues(alpha: 0.55),
                      semanticLabel: l10n.memoryEntryActionBatchDelete,
                      onChanged: (v) => onSelectedChanged?.call(v),
                    ),
                    const SizedBox(width: 6),
                  ],
                  MemoryBadge(
                    label: memoryTypeLabel(l10n, entry.type),
                    color: typeColor,
                  ),
                  const SizedBox(width: 6),
                  MemoryBadge(
                    label: memoryScopeLabel(
                      l10n,
                      entry,
                      assistantName: assistantName,
                      useThisAssistant: useThisAssistantLabel,
                    ),
                    color: scopeColor,
                    onTap: scopeToggleAssistantId == null
                        ? null
                        : () => _toggleScope(context),
                  ),
                  const Spacer(),
                  if (onEdit != null)
                    _IconAction(
                      icon: Lucide.Pencil,
                      color: cs.primary,
                      tooltip: l10n.memoryEntryActionEdit,
                      onTap: onEdit!,
                    ),
                  const SizedBox(width: 4),
                  _IconAction(
                    icon: Lucide.Trash2,
                    color: cs.error,
                    tooltip: l10n.memoryEntryActionDelete,
                    onTap: () => _hardDelete(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                entry.content,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
              const SizedBox(height: 6),
              Text(
                meta,
                style: TextStyle(
                  fontSize: 11.5,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return GestureDetector(
      onLongPressStart: (details) {
        HapticFeedback.mediumImpact();
        unawaited(_showContextMenu(context, details.globalPosition));
      },
      onSecondaryTapDown: (details) {
        unawaited(_showContextMenu(context, details.globalPosition));
      },
      child: card,
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IosIconButton(
        icon: icon,
        color: color,
        size: 18,
        minSize: 32,
        onTap: onTap,
      ),
    );
  }
}

class MemoryModelMissingNotice extends StatelessWidget {
  const MemoryModelMissingNotice({super.key, required this.onGoSelect});

  final VoidCallback onGoSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Lucide.MessageCircleWarning, size: 18, color: cs.error),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.memoryModelMissingNotice,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: cs.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IosTileButton(
                      label: l10n.memoryModelMissingGoSelect,
                      icon: Lucide.Settings2,
                      fontSize: 12.5,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      backgroundColor: cs.primary,
                      onTap: onGoSelect,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MemoryOrphanBanner extends StatelessWidget {
  const MemoryOrphanBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final count = context.watch<MemoryProviderV2>().orphanCount;
    if (count <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Icon(Lucide.TriangleAlert, size: 18, color: cs.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.memoryOrphanBanner(count),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  color: cs.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IosTileButton(
              label: l10n.memoryOrphanCleanupButton,
              icon: Lucide.Trash2,
              fontSize: 12.5,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              backgroundColor: cs.error,
              onTap: () async {
                if (!await confirmOrphanCleanup(context, count: count)) {
                  return;
                }
                if (!context.mounted) return;
                await context
                    .read<MemoryProviderV2>()
                    .deleteOrphanAssistantMemories();
              },
            ),
          ],
        ),
      ),
    );
  }
}

String? resolveAssistantName(BuildContext context, String? assistantId) {
  if (assistantId == null) return null;
  return context.read<AssistantProvider>().getById(assistantId)?.name;
}
