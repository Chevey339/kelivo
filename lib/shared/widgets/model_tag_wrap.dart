import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/models/model_spec.dart';
import '../../core/utils/token_format.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

IconData _modalityIcon(Modality m) => switch (m) {
  Modality.text => Lucide.Type,
  Modality.image => Lucide.Image,
  Modality.audio => Lucide.AudioLines,
  Modality.video => Lucide.FileVideo,
  Modality.pdf => Lucide.FileText,
};

/// Shared model tag/capsule renderer used across model lists.
class ModelTagWrap extends StatelessWidget {
  const ModelTagWrap({
    super.key,
    required this.model,
    this.alignment = WrapAlignment.start,
  });

  final ModelSpec model;
  final WrapAlignment alignment;

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
              color: isDark
                  ? baseColor.withValues(alpha: darkBgAlpha)
                  : baseColor.withValues(alpha: lightBgAlpha),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: baseColor.withValues(alpha: borderAlpha),
                width: 0.5,
              ),
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
    final imageTypeLabel = l10n?.modelSpecFormImageType ?? 'Image';
    final textLabel = l10n?.modelDetailSheetTextMode ?? 'Text';
    final imageLabel = l10n?.modelDetailSheetImageMode ?? 'Image';
    final audioLabel = l10n?.modelSpecFormAudioMode ?? 'Audio';
    final videoLabel = l10n?.modelSpecFormVideoMode ?? 'Video';
    final pdfLabel = l10n?.modelSpecFormPdfMode ?? 'PDF';
    final toolsLabel = l10n?.modelDetailSheetToolsAbility ?? 'Tools';
    final reasoningLabel =
        l10n?.modelDetailSheetReasoningAbility ?? 'Reasoning';
    final contextLabel = l10n?.modelSpecFormContextWindow ?? 'Context window';

    final chips = <Widget>[];

    chips.add(
      Container(
        decoration: BoxDecoration(
          color: isDark
              ? cs.primary.withValues(alpha: 0.25)
              : cs.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          model.type == ModelType.embedding
              ? embeddingLabel
              : model.type == ModelType.image
              ? imageTypeLabel
              : chatLabel,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? cs.primary : cs.primary.withValues(alpha: 0.9),
            fontWeight: AppFontWeights.medium,
          ),
        ),
      ),
    );

    final bool embeddingHasNonTextMods =
        isEmbedding && model.input.any((m) => m != Modality.text);
    final inputMods = (isEmbedding && !embeddingHasNonTextMods)
        ? const [Modality.text]
        : (model.type != ModelType.embedding && model.input.isEmpty
              ? const [Modality.text]
              : model.input);
    final outputMods = isEmbedding
        ? const [Modality.text]
        : (model.type != ModelType.embedding && model.output.isEmpty
              ? const [Modality.text]
              : model.output);

    final inputModsUnique = LinkedHashSet<Modality>.from(
      inputMods,
    ).toList(growable: false);
    final outputModsUnique = LinkedHashSet<Modality>.from(
      outputMods,
    ).toList(growable: false);
    String modLabel(Modality m) => switch (m) {
      Modality.text => textLabel,
      Modality.image => imageLabel,
      Modality.audio => audioLabel,
      Modality.video => videoLabel,
      Modality.pdf => pdfLabel,
    };
    final ioLabel =
        '${inputModsUnique.map(modLabel).join(', ')} -> ${outputModsUnique.map(modLabel).join(', ')}';

    chips.add(
      Tooltip(
        message: ioLabel,
        child: Semantics(
          label: ioLabel,
          child: ExcludeSemantics(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? cs.tertiary.withValues(alpha: 0.25)
                    : cs.tertiary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: cs.tertiary.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final mod in inputModsUnique)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Icon(
                        _modalityIcon(mod),
                        size: 12,
                        color: isDark
                            ? cs.tertiary
                            : cs.tertiary.withValues(alpha: 0.9),
                      ),
                    ),
                  Icon(
                    Lucide.ChevronRight,
                    size: 12,
                    color: isDark
                        ? cs.tertiary
                        : cs.tertiary.withValues(alpha: 0.9),
                  ),
                  for (final mod in outputModsUnique)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(
                        _modalityIcon(mod),
                        size: 12,
                        color: isDark
                            ? cs.tertiary
                            : cs.tertiary.withValues(alpha: 0.9),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!isEmbedding) {
      final uniqueAbilities = LinkedHashSet<ModelAbility>.from(model.abilities);
      for (final ab in uniqueAbilities) {
        switch (ab) {
          case ModelAbility.tool:
            chips.add(
              _abilityChip(
                isDark: isDark,
                label: toolsLabel,
                baseColor: cs.primary,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Icon(
                  Lucide.Hammer,
                  size: 12,
                  color: isDark
                      ? cs.primary
                      : cs.primary.withValues(alpha: 0.9),
                ),
                darkBgAlpha: 0.25,
                lightBgAlpha: 0.15,
                borderAlpha: 0.2,
              ),
            );
          case ModelAbility.reasoning:
            chips.add(
              _abilityChip(
                isDark: isDark,
                label: reasoningLabel,
                baseColor: cs.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: SvgPicture.asset(
                  'assets/icons/deepthink.svg',
                  width: 12,
                  height: 12,
                  colorFilter: ColorFilter.mode(
                    isDark ? cs.secondary : cs.secondary.withValues(alpha: 0.9),
                    BlendMode.srcIn,
                  ),
                  errorBuilder: (_, __, ___) {
                    if (kDebugMode) {
                      debugPrint(
                        '[ModelTagWrap] Failed to load assets/icons/deepthink.svg',
                      );
                    }
                    return Icon(
                      Lucide.Brain,
                      size: 12,
                      color: isDark
                          ? cs.secondary
                          : cs.secondary.withValues(alpha: 0.9),
                    );
                  },
                  placeholderBuilder: (_) {
                    return Icon(
                      Lucide.Brain,
                      size: 12,
                      color: isDark
                          ? cs.secondary
                          : cs.secondary.withValues(alpha: 0.9),
                    );
                  },
                ),
                darkBgAlpha: 0.3,
                lightBgAlpha: 0.18,
                borderAlpha: 0.25,
              ),
            );
          case ModelAbility.structuredOutput:
            break;
        }
      }
    }

    final contextWindow = model.contextWindow;
    if (contextWindow != null) {
      chips.add(
        Tooltip(
          message: contextLabel,
          child: Semantics(
            label: '$contextLabel ${formatTokenCount(contextWindow)}',
            child: ExcludeSemantics(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.onSurface.withValues(alpha: 0.12)
                      : cs.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: cs.onSurface.withValues(alpha: 0.16),
                    width: 0.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(
                  formatTokenCount(contextWindow),
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: isDark ? 0.86 : 0.78),
                    fontWeight: AppFontWeights.medium,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }
}

/// Capsule row used by desktop model lists.
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
    this.alignment = WrapAlignment.start,
  });

  final ModelSpec model;
  final double iconSize;
  final EdgeInsets pillPadding;
  final double bgOpacityDark;
  final double bgOpacityLight;
  final double borderOpacity;
  final double itemSpacing;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputLabel = l10n?.modelDetailSheetInputModesLabel ?? 'Input';
    final outputLabel = l10n?.modelDetailSheetOutputModesLabel ?? 'Output';
    final imageLabel = l10n?.modelDetailSheetImageMode ?? 'Image';
    final audioLabel = l10n?.modelSpecFormAudioMode ?? 'Audio';
    final videoLabel = l10n?.modelSpecFormVideoMode ?? 'Video';
    final pdfLabel = l10n?.modelSpecFormPdfMode ?? 'PDF';
    final toolsLabel = l10n?.modelDetailSheetToolsAbility ?? 'Tools';
    final reasoningLabel =
        l10n?.modelDetailSheetReasoningAbility ?? 'Reasoning';
    final contextLabel = l10n?.modelSpecFormContextWindow ?? 'Context window';

    Widget pillCapsule(Widget icon, Color color) {
      final bg = isDark
          ? color.withValues(alpha: bgOpacityDark)
          : color.withValues(alpha: bgOpacityLight);
      final bd = color.withValues(alpha: borderOpacity);
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

    Widget labeledCapsule({
      required String label,
      required Widget icon,
      required Color color,
    }) {
      return Tooltip(
        message: label,
        child: Semantics(
          label: label,
          child: ExcludeSemantics(child: pillCapsule(icon, color)),
        ),
      );
    }

    final caps = <Widget>[];

    if (model.input.contains(Modality.image)) {
      caps.add(
        labeledCapsule(
          label: '$inputLabel: $imageLabel',
          icon: Icon(Lucide.Eye, size: iconSize, color: cs.secondary),
          color: cs.secondary,
        ),
      );
    }

    if (model.input.contains(Modality.audio)) {
      caps.add(
        labeledCapsule(
          label: '$inputLabel: $audioLabel',
          icon: Icon(Lucide.AudioLines, size: iconSize, color: cs.tertiary),
          color: cs.tertiary,
        ),
      );
    }

    if (model.input.contains(Modality.video)) {
      caps.add(
        labeledCapsule(
          label: '$inputLabel: $videoLabel',
          icon: Icon(Lucide.FileVideo, size: iconSize, color: cs.tertiary),
          color: cs.tertiary,
        ),
      );
    }

    if (model.input.contains(Modality.pdf)) {
      caps.add(
        labeledCapsule(
          label: '$inputLabel: $pdfLabel',
          icon: Icon(Lucide.FileText, size: iconSize, color: cs.tertiary),
          color: cs.tertiary,
        ),
      );
    }

    if (model.type != ModelType.embedding &&
        model.output.contains(Modality.image)) {
      caps.add(
        labeledCapsule(
          label: '$outputLabel: $imageLabel',
          icon: Icon(Lucide.Image, size: iconSize, color: cs.tertiary),
          color: cs.tertiary,
        ),
      );
    }

    if (model.type != ModelType.embedding) {
      final uniqueAbilities = LinkedHashSet<ModelAbility>.from(model.abilities);
      for (final ab in uniqueAbilities) {
        switch (ab) {
          case ModelAbility.tool:
            caps.add(
              labeledCapsule(
                label: toolsLabel,
                icon: Icon(Lucide.Hammer, size: iconSize, color: cs.primary),
                color: cs.primary,
              ),
            );
          case ModelAbility.reasoning:
            caps.add(
              labeledCapsule(
                label: reasoningLabel,
                icon: SvgPicture.asset(
                  'assets/icons/deepthink.svg',
                  width: iconSize,
                  height: iconSize,
                  colorFilter: ColorFilter.mode(cs.secondary, BlendMode.srcIn),
                  errorBuilder: (_, __, ___) {
                    if (kDebugMode) {
                      debugPrint(
                        '[ModelTagWrap] Failed to load assets/icons/deepthink.svg',
                      );
                    }
                    return Icon(
                      Lucide.Brain,
                      size: iconSize,
                      color: cs.secondary,
                    );
                  },
                  placeholderBuilder: (_) {
                    return Icon(
                      Lucide.Brain,
                      size: iconSize,
                      color: cs.secondary,
                    );
                  },
                ),
                color: cs.secondary,
              ),
            );
          case ModelAbility.structuredOutput:
            break;
        }
      }
    }

    final contextWindow = model.contextWindow;
    if (contextWindow != null) {
      caps.add(
        labeledCapsule(
          label: contextLabel,
          icon: Text(
            formatTokenCount(contextWindow),
            style: TextStyle(
              fontSize: iconSize,
              height: 1,
              color: cs.onSurface.withValues(alpha: 0.82),
              fontWeight: AppFontWeights.medium,
            ),
          ),
          color: cs.onSurface,
        ),
      );
    }

    if (caps.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: itemSpacing,
      runSpacing: itemSpacing,
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: caps,
    );
  }
}
