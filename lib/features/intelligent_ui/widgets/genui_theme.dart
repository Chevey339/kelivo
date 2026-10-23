import 'package:flutter/material.dart';
import 'package:markstream/markstream.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'package:Kelivo/theme/design_tokens.dart';
import 'package:Kelivo/theme/surface_ladder.dart';

/// The sole mapping from Kelivo appearance tokens to generated native content.
/// Model declarations select semantic variants, never colors or pixel geometry.
final class GenUiTheme {
  GenUiTheme._(ThemeData theme, MarkstreamTheme? inheritedMarkdown) {
    final cs = theme.colorScheme;
    final semantic =
        theme.extension<AppSemanticColors>() ??
        (theme.brightness == Brightness.dark
            ? AppSemanticColors.dark(cs)
            : AppSemanticColors.light(cs));
    final ladder = SurfaceLadder.fromScheme(cs, layered: semantic.layered);
    page = ladder.page;
    card = ladder.card;
    fill = ladder.surfaceFill;
    cardFill = ladder.surfaceCardFill;
    hairline = ladder.hairline;
    hairlineStrong = ladder.hairlineStrong;
    ink = cs.onSurface;
    secondaryInk = ink.withValues(alpha: .72);
    captionInk = ink.withValues(alpha: .50);
    disabledInk = ink.withValues(alpha: .30);
    primary = cs.primary;
    onPrimary = cs.onPrimary;
    primaryContainer = cs.primaryContainer;
    onPrimaryContainer = cs.onPrimaryContainer;
    error = cs.error;
    errorContainer = cs.errorContainer;
    onErrorContainer = cs.onErrorContainer;
    successContainer = semantic.successContainer;
    onSuccessContainer = semantic.onSuccessContainer;
    warningContainer = semantic.warningContainer;
    onWarningContainer = semantic.onWarningContainer;
    searchHighlight = semantic.searchHighlight;
    popover = AppOverlayColors.desktopPopoverSurface(cs);
    transparent = card.withValues(alpha: 0);
    errorWash = Color.alphaBlend(errorContainer.withValues(alpha: .20), card);
    final base =
        inheritedMarkdown?.body ??
        theme.textTheme.bodyMedium ??
        const TextStyle();
    body = base.copyWith(
      fontSize: inheritedMarkdown?.body.fontSize ?? 14.5,
      height: 1.6,
      color: ink,
    );
    final scale = body.fontSize! / 14.5;
    title = body.copyWith(
      fontSize: 16 * scale,
      height: 1.35,
      fontWeight: AppFontWeights.semibold,
    );
    sectionTitle = body.copyWith(
      fontSize: 14 * scale,
      height: 1.4,
      fontWeight: AppFontWeights.semibold,
    );
    caption = body.copyWith(
      fontSize: 12.5 * scale,
      height: 1.4,
      color: captionInk,
    );
    label = body.copyWith(fontSize: 12 * scale, height: 1.4, color: captionInk);
    header = body.copyWith(
      fontSize: 13 * scale,
      height: 1.3,
      fontWeight: AppFontWeights.semibold,
    );
    badge = body.copyWith(
      fontSize: 11 * scale,
      height: 1.3,
      fontWeight: AppFontWeights.semibold,
    );
    metric = body.copyWith(
      fontSize: 26 * scale,
      height: 1.2,
      fontWeight: AppFontWeights.semibold,
      color: primary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // GenUI cards are opaque even on wallpaper/tinted messages. Preserve the
    // inherited Markdown font choices while pairing its ink with this card.
    markdown = MarkstreamTheme.fromColorScheme(
      cs,
      bodyStyle: body,
      codeFontFamily: inheritedMarkdown?.code.text.fontFamily ?? 'monospace',
      medium: AppFontWeights.medium,
      semibold: AppFontWeights.semibold,
      strong: AppFontWeights.strong,
    );
    mono = markdown.code.text;
    final dark = theme.brightness == Brightness.dark;
    chartColors = List.unmodifiable([
      primary,
      if (dark) ...const [
        Color(0xFFFDBA74),
        Color(0xFF5EEAD4),
        Color(0xFFF0ABFC),
        Color(0xFFFDE68A),
        Color(0xFF93C5FD),
      ] else ...const [
        Color(0xFFC2410C),
        Color(0xFF0F766E),
        Color(0xFF9D3C8F),
        Color(0xFFA16207),
        Color(0xFF4B7BB5),
      ],
    ]);
  }

  late final Color page, card, fill, cardFill, hairline, hairlineStrong;
  late final Color ink, secondaryInk, captionInk, disabledInk, transparent;
  late final Color primary, onPrimary, primaryContainer, onPrimaryContainer;
  late final Color error, errorContainer, onErrorContainer, errorWash;
  late final Color successContainer, onSuccessContainer;
  late final Color warningContainer,
      onWarningContainer,
      searchHighlight,
      popover;
  late final TextStyle body,
      title,
      sectionTitle,
      caption,
      label,
      header,
      badge,
      metric,
      mono;
  late final MarkstreamTheme markdown;
  late final List<Color> chartColors;

  double get xxs => AppSpacing.xxs;
  double get xs => AppSpacing.xs;
  double get sm => AppSpacing.sm;
  double get md => AppSpacing.md;
  double get lg => AppSpacing.lg;
  double get cardRadius => MarkstreamTheme.radiusMd;
  double get controlRadius => 10;
  double get capsuleRadius => AppRadii.capsule;
  List<BoxShadow> get softShadow => AppShadows.soft;
  double gap(String? value) => switch (value) {
    'small' => xs,
    'large' => md,
    _ => sm,
  };
  TextStyle text(String? variant) => switch (variant) {
    'title' => title,
    'caption' => caption,
    'mono' => mono,
    _ => body,
  };
  ({Color fill, Color ink, Color border}) tone(
    String? value, {
    bool subtle = false,
  }) {
    final colors = switch (value) {
      'success' || 'tip' => (fill: successContainer, ink: onSuccessContainer),
      'warning' => (fill: warningContainer, ink: onWarningContainer),
      'error' => (fill: errorContainer, ink: onErrorContainer),
      'primary' || 'info' => (fill: primaryContainer, ink: onPrimaryContainer),
      _ => (fill: fill, ink: secondaryInk),
    };
    return (
      fill: subtle
          ? Color.alphaBlend(colors.fill.withValues(alpha: .2), card)
          : colors.fill,
      ink: colors.ink,
      border: colors.ink.withValues(alpha: .2),
    );
  }

  Color pieColor(int index) => index < chartColors.length
      ? chartColors[index]
      : Color.lerp(chartColors[index % chartColors.length], card, .5)!;

  static GenUiTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GenUiThemeData>()?.data ??
      GenUiTheme._(Theme.of(context), null);
}

/// Cache one derived palette per Surface, including across unrelated parent
/// rebuilds. A theme/font change replaces only appearance, not its controller.
class GenUiThemeScope extends StatefulWidget {
  const GenUiThemeScope({super.key, required this.child, this.markdownTheme});
  final Widget child;
  final MarkstreamTheme? markdownTheme;
  @override
  State<GenUiThemeScope> createState() => _GenUiThemeScopeState();
}

class _GenUiThemeScopeState extends State<GenUiThemeScope> {
  ThemeData? _theme;
  MarkstreamTheme? _markdown;
  GenUiTheme? _data;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_data == null || _theme != theme || _markdown != widget.markdownTheme) {
      _theme = theme;
      _markdown = widget.markdownTheme;
      _data = GenUiTheme._(theme, widget.markdownTheme);
    }
    return _GenUiThemeData(data: _data!, child: widget.child);
  }
}

class _GenUiThemeData extends InheritedWidget {
  const _GenUiThemeData({required this.data, required super.child});
  final GenUiTheme data;
  @override
  bool updateShouldNotify(_GenUiThemeData oldWidget) =>
      !identical(data, oldWidget.data);
}
