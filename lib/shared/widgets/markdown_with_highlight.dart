import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:gpt_markdown/custom_widgets/markdown_config.dart'
    show GptMarkdownConfig;
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/atom-one-dark-reasonable.dart';
import 'package:flutter/rendering.dart';
import 'package:highlight/highlight.dart' show Node, highlight;
import '../../icons/lucide_adapter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../utils/sandbox_path_resolver.dart';
import '../../utils/clipboard_images.dart';
import '../../features/chat/pages/image_viewer_page.dart';
import '../../features/chat/pages/html_preview_page.dart';
import 'snackbar.dart';
import 'ios_tactile.dart';
import 'mermaid_bridge.dart';
import 'export_capture_scope.dart';
import 'mermaid_image_cache.dart';
import 'plantuml_block.dart';
import 'package:path/path.dart' as p;
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/theme_factory.dart' show getPlatformFontFallback;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/html_preview_dialog.dart';

// Inline math is parsed on the UI thread. Bound the lookahead window so a long
// line with many unmatched openers cannot trigger repeated whole-line scans.
const int _maxInlineMathBodyLength = 512;
const String _codeDollarMask = '___CODE_DOLLAR_MASK___';

/// gpt_markdown with custom code block highlight and inline code styling.
class MarkdownWithCodeHighlight extends StatefulWidget {
  const MarkdownWithCodeHighlight({
    super.key,
    required this.text,
    this.onCitationTap,
    this.baseStyle,
    this.streaming = false,
  });

  final String text;
  final void Function(String id)? onCitationTap;
  final TextStyle? baseStyle; // optional override for base markdown text style
  final bool streaming;

  static const int _streamingTableMaxRows = 30;
  static const int _streamingHighlightMaxLines = 300;
  static const int _streamingHighlightMaxChars = 12000;

  // Tunable: list scaling compensation exponent.
  // When chat scale s != 1.0, lists often feel slightly off compared to body.
  // We apply s^(1-k) instead of s to the list rows to gently normalize.
  // Increase k if lists still look larger at small scales; decrease if too small at large scales.
  static const double kMarkdownListScaleCompensation = 0.84;

  @override
  State<MarkdownWithCodeHighlight> createState() =>
      _MarkdownWithCodeHighlightState();
}

class _MarkdownWithCodeHighlightState extends State<MarkdownWithCodeHighlight> {
  static const int _streamingDebounceThresholdChars = 8000;
  static const Duration _streamingLongRenderDebounce = Duration(
    milliseconds: 120,
  );

  late String _renderText;
  Timer? _renderDebounce;

  @override
  void initState() {
    super.initState();
    _renderText = widget.text;
  }

  @override
  void didUpdateWidget(covariant MarkdownWithCodeHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text &&
        oldWidget.streaming == widget.streaming) {
      return;
    }
    _syncRenderText();
  }

  @override
  void dispose() {
    _renderDebounce?.cancel();
    super.dispose();
  }

  void _syncRenderText() {
    if (!widget.streaming ||
        widget.text.length < _streamingDebounceThresholdChars ||
        widget.text.length < _renderText.length) {
      _renderDebounce?.cancel();
      _renderDebounce = null;
      _renderText = widget.text;
      return;
    }
    if (_renderDebounce?.isActive ?? false) return;
    _renderDebounce = Timer(_streamingLongRenderDebounce, () {
      if (!mounted) return;
      setState(() => _renderText = widget.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    final sanitizedText = _sanitizeImageLinks(_renderText);
    final imageUrls = _extractImageUrls(sanitizedText);
    final normalized = _preprocessFences(
      sanitizedText,
      enableMath: settings.enableMathRendering,
      enableDollarLatex: settings.enableDollarLatex,
      streaming: widget.streaming,
    );
    // Base text style (can be overridden by caller)
    final baseTextStyle =
        (widget.baseStyle ?? Theme.of(context).textTheme.bodyMedium)?.copyWith(
          fontSize: widget.baseStyle?.fontSize ?? 15.5,
          height: widget.baseStyle?.height ?? 1.55,
          letterSpacing:
              widget.baseStyle?.letterSpacing ?? (_isZh(context) ? 0.0 : 0.05),
          color: null,
        );

    // Replace default components and add our own where needed
    final components = List<MarkdownComponent>.from(
      MarkdownComponent.globalComponents,
    );
    components.removeWhere((c) => c is LatexMathMultiLine);
    final hrIdx = components.indexWhere((c) => c is HrLine);
    if (hrIdx != -1) components[hrIdx] = SoftHrLine();
    components.removeWhere((c) => c is BlockQuote);
    final cbIdx = components.indexWhere((c) => c is CheckBoxMd);
    if (cbIdx != -1) components[cbIdx] = ModernCheckBoxMd();
    final rbIdx = components.indexWhere((c) => c is RadioButtonMd);
    if (rbIdx != -1) components[rbIdx] = ModernRadioMd();
    final tableIdx = components.indexWhere((c) => c is TableMd);
    if (tableIdx != -1) components[tableIdx] = EscapeAwareTableMd();
    // Prepend custom renderers in priority order (fence first)
    // Temporarily disable custom bold label line transformer to avoid
    // interfering with block parsing for complex documents.
    // components.insert(0, LabelValueLineMd());
    components.removeWhere((c) => c is CodeBlockMd);
    // Conditionally add LaTeX/math renderers
    if (settings.enableMathRendering) {
      // Block-level LaTeX (e.g., $$...$$ or \[...\])
      components.insert(0, LatexBlockScrollableMd());
    }
    components.insert(0, AtxHeadingMd());
    // Ensure fenced code blocks take precedence over headings and other blocks
    // so lines like "# comment" inside code fences are not parsed as headings.
    components.insert(0, ModernBlockQuote());
    components.insert(0, FencedCodeBlockMd(streaming: widget.streaming));
    components.insert(0, DetailsHtmlMd());
    // Inline components: keep defaults but make link parsing line-scoped
    final inlineComponents = List<MarkdownComponent>.from(
      MarkdownComponent.inlineComponents,
    );
    inlineComponents.removeWhere(
      (c) => c is LatexMath || c is LatexMathMultiLine,
    );
    // Add whitelist-based HTML tag renderer (e.g., <br>)
    inlineComponents.insert(0, HtmlAnchorMd());
    inlineComponents.insert(0, AllowedHtmlTagsMd());

    // Conditionally add inline LaTeX/math renderers
    if (settings.enableMathRendering) {
      // Inline LaTeX: $...$ and \(...\)
      if (settings.enableDollarLatex) {
        inlineComponents.insert(0, InlineLatexParenScrollableMd());
        inlineComponents.insert(0, InlineLatexDollarScrollableMd());
      } else {
        // Only \(...\) inline
        inlineComponents.insert(0, InlineLatexParenScrollableMd());
      }
    }

    final boldIdxInline = inlineComponents.indexWhere((c) => c is BoldMd);
    if (boldIdxInline != -1) {
      inlineComponents[boldIdxInline] = EscapeAwareBoldMd();
    }
    final italicIdxInline = inlineComponents.indexWhere((c) => c is ItalicMd);
    if (italicIdxInline != -1) {
      inlineComponents[italicIdxInline] = EscapeAwareItalicMd();
    }
    final imageIdxInline = inlineComponents.indexWhere((c) => c is ImageMd);
    if (imageIdxInline != -1) {
      inlineComponents[imageIdxInline] = EscapeAwareImageMd();
    }
    final codeIdxInline = inlineComponents.indexWhere(
      (c) => c is HighlightedText,
    );
    if (codeIdxInline != -1) {
      inlineComponents[codeIdxInline] = EscapeAwareHighlightedTextMd();
    }
    final linkIdxInline = inlineComponents.indexWhere((c) => c is ATagMd);
    if (linkIdxInline != -1) {
      inlineComponents[linkIdxInline] = LineSafeLinkMd();
    }
    // Keep escaped punctuation out of block parsing so it cannot split
    // \( ... \) math containing \{...\}; inline math is registered ahead of it.
    inlineComponents.add(BackslashEscapeMd());
    // codeBuilder handles rendering. A custom BlockMd for fences can
    // interfere with block segmentation in some cases.
    // Resolve user preferred code font family (default to monospace)
    String resolveCodeFont() {
      final fam = settings.codeFontFamily;
      if (fam == null || fam.isEmpty) return 'monospace';
      if (settings.codeFontIsGoogle) {
        try {
          final s = GoogleFonts.getFont(fam);
          return s.fontFamily ?? fam;
        } catch (_) {
          return fam;
        }
      }
      return fam;
    }

    final codeFontFamily = resolveCodeFont();

    // Resolve app font for all markdown text (headings, lists, etc.)
    String resolveAppFont() {
      final fam = settings.appFontFamily;
      if (fam == null || fam.isEmpty) return '';
      if (settings.appFontIsGoogle) {
        try {
          final s = GoogleFonts.getFont(fam);
          return s.fontFamily ?? fam;
        } catch (_) {
          return fam;
        }
      }
      return fam;
    }

    final appFontFamily = resolveAppFont();

    // Force rebuild of the markdown when key theme colors change to avoid stale styles
    final markdownWidget = GptMarkdown(
      key: ValueKey(
        '${Theme.of(context).brightness.index}-${cs.surface.toARGB32()}-${cs.onSurface.toARGB32()}-${cs.primary.toARGB32()}-${cs.outlineVariant.toARGB32()}-${settings.enableMathRendering}-${settings.enableDollarLatex}',
      ),
      normalized,
      style: baseTextStyle,
      followLinkColor: true,
      // Disable built-in $...$ LaTeX so our custom scrollable handlers take over
      useDollarSignsForLatex: false,
      onLinkTap: (url, title) => _handleLinkTap(context, url),
      components: components,
      inlineComponents: inlineComponents,
      imageBuilder: (ctx, url, width, height) {
        final imgs = imageUrls.isNotEmpty ? imageUrls : <String>[url];
        final idx = imgs.indexOf(url);
        final initial = idx >= 0 ? idx : 0;
        final provider = _imageProviderFor(url);
        return GestureDetector(
          onTap: () {
            Navigator.of(ctx).push(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) =>
                    ImageViewerPage(images: imgs, initialIndex: initial),
                transitionDuration: const Duration(milliseconds: 360),
                reverseTransitionDuration: const Duration(milliseconds: 280),
                transitionsBuilder: (context, anim, sec, child) {
                  final curved = CurvedAnimation(
                    parent: anim,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
              ),
            );
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: () {
                  if (provider == null) {
                    // Missing or unsupported source: show a broken image indicator
                    return const Icon(Icons.broken_image);
                  }
                  return Image(
                    image: provider,
                    width: width ?? constraints.maxWidth,
                    height: height,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.broken_image),
                  );
                }(),
              );
            },
          ),
        );
      },
      linkBuilder: (ctx, span, url, style) {
        final label = span.toPlainText().trim();
        // Special handling: [citation](index:id)
        if (label.toLowerCase() == 'citation') {
          final citation = _parseCitationRef(url);
          if (citation != null) {
            final cs = Theme.of(ctx).colorScheme;
            return GestureDetector(
              onTap: () {
                if (widget.onCitationTap != null && citation.id.isNotEmpty) {
                  widget.onCitationTap!(citation.id);
                } else {
                  // Fallback: do nothing
                }
              },
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  citation.indexText,
                  style: TextStyle(fontSize: 12, height: 1.0),
                ),
              ),
            );
          }
        }
        // Default link appearance
        final cs = Theme.of(ctx).colorScheme;
        return Text(
          span.toPlainText(),
          style: style.copyWith(
            color: cs.primary,
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.start,
        );
      },
      orderedListBuilder: (ctx, no, child, cfg) {
        final style = (cfg.style ?? TextStyle()).copyWith(
          fontWeight: AppFontWeights.regular,
        );
        // Apply a soft compensation so when chat scale != 100%,
        // list items don't visually feel larger/smaller than body text.
        final double kListComp =
            MarkdownWithCodeHighlight.kMarkdownListScaleCompensation;
        final mediaQuery = MediaQuery.of(ctx);
        final double s = mediaQuery.textScaler.scale(1);
        final double comp = math.pow(s == 0 ? 1.0 : s, -kListComp).toDouble();
        final double newScale = (s * comp).clamp(0.5, 3.0);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.linear(newScale)),
          child: Directionality(
            textDirection: cfg.textDirection,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textBaseline: TextBaseline.alphabetic,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6, end: 6),
                  child: Text("$no.", style: style),
                ),
                // Keep child as-is so it inherits context MediaQuery scaling once
                Flexible(child: child),
              ],
            ),
          ),
        );
      },
      // Note: property name is unOrderedListBuilder (camel-cased with capital O)
      // Signature in gpt_markdown 1.1.4: (BuildContext ctx, Widget child, GptMarkdownConfig cfg) -> Widget
      // We compose the bullet + content here to control scaling/spacing.
      unOrderedListBuilder: (ctx, child, cfg) {
        final style = (cfg.style ?? TextStyle()).copyWith(
          fontWeight: AppFontWeights.regular,
        );
        final double kListComp =
            MarkdownWithCodeHighlight.kMarkdownListScaleCompensation;
        final mediaQuery = MediaQuery.of(ctx);
        final double s = mediaQuery.textScaler.scale(1);
        final double comp = math.pow(s == 0 ? 1.0 : s, -kListComp).toDouble();
        final double newScale = (s * comp).clamp(0.5, 3.0);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.linear(newScale)),
          child: Directionality(
            textDirection: cfg.textDirection,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textBaseline: TextBaseline.alphabetic,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6, end: 6),
                  child: Text('•', style: style),
                ),
                // Keep child untouched to follow context scaling exactly once
                Flexible(child: child),
              ],
            ),
          ),
        );
      },
      tableBuilder: (ctx, rows, style, cfg) {
        return _MarkdownTableBlock(
          rows: _MarkdownTableData.fromRows(
            rows,
            maxBodyRows: widget.streaming
                ? MarkdownWithCodeHighlight._streamingTableMaxRows
                : null,
          ),
          style: style,
          config: cfg,
          appFontFamily: appFontFamily.isEmpty ? null : appFontFamily,
        );
      },
      // Inline `code` styling via highlightBuilder in gpt_markdown
      highlightBuilder: (ctx, inline, style) {
        // Unmask dollar signs that were protected during preprocessing
        String unmasked = inline.replaceAll(_codeDollarMask, r'$');
        String softened = _softBreakInline(unmasked);
        final bool isDarkCtx = Theme.of(ctx).brightness == Brightness.dark;
        final csCtx = Theme.of(ctx).colorScheme;
        final bg = isDarkCtx ? Colors.white12 : const Color(0xFFF1F3F5);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: csCtx.outlineVariant.withValues(alpha: 0.22),
            ),
          ),
          child: Text(
            softened,
            style: TextStyle(
              fontFamily: codeFontFamily,
              fontSize: 13,
              height: 1.4,
            ).copyWith(color: csCtx.onSurface),
            softWrap: true,
            overflow: TextOverflow.visible,
          ),
        );
      },
      // Fenced code block styling via codeBuilder (with collapse/expand)
      codeBuilder: (ctx, name, code, closed) {
        final lang = name.trim();
        if (lang.toLowerCase() == 'mermaid') {
          return _MermaidBlock(
            code: code,
            streaming: widget.streaming && !closed,
          );
        } else if (lang.toLowerCase() == 'plantuml') {
          return PlantUMLBlock(code: code);
        }
        return _CollapsibleCodeBlock(
          language: lang,
          code: code,
          streaming: widget.streaming,
          closed: closed,
        );
      },
    );

    final result = appFontFamily.isEmpty
        ? markdownWidget
        : DefaultTextStyle.merge(
            style: TextStyle(fontFamily: appFontFamily),
            child: markdownWidget,
          );
    return result;
  }

  Future<void> _handleLinkTap(BuildContext context, String url) async {
    Uri uri;
    try {
      uri = _normalizeUrl(url);
    } catch (_) {
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.chatMessageWidgetCannotOpenUrl(url),
        type: NotificationType.error,
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.chatMessageWidgetOpenLinkError,
        type: NotificationType.error,
      );
    }
  }

  Uri _normalizeUrl(String url) {
    var u = url.trim();
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(u)) {
      u = 'https://$u';
    }
    return Uri.parse(u);
  }
}

String _displayLanguage(BuildContext context, String? raw) {
  final zh = _isZh(context);
  final t = raw?.trim();
  if (t != null && t.isNotEmpty) return t;
  return zh ? '代码' : 'Code';
}

