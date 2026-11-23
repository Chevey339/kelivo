import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/services/media/creation_prompt_enhancer.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/thinking_sheen.dart';
import '../../../theme/app_font_weights.dart';

class CreationEnhancementPanel extends StatefulWidget {
  const CreationEnhancementPanel({
    super.key,
    required this.original,
    required this.modelName,
    required this.spans,
    required this.onClose,
    required this.onAgain,
    required this.onApply,
  });

  final String original, modelName;
  final List<CreationPromptSpan>? spans;
  final VoidCallback onClose, onAgain, onApply;

  @override
  State<CreationEnhancementPanel> createState() =>
      _CreationEnhancementPanelState();
}

class _CreationEnhancementPanelState extends State<CreationEnhancementPanel> {
  bool _showOriginal = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final spans = widget.spans;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final panel = Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.primary.withValues(alpha: .06), Colors.transparent],
        ),
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: .55),
            width: .5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 7,
        children: [
          Row(
            spacing: 7,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  Lucide.WandSparkles,
                  size: 13,
                  color: colors.primary,
                ),
              ),
              Flexible(
                child: Text(
                  spans == null
                      ? l10n.creationEnhanceLoading
                      : l10n.creationEnhanceResult,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  widget.modelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              IosIconButton(
                icon: Lucide.X,
                minSize: 26,
                size: 14,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onTap: widget.onClose,
              ),
            ],
          ),
          if (spans == null)
            ThinkingSheen(
              enabled: !reduceMotion && TickerMode.valuesOf(context).enabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 7,
                children: [
                  for (final width in [1.0, .84, .58])
                    FractionallySizedBox(
                      widthFactor: width,
                      child: Container(
                        height: 11,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 122),
              child: SingleChildScrollView(
                child: Text.rich(
                  TextSpan(
                    children: [
                      for (final span in spans)
                        TextSpan(
                          text: span.text,
                          style: span.added
                              ? TextStyle(color: colors.primary)
                              : null,
                        ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 5,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _showOriginal = !_showOriginal),
                  icon: Icon(
                    _showOriginal ? Lucide.ChevronUp : Lucide.ChevronDown,
                    size: 14,
                  ),
                  label: Text(l10n.creationEnhanceOriginal),
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 5,
                  children: [
                    TextButton.icon(
                      onPressed: widget.onAgain,
                      icon: const Icon(Lucide.RotateCcw, size: 14),
                      label: Text(l10n.creationEnhanceAgain),
                    ),
                    FilledButton.icon(
                      onPressed: widget.onApply,
                      icon: const Icon(Lucide.Check, size: 14),
                      label: Text(l10n.creationEnhanceApply),
                    ),
                  ],
                ),
              ],
            ),
            if (_showOriginal)
              Text(
                widget.original,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
          ],
        ],
      ),
    );
    if (reduceMotion) return panel;
    return panel
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 260))
        .slideY(begin: .045, end: 0);
  }
}
