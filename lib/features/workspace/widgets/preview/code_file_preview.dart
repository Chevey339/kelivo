import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/themes/atom-one-dark-reasonable.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:highlight/highlight.dart' show Node, highlight;
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/utils/format_bytes.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

import 'preview_actions.dart';
import 'preview_file_type.dart';
import 'preview_states.dart';

export 'preview_file_type.dart'
    show highlightLanguageFor, languageForExtension, languageForPath;

/// Matches chat `_CollapsibleCodeBlock` chrome (fill alpha + 16 radius).
const double _kCodeBlockFillAlpha = 0.80;
const double _kCodeBlockRadius = 16;
const double _kMinFontSize = 11;
const double _kMaxFontSize = 20;
const double _kDefaultFontSize = 13;
const EdgeInsets _kGutterListPadding = EdgeInsets.fromLTRB(0, 8, 8, 12);
const EdgeInsets _kCodeListPadding = EdgeInsets.fromLTRB(12, 8, 12, 12);

class CodeFilePreview extends StatefulWidget {
  const CodeFilePreview({
    super.key,
    required this.file,
    this.maxBytes = defaultMaxBytes,
    this.virtualizeAfterLines = defaultVirtualizeAfterLines,
    this.showCopyButton = true,
    this.autoLoad = true,
    this.language,
  });

  static const int defaultMaxBytes = 2 * 1024 * 1024;
  static const int defaultVirtualizeAfterLines = 1000;
  static const Key tooLargeKey = ValueKey<String>(
    'code-file-preview-too-large',
  );
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

  final File file;
  final int maxBytes;
  final int virtualizeAfterLines;
  final bool showCopyButton;
  final bool autoLoad;

  /// Highlight / header language. When null, derived from the file extension.
  final String? language;

  @override
  CodeFilePreviewState createState() => CodeFilePreviewState();
}