bool _isZh(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'zh';

Map<String, TextStyle> _transparentBgTheme(Map<String, TextStyle> base) {
  final m = Map<String, TextStyle>.from(base);
  final root = base['root'];
  if (root != null) {
    m['root'] = root.copyWith(backgroundColor: Colors.transparent);
  } else {
    m['root'] = TextStyle(backgroundColor: Colors.transparent);
  }
  return m;
}

String? _normalizeLanguage(String? lang) {
  if (lang == null || lang.trim().isEmpty) return null;
  final l = lang.trim().toLowerCase();
  switch (l) {
    case 'js':
    case 'javascript':
      return 'javascript';
    case 'ts':
    case 'typescript':
      return 'typescript';
    case 'sh':
    case 'zsh':
    case 'bash':
    case 'shell':
      return 'bash';
    case 'yml':
      return 'yaml';
    case 'py':
    case 'python':
      return 'python';
    case 'rb':
    case 'ruby':
      return 'ruby';
    case 'kt':
    case 'kotlin':
      return 'kotlin';
    case 'java':
      return 'java';
    case 'c#':
    case 'cs':
    case 'csharp':
      return 'csharp';
    case 'objc':
    case 'objectivec':
      return 'objectivec';
    case 'swift':
      return 'swift';
    case 'go':
    case 'golang':
      return 'go';
    case 'php':
      return 'php';
    case 'dart':
      return 'dart';
    case 'json':
      return 'json';
    case 'html':
      return 'xml';
    case 'md':
    case 'markdown':
      return 'markdown';
    case 'sql':
      return 'sql';
    default:
      return l; // try as-is
  }
}

String _preprocessFences(
  String input, {
  required bool enableMath,
  required bool enableDollarLatex,
  bool streaming = false,
}) {
  // Normalize newlines to simplify regex handling
  var out = input.replaceAll('\r\n', '\n');
  out = _maskBlockquoteFenceMarkers(out);

  // Move fenced code from list lines to the next line before masking so list
  // fences are protected from later inline math normalization.
  final bulletFence = RegExp(
    r"^(\s*(?:[*+-]|\d+\.)\s+)```([^\s`]*)\s*$",
    multiLine: true,
  );
  out = out.replaceAllMapped(bulletFence, (m) => "${m[1]}\n```${m[2]}");

  // STEP 1: MASKING - Protect code blocks from LaTeX processing
  // This prevents $...$ inside code from being converted to LaTeX
  final Map<String, String> codeMap = {};
  int codeCount = 0;

  // Match fenced code blocks and inline code (`...`)
  // Fenced: CommonMark-style variable-length fences (>= 3 backticks or tildes)
  // Group 1: entire fenced block, Group 2: opening fence, Group 3: fence char
  // Closing fence must use same char and be >= opening length
  final codeRegex = RegExp(
    r'(^[ \t]*(([`~])\3{2,})[ \t]*[^\n]*\n(?:[\s\S]*?^[ \t]*\2\3*[ \t]*$|[\s\S]*))'
    r'|(`[^`\n]+`)',
    multiLine: true,
  );

  out = out.replaceAllMapped(codeRegex, (match) {
    final key = '__CODE_MASK_${codeCount++}__';
    var codeContent = match.group(0)!;

    // For inline code (`...`), escape dollar signs to prevent LaTeX interpretation
    // Inline code is single-line and delimited by single backticks (not fenced)
    final isInlineCode =
        !codeContent.contains('\n') &&
        codeContent.startsWith('`') &&
        codeContent.endsWith('`');
    if (isInlineCode) {
      codeContent = codeContent.replaceAllMapped(
        RegExp(r'\$'),
        (m) => _codeDollarMask,
      );
    }

    codeMap[key] = codeContent;
    return key;
  });

  // STEP 2: PROCESSING (on masked string, code is now protected)
  if (streaming) {
    out = _stabilizeStreamingTables(out);
    if (enableMath && enableDollarLatex) {
      out = _stabilizeStreamingDollarMath(out);
    }
  }

  // Keep HTML paragraph breaks stable: </p> emits one line break, and
  // one preserved source newline gives a single visual blank line.
  out = out.replaceAllMapped(
    RegExp(r"<\/p\s*>\s*\n\s*\n\s*", caseSensitive: false),
    (_) => '</p>\n',
  );
  out = out.replaceAllMapped(
    RegExp(r"<\/p\s*>(?=<p(?:\s+[^>]*)?>)", caseSensitive: false),
    (_) => '</p>\n',
  );

  // 2025-10-23 Fix: Remove title attributes from markdown links to work around gpt_markdown's
  // link regex limitation. The package's regex `[^\s]*` stops at spaces, so
  // [text](url "title") breaks. Strip titles while preserving the URL.
  // Matches: [text](url "title") or [text](url 'title') or [text](url title)
  final linkWithTitle = RegExp(r'\[([^\]]+)\]\(([^\s)]+)\s+[^)]*\)');
  out = out.replaceAllMapped(linkWithTitle, (match) {
    final text = match.group(1);
    final url = match.group(2);
    return '[$text]($url)';
  });
  out = _normalizeRawCitationMetadata(out);

  // Normalize inline $...$ math into \( ... \) so it always matches the LaTeX
  // renderer (even when vendors emit single-dollar math mixed with prose).
  // Skips $$...$$ blocks, which are handled separately.
  // NOW SAFE: Code blocks are masked, so $variables in code won't be converted.
  if (enableMath && enableDollarLatex) {
    out = _replaceInlineDollarMath(out);
  }

  // Ensure display-math blocks stay as standalone blocks even when generated inline.
  // Some providers emit "$$...$$" inside list items or paragraphs; without extra
  // newlines gpt_markdown may treat them as plain text. We normalize multi-line
  // display math into its own block to guarantee rendering.
  final inlineDisplayMath = RegExp(r"\$\$([\s\S]*?)\$\$");
  out = out.replaceAllMapped(inlineDisplayMath, (m) {
    final body = (m.group(1) ?? '').trim();
    // Only normalize true display math (multi-line or clearly not inline literals)
    if (body.isEmpty) {
      return m[0]!;
    }
    final hasNewline = body.contains('\n');
    if (!hasNewline && body.length < 12) {
      return m[0]!; // looks like inline literal, leave intact
    }
    // Surround with blank lines to force a block; keep existing body trimmed
    final prefix = m.start == 0 || out.substring(0, m.start).endsWith('\n\n')
        ? ''
        : '\n';
    final suffix =
        m.end == out.length || out.substring(m.end).startsWith('\n\n')
        ? ''
        : '\n';
    return '$prefix\$\$\n$body\n\$\$$suffix';
  });

  // 2) Dedent opening fences: leading spaces before ```lang
  final dedentOpen = RegExp(r"^[ \t]+```([^\n`]*)\s*$", multiLine: true);
  out = out.replaceAllMapped(dedentOpen, (m) => "```${m[1]}");

  // 3) Dedent closing fences: leading spaces before ```
  final dedentClose = RegExp(r"^[ \t]+```\s*$", multiLine: true);
  out = out.replaceAllMapped(dedentClose, (m) => "```");

  // 4) Ensure closing fences are on their own line: transform "} ```" or "}```" into "}\n```"
  final inlineClosing = RegExp(r"([^\r\n`])```(?=\s*(?:\r?\n|$))");
  out = out.replaceAllMapped(inlineClosing, (m) => "${m[1]}\n```");

  // 5) Disambiguate Setext vs HR after label-value lines:
  // If a line of only dashes follows a bold label line (e.g., "**作者:** 张三"),
  // insert a blank line so it's treated as an HR, not a Setext heading underline.
  final labelThenDash = RegExp(
    r"^(\*\*[^\n*]+\*\*.*)\n(\s*-{3,}\s*$)",
    multiLine: true,
  );
  out = out.replaceAllMapped(labelThenDash, (m) => "${m[1]}\n\n${m[2]}");

  // 6) Allow ATX headings starting with enumerations like "## 1.引言" or "## 1. 引言"
  // Insert a zero-width non-joiner after the dot to prevent list parsing without changing visual text.
  final atxEnum = RegExp(r"^(\s{0,3}#{1,6}\s+\d+)\.(\s*)(\S)", multiLine: true);
  out = out.replaceAllMapped(atxEnum, (m) => "${m[1]}.\u200C${m[2]}${m[3]}");

  // 7) Normalize double-bracket citation links: [[n]](url) → [n](url)
  //    Many LLMs with built-in web search (DashScope, Perplexity, etc.) emit
  //    citations as [[1]](url), where the inner [1] is the display text. The
  //    link regex cannot match nested brackets, so flatten them first.
  final doubleBracketLink = RegExp(r'\[\[([^\]]+)\]\]\(([^\s)]+)\)');
  out = out.replaceAllMapped(doubleBracketLink, (m) => '[${m[1]}](${m[2]})');

  // 8) Fix: when multiple markdown links are placed on separate lines using
  //    trailing double-spaces (hard line breaks), gpt_markdown may treat them
  //    as a single paragraph and only render the first link correctly.
  //    To avoid this, convert such lines into separate paragraphs by
  //    inserting an extra blank line after lines that end with a markdown
  //    link and have at least two trailing spaces.
  //    Example affected pattern:
  //      Label：[text](url)  \nNext： [text](url)  \n
  final linkWithTrailingSpaces = RegExp(r"\[[^\]]+\]\([^\)]+\)\s{2,}$");
  final lines = out.split('\n');
  if (lines.length > 1) {
    final buf = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      buf.write(line);
      if (i < lines.length - 1) buf.write('\n');
      if (linkWithTrailingSpaces.hasMatch(line)) {
        // Ensure a blank line to break the paragraph for the next line
        buf.write('\n');
      }
    }
    out = buf.toString();
  }

  // STEP 3: UNMASKING - Restore code blocks
  // Replace all mask placeholders with their original content
  // NOTE: We do NOT restore _codeDollarMask here because we want LaTeX components
  // to never see dollar signs inside code. The unmask will happen later in highlightBuilder.
  out = out.replaceAllMapped(RegExp(r'__CODE_MASK_\d+__'), (match) {
    final key = match.group(0)!;
    return codeMap[key] ?? key;
  });

  return out;
}

String _normalizeRawCitationMetadata(String input) {
  final rawCitation = RegExp(
    r'\[citation:([^\]\r\n]+)\]',
    caseSensitive: false,
  );
  return input.replaceAllMapped(rawCitation, (match) {
    final refs = _parseCitationRefList(match.group(1) ?? '');
    if (refs.isEmpty) return match.group(0)!;
    return refs.map((ref) => '[citation](${ref.markdownTarget})').join(' ');
  });
}

List<_CitationRef> _parseCitationRefList(String raw) {
  final refs = <_CitationRef>[];
  for (final rawPart in raw.split(',')) {
    var part = rawPart.trim();
    if (part.isEmpty) return const <_CitationRef>[];
    if (part.toLowerCase().startsWith('citation:')) {
      part = part.substring('citation:'.length).trim();
    }
    final ref = _parseCitationRef(part);
    if (ref == null) return const <_CitationRef>[];
    refs.add(ref);
  }
  return refs;
}

_CitationRef? _parseCitationRef(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final separator = trimmed.indexOf(':');
  final hasSeparator = separator != -1;
  final indexText = separator == -1
      ? trimmed
      : trimmed.substring(0, separator).trim();
  final id = separator == -1
      ? indexText
      : trimmed.substring(separator + 1).trim();

  if (!_isCitationIndex(indexText) ||
      (hasSeparator && !RegExp(r'\d').hasMatch(indexText)) ||
      id.isEmpty) {
    return null;
  }
  if (id.contains(')') || id.contains(']') || RegExp(r'\s').hasMatch(id)) {
    return null;
  }
  return _CitationRef(indexText: indexText, id: id);
}

bool _isCitationIndex(String value) =>
    RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);

class _CitationRef {
  const _CitationRef({required this.indexText, required this.id});

  final String indexText;
  final String id;

  String get markdownTarget => indexText == id ? indexText : '$indexText:$id';
}

String _maskBlockquoteFenceMarkers(String input) {
  final lines = input.split('\n');
  var inTopLevelFence = false;
  String? topLevelFence;
  String? topLevelFenceMarker;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (inTopLevelFence) {
      final closeFence = topLevelFence;
      final closeMarker = topLevelFenceMarker;
      if (closeFence != null &&
          closeMarker != null &&
          RegExp(
            '^[ \\t]*${RegExp.escape(closeFence)}${RegExp.escape(closeMarker)}*[ \\t]*\$',
          ).hasMatch(line)) {
        inTopLevelFence = false;
        topLevelFence = null;
        topLevelFenceMarker = null;
      }
      continue;
    }

    final topLevelOpen = RegExp(
      r'^[ \t]*(([`~])\2{2,})[ \t]*[^\n]*$',
    ).firstMatch(line);
    if (topLevelOpen != null) {
      inTopLevelFence = true;
      topLevelFence = topLevelOpen.group(1)!;
      topLevelFenceMarker = topLevelOpen.group(2)!;
      continue;
    }

    final blockquoteFence = RegExp(
      r'^([ \t]*>[ \t]*)([`~]{3,})([^\n]*)$',
    ).firstMatch(line);
    if (blockquoteFence == null) continue;

    final prefix = blockquoteFence.group(1)!;
    final fence = blockquoteFence.group(2)!;
    final suffix = blockquoteFence.group(3) ?? '';
    final marker = fence.startsWith('`') ? '\uE000' : '\uE001';
    lines[i] =
        '$prefix${List<String>.filled(fence.length, marker).join()}$suffix';
  }

  return lines.join('\n');
}

String _unmaskBlockquoteFenceMarkers(String input) {
  return input.replaceAll('\uE000', '`').replaceAll('\uE001', '~');
}

String _stabilizeStreamingTables(String input) {
  final lines = input.split('\n');
  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_isStreamingTailTableHeader(lines, i)) {
      final columnCount = math.max(2, _markdownTableCellCount(line));
      out.add(_completeStreamingTableRow(line, columnCount));
      out.add(_streamingTableDividerFor(columnCount));
      final nextIndex = i + 1;
      if (nextIndex < lines.length &&
          _looksLikePartialTableDivider(lines[nextIndex])) {
        i = nextIndex;
      }
      continue;
    }

    out.add(line);

    if (!_looksLikeTableDivider(line)) continue;
    final headerIndex = out.length - 2;
    if (headerIndex < 0 || !_looksLikeTableRow(out[headerIndex])) continue;
    final columnCount = _markdownTableCellCount(out[headerIndex]);
    if (columnCount < 2) continue;

    i++;
    while (i < lines.length) {
      final row = lines[i];
      if (row.trim().isEmpty) {
        out.add(row);
        break;
      }
      if (!_looksLikeTableRowStart(row)) {
        i--;
        break;
      }
      out.add(_completeStreamingTableRow(row, columnCount));
      i++;
    }
  }
  return out.join('\n');
}

bool _looksLikeTableDivider(String line) {
  final trimmed = line.trim();
  if (!trimmed.contains('|')) return false;
  final cells = _splitMarkdownTableLine(trimmed);
  if (cells.length < 2) return false;
  return cells.every((cell) => RegExp(r'^:?-{1,}:?$').hasMatch(cell.trim()));
}

bool _looksLikePartialTableDivider(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('|')) return false;
  final cells = _splitMarkdownTableLine(trimmed);
  if (cells.isEmpty) return false;
  return cells.every((cell) {
    final value = cell.trim();
    return value.isEmpty || RegExp(r'^:?-*:?$').hasMatch(value);
  });
}

bool _looksLikeTableRow(String line) {
  final trimmed = line.trim();
  return trimmed.startsWith('|') && trimmed.contains('|');
}

bool _looksLikePartialTableRow(String line) {
  final trimmed = line.trim();
  return trimmed.startsWith('|');
}

bool _looksLikeTableRowStart(String line) {
  return line.trimLeft().startsWith('|');
}

int _markdownTableCellCount(String line) {
  return _splitMarkdownTableLine(line).length;
}

bool _isStreamingTailTableHeader(List<String> lines, int index) {
  if (index != lines.length - 1 && index != lines.length - 2) return false;
  final current = lines[index];
  if (!_looksLikePartialTableRow(current)) return false;
  if (_looksLikeTableDivider(current)) return false;

  if (index == lines.length - 2) {
    final next = lines[index + 1];
    if (!_looksLikePartialTableDivider(next)) return false;
  }

  if (index > 0) {
    final previous = lines[index - 1];
    if (previous.trim().isNotEmpty && _looksLikeTableRowStart(previous)) {
      return false;
    }
  }
  return true;
}

String _streamingTableDividerFor(int columnCount) =>
    '|${List<String>.filled(columnCount, ' --- ').join('|')}|';

List<String> _splitMarkdownTableLine(String line) {
  var trimmed = line.trim();
  if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
  if (trimmed.endsWith('|') && !_isEscaped(trimmed, trimmed.length - 1)) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }

  final cells = <String>[];
  final cell = StringBuffer();
  var dollarMathEnd = -1;
  var parenMathEnd = -1;

  for (var i = 0; i < trimmed.length; i++) {
    final ch = trimmed.codeUnitAt(i);

    if (i > dollarMathEnd && i > parenMathEnd) {
      if (ch == 0x24 && !_isEscaped(trimmed, i)) {
        final close = _findClosingDollarMathInTableCell(trimmed, i + 1);
        if (close != -1) dollarMathEnd = close;
      } else if (ch == 0x5C && i + 1 < trimmed.length) {
        final next = trimmed.codeUnitAt(i + 1);
        if (next == 0x28) {
          final close = _findClosingParenMathInTableCell(trimmed, i + 2);
          if (close != -1) parenMathEnd = close + 1;
        }
      }
    }

    if (ch == 0x7C &&
        !_isEscaped(trimmed, i) &&
        i > dollarMathEnd &&
        i > parenMathEnd) {
      cells.add(cell.toString());
      cell.clear();
      continue;
    }

    cell.writeCharCode(ch);
  }
  cells.add(cell.toString());
  return cells;
}

int _findClosingDollarMathInTableCell(String input, int start) {
  final end = math.min(input.length, start + _maxInlineMathBodyLength + 1);
  for (var i = start; i < end; i++) {
    final ch = input.codeUnitAt(i);
    if (ch == 0x0A) return -1;
    if (ch == 0x5C) {
      i++;
      continue;
    }
    if (ch != 0x24) continue;

    final body = input.substring(start, i);
    if (_isValidDollarMathBody(body, allowUnescapedPipes: true) &&
        _canCloseDollarMath(input, i)) {
      return i;
    }
    return -1;
  }
  return -1;
}

