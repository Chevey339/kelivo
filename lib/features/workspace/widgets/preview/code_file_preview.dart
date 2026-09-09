import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/themes/atom-one-dark-reasonable.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:highlight/highlight.dart' show Node, highlight;
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/utils/format_bytes.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

import 'preview_file_type.dart';
import 'paged_text_file_view.dart';
import 'preview_states.dart';
import 'preview_text_document.dart';

export 'preview_file_type.dart'
    show highlightLanguageFor, languageForExtension, languageForPath;

/// Matches chat `_CollapsibleCodeBlock` chrome (fill alpha + 16 radius).
const double _kCodeBlockFillAlpha = 0.80;
const double _kCodeBlockRadius = 16;
const double _kMinFontSize = 11;
const double _kMaxFontSize = 20;
const double _kDefaultFontSize = 13;
const EdgeInsets _kGutterPadding = EdgeInsets.fromLTRB(0, 8, 8, 12);
const EdgeInsets _kCodePadding = EdgeInsets.fromLTRB(12, 8, 12, 12);
const double _kCursorWidth = 2;

/// RenderEditable reserves a caret gap plus the cursor width and lays the text
/// out at `maxWidth - this`, so a wrap measurement has to subtract it too.
const double _kCaretMargin = 1 + _kCursorWidth;

class CodeFilePreview extends StatefulWidget {
  const CodeFilePreview({
    super.key,
    required this.file,
    this.document,
    this.showCopyButton = true,
    this.autoLoad = true,
    this.language,
  });

  static const Key plainTextListKey = PagedTextFileView.listKey;
  static const Key lineCountKey = ValueKey<String>(
    'code-file-preview-line-count',
  );
  static const Key languageLabelKey = ValueKey<String>(
    'code-file-preview-language',
  );
  static const Key wrapToggleKey = ValueKey<String>(
    'code-file-preview-wrap-toggle',
  );
  static const Key horizontalScrollKey = ValueKey<String>(
    'code-file-preview-horizontal-scroll',
  );
  static const Key gutterKey = ValueKey<String>('code-file-preview-gutter');
  static const Key codeKey = ValueKey<String>('code-file-preview-code');

  final File file;
  final PreviewTextDocument? document;
  final bool showCopyButton;
  final bool autoLoad;

  /// Highlight / header language. When null, derived from the file extension.
  final String? language;

  @override
  CodeFilePreviewState createState() => CodeFilePreviewState();
}

class CodeFilePreviewState extends State<CodeFilePreview> {
  bool _loading = true;
  bool _failed = false;
  bool _wrap = false;
  double _fontSize = _kDefaultFontSize;
  PreviewTextDocument? _document;
  int _loadGeneration = 0;

