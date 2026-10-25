import '../text/ui_number_display.dart';
import '../text/ui_markdown_text.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:markstream/markstream.dart' as ms;
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/math_adapter.dart';
import 'genui_theme.dart';
import 'genui_clipboard.dart';
import 'genui_source_selection.dart';

/// Join a surrounding message selection; still support standalone galleries.
class _GenUiSelectableText extends StatelessWidget {
  const _GenUiSelectableText(this.text, {this.style, this.textDirection});
  final String text;
  final TextStyle? style;
  final TextDirection? textDirection;
  @override
  Widget build(BuildContext context) =>
      SelectionContainer.maybeOf(context) == null
      ? SelectableText(text, style: style, textDirection: textDirection)
      : Text(text, style: style, textDirection: textDirection);
}

class GenUiText extends StatelessWidget {
  const GenUiText({super.key, required this.text, this.variant});
  final String text;
  final String? variant;
  @override
  Widget build(BuildContext context) => _GenUiSelectableText(
    text,
    style: GenUiTheme.of(context).text(variant),
    textDirection: variant == 'mono' ? TextDirection.ltr : null,
  );
}

/// A deliberately isolated Markdown renderer. Empty extensions ensure nested
/// kelivo-ui/kelivo-web fences remain code, and images use the library's alt text.
class GenUiMarkdown extends StatelessWidget {
  const GenUiMarkdown({
    super.key,
    required this.text,
    this.linkHandler,
    this.exporting = false,
  });
  final String text;
  final ms.LinkHandler? linkHandler;
  final bool exporting;
  @override
  Widget build(BuildContext context) => ms.MarkstreamView(
    source: text,
    theme: GenUiTheme.of(context).markdown,
    options: genUiMarkdownOptions,
    mathRenderer: const _GenUiMathRenderer(),
    linkHandler: linkHandler,
    exporting: exporting,
    cullToViewport: !exporting,
    labels: _labels(AppLocalizations.of(context)!),
  );
}

final _labelCache = Expando<ms.MarkstreamLabels>();
ms.MarkstreamLabels _labels(AppLocalizations l10n) =>
    _labelCache[l10n] ??= ms.MarkstreamLabels(
      copyCode: l10n.genuiCopySource,
      copyMarkdown: l10n.markdownCopyMarkdownAction,
      copyCsv: l10n.markdownCopyCsvAction,
      expand: l10n.genuiExpand,
      collapse: l10n.codeBlockCollapseButton,
      unnamedCode: l10n.markdownCodeLabel,
      details: l10n.markdownDetailsLabel,
      moreRows: l10n.markdownMoreRows,
      note: l10n.markdownNoteLabel,
      tip: l10n.markdownTipLabel,
      important: l10n.markdownImportantLabel,
      warning: l10n.markdownWarningLabel,
      caution: l10n.markdownCautionLabel,
      danger: l10n.markdownDangerLabel,
    );

class _GenUiMathRenderer implements ms.MathRenderer {
  const _GenUiMathRenderer();
  @override
  Widget build(
    BuildContext context,
    String tex, {
    required TextStyle style,
    required bool displayMode,
  }) {
    if (GenUiFormula._requiresSource(tex)) {
      return Text(
        tex,
        textDirection: TextDirection.ltr,
        style: GenUiTheme.of(context).mono,
      );
    }
    return const KelivoMathRenderer().build(
      context,
      tex,
      style: style,
      displayMode: displayMode,
    );
  }
}

/// Use Markstream's existing code virtualization and selection without turning
/// source into another Markdown string or activating any extension builders.
class GenUiSource extends StatefulWidget {
  const GenUiSource({
    super.key,
    required this.source,
    this.language = 'kelivo-ui',
    this.exporting = false,
  });
  final String source;
  final String language;
  final bool exporting;
  @override
  State<GenUiSource> createState() => _GenUiSourceState();
}

