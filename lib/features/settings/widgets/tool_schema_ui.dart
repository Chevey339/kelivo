import 'package:flutter/material.dart';

import '../../../core/models/tool_schema_override.dart';
import '../../../core/services/memory/memory_tools.dart';
import '../../../core/services/search/search_tool_service.dart';
import '../../../core/services/tools/built_in_tool_catalog.dart';
import '../../../features/home/services/local_tools_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

IconData toolSchemaIconFor(String name) {
  switch (name) {
    case SearchToolService.toolName:
      return Lucide.Earth;
    case MemoryTools.memoryRead:
    case MemoryTools.memoryUpdate:
    case MemoryTools.memorySearchProfile:
    case MemoryTools.memoryEdit:
    case MemoryTools.updateUserProfile:
    case 'create_memory':
    case 'edit_memory':
      return Lucide.bookHeart;
    case MemoryTools.memoryDelete:
    case 'delete_memory':
      return Lucide.bookDashed;
    case MemoryTools.chatSearch:
      return Lucide.Search;
    case LocalToolNames.timeInfo:
      return Lucide.clock;
    case LocalToolNames.clipboard:
      return Lucide.Clipboard;
    case LocalToolNames.textToSpeech:
      return Lucide.Volume2;
    case LocalToolNames.askUser:
      return Lucide.MessageCircleQuestionMark;
    case LocalToolNames.calculate:
      return Lucide.Calculator;
    case LocalToolNames.screenTime:
      return Lucide.Smartphone;
    case LocalToolNames.calendarQuery:
      return Lucide.Calendar;
    case LocalToolNames.calendarCreate:
      return Lucide.CalendarPlus;
    case LocalToolNames.currentLocation:
      return Lucide.MapPin;
    case LocalToolNames.weather:
      return Lucide.CloudSun;
    case LocalToolNames.healthSummary:
      return Lucide.HeartPulse;
    case LocalToolNames.remindersQuery:
      return Lucide.ListTodo;
    case LocalToolNames.remindersCreate:
      return Lucide.ListPlus;
    case LocalToolNames.remindersComplete:
      return Lucide.CheckCircle;
    default:
      return Lucide.Wrench;
  }
}

String toolSchemaFirstLine(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split(RegExp(r'\r?\n')).first;
}

Future<bool> confirmResetAllToolSchemas(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: dialogContext.overlaySurface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.toolSchemaSettingsResetAllTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: AppFontWeights.emphasis,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.toolSchemaSettingsResetAllMessage,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: cs.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: IosTileButton(
                        icon: Lucide.X,
                        label: l10n.toolSchemaSettingsCancel,
                        onTap: () => Navigator.of(dialogContext).pop(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: IosTileButton(
                        icon: Lucide.RotateCcw,
                        label: l10n.toolSchemaSettingsResetAllConfirm,
                        backgroundColor: cs.error,
                        foregroundColor: cs.error,
                        onTap: () => Navigator.of(dialogContext).pop(true),
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
  return confirmed == true;
}

class ToolSchemaModifiedBadge extends StatelessWidget {
  const ToolSchemaModifiedBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: AppFontWeights.medium,
          color: cs.primary,
        ),
      ),
    );
  }
}

/// Settings-style tool row: icon, title, subtitle, optional modified badge,
/// chevron. Press wash only; no Material splash.
class ToolSchemaToolRow extends StatelessWidget {
  const ToolSchemaToolRow({
    super.key,
    required this.entry,
    this.schemaOverride,
    required this.onTap,
    this.selected = false,
    this.showChevron = true,
    this.compact = false,
  });

  final BuiltInToolCatalogEntry entry;
  final ToolSchemaOverride? schemaOverride;
  final VoidCallback onTap;
  final bool selected;
  final bool showChevron;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final modified = schemaOverride != null && !schemaOverride!.isEmpty;
    final effective = modified
        ? (schemaOverride!.description?.trim().isNotEmpty == true
              ? schemaOverride!.description!
              : entry.defaultDescription ?? '')
        : (entry.defaultDescription ?? '');
    final summary = toolSchemaFirstLine(effective);
    final radius = compact ? BorderRadius.circular(14) : BorderRadius.zero;
    final iconSize = compact ? 18.0 : 20.0;
    final titleSize = compact ? 13.5 : 15.0;
    final subtitleSize = compact ? 11.0 : 12.0;
    final pad = compact
        ? const EdgeInsets.fromLTRB(10, 9, 10, 9)
        : const EdgeInsets.fromLTRB(12, 11, 12, 11);
    final base = selected
        ? cs.primary.withValues(alpha: 0.10)
        : Colors.transparent;

    return IosCardPress(
      onTap: onTap,
      haptics: false,
      borderRadius: radius,
      baseColor: base,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: pad,
        child: Row(
          children: [
            SizedBox(
              width: compact ? 26 : 36,
              child: Icon(
                toolSchemaIconFor(entry.name),
                size: iconSize,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.9),
              ),
            ),
            SizedBox(width: compact ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: selected
                          ? AppFontWeights.semibold
                          : AppFontWeights.medium,
                      color: selected ? cs.primary : cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: subtitleSize,
                        height: 1.25,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (modified) ...[
              const SizedBox(width: 8),
              ToolSchemaModifiedBadge(label: l10n.toolSchemaSettingsModified),
            ],
            if (showChevron) ...[
              const SizedBox(width: 8),
              Icon(
                Lucide.ChevronRight,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
