import 'package:flutter/widgets.dart';

class TerminalTheme {
  const TerminalTheme({
    required this.cursor,
    required this.selection,
    required this.foreground,
    required this.background,
    required this.black,
    required this.white,
    required this.red,
    required this.green,
    required this.yellow,
    required this.blue,
    required this.magenta,
    required this.cyan,
    required this.brightBlack,
    required this.brightRed,
    required this.brightGreen,
    required this.brightYellow,
    required this.brightBlue,
    required this.brightMagenta,
    required this.brightCyan,
    required this.brightWhite,
    required this.searchHitBackground,
    required this.searchHitBackgroundCurrent,
    required this.searchHitForeground,
    this.cursorAccent,
    this.selectionForeground,
    this.minimumContrastRatio = 1.0,
    this.drawBoldTextInBrightColors = true,
  });

  final Color cursor;
  final Color selection;

  final Color? cursorAccent;
  final Color? selectionForeground;
  final double minimumContrastRatio;
  final bool drawBoldTextInBrightColors;

  final Color foreground;
  final Color background;

  final Color black;
  final Color red;
  final Color green;
  final Color yellow;
  final Color blue;
  final Color magenta;
  final Color cyan;
  final Color white;

  final Color brightBlack;
  final Color brightRed;
  final Color brightGreen;
  final Color brightYellow;
  final Color brightBlue;
  final Color brightMagenta;
  final Color brightCyan;
  final Color brightWhite;

  final Color searchHitBackground;
  final Color searchHitBackgroundCurrent;
  final Color searchHitForeground;

  // A new theme clears the paragraph cache. Callers build one inline on every
  // widget rebuild, so identity comparison would flush it several times a
  // second for nothing.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TerminalTheme &&
        other.cursor == cursor &&
        other.selection == selection &&
        other.foreground == foreground &&
        other.background == background &&
        other.black == black &&
        other.red == red &&
        other.green == green &&
        other.yellow == yellow &&
        other.blue == blue &&
        other.magenta == magenta &&
        other.cyan == cyan &&
        other.white == white &&
        other.brightBlack == brightBlack &&
        other.brightRed == brightRed &&
        other.brightGreen == brightGreen &&
        other.brightYellow == brightYellow &&
        other.brightBlue == brightBlue &&
        other.brightMagenta == brightMagenta &&
        other.brightCyan == brightCyan &&
        other.brightWhite == brightWhite &&
        other.searchHitBackground == searchHitBackground &&
        other.searchHitBackgroundCurrent == searchHitBackgroundCurrent &&
        other.searchHitForeground == searchHitForeground &&
        other.cursorAccent == cursorAccent &&
        other.selectionForeground == selectionForeground &&
        other.minimumContrastRatio == minimumContrastRatio &&
        other.drawBoldTextInBrightColors == drawBoldTextInBrightColors;
  }

  @override
  int get hashCode => Object.hashAll([
        cursor,
        selection,
        foreground,
        background,
        black,
        red,
        green,
        yellow,
        blue,
        magenta,
        cyan,
        white,
        brightBlack,
        brightRed,
        brightGreen,
        brightYellow,
        brightBlue,
        brightMagenta,
        brightCyan,
        brightWhite,
        searchHitBackground,
        searchHitBackgroundCurrent,
        searchHitForeground,
        cursorAccent,
        selectionForeground,
        minimumContrastRatio,
        drawBoldTextInBrightColors,
      ]);
}