int _findClosingParenMathInTableCell(String input, int start) {
  final end = math.min(input.length, start + _maxInlineMathBodyLength + 2);
  for (var i = start; i < end - 1; i++) {
    final ch = input.codeUnitAt(i);
    if (ch == 0x0A) return -1;
    if (ch == 0x5C && input.codeUnitAt(i + 1) == 0x29) return i;
  }
  return -1;
}

String _completeStreamingTableRow(String line, int columnCount) {
  final leadingWhitespace = RegExp(r'^\s*').firstMatch(line)?.group(0) ?? '';
  final trimmedLeft = line.trimLeft();
  final hadTrailingPipe = trimmedLeft.trimRight().endsWith('|');
  var cells = _splitMarkdownTableLine(trimmedLeft).toList();
  final originalCellCount = cells.length;
  for (var i = 0; i < cells.length; i++) {
    if (cells[i].trim().isEmpty) {
      cells[i] = '\u200B';
    }
  }
  while (cells.length < columnCount) {
    cells.add('\u200B');
  }
  if (cells.length > columnCount) {
    return line;
  }
  if (hadTrailingPipe && originalCellCount == columnCount) {
    return line;
  }
  return '$leadingWhitespace|${cells.join('|')}|';
}

String _stabilizeStreamingDollarMath(String input) {
  var inFence = false;
  final lines = input.split('\n');
  for (var i = lines.length - 1; i >= 0; i--) {
    final line = lines[i];
    if (line.trimLeft().startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    final open = _findLastOpenStreamingDollar(line);
    if (open == -1) continue;
    final body = line.substring(open + 1);
    if (!_isValidStreamingDollarMathBody(body)) continue;
    lines[i] = '$line\$';
    break;
  }
  return lines.join('\n');
}

int _findLastOpenStreamingDollar(String line) {
  for (var i = line.length - 1; i >= 0; i--) {
    if (line.codeUnitAt(i) != 0x24) continue;
    if (_isEscaped(line, i) || _isDoubleDollar(line, i)) continue;
    if (!_canOpenDollarMath(line, i)) continue;
    final close = _findClosingDollarMath(line, i + 1);
    if (close == -1) return i;
  }
  return -1;
}

bool _isValidStreamingDollarMathBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.length < 2) return false;
  return _isValidDollarMathBody(trimmed);
}

// Safe math renderer that falls back to plain text when parsing fails.
Widget _renderMath(String tex, {TextStyle? style, bool displayMode = false}) {
  final resolved = style ?? TextStyle();
  final normalizedTex = _normalizeMathTex(tex);
  try {
    return Math.tex(
      normalizedTex,
      mathStyle: displayMode ? MathStyle.display : MathStyle.text,
      textStyle: resolved,
      onErrorFallback: (_) => Text(normalizedTex, style: resolved),
    );
  } catch (_) {
    return Text(normalizedTex, style: resolved);
  }
}

TextStyle _inlineMathTextStyle(TextStyle? style) {
  final base = style ?? TextStyle();
  final baseSize = base.fontSize ?? 15.5;
  return base.copyWith(fontSize: baseSize * 1.2);
}

WidgetSpan _inlineMathSpan(Widget math) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: SelectionContainer.disabled(
      child: _InlineMathScrollable(child: math),
    ),
  );
}

/// Horizontally scrollable inline math that preserves baseline alignment.
///
/// [SingleChildScrollView] breaks baseline forwarding because its internal
/// [RenderViewport] does not implement [computeDistanceToActualBaseline].
/// This widget uses a custom [RenderObject] that lays out the child
/// unconstrained in width, reports correct baseline, and paints with a
/// horizontal scroll offset driven by a [GestureDetector].
class _InlineMathScrollable extends StatefulWidget {
  const _InlineMathScrollable({required this.child});
  final Widget child;

  @override
  State<_InlineMathScrollable> createState() => _InlineMathScrollableState();
}

class _InlineMathScrollableState extends State<_InlineMathScrollable> {
  double _scrollOffset = 0.0;
  double _maxScroll = 0.0;

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    setState(() {
      _scrollOffset = (_scrollOffset - d.delta.dx).clamp(0.0, _maxScroll);
    });
  }

  void _updateMaxScroll(double childWidth, double viewportWidth) {
    _maxScroll = (childWidth - viewportWidth).clamp(0.0, double.infinity);
    // Ensure current offset stays valid after relayout.
    if (_scrollOffset > _maxScroll) {
      _scrollOffset = _maxScroll;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      child: _InlineMathScrollableRenderWidget(
        scrollOffset: _scrollOffset,
        onMetrics: _updateMaxScroll,
        child: widget.child,
      ),
    );
  }
}

class _InlineMathScrollableRenderWidget extends SingleChildRenderObjectWidget {
  const _InlineMathScrollableRenderWidget({
    required this.scrollOffset,
    required this.onMetrics,
    required Widget child,
  }) : super(child: child);

  final double scrollOffset;
  final void Function(double childWidth, double viewportWidth) onMetrics;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderInlineMathScrollable(
        initialScrollOffset: scrollOffset,
        onMetrics: onMetrics,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderInlineMathScrollable renderObject,
  ) {
    renderObject
      ..scrollOffset = scrollOffset
      ..onMetrics = onMetrics;
  }
}

class _RenderInlineMathScrollable extends RenderProxyBox {
  _RenderInlineMathScrollable({
    required double initialScrollOffset,
    required this.onMetrics,
  }) : _scrollOffset = initialScrollOffset;

  double _scrollOffset;
  set scrollOffset(double value) {
    if (_scrollOffset == value) return;
    _scrollOffset = value;
    markNeedsPaint();
  }

  void Function(double childWidth, double viewportWidth) onMetrics;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      constraints.copyWith(maxWidth: double.infinity),
      parentUsesSize: true,
    );
    size = constraints.constrain(child.size);
    // Notify stateful widget of the scrollable extent.
    if (child.size.width > size.width) {
      onMetrics(child.size.width, size.width);
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return child?.getDistanceToActualBaseline(baseline);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (child.size.width <= size.width) {
      context.paintChild(child, offset);
      return;
    }
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, (
      context,
      clipOffset,
    ) {
      context.paintChild(child, clipOffset - Offset(_scrollOffset, 0));
    });
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: Offset(-_scrollOffset, 0),
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }
}

String _replaceInlineDollarMath(String input) {
  final buf = StringBuffer();
  var i = 0;
  var previousDollarWasInlineClose = false;
  while (i < input.length) {
    if (input.codeUnitAt(i) == 0x24 &&
        !_isEscaped(input, i) &&
        _canOpenDollarMath(
          input,
          i,
          allowAdjacentOpen: previousDollarWasInlineClose,
        )) {
      final close = _findClosingDollarMath(input, i + 1);
      if (close != -1) {
        final body = input.substring(i + 1, close);
        buf
          ..write(r'\(')
          ..write(body)
          ..write(r'\)');
        i = close + 1;
        previousDollarWasInlineClose = true;
        continue;
      }
    }
    buf.writeCharCode(input.codeUnitAt(i));
    previousDollarWasInlineClose = false;
    i++;
  }
  return buf.toString();
}

int _findClosingDollarMath(String input, int start) {
  final end = math.min(input.length, start + _maxInlineMathBodyLength + 1);
  final allowUnescapedPipes = !_isDollarMathOnMarkdownTableRow(
    input,
    start - 1,
  );
  for (var i = start; i < end; i++) {
    final ch = input.codeUnitAt(i);
    if (ch == 0x0A) return -1;
    if (ch == 0x5C) {
      i++;
      continue;
    }
    if (ch != 0x24) continue;

    final body = input.substring(start, i);
    if (_isValidDollarMathBody(
          body,
          allowUnescapedPipes: allowUnescapedPipes,
        ) &&
        _canCloseDollarMath(input, i)) {
      return i;
    }
    return -1;
  }
  return -1;
}

bool _isValidDollarMathBody(String body, {bool allowUnescapedPipes = false}) {
  if (body.isEmpty) return false;
  if (body.length > _maxInlineMathBodyLength) return false;
  if (_isWhitespaceCodeUnit(body.codeUnitAt(0))) return false;
  if (_isWhitespaceCodeUnit(body.codeUnitAt(body.length - 1))) return false;
  return allowUnescapedPipes || !_containsUnescapedPipe(body);
}

bool _isDollarMathOnMarkdownTableRow(String input, int dollarIndex) {
  final lineStart = input.lastIndexOf('\n', dollarIndex);
  final lineEnd = input.indexOf('\n', dollarIndex);
  final start = lineStart == -1 ? 0 : lineStart + 1;
  final end = lineEnd == -1 ? input.length : lineEnd;
  return _looksLikeTableRowStart(input.substring(start, end));
}

bool _containsUnescapedPipe(String input) {
  for (var i = 0; i < input.length; i++) {
    final ch = input.codeUnitAt(i);
    if (ch == 0x5C) {
      i++;
      continue;
    }
    if (ch == 0x7C) return true;
  }
  return false;
}

bool _canOpenDollarMath(
  String input,
  int index, {
  bool allowAdjacentOpen = false,
}) {
  if (index + 1 >= input.length) return false;
  final next = input.codeUnitAt(index + 1);
  if (!_canStartDollarMathBody(next)) return false;
  if (index == 0) return true;
  final prev = input.codeUnitAt(index - 1);
  if (prev == 0x24) {
    return allowAdjacentOpen && _canStartAdjacentDollarMathBody(next);
  }
  return _isWhitespaceCodeUnit(prev) || _isDollarMathBoundary(prev);
}

bool _canCloseDollarMath(String input, int index) {
  if (index == 0 || _isWhitespaceCodeUnit(input.codeUnitAt(index - 1))) {
    return false;
  }
  final nextIndex = index + 1;
  if (nextIndex >= input.length) return true;
  final next = input.codeUnitAt(nextIndex);
  if (next == 0x24) return true;
  return next != 0x24 &&
      (_isWhitespaceCodeUnit(next) || _isDollarMathBoundary(next));
}

bool _isDollarMathBoundary(int codeUnit) {
  return _isAsciiPunctuation(codeUnit) ||
      _isUnicodePunctuation(codeUnit) ||
      _isCjkCodeUnit(codeUnit);
}

bool _canStartDollarMathBody(int codeUnit) {
  if (_isWhitespaceCodeUnit(codeUnit) || codeUnit == 0x24) return false;
  if (_isAsciiLetterOrDigit(codeUnit) || codeUnit == 0x5C) return true;
  if (codeUnit == 0x28 || codeUnit == 0x5B || codeUnit == 0x7B) return true;
  if (codeUnit == 0x2B || codeUnit == 0x2D) return true;
  if (codeUnit == 0x7C) return true; // |
  return !_isClosingOrSentencePunctuation(codeUnit);
}

bool _canStartAdjacentDollarMathBody(int codeUnit) {
  if (_isAsciiLetterOrDigit(codeUnit) || codeUnit == 0x5C) return true;
  if (codeUnit == 0x28 || codeUnit == 0x5B || codeUnit == 0x7B) return true;
  return codeUnit == 0x2B ||
      codeUnit == 0x2D ||
      codeUnit == 0x2A ||
      codeUnit == 0x2F ||
      codeUnit == 0x3C ||
      codeUnit == 0x3D ||
      codeUnit == 0x3E ||
      codeUnit == 0x5E ||
      codeUnit == 0x5F ||
      codeUnit == 0x7C;
}

bool _isDoubleDollar(String input, int index) {
  return (index > 0 && input.codeUnitAt(index - 1) == 0x24) ||
      (index + 1 < input.length && input.codeUnitAt(index + 1) == 0x24);
}

bool _isEscaped(String input, int index) {
  var backslashes = 0;
  for (var i = index - 1; i >= 0 && input.codeUnitAt(i) == 0x5C; i--) {
    backslashes++;
  }
  return backslashes.isOdd;
}

bool _isWhitespaceCodeUnit(int codeUnit) {
  return codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D;
}

bool _isAsciiDigit(int codeUnit) {
  return codeUnit >= 0x30 && codeUnit <= 0x39;
}

bool _isAsciiLetterOrDigit(int codeUnit) {
  return _isAsciiDigit(codeUnit) ||
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A);
}

bool _isClosingOrSentencePunctuation(int codeUnit) {
  return codeUnit == 0x21 ||
      codeUnit == 0x22 ||
      codeUnit == 0x27 ||
      codeUnit == 0x29 ||
      codeUnit == 0x2C ||
      codeUnit == 0x2E ||
      codeUnit == 0x3A ||
      codeUnit == 0x3B ||
      codeUnit == 0x3F ||
      codeUnit == 0x5D ||
      codeUnit == 0x7D ||
      _isUnicodePunctuation(codeUnit);
}

bool _isAsciiPunctuation(int codeUnit) {
  return (codeUnit >= 0x21 && codeUnit <= 0x2F) ||
      (codeUnit >= 0x3A && codeUnit <= 0x40) ||
      (codeUnit >= 0x5B && codeUnit <= 0x60) ||
      (codeUnit >= 0x7B && codeUnit <= 0x7E);
}

bool _isUnicodePunctuation(int codeUnit) {
  return (codeUnit >= 0x2000 && codeUnit <= 0x206F) ||
      (codeUnit >= 0x3000 && codeUnit <= 0x303F) ||
      (codeUnit >= 0xFE10 && codeUnit <= 0xFE1F) ||
      (codeUnit >= 0xFE30 && codeUnit <= 0xFE4F) ||
      (codeUnit >= 0xFF01 && codeUnit <= 0xFF0F) ||
      (codeUnit >= 0xFF1A && codeUnit <= 0xFF20) ||
      (codeUnit >= 0xFF3B && codeUnit <= 0xFF40) ||
      (codeUnit >= 0xFF5B && codeUnit <= 0xFF65);
}

bool _isCjkCodeUnit(int codeUnit) {
  return (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) ||
      (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) ||
      (codeUnit >= 0xF900 && codeUnit <= 0xFAFF);
}

String _normalizeMathTex(String tex) {
  final escapedSpecials = _escapeInlineMathSpecials(tex);
  final normalizedBraces = _escapeLikelyLiteralMathBraces(escapedSpecials);
  return normalizedBraces.replaceAllMapped(RegExp(r'\\\|([\s\S]*?)\\\|'), (
    match,
  ) {
    final body = match.group(1) ?? '';
    return r'\lVert '
        '$body'
        r' \rVert';
  });
}

String _escapeInlineMathSpecials(String tex) {
  final buf = StringBuffer();
  for (var i = 0; i < tex.length; i++) {
    final ch = tex.codeUnitAt(i);
    if (ch == 0x23 && !_isEscaped(tex, i)) {
      buf.write(r'\#');
    } else {
      buf.writeCharCode(ch);
    }
  }
  return buf.toString();
}

String _escapeLikelyLiteralMathBraces(String tex) {
  final escapeOpens = <int>{};
  final escapeCloses = <int>{};
  final stack = <int>[];

  for (var i = 0; i < tex.length; i++) {
    final ch = tex.codeUnitAt(i);
    if (ch == 0x5C) {
      i++;
      continue;
    }
    if (ch == 0x7B) {
      stack.add(i);
      continue;
    }
    if (ch != 0x7D || stack.isEmpty) continue;

    final open = stack.removeLast();
    if (stack.isNotEmpty) continue;
    if (_looksLikeLiteralMathBraceGroup(tex, open, i)) {
      escapeOpens.add(open);
      escapeCloses.add(i);
    }
  }

  if (escapeOpens.isEmpty) return tex;
  final buf = StringBuffer();
  for (var i = 0; i < tex.length; i++) {
    if (escapeOpens.contains(i)) {
      buf.write(r'\{');
    } else if (escapeCloses.contains(i)) {
      buf.write(r'\}');
    } else {
      buf.writeCharCode(tex.codeUnitAt(i));
    }
  }
  return buf.toString();
}

