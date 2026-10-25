import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'genui_content.dart';
import 'genui_theme.dart';

class GenUiColumn extends StatelessWidget {
  const GenUiColumn({super.key, required this.children, this.gap = 'medium'});
  final List<Widget> children;
  final String gap;
  @override
  Widget build(BuildContext context) {
    final spacing = GenUiTheme.of(context).gap(gap);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          children[i],
        ],
      ],
    );
  }
}

class GenUiRow extends StatelessWidget {
  const GenUiRow({
    super.key,
    required this.children,
    this.gap = 'medium',
    this.distribution = 'equal',
  });
  final List<Widget> children;
  final String gap;
  final String distribution;
  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = GenUiTheme.of(context);
    final spacing = theme.gap(gap);
    final scale = MediaQuery.textScalerOf(context).scale(14.5) / 14.5;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columns = width < 360 || scale >= 1.3
            ? 1
            : math.min(
                children.length,
                math.max(
                  1,
                  ((width + spacing) / (theme.md * 10 + spacing)).floor(),
                ),
              );
        final childWidth = (width - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              // Keep the same keyed parent and child Elements across width,
              // text-scale and sibling-visibility changes: inputs own focus/IME.
              ConstrainedBox(
                key: child.key,
                constraints: distribution == 'fit'
                    ? BoxConstraints(maxWidth: width)
                    : BoxConstraints.tightFor(width: childWidth),
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class GenUiSection extends StatelessWidget {
  const GenUiSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.tone = 'info',
  });
  final String title;
  final String? subtitle;
  final String tone;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final colors = theme.tone(tone);
    final showIcon = tone != 'info' && tone != 'primary';
    return Container(
      padding: tone == 'primary'
          ? EdgeInsetsDirectional.only(start: theme.sm)
          : null,
      decoration: tone == 'primary'
          ? BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: theme.primary, width: 3),
              ),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Row(
              children: [
                if (showIcon) ...[
                  ExcludeSemantics(
                    child: Icon(
                      genUiToneIcon(tone),
                      size: 14,
                      color: colors.ink,
                    ),
                  ),
                  SizedBox(width: theme.xs),
                ],
                Expanded(child: Text(title, style: theme.sectionTitle)),
              ],
            ),
          ),
          if (subtitle?.isNotEmpty == true) ...[
            SizedBox(height: theme.xxs),
            Text(subtitle!, style: theme.label),
          ],
          if (children.isNotEmpty) ...[
            SizedBox(height: theme.sm),
            GenUiColumn(children: children),
          ],
        ],
      ),
    );
  }
}

class GenUiDivider extends StatelessWidget {
  const GenUiDivider({super.key, this.label});
  final String? label;
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    Widget rule() =>
        SizedBox(height: 1, child: ColoredBox(color: theme.hairline));
    return ExcludeSemantics(
      child: label?.isNotEmpty != true
          ? rule()
          : LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  Expanded(child: rule()),
                  SizedBox(width: theme.xs),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.max(
                        0,
                        (constraints.maxWidth - theme.xs * 2) * .7,
                      ),
                    ),
                    child: Text(
                      label!,
                      textAlign: TextAlign.center,
                      style: theme.label,
                    ),
                  ),
                  SizedBox(width: theme.xs),
                  Expanded(child: rule()),
                ],
              ),
            ),
    );
  }
}
