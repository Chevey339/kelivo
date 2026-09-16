import 'package:flutter/material.dart';

import '../../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../../icons/lucide_adapter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ios_tactile.dart';
import '../../../../theme/app_font_weights.dart';

String specSourceLabel(AppLocalizations l10n, SpecSource source) {
  return switch (source) {
    SpecSource.override => l10n.modelSpecFormSourceCustom,
    SpecSource.catalog => l10n.modelSpecFormSourceCatalog,
    SpecSource.guess => l10n.modelSpecFormSourceInferred,
    SpecSource.vendor || SpecSource.fallback => l10n.modelSpecFormSourceDefault,
  };
}

class SpecFieldHeader extends StatelessWidget {
  const SpecFieldHeader({
    super.key,
    required this.label,
    required this.source,
    required this.overridden,
    this.onReset,
    this.trailing,
  });

  final String label;
  final SpecSource source;
  final bool overridden;
  final VoidCallback? onReset;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: AppFontWeights.semibold,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
          _SourceCapsule(label: specSourceLabel(l10n, source)),
          if (overridden && onReset != null)
            IosIconButton(
              icon: Lucide.RotateCcw,
              size: 16,
              minSize: 32,
              tooltip: l10n.modelSpecFormReset,
              semanticLabel: l10n.modelSpecFormReset,
              color: cs.onSurface.withValues(alpha: 0.7),
              onTap: onReset,
            ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SourceCapsule extends StatelessWidget {
  const _SourceCapsule({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('spec-source-capsule'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
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
