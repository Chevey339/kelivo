import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/models/model_types.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';

/// Shared model tag/capsule renderer used across model lists.
///
/// Behavior notes:
/// - Always shows model type chip.
/// - Always shows modality chip; for embeddings we default to text-only unless
///   the embedding model is explicitly multimodal (non-text modalities present).
/// - Ability chips (tool/reasoning) are rendered for chat models only.
class ModelTagWrap extends StatelessWidget {
  const ModelTagWrap({super.key, required this.model});

  final ModelInfo model;

  Widget _abilityChip({
    required bool isDark,
    required String label,
    required Color baseColor,
    required EdgeInsets padding,
    required Widget child,
    required double darkBgAlpha,
    required double lightBgAlpha,
    required double borderAlpha,
  }) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: ExcludeSemantics(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? baseColor.withOpacity(darkBgAlpha) : baseColor.withOpacity(lightBgAlpha),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: baseColor.withOpacity(borderAlpha), width: 0.5),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isEmbedding = model.type == ModelType.embedding;
    final chatLabel = l10n?.modelSelectSheetChatType ?? 'Chat';
    final embeddingLabel = l10n?.modelSelectSheetEmbeddingType ?? 'Embedding';
    final textLabel = l10n?.modelDetailSheetTextMode ?? 'Text';
    final imageLabel = l10n?.modelDetailSheetImageMode ?? 'Image';
    final toolsLabel = l10n?.modelDetailSheetToolsAbility ?? 'Tools';
    final reasoningLabel = l10n?.modelDetailSheetReasoningAbility ?? 'Reasoning';

    final chips = <Widget>[];

