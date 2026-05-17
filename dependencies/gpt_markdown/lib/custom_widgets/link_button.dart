import 'package:flutter/material.dart';

import 'markdown_config.dart';

/// A builder that creates a styled [InlineSpan] for the given link [color].
///
/// [LinkButton] calls this on every rebuild so the span is always coloured
/// with the current hover state — normal [LinkButton.color] or
/// [LinkButton.hoverColor].
typedef LinkSpanBuilder = InlineSpan Function(Color color);

/// A custom button widget that displays a link with customisable colours.
class LinkButton extends StatefulWidget {
  /// The raw link text (used only as fallback when neither [child] nor
  /// [spanBuilder] is provided).
  final String text;

  /// A pre-built child widget (used by [linkBuilder] custom rendering).
  final Widget? child;

  /// Builds a colour-aware [InlineSpan] for the link text.
  ///
  /// Called with the current colour on every rebuild so hover transitions
  /// update all inline spans, including bold and italic content inside links.
  final LinkSpanBuilder? spanBuilder;

  /// The callback function to be called when the link is pressed.
  final VoidCallback? onPressed;

  /// The style of the text.
  final TextStyle? textStyle;

  /// The URL of the link.
  final String? url;

  /// The configuration for the link.
  final GptMarkdownConfig config;

  /// The colour used for the link in its default (non-hover) state.
  final Color color;

  /// The colour used for the link when the cursor is hovering over it.
  final Color hoverColor;

  const LinkButton({
    super.key,
    required this.text,
    required this.config,
    required this.color,
    required this.hoverColor,
    this.onPressed,
    this.textStyle,
    this.url,
    this.child,
    this.spanBuilder,
  });

  @override
  State<LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<LinkButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final currentColor = _isHovering ? widget.hoverColor : widget.color;

    Widget content;
    if (widget.child != null) {
      // Custom linkBuilder — use the pre-built widget as-is.
      content = widget.child!;
    } else if (widget.spanBuilder != null) {
      // Default path — rebuild the span with the current hover colour.
      content = widget.config.getRich(widget.spanBuilder!(currentColor));
    } else {
      // Fallback plain text path (no inline formatting in link text).
      final style = (widget.config.style ?? const TextStyle()).copyWith(
        color: currentColor,
        decoration: TextDecoration.underline,
        decorationColor: currentColor,
      );
      content = widget.config.getRich(
        TextSpan(text: widget.text, style: style),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: GestureDetector(
        onTapDown: (_) => _handlePress(true),
        onTapUp: (_) => _handlePress(false),
        onTapCancel: () => _handlePress(false),
        onTap: widget.onPressed,
        child: content,
      ),
    );
  }

  void _handleHover(bool hover) {
    setState(() {
      _isHovering = hover;
    });
  }

  void _handlePress(bool pressed) {
    setState(() {});
  }
}
