import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_labels.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

class EnvironmentRowDivider extends StatelessWidget {
  const EnvironmentRowDivider({super.key, this.indent = 54});

  final double indent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Divider(
      height: 6,
      thickness: 0.6,
      indent: indent,
      endIndent: 12,
      color: cs.outlineVariant.withValues(alpha: 0.18),
    );
  }
}

class EnvironmentMetricRow extends StatelessWidget {
  const EnvironmentMetricRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final Widget value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return IosCardPress(
      haptics: false,
      onTap: () {
        Haptics.light();
        onTap!();
      },
      borderRadius: BorderRadius.circular(12),
      child: row,
    );
  }
}

class EnvironmentPhaseCapsule extends StatelessWidget {
  const EnvironmentPhaseCapsule({super.key, required this.phase});

  final EnvironmentPhase phase;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context)!;
    final Color fg = switch (phase) {
      EnvironmentPhase.ready => colors.success,
      EnvironmentPhase.error => cs.error,
      EnvironmentPhase.needsRestart => colors.warning,
      EnvironmentPhase.notInstalled => cs.onSurface.withValues(alpha: 0.5),
      _ => cs.primary,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          workspaceEnvPhaseLabel(l10n, phase),
          style: TextStyle(
            fontSize: 11,
            fontWeight: AppFontWeights.medium,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class EnvironmentTextCapsule extends StatelessWidget {
  const EnvironmentTextCapsule({
    super.key,
    required this.label,
    this.foreground,
    this.background,
  });

  final String label;
  final Color? foreground;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final fg = foreground ?? cs.onSurface.withValues(alpha: 0.7);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? colors.surfaceFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: AppFontWeights.medium,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class EnvironmentLatencyCapsule extends StatelessWidget {
  const EnvironmentLatencyCapsule({
    super.key,
    required this.ms,
    required this.timedOut,
  });

  final int? ms;
  final bool timedOut;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context)!;
    if (timedOut || ms == null) {
      return EnvironmentTextCapsule(
        label: l10n.workspaceEnvMirrorTimeout,
        foreground: cs.onSurface.withValues(alpha: 0.5),
      );
    }
    final value = ms!;
    final Color fg = value < 200
        ? colors.success
        : (value < 500 ? colors.warning : cs.error);
    return EnvironmentTextCapsule(
      label: l10n.workspaceEnvMirrorLatency(value),
      foreground: fg,
      background: fg.withValues(alpha: 0.12),
    );
  }
}

class EnvironmentSwitchRow extends StatelessWidget {
  const EnvironmentSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.switchKey,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: subtitle == null ? 2 : 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: IosCardPress(
              haptics: false,
              onTap: onChanged == null
                  ? null
                  : () {
                      Haptics.light();
                      onChanged!(!value);
                    },
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.medium,
                      color: cs.onSurface,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: cs.onSurface.withValues(alpha: 0.56),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          IosSwitch(key: switchKey, value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class EnvironmentInlineSpinner extends StatelessWidget {
  const EnvironmentInlineSpinner({super.key, this.radius = 8});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return CupertinoActivityIndicator(radius: radius);
  }
}
