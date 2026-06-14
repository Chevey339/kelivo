import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart' as fmp;
import 'package:markdown/markdown.dart' as md;
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

class DetailsElementBuilder extends fmp.MarkdownElementBuilder {
  DetailsElementBuilder({this.extensionSet, this.builders = const {}});

  final md.ExtensionSet? extensionSet;
  final Map<String, fmp.MarkdownElementBuilder> builders;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    if (element.tag != 'details') return null;

    final attrs = element.attributes;
    final initiallyExpanded = attrs['open'] == 'true';
    final children = element.children;

    String summary = '';
    String body = '';
    if (children != null) {
      for (final child in children) {
        if (child is md.Element) {
          if (child.tag == 'summary_text') {
            final textNodes = child.children;
            if (textNodes != null &&
                textNodes.isNotEmpty &&
                textNodes[0] is md.Text) {
              summary = (textNodes[0] as md.Text).text;
            }
          } else if (child.tag == 'body_text') {
            final textNodes = child.children;
            if (textNodes != null &&
                textNodes.isNotEmpty &&
                textNodes[0] is md.Text) {
              body = (textNodes[0] as md.Text).text;
            }
          }
        }
      }
    }

    return _DetailsWidget(
      summary: summary,
      body: body,
      initiallyExpanded: initiallyExpanded,
      style: preferredStyle,
      extensionSet: extensionSet,
      builders: builders,
    );
  }
}

class _DetailsWidget extends StatefulWidget {
  const _DetailsWidget({
    required this.summary,
    required this.body,
    required this.initiallyExpanded,
    this.style,
    this.extensionSet,
    this.builders = const {},
  });

  final String summary;
  final String body;
  final bool initiallyExpanded;
  final TextStyle? style;
  final md.ExtensionSet? extensionSet;
  final Map<String, fmp.MarkdownElementBuilder> builders;

  @override
  State<_DetailsWidget> createState() => _DetailsWidgetState();
}

class _DetailsWidgetState extends State<_DetailsWidget> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Color.alphaBlend(
      cs.onSurface.withValues(alpha: isDark ? 0.05 : 0.025),
      cs.surface,
    );
    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.18 : 0.30,
    );
    final summaryStyle = (widget.style ?? const TextStyle()).copyWith(
      color: cs.onSurface,
      fontWeight: AppFontWeights.medium,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          IosCardPress(
            onTap: () => setState(() => _expanded = !_expanded),
            baseColor: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            haptics: false,
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Lucide.ChevronRight,
                    size: 15,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    widget.summary,
                    style: summaryStyle,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  alignment: const AlignmentDirectional(-1.0, -1.0),
                  child: child,
                ),
              );
            },
            child: _expanded && widget.body.isNotEmpty
                ? Container(
                    key: const ValueKey('details-expanded'),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: borderColor, width: 0.8),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: fmp.MarkdownBody(
                        data: widget.body,
                        styleSheet: fmp.MarkdownStyleSheet.fromTheme(
                          Theme.of(context),
                        ),
                        extensionSet: widget.extensionSet,
                        builders: widget.builders,
                        selectable: true,
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('details-collapsed')),
          ),
        ],
      ),
    );
  }
}