bool _looksLikeLiteralMathBraceGroup(String tex, int open, int close) {
  if (_isCommandArgumentBrace(tex, open) || _isScriptArgumentBrace(tex, open)) {
    return false;
  }
  if (!_hasLiteralBraceBoundaryBefore(tex, open)) return false;

  final body = tex.substring(open + 1, close).trim();
  if (body.isEmpty) return true;
  if (body.startsWith(r'\')) return false;
  if (_nextNonWhitespaceCodeUnit(tex, close + 1) == 0x5F &&
      body.contains('_')) {
    return true;
  }
  return body.contains(',') ||
      body.contains(':') ||
      body.contains(';') ||
      body.contains(r'\in') ||
      body.contains(r'\notin') ||
      body.contains(r'\mid') ||
      body.contains('|');
}

bool _isCommandArgumentBrace(String tex, int open) {
  final prev = _previousNonWhitespaceIndex(tex, open - 1);
  if (prev == -1) return false;

  if (tex.codeUnitAt(prev) == 0x5D) {
    final optionalOpen = _findMatchingOpenBracket(tex, prev);
    if (optionalOpen != -1) {
      final beforeOptional = _previousNonWhitespaceIndex(tex, optionalOpen - 1);
      if (beforeOptional != -1 && _endsControlWordAt(tex, beforeOptional)) {
        return true;
      }
    }
  }

  return _endsControlWordAt(tex, prev);
}

bool _isScriptArgumentBrace(String tex, int open) {
  final prev = _previousNonWhitespaceIndex(tex, open - 1);
  if (prev == -1) return false;
  final ch = tex.codeUnitAt(prev);
  return ch == 0x5E || ch == 0x5F;
}

bool _hasLiteralBraceBoundaryBefore(String tex, int open) {
  final prev = _previousNonWhitespaceIndex(tex, open - 1);
  if (prev == -1) return true;
  final ch = tex.codeUnitAt(prev);
  if (ch == 0x5C || ch == 0x5E || ch == 0x5F || ch == 0x7D) return false;
  if (_isAsciiLetterOrDigit(ch)) return false;
  return true;
}

int _previousNonWhitespaceIndex(String input, int index) {
  for (var i = index; i >= 0; i--) {
    if (!_isWhitespaceCodeUnit(input.codeUnitAt(i))) return i;
  }
  return -1;
}

int _nextNonWhitespaceCodeUnit(String input, int index) {
  for (var i = index; i < input.length; i++) {
    final ch = input.codeUnitAt(i);
    if (!_isWhitespaceCodeUnit(ch)) return ch;
  }
  return -1;
}

bool _endsControlWordAt(String tex, int index) {
  if (index < 0 || index >= tex.length) return false;
  var start = index;
  while (start >= 0 && _isAsciiLetter(tex.codeUnitAt(start))) {
    start--;
  }
  return start < index && start >= 0 && tex.codeUnitAt(start) == 0x5C;
}

bool _isAsciiLetter(int codeUnit) {
  return (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A);
}

int _findMatchingOpenBracket(String tex, int close) {
  var depth = 0;
  for (var i = close; i >= 0; i--) {
    final ch = tex.codeUnitAt(i);
    if (ch == 0x5C) {
      i--;
      continue;
    }
    if (ch == 0x5D) {
      depth++;
    } else if (ch == 0x5B) {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

String _softBreakInline(String input) {
  // Insert zero-width break for inline code segments with long tokens.
  if (input.length < 60) return input;
  final buf = StringBuffer();
  for (int i = 0; i < input.length; i++) {
    buf.write(input[i]);
    if ((i + 1) % 24 == 0) buf.write('\u200B');
  }
  return buf.toString();
}

List<String> _extractImageUrls(String md) {
  final re = RegExp(r"!\[[^\]]*\]\(([^)\s]+)\)");
  return re
      .allMatches(md)
      .map((m) => (m.group(1) ?? '').trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

String _sanitizeImageLinks(String input) {
  final re = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)', multiLine: true);
  return input.replaceAllMapped(re, (m) {
    final alt = m.group(1) ?? '';
    final inside = (m.group(2) ?? '').trim();
    if (inside.isEmpty) return m[0]!;

    // Leave remote URLs and data URLs untouched.
    if (inside.startsWith('http://') ||
        inside.startsWith('https://') ||
        inside.startsWith('data:')) {
      return m[0]!;
    }

    final url = inside;
    final isFileUri = url.startsWith('file://');
    final isRemote = url.startsWith('http://') || url.startsWith('https://');
    final isData = url.startsWith('data:');
    final isWindowsAbs = RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(url);
    final isLikelyLocalPath =
        (!isRemote && !isData) &&
        (isFileUri || url.startsWith('/') || isWindowsAbs);

    if (!isLikelyLocalPath || !url.contains(' ')) {
      return m[0]!;
    }

    String safeUrl;
    try {
      if (isFileUri) {
        final uri = Uri.parse(url);
        safeUrl = uri.toString();
      } else {
        // Plain absolute file system path -> file:// URI.
        safeUrl = Uri.file(url).toString();
      }
    } catch (_) {
      // Fallback: minimally escape spaces.
      safeUrl = url.replaceAll(' ', '%20');
    }

    return '![$alt]($safeUrl)';
  });
}

ImageProvider? _imageProviderFor(String src) {
  if (src.startsWith('http://') || src.startsWith('https://')) {
    return NetworkImage(src);
  }
  if (src.startsWith('data:')) {
    try {
      final base64Marker = 'base64,';
      final idx = src.indexOf(base64Marker);
      if (idx != -1) {
        final b64 = src.substring(idx + base64Marker.length);
        return MemoryImage(base64Decode(b64));
      }
    } catch (_) {}
    return null;
  }
  final fixed = SandboxPathResolver.fix(src);
  final f = File(fixed);
  if (f.existsSync()) {
    return FileImage(f);
  }
  // Missing local file or unsupported scheme
  return null;
}

class _CollapsibleCodeBlock extends StatefulWidget {
  final String language;
  final String code;
  final bool streaming;
  final bool closed;

  const _CollapsibleCodeBlock({
    required this.language,
    required this.code,
    required this.streaming,
    required this.closed,
  });

  @override
  State<_CollapsibleCodeBlock> createState() => _CollapsibleCodeBlockState();
}

class _CollapsibleCodeBlockState extends State<_CollapsibleCodeBlock> {
  static final Map<String, bool> _manualExpansionByCodeKey = <String, bool>{};
  static const int _maxStoredManualExpansionStates = 80;

  bool _expanded = true;
  bool _manuallyToggled = false;
  late String _stateKey;

  @override
  void initState() {
    super.initState();
    _stateKey = _codeBlockStateKey(widget.language, widget.code);
    _applyInitialAutoCollapse();
  }

  @override
  void didUpdateWidget(covariant _CollapsibleCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncStateKeyForStreamingUpdate();
    _applyAutoCollapseIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyAutoCollapseIfNeeded();
  }

  void _applyInitialAutoCollapse() {
    final stored = _manualExpansionByCodeKey[_stateKey];
    if (stored != null) {
      _expanded = stored;
      _manuallyToggled = true;
      return;
    }

    final sp = context.read<SettingsProvider>();
    if (!sp.autoCollapseCodeBlock) return;
    final threshold = sp.autoCollapseCodeBlockLines;
    if (_exceedsLineThreshold(widget.code, threshold)) {
      _expanded = false;
    }
  }

  void _applyAutoCollapseIfNeeded() {
    if (_manuallyToggled) return;
    if (!_expanded) return;
    final sp = context.read<SettingsProvider>();
    if (!sp.autoCollapseCodeBlock) return;
    final threshold = sp.autoCollapseCodeBlockLines;

    if (_exceedsLineThreshold(widget.code, threshold)) {
      setState(() => _expanded = false);
    }
  }

  void _syncStateKeyForStreamingUpdate() {
    final nextKey = _codeBlockStateKey(widget.language, widget.code);
    if (nextKey == _stateKey) return;

    if (_manuallyToggled) {
      _stateKey = nextKey;
      _rememberManualExpansionState();
      return;
    }

    _stateKey = nextKey;
    final stored = _manualExpansionByCodeKey[_stateKey];
    if (stored == null) return;
    _expanded = stored;
    _manuallyToggled = true;
  }

  void _rememberManualExpansionState() {
    _manualExpansionByCodeKey[_stateKey] = _expanded;
    if (_manualExpansionByCodeKey.length <= _maxStoredManualExpansionStates) {
      return;
    }
    _manualExpansionByCodeKey.remove(_manualExpansionByCodeKey.keys.first);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    String resolveCodeFont() {
      final fam = settings.codeFontFamily;
      if (fam == null || fam.isEmpty) return 'monospace';
      if (settings.codeFontIsGoogle) {
        try {
          final s = GoogleFonts.getFont(fam);
          return s.fontFamily ?? fam;
        } catch (_) {
          return fam;
        }
      }
      return fam;
    }

    final codeFontFamily = resolveCodeFont();
    final codeTextStyle = TextStyle(
      fontFamily: codeFontFamily,
      fontSize: 13,
      height: 1.5,
    );
    final codeLanguage = _normalizeLanguage(widget.language) ?? 'plaintext';
    final codeTheme = _transparentBgTheme(
      isDark ? atomOneDarkReasonableTheme : githubTheme,
    );
    final highlightEnabled = !_shouldSkipHighlightWhileStreaming();

    Widget buildCodeView(String visibleCode) {
      final codeView = SelectableHighlightView(
        visibleCode,
        language: codeLanguage,
        theme: codeTheme,
        padding: EdgeInsets.zero,
        textStyle: codeTextStyle,
        enableHighlight: highlightEnabled,
      );

      final bool isDesktop =
          Platform.isMacOS || Platform.isWindows || Platform.isLinux;
      if (isDesktop || settings.mobileCodeBlockWrap) {
        return codeView;
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        primary: false,
        child: codeView,
      );
    }

    final Color bodyBg = cs.surfaceContainer;
    final Color headerBg = cs.surfaceContainerHighest;
    final borderColor = _codeBlockBorderColor(cs, isDark);
    final isEffectivelyExpanded = _isEffectivelyExpanded(settings);
    final isCollapsed = !isEffectivelyExpanded;
    final showCollapsedTailFade =
        isCollapsed && _hasCollapsedHiddenLines(settings);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bodyBg,
        borderRadius: BorderRadius.circular(16),
      ),
      // Clip children to the same radius so they don't overpaint corners
      clipBehavior: Clip.antiAlias,
      // Draw the border on top so it remains visible at corners
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: headerBg,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _CodeBlockHeaderToggle(
                    expanded: isEffectivelyExpanded,
                    onTap: () => _toggleExpanded(settings),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _displayLanguage(context, widget.language),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: AppFontWeights.medium,
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.72,
                              ),
                              height: 1.0,
                            ),
                          ),
                        ),
                        _CodeBlockCollapseIcon(collapsed: isCollapsed),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CodeBlockIconAction(
                      icon: Lucide.Download,
                      label: AppLocalizations.of(
                        context,
                      )!.codeBlockSaveAsButton,
                      onTap: () => _saveCodeAsFile(context),
                    ),
                    const SizedBox(width: 16),
                    _CodeBlockIconAction(
                      icon: Lucide.Copy,
                      label: AppLocalizations.of(
                        context,
                      )!.shareProviderSheetCopyButton,
                      onTap: () => _copyCode(context),
                    ),
                    if (_isHtml(widget.language)) ...[
                      const SizedBox(width: 16),
                      _CodeBlockIconAction(
                        icon: Lucide.Eye,
                        label: AppLocalizations.of(
                          context,
                        )!.codeBlockPreviewButton,
                        onTap: () => _previewHtml(context),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: bodyBg,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topLeft,
                      clipBehavior: Clip.hardEdge,
                      child: buildCodeView(
                        isCollapsed
                            ? _collapsedHighlightedCode(settings)
                            : _trimTrailingNewlines(widget.code),
                      ),
                    ),
                  ],
                ),
                if (showCollapsedTailFade)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _CodeBlockCollapsedTailFade(color: bodyBg),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasCollapsedHiddenLines(SettingsProvider settings) {
    return _exceedsLineThreshold(
      widget.code,
      _collapsedVisibleLineCount(settings),
    );
  }

  int _collapsedVisibleLineCount(SettingsProvider settings) {
    return settings.autoCollapseCodeBlockLines.clamp(1, 999999);
  }

  bool _isEffectivelyExpanded(SettingsProvider settings) {
    if (_manuallyToggled) return _expanded;
    if (!settings.autoCollapseCodeBlock) return true;
    return !_exceedsLineThreshold(
      widget.code,
      settings.autoCollapseCodeBlockLines,
    );
  }

  void _toggleExpanded(SettingsProvider settings) {
    final nextExpanded = !_isEffectivelyExpanded(settings);
    setState(() {
      _manuallyToggled = true;
      _expanded = nextExpanded;
      _rememberManualExpansionState();
    });
  }

  Future<void> _copyCode(BuildContext context) async {
    final copiedMessage = AppLocalizations.of(
      context,
    )!.chatMessageWidgetCopiedToClipboard;
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: copiedMessage,
      type: NotificationType.success,
    );
  }

  Future<void> _saveCodeAsFile(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final extension = _codeFileExtension(widget.language);
    final timestamp = DateTime.now().toLocal().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final filename =
        '${l10n.codeBlockDefaultFileNameStem}_$timestamp$extension';

    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: l10n.backupPageExportToFile,
          fileName: filename,
          type: FileType.custom,
          allowedExtensions: [_extensionWithoutDot(extension)],
        );
        if (savePath == null) return;
        await File(savePath).parent.create(recursive: true);
        await File(savePath).writeAsString(widget.code);
        if (!context.mounted) return;
        showAppSnackBar(
          context,
          message: l10n.messageExportSheetExportedAs(p.basename(savePath)),
          type: NotificationType.success,
        );
        return;
      }

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.backupPageExportToFile,
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: [_extensionWithoutDot(extension)],
        bytes: Uint8List.fromList(utf8.encode(widget.code)),
      );
      if (savePath == null || !context.mounted) return;
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportedAs(p.basename(savePath)),
        type: NotificationType.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportFailed('$e'),
        type: NotificationType.error,
      );
    }
  }

  void _previewHtml(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (Platform.isAndroid || Platform.isIOS) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => HtmlPreviewPage(html: widget.code),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          transitionsBuilder: (context, anim, sec, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(opacity: curved, child: child);
          },
        ),
      );
    } else if (Platform.isLinux) {
      showAppSnackBar(
        context,
        message: l10n.htmlPreviewNotSupportedOnLinux,
        type: NotificationType.warning,
      );
    } else {
      showHtmlPreviewDesktopDialog(context, html: widget.code);
    }
  }

  String _collapsedHighlightedCode(SettingsProvider settings) {
    final visibleLines = _collapsedVisibleLineCount(settings);
    final trimmed = _trimTrailingNewlines(widget.code);
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(RegExp(r'\r\n|\r|\n')).take(visibleLines).join('\n');
  }

  bool _exceedsLineThreshold(String code, int threshold) {
    if (threshold < 1) return true;
    final end = _trimTrailingNewlinesEndIndex(code);
    if (end <= 0) return false;

    int lines = 1;
    for (int i = 0; i < end; i++) {
      final cu = code.codeUnitAt(i);
      if (cu == 0x0A /* \n */ ) {
        lines++;
        if (lines > threshold) return true;
        continue;
      }
      if (cu == 0x0D /* \r */ ) {
        lines++;
        if (lines > threshold) return true;
        if (i + 1 < end && code.codeUnitAt(i + 1) == 0x0A) i++;
      }
    }
    return false;
  }

  bool _shouldSkipHighlightWhileStreaming() {
    if (!widget.streaming) return false;
    if (!widget.closed) return true;
    return _exceedsLineThreshold(
          widget.code,
          MarkdownWithCodeHighlight._streamingHighlightMaxLines,
        ) ||
        widget.code.length >
            MarkdownWithCodeHighlight._streamingHighlightMaxChars;
  }

  int _trimTrailingNewlinesEndIndex(String s) {
    int end = s.length;
    while (end > 0) {
      final ch = s.codeUnitAt(end - 1);
      if (ch == 0x0A /* \n */ || ch == 0x0D /* \r */ ) {
        end--;
        continue;
      }
      break;
    }
    return end;
  }

  // Remove trailing newlines to avoid rendering an extra empty line at the bottom
  String _trimTrailingNewlines(String s) {
    if (s.isEmpty) return s;
    final end = _trimTrailingNewlinesEndIndex(s);
    return end == s.length ? s : s.substring(0, end);
  }
}

class _CodeBlockCollapsedTailFade extends StatelessWidget {
  const _CodeBlockCollapsedTailFade({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        key: const ValueKey('code-block-collapsed-tail-fade'),
        height: 24,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0),
                color.withValues(alpha: 0.72),
                color,
              ],
            ),
          ),
        ),
      ),
    );
  }
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

String _codeBlockStateKey(String language, String code) {
  final normalizedLanguage = language.trim().toLowerCase();
  final normalizedCode = code.trimLeft().replaceAll(RegExp(r'\s+'), ' ');
  final anchor = normalizedCode.length <= 16
      ? normalizedCode
      : normalizedCode.substring(0, 16);
  return '$normalizedLanguage|$anchor';
}

String _mermaidCacheKey(
  String code,
  bool isDark,
  Map<String, String> themeVars,
) {
  final entries = themeVars.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final themeSig = entries.map((e) => '${e.key}=${e.value}').join('&');
  return '${isDark ? 'dark' : 'light'}|$themeSig|$code';
}

enum MermaidBitmapRenderStatus { success, failed, unsupported }

class MermaidBitmapRenderResult {
  const MermaidBitmapRenderResult._(this.status, [this.bytes]);

  factory MermaidBitmapRenderResult.success(Uint8List bytes) {
    return MermaidBitmapRenderResult._(
      MermaidBitmapRenderStatus.success,
      bytes,
    );
  }

  factory MermaidBitmapRenderResult.failed() {
    return const MermaidBitmapRenderResult._(MermaidBitmapRenderStatus.failed);
  }

  factory MermaidBitmapRenderResult.unsupported() {
    return const MermaidBitmapRenderResult._(
      MermaidBitmapRenderStatus.unsupported,
    );
  }

  final MermaidBitmapRenderStatus status;
  final Uint8List? bytes;
}

typedef MermaidBitmapRenderOverride =
    Future<MermaidBitmapRenderResult> Function(
      String code,
      bool isDark,
      Map<String, String> themeVars,
    );

@visibleForTesting
MermaidBitmapRenderOverride? debugMermaidBitmapRenderOverride;