class CodeFilePreviewState extends State<CodeFilePreview> {
  bool _loading = true;
  bool _tooLarge = false;
  bool _failed = false;
  bool _wrap = false;
  double _fontSize = _kDefaultFontSize;
  String _source = '';
  int _fileSize = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(load());
      });
    }
  }

  @override
  void didUpdateWidget(covariant CodeFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.maxBytes != widget.maxBytes) {
      setState(() {
        _loading = true;
        _tooLarge = false;
        _failed = false;
        _source = '';
        _fileSize = 0;
      });
      if (widget.autoLoad) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(load());
        });
      }
    }
  }

  @visibleForTesting
  Future<void> load() async {
    assert(widget.virtualizeAfterLines >= 0);
    try {
      final length = widget.file.lengthSync();
      if (length > widget.maxBytes) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _tooLarge = true;
          _failed = false;
          _fileSize = length;
        });
        return;
      }
      final source = utf8.decode(
        widget.file.readAsBytesSync(),
        allowMalformed: true,
      );
      if (!mounted) return;
      setState(() {
        _source = source;
        _fileSize = length;
        _loading = false;
        _tooLarge = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _source = '';
        _loading = false;
        _tooLarge = false;
        _failed = true;
      });
    }
  }

  List<String> get _lines {
    if (_source.isEmpty) return const <String>[''];
    return _source.split(RegExp(r'\r\n|\r|\n'));
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
    await Clipboard.setData(ClipboardData(text: _source));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: l10n.chatMessageWidgetCopiedToClipboard,
      type: NotificationType.success,
    );
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
    if (_tooLarge) {
      return _TooLargeState(file: widget.file);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lines = _lines;
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
    final meta =
        '${l10n.workspacePreviewLineCount(lines.length)} · ${formatBytes(_fileSize)}';

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
                        onTap: () => unawaited(_copySource()),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: bodyBg,
                  child: _VirtualizedSource(
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

class _TooLargeState extends StatelessWidget {
  const _TooLargeState({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final desktop = ResponsiveHelper.isDesktop(context);
    return Center(
      key: CodeFilePreview.tooLargeKey,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.workspacePreviewFileTooLarge,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 340;
                  final primary = IosTileButton(
                    icon: desktop ? Lucide.FolderOpen : Lucide.ExternalLink,
                    label: desktop
                        ? revealInFileManagerLabel(l10n)
                        : l10n.workspacePreviewOpen,
                    backgroundColor: cs.primary,
                    onTap: () {
                      if (desktop) {
                        unawaited(
                          revealPreviewFileInFileManager(context, file),
                        );
                      } else {
                        unawaited(openPreviewFileExternally(context, file));
                      }
                    },
                  );
                  final secondary = IosTileButton(
                    icon: desktop ? Lucide.ExternalLink : Lucide.Share2,
                    label: desktop
                        ? l10n.workspacePreviewOpenInSystemApp
                        : l10n.workspacePreviewShare,
                    onTap: () {
                      if (desktop) {
                        unawaited(openPreviewFileExternally(context, file));
                      } else {
                        unawaited(sharePreviewFile(context, file));
                      }
                    },
                  );
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [primary, const SizedBox(height: 8), secondary],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: primary),
                      const SizedBox(width: 8),
                      Expanded(child: secondary),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VirtualizedSource extends StatefulWidget {
  const _VirtualizedSource({
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
  State<_VirtualizedSource> createState() => _VirtualizedSourceState();
}

class _VirtualizedSourceState extends State<_VirtualizedSource> {
  late final ScrollController _codeCtrl;
  late final ScrollController _gutterCtrl;

  @override
  void initState() {
    super.initState();
    _codeCtrl = ScrollController();
    _gutterCtrl = ScrollController();
    _codeCtrl.addListener(_syncGutterToCode);
  }

  @override
  void dispose() {
    _codeCtrl.removeListener(_syncGutterToCode);
    _codeCtrl.dispose();
    _gutterCtrl.dispose();
    super.dispose();
  }

  void _syncGutterToCode() {
    if (!_codeCtrl.hasClients || !_gutterCtrl.hasClients) return;
    final target = _codeCtrl.offset.clamp(
      0.0,
      _gutterCtrl.position.maxScrollExtent,
    );
    if (_gutterCtrl.offset != target) {
      _gutterCtrl.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.textStyle.fontSize ?? _kDefaultFontSize;
    final gutterWidth =
        (widget.lines.length.toString().length * fontSize * 0.62 + 16).clamp(
          36.0,
          80.0,
        );
    if (widget.wrap) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 12, 12),
        itemCount: widget.lines.length,
        itemBuilder: (context, index) {
          return _CodeLine(
            index: index,
            text: widget.lines[index],
            language: widget.language,
            theme: widget.theme,
            textStyle: widget.textStyle,
            gutterStyle: widget.gutterStyle,
            gutterWidth: gutterWidth,
            wrap: true,
          );
        },
      );
    }

    final maxLineWidth = _measureWidestLine(
      widget.lines,
      widget.textStyle,
      MediaQuery.textScalerOf(context),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - gutterWidth).clamp(0.0, double.infinity)
            : maxLineWidth;
        final codeWidth = maxLineWidth + _kCodeListPadding.horizontal;
        final width = codeWidth > available ? codeWidth : available;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: gutterWidth,
              child: IgnorePointer(
                child: ListView.builder(
                  controller: _gutterCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: _kGutterListPadding,
                  itemCount: widget.lines.length,
                  itemBuilder: (context, index) {
                    return _GutterLine(index: index, style: widget.gutterStyle);
                  },
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: CodeFilePreview.horizontalScrollKey,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: ListView.builder(
                    controller: _codeCtrl,
                    padding: _kCodeListPadding,
                    itemCount: widget.lines.length,
                    itemBuilder: (context, index) {
                      return _CodeLine(
                        index: index,
                        text: widget.lines[index],
                        language: widget.language,
                        theme: widget.theme,
                        textStyle: widget.textStyle,
                        gutterStyle: widget.gutterStyle,
                        gutterWidth: gutterWidth,
                        wrap: false,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Width of the widest rendered line. Laying out the whole text once with an
/// unbounded width yields the widest line directly, so CJK and other
/// double-width glyphs are measured instead of guessed from code-unit counts.
double _measureWidestLine(
  List<String> lines,
  TextStyle textStyle,
  TextScaler textScaler,
) {
  final painter = TextPainter(
    text: TextSpan(text: lines.join('\n'), style: textStyle),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();
  // Unlike `width`, the intrinsic width keeps trailing whitespace, which the
  // per-line text below still occupies.
  final width = painter.maxIntrinsicWidth;
  painter.dispose();
  // SelectableText.rich is a few pixels wider than a bare TextPainter.
  return width + 32;
}

class _CodeLine extends StatelessWidget {
  const _CodeLine({
    required this.index,
    required this.text,
    required this.language,
    required this.theme,
    required this.textStyle,
    required this.gutterStyle,
    required this.gutterWidth,
    required this.wrap,
  });

  final int index;
  final String text;
  final String language;
  final Map<String, TextStyle> theme;
  final TextStyle textStyle;
  final TextStyle gutterStyle;
  final double gutterWidth;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final spans = (language.isEmpty || language == 'plaintext')
        ? <InlineSpan>[TextSpan(text: text, style: textStyle)]
        : highlightSpans(text, language, theme, textStyle);
    final body = SelectableText.rich(
      TextSpan(style: textStyle, children: spans),
      style: textStyle,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: wrap
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: gutterWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${index + 1}',
                      textAlign: TextAlign.right,
                      style: gutterStyle,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: body),
              ],
            )
          : OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              fit: OverflowBoxFit.deferToChild,
              child: body,
            ),
    );
  }
}

class _GutterLine extends StatelessWidget {
  const _GutterLine({required this.index, required this.style});

  final int index;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text('${index + 1}', textAlign: TextAlign.right, style: style),
    );
  }
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
