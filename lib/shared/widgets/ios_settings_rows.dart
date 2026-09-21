import 'package:flutter/material.dart';

import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

/// Settings-style rows matching Backup (`_iosNavRow` / `_iosSwitchRow` /
/// `_iosDivider` / `header()` / snapshot footer) and World Book
/// (`_IosEntryRow`). Leading icon is a plain 20px [Icon] in a 36-wide slot —
/// no tinted well.
class IosNavRow extends StatelessWidget {
  const IosNavRow({
    super.key,
    this.icon,
    this.leading,
    required this.label,
    this.subtitle,
    this.caption,
    this.subtitleMaxLines = 1,
    this.detailText,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.destructive = false,
    this.labelWeight,
    this.iconColor,
  });

  final IconData? icon;

  /// Custom content in the existing icon slot, such as a file thumbnail.
  final Widget? leading;
  final String label;
  final String? subtitle;

  /// Extra muted line under [subtitle] (12 / α0.55), e.g. usage counts.
  final String? caption;

  /// `null` lets a long subtitle wrap. Defaults to one line with ellipsis.
  final int? subtitleMaxLines;
  final String? detailText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool destructive;

  /// `null` matches Backup (no weight). World Book rows pass
  /// [AppFontWeights.medium].
  final FontWeight? labelWeight;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = destructive
        ? cs.error
        : cs.onSurface.withValues(alpha: 0.9);
    final resolvedIconColor = iconColor ?? baseColor;
    final interactive = onTap != null || onLongPress != null;

    return IosCardPress(
      baseColor: Colors.transparent,
      borderRadius: BorderRadius.zero,
      pressedBlendStrength: 0,
      pressedScale: 1.0,
      haptics: interactive,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            if (icon != null || leading != null) ...[
              SizedBox(
                width: 36,
                child: leading != null
                    ? Center(child: leading)
                    : Icon(icon, size: 20, color: resolvedIconColor),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: (subtitle == null && caption == null)
                  ? Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        color: baseColor,
                        fontWeight: labelWeight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            color: baseColor,
                            fontWeight: labelWeight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: subtitleMaxLines,
                            overflow: subtitleMaxLines == null
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                          ),
                        if (caption != null)
                          Text(
                            caption!,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
            ),
            if (detailText != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  detailText!,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Lucide.ChevronRight, size: 16, color: baseColor),
          ],
        ),
      ),
    );
  }
}

/// Switch row matching Backup `_iosSwitchRow` (padding h12 v2).
class IosSwitchRow extends StatelessWidget {
  const IosSwitchRow({
    super.key,
    this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onLongPress,
    this.destructive = false,
    this.iconColor,
    this.subtitle,
  });

  final IconData? icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onLongPress;
  final bool destructive;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = destructive
        ? cs.error
        : cs.onSurface.withValues(alpha: 0.9);
    final resolvedIconColor = iconColor ?? baseColor;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return IosCardPress(
      baseColor: Colors.transparent,
      borderRadius: BorderRadius.zero,
      pressedBlendStrength: 0,
      pressedScale: 1.0,
      haptics: true,
      onTap: () => onChanged(!value),
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: hasSubtitle ? 11 : 2,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              SizedBox(
                width: 36,
                child: Icon(icon, size: 20, color: resolvedIconColor),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: hasSubtitle
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(fontSize: 15, color: baseColor),
                        ),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      label,
                      style: TextStyle(fontSize: 15, color: baseColor),
                    ),
            ),
            IosSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// Hairline between settings rows. Indent 54 = 12 pad + 36 icon + 12 gap.
/// Matches Backup / World Book `_iosDivider`.
class IosRowDivider extends StatelessWidget {
  const IosRowDivider({super.key, this.indent = 54});

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

/// Section label matching Backup `header()`.
class IosSectionHeader extends StatelessWidget {
  const IosSectionHeader({super.key, required this.text, this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, first ? 2 : 18, 12, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: AppFontWeights.semibold,
          color: cs.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

/// Hint under a section matching Backup local-snapshot footer.
class IosSectionFooter extends StatelessWidget {
  const IosSectionFooter({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.45,
          color: cs.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
