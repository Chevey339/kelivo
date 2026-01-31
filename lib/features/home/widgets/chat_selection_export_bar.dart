import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/design_tokens.dart';

class ChatSelectionExportBar extends StatelessWidget {
  const ChatSelectionExportBar({
    super.key,
    required this.onExportMarkdown,
    required this.onExportTxt,
    required this.onExportImage,
    required this.showThinkingTools,
    required this.showThinkingContent,
    required this.onToggleThinkingTools,
    required this.onToggleThinkingContent,
  });

  final VoidCallback onExportMarkdown;
  final VoidCallback onExportTxt;
  final VoidCallback onExportImage;

  final bool showThinkingTools;
  final bool showThinkingContent;
  final VoidCallback onToggleThinkingTools;
  final VoidCallback onToggleThinkingContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final bg = isDark ? Colors.black.withOpacity(0.35) : cs.surface.withOpacity(0.78);
    final shadowColor = isDark ? Colors.black.withOpacity(0.40) : Colors.black.withOpacity(0.10);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 22,
            spreadRadius: 0,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: ColoredBox(
            color: bg,
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 380;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _ExportPillButton(
                                icon: Lucide.FileText,
                                label: l10n.chatSelectionExportTxt,
                                color: cs.tertiary,
                                onTap: onExportTxt,
                                dense: compact,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ExportPillButton(
                                icon: Lucide.BookOpenText,
                                label: l10n.chatSelectionExportMd,
                                color: cs.primary,
                                onTap: onExportMarkdown,
                                dense: compact,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ExportPillButton(
                                icon: Lucide.Image,
                                label: l10n.chatSelectionExportImage,
                                color: cs.secondary,
                                onTap: onExportImage,
                                dense: compact,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _ToggleCard(
                                icon: Lucide.Wrench,
                                label: l10n.chatSelectionThinkingTools,
                                selected: showThinkingTools,
                                enabled: true,
                                onTap: onToggleThinkingTools,
                                compact: compact,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ToggleCard(
                                icon: Lucide.Brain,
                                label: l10n.chatSelectionThinkingContent,
                                selected: showThinkingContent,
                                enabled: showThinkingTools,
                                onTap: onToggleThinkingContent,
                                compact: compact,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExportPillButton extends StatelessWidget {
  const _ExportPillButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = Color.alphaBlend(
      (isDark ? Colors.white : Colors.black).withOpacity(0.04),
      color.withOpacity(isDark ? 0.18 : 0.14),
    );

    return IosCardPress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      baseColor: bg,
      pressedBlendStrength: isDark ? 0.20 : 0.16,
      pressedScale: 0.98,
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: dense ? 16 : 18, color: color),
            SizedBox(width: dense ? 4 : 6),
            Text(
              label,
              style: TextStyle(
                fontSize: dense ? 13 : 14,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color base = selected
        ? cs.primary.withOpacity(isDark ? 0.22 : 0.14)
        : (isDark ? Colors.white.withOpacity(0.06) : cs.surface.withOpacity(0.55));
    final Color border = selected
        ? cs.primary.withOpacity(isDark ? 0.52 : 0.36)
        : cs.outlineVariant.withOpacity(isDark ? 0.18 : 0.14);
    final Color fg = selected ? cs.primary : cs.onSurface.withOpacity(enabled ? 0.9 : 0.35);

    return IosCardPress(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      baseColor: Colors.transparent,
      pressedBlendStrength: 0.0,
      pressedScale: 0.985,
      padding: EdgeInsets.zero,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: base,
          border: Border.all(color: border, width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
