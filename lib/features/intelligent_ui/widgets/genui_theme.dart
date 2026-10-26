import 'package:flutter/material.dart';
import 'package:markstream/markstream.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'package:Kelivo/theme/design_tokens.dart';
import 'package:Kelivo/theme/surface_ladder.dart';

/// The sole mapping from Kelivo appearance tokens to generated native content.
/// Model declarations select semantic variants, never colors or pixel geometry.
final class GenUiTheme {
  GenUiTheme._(
    ThemeData theme,
    MarkstreamTheme? inheritedMarkdown, {
    bool opaque = false,
  }) {
    final appScheme = theme.colorScheme;
    final backdrop =
        !opaque && inheritedMarkdown?.backdrop != MarkstreamBackdrop.plain
        ? inheritedMarkdown
        : null;
    final colors = backdrop?.colors;
    final brightness = backdrop?.brightness ?? theme.brightness;
    final followsApp = brightness == theme.brightness;
    // Custom bubble colors can invert the local surface. Derive all accent
    // pairs together so callouts, trends, charts and filled controls agree.
    final cs = followsApp
        ? appScheme
        : ColorScheme.fromSeed(
            seedColor: appScheme.primary,
            brightness: brightness,
          );
    final appSemantic =
        theme.extension<AppSemanticColors>() ??
        (theme.brightness == Brightness.dark
            ? AppSemanticColors.dark(appScheme)
            : AppSemanticColors.light(appScheme));
    final semantic = followsApp
        ? appSemantic
        : brightness == Brightness.dark
        ? AppSemanticColors.dark(cs)
        : AppSemanticColors.light(cs);
    final ladder = SurfaceLadder.fromScheme(
      appScheme,
      layered: appSemantic.layered,
    );
    page = ladder.page;
    card = colors?.fillBlockOpaque ?? ladder.card;
    surface = colors?.fillBlock ?? card;
    previewHeader = theme.brightness == Brightness.dark
        ? card
        : appScheme.inverseSurface;
    previewHeaderInk = theme.brightness == Brightness.dark
        ? appScheme.onSurface
        : appScheme.onInverseSurface;
    fill = colors?.fillHead ?? ladder.surfaceFill;
    cardFill = colors?.fillInline ?? ladder.surfaceCardFill;
    hairline = colors?.border ?? ladder.hairline;
    hairlineStrong = colors?.borderStrong ?? ladder.hairlineStrong;
    ink = colors?.ink ?? cs.onSurface;
    secondaryInk = colors?.ink2 ?? ink.withValues(alpha: .72);
    captionInk = colors?.ink3 ?? ink.withValues(alpha: .50);
    disabledInk = ink.withValues(alpha: .30);
    primary = cs.primary;
    onPrimary = cs.onPrimary;
    primaryContainer = cs.primaryContainer;
    onPrimaryContainer = cs.onPrimaryContainer;
    error = cs.error;
    errorContainer = cs.errorContainer;
    onErrorContainer = cs.onErrorContainer;
    final success = followsApp
        ? null
        : ColorScheme.fromSeed(
            seedColor: semantic.success,
            brightness: brightness,
          );
    final warning = followsApp
        ? null
        : ColorScheme.fromSeed(
            seedColor: semantic.warning,
            brightness: brightness,
          );
    successContainer = success?.primaryContainer ?? semantic.successContainer;
    onSuccessContainer =
        success?.onPrimaryContainer ?? semantic.onSuccessContainer;
    warningContainer = warning?.primaryContainer ?? semantic.warningContainer;
    onWarningContainer =
        warning?.onPrimaryContainer ?? semantic.onWarningContainer;
    searchHighlight = semantic.searchHighlight;
    popover = Color.alphaBlend(
      AppOverlayColors.desktopPopoverSurface(appScheme),
      ladder.card,
    );
    transparent = card.withValues(alpha: 0);
    sliderThumb = ink.computeLuminance() > card.computeLuminance() ? ink : card;
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
    fieldLabel = header.copyWith(
      color: secondaryInk,
      fontWeight: AppFontWeights.medium,
    );
    input = body.copyWith(height: 1.3);
    tableBody = body.copyWith(fontSize: 13 * scale, height: 1.4);
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
    chartCenterValue = metric.copyWith(fontSize: 18 * scale, color: ink);
    // Inline content shares the resolved message backdrop, including its mask
    // strength and custom bubble colors. Standalone routes/captures instead
    // pair opaque app surfaces with app ink while retaining the message fonts.
    markdown =
        backdrop?.copyWith(body: body) ??
        MarkstreamTheme.fromColorScheme(
          cs,
          bodyStyle: body,
          codeFontFamily:
              inheritedMarkdown?.code.text.fontFamily ?? 'monospace',
          medium: AppFontWeights.medium,
          semibold: AppFontWeights.semibold,
          strong: AppFontWeights.strong,
        );
    mono = markdown.code.text;
    final dark = brightness == Brightness.dark;
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

  late final Color page,
      card,
      surface,
      fill,
      cardFill,
      hairline,
      hairlineStrong;
  late final Color previewHeader, previewHeaderInk;
  late final Color ink, secondaryInk, captionInk, disabledInk, transparent;
  late final Color sliderThumb;
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
      fieldLabel,
      input,
      tableBody,
      badge,
      metric,
      chartCenterValue,
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
  Color get headerFill => markdown.code.headerBackgroundColor;
  // The outer surface already supplies the Markdown backdrop. Painting it
  // again inside tables or donut holes would hide the wallpaper underneath.
  Color get contentBackground =>
      markdown.backdrop == MarkstreamBackdrop.plain ? card : transparent;
  BoxDecoration fieldDecoration({bool focused = false, bool invalid = false}) =>
      BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(controlRadius),
        border: Border.all(
          color: invalid
              ? error
              : focused
              ? primary
              : transparent,
          width: 2,
        ),
      );
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
          ? Color.alphaBlend(
              colors.fill.withValues(alpha: .2),
              contentBackground,
            )
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
  const GenUiThemeScope({
    super.key,
    required this.child,
    this.markdownTheme,
    this.opaque = false,
  });
  final Widget child;
  final MarkstreamTheme? markdownTheme;
  final bool opaque;
  @override
  State<GenUiThemeScope> createState() => _GenUiThemeScopeState();
}

class _GenUiThemeScopeState extends State<GenUiThemeScope> {
  ThemeData? _theme;
  MarkstreamTheme? _markdown;
  bool? _opaque;
  GenUiTheme? _data;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_data == null ||
        _theme != theme ||
        _markdown != widget.markdownTheme ||
        _opaque != widget.opaque) {
      _theme = theme;
      _markdown = widget.markdownTheme;
      _opaque = widget.opaque;
      _data = GenUiTheme._(theme, widget.markdownTheme, opaque: widget.opaque);
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
