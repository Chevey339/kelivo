import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/providers/model_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isEmbedding = model.type == ModelType.embedding;

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
          model.type == ModelType.chat ? l10n.modelSelectSheetChatType : l10n.modelSelectSheetEmbeddingType,
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
    String modLabel(Modality m) => m == Modality.text ? l10n.modelDetailSheetTextMode : l10n.modelDetailSheetImageMode;
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
      final uniqueAbilities = LinkedHashSet<ModelAbility>.from(model.abilities).toList(growable: false);
      for (final ab in uniqueAbilities) {
        if (ab == ModelAbility.tool) {
          final label = l10n.modelDetailSheetToolsAbility;
          chips.add(
            Tooltip(
              message: label,
              child: Semantics(
                label: label,
                child: ExcludeSemantics(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? cs.primary.withOpacity(0.25) : cs.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: cs.primary.withOpacity(0.2), width: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Icon(Lucide.Hammer, size: 12, color: isDark ? cs.primary : cs.primary.withOpacity(0.9)),
                  ),
                ),
              ),
            ),
          );
        } else if (ab == ModelAbility.reasoning) {
          final label = l10n.modelDetailSheetReasoningAbility;
          chips.add(
            Tooltip(
              message: label,
              child: Semantics(
                label: label,
                child: ExcludeSemantics(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? cs.secondary.withOpacity(0.3) : cs.secondary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: cs.secondary.withOpacity(0.25), width: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: SvgPicture.asset(
                      'assets/icons/deepthink.svg',
                      width: 12,
                      height: 12,
                      colorFilter: ColorFilter.mode(isDark ? cs.secondary : cs.secondary.withOpacity(0.9), BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
          );
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

    Widget pillCapsule(Widget icon, Color color) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
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

    final caps = <Widget>[];

    // Input: image eye (chat + embedding)
    if (model.input.contains(Modality.image)) {
      caps.add(pillCapsule(Icon(Lucide.Eye, size: iconSize, color: cs.secondary), cs.secondary));
    }

    // Output: image (chat only)
    if (model.type == ModelType.chat && model.output.contains(Modality.image)) {
      caps.add(pillCapsule(Icon(Lucide.Image, size: iconSize, color: cs.tertiary), cs.tertiary));
    }

    // Abilities: chat only
    if (model.type == ModelType.chat) {
      final uniqueAbilities = LinkedHashSet<ModelAbility>.from(model.abilities);
      for (final ab in uniqueAbilities) {
        if (ab == ModelAbility.tool) {
          caps.add(pillCapsule(Icon(Lucide.Hammer, size: iconSize, color: cs.primary), cs.primary));
        } else if (ab == ModelAbility.reasoning) {
          caps.add(pillCapsule(
            SvgPicture.asset(
              'assets/icons/deepthink.svg',
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(cs.secondary, BlendMode.srcIn),
            ),
            cs.secondary,
          ));
        }
      }
    }

    if (caps.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < caps.length; i++) ...[
          if (i != 0) SizedBox(width: itemSpacing),
          caps[i],
        ],
      ],
    );
  }
}
