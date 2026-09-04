import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_labels.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

/// Compact chat-input chip. Hidden while the sandbox is [EnvironmentPhase.ready].
class EnvironmentStatusChip extends StatelessWidget {
  const EnvironmentStatusChip({super.key, this.onTap});

  static const chipKey = ValueKey<String>('workspace-env-status-chip');

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EnvironmentProvider>().state;
    if (state.phase == EnvironmentPhase.ready) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final label = _label(l10n, state);
    final (bg, fg, icon) = _tone(cs, colors, state.phase);

    final chip = IosCardPress(
      key: chipKey,
      haptics: false,
      onTap: onTap == null
          ? null
          : () {
              Haptics.light();
              onTap!();
            },
      borderRadius: BorderRadius.circular(999),
      baseColor: bg,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: AppFontWeights.semibold,
              color: fg,
            ),
          ),
        ],
      ),
    );
    if (ResponsiveHelper.isDesktop(context)) {
      return Tooltip(message: label, child: chip);
    }
    return chip;
  }

  static String _label(AppLocalizations l10n, EnvironmentState state) {
    switch (state.phase) {
      case EnvironmentPhase.notInstalled:
        return l10n.workspaceEnvChipInstall;
      case EnvironmentPhase.downloading:
      case EnvironmentPhase.verifying:
      case EnvironmentPhase.extracting:
      case EnvironmentPhase.patching:
        final percent = workspaceEnvInstallPercent(state);
        if (percent == null) {
          return l10n.workspaceEnvChipInstallingIndeterminate;
        }
        return l10n.workspaceEnvChipInstalling(percent);
      case EnvironmentPhase.error:
        return l10n.workspaceEnvChipError;
      case EnvironmentPhase.needsRestart:
        return l10n.workspaceEnvChipRestart;
      case EnvironmentPhase.ready:
        return '';
    }
  }

  static (Color, Color, IconData) _tone(
    ColorScheme cs,
    AppSemanticColors colors,
    EnvironmentPhase phase,
  ) {
    switch (phase) {
      case EnvironmentPhase.error:
        return (
          cs.error.withValues(alpha: 0.12),
          cs.error,
          Lucide.TriangleAlert,
        );
      case EnvironmentPhase.needsRestart:
        return (
          colors.warning.withValues(alpha: 0.14),
          colors.warning,
          Lucide.RotateCcw,
        );
      case EnvironmentPhase.downloading:
      case EnvironmentPhase.verifying:
      case EnvironmentPhase.extracting:
      case EnvironmentPhase.patching:
        return (
          cs.primary.withValues(alpha: 0.12),
          cs.primary,
          Lucide.Download,
        );
      case EnvironmentPhase.notInstalled:
      case EnvironmentPhase.ready:
        return (
          cs.onSurface.withValues(alpha: 0.08),
          cs.onSurface.withValues(alpha: 0.7),
          Lucide.HardDrive,
        );
    }
  }
}