  bool _copying = false;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _loading = _document == null;
    if (_loading && widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(load());
      });
    }
  }

  @override
  void didUpdateWidget(covariant CodeFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.document != widget.document) {
      _loadGeneration++;
      _document = widget.document;
      _loading = _document == null;
      _failed = false;
      if (_loading && widget.autoLoad) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(load());
        });
      }
    }
  }

  @visibleForTesting
  Future<void> load() async {
    final generation = ++_loadGeneration;
    try {
      final document = await loadPreviewTextDocument(widget.file);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _document = document;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _document = null;
        _loading = false;
        _failed = true;
      });
    }
  }

  String get _language {
    final override = widget.language?.trim();
    if (override != null && override.isNotEmpty) return override;
    return languageForPath(widget.file.path);
  }

  String get _displayLanguage {
    final raw = _language.trim();
    if (raw.isNotEmpty) return raw;
    return 'text';
  }

  Future<void> _copySource() async {
    final l10n = AppLocalizations.of(context)!;
    Haptics.light();
    if (_copying) return;
    final document = _document!;
    setState(() => _copying = true);
    try {
      final source = await document.readSource();
      if (!mounted || _document != document) return;
      await Clipboard.setData(ClipboardData(text: source));
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.chatMessageWidgetCopiedToClipboard,
        type: NotificationType.success,
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.workspacePreviewLoadError,
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  String _resolveCodeFont() {
    try {
      final fam = context.watch<SettingsProvider>().codeFontFamily;
      if (fam == null || fam.isEmpty) return 'monospace';
      return fam;
    } catch (_) {
      return 'monospace';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PreviewLoading(
        key: ValueKey<String>('code-file-preview-loading'),
      );
    }
    if (_failed) {
      return PreviewError(onRetry: () => unawaited(load()));
    }
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final document = _document!;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lines = document.lines;
    final theme = _transparentBgTheme(
      isDark ? atomOneDarkReasonableTheme : githubTheme,
    );
    final language = highlightLanguageFor(_language);
    final codeFontFamily = _resolveCodeFont();
    final textStyle = TextStyle(
      fontFamily: codeFontFamily,
      fontSize: _fontSize,
      height: 1.5,
      color: cs.onSurface,
    );
    final gutterStyle = textStyle.copyWith(
      color: cs.onSurface.withValues(alpha: 0.4),
    );

    final headerBg = cs.surfaceContainerHighest.withValues(
      alpha: _kCodeBlockFillAlpha,
    );
    final bodyBg = cs.surfaceContainer.withValues(alpha: _kCodeBlockFillAlpha);
    final borderColor = _codeBlockBorderColor(cs, isDark);
    final meta = document.usesPlainText
        ? formatBytes(document.byteLength)
        : '${l10n.workspacePreviewLineCount(lines.length)} · ${formatBytes(document.byteLength)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bodyBg,
          borderRadius: BorderRadius.circular(_kCodeBlockRadius),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kCodeBlockRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: headerBg,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              _displayLanguage,
                              key: CodeFilePreview.languageLabelKey,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: AppFontWeights.medium,
                                height: 1.0,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.72,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              meta,
                              key: CodeFilePreview.lineCountKey,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!document.usesPlainText)
                      _headerAction(
                        context,
                        key: CodeFilePreview.wrapToggleKey,
                        icon: Lucide.WrapText,
                        label: l10n.workspacePreviewWrap,
                        color: _wrap ? cs.primary : null,
                        onTap: () {
                          Haptics.light();
                          setState(() => _wrap = !_wrap);
                        },
                      ),
                    _headerAction(
                      context,
                      icon: Lucide.AArrowDown,
                      label: l10n.workspacePreviewFontDecrease,
                      enabled: _fontSize > _kMinFontSize,
                      onTap: () {
                        Haptics.light();
                        setState(
                          () => _fontSize = (_fontSize - 1).clamp(
                            _kMinFontSize,
                            _kMaxFontSize,
                          ),
                        );
                      },
                    ),
                    _headerAction(
                      context,
                      icon: Lucide.AArrowUp,
                      label: l10n.workspacePreviewFontIncrease,
                      enabled: _fontSize < _kMaxFontSize,
                      onTap: () {
                        Haptics.light();
                        setState(
                          () => _fontSize = (_fontSize + 1).clamp(
                            _kMinFontSize,
                            _kMaxFontSize,
                          ),
                        );
                      },
                    ),
                    if (widget.showCopyButton)
                      _headerAction(
                        context,
                        icon: Lucide.Copy,
                        label: l10n.workspacePreviewCopy,
                        enabled: !_copying,
                        onTap: () => unawaited(_copySource()),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: bodyBg,
                  child: document.usesPlainText
                      ? PagedTextFileView(
                          key: ObjectKey(document),
                          document: document,
                          style: textStyle,
                        )
                      : _SourceBody(
                          lines: lines,
                          language: language,
                          theme: theme,
                          textStyle: textStyle,
                          gutterStyle: gutterStyle,
                          wrap: _wrap,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerAction(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool enabled = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    final resolved =
        color ?? cs.onSurfaceVariant.withValues(alpha: enabled ? 0.5 : 0.28);
    return Tooltip(
      key: key,
      message: label,
      child: IosIconButton(
        icon: icon,
        semanticLabel: label,
        onTap: enabled ? onTap : null,
        enabled: enabled,
        size: 16,
        padding: const EdgeInsets.all(4),
        minSize: 44,
        color: resolved,
      ),
    );
  }
}

/// The whole file as one paragraph, with the line numbers as a second
/// paragraph beside it.
///
/// One paragraph is what makes a selection span lines: separate per-line
/// widgets cannot be selected across, and copying them back concatenates their
/// text without the line breaks. It also lets multi-line syntax (block
/// comments, template strings) highlight correctly, and it removes the need to
/// keep two scroll positions in sync.
class _SourceBody extends StatelessWidget {
  const _SourceBody({
    required this.lines,
    required this.language,
    required this.theme,
    required this.textStyle,
    required this.gutterStyle,
    required this.wrap,
  });

  final List<String> lines;
  final String language;
  final Map<String, TextStyle> theme;
  final TextStyle textStyle;
  final TextStyle gutterStyle;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final fontSize = textStyle.fontSize ?? _kDefaultFontSize;
    final gutterWidth = (lines.length.toString().length * fontSize * 0.62 + 16)
        .clamp(36.0, 80.0);
    // Forcing the strut pins every rendered line to fontSize * height. Without
    // it a line box takes the tallest run's ascent plus the tallest run's
    // descent, so a line mixing latin and CJK would outgrow the number beside
    // it and the two columns would drift apart.
    final strutStyle = StrutStyle.fromTextStyle(
      textStyle,
      forceStrutHeight: true,
    );
    final source = lines.join('\n');
    final spans = (language.isEmpty || language == 'plaintext')
        ? <InlineSpan>[TextSpan(text: source, style: textStyle)]
        : highlightSpans(source, language, theme, textStyle);
    final span = TextSpan(style: textStyle, children: spans);
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - gutterWidth).clamp(0.0, double.infinity)
            : double.infinity;
        final wrapWidth = wrap && available.isFinite
            ? (available - _kCodePadding.horizontal - _kCaretMargin).clamp(
                0.0,
                double.infinity,
              )
            : null;
        final code = Padding(
          padding: _kCodePadding,
          child: _column(
            span,
            key: CodeFilePreview.codeKey,
            style: textStyle,
            strutStyle: strutStyle,
          ),
        );
        return SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: gutterWidth,
                child: Padding(
                  padding: _kGutterPadding,
                  // Numbers are never selected, and never take a gesture: a
                  // drag anywhere over the file scrolls it.
                  child: IgnorePointer(
                    child: _column(
                      TextSpan(
                        text: _gutterLabels(
                          span: span,
                          lines: lines,
                          strutStyle: strutStyle,
                          textScaler: textScaler,
                          wrapWidth: wrapWidth,
                        ),
                        style: gutterStyle,
                      ),
                      key: CodeFilePreview.gutterKey,
                      style: gutterStyle,
                      strutStyle: strutStyle,
                      textAlign: TextAlign.right,
                      selectable: false,
                    ),
                  ),
                ),
              ),
              if (wrap)
                Expanded(child: code)
              else
                Expanded(
                  child: SingleChildScrollView(
                    key: CodeFilePreview.horizontalScrollKey,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: available),
                      child: code,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One column of the view, code or line numbers.
///
/// Both are the same widget even though only the code is ever selected:
/// RenderParagraph and RenderEditable round a forced-strut line box
/// differently - on iOS a 13px / 1.5 style measures 20.0 per line as a `Text`
/// and 19.0 as a `SelectableText` - so a `Text` gutter beside selectable code
/// drifts a pixel per line, which is a whole line every twenty.
Widget _column(
  TextSpan span, {
  required Key key,
  required TextStyle style,
  required StrutStyle strutStyle,
  TextAlign? textAlign,
  bool selectable = true,
}) {
  return SelectableText.rich(
    span,
    key: key,
    style: style,
    strutStyle: strutStyle,
    textAlign: textAlign,
    cursorWidth: _kCursorWidth,
    enableInteractiveSelection: selectable,
    // The column is laid out in full inside the scroll views around it, so its
    // own viewport must not swallow their drags.
    scrollPhysics: const NeverScrollableScrollPhysics(),
  );
}

/// Line numbers as one paragraph, one label per rendered line.
///
/// Unwrapped that is one label per source line. When wrapping, a source line
/// can occupy several rendered lines, so its number is followed by as many
/// blank lines as the code beside it takes; laying the code out here with the
/// styled spans and the width it is rendered at is what keeps the two columns
/// on the same rows.
String _gutterLabels({
  required TextSpan span,
  required List<String> lines,
  required StrutStyle strutStyle,
  required TextScaler textScaler,
  required double? wrapWidth,
}) {
  String plainLabels() =>
      <String>[for (var i = 1; i <= lines.length; i++) '$i'].join('\n');
  if (wrapWidth == null) return plainLabels();

  final painter = TextPainter(
    text: span,
    strutStyle: strutStyle,
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout(maxWidth: wrapWidth);
  final metrics = painter.computeLineMetrics();
  // Every rendered line is the strut's height, so a caret offset divided by it
  // is the row that offset sits on.
  final lineHeight = metrics.isEmpty ? 0.0 : metrics.first.height;
  if (lineHeight <= 0) {
    painter.dispose();
    return plainLabels();
  }

  final buffer = StringBuffer();
  var offset = 0;
  var previousRow = 0;
  for (var i = 0; i < lines.length; i++) {
    final caret = painter.getOffsetForCaret(
      TextPosition(offset: offset),
      Rect.zero,
    );
    final row = (caret.dy / lineHeight).round();
    if (i > 0) buffer.write('\n' * math.max(1, row - previousRow));
    buffer.write('${i + 1}');
    previousRow = row;
    offset += lines[i].length + 1; // + the line break
  }
  painter.dispose();
  return buffer.toString();
}

List<InlineSpan> highlightSpans(
  String source,
  String language,
  Map<String, TextStyle> theme,
  TextStyle base,
) {
  try {
    final result = highlight.parse(source, language: language);
    final nodes = result.nodes;
    if (nodes == null || nodes.isEmpty) {
      return <InlineSpan>[TextSpan(text: source, style: base)];
    }
    return _convertHighlightNodes(nodes, theme, base);
  } catch (_) {
    return <InlineSpan>[TextSpan(text: source, style: base)];
  }
}

List<InlineSpan> _convertHighlightNodes(
  List<Node> nodes,
  Map<String, TextStyle> theme,
  TextStyle base,
) {
  final spans = <InlineSpan>[];
  for (final node in nodes) {
    final style = node.className == null
        ? base
        : base.merge(theme[node.className]);
    final value = node.value;
    if (value != null) {
      spans.add(TextSpan(text: value, style: style));
    } else if (node.children != null) {
      spans.addAll(_convertHighlightNodes(node.children!, theme, style));
    }
  }
  return spans;
}

Map<String, TextStyle> _transparentBgTheme(Map<String, TextStyle> base) {
  final m = Map<String, TextStyle>.from(base);
  final root = base['root'];
  if (root != null) {
    m['root'] = root.copyWith(backgroundColor: Colors.transparent);
  } else {
    m['root'] = const TextStyle(backgroundColor: Colors.transparent);
  }
  return m;
}

Color _codeBlockBorderColor(ColorScheme cs, bool isDark) {
  final outlineVariant = cs.outlineVariant;
  final isExtreme =
      outlineVariant == Colors.black || outlineVariant == Colors.white;
  if (!isExtreme) return outlineVariant;
  return Color.alphaBlend(
    cs.onSurfaceVariant.withValues(alpha: isDark ? 0.32 : 0.24),
    cs.surface,
  );
}
