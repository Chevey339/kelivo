import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:gpt_markdown/custom_widgets/markdown_config.dart'
    show GptMarkdownConfig;
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/atom-one-dark-reasonable.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import '../../icons/lucide_adapter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui' as ui;
import '../../utils/sandbox_path_resolver.dart';
import '../../features/chat/pages/image_viewer_page.dart';
import '../../features/chat/pages/html_preview_page.dart';
import 'snackbar.dart';
import 'mermaid_bridge.dart';
import 'export_capture_scope.dart';
import 'mermaid_image_cache.dart';
import 'plantuml_block.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart' show getPlatformFontFallback;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/html_preview_dialog.dart';

/// gpt_markdown with custom code block highlight and inline code styling.
class MarkdownWithCodeHighlight extends StatelessWidget {
  const MarkdownWithCodeHighlight({
    super.key,
    required this.text,
    this.onCitationTap,
    this.baseStyle,
  });

  final String text;
  final void Function(String id)? onCitationTap;
  final TextStyle? baseStyle; // optional override for base markdown text style

  // Tunable: list scaling compensation exponent.
  // When chat scale s != 1.0, lists often feel slightly off compared to body.
  // We apply s^(1-k) instead of s to the list rows to gently normalize.
  // Increase k if lists still look larger at small scales; decrease if too small at large scales.
  static const double kMarkdownListScaleCompensation = 0.84;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final sanitizedText = _sanitizeImageLinks(text);
    final imageUrls = _extractImageUrls(sanitizedText);
    final normalized = _preprocessFences(
      sanitizedText,
      enableMath: settings.enableMathRendering,
      enableDollarLatex: settings.enableDollarLatex,
    );
    // Base text style (can be overridden by caller)
    final baseTextStyle = (baseStyle ?? Theme.of(context).textTheme.bodyMedium)
        ?.copyWith(
          fontSize: baseStyle?.fontSize ?? 15.5,
          height: baseStyle?.height ?? 1.55,
          letterSpacing:
              baseStyle?.letterSpacing ?? (_isZh(context) ? 0.0 : 0.05),
          color: null,
        );

    // Replace default components and add our own where needed
    final components = List<MarkdownComponent>.from(
      MarkdownComponent.globalComponents,
    );
    final hrIdx = components.indexWhere((c) => c is HrLine);
    if (hrIdx != -1) components[hrIdx] = SoftHrLine();
    final bqIdx = components.indexWhere((c) => c is BlockQuote);
    if (bqIdx != -1) components[bqIdx] = ModernBlockQuote();
    final cbIdx = components.indexWhere((c) => c is CheckBoxMd);
    if (cbIdx != -1) components[cbIdx] = ModernCheckBoxMd();
    final rbIdx = components.indexWhere((c) => c is RadioButtonMd);
    if (rbIdx != -1) components[rbIdx] = ModernRadioMd();
    // Prepend custom renderers in priority order (fence first)
    // Temporarily disable custom bold label line transformer to avoid
    // interfering with block parsing for complex documents.
    // components.insert(0, LabelValueLineMd());
    // Ensure backslash-escaped punctuation renders literally (e.g., \*, \`, \[)
    // Must run before emphasis/links/code parsing to neutralize markers.
    components.insert(0, BackslashEscapeMd());
    // Conditionally add LaTeX/math renderers
    if (settings.enableMathRendering) {
      // Block-level LaTeX (e.g., $$...$$ or \[...\])
      components.insert(0, LatexBlockScrollableMd());
      // Inline LaTeX: $...$ and \(...\)
      if (settings.enableDollarLatex) {
        components.insert(0, InlineLatexParenScrollableMd());
        components.insert(0, InlineLatexDollarScrollableMd());
      } else {
        // Only \(...\) inline
        components.insert(0, InlineLatexParenScrollableMd());
      }
    }
    components.insert(0, AtxHeadingMd());
    // Ensure fenced code blocks take precedence over headings and other blocks
    // so lines like "# comment" inside code fences are not parsed as headings.
    components.insert(0, FencedCodeBlockMd());
    // Inline components: keep defaults but make link parsing line-scoped
    final inlineComponents = List<MarkdownComponent>.from(
      MarkdownComponent.inlineComponents,
    );
    // Add whitelist-based HTML tag renderer (e.g., <br>)
    inlineComponents.insert(0, AllowedHtmlTagsMd());