class _CodeBlockHeaderToggle extends StatelessWidget {
  const _CodeBlockHeaderToggle({
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = expanded
        ? l10n.codeBlockCollapseButton
        : l10n.codeBlockExpandButton;

    return SelectionContainer.disabled(
      child: Semantics(
        button: true,
        label: label,
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => onTap(),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _CodeBlockCollapseIcon extends StatelessWidget {
  const _CodeBlockCollapseIcon({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final reduceMotion =
        (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final cs = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      key: const ValueKey('code-block-collapse-icon-switcher'),
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: collapsed
          ? Row(
              key: const ValueKey('code-block-collapse-icon-visible'),
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 4),
                Icon(
                  Lucide.ChevronRight,
                  size: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.56),
                ),
              ],
            )
          : const SizedBox(
              key: ValueKey('code-block-collapse-icon-hidden'),
              width: 0,
              height: 14,
            ),
    );
  }
}

class _CodeBlockIconAction extends StatelessWidget {
  const _CodeBlockIconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    return Tooltip(
      message: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: IosIconButton(
          icon: icon,
          semanticLabel: label,
          onTap: onTap,
          size: 16,
          padding: const EdgeInsets.all(4),
          color: color,
        ),
      ),
    );
  }
}

String _codeFileExtension(String? language) {
  switch ((language ?? '').trim().toLowerCase()) {
    case 'kotlin':
    case 'kt':
      return '.kt';
    case 'java':
      return '.java';
    case 'python':
    case 'py':
      return '.py';
    case 'javascript':
    case 'js':
      return '.js';
    case 'typescript':
    case 'ts':
      return '.ts';
    case 'dart':
      return '.dart';
    case 'cpp':
    case 'c++':
      return '.cpp';
    case 'c':
      return '.c';
    case 'csharp':
    case 'cs':
    case 'c#':
      return '.cs';
    case 'go':
    case 'golang':
      return '.go';
    case 'rust':
    case 'rs':
      return '.rs';
    case 'swift':
      return '.swift';
    case 'html':
    case 'htm':
    case 'rawhtml':
    case 'raw_html':
      return '.html';
    case 'css':
      return '.css';
    case 'xml':
      return '.xml';
    case 'json':
      return '.json';
    case 'yaml':
    case 'yml':
      return '.yml';
    case 'markdown':
    case 'md':
      return '.md';
    case 'sql':
      return '.sql';
    case 'shell':
    case 'bash':
    case 'sh':
    case 'zsh':
      return '.sh';
    case 'svg':
      return '.svg';
    default:
      return '.txt';
  }
}

String _extensionWithoutDot(String extension) {
  return extension.startsWith('.') ? extension.substring(1) : extension;
}

bool _isHtml(String? lang) {
  final l = (lang ?? '').trim().toLowerCase();
  return l == 'html' || l == 'htm' || l == 'rawhtml' || l == 'raw_html';
}

@visibleForTesting
String markdownTableRowsToCsvForTesting(List<List<String>> rows) =>
    _rowsToCsv(rows);

@visibleForTesting
String markdownTableRowsToMarkdownForTesting(List<List<String>> rows) =>
    _rowsToMarkdown(rows);

@visibleForTesting
TargetPlatform? markdownTableTargetPlatformOverride;

class _MarkdownTableBlock extends StatelessWidget {
  _MarkdownTableBlock({
    required this.rows,
    required this.style,
    required this.config,
    required this.appFontFamily,
  }) : _tableBoundaryKey = GlobalKey();

  final _MarkdownTableData rows;
  final TextStyle style;
  final GptMarkdownConfig config;
  final String? appFontFamily;
  final GlobalKey _tableBoundaryKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.22 : 0.30,
    );
    final headerBg = Color.alphaBlend(
      cs.primary.withValues(alpha: isDark ? 0.15 : 0.07),
      cs.surface,
    );
    final bodyBg = Color.alphaBlend(
      cs.primary.withValues(alpha: isDark ? 0.04 : 0.015),
      cs.surface,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktopPlatform = _markdownTableTargetPlatformIsDesktop();
        final bool isExporting = ExportCaptureScope.of(context);
        final bool useCompactTable =
            !isDesktopPlatform || constraints.maxWidth < 520;

        final columnWidth = _compactColumnWidth(
          constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width,
          rows.columnCount,
        );
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final shouldScrollHorizontally =
            !isExporting &&
            useCompactTable &&
            rows.columnCount >= 4 &&
            columnWidth * rows.columnCount > viewportWidth;
        final table = _buildTable(
          context,
          borderColor: borderColor,
          headerBg: headerBg,
          compact: useCompactTable,
          columnWidth: columnWidth,
          fixedColumns: shouldScrollHorizontally,
        );

        final tableSurface = _buildTableSurface(
          context,
          table: table,
          bodyBg: bodyBg,
          borderColor: borderColor,
          compact: useCompactTable,
        );

        if (!useCompactTable) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: tableSurface,
          );
        }

        final l10n = AppLocalizations.of(context)!;
        return SelectionContainer.disabled(
          child: Container(
            key: const ValueKey('markdown-table-block'),
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                cs.primary.withValues(alpha: isDark ? 0.045 : 0.018),
                cs.surface,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MarkdownTableToolbar(
                  label: l10n.markdownTableLabel,
                  backgroundColor: headerBg,
                  copyLabel: l10n.shareProviderSheetCopyButton,
                  exportLabel: l10n.markdownTableExportCsvTooltip,
                  imageActionLabel: isDesktopPlatform
                      ? l10n.messageExportSheetExportImage
                      : l10n.markdownTableSaveImageTooltip,
                  onCopy: () => _copyMarkdown(context),
                  onCopyImage: () => _copyImage(context),
                  onExport: () => _exportCsv(context),
                  onExportImage: () => _exportImage(context),
                  onImageAction: () => isDesktopPlatform
                      ? _exportImage(context)
                      : _saveImageToGallery(context),
                ),
                GestureDetector(
                  key: const ValueKey('markdown-table-body'),
                  behavior: HitTestBehavior.opaque,
                  child: _buildMobileTableViewport(
                    scrollable: shouldScrollHorizontally,
                    child: tableSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTable(
    BuildContext context, {
    required Color borderColor,
    required Color headerBg,
    required bool compact,
    required double columnWidth,
    required bool fixedColumns,
  }) {
    final columnWidths = <int, TableColumnWidth>{
      for (int i = 0; i < rows.columnCount; i++)
        i: fixedColumns
            ? FixedColumnWidth(columnWidth)
            : const FlexColumnWidth(),
    };

    return Table(
      defaultColumnWidth: fixedColumns
          ? FixedColumnWidth(columnWidth)
          : const FlexColumnWidth(),
      columnWidths: columnWidths,
      border: TableBorder(
        horizontalInside: BorderSide(color: borderColor, width: 0.5),
        verticalInside: BorderSide(color: borderColor, width: 0.5),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (int r = 0; r < rows.rows.length; r++)
          TableRow(
            decoration: r == 0 ? BoxDecoration(color: headerBg) : null,
            children: [
              for (int c = 0; c < rows.columnCount; c++)
                _MarkdownTableCell(
                  data: rows.rows[r].cells[c],
                  header: r == 0,
                  style: style,
                  config: config,
                  appFontFamily: appFontFamily,
                  selectable: !compact,
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildTableSurface(
    BuildContext context, {
    required Widget table,
    required Color bodyBg,
    required Color borderColor,
    required bool compact,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tableContent = Container(
      decoration: BoxDecoration(
        color: bodyBg,
        borderRadius: compact ? BorderRadius.zero : BorderRadius.circular(10),
      ),
      foregroundDecoration: compact
          ? null
          : BoxDecoration(
              border: Border.all(color: borderColor, width: 0.8),
              borderRadius: BorderRadius.circular(10),
            ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: cs.onSurface, fontFamily: appFontFamily),
        child: table,
      ),
    );

    if (compact) {
      return RepaintBoundary(key: _tableBoundaryKey, child: tableContent);
    }

    return RepaintBoundary(
      key: _tableBoundaryKey,
      child: SizedBox(
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: tableContent,
        ),
      ),
    );
  }

  Widget _buildMobileTableViewport({
    required Widget child,
    required bool scrollable,
  }) {
    if (!scrollable) return child;
    return SingleChildScrollView(
      key: const ValueKey('markdown-table-horizontal-scroll'),
      scrollDirection: Axis.horizontal,
      primary: false,
      physics: const ClampingScrollPhysics(),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }

  double _compactColumnWidth(double maxWidth, int columnCount) {
    final safeMax = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 360.0;
    if (columnCount <= 1) {
      return (safeMax - 16).clamp(220.0, 360.0).toDouble();
    }
    final visibleColumns = columnCount >= 4 ? 2.45 : columnCount.toDouble();
    return ((safeMax - 16) / visibleColumns).clamp(112.0, 178.0).toDouble();
  }

  Future<void> _copyMarkdown(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: rows.toMarkdown()));
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.markdownTableCopiedMarkdownSnackbar,
      type: NotificationType.success,
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final timestamp = DateTime.now().toLocal().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final filename = '${l10n.markdownTableDefaultFileNameStem}_$timestamp.csv';
    final csv = rows.toCsv();

    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: l10n.backupPageExportToFile,
          fileName: filename,
          type: FileType.custom,
          allowedExtensions: const ['csv'],
        );
        if (savePath == null) return;
        await File(savePath).parent.create(recursive: true);
        await File(savePath).writeAsString(csv);
        if (!context.mounted) return;
        showAppSnackBar(
          context,
          message: l10n.messageExportSheetExportedAs(p.basename(savePath)),
          type: NotificationType.success,
        );
        return;
      }

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.backupPageExportToFile,
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );
      if (savePath == null || !context.mounted) return;
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportedAs(p.basename(savePath)),
        type: NotificationType.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportFailed('$e'),
        type: NotificationType.error,
      );
    }
  }

  Future<void> _exportImage(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final timestamp = DateTime.now().toLocal().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final filename = '${l10n.markdownTableDefaultFileNameStem}_$timestamp.png';
    try {
      final bytes = await _captureTablePngBytes();
      if (bytes == null) throw 'render error';
      final savePath = await _savePngBytes(
        dialogTitle: l10n.backupPageExportToFile,
        filename: filename,
        bytes: bytes,
      );
      if (savePath == null) return;
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportedAs(p.basename(savePath)),
        type: NotificationType.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportFailed('$e'),
        type: NotificationType.error,
      );
    }
  }

  Future<void> _saveImageToGallery(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final bytes = await _captureTablePngBytes();
      if (bytes == null) throw 'render error';
      final ok = await _savePngBytesToGallery(bytes);
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: ok
            ? l10n.imagePreviewSheetSaveSuccess
            : l10n.imagePreviewSheetSaveFailed('unknown'),
        type: ok ? NotificationType.success : NotificationType.error,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: l10n.imagePreviewSheetSaveFailed('$e'),
        type: NotificationType.error,
      );
    }
  }

  Future<bool> _savePngBytesToGallery(Uint8List bytes) async {
    final result = await ImageGallerySaverPlus.saveImage(
      bytes,
      quality: 100,
      name: 'kelivo-table-${DateTime.now().millisecondsSinceEpoch}',
    );
    if (result is Map) {
      final isSuccess = result['isSuccess'] == true || result['isSuccess'] == 1;
      final filePath = result['filePath'] ?? result['file_path'];
      return isSuccess || (filePath is String && filePath.isNotEmpty);
    }
    return false;
  }

  Future<void> _copyImage(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final bytes = await _captureTablePngBytes();
      if (bytes == null) throw 'render error';
      final ok = await _writePngToClipboard(bytes);
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: ok
            ? l10n.chatMessageWidgetCopiedToClipboard
            : l10n.messageExportSheetExportFailed('clipboard'),
        type: ok ? NotificationType.success : NotificationType.error,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportFailed('$e'),
        type: NotificationType.error,
      );
    }
  }

  Future<Uint8List?> _captureTablePngBytes() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _tableBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<File> _writeTableImageTempFile(Uint8List bytes) async {
    final dir = Directory.systemTemp;
    final file = File(
      p.join(
        dir.path,
        'kelivo-table-${DateTime.now().millisecondsSinceEpoch}.png',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<String?> _savePngBytes({
    required String dialogTitle,
    required String filename,
    required Uint8List bytes,
  }) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: const ['png'],
      );
      if (savePath == null) return null;
      await File(savePath).parent.create(recursive: true);
      await File(savePath).writeAsBytes(bytes, flush: true);
      return savePath;
    }

    return FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: const ['png'],
      bytes: bytes,
    );
  }

  Future<bool> _writePngToClipboard(Uint8List bytes) async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        final item = DataWriterItem(suggestedName: 'kelivo-table.png');
        item.add(Formats.png(bytes));
        await clipboard.write([item]);
        return true;
      }
    } catch (_) {}

    try {
      final file = await _writeTableImageTempFile(bytes);
      return await ClipboardImages.setImagePath(file.path);
    } catch (_) {
      return false;
    }
  }
}

class _MarkdownTableCell extends StatelessWidget {
  const _MarkdownTableCell({
    required this.data,
    required this.header,
    required this.style,
    required this.config,
    required this.appFontFamily,
    required this.selectable,
  });

  final _MarkdownTableCellData data;
  final bool header;
  final TextStyle style;
  final GptMarkdownConfig config;
  final String? appFontFamily;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseStyle = style.copyWith(
      fontSize: header ? 13.0 : 13.5,
      height: 1.42,
      fontWeight: header ? AppFontWeights.semibold : AppFontWeights.regular,
      color: header ? cs.onSurface : cs.onSurface.withValues(alpha: 0.90),
      fontFamily: appFontFamily ?? style.fontFamily,
    );
    final innerCfg = config.copyWith(style: baseStyle);
    final cellText = data.text.trim().replaceAll(_codeDollarMask, r'$');
    final displayText = _softBreakTableCellText(cellText);
    final spans = MarkdownComponent.generate(
      context,
      displayText,
      innerCfg,
      true,
    );
    final textSpan = TextSpan(style: baseStyle, children: spans);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Align(
        alignment: _alignmentFor(data.alignment),
        child: selectable
            ? SelectableText.rich(textSpan, textAlign: data.alignment)
            : RichText(
                text: textSpan,
                textAlign: data.alignment,
                softWrap: true,
                overflow: TextOverflow.visible,
                textWidthBasis: TextWidthBasis.parent,
              ),
      ),
    );
  }

  Alignment _alignmentFor(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }

  String _softBreakTableCellText(String input) {
    return input.replaceAllMapped(RegExp(r'[^\s/\\-]{22,}'), (match) {
      final value = match.group(0)!;
      final buffer = StringBuffer();
      for (var i = 0; i < value.length; i++) {
        buffer.write(value[i]);
        if ((i + 1) % 18 == 0 && i != value.length - 1) {
          buffer.write('\u200B');
        }
      }
      return buffer.toString();
    });
  }
}

class _MarkdownTableToolbar extends StatelessWidget {
  const _MarkdownTableToolbar({
    required this.label,
    required this.backgroundColor,
    required this.copyLabel,
    required this.exportLabel,
    required this.imageActionLabel,
    required this.onCopy,
    required this.onCopyImage,
    required this.onExport,
    required this.onExportImage,
    required this.onImageAction,
  });