    // type tag
    chips.add(
      Container(
        decoration: BoxDecoration(
          color: isDark ? cs.primary.withOpacity(0.25) : cs.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.primary.withOpacity(0.2), width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          model.type == ModelType.chat ? chatLabel : embeddingLabel,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? cs.primary : cs.primary.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );

    // modality tag capsule
    final bool embeddingHasNonTextMods = isEmbedding && model.input.any((m) => m != Modality.text);
    final inputMods = (isEmbedding && !embeddingHasNonTextMods)
        ? const [Modality.text]
        : (model.type == ModelType.chat && model.input.isEmpty ? const [Modality.text] : model.input);
    // Embedding output is treated as text-only in UI; embedding supports multimodal input only.
    final outputMods = isEmbedding
        ? const [Modality.text]
        : (model.type == ModelType.chat && model.output.isEmpty ? const [Modality.text] : model.output);
    // Dedupe while preserving order (defensive against malformed/duplicated upstream data).
    final inputModsUnique = LinkedHashSet<Modality>.from(inputMods).toList(growable: false);
    final outputModsUnique = LinkedHashSet<Modality>.from(outputMods).toList(growable: false);
    String modLabel(Modality m) => m == Modality.text ? textLabel : imageLabel;
    final ioLabel = '${inputModsUnique.map(modLabel).join(', ')} → ${outputModsUnique.map(modLabel).join(', ')}';
    chips.add(
      Tooltip(
        message: ioLabel,
        child: Semantics(
          label: ioLabel,
          child: ExcludeSemantics(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? cs.tertiary.withOpacity(0.25) : cs.tertiary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.tertiary.withOpacity(0.2), width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final mod in inputModsUnique)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Icon(
                        mod == Modality.text ? Lucide.Type : Lucide.Image,
                        size: 12,
                        color: isDark ? cs.tertiary : cs.tertiary.withOpacity(0.9),
                      ),
                    ),
                  Icon(Lucide.ChevronRight, size: 12, color: isDark ? cs.tertiary : cs.tertiary.withOpacity(0.9)),
                  for (final mod in outputModsUnique)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(
                        mod == Modality.text ? Lucide.Type : Lucide.Image,
                        size: 12,
                        color: isDark ? cs.tertiary : cs.tertiary.withOpacity(0.9),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // abilities capsules - chat only
    if (!isEmbedding) {
      final uniqueAbilities = LinkedHashSet<ModelAbility>.from(model.abilities);
      for (final ab in uniqueAbilities) {
        if (ab == ModelAbility.tool) {
          final label = toolsLabel;
          chips.add(_abilityChip(
            isDark: isDark,
            label: label,
            baseColor: cs.primary,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Icon(Lucide.Hammer, size: 12, color: isDark ? cs.primary : cs.primary.withOpacity(0.9)),
            darkBgAlpha: 0.25,
            lightBgAlpha: 0.15,
            borderAlpha: 0.2,
          ));
        } else if (ab == ModelAbility.reasoning) {
          final label = reasoningLabel;
          chips.add(_abilityChip(
            isDark: isDark,
            label: label,
            baseColor: cs.secondary,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: SvgPicture.asset(
              'assets/icons/deepthink.svg',
              width: 12,
              height: 12,
              colorFilter: ColorFilter.mode(isDark ? cs.secondary : cs.secondary.withOpacity(0.9), BlendMode.srcIn),
              placeholderBuilder: (_) => Icon(
                Lucide.Brain,
                size: 12,
                color: isDark ? cs.secondary : cs.secondary.withOpacity(0.9),
              ),
            ),
            darkBgAlpha: 0.3,
            lightBgAlpha: 0.18,
            borderAlpha: 0.25,
          ));
        }
      }
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }
}

/// Capsule row used by desktop model lists.
///
/// Rules:
/// - Show input image (eye) for both chat and embedding when input includes image.
/// - Show output image for chat only.
/// - Show abilities (tool/reasoning) for chat only.
class ModelCapsulesRow extends StatelessWidget {
  const ModelCapsulesRow({
    super.key,
    required this.model,
    this.iconSize = 12,
    this.pillPadding = const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    this.bgOpacityDark = 0.20,
    this.bgOpacityLight = 0.16,
    this.borderOpacity = 0.25,
    this.itemSpacing = 4,
  });

  final ModelInfo model;
  final double iconSize;
  final EdgeInsets pillPadding;
  final double bgOpacityDark;
  final double bgOpacityLight;
  final double borderOpacity;
  final double itemSpacing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputLabel = l10n?.modelDetailSheetInputModesLabel ?? 'Input';
    final outputLabel = l10n?.modelDetailSheetOutputModesLabel ?? 'Output';
    final imageLabel = l10n?.modelDetailSheetImageMode ?? 'Image';
    final toolsLabel = l10n?.modelDetailSheetToolsAbility ?? 'Tools';
    final reasoningLabel = l10n?.modelDetailSheetReasoningAbility ?? 'Reasoning';

    Widget pillCapsule(Widget icon, Color color) {
      final bg = isDark ? color.withOpacity(bgOpacityDark) : color.withOpacity(bgOpacityLight);
      final bd = color.withOpacity(borderOpacity);
      return Container(
        padding: pillPadding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: bd, width: 0.5),
        ),
        child: icon,
      );
    }

    Widget labeledCapsule({required String label, required Widget icon, required Color color}) {
      return Tooltip(
        message: label,
        child: Semantics(
          label: label,
          child: ExcludeSemantics(
            child: pillCapsule(icon, color),
          ),
        ),
      );
    }

    final caps = <Widget>[];

    // Input: image eye (chat + embedding)
    if (model.input.contains(Modality.image)) {
      caps.add(
        labeledCapsule(
          label: '$inputLabel: $imageLabel',
          icon: Icon(Lucide.Eye, size: iconSize, color: cs.secondary),
          color: cs.secondary,
        ),
      );
    }

    // Output: image (chat only)
    if (model.type == ModelType.chat && model.output.contains(Modality.image)) {
      caps.add(
        labeledCapsule(
          label: '$outputLabel: $imageLabel',
          icon: Icon(Lucide.Image, size: iconSize, color: cs.tertiary),
          color: cs.tertiary,
        ),
      );
    }

    // Abilities: chat only
    if (model.type == ModelType.chat) {
      final uniqueAbilities = LinkedHashSet<ModelAbility>.from(model.abilities);
      for (final ab in uniqueAbilities) {
        if (ab == ModelAbility.tool) {
          caps.add(
            labeledCapsule(
              label: toolsLabel,
              icon: Icon(Lucide.Hammer, size: iconSize, color: cs.primary),
              color: cs.primary,
            ),
          );
        } else if (ab == ModelAbility.reasoning) {
          caps.add(
            labeledCapsule(
              label: reasoningLabel,
              icon: SvgPicture.asset(
                'assets/icons/deepthink.svg',
                width: iconSize,
                height: iconSize,
                colorFilter: ColorFilter.mode(cs.secondary, BlendMode.srcIn),
                placeholderBuilder: (_) => Icon(
                  Lucide.Brain,
                  size: iconSize,
                  color: cs.secondary,
                ),
              ),
              color: cs.secondary,
            ),
          );
        }
      }
    }

    if (caps.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: itemSpacing,
      runSpacing: itemSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: caps,
    );
  }
}
