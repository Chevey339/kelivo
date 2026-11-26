import 'package:flutter/widgets.dart';

import '../selection/selectable_rich_text.dart';
import '../selection/selectable_span_adapter.dart';

const _objectReplacement = '\uFFFC';
const _codeTextHeight = TextHeightBehavior(
  leadingDistribution: TextLeadingDistribution.even,
);

/// Displays inline code whose text joins the surrounding selection.
/// Use it in a baseline-aligned WidgetSpan inside buildSelectableText.
class InlineCodeCapsule extends StatelessWidget {
  const InlineCodeCapsule({
    super.key,
    required this.text,
    required this.style,
    required this.backgroundColor,
    required this.borderColor,
    this.textSpan,
    this.padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    this.border,
    this.radius = 6,
    this.mouseCursor = SystemMouseCursors.text,
  });

  final String text;
  final TextSpan? textSpan;
  final TextStyle style;
  final Color backgroundColor;
  final Color borderColor;
  final Border? border;
  final EdgeInsetsGeometry padding;
  final double radius;
  final MouseCursor mouseCursor;

  @override
  Widget build(BuildContext context) => DefaultSelectionStyle.merge(
    mouseCursor: mouseCursor,
    child: buildSelectableText(
      Text.rich(
        _selectionText,
        textDirection: TextDirection.ltr,
        style: style,
        textHeightBehavior: _codeTextHeight,
      ),
      inlineContainer: (child) => DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          border:
              border ??
              (borderColor.a == 0 ? null : Border.all(color: borderColor)),
          borderRadius: switch (radius) {
            6 => const BorderRadius.all(Radius.circular(6)),
            4 => const BorderRadius.all(Radius.circular(4)),
            _ => BorderRadius.circular(radius),
          },
        ),
        child: Padding(padding: padding, child: child),
      ),
    ),
  );

  TextSpan get _selectionText {
    final span = textSpan ?? TextSpan(text: text);
    return text.contains(_objectReplacement)
        ? _registerLiteralPlaceholders(span, style)
        : span;
  }

  TextSpan _registerLiteralPlaceholders(TextSpan span, TextStyle inherited) {
    final parts = span.text?.split(_objectReplacement) ?? const <String>[];
    final effectiveStyle = inherited.merge(span.style);
    // Flutter splits selectable paragraphs at U+FFFC. Give a literal
    // replacement character its own selectable when no reference chip exists.
    return TextSpan(
      text: parts.firstOrNull,
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      semanticsIdentifier: span.semanticsIdentifier,
      locale: span.locale,
      spellOut: span.spellOut,
      children: [
        for (final part in parts.skip(1)) ...[
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: SelectableSpanAdapter(
              selectedText: _objectReplacement,
              mouseCursor: mouseCursor,
              child: Text(
                _objectReplacement,
                style: effectiveStyle,
                textDirection: TextDirection.ltr,
                textHeightBehavior: _codeTextHeight,
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
          if (part.isNotEmpty)
            TextSpan(
              text: part,
              recognizer: span.recognizer,
              mouseCursor: span.mouseCursor,
              onEnter: span.onEnter,
              onExit: span.onExit,
              locale: span.locale,
              spellOut: span.spellOut,
            ),
        ],
        for (final child in span.children ?? const <InlineSpan>[])
          child is TextSpan
              ? _registerLiteralPlaceholders(child, effectiveStyle)
              : child,
      ],
    );
  }
}