  final String label;
  final Color backgroundColor;
  final String copyLabel;
  final String exportLabel;
  final String imageActionLabel;
  final VoidCallback onCopy;
  final VoidCallback onCopyImage;
  final VoidCallback onExport;
  final VoidCallback onExportImage;
  final VoidCallback onImageAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 38,
      padding: const EdgeInsetsDirectional.only(start: 12, end: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.20 : 0.28),
            width: 0.6,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.80),
                fontSize: 12,
                fontWeight: AppFontWeights.semibold,
                height: 1.0,
              ),
            ),
          ),
          Tooltip(
            message: copyLabel,
            child: IosIconButton(
              icon: Lucide.Copy,
              semanticLabel: copyLabel,
              onTap: onCopy,
              onLongPress: onCopyImage,
              size: 15,
              minSize: 32,
              padding: const EdgeInsets.all(7),
              color: cs.onSurfaceVariant.withValues(alpha: 0.68),
            ),
          ),
          Tooltip(
            message: imageActionLabel,
            child: IosIconButton(
              icon: Lucide.ImageDown,
              semanticLabel: imageActionLabel,
              onTap: onImageAction,
              onLongPress: onExportImage,
              size: 15,
              minSize: 32,
              padding: const EdgeInsets.all(7),
              color: cs.onSurfaceVariant.withValues(alpha: 0.68),
            ),
          ),
          Tooltip(
            message: exportLabel,
            child: IosIconButton(
              icon: Lucide.Download,
              semanticLabel: exportLabel,
              onTap: onExport,
              size: 15,
              minSize: 32,
              padding: const EdgeInsets.all(7),
              color: cs.onSurfaceVariant.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownTableData {
  const _MarkdownTableData({required this.rows, required this.columnCount});

  final List<_MarkdownTableRowData> rows;
  final int columnCount;

  factory _MarkdownTableData.fromRows(
    List<CustomTableRow> sourceRows, {
    int? maxBodyRows,
  }) {
    var columnCount = 0;
    final visibleSourceRows = _limitStreamingRows(
      sourceRows,
      maxBodyRows: maxBodyRows,
    );
    for (final row in visibleSourceRows) {
      if (row.fields.length > columnCount) columnCount = row.fields.length;
    }

    final normalizedRows = visibleSourceRows
        .map((row) {
          final cells = <_MarkdownTableCellData>[];
          for (var i = 0; i < columnCount; i++) {
            final field = i < row.fields.length ? row.fields[i] : null;
            cells.add(
              _MarkdownTableCellData(
                text: field?.data ?? '',
                alignment: field?.alignment ?? TextAlign.left,
              ),
            );
          }
          return _MarkdownTableRowData(cells);
        })
        .toList(growable: false);

    return _MarkdownTableData(rows: normalizedRows, columnCount: columnCount);
  }

  static List<CustomTableRow> _limitStreamingRows(
    List<CustomTableRow> sourceRows, {
    required int? maxBodyRows,
  }) {
    if (maxBodyRows == null || maxBodyRows < 1) return sourceRows;
    if (sourceRows.length <= maxBodyRows + 1) return sourceRows;
    return sourceRows.take(maxBodyRows + 1).toList(growable: false);
  }

  String toCsv() => _rowsToCsv(
    rows.map((row) => row.cells.map((c) => c.text).toList()).toList(),
  );

  String toMarkdown() => _rowsToMarkdown(
    rows.map((row) => row.cells.map((c) => c.text).toList()).toList(),
  );
}

class _MarkdownTableRowData {
  const _MarkdownTableRowData(this.cells);

  final List<_MarkdownTableCellData> cells;
}

class _MarkdownTableCellData {
  const _MarkdownTableCellData({required this.text, required this.alignment});

  final String text;
  final TextAlign alignment;
}

String _rowsToCsv(List<List<String>> rows) {
  return rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
}

bool _markdownTableTargetPlatformIsDesktop() {
  final override = markdownTableTargetPlatformOverride;
  if (override != null) {
    return override == TargetPlatform.macOS ||
        override == TargetPlatform.windows ||
        override == TargetPlatform.linux;
  }
  return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}

String _rowsToMarkdown(List<List<String>> rows) {
  if (rows.isEmpty) return '';
  final columnCount = rows.fold<int>(
    0,
    (count, row) => math.max(count, row.length),
  );
  if (columnCount == 0) return '';

  final normalizedRows = rows
      .map(
        (row) => List<String>.generate(
          columnCount,
          (index) => index < row.length ? _markdownTableCell(row[index]) : '',
          growable: false,
        ),
      )
      .toList(growable: false);
  final buffer = StringBuffer();
  buffer.writeln(_markdownTableLine(normalizedRows.first));
  buffer.writeln(_markdownTableLine(List.filled(columnCount, '---')));
  for (final row in normalizedRows.skip(1)) {
    buffer.writeln(_markdownTableLine(row));
  }
  return buffer.toString().trimRight();
}

String _markdownTableLine(List<String> cells) => '| ${cells.join(' | ')} |';

String _markdownTableCell(String value) {
  return value
      .trim()
      .replaceAll('\\', r'\\')
      .replaceAll('|', r'\|')
      .replaceAll('\r\n', '<br>')
      .replaceAll('\n', '<br>')
      .replaceAll('\r', '<br>');
}

String _csvCell(String value) {
  if (!value.contains(',') &&
      !value.contains('"') &&
      !value.contains('\n') &&
      !value.contains('\r')) {
    return value;
  }
  return '"${value.replaceAll('"', '""')}"';
}

class _MermaidBlock extends StatefulWidget {
  final String code;
  final bool streaming;
  const _MermaidBlock({required this.code, required this.streaming});

  @override
  State<_MermaidBlock> createState() => _MermaidBlockState();
}

enum _MermaidTab { image, code }

class _MermaidBlockState extends State<_MermaidBlock> {
  static const Duration _streamingBitmapRenderDelay = Duration(
    milliseconds: 360,
  );
  static const Duration _settledBitmapRenderDelay = Duration(milliseconds: 220);
  static const double _previewHeight = 406;

  _MermaidTab _selectedTab = _MermaidTab.image;
  late final ScrollController _vMermaidScrollController;
  OverlayEntry? _renderOverlayEntry;
  bool _renderQueued = false;
  bool _renderingBitmap = false;
  String? _renderKey;
  Uint8List? _lastRenderedBytes;
  Timer? _streamingRenderDebounce;
  bool _bitmapRenderingUnsupported = false;
  bool _suppressBitmapLoading = false;
  final Set<String> _failedBitmapRenderKeys = <String>{};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final mermaidColors = _MermaidBlockColors.resolve(isDark);

    // Build theme variables mapping for Mermaid from Material ColorScheme
    String hex(Color c) {
      final v = c.toARGB32();
      final r = (v >> 16) & 0xFF;
      final g = (v >> 8) & 0xFF;
      final b = v & 0xFF;
      return '#'
              '${r.toRadixString(16).padLeft(2, '0')}'
              '${g.toRadixString(16).padLeft(2, '0')}'
              '${b.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();
    }

    final themeVars = <String, String>{
      'primaryColor': hex(cs.primary),
      'primaryTextColor': hex(cs.onPrimary),
      'primaryBorderColor': hex(cs.primary),
      'secondaryColor': hex(cs.secondary),
      'secondaryTextColor': hex(cs.onSecondary),
      'secondaryBorderColor': hex(cs.secondary),
      'tertiaryColor': hex(cs.tertiary),
      'tertiaryTextColor': hex(cs.onTertiary),
      'tertiaryBorderColor': hex(cs.tertiary),
      'background': hex(cs.surface),
      'mainBkg': hex(cs.primaryContainer),
      'secondBkg': hex(cs.secondaryContainer),
      'lineColor': hex(cs.onSurface),
      'textColor': hex(cs.onSurface),
      'nodeBkg': hex(cs.surface),
      'nodeBorder': hex(cs.primary),
      'clusterBkg': hex(cs.surface),
      'clusterBorder': hex(cs.primary),
      'actorBorder': hex(cs.primary),
      'actorBkg': hex(cs.surface),
      'actorTextColor': hex(cs.onSurface),
      'actorLineColor': hex(cs.primary),
      'taskBorderColor': hex(cs.primary),
      'taskBkgColor': hex(cs.primary),
      'taskTextLightColor': hex(cs.onPrimary),
      'taskTextDarkColor': hex(cs.onSurface),
      'labelColor': hex(cs.onSurface),
      'errorBkgColor': hex(cs.error),
      'errorTextColor': hex(cs.onError),
    };

    final exporting = ExportCaptureScope.of(context);
    final cacheKey = _mermaidCacheKey(widget.code, isDark, themeVars);
    final themedCachedBytes = MermaidImageCache.get(cacheKey);
    final legacyCachedBytes = MermaidImageCache.get(widget.code);
    final prefixCachedBytes = widget.streaming
        ? _findCachedStreamingMermaidPrefix(
            widget.code,
            isDark: isDark,
            themeVars: themeVars,
          )
        : null;
    final exactCachedBytes = themedCachedBytes ?? legacyCachedBytes;
    final cachedBytes = exactCachedBytes ?? prefixCachedBytes;
    final displayBytes =
        cachedBytes ?? (widget.streaming ? _lastRenderedBytes : null);
    final actionBytes = cachedBytes ?? displayBytes;
    final renderFailedForCurrentCode = _failedBitmapRenderKeys.contains(
      cacheKey,
    );
    final hasRenderableCode = widget.code.trim().isNotEmpty;
    if (!exporting &&
        hasRenderableCode &&
        exactCachedBytes == null &&
        !_bitmapRenderingUnsupported &&
        !renderFailedForCurrentCode) {
      _scheduleBitmapRender(
        isDark: isDark,
        themeVars: themeVars,
        delay: widget.streaming
            ? _streamingBitmapRenderDelay
            : _settledBitmapRenderDelay,
      );
    }
    final hasImage = displayBytes != null && displayBytes.isNotEmpty;
    final showLoading =
        !hasImage &&
        !_suppressBitmapLoading &&
        !_bitmapRenderingUnsupported &&
        !renderFailedForCurrentCode &&
        (widget.streaming || _renderQueued || _renderingBitmap);
    final showError =
        !hasImage &&
        !_bitmapRenderingUnsupported &&
        renderFailedForCurrentCode &&
        _selectedTab == _MermaidTab.image;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: mermaidColors.body,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: mermaidColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: mermaidColors.header,
              border: Border(
                bottom: BorderSide(color: mermaidColors.border, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 16,
                      end: 10,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: mermaidColors.tabTrack,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _MermaidTabButton(
                                label: l10n.mermaidImageTab,
                                selected: _selectedTab == _MermaidTab.image,
                                colors: mermaidColors,
                                onTap: () {
                                  setState(
                                    () => _selectedTab = _MermaidTab.image,
                                  );
                                },
                              ),
                              _MermaidTabButton(
                                label: l10n.mermaidCodeTab,
                                selected: _selectedTab == _MermaidTab.code,
                                colors: mermaidColors,
                                onTap: () {
                                  setState(
                                    () => _selectedTab = _MermaidTab.code,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!exporting)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MermaidTextAction(
                          icon: Lucide.Copy,
                          label: l10n.shareProviderSheetCopyButton,
                          colors: mermaidColors,
                          onTap: () => _copyMermaidCode(context),
                        ),
                        const SizedBox(width: 4),
                        _MermaidTextAction(
                          icon: Lucide.Download,
                          label: l10n.mermaidExportPng,
                          colors: mermaidColors,
                          enabled:
                              actionBytes != null && actionBytes.isNotEmpty,
                          onTap: actionBytes == null || actionBytes.isEmpty
                              ? null
                              : () => _saveMermaidBytes(context, actionBytes),
                        ),
                        const SizedBox(width: 4),
                        _MermaidTextAction(
                          icon: Lucide.Maximize2,
                          label: l10n.mermaidFullScreen,
                          colors: mermaidColors,
                          enabled:
                              actionBytes != null && actionBytes.isNotEmpty,
                          onTap: actionBytes == null || actionBytes.isEmpty
                              ? null
                              : () => _openMermaidImageViewer(
                                  context,
                                  actionBytes,
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            key: const ValueKey('mermaid-preview-body'),
            width: double.infinity,
            height: _previewHeight,
            child: ColoredBox(
              color: mermaidColors.body,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return currentChild ?? const SizedBox.shrink();
                },
                child: _buildMermaidBody(
                  context: context,
                  isDark: isDark,
                  colors: mermaidColors,
                  displayBytes: displayBytes,
                  cacheKey: cacheKey,
                  showLoading: showLoading,
                  showError: showError,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMermaidBody({
    required BuildContext context,
    required bool isDark,
    required _MermaidBlockColors colors,
    required Uint8List? displayBytes,
    required String cacheKey,
    required bool showLoading,
    required bool showError,
  }) {
    if (_selectedTab == _MermaidTab.code ||
        _bitmapRenderingUnsupported ||
        widget.code.trim().isEmpty) {
      return _buildMermaidCodeView(context, isDark);
    }

    if (displayBytes != null && displayBytes.isNotEmpty) {
      return Padding(
        key: ValueKey<String>('mermaid-image-$cacheKey'),
        padding: const EdgeInsets.all(8),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openMermaidImageViewer(context, displayBytes),
            child: Image(image: MemoryImage(displayBytes), fit: BoxFit.contain),
          ),
        ),
      );
    }

    if (showLoading) {
      return _MermaidLoadingView(
        key: const ValueKey('mermaid-loading-body'),
        colors: colors,
      );
    }

    if (showError) {
      return _MermaidErrorView(
        key: const ValueKey('mermaid-error-body'),
        colors: colors,
      );
    }

    return _buildMermaidCodeView(context, isDark);
  }

  Widget _buildMermaidCodeView(BuildContext context, bool isDark) {
    final codeView = SelectableHighlightView(
      widget.code,
      language: 'plaintext',
      theme: _transparentBgTheme(
        isDark ? atomOneDarkReasonableTheme : githubTheme,
      ),
      padding: EdgeInsets.zero,
      textStyle: TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
    );

    return Padding(
      key: const ValueKey('mermaid-code-body'),
      padding: const EdgeInsets.all(12),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            ui.PointerDeviceKind.touch,
            ui.PointerDeviceKind.mouse,
            ui.PointerDeviceKind.stylus,
            ui.PointerDeviceKind.unknown,
          },
        ),
        child: Scrollbar(
          controller: _vMermaidScrollController,
          thumbVisibility: true,
          interactive: true,
          notificationPredicate: (notif) => notif.metrics.axis == Axis.vertical,
          child: SingleChildScrollView(
            controller: _vMermaidScrollController,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: codeView,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _vMermaidScrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant _MermaidBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code ||
        oldWidget.streaming != widget.streaming) {
      _suppressBitmapLoading = false;
      if (!widget.streaming || oldWidget.streaming != widget.streaming) {
        _streamingRenderDebounce?.cancel();
        _renderQueued = false;
        _renderingBitmap = false;
        _removeRenderOverlay();
        _renderKey = null;
      }
    }
    if (widget.code.trim().isEmpty) {
      _lastRenderedBytes = null;
      _suppressBitmapLoading = false;
      _bitmapRenderingUnsupported = false;
      _failedBitmapRenderKeys.clear();
    }
  }

  @override
  void dispose() {
    _streamingRenderDebounce?.cancel();
    _removeRenderOverlay();
    _vMermaidScrollController.dispose();
    super.dispose();
  }

  void _scheduleBitmapRender({
    required bool isDark,
    required Map<String, String> themeVars,
    required Duration delay,
  }) {
    if (_renderQueued || _renderingBitmap) return;
    _renderQueued = true;
    _streamingRenderDebounce?.cancel();
    _streamingRenderDebounce = Timer(delay, () {
      _renderQueued = false;
      if (!mounted) return;
      _renderBitmap(isDark: isDark, themeVars: themeVars);
    });
  }

  Future<void> _renderBitmap({
    required bool isDark,
    required Map<String, String> themeVars,
  }) async {
    final code = widget.code;
    final cacheKey = _mermaidCacheKey(code, isDark, themeVars);
    if (MermaidImageCache.get(cacheKey) != null) return;
    final renderOverride = debugMermaidBitmapRenderOverride;
    final overlay = renderOverride == null ? Overlay.maybeOf(context) : null;
    if (renderOverride == null && overlay == null) {
      _markBitmapRenderingUnsupported(cacheKey);
      return;
    }
    setState(() {
      _renderKey = cacheKey;
      _renderingBitmap = true;
    });

    MermaidBitmapRenderResult result = MermaidBitmapRenderResult.failed();
    try {
      result = renderOverride == null
          ? await _renderMermaidBitmapWithOverlay(
              overlay!,
              code,
              isDark,
              themeVars,
            )
          : await renderOverride(code, isDark, themeVars);
      if (!mounted || _renderKey != cacheKey) return;
      final bytes = result.bytes;
      if (result.status == MermaidBitmapRenderStatus.success &&
          bytes != null &&
          bytes.isNotEmpty) {
        MermaidImageCache.put(cacheKey, bytes);
        _failedBitmapRenderKeys.remove(cacheKey);
      }
    } catch (e, st) {
      debugPrint('Mermaid bitmap render failed: $e\n$st');
    } finally {
      if (mounted && _renderKey == cacheKey) {
        _removeRenderOverlay();
        setState(() {
          if (result.status == MermaidBitmapRenderStatus.success &&
              result.bytes != null &&
              result.bytes!.isNotEmpty) {
            _lastRenderedBytes = result.bytes;
          } else if (result.status == MermaidBitmapRenderStatus.unsupported) {
            _bitmapRenderingUnsupported = true;
            _suppressBitmapLoading = true;
          } else {
            _failedBitmapRenderKeys.add(cacheKey);
            _suppressBitmapLoading = true;
          }
          _renderingBitmap = false;
        });
      }
    }
  }

  Future<MermaidBitmapRenderResult> _renderMermaidBitmapWithOverlay(
    OverlayState overlay,
    String code,
    bool isDark,
    Map<String, String> themeVars,
  ) async {
    _removeRenderOverlay();
    final renderKey = GlobalKey();
    final handle = createMermaidView(
      code,
      isDark,
      themeVars: themeVars,
      viewKey: renderKey,
    );
    if (handle == null) return MermaidBitmapRenderResult.unsupported();

    _renderOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000,
        top: -10000,
        child: ConstrainedBox(
          constraints: const BoxConstraints.tightFor(width: 720, height: 600),
          child: Material(color: Colors.transparent, child: handle.widget),
        ),
      ),
    );
    overlay.insert(_renderOverlayEntry!);

    return _captureMermaidBitmap(handle);
  }

  void _markBitmapRenderingUnsupported(String cacheKey) {
    if (!mounted) return;
    _streamingRenderDebounce?.cancel();
    _removeRenderOverlay();
    setState(() {
      if (_renderKey == null || _renderKey == cacheKey) {
        _renderKey = null;
        _renderQueued = false;
        _renderingBitmap = false;
      }
      _bitmapRenderingUnsupported = true;
    });
  }

  Uint8List? _findCachedStreamingMermaidPrefix(
    String code, {
    required bool isDark,
    required Map<String, String> themeVars,
  }) {
    final lines = code.split('\n');
    for (var end = lines.length - 1; end >= 1; end--) {
      final candidate = lines.take(end).join('\n').trimRight();
      if (candidate.isEmpty) continue;
      final themed = MermaidImageCache.get(
        _mermaidCacheKey(candidate, isDark, themeVars),
      );
      final legacy = MermaidImageCache.get(candidate);
      final bytes = themed ?? legacy;
      if (bytes != null && bytes.isNotEmpty) {
        _lastRenderedBytes = bytes;
        return bytes;
      }
    }
    return null;
  }

  Future<MermaidBitmapRenderResult> _captureMermaidBitmap(
    MermaidViewHandle handle,
  ) async {
    final exportBytes = handle.exportPngBytes;
    if (exportBytes == null) return MermaidBitmapRenderResult.unsupported();
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    for (var i = 0; i < 4; i++) {
      try {
        final bytes = await exportBytes().timeout(
          const Duration(milliseconds: 900),
          onTimeout: () => null,
        );
        if (bytes != null && bytes.isNotEmpty) {
          return MermaidBitmapRenderResult.success(bytes);
        }
      } catch (e) {
        if (e is UnsupportedError) {
          return MermaidBitmapRenderResult.unsupported();
        }
        // Mermaid/WebView can report readiness before pixel capture is available.
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return MermaidBitmapRenderResult.failed();
  }

  Future<void> _copyMermaidCode(BuildContext context) async {
    final copiedMessage = AppLocalizations.of(
      context,
    )!.chatMessageWidgetCopiedToClipboard;
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: copiedMessage,
      type: NotificationType.success,
    );
  }

  Future<void> _saveMermaidBytes(BuildContext context, Uint8List bytes) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _saveCachedMermaidPng(bytes);
    if (!context.mounted) return;
    if (!ok) {
      showAppSnackBar(
        context,
        message: l10n.mermaidExportFailed,
        type: NotificationType.error,
      );
    } else if (Platform.isAndroid || Platform.isIOS) {
      showAppSnackBar(
        context,
        message: l10n.imageViewerPageSaveSuccess,
        type: NotificationType.success,
      );
    }
  }

  void _openMermaidImageViewer(BuildContext context, Uint8List bytes) {
    final src = 'data:image/png;base64,${base64Encode(bytes)}';
    final provider = MemoryImage(bytes);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            ImageViewerPage(images: [src], imageProviders: {src: provider}),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        transitionsBuilder: (context, anim, sec, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }

  void _removeRenderOverlay() {
    try {
      _renderOverlayEntry?.remove();
    } catch (_) {}
    _renderOverlayEntry = null;
  }

  Future<bool> _saveCachedMermaidPng(Uint8List bytes) async {
    try {
      final l10n = AppLocalizations.of(context)!;
      final suggested = 'mermaid_${DateTime.now().millisecondsSinceEpoch}.png';
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: l10n.backupPageExportToFile,
          fileName: suggested,
          type: FileType.custom,
          allowedExtensions: const ['png'],
        );
        if (savePath == null || savePath.isEmpty) return false;
        await File(savePath).parent.create(recursive: true);
        await File(savePath).writeAsBytes(bytes);
        return true;
      }
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: 'kelivo-mermaid-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (result is Map) {
        final isSuccess =
            result['isSuccess'] == true || result['isSuccess'] == 1;
        final filePath = result['filePath'] ?? result['file_path'];
        return isSuccess || (filePath is String && filePath.isNotEmpty);
      }
    } catch (_) {}
    return false;
  }
}

class _MermaidBlockColors {
  const _MermaidBlockColors({
    required this.body,
    required this.header,
    required this.border,
    required this.tabTrack,
    required this.tabSelected,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  final Color body;
  final Color header;
  final Color border;
  final Color tabTrack;
  final Color tabSelected;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  static _MermaidBlockColors resolve(bool isDark) {
    if (isDark) {
      return const _MermaidBlockColors(
        body: Color(0xFF212121),
        header: Color(0xFF303030),
        border: Color(0xFF383838),
        tabTrack: Color(0xF2212121),
        tabSelected: Color(0xFF333333),
        textPrimary: Color(0xFFE6E6E6),
        textSecondary: Color(0xFFA0A0A0),
        textTertiary: Color(0xFF707070),
      );
    }

    return const _MermaidBlockColors(
      body: Color(0xFFF8F8F8),
      header: Color(0xFFEDEDED),
      border: Color(0xFFE0E0E0),
      tabTrack: Color(0xCCD9D9D9),
      tabSelected: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF261208),
      textSecondary: Color(0xFF46352B),
      textTertiary: Color(0xFF5B4C43),
    );
  }
}

class _MermaidTabButton extends StatefulWidget {
  const _MermaidTabButton({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final _MermaidBlockColors colors;
  final VoidCallback onTap;

  @override
  State<_MermaidTabButton> createState() => _MermaidTabButtonState();
}

class _MermaidTabButtonState extends State<_MermaidTabButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.selected
        ? widget.colors.tabSelected
        : Colors.transparent;
    final hoverColor = Color.alphaBlend(
      widget.colors.textPrimary.withValues(alpha: _pressed ? 0.10 : 0.06),
      baseColor,
    );
    final bg = widget.selected || _pressed || _hovered
        ? hoverColor
        : Colors.transparent;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectionContainer.disabled(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: widget.selected
                      ? AppFontWeights.semibold
                      : AppFontWeights.medium,
                  color: widget.selected
                      ? widget.colors.textPrimary
                      : widget.colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MermaidTextAction extends StatelessWidget {
  const _MermaidTextAction({
    required this.icon,
    required this.label,
    required this.colors,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final _MermaidBlockColors colors;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    final color = colors.textSecondary.withValues(alpha: active ? 0.88 : 0.38);

    return Tooltip(
      message: label,
      child: IosIconButton(
        onTap: onTap,
        enabled: active,
        semanticLabel: label,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        builder: (buttonColor) => Icon(icon, size: 14, color: buttonColor),
      ),
    );
  }
}

class _MermaidLoadingView extends StatefulWidget {
  const _MermaidLoadingView({super.key, required this.colors});

  final _MermaidBlockColors colors;

  @override
  State<_MermaidLoadingView> createState() => _MermaidLoadingViewState();
}

class _MermaidLoadingViewState extends State<_MermaidLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _controller,
            child: Icon(
              Lucide.Loader,
              size: 24,
              color: widget.colors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.mermaidGeneratingImage,
            style: TextStyle(
              fontSize: 14,
              height: 1.3,
              color: widget.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MermaidErrorView extends StatelessWidget {
  const _MermaidErrorView({super.key, required this.colors});

  final _MermaidBlockColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Lucide.ImageOff, size: 48, color: colors.textTertiary),
          const SizedBox(height: 8),
          Text(
            l10n.mermaidGenerationFailedHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// Full-width horizontal rule with softer color
class SoftHrLine extends BlockMd {
  @override
  String get expString => (r"^\s*(?:-{3,}|⸻)\s*$");

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.outlineVariant.withValues(alpha: 0.4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        width: double.infinity,
        height: 1,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// Robust fenced code block that takes precedence over other blocks
class FencedCodeBlockMd extends BlockMd {
  FencedCodeBlockMd({required this.streaming});

  final bool streaming;

  @override
  RegExp get exp => RegExp(expString, dotAll: true, multiLine: true);

  @override
  // CommonMark-style fences:
  // - fence length is variable (>= 3)
  // - closing fence must use the same marker and be >= opening length
  // - supports both ``` and ~~~
  String get expString =>
      (r"^[ \t]*(([`~])\2{2,})[ \t]*([^\n]*?)\n"
      r"(?:(?:([\s\S]*?)^[ \t]*\1\2*[ \t]*)|([\s\S]*))");

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    final m = exp.firstMatch(text);
    if (m == null) return const SizedBox.shrink();
    final lang = (m.group(3) ?? '').trim();
    final code = (m.group(4) ?? m.group(5) ?? '');
    final closed = m.group(4) != null;
    final langLower = lang.toLowerCase();
    final isStreamingFence = streaming && !closed;
    if (langLower == 'mermaid') {
      return _MermaidBlock(code: code, streaming: isStreamingFence);
    } else if (langLower == 'plantuml') {
      return PlantUMLBlock(code: code);
    }
    return _CollapsibleCodeBlock(
      language: lang,
      code: code,
      streaming: isStreamingFence,
      closed: closed,
    );
  }
}

/// Scrollable LaTeX block to prevent overflow when equations are very wide
class LatexBlockScrollableMd extends BlockMd {
  @override
  // Match either $$...$$ or \[...\] as standalone block
  String get expString =>
      (r"^(?:\s*\$\$([\s\S]*?)\$\$\s*|\s*\\\[([\s\S]*?)\\\]\s*)$");

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    final m = exp.firstMatch(text.trim());
    if (m == null) return const SizedBox.shrink();
    final body = ((m.group(1) ?? m.group(2) ?? '')).trim();
    if (body.isEmpty) return const SizedBox.shrink();

    final math = _renderMath(body, style: config.style, displayMode: true);
    // Wrap in horizontal scroll to avoid overflow and center within available width
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SelectionContainer.disabled(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              primary: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Center(child: math),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Inline LaTeX `$...$` rendered in the text flow.
class InlineLatexScrollableMd extends InlineMd {
  @override
  // Match single-dollar $...$ or \(...\) inline math (avoid $$ block)
  RegExp get exp => RegExp(
    r"(?:(?<!\$)\$([^\$\n]{1,"
    "$_maxInlineMathBodyLength"
    r"})\$(?!\$)|\\\(([^\n]{1,"
    "$_maxInlineMathBodyLength"
    r"}?)\\\))",
  );

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final m = exp.firstMatch(text);
    if (m == null) return TextSpan(text: text, style: config.style);
    final body = ((m.group(1) ?? m.group(2) ?? '')).trim();
    if (body.isEmpty) return TextSpan(text: text, style: config.style);
    final math = _renderMath(body, style: _inlineMathTextStyle(config.style));
    return _inlineMathSpan(math);
  }
}

/// Inline LaTeX for dollar delimiters only: `$...$`
class InlineLatexDollarScrollableMd extends InlineMd {
  @override
  RegExp get exp => RegExp(
    r"(^|[ \t\r\n(])(?<!\\)(?<!\$)\$((?:\\.|[^\$\\\n|]){1,"
    "$_maxInlineMathBodyLength"
    r"})\$(?!\$)(?![A-Za-z0-9])",
  );

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final m = exp.firstMatch(text);
    if (m == null) return TextSpan(text: text, style: config.style);
    final prefix = m.group(1) ?? '';
    final body = (m.group(2) ?? '').trim();
    if (body.isEmpty) return TextSpan(text: text, style: config.style);
    if (!_isValidDollarMathBody(m.group(2) ?? '')) {
      return TextSpan(text: text, style: config.style);
    }
    final math = _renderMath(body, style: _inlineMathTextStyle(config.style));
    return TextSpan(
      style: config.style,
      children: [
        if (prefix.isNotEmpty) TextSpan(text: prefix, style: config.style),
        _inlineMathSpan(math),
      ],
    );
  }
}

/// Inline LaTeX for parenthesis delimiters only: `\(...\)`
class InlineLatexParenScrollableMd extends InlineMd {
  @override
  RegExp get exp => RegExp(
    r"(?:\\\(([^\n]{1,"
    "$_maxInlineMathBodyLength"
    r"}?)\\\))",
  );

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final m = exp.firstMatch(text);
    if (m == null) return TextSpan(text: text, style: config.style);
    final body = (m.group(1) ?? '').trim();
    if (body.isEmpty) return TextSpan(text: text, style: config.style);
    final math = _renderMath(body, style: _inlineMathTextStyle(config.style));
    return _inlineMathSpan(math);
  }
}

// Balanced ATX-style headings (#, ##, ###, …) with consistent spacing and typography
class AtxHeadingMd extends BlockMd {
  @override
  // Restrict heading content to a single line to avoid swallowing
  // subsequent blocks (e.g., fenced code) when the engine builds
  // the regex with dotAll=true. Using [^\n]+ keeps it line-bound.
  String get expString => (r"^\s{0,3}(#{1,6})\s+([^\n]+?)(?:\s+#+\s*)?$");

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    final m = exp.firstMatch(text.trim());
    if (m == null) return const SizedBox.shrink();
    final hashes = m.group(1) ?? '#';
    final raw = (m.group(2) ?? '').trim();
    final lvl = hashes.length;
    final level = lvl < 1 ? 1 : (lvl > 6 ? 6 : lvl);

    final innerCfg = config.copyWith(style: TextStyle());
    final inner = TextSpan(
      children: MarkdownComponent.generate(context, raw, innerCfg, true),
    );
    final style = _headingTextStyle(context, config, level);
    // Slightly tighter spacing between headings and body
    final top = switch (level) {
      1 => 2.0,
      2 => 2.0,
      _ => 2.0,
    };
    final bottom = switch (level) {
      1 => 2.0,
      2 => 2.0,
      3 => 2.0,
      _ => 2.0,
    };

    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: DefaultTextStyle.merge(
        // Use selection-aware renderer from config so headings can be selected/copied
        style: style,
        child: config.getRich(inner),
      ),
    );
  }

  TextStyle _headingTextStyle(
    BuildContext ctx,
    GptMarkdownConfig cfg,
    int level,
  ) {
    final cs = Theme.of(ctx).colorScheme;
    final isZh = _isZh(ctx);
    final settings = ctx.read<SettingsProvider>();
    String? appFamily;
    if ((settings.appFontFamily ?? '').isNotEmpty) {
      appFamily = settings.appFontFamily;
      if (settings.appFontIsGoogle) {
        try {
          final s = GoogleFonts.getFont(appFamily!);
          appFamily = s.fontFamily ?? appFamily;
        } catch (_) {}
      }
    }
    // Start from Material styles but tighten sizes for balance with body text
    TextStyle base;
    // Explicit sizes ensure visible contrast over the body (16.0)
    switch (level) {
      case 1:
        base = TextStyle(fontSize: 24);
        break;
      case 2:
        base = TextStyle(fontSize: 20);
        break;
      case 3:
        base = TextStyle(fontSize: 18);
        break;
      case 4:
        base = TextStyle(fontSize: 16);
        break;
      case 5:
        base = TextStyle(fontSize: 15);
        break;
      default:
        base = TextStyle(fontSize: 14);
    }
    final weight = switch (level) {
      1 => AppFontWeights.strong,
      2 => AppFontWeights.semibold,
      3 => AppFontWeights.semibold,
      _ => AppFontWeights.medium,
    };
    final ls = switch (level) {
      1 => isZh ? 0.0 : 0.1,
      2 => isZh ? 0.0 : 0.08,
      _ => isZh ? 0.0 : 0.05,
    };
    final h = switch (level) {
      1 => 1.25,
      2 => 1.3,
      _ => 1.35,
    };
    return base.copyWith(
      fontWeight: weight,
      height: h,
      letterSpacing: ls,
      color: cs.onSurface,
      fontFamily: appFamily,
      fontFamilyFallback: getPlatformFontFallback(),
    );
  }
}

// Setext-style headings (underlines with === or ---)
class SetextHeadingMd extends BlockMd {
  @override
  String get expString => (r"^(.+?)\n(=+|-+)\s*$");

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    final m = exp.firstMatch(text.trimRight());
    if (m == null) return const SizedBox.shrink();
    final title = (m.group(1) ?? '').trim();
    final underline = (m.group(2) ?? '').trim();
    final level = underline.startsWith('=') ? 1 : 2;

    final innerCfg = config.copyWith(style: TextStyle());
    final inner = TextSpan(
      children: MarkdownComponent.generate(context, title, innerCfg, true),
    );
    final style = AtxHeadingMd()._headingTextStyle(context, config, level);
    // Match the tighter spacing used in ATX headings
    final top = level == 1 ? 10.0 : 9.0;
    final bottom = 6.0;

    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: DefaultTextStyle.merge(
        // Use selection-aware renderer from config so headings can be selected/copied
        style: style,
        child: config.getRich(inner),
      ),
    );
  }
}

// Label-value strong lines like "**作者:** 张三" should not render as heading-sized text
class LabelValueLineMd extends InlineMd {
  @override
  // Treat this as an inline transform so it only affects the matched
  // line segment and does not interfere with block parsing.
  bool get inline => false;

  @override
  // 同时匹配两种写法：
  // 1) **标签:** 值   （冒号在加粗内）
  // 2) **标签**: 值   （冒号在加粗外）
  // 支持半角/全角冒号
  RegExp get exp =>
      RegExp(r"(?:(?:^|\n)\*\*([^*]+?)\*\*\s*[：:]?\s+(.+)$)", multiLine: true);

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final match = exp.firstMatch(text);
    if (match == null) return TextSpan(text: text, style: config.style);

    // 提取并规范化标签与值
    var rawLabel = (match.group(1) ?? '').trim();
    final value = (match.group(2) ?? '').trim();
    // 如果标签末尾自带冒号，去掉以避免重复
    rawLabel = rawLabel.replaceFirst(RegExp(r"[：:]+$"), '');

    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    // 继承基础样式，确保字间距/行高一致
    final base = (config.style ?? t.bodyMedium ?? TextStyle(fontSize: 14));
    final labelStyle = base.copyWith(
      fontWeight: AppFontWeights.strong,
      color: cs.onSurface,
    );
    final valueStyle = base.copyWith(
      fontWeight: AppFontWeights.regular,
      color: cs.onSurface.withValues(alpha: 0.92),
    );

    // 将值部分继续按 markdown 解析，保证链接/引用等语法正常
    final valueChildren = MarkdownComponent.generate(
      context,
      value,
      config.copyWith(style: valueStyle),
      true,
    );

    // 返回 TextSpan（而非 WidgetSpan）以保证在外层 RichText/SelectionArea 中可选择复制
    return TextSpan(
      children: [
        TextSpan(text: rawLabel, style: labelStyle),
        const TextSpan(text: '： '),
        ...valueChildren,
      ],
    );
  }
}

// Minimal block quote with a neutral rounded leading line.
class ModernBlockQuote extends InlineMd {
  @override
  bool get inline => false;

  @override
  RegExp get exp =>
      RegExp(r"^[ \t]*>[^\n]*(?:\n[ \t]*>[^\n]*)*", multiLine: true);

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final match = exp.firstMatch(text);
    final m = match?[0] ?? '';
    final sb = StringBuffer();
    for (final line in m.split('\n')) {
      if (RegExp(r'^[ \t]*>').hasMatch(line)) {
        var sub = line.trimLeft();
        sub = sub.substring(1); // remove '>'
        if (sub.startsWith(' ')) sub = sub.substring(1);
        sb.writeln(sub);
      } else {
        sb.writeln(line);
      }
    }
    final data = _unmaskBlockquoteFenceMarkers(sb.toString().trim());
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final lineColor = cs.onSurfaceVariant.withValues(
      alpha: isDark ? 0.48 : 0.36,
    );
    final innerComponents =
        (config.components ?? MarkdownComponent.globalComponents)
            .where((component) => component is! CodeBlockMd)
            .map((component) {
              if (component is FencedCodeBlockMd) {
                return FencedCodeBlockMd(streaming: false);
              }
              return component;
            })
            .toList(growable: false);
    final innerMarkdown = _BlockquoteMarkdownContent(
      data: data,
      config: config,
      components: innerComponents,
    );
    final child = Directionality(
      textDirection: config.textDirection,
      child: Container(
        key: const ValueKey('markdown-blockquote'),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Stack(
          children: [
            PositionedDirectional(
              start: 0,
              top: 2,
              bottom: 2,
              width: 3,
              child: DecoratedBox(
                key: const ValueKey('markdown-blockquote-line'),
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 13,
                top: 2,
                bottom: 2,
              ),
              child: innerMarkdown,
            ),
          ],
        ),
      ),
    );

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: child,
    );
  }
}

class _BlockquoteMarkdownContent extends StatelessWidget {
  const _BlockquoteMarkdownContent({
    required this.data,
    required this.config,
    required this.components,
  });

  final String data;
  final GptMarkdownConfig config;
  final List<MarkdownComponent> components;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final textBuffer = StringBuffer();
    final lines = data.split('\n');

    void flushText() {
      final text = textBuffer.toString().trim();
      if (text.isEmpty) {
        textBuffer.clear();
        return;
      }
      children.add(_buildMarkdown(text));
      textBuffer.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final open = RegExp(
        r'^[ \t]*(([`~])\2{2,})[ \t]*([^\n]*)$',
      ).firstMatch(line);
      if (open == null) {
        textBuffer.writeln(line);
        continue;
      }

      flushText();
      final fence = open.group(1)!;
      final marker = open.group(2)!;
      final language = (open.group(3) ?? '').trim();
      final codeBuffer = StringBuffer();
      var closed = false;

      i++;
      while (i < lines.length) {
        final current = lines[i];
        final close = RegExp(
          '^${RegExp.escape(fence)}${RegExp.escape(marker)}*[ \\t]*\$',
        ).hasMatch(current.trimRight());
        if (close) {
          closed = true;
          break;
        }
        codeBuffer.writeln(current);
        i++;
      }

      children.add(
        _CollapsibleCodeBlock(
          language: language,
          code: codeBuffer.toString(),
          streaming: false,
          closed: closed,
        ),
      );
    }

    flushText();
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildMarkdown(String text) {
    return GptMarkdown(
      text,
      style: config.style,
      textDirection: config.textDirection,
      textAlign: config.textAlign,
      textScaler: config.textScaler,
      onLinkTap: config.onLinkTap,
      latexWorkaround: config.latexWorkaround,
      latexBuilder: config.latexBuilder,
      codeBuilder: config.codeBuilder,
      sourceTagBuilder: config.sourceTagBuilder,
      highlightBuilder: config.highlightBuilder,
      linkBuilder: config.linkBuilder,
      imageBuilder: config.imageBuilder,
      orderedListBuilder: config.orderedListBuilder,
      unOrderedListBuilder: config.unOrderedListBuilder,
      tableBuilder: config.tableBuilder,
      components: components,
      inlineComponents: config.inlineComponents,
      followLinkColor: config.followLinkColor,
      useDollarSignsForLatex: false,
    );
  }
}

// Modern task checkbox: square with subtle border, primary check on done
class ModernCheckBoxMd extends BlockMd {
  @override
  String get expString => (r"\[((?:\x|\ ))\]\ (\S[^\n]*?)$");

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    final match = exp.firstMatch(text.trim());
    final checked = (match?[1] == 'x');
    final content = match?[2] ?? '';
    final cs = Theme.of(context).colorScheme;

    final contentStyle = (config.style ?? TextStyle()).copyWith(
      decoration: checked ? TextDecoration.lineThrough : null,
      color: (config.style?.color ?? cs.onSurface).withValues(
        alpha: checked ? 0.75 : 1.0,
      ),
    );

    final child = MdWidget(
      context,
      content,
      false,
      config: config.copyWith(style: contentStyle),
    );

    return Directionality(
      textDirection: config.textDirection,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textBaseline: TextBaseline.alphabetic,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, end: 8),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.8),
                  width: 1,
                ),
                color: checked
                    ? cs.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: checked
                  ? Icon(Icons.check, size: 14, color: cs.primary)
                  : null,
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

// Modern radio (optional): circle with primary dot when selected
class ModernRadioMd extends BlockMd {
  @override
  String get expString => (r"\(((?:\x|\ ))\)\ (\S[^\n]*)$");

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    final match = exp.firstMatch(text.trim());
    final selected = (match?[1] == 'x');
    final content = match?[2] ?? '';
    final cs = Theme.of(context).colorScheme;

    final contentStyle = (config.style ?? TextStyle()).copyWith(
      color: (config.style?.color ?? cs.onSurface).withValues(
        alpha: selected ? 0.95 : 1.0,
      ),
    );

    final child = MdWidget(
      context,
      content,
      false,
      config: config.copyWith(style: contentStyle),
    );

    return Directionality(
      textDirection: config.textDirection,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textBaseline: TextBaseline.alphabetic,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, end: 8),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.8),
                  width: 1,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

class EscapeAwareTableMd extends TableMd {
  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    final value = text
        .trim()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map<Map<int, String>>(
          (line) => _splitMarkdownTableLine(line.trim()).asMap(),
        )
        .toList();

    if (value.isEmpty) return Text('', style: config.style);

    final hasHeader = value.length >= 2;
    final columnAlignments = <TextAlign>[];

    if (hasHeader) {
      final separatorRow = value[1];
      for (var index = 0; index < separatorRow.length; index++) {
        final separator = (separatorRow[index] ?? '').trim();
        final hasLeftColon = separator.startsWith(':');
        final hasRightColon = separator.endsWith(':');

        if (hasLeftColon && hasRightColon) {
          columnAlignments.add(TextAlign.center);
        } else if (hasRightColon) {
          columnAlignments.add(TextAlign.right);
        } else {
          columnAlignments.add(TextAlign.left);
        }
      }
    }

    var maxCol = 0;
    for (final row in value) {
      if (maxCol < row.length) maxCol = row.length;
    }
    if (maxCol == 0) return Text('', style: config.style);

    while (columnAlignments.length < maxCol) {
      columnAlignments.add(TextAlign.left);
    }

    final tableBuilder = config.tableBuilder;
    if (tableBuilder == null) {
      return super.build(context, text, config);
    }

    final customTable = List<CustomTableRow?>.generate(value.length, (
      rowIndex,
    ) {
      if (hasHeader && rowIndex == 1) return null;
      final row = value[rowIndex];
      if (row.isEmpty) return null;

      final fields = List<CustomTableField>.generate(maxCol, (fieldIndex) {
        return CustomTableField(
          data: row[fieldIndex] ?? '',
          alignment: columnAlignments[fieldIndex],
        );
      });
      return CustomTableRow(isHeader: rowIndex == 0, fields: fields);
    }).nonNulls.toList();

    return tableBuilder(
      context,
      customTable,
      config.style ?? const TextStyle(),
      config,
    );
  }
}

// Prevent link regex from spanning across lines (dotAll=true in engine).
class LineSafeLinkMd extends ATagMd {
  @override
  RegExp get exp =>
      RegExp(r"(?<!\\)(?<!\!)\[[^\]\n]+(?<!\\)\]\([^\s\n]*(?<!\\)\)");
}

class EscapeAwareImageMd extends ImageMd {
  @override
  RegExp get exp =>
      RegExp(r"(?<!\\)\!\[[^\[\]\n]*(?<!\\)\]\([^\s\n]*(?<!\\)\)");
}

class EscapeAwareBoldMd extends BoldMd {
  @override
  RegExp get exp =>
      RegExp(r"(?<![\\*])\*\*(?!\s)(.+?)(?<![\s\\])\*\*(?!\*)", dotAll: true);

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final match = exp.firstMatch(text.trim());
    final conf = config.copyWith(
      style:
          config.style?.copyWith(fontWeight: AppFontWeights.strong) ??
          TextStyle(fontWeight: AppFontWeights.strong),
    );
    return TextSpan(
      children: MarkdownComponent.generate(
        context,
        '${match?[1]}',
        conf,
        false,
      ),
      style: conf.style,
    );
  }
}

class EscapeAwareItalicMd extends ItalicMd {
  @override
  RegExp get exp => RegExp(
    r"(?<![\\*])\*(?!\*)(?!\s)(.+?)(?<![\s\\*])\*(?!\*)",
    dotAll: true,
  );
}

class EscapeAwareHighlightedTextMd extends HighlightedText {
  @override
  RegExp get exp => RegExp(r"(?<!\\)`(?!`)(.+?)(?<![\\`])`(?!`)");
}

/// Treat backslash-escaped punctuation as a literal character, so that
/// sequences like `\*text\*`, `\`code\``, `\[label\]`, and `\# heading`
/// do not trigger emphasis, inline code, links, or headings.
///
/// We intentionally DO NOT consume `\(` and `\)` here to avoid interfering
/// with inline LaTeX parsing handled by InlineLatexParenScrollableMd.
class BackslashEscapeMd extends InlineMd {
  @override
  // CommonMark escape set (subset), excluding parentheses to keep LaTeX intact.
  // Matches a backslash followed by one escapable punctuation character.
  // Include $ so \$ in regular text renders as literal dollar sign.
  RegExp get exp => RegExp(r"\\([\\`*_{}\[\]#+\-.!$|])");

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final m = exp.firstMatch(text);
    if (m == null) return TextSpan(text: text, style: config.style);
    final ch = m.group(1) ?? '';
    // Render only the escaped character (drop the backslash)
    return TextSpan(text: ch, style: config.style);
  }
}

