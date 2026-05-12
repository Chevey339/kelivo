import 'package:flutter/material.dart';

class ChatInputOverlayLayout extends StatelessWidget {
  const ChatInputOverlayLayout({
    super.key,
    required this.topInset,
    required this.content,
    required this.bottomOverlay,
    this.contentBottomInset = 0,
    this.bottomOverlayInset = 0,
    this.background,
    this.foreground,
  });

  final double topInset;
  final Widget content;
  final Widget bottomOverlay;
  final double contentBottomInset;
  final double bottomOverlayInset;
  final Widget? background;
  final Widget? foreground;

  @override
  Widget build(BuildContext context) {
    final effectiveContentBottomInset = contentBottomInset
        .clamp(0.0, double.infinity)
        .toDouble();
    final effectiveBottomOverlayInset = bottomOverlayInset
        .clamp(0.0, double.infinity)
        .toDouble();
    return Stack(
      children: [
        if (background != null) Positioned.fill(child: background!),
        Positioned.fill(
          top: topInset,
          bottom: effectiveContentBottomInset,
          child: content,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: effectiveBottomOverlayInset,
          child: UnconstrainedBox(
            constrainedAxis: Axis.horizontal,
            alignment: Alignment.bottomCenter,
            child: bottomOverlay,
          ),
        ),
        if (foreground != null) Positioned.fill(child: foreground!),
      ],
    );
  }
}