    final linkIdxInline = inlineComponents.indexWhere((c) => c is ATagMd);
    if (linkIdxInline != -1) {
      inlineComponents[linkIdxInline] = LineSafeLinkMd();
    }
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
        '${Theme.of(context).brightness.index}-${cs.surface.value}-${cs.onSurface.value}-${cs.primary.value}-${cs.outlineVariant.value}',
      ),
      normalized,
      style: baseTextStyle,
      followLinkColor: true,
      // Disable built-in $...$ LaTeX so our custom scrollable handlers take over
      useDollarSignsForLatex: false,
      onLinkTap: (url, title) => _handleLinkTap(context, url),
      components: components,
      inlineComponents: inlineComponents,
      imageBuilder: (ctx, url) {
        final imgs = (imageUrls ?? const <String>[]).isNotEmpty
            ? imageUrls!
            : <String>[url];
        final idx = imgs.indexOf(url);
        final initial = idx >= 0 ? idx : 0;
        final provider = _imageProviderFor(url);
        return GestureDetector(
          onTap: () {
            Navigator.of(ctx).push(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => ImageViewerPage(
                  images: imgs ?? <String>[url],
                  initialIndex: initial,
                ),
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
                    width: constraints.maxWidth,
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
          final parts = url.split(':');
          if (parts.length == 2) {
            final indexText = parts[0].trim();
            final id = parts[1].trim();
            final cs = Theme.of(ctx).colorScheme;
            return GestureDetector(
              onTap: () {
                if (onCitationTap != null && id.isNotEmpty) {
                  onCitationTap!(id);
                } else {
                  // Fallback: do nothing
                }
              },
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  indexText,
                  style: const TextStyle(fontSize: 12, height: 1.0),
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
        final style = (cfg.style ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w400,
        );
        // Apply a soft compensation so when chat scale != 100%,
        // list items don't visually feel larger/smaller than body text.
        final double kListComp =
            MarkdownWithCodeHighlight.kMarkdownListScaleCompensation;
        final double s = MediaQuery.of(ctx).textScaleFactor;
        final double comp = math.pow(s == 0 ? 1.0 : s, -kListComp).toDouble();
        final double newScale = (s * comp).clamp(0.5, 3.0);
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(textScaleFactor: newScale),
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
        final style = (cfg.style ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w400,
        );
        final double kListComp =
            MarkdownWithCodeHighlight.kMarkdownListScaleCompensation;
        final double s = MediaQuery.of(ctx).textScaleFactor;
        final double comp = math.pow(s == 0 ? 1.0 : s, -kListComp).toDouble();
        final double newScale = (s * comp).clamp(0.5, 3.0);
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(textScaleFactor: newScale),
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
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final borderColor = cs.outlineVariant.withOpacity(isDark ? 0.22 : 0.28);
        // Blend header background with surface so it matches current theme tone
        final headerBg = Color.alphaBlend(
          cs.primary.withOpacity(isDark ? 0.14 : 0.08),
          cs.surface,
        );
        final headerStyle = (style).copyWith(
          fontWeight: FontWeight.w600,
          // Ensure header text adapts to theme changes
          color: cs.onSurface,
        );
        final cellStyle = (style).copyWith(
          // Ensure cell text adapts to theme changes
          color: cs.onSurface,
        );

        // Count max columns to pad missing cells
        int maxCol = 0;
        for (final r in rows) {
          if (r.fields.length > maxCol) maxCol = r.fields.length;
        }

        // Desktop platform detection (for selection + layout)
        final bool isDesktop =
            Platform.isMacOS || Platform.isWindows || Platform.isLinux;

        // Common cell builder
        Widget cell(
          String text,
          TextAlign align, {
          bool header = false,
          bool lastCol = false,
          bool lastRow = false,
        }) {
          // Render inline markdown (bold, code, links) inside table cells
          final innerCfg = cfg.copyWith(
            style: header ? headerStyle : cellStyle,
          );
          final children = MarkdownComponent.generate(
            ctx,
            text,
            innerCfg,
            true,
          );
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Align(
              alignment: () {
                switch (align) {
                  case TextAlign.center:
                    return Alignment.center;
                  case TextAlign.right:
                    return Alignment.centerRight;
                  default:
                    return Alignment.centerLeft;
                }
              }(),
              child: isDesktop
                  ? SelectableText.rich(
                      TextSpan(
                        style: header ? headerStyle : cellStyle,
                        children: children,
                      ),
                      textAlign: align,
                      maxLines: null,
                    )
                  : RichText(
                      text: TextSpan(
                        style: header ? headerStyle : cellStyle,
                        children: children,
                      ),
                      textAlign: align,
                      softWrap: true,
                      maxLines: null,
                      overflow: TextOverflow.visible,
                      textWidthBasis: TextWidthBasis.parent,
                    ),
            ),
          );
        }

        // Build a horizontally scrollable table (mobile) or responsive wrapping table (desktop)
        if (!isDesktop) {
          // Mobile/tablet: keep horizontal scroll to preserve layout
          final table = Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder(
              horizontalInside: BorderSide(color: borderColor, width: 0.5),
              verticalInside: BorderSide(color: borderColor, width: 0.5),
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              if (rows.isNotEmpty)
                TableRow(
                  decoration: BoxDecoration(color: headerBg),
                  children: List.generate(maxCol, (i) {
                    final f = i < rows.first.fields.length
                        ? rows.first.fields[i]
                        : null;
                    final txt = f?.data ?? '';
                    final align = f?.alignment ?? TextAlign.left;
                    return cell(
                      txt,
                      align,
                      header: true,
                      lastCol: i == maxCol - 1,
                      lastRow: false,
                    );
                  }),
                ),
              for (int r = 1; r < rows.length; r++)
                TableRow(
                  children: List.generate(maxCol, (c) {
                    final f = c < rows[r].fields.length
                        ? rows[r].fields[c]
                        : null;
                    final txt = f?.data ?? '';
                    final align = f?.alignment ?? TextAlign.left;
                    return cell(
                      txt,
                      align,
                      lastCol: c == maxCol - 1,
                      lastRow: r == rows.length - 1,
                    );
                  }),
                ),
            ],
          );

          return SelectionContainer.disabled(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              primary: false,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // Draw border on top so header row background won't cover top corners
                  foregroundDecoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DefaultTextStyle.merge(
                    // Ensure any nested spans fallback to current onSurface instead of stale defaults
                    style: TextStyle(color: cs.onSurface),
                    child: table,
                  ),
                ),
              ),
            ),
          );
        }

        // Desktop: fit within available width and wrap cell content.
        // Do NOT add an inner SelectionArea here to allow selection to span
        // across the entire message-level SelectionArea wrapper.
        return LayoutBuilder(
          builder: (context, constraints) {
            // Use equal flex for all columns so table width == available width.
            final Map<int, TableColumnWidth> columnWidths = {
              for (int i = 0; i < maxCol; i++) i: const FlexColumnWidth(),
            };

            final table = Table(
              defaultColumnWidth: const FlexColumnWidth(),
              border: TableBorder(
                horizontalInside: BorderSide(color: borderColor, width: 0.5),
                verticalInside: BorderSide(color: borderColor, width: 0.5),
              ),
              columnWidths: columnWidths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                if (rows.isNotEmpty)
                  TableRow(
                    decoration: BoxDecoration(color: headerBg),
                    children: List.generate(maxCol, (i) {
                      final f = i < rows.first.fields.length
                          ? rows.first.fields[i]
                          : null;
                      final txt = f?.data ?? '';
                      final align = f?.alignment ?? TextAlign.left;
                      return cell(
                        txt,
                        align,
                        header: true,
                        lastCol: i == maxCol - 1,
                        lastRow: false,
                      );
                    }),
                  ),
                for (int r = 1; r < rows.length; r++)
                  TableRow(
                    children: List.generate(maxCol, (c) {
                      final f = c < rows[r].fields.length
                          ? rows[r].fields[c]
                          : null;
                      final txt = f?.data ?? '';
                      final align = f?.alignment ?? TextAlign.left;
                      return cell(
                        txt,
                        align,
                        lastCol: c == maxCol - 1,
                        lastRow: r == rows.length - 1,
                      );
                    }),
                  ),
              ],
            );

            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                foregroundDecoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: cs.onSurface),
                  child: table,
                ),
              ),
            );
          },
        );
      },
      // Inline `code` styling via highlightBuilder in gpt_markdown
      highlightBuilder: (ctx, inline, style) {
        // Unmask dollar signs that were protected during preprocessing
        String unmasked = inline.replaceAll('___CODE_DOLLAR_MASK___', r'$');
        String softened = _softBreakInline(unmasked);
        final bool isDarkCtx = Theme.of(ctx).brightness == Brightness.dark;
        final csCtx = Theme.of(ctx).colorScheme;
        final bg = isDarkCtx ? Colors.white12 : const Color(0xFFF1F3F5);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: csCtx.outlineVariant.withOpacity(0.22)),
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
          return _MermaidBlock(code: code);
        } else if (lang.toLowerCase() == 'plantuml') {
          return PlantUMLBlock(code: code);
        }
        return _CollapsibleCodeBlock(language: lang, code: code);
      },
    );

    if (appFontFamily.isEmpty) return markdownWidget;
    return DefaultTextStyle.merge(
      style: TextStyle(fontFamily: appFontFamily),
      child: markdownWidget,
    );
  }

  static String _displayLanguage(BuildContext context, String? raw) {
    final zh = _isZh(context);
    final t = raw?.trim();
    if (t != null && t.isNotEmpty) return t;
    return zh ? '代码' : 'Code';
  }

  static bool _isZh(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'zh';

  static Map<String, TextStyle> _transparentBgTheme(
    Map<String, TextStyle> base,
  ) {
    final m = Map<String, TextStyle>.from(base);
    final root = base['root'];
    if (root != null) {
      m['root'] = root.copyWith(backgroundColor: Colors.transparent);
    } else {
      m['root'] = const TextStyle(backgroundColor: Colors.transparent);
    }
    return m;
  }

  static String? _normalizeLanguage(String? lang) {
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

  static String _preprocessFences(
    String input, {
    required bool enableMath,
    required bool enableDollarLatex,
  }) {
    // Normalize newlines to simplify regex handling
    var out = input.replaceAll('\r\n', '\n');

    // STEP 1: MASKING - Protect code blocks from LaTeX processing
    // This prevents $...$ inside code from being converted to LaTeX
    final Map<String, String> codeMap = {};
    int codeCount = 0;

    // Match fenced code blocks and inline code (`...`)
    // Fenced: CommonMark-style variable-length fences (>= 3 backticks or tildes)
    // Group 1: entire fenced block, Group 2: opening fence, Group 3: fence char
    // Closing fence must use same char and be >= opening length
    final codeRegex = RegExp(
      r'([ \t]*(([`~])\3{2,})[ \t]*[^\n]*\n(?:[\s\S]*?^[ \t]*\2\3*[ \t]*$|[\s\S]*))'
      r'|(`[^`\n]+`)',
      multiLine: true,
    );

    out = out.replaceAllMapped(codeRegex, (match) {
      final key = '__CODE_MASK_${codeCount++}__';
      var codeContent = match.group(0)!;

      // For inline code (`...`), escape dollar signs to prevent LaTeX interpretation
      // Inline code is single-line and delimited by single backticks (not fenced)
      final isInlineCode = !codeContent.contains('\n') &&
          codeContent.startsWith('`') &&
          codeContent.endsWith('`');
      if (isInlineCode) {
        codeContent = codeContent.replaceAllMapped(
          RegExp(r'\$'),
          (m) => '___CODE_DOLLAR_MASK___',
        );
      }

      codeMap[key] = codeContent;
      return key;
    });

    // STEP 2: PROCESSING (on masked string, code is now protected)

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

    // Normalize inline $...$ math into \( ... \) so it always matches the LaTeX
    // renderer (even when vendors emit single-dollar math mixed with prose).
    // Skips $$...$$ blocks, which are handled separately.
    // NOW SAFE: Code blocks are masked, so $variables in code won't be converted.
    if (enableMath && enableDollarLatex) {
      final inlineDollar = RegExp(r"(?<!\$)\$([^\$\n]+?)\$(?!\$)");
      out = out.replaceAllMapped(inlineDollar, (m) {
        return "\\(${m[1]}\\)";
      });
    }

    // Ensure display-math blocks stay as standalone blocks even when generated inline.
    // Some providers emit "$$...$$" inside list items or paragraphs; without extra
    // newlines gpt_markdown may treat them as plain text. We normalize multi-line
    // display math into its own block to guarantee rendering.
    final inlineDisplayMath = RegExp(r"\$\$([\s\S]*?)\$\$");
    out = out.replaceAllMapped(inlineDisplayMath, (m) {
      final body = (m.group(1) ?? '').trim();
      // Only normalize true display math (multi-line or clearly not inline literals)
      if (body.isEmpty) return m[0]!;
      final hasNewline = body.contains('\n');
      if (!hasNewline && body.length < 12)
        return m[0]!; // looks like inline literal, leave intact
      // Surround with blank lines to force a block; keep existing body trimmed
      final prefix = m.start == 0 || out.substring(0, m.start).endsWith('\n\n')
          ? ''
          : '\n';
      final suffix =
          m.end == out.length || out.substring(m.end).startsWith('\n\n')
          ? ''
          : '\n';
      return '${prefix}\$\$\n$body\n\$\$${suffix}';
    });

    // 1) Move fenced code from list lines to the next line: "* ```lang" -> "*\n```lang"
    final bulletFence = RegExp(
      r"^(\s*(?:[*+-]|\d+\.)\s+)```([^\s`]*)\s*$",
      multiLine: true,
    );
    out = out.replaceAllMapped(bulletFence, (m) => "${m[1]}\n```${m[2]}");

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
    final atxEnum = RegExp(
      r"^(\s{0,3}#{1,6}\s+\d+)\.(\s*)(\S)",
      multiLine: true,
    );
    out = out.replaceAllMapped(atxEnum, (m) => "${m[1]}.\u200C${m[2]}${m[3]}");

    // 7) Fix: when multiple markdown links are placed on separate lines using
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
    // NOTE: We do NOT restore ___CODE_DOLLAR_MASK___ here because we want LaTeX components
    // to never see dollar signs inside code. The unmask will happen later in highlightBuilder.
    out = out.replaceAllMapped(
      RegExp(r'__CODE_MASK_\d+__'),
      (match) {
        final key = match.group(0)!;
        return codeMap[key] ?? key;
      },
    );

    return out;
  }

  // Safe math renderer that falls back to plain text when parsing fails.
  static Widget _renderMath(
    String tex, {
    TextStyle? style,
    MathStyle mathStyle = MathStyle.text,
  }) {
    final resolved = style ?? const TextStyle();
    try {
      return Math.tex(
        tex,
        mathStyle: mathStyle,
        textStyle: resolved,
        onErrorFallback: (err) => Text(tex, style: resolved),
      );
    } catch (_) {
      return Text(tex, style: resolved);
    }
  }

  static String _softBreakInline(String input) {
    // Insert zero-width break for inline code segments with long tokens.
    if (input.length < 60) return input;
    final buf = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      buf.write(input[i]);
      if ((i + 1) % 24 == 0) buf.write('\u200B');
    }
    return buf.toString();
  }

  Future<void> _handleLinkTap(BuildContext context, String url) async {
    Uri uri;
    try {
      uri = _normalizeUrl(url);
    } catch (_) {
      showAppSnackBar(
        context,
        message: _isZh(context) ? '无效链接' : 'Invalid link',
        type: NotificationType.error,
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showAppSnackBar(
        context,
        message: _isZh(context) ? '无法打开链接' : 'Cannot open link',
        type: NotificationType.error,
      );
    }
  }

  Uri _normalizeUrl(String url) {
    var u = url.trim();
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(u)) {
      u = 'https://' + u;
    }
    return Uri.parse(u);
  }

  static List<String> _extractImageUrls(String md) {
    final re = RegExp(r"!\[[^\]]*\]\(([^)\s]+)\)");
    return re
        .allMatches(md)
        .map((m) => (m.group(1) ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String _sanitizeImageLinks(String input) {
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

      return '![${alt}](${safeUrl})';
    });
  }

  static ImageProvider? _imageProviderFor(String src) {
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
}

class _CollapsibleCodeBlock extends StatefulWidget {
  final String language;
  final String code;

  const _CollapsibleCodeBlock({required this.language, required this.code});

  @override
  State<_CollapsibleCodeBlock> createState() => _CollapsibleCodeBlockState();
}

class _CollapsibleCodeBlockState extends State<_CollapsibleCodeBlock> {
  bool _expanded = true;
  bool _manuallyToggled = false;

  @override
  void initState() {
    super.initState();
    _applyInitialAutoCollapse();
  }

  @override
  void didUpdateWidget(covariant _CollapsibleCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyAutoCollapseIfNeeded();
  }

  void _applyInitialAutoCollapse() {
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

    // Use theme-tinted surfaces so headers follow the current theme color.
    final Color bodyBg = Color.alphaBlend(
      cs.primary.withOpacity(isDark ? 0.06 : 0.03),
      cs.surface,
    );
    final Color headerBg = Color.alphaBlend(
      cs.primary.withOpacity(isDark ? 0.16 : 0.10),
      cs.surface,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      // Clip children to the same radius so they don't overpaint corners
      clipBehavior: Clip.antiAlias,
      // Draw the border on top so it remains visible at corners
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header layout: language (left) + copy action (icon + label) + expand/collapse icon
          Material(
            color: headerBg,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() {
                _manuallyToggled = true;
                _expanded = !_expanded;
              }),
              splashColor: Platform.isIOS ? Colors.transparent : null,
              highlightColor: Platform.isIOS ? Colors.transparent : null,
              hoverColor: Platform.isIOS ? Colors.transparent : null,
              overlayColor: Platform.isIOS
                  ? const MaterialStatePropertyAll(Colors.transparent)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: cs.outlineVariant.withOpacity(0.28),
                      width: 1.0,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 2),
                    Text(
                      MarkdownWithCodeHighlight._displayLanguage(
                        context,
                        widget.language,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        height: 1.0,
                      ),
                    ),
                    const Spacer(),
                    if (_isHtml(widget.language))
                      InkWell(
                        onTap: () async {
                          final l10n = AppLocalizations.of(context)!;
                          if (Platform.isAndroid || Platform.isIOS) {
                            // Mobile: navigate to preview page
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) =>
                                    HtmlPreviewPage(html: widget.code),
                                transitionDuration: const Duration(
                                  milliseconds: 300,
                                ),
                                reverseTransitionDuration: const Duration(
                                  milliseconds: 240,
                                ),
                                transitionsBuilder:
                                    (context, anim, sec, child) {
                                      final curved = CurvedAnimation(
                                        parent: anim,
                                        curve: Curves.easeOutCubic,
                                        reverseCurve: Curves.easeInCubic,
                                      );
                                      return FadeTransition(
                                        opacity: curved,
                                        child: child,
                                      );
                                    },
                              ),
                            );
                          } else if (Platform.isLinux) {
                            // Linux: show not supported
                            showAppSnackBar(
                              context,
                              message: l10n.htmlPreviewNotSupportedOnLinux,
                              type: NotificationType.warning,
                            );
                          } else {
                            // Desktop (macOS/Windows): open dialog
                            try {
                              // Defer import to avoid cycle
                              // ignore: use_build_context_synchronously
                              await showHtmlPreviewDesktopDialog(
                                context,
                                html: widget.code,
                              );
                            } catch (_) {}
                          }
                        },
                        splashColor: Platform.isIOS ? Colors.transparent : null,
                        highlightColor: Platform.isIOS
                            ? Colors.transparent
                            : null,
                        hoverColor: Platform.isIOS ? Colors.transparent : null,
                        overlayColor: Platform.isIOS
                            ? const MaterialStatePropertyAll(Colors.transparent)
                            : null,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Lucide.Eye,
                                size: 14,
                                color: cs.onSurface.withOpacity(0.6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.codeBlockPreviewButton,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withOpacity(0.6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Copy action: icon + label ("复制"/localized)
                    InkWell(
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: widget.code),
                        );
                        if (mounted) {
                          showAppSnackBar(
                            context,
                            message: AppLocalizations.of(
                              context,
                            )!.chatMessageWidgetCopiedToClipboard,
                            type: NotificationType.success,
                          );
                        }
                      },
                      splashColor: Platform.isIOS ? Colors.transparent : null,
                      highlightColor: Platform.isIOS
                          ? Colors.transparent
                          : null,
                      hoverColor: Platform.isIOS ? Colors.transparent : null,
                      overlayColor: Platform.isIOS
                          ? const MaterialStatePropertyAll(Colors.transparent)
                          : null,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Lucide.Copy,
                              size: 14,
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.shareProviderSheetCopyButton,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0.0, // right -> down
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Lucide.ChevronRight,
                        size: 16,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SizeTransition(
                sizeFactor: anim,
                axisAlignment: -1.0,
                child: child,
              ),
            ),
            child: _expanded
                ? Container(
                    key: const ValueKey('code-expanded'),
                    width: double.infinity,
                    color: bodyBg,
                    padding: const EdgeInsets.fromLTRB(10, 6, 6, 10),
                    child: () {
                      // Desktop: enable word wrap, allow selection, no height limit, no scroll
                      // Mobile: horizontal scroll by default, or word wrap if setting enabled
                      final bool isDesktop =
                          Platform.isMacOS ||
                          Platform.isWindows ||
                          Platform.isLinux;

                      if (isDesktop) {
                        // Desktop: auto wrap, selectable, no height limit, no scroll
                        return SelectableHighlightView(
                          _trimTrailingNewlines(widget.code),
                          language:
                              MarkdownWithCodeHighlight._normalizeLanguage(
                                widget.language,
                              ) ??
                              'plaintext',
                          theme: MarkdownWithCodeHighlight._transparentBgTheme(
                            isDark ? atomOneDarkReasonableTheme : githubTheme,
                          ),
                          padding: EdgeInsets.zero,
                          textStyle: TextStyle(
                            fontFamily: codeFontFamily,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        );
                      }

                      // Mobile: check settings for word wrap
                      final bool shouldWrap = settings.mobileCodeBlockWrap;

                      if (shouldWrap) {
                        // Mobile with wrap enabled: selectable, auto wrap
                        return SelectableHighlightView(
                          _trimTrailingNewlines(widget.code),
                          language:
                              MarkdownWithCodeHighlight._normalizeLanguage(
                                widget.language,
                              ) ??
                              'plaintext',
                          theme: MarkdownWithCodeHighlight._transparentBgTheme(
                            isDark ? atomOneDarkReasonableTheme : githubTheme,
                          ),
                          padding: EdgeInsets.zero,
                          textStyle: TextStyle(
                            fontFamily: codeFontFamily,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        );
                      }

                      // Mobile without wrap: horizontal scroll, selectable
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        primary: false,
                        child: SelectableHighlightView(
                          _trimTrailingNewlines(widget.code),
                          language:
                              MarkdownWithCodeHighlight._normalizeLanguage(
                                widget.language,
                              ) ??
                              'plaintext',
                          theme: MarkdownWithCodeHighlight._transparentBgTheme(
                            isDark ? atomOneDarkReasonableTheme : githubTheme,
                          ),
                          padding: EdgeInsets.zero,
                          textStyle: TextStyle(
                            fontFamily: codeFontFamily,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      );
                    }(),
                  )
                : Container(
                    key: const ValueKey('code-collapsed'),
                    width: double.infinity,
                    color: bodyBg,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: () {
                      final l10n = AppLocalizations.of(context)!;
                      final code = widget.code;
                      final end = _trimTrailingNewlinesEndIndex(code);

                      final preview = <String>[];
                      int totalLines = 0;
                      if (end > 0) {
                        totalLines = 1;
                        int lineStart = 0;
                        for (int i = 0; i < end; i++) {
                          final cu = code.codeUnitAt(i);
                          if (cu == 0x0A /* \n */ || cu == 0x0D /* \r */) {
                            if (preview.length < 2) {
                              preview.add(code.substring(lineStart, i));
                            }
                            totalLines++;
                            if (cu == 0x0D /* \r */ &&
                                i + 1 < end &&
                                code.codeUnitAt(i + 1) == 0x0A /* \n */) {
                              i++;
                            }
                            lineStart = i + 1;
                          }
                        }
                        if (preview.length < 2) {
                          preview.add(code.substring(lineStart, end));
                        }
                      }

                      final hiddenLines =
                          (totalLines - preview.length).clamp(0, 999999);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in preview)
                            Text(
                              line,
                              style: TextStyle(
                                fontFamily: codeFontFamily,
                                fontSize: 13,
                                height: 1.5,
                                color: cs.onSurface,
                              ),
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (hiddenLines > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                l10n.codeBlockCollapsedLines(hiddenLines),
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: cs.onSurface.withOpacity(0.55),
                                ),
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      );
                    }(),
                  ),
          ),
        ],
      ),
    );
  }

  bool _exceedsLineThreshold(String code, int threshold) {
    if (threshold < 1) return true;
    final end = _trimTrailingNewlinesEndIndex(code);
    if (end <= 0) return false;

    int lines = 1;
    for (int i = 0; i < end; i++) {
      final cu = code.codeUnitAt(i);
      if (cu == 0x0A /* \n */) {
        lines++;
        if (lines > threshold) return true;
        continue;
      }
      if (cu == 0x0D /* \r */) {
        lines++;
        if (lines > threshold) return true;
        if (i + 1 < end && code.codeUnitAt(i + 1) == 0x0A) i++;
      }
    }
    return false;
  }

  int _trimTrailingNewlinesEndIndex(String s) {
    int end = s.length;
    while (end > 0) {
      final ch = s.codeUnitAt(end - 1);
      if (ch == 0x0A /* \n */ || ch == 0x0D /* \r */) {
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

bool _isHtml(String? lang) {
  final l = (lang ?? '').trim().toLowerCase();
  return l == 'html' || l == 'htm' || l == 'rawhtml' || l == 'raw_html';
}

class _MermaidBlock extends StatefulWidget {
  final String code;
  const _MermaidBlock({required this.code});

  @override
  State<_MermaidBlock> createState() => _MermaidBlockState();
}

class _MermaidBlockState extends State<_MermaidBlock> {
  bool _expanded = true;
  // Stable key to avoid frequent WebView recreation across rebuilds
  final GlobalKey _mermaidViewKey = GlobalKey();
  late final ScrollController _vMermaidScrollController;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use theme-tinted surfaces so headers follow the current theme color.
    final Color bodyBg = Color.alphaBlend(
      cs.primary.withOpacity(isDark ? 0.06 : 0.03),
      cs.surface,
    );
    final Color headerBg = Color.alphaBlend(
      cs.primary.withOpacity(isDark ? 0.16 : 0.10),
      cs.surface,
    );

    // Build theme variables mapping for Mermaid from Material ColorScheme
    String hex(Color c) {
      final v = c.value & 0xFFFFFFFF;
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
      'background': hex(cs.background),
      'mainBkg': hex(cs.primaryContainer),
      'secondBkg': hex(cs.secondaryContainer),
      'lineColor': hex(cs.onBackground),
      'textColor': hex(cs.onBackground),
      'nodeBkg': hex(cs.surface),
      'nodeBorder': hex(cs.primary),
      'clusterBkg': hex(cs.surface),
      'clusterBorder': hex(cs.primary),
      'actorBorder': hex(cs.primary),
      'actorBkg': hex(cs.surface),
      'actorTextColor': hex(cs.onBackground),
      'actorLineColor': hex(cs.primary),
      'taskBorderColor': hex(cs.primary),
      'taskBkgColor': hex(cs.primary),
      'taskTextLightColor': hex(cs.onPrimary),
      'taskTextDarkColor': hex(cs.onBackground),
      'labelColor': hex(cs.onBackground),
      'errorBkgColor': hex(cs.error),
      'errorTextColor': hex(cs.onError),
    };

    final exporting = ExportCaptureScope.of(context);
    final handle = exporting
        ? null
        : createMermaidView(
            widget.code,
            isDark,
            themeVars: themeVars,
            viewKey: _mermaidViewKey,
          );
    final Widget? mermaidView = () {
      if (exporting) {
        final bytes = MermaidImageCache.get(widget.code);
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(bytes, fit: BoxFit.contain);
        }
        return null;
      } else {
        return handle?.widget;
      }
    }();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: left label (mermaid), right actions (copy label + export + chevron)
          Material(
            color: headerBg,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              splashColor: Platform.isIOS ? Colors.transparent : null,
              highlightColor: Platform.isIOS ? Colors.transparent : null,
              hoverColor: Platform.isIOS ? Colors.transparent : null,
              overlayColor: Platform.isIOS
                  ? const MaterialStatePropertyAll(Colors.transparent)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    // Show divider only when expanded
                    bottom: _expanded
                        ? BorderSide(
                            color: cs.outlineVariant.withOpacity(0.28),
                            width: 1.0,
                          )
                        : BorderSide.none,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 2),
                    Text(
                      'mermaid',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        height: 1.0,
                      ),
                    ),
                    const Spacer(),
                    if (!ExportCaptureScope.of(context)) ...[
                      // Copy action
                      InkWell(
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: widget.code),
                          );
                          if (mounted) {
                            showAppSnackBar(
                              context,
                              message: AppLocalizations.of(
                                context,
                              )!.chatMessageWidgetCopiedToClipboard,
                              type: NotificationType.success,
                            );
                          }
                        },
                        splashColor: Platform.isIOS ? Colors.transparent : null,
                        highlightColor: Platform.isIOS
                            ? Colors.transparent
                            : null,
                        hoverColor: Platform.isIOS ? Colors.transparent : null,
                        overlayColor: Platform.isIOS
                            ? const MaterialStatePropertyAll(Colors.transparent)
                            : null,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Lucide.Copy,
                                size: 14,
                                color: cs.onSurface.withOpacity(0.6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.shareProviderSheetCopyButton,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withOpacity(0.6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (handle != null) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () async {
                            final ok = await handle.exportPng();
                            if (!mounted) return;
                            if (!ok) {
                              final l10n = AppLocalizations.of(context)!;
                              showAppSnackBar(
                                context,
                                message: l10n.mermaidExportFailed,
                                type: NotificationType.error,
                              );
                            } else if (Platform.isAndroid || Platform.isIOS) {
                              showAppSnackBar(
                                context,
                                message: AppLocalizations.of(
                                  context,
                                )!.imageViewerPageSaveSuccess,
                                type: NotificationType.success,
                              );
                            }
                          },
                          splashColor: Platform.isIOS
                              ? Colors.transparent
                              : null,
                          highlightColor: Platform.isIOS
                              ? Colors.transparent
                              : null,
                          hoverColor: Platform.isIOS
                              ? Colors.transparent
                              : null,
                          overlayColor: Platform.isIOS
                              ? const MaterialStatePropertyAll(
                                  Colors.transparent,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Lucide.Download,
                              size: 14,
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _expanded ? 0.25 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Lucide.ChevronRight,
                          size: 16,
                          color: cs.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SizeTransition(
                sizeFactor: anim,
                axisAlignment: -1.0,
                child: child,
              ),
            ),
            child: _expanded
                ? Container(
                    key: const ValueKey('mermaid-expanded'),
                    width: double.infinity,
                    color: bodyBg,
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (mermaidView != null) ...[
                          SizedBox(width: double.infinity, child: mermaidView),
                        ] else ...[
                          // Fallback: show raw code and a preview button (opens browser)
                          () {
                            final bool isDesktop =
                                Platform.isMacOS ||
                                Platform.isWindows ||
                                Platform.isLinux;
                            if (!isDesktop) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SelectableHighlightView(
                                  widget.code,
                                  language: 'plaintext',
                                  theme:
                                      MarkdownWithCodeHighlight._transparentBgTheme(
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? atomOneDarkReasonableTheme
                                            : githubTheme,
                                      ),
                                  padding: EdgeInsets.zero,
                                  textStyle: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              );
                            }
                            final screenH = MediaQuery.of(context).size.height;
                            final maxH = math.min(420.0, screenH * 0.55);
                            return ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: maxH),
                              child: ScrollConfiguration(
                                behavior: ScrollConfiguration.of(context)
                                    .copyWith(
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
                                  notificationPredicate: (notif) =>
                                      notif.metrics.axis == Axis.vertical,
                                  child: SingleChildScrollView(
                                    controller: _vMermaidScrollController,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SelectableHighlightView(
                                        widget.code,
                                        language: 'plaintext',
                                        theme:
                                            MarkdownWithCodeHighlight._transparentBgTheme(
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? atomOneDarkReasonableTheme
                                                  : githubTheme,
                                            ),
                                        padding: EdgeInsets.zero,
                                        textStyle: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }(),
                          if (!ExportCaptureScope.of(context)) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _openMermaidPreviewInBrowser(
                                  context,
                                  widget.code,
                                  Theme.of(context).brightness ==
                                      Brightness.dark,
                                ),
                                icon: Icon(Lucide.Eye, size: 16),
                                label: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.mermaidPreviewOpen,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('mermaid-collapsed')),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _vMermaidScrollController = ScrollController();
  }

  @override
  void dispose() {
    _vMermaidScrollController.dispose();
    super.dispose();
  }

  Future<void> _openMermaidPreviewInBrowser(
    BuildContext context,
    String code,
    bool dark,
  ) async {
    final htmlStr = _buildMermaidHtml(code, dark);
    final uri = Uri.dataFromString(
      htmlStr,
      mimeType: 'text/html',
      encoding: utf8,
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.mermaidPreviewOpenFailed,
        type: NotificationType.error,
      );
    }
  }

  String _buildMermaidHtml(String code, bool dark) {
    final bg = dark ? '#111111' : '#ffffff';
    final fg = dark ? '#eaeaea' : '#222222';
    final escaped = code
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes, maximum-scale=5.0">
    <title>Mermaid Preview</title>
    <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
    <style>
      body{ margin:0; padding:12px; background:${bg}; color:${fg}; }
      .wrap{ max-width: 1000px; margin: 0 auto; }
      .mermaid{ text-align:center; }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="mermaid">${escaped}</div>
    </div>
    <script>
      mermaid.initialize({ startOnLoad:false, theme: '${dark ? 'dark' : 'default'}', securityLevel:'loose' });
      mermaid.run({ querySelector: '.mermaid' });
    </script>
  </body>
</html>
''';
  }
}

// Full-width horizontal rule with softer color
class SoftHrLine extends BlockMd {
  @override
  String get expString => (r"^\s*(?:-{3,}|⸻)\s*$");

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.outlineVariant.withOpacity(0.4);
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
  @override
  // CommonMark-style fences:
  // - fence length is variable (>= 3)
  // - closing fence must use the same marker and be >= opening length
  // - supports both ``` and ~~~
  String get expString =>
      (r"[ \t]*(([`~])\2{2,})[ \t]*([^\n]*?)\n"
          r"(?:(?:([\s\S]*?)^[ \t]*\1\2*[ \t]*)|([\s\S]*))");

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    final m = exp.firstMatch(text);
    if (m == null) return const SizedBox.shrink();
    final lang = (m.group(3) ?? '').trim();
    final code = (m.group(4) ?? m.group(5) ?? '');
    final langLower = lang.toLowerCase();
    if (langLower == 'mermaid') {
      return _MermaidBlock(code: code);
    } else if (langLower == 'plantuml') {
      return PlantUMLBlock(code: code);
    }
    return _CollapsibleCodeBlock(language: lang, code: code);
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

    final math = MarkdownWithCodeHighlight._renderMath(
      body,
      style: config.style,
      mathStyle: MathStyle.display,
    );
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

/// Inline LaTeX `$...$` rendered in a horizontally scrollable bubble to avoid line overflow
class InlineLatexScrollableMd extends InlineMd {
  @override
  // Match single-dollar $...$ or \(...\) inline math (avoid $$ block)
  RegExp get exp =>
      RegExp(r"(?:(?<!\$)\$([^\$\n]+?)\$(?!\$)|\\\(([^\n]+?)\\\))");

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final m = exp.firstMatch(text);
    if (m == null) return TextSpan(text: text, style: config.style);
    final body = ((m.group(1) ?? m.group(2) ?? '')).trim();
    if (body.isEmpty) return TextSpan(text: text, style: config.style);
    final math = MarkdownWithCodeHighlight._renderMath(
      body,
      mathStyle: MathStyle.text,
      style: () {
        final base = (config.style ?? const TextStyle());
        final baseSize = base.fontSize ?? 15.5;
        // Slightly enlarge inline math for readability
        return base.copyWith(fontSize: baseSize * 1.2);
      }(),
    );
    // Wrap in horizontal scroll to prevent line overflow; no extra background
    final w = LayoutBuilder(
      builder: (context, constraints) {
        return SelectionContainer.disabled(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: false,
            child: math,
          ),
        );
      },
    );

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: w,
    );
  }
}

/// Inline LaTeX for dollar delimiters only: `$...$`
class InlineLatexDollarScrollableMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r"(?:(?<!\$)\$([^\$\n]+?)\$(?!\$))");

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final m = exp.firstMatch(text);
    if (m == null) return TextSpan(text: text, style: config.style);
    final body = (m.group(1) ?? '').trim();
    if (body.isEmpty) return TextSpan(text: text, style: config.style);
    final math = MarkdownWithCodeHighlight._renderMath(
      body,
      mathStyle: MathStyle.text,
      style: () {
        final base = (config.style ?? const TextStyle());
        final baseSize = base.fontSize ?? 15.5;
        return base.copyWith(fontSize: baseSize * 1.2);
      }(),
    );
    final w = LayoutBuilder(
      builder: (context, constraints) {
        return SelectionContainer.disabled(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: false,
            child: math,
          ),
        );
      },
    );
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: w,
    );
  }
}

/// Inline LaTeX for parenthesis delimiters only: `\(...\)`
class InlineLatexParenScrollableMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r"(?:\\\(([^\n]+?)\\\))");

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final m = exp.firstMatch(text);
    if (m == null) return TextSpan(text: text, style: config.style);
    final body = (m.group(1) ?? '').trim();
    if (body.isEmpty) return TextSpan(text: text, style: config.style);
    final math = MarkdownWithCodeHighlight._renderMath(
      body,
      mathStyle: MathStyle.text,
      style: () {
        final base = (config.style ?? const TextStyle());
        final baseSize = base.fontSize ?? 15.5;
        return base.copyWith(fontSize: baseSize * 1.2);
      }(),
    );
    final w = LayoutBuilder(
      builder: (context, constraints) {
        return SelectionContainer.disabled(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: false,
            child: math,
          ),
        );
      },
    );
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: w,
    );
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

    final innerCfg = config.copyWith(style: const TextStyle());
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
    final t = Theme.of(ctx).textTheme;
    final cs = Theme.of(ctx).colorScheme;
    final isZh = MarkdownWithCodeHighlight._isZh(ctx);
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
        base = const TextStyle(fontSize: 24);
        break;
      case 2:
        base = const TextStyle(fontSize: 20);
        break;
      case 3:
        base = const TextStyle(fontSize: 18);
        break;
      case 4:
        base = const TextStyle(fontSize: 16);
        break;
      case 5:
        base = const TextStyle(fontSize: 15);
        break;
      default:
        base = const TextStyle(fontSize: 14);
    }
    final weight = switch (level) {
      1 => FontWeight.w700,
      2 => FontWeight.w600,
      3 => FontWeight.w600,
      _ => FontWeight.w500,
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

    final innerCfg = config.copyWith(style: const TextStyle());
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
    final base =
        (config.style ?? t.bodyMedium ?? const TextStyle(fontSize: 14));
    final labelStyle = base.copyWith(
      fontWeight: FontWeight.w700, // 与 ** 加粗视觉一致
      color: cs.onSurface,
    );
    final valueStyle = base.copyWith(
      fontWeight: FontWeight.w400,
      color: cs.onSurface.withOpacity(0.92),
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

// Modern, app-styled block quote with soft background and accent border
class ModernBlockQuote extends InlineMd {
  @override
  bool get inline => false;

  @override
  RegExp get exp => RegExp(
    r"^[ \t]*>[^\n]*(?:\n[ \t]*>[^\n]*)*",
    multiLine: true,
  );

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final match = exp.firstMatch(text);
    final m = match?[0] ?? '';
    final sb = StringBuffer();
    for (final line in m.split('\n')) {
      if (RegExp(r'^\ *>').hasMatch(line)) {
        var sub = line.trimLeft();
        sub = sub.substring(1); // remove '>'
        if (sub.startsWith(' ')) sub = sub.substring(1);
        sb.writeln(sub);
      } else {
        sb.writeln(line);
      }
    }
    final data = sb.toString().trim();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = cs.primaryContainer.withOpacity(isDark ? 0.18 : 0.12);
    final accent = cs.primary.withOpacity(isDark ? 0.90 : 0.80);

    final inner = TextSpan(
      children: MarkdownComponent.generate(context, data, config, true),
    );
    final child = Directionality(
      textDirection: config.textDirection,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: config.getRich(inner),
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

    final contentStyle = (config.style ?? const TextStyle()).copyWith(
      decoration: checked ? TextDecoration.lineThrough : null,
      color: (config.style?.color ?? cs.onSurface).withOpacity(
        checked ? 0.75 : 1.0,
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
                  color: cs.outlineVariant.withOpacity(0.8),
                  width: 1,
                ),
                color: checked
                    ? cs.primary.withOpacity(0.12)
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

    final contentStyle = (config.style ?? const TextStyle()).copyWith(
      color: (config.style?.color ?? cs.onSurface).withOpacity(
        selected ? 0.95 : 1.0,
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
                  color: cs.outlineVariant.withOpacity(0.8),
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

// Prevent link regex from spanning across lines (dotAll=true in engine).
class LineSafeLinkMd extends ATagMd {
  @override
  RegExp get exp => RegExp(r"(?<!\!)\[[^\]\n]+\]\([^\s]*\)");
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
  RegExp get exp => RegExp(r"\\([\\`*_{}\[\]#+\-.!$])");

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final m = exp.firstMatch(text);
    if (m == null) return TextSpan(text: text, style: config.style);
    final ch = m.group(1) ?? '';
    // Render only the escaped character (drop the backslash)
    return TextSpan(text: ch, style: config.style);
  }
}

/// Whitelist-based HTML tag renderer.
/// Currently supports <br> tags for manual line breaks.
class AllowedHtmlTagsMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r"<br\s*/?>", caseSensitive: false);

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    return const TextSpan(text: '\n');
  }
}

/// A selectable version of HighlightView that allows users to select
/// and copy portions of the code instead of just the entire block.
class SelectableHighlightView extends StatelessWidget {
  const SelectableHighlightView(
    this.source, {
    super.key,
    this.language,
    this.theme = const {},
    this.padding,
    this.textStyle,
  });

  final String source;
  final String? language;
  final Map<String, TextStyle> theme;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;

  /// Converts a highlight Node tree to a TextSpan tree with appropriate styling
  List<TextSpan> _convertNodes(List<Node> nodes) {
    final List<TextSpan> spans = [];

    for (final node in nodes) {
      if (node.value != null) {
        // Leaf node with text content
        spans.add(TextSpan(text: node.value, style: theme[node.className]));
      } else if (node.children != null) {
        // Node with children - recurse
        spans.add(
          TextSpan(
            children: _convertNodes(node.children!),
            style: theme[node.className],
          ),
        );
      }
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final result = highlight.parse(source, language: language);
    final codeTextSpans = _convertNodes(result.nodes ?? []);

    return SelectableText.rich(
      TextSpan(
        style: textStyle,
        children: codeTextSpans.isEmpty
            ? [TextSpan(text: source)]
            : codeTextSpans,
      ),
    );
  }
}
