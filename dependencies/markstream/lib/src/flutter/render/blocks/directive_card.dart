import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/markstream_theme.dart';

/// Default presentation for named directives and GitHub alerts. The title is
/// chrome; only the source-backed body participates in document selection.
class MarkstreamDirectiveCard extends StatelessWidget {
  const MarkstreamDirectiveCard({
    super.key,
    required this.kind,
    required this.title,
    required this.theme,
    required this.child,
  });
  static const kinds = {
    'note',
    'tip',
    'important',
    'warning',
    'caution',
    'danger',
  };
  final String kind, title;
  final MarkstreamTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = theme.colors;
    final dark = theme.brightness == Brightness.dark;
    final accent = switch (kind.toLowerCase()) {
      'tip' => colors.tip,
      'warning' => colors.warning,
      'caution' || 'danger' => colors.danger,
      'important' => colors.important,
      _ => colors.accent,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DecoratedBox(
        key: ValueKey('markstream-directive-$kind'),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: dark ? .10 : .06),
          border: Border.all(
            color: accent.withValues(alpha: dark ? .26 : .22),
            width: MarkstreamTheme.stroke,
          ),
          borderRadius: BorderRadius.circular(MarkstreamTheme.radiusMd),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectionContainer.disabled(
                child: Row(
                  children: [
                    Icon(
                      switch (kind.toLowerCase()) {
                        'tip' => LucideIcons.lightbulb,
                        'warning' => LucideIcons.triangleAlert,
                        'caution' || 'danger' => LucideIcons.octagonAlert,
                        'important' => LucideIcons.messageSquareWarning,
                        _ => LucideIcons.info,
                      },
                      size: 15,
                      color: accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