class DetailsHtmlMd extends BlockMd {
  @override
  RegExp get exp => RegExp(
    r'^\ *?(?:' + expString + r")$",
    dotAll: true,
    multiLine: true,
    caseSensitive: false,
  );

  @override
  String get expString => _detailsPattern(6);

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    final match = RegExp(
      r"^<details(?<attrs>[^>]*)>\s*<summary(?:\s+[^>]*)?>(?<summary>[\s\S]*?)<\/summary>(?<body>[\s\S]*)<\/details>$",
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text.trim());

    if (match == null) {
      return config.getRich(TextSpan(text: text, style: config.style));
    }

    final attrs = match.namedGroup('attrs') ?? '';
    final summary = _plainHtmlText(match.namedGroup('summary') ?? '').trim();
    final body = (match.namedGroup('body') ?? '').trim();
    final initiallyExpanded = RegExp(
      r"(?:^|\s)open(?:\s|$|=)",
      caseSensitive: false,
    ).hasMatch(attrs);

    return _DetailsHtmlBlock(
      summary: summary,
      body: body,
      initiallyExpanded: initiallyExpanded,
      config: config,
    );
  }

  static String _detailsPattern(int depth) {
    final open = r"<details(?:\s+[^>]*)?>";
    final summary = r"\s*<summary(?:\s+[^>]*)?>[\s\S]*?<\/summary>";
    if (depth <= 1) {
      return '$open$summary(?:(?!<details\\b|<\\/details>)[\\s\\S])*<\\/details>';
    }
    final nested = _detailsPattern(depth - 1);
    return '$open$summary(?:(?!<details\\b|<\\/details>)[\\s\\S]|$nested)*<\\/details>';
  }

  static String _plainHtmlText(String input) {
    return input
        .replaceAll(RegExp(r"<br\s*/?>", caseSensitive: false), '\n')
        .replaceAll(RegExp(r"<[^>]+>"), '')
        .trim();
  }
}

