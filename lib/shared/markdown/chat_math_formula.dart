import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:provider/provider.dart';
import 'package:val_latex_flutter/val_latex_flutter.dart' as stix;

import '../../core/providers/settings_provider.dart';
import '../../theme/app_font_weights.dart';

/// Both fonts use the same TeX source, normalization and error presentation.
class ChatMathFormula extends StatelessWidget {
  const ChatMathFormula({
    super.key,
    required this.tex,
    required this.defaultMath,
  });

  final String tex;
  final Math defaultMath;

  @override
  Widget build(BuildContext context) {
    final font = context.select<SettingsProvider?, ChatMathFont>(
      (settings) => settings?.chatMathFont ?? ChatMathFont.standard,
    );
    if (font == ChatMathFont.standard) return defaultMath;
    final style = DefaultTextStyle.of(
      context,
    ).style.merge(defaultMath.textStyle);
    final fonts = stix.MathTextFonts(
      fallback: [?style.fontFamily, ...?style.fontFamilyFallback],
    );
    return _StixFormula(
      source: (
        tex: tex,
        display: defaultMath.mathStyle == MathStyle.display,
        bold:
            MediaQuery.boldTextOf(context) ||
            (style.fontWeight ?? FontWeight.normal).value >=
                AppFontWeights.semibold.value,
        fonts: fonts,
        direction: Directionality.maybeOf(context) == TextDirection.rtl
            ? stix.TextRunDirection.rtl
            : stix.TextRunDirection.ltr,
      ),
      style: style,
      fallback: defaultMath,
    );
  }
}

typedef _StixSource = ({
  String tex,
  bool display,
  bool bold,
  stix.MathTextFonts fonts,
  stix.TextRunDirection direction,
});

class _StixFormula extends StatefulWidget {
  _StixFormula({
    required this.source,
    required this.style,
    required this.fallback,
  }) : super(key: ValueKey(source));

  final _StixSource source;
  final TextStyle style;
  final Widget fallback;

  @override
  State<_StixFormula> createState() => _StixFormulaState();
}

class _StixFormulaState extends State<_StixFormula> {
  // Keep text measurements and native paragraphs local to the mounted formula.
  late final shaper = stix.ParagraphTextShaper(widget.source.fonts);
  late final formula = _typeset();

  ({stix.ParseResult parsed, stix.MathLayout layout})? _typeset() {
    final source = widget.source;
    try {
      final parsed = stix.parseLatex(
        source.tex,
        options: stix.ParseOptions(
          displayMode: source.display,
          streaming: false,
        ),
      );
      if (parsed.hasErrors) return null;
      final layout = stix.layoutFormula(
        parsed,
        font: stix.MathFont.stixTwo,
        shaper: source.bold ? _BoldTextShaper(shaper) : shaper,
        options: stix.LayoutOptions(
          displayMode: source.display,
          textDirection: source.direction,
        ),
      );
      return (
        parsed: parsed,
        layout: source.bold ? _boldTextLayout(layout) : layout,
      );
    } catch (_) {
      // Let the existing renderer handle expressions STIX cannot typeset.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeset = formula;
    if (typeset == null) return widget.fallback;
    final style = widget.style;
    final color = style.color ?? const Color(0xff000000);
    return _StixGlyphs(
      layout: typeset.layout,
      result: typeset.parsed,
      shaper: shaper,
      fontSize: MediaQuery.textScalerOf(context).scale(style.fontSize ?? 14),
      color: MediaQuery.highContrastOf(context)
          ? color.withValues(alpha: 1)
          : color,
      bold: widget.source.bold,
      pixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 0,
    );
  }
}

// RenderMath emboldens math glyphs. Native paragraphs (such as \text) need
// the same font weight during measurement and painting.
class _BoldTextShaper implements stix.TextShaper {
  const _BoldTextShaper(this.shaper);
  final stix.ParagraphTextShaper shaper;

  @override
  stix.ShapedText shape(String text, stix.TextFont font) =>
      shaper.shape(text, font.copyWith(bold: true));
}

stix.MathLayout _boldTextLayout(stix.MathLayout layout) {
  stix.DisplayItem boldText(stix.DisplayItem item) => switch (item) {
    stix.TextItem() => stix.TextItem(
      item.text,
      item.font.copyWith(bold: true),
      item.x,
      item.y,
      item.size,
      item.width,
      glyphs: item.glyphs,
      rtl: item.rtl,
      reflected: item.reflected,
      color: item.color,
      info: item.info,
    ),
    stix.CompositeItem() => item.map(boldText),
    _ => item,
  };
  stix.Box withBoldText(stix.Box box) => stix.Box(
    box.width,
    box.height,
    box.depth,
    box.items.map(boldText).toList(),
    italic: box.italic,
    skew: box.skew,
  );
  return stix.MathLayout(
    withBoldText(layout.box),
    equationNumbers: [
      for (final number in layout.equationNumbers)
        stix.EquationNumber(
          withBoldText(number.box),
          number.baseline,
          left: number.left,
        ),
    ],
    rtl: layout.rtl,
    lineCount: layout.lineCount,
    breakPoints: layout.breakPoints,
    lineSpans: layout.lineSpans,
  );
}

/// Markstream and GenUI own scrolling and selection around this render box.
class _StixGlyphs extends LeafRenderObjectWidget {
  const _StixGlyphs({
    required this.layout,
    required this.result,
    required this.shaper,
    required this.fontSize,
    required this.color,
    required this.bold,
    required this.pixelRatio,
  });

  final stix.MathLayout layout;
  final stix.ParseResult result;
  final stix.ParagraphTextShaper shaper;
  final double fontSize;
  final Color color;
  final bool bold;
  final double pixelRatio;

  @override
  stix.RenderMath createRenderObject(BuildContext context) => stix.RenderMath(
    layout: layout,
    result: result,
    painter: stix.MathPainter(shaper),
    fontSize: fontSize,
    color: color,
    bold: bold,
    devicePixelRatio: pixelRatio,
  );

  @override
  void updateRenderObject(BuildContext context, stix.RenderMath renderObject) {
    // Paragraphs also capture their paint size and color.
    if (renderObject.fontSize != fontSize || renderObject.color != color) {
      renderObject.painter.dispose();
      renderObject.painter = stix.MathPainter(shaper);
    }
    renderObject
      ..fontSize = fontSize
      ..color = color
      ..bold = bold
      ..devicePixelRatio = pixelRatio;
  }

  @override
  void didUnmountRenderObject(stix.RenderMath renderObject) =>
      renderObject.painter.dispose();
}
