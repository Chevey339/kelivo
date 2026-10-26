import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'genui_theme.dart';

class GenUiFieldFrame extends StatelessWidget {
  const GenUiFieldFrame({
    super.key,
    required this.label,
    required this.child,
    this.requiredField = false,
    this.error,
    this.helper,
    this.counter,
  });
  final String label;
  final Widget child;
  final bool requiredField;
  final String? error, helper, counter;
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label.isNotEmpty)
          ExcludeSemantics(
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (requiredField)
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: theme.error),
                    ),
                ],
              ),
              style: theme.fieldLabel,
            ),
          ),
        if (label.isNotEmpty) SizedBox(height: theme.xxs),
        child,
        if (error != null) ...[
          SizedBox(height: theme.xxs),
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    LucideIcons.circleAlert,
                    size: 14,
                    color: theme.error,
                  ),
                ),
                SizedBox(width: theme.xxs),
                Expanded(
                  child: Text(
                    error!,
                    style: theme.caption.copyWith(color: theme.error),
                  ),
                ),
              ],
            ),
          ),
        ] else if (helper != null) ...[
          SizedBox(height: theme.xxs),
          Text(helper!, style: theme.caption),
        ],
        if (counter != null) ...[
          SizedBox(height: theme.xxs),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(counter!, style: theme.caption),
          ),
        ],
      ],
    );
  }
}

/// Compact visual fill; the child retains its complete touch/keyboard region.
class GenUiFieldSurface extends StatelessWidget {
  const GenUiFieldSurface({
    super.key,
    required this.decoration,
    required this.child,
  });
  final BoxDecoration decoration;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        top: 4,
        bottom: 4,
        child: DecoratedBox(decoration: decoration),
      ),
      child,
    ],
  );
}
