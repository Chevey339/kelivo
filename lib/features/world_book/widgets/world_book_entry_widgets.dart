import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../core/models/world_book.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../theme/app_font_weights.dart';

Color worldBookPositionColor(
  BuildContext context,
  WorldBookInjectionPosition position,
) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (position) {
    WorldBookInjectionPosition.beforeSystemPrompt =>
      dark ? const Color(0xFFB6A0FF) : const Color(0xFF7052C2),
    WorldBookInjectionPosition.afterSystemPrompt =>
      dark ? const Color(0xFF82B6FF) : const Color(0xFF2864BA),
    WorldBookInjectionPosition.topOfChat =>
      dark ? const Color(0xFF70CFB8) : const Color(0xFF227C69),
    WorldBookInjectionPosition.bottomOfChat =>
      dark ? const Color(0xFFFFBD76) : const Color(0xFF9A5B13),
    WorldBookInjectionPosition.atDepth =>
      dark ? const Color(0xFFFF9CB9) : const Color(0xFFB33A65),
  };
}

String worldBookPositionLabel(
  AppLocalizations l10n,
  WorldBookInjectionPosition position,
) => switch (position) {
  WorldBookInjectionPosition.beforeSystemPrompt =>
    l10n.worldBookInjectionPositionBeforeSystemPrompt,
  WorldBookInjectionPosition.afterSystemPrompt =>
    l10n.worldBookInjectionPositionAfterSystemPrompt,
  WorldBookInjectionPosition.topOfChat =>
    l10n.worldBookInjectionPositionTopOfChat,
  WorldBookInjectionPosition.bottomOfChat =>
    l10n.worldBookInjectionPositionBottomOfChat,
  WorldBookInjectionPosition.atDepth => l10n.worldBookInjectionPositionAtDepth,
};

class WorldBookPositionBadge extends StatelessWidget {
  const WorldBookPositionBadge({
    super.key,
    required this.position,
    this.depth,
    this.enabled = true,
  });
  final WorldBookInjectionPosition position;
  final int? depth;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = worldBookPositionColor(context, position);
    final label = worldBookPositionLabel(
      AppLocalizations.of(context)!,
      position,
    );
    final text = position == WorldBookInjectionPosition.atDepth && depth != null
        ? '$label · $depth'
        : label;
    return Tooltip(
      message: text,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: AppFontWeights.medium,
            ),
          ),
        ),
      ),
    );
  }
}

class WorldBookEntryTitle extends StatelessWidget {
  const WorldBookEntryTitle({
    super.key,
    required this.entry,
    this.fontSize = 15,
  });

  final WorldBookEntry entry;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final title = entry.name.trim().isEmpty
        ? AppLocalizations.of(context)!.worldBookUnnamedEntry
        : entry.name.trim();
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: AppFontWeights.medium,
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: entry.enabled ? 0.9 : 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: WorldBookPositionBadge(
            position: entry.position,
            depth: entry.injectDepth,
            enabled: entry.enabled,
          ),
        ),
      ],
    );
  }
}

/// Shared fields keep the mobile sheet and desktop dialog's timing semantics identical.
class WorldBookTimedEffectsFields extends StatefulWidget {
  const WorldBookTimedEffectsFields({
    super.key,
    required this.entry,
    required this.onChanged,
  });
  final WorldBookEntry entry;
  final void Function(int sticky, int cooldown, int delay) onChanged;

  @override
  State<WorldBookTimedEffectsFields> createState() =>
      _WorldBookTimedEffectsFieldsState();
}

class _WorldBookTimedEffectsFieldsState
    extends State<WorldBookTimedEffectsFields> {
  late final _controllers = [
    widget.entry.sticky,
    widget.entry.cooldown,
    widget.entry.delay,
  ].map((value) => TextEditingController(text: '$value')).toList();

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fields = [
      (l10n.worldBookStickyLabel, l10n.worldBookStickyHint),
      (l10n.worldBookCooldownLabel, l10n.worldBookCooldownHint),
      (l10n.worldBookDelayLabel, l10n.worldBookDelayHint),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          IosFormTextField(
            label: fields[i].$1,
            controller: _controllers[i],
            keyboardType: TextInputType.number,
            fieldWidth: 80,
            selectAllOnFocus: true,
            onChanged: (_) {
              final values = _controllers
                  .map(
                    (c) => (int.tryParse(c.text.trim()) ?? 0).clamp(0, 10000),
                  )
                  .toList();
              widget.onChanged(values[0], values[1], values[2]);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Text(
              fields[i].$2,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

@Preview(
  name: 'World book positions · light',
  size: Size(340, 220),
  brightness: Brightness.light,
)
@Preview(
  name: 'World book positions · dark',
  size: Size(340, 220),
  brightness: Brightness.dark,
)
Widget worldBookPositionBadgesPreview() => Localizations(
  locale: const Locale('zh'),
  delegates: AppLocalizations.localizationsDelegates,
  child: Builder(
    builder: (context) => Material(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            for (final position in WorldBookInjectionPosition.values)
              WorldBookPositionBadge(position: position, depth: 4),
          ],
        ),
      ),
    ),
  ),
);