class _GenUiSourceState extends State<GenUiSource> {
  late ms.DocumentNode _document;
  late final _extensions = ms.MarkstreamExtensions(
    actionButtonBuilder: (context, action) => ms.MarkstreamActionButton(
      action: action.kind != ms.MarkstreamActionKind.copyCode
          ? action
          : ms.MarkstreamAction(
              kind: action.kind,
              chrome: action.chrome,
              label: action.label,
              onInvoke: () => copyGenUiText(context, widget.source),
            ),
    ),
  );
  void _update() {
    final span = ms.SourceSpan(0, widget.source.length);
    _document = ms.DocumentNode(
      source: widget.source,
      children: [
        ms.CodeBlockNode(
          span: span,
          info: widget.language,
          children: [ms.TextNode(span: span, text: widget.source)],
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(GenUiSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.language != widget.language) {
      _update();
    }
  }

  @override
  Widget build(BuildContext context) => GenUiSourceSelection(
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ms.MarkstreamView(
        document: _document,
        extensions: _extensions,
        theme: GenUiTheme.of(context).markdown,
        exporting: widget.exporting,
        cullToViewport: !widget.exporting,
        labels: _labels(AppLocalizations.of(context)!),
        codeOptions: const ms.CodeBlockOptions(highlight: false),
      ),
    ),
  );
}

class GenUiFormula extends StatelessWidget {
  const GenUiFormula({
    super.key,
    required this.tex,
    this.label,
    this.exporting = false,
  });
  final String tex;
  final String? label;
  final bool exporting;
  // Formula content may not override host color, font size or pixel geometry.
  static final _visualCommands = RegExp(
    r'\\(?:color|textcolor|colorbox|fcolorbox|bbox|htmlStyle|htmlClass|htmlId|style|class|cssId|includegraphics|fontsize|Huge|huge|LARGE|Large|large|small|tiny|scriptsize|sixptsize|footnotesize|normalsize|setlength|rule|kern|mkern|hskip|mskip|hspace|vspace|raisebox|genfrac|above|tmspace|newcommand|renewcommand|providecommand|def|gdef|edef|xdef|let|futurelet|csname|expandafter)\b',
  );
  static final _sizedBreak = RegExp(
    r'(?:\\\\|\\(?:cr|newline)\b)\s*(?:%[^\n]*\n\s*)*\[',
  );
  static bool _requiresSource(String tex) =>
      tex.length > 4096 ||
      _visualCommands.hasMatch(tex) ||
      _sizedBreak.hasMatch(tex);
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    Widget fallback() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context)!.genuiFormulaInvalid,
          style: theme.caption.copyWith(color: theme.error),
        ),
        GenUiSource(source: tex, language: 'tex', exporting: exporting),
      ],
    );
    if (_requiresSource(tex)) return _withLabel(theme, fallback());
    return _withLabel(
      theme,
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final formula = Math.tex(
            normalizeMathTex(tex),
            mathStyle: MathStyle.display,
            textStyle: theme.body,
            textScaleFactor:
                MediaQuery.textScalerOf(context).scale(theme.body.fontSize!) /
                theme.body.fontSize!,
            // Layout errors can be discovered only when Math builds. The fallback
            // must retain the viewport width inside the horizontal scroll view.
            onErrorFallback: (_) => SizedBox(width: width, child: fallback()),
          );
          if (formula.parseError != null) return fallback();
          return ms.SelectableSpanAdapter(
            selectedText: tex,
            child: Semantics(
              label: tex,
              child: ExcludeSemantics(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: width),
                      child: Center(child: formula),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _withLabel(GenUiTheme theme, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (label?.isNotEmpty == true) ...[
        _GenUiSelectableText(label!, style: theme.label),
        SizedBox(height: theme.xs),
      ],
      child,
    ],
  );
}

class GenUiMetric extends StatefulWidget {
  const GenUiMetric({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.digits,
    this.trend,
  });
  final String label;
  final num? value;
  final String? unit;
  final int? digits;
  final num? trend;
  @override
  State<GenUiMetric> createState() => _GenUiMetricState();
}

class _GenUiMetricState extends State<GenUiMetric> {
  Timer? _announcement;
  String _announced = '';
  String _pending = '';
  String _description() {
    final l10n = AppLocalizations.of(context)!;
    return [
      widget.label,
      widget.value == null
          ? l10n.genuiValueUnavailable
          : genUiDisplayNumber(widget.value, digits: widget.digits),
      if (widget.unit?.isNotEmpty == true) widget.unit!,
      if (widget.trend != null)
        l10n.genuiMetricTrend(genUiDisplayNumber(widget.trend)),
    ].join(' ');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _announcement?.cancel();
    _announcement = null;
    _announced = _pending = _description();
  }

  @override
  void didUpdateWidget(GenUiMetric oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pending = _description();
    if (_pending == _announced || _announcement != null) return;
    _announcement = Timer(const Duration(milliseconds: 500), () {
      _announcement = null;
      if (mounted) setState(() => _announced = _pending);
    });
  }

  @override
  void dispose() {
    _announcement?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final trend = widget.trend;
    return Semantics(
      liveRegion: true,
      label: _announced,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.all(theme.sm),
        decoration: BoxDecoration(
          color: theme.fill,
          borderRadius: BorderRadius.circular(theme.controlRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label, style: theme.label),
            SizedBox(height: theme.xxs),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: theme.xxs,
              children: [
                Text(
                  genUiDisplayNumber(widget.value, digits: widget.digits),
                  textDirection: TextDirection.ltr,
                  style: theme.metric,
                ),
                if (widget.unit?.isNotEmpty == true)
                  Padding(
                    padding: EdgeInsets.only(bottom: theme.xxs / 2),
                    child: Text(
                      widget.unit!,
                      style: theme.header.copyWith(color: theme.secondaryInk),
                    ),
                  ),
              ],
            ),
            if (trend != null) ...[
              SizedBox(height: theme.xxs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    trend >= 0
                        ? LucideIcons.trendingUp
                        : LucideIcons.trendingDown,
                    size: 12,
                    color: trend >= 0 ? theme.onSuccessContainer : theme.error,
                  ),
                  SizedBox(width: theme.xxs),
                  Flexible(
                    child: Text(
                      '${trend > 0 ? '+' : ''}${genUiDisplayNumber(trend)}',
                      textDirection: TextDirection.ltr,
                      style: theme.label.copyWith(
                        color: trend >= 0
                            ? theme.onSuccessContainer
                            : theme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

IconData genUiToneIcon(String? tone) => switch (tone) {
  'success' => LucideIcons.circleCheck,
  'tip' => LucideIcons.lightbulb,
  'warning' => LucideIcons.triangleAlert,
  'error' => LucideIcons.circleX,
  'primary' => LucideIcons.sparkles,
  _ => LucideIcons.info,
};

class GenUiBadge extends StatelessWidget {
  const GenUiBadge({super.key, required this.text, this.tone = 'neutral'});
  final String text;
  final String tone;
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final colors = theme.tone(tone);
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.xs,
          vertical: theme.xxs,
        ),
        decoration: BoxDecoration(
          color: colors.fill,
          borderRadius: BorderRadius.circular(theme.capsuleRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tone != 'neutral') ...[
              Icon(genUiToneIcon(tone), size: 12, color: colors.ink),
              SizedBox(width: theme.xxs),
            ],
            Flexible(
              child: Text(
                text,
                style: theme.badge.copyWith(color: colors.ink),
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GenUiCallout extends StatelessWidget {
  const GenUiCallout({
    super.key,
    required this.text,
    this.title,
    this.tone = 'info',
  });
  final String text;
  final String? title;
  final String tone;
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final colors = theme.tone(tone, subtle: true);
    return Semantics(
      liveRegion: tone == 'error',
      child: Container(
        padding: EdgeInsets.all(theme.sm),
        decoration: BoxDecoration(
          color: colors.fill,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(theme.controlRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(genUiToneIcon(tone), size: 16, color: colors.ink),
                ),
                SizedBox(width: theme.xs),
                Expanded(
                  child: title?.isNotEmpty == true
                      ? Text(
                          title!,
                          style: theme.sectionTitle.copyWith(color: colors.ink),
                          textHeightBehavior: const TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          ),
                        )
                      : _GenUiSelectableText(
                          text,
                          style: theme.body.copyWith(color: colors.ink),
                        ),
                ),
              ],
            ),
            if (title?.isNotEmpty == true)
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: 16 + theme.xs,
                  top: theme.xxs,
                ),
                child: _GenUiSelectableText(
                  text,
                  style: theme.body.copyWith(color: colors.ink),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
