import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = switch (kind.toLowerCase()) {
      'tip' => Color(dark ? 0xff75dfa3 : 0xff166534),
      'warning' => Color(dark ? 0xffffd17b : 0xff855000),
      'caution' || 'danger' => scheme.error,
      'important' => scheme.tertiary,
      _ => scheme.primary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        key: ValueKey('markstream-directive-$kind'),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: dark ? .10 : .05),
          border: BorderDirectional(start: BorderSide(color: accent, width: 3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectionContainer.disabled(
                child: Text(
                  title,
                  style: theme.body.copyWith(
                    color: accent,
                    fontWeight: theme.strongWeight,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