class _DetailsHtmlBlock extends StatefulWidget {
  const _DetailsHtmlBlock({
    required this.summary,
    required this.body,
    required this.initiallyExpanded,
    required this.config,
  });

  final String summary;
  final String body;
  final bool initiallyExpanded;
  final GptMarkdownConfig config;

  @override
  State<_DetailsHtmlBlock> createState() => _DetailsHtmlBlockState();
}

class _DetailsHtmlBlockState extends State<_DetailsHtmlBlock> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Color.alphaBlend(
      cs.onSurface.withValues(alpha: isDark ? 0.05 : 0.025),
      cs.surface,
    );
    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.18 : 0.30,
    );
    final summaryStyle = (widget.config.style ?? TextStyle()).copyWith(
      color: cs.onSurface,
      fontWeight: AppFontWeights.medium,
    );
    final bodyStyle = (widget.config.style ?? TextStyle()).copyWith(
      color: cs.onSurface,
    );
    final bodyConfig = widget.config.copyWith(style: bodyStyle);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          IosCardPress(
            onTap: () => setState(() => _expanded = !_expanded),
            baseColor: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            haptics: false,
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Lucide.ChevronRight,
                    size: 15,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    widget.summary,
                    style: summaryStyle,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  alignment: const AlignmentDirectional(-1.0, -1.0),
                  child: child,
                ),
              );
            },
            child: _expanded && widget.body.isNotEmpty
                ? Container(
                    key: const ValueKey('details-expanded'),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: borderColor, width: 0.8),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: widget.config.getRich(
                        TextSpan(
                          style: bodyStyle,
                          children: MarkdownComponent.generate(
                            context,
                            widget.body,
                            bodyConfig,
                            true,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('details-collapsed')),
          ),
        ],
      ),
    );
  }
}

class HtmlAnchorMd extends InlineMd {
  @override
  RegExp get exp => RegExp(
    r'''<a\s+[^>]*href\s*=\s*(['"])(.*?)\1[^>]*>([\s\S]*?)<\/a>''',
    caseSensitive: false,
    dotAll: true,
  );

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final match = exp.firstMatch(text);
    if (match == null) return TextSpan(text: text, style: config.style);

    final url = (match.group(2) ?? '').trim();
    final linkText = _stripTags(match.group(3) ?? '');
    final cs = Theme.of(context).colorScheme;

    return WidgetSpan(
      baseline: TextBaseline.alphabetic,
      alignment: PlaceholderAlignment.baseline,
      child: GestureDetector(
        onTap: url.isEmpty ? null : () => config.onLinkTap?.call(url, linkText),
        child: Text(
          linkText,
          style: (config.style ?? TextStyle()).copyWith(
            color: cs.primary,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  static String _stripTags(String input) =>
      input.replaceAll(RegExp(r"<[^>]+>"), '').trim();
}

/// Whitelist-based HTML tag renderer.
/// Currently supports simple paragraph and line-break tags.
class AllowedHtmlTagsMd extends InlineMd {
  @override
  RegExp get exp =>
      RegExp(r"<br\s*/?>|<p(?:\s+[^>]*)?>|<\/p\s*>", caseSensitive: false);

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    if (RegExp(r"<br\s*/?>", caseSensitive: false).hasMatch(text)) {
      return const TextSpan(text: '\n');
    }
    if (RegExp(r"<\/p\s*>", caseSensitive: false).hasMatch(text)) {
      return const TextSpan(text: '\n');
    }
    return const TextSpan(text: '');
  }
}

/// A selectable version of HighlightView that allows users to select
/// and copy portions of the code instead of just the entire block.
class SelectableHighlightView extends StatefulWidget {
  const SelectableHighlightView(
    this.source, {
    super.key,
    this.language,
    this.theme = const {},
    this.padding,
    this.textStyle,
    this.enableHighlight = true,
  });

  final String source;
  final String? language;
  final Map<String, TextStyle> theme;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final bool enableHighlight;

  @override
  State<SelectableHighlightView> createState() =>
      _SelectableHighlightViewState();
}

class _SelectableHighlightViewState extends State<SelectableHighlightView> {
  late List<TextSpan> _codeTextSpans;

  @override
  void initState() {
    super.initState();
    _codeTextSpans = _highlightSource();
  }

  @override
  void didUpdateWidget(covariant SelectableHighlightView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source == widget.source &&
        oldWidget.language == widget.language &&
        oldWidget.textStyle == widget.textStyle &&
        oldWidget.enableHighlight == widget.enableHighlight &&
        _highlightThemeEquals(oldWidget.theme, widget.theme)) {
      return;
    }
    _codeTextSpans = _highlightSource();
  }

  List<TextSpan> _highlightSource() {
    if (!widget.enableHighlight) {
      return <TextSpan>[TextSpan(text: widget.source)];
    }
    try {
      final result = highlight.parse(widget.source, language: widget.language);
      return _convertNodes(result.nodes ?? const []);
    } catch (_) {
      return const [];
    }
  }

  /// Converts a highlight Node tree to a TextSpan tree with appropriate styling
  List<TextSpan> _convertNodes(List<Node> nodes) {
    final List<TextSpan> spans = [];

    for (final node in nodes) {
      if (node.value != null) {
        // Leaf node with text content
        spans.add(
          TextSpan(text: node.value, style: widget.theme[node.className]),
        );
      } else if (node.children != null) {
        // Node with children - recurse
        spans.add(
          TextSpan(
            children: _convertNodes(node.children!),
            style: widget.theme[node.className],
          ),
        );
      }
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(
        style: widget.textStyle,
        children: _codeTextSpans.isEmpty
            ? [TextSpan(text: widget.source)]
            : _codeTextSpans,
      ),
    );
  }
}

bool _highlightThemeEquals(Map<String, TextStyle> a, Map<String, TextStyle> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
