import 'package:flutter/material.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/utils/svg_preview_html.dart';
import 'package:Kelivo/shared/widgets/plantuml_block.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';

import 'package:Kelivo/features/intelligent_ui/host/ui_markdown_builder.dart';

import 'citation_syntax.dart';
import 'diagram_code_blocks.dart';
import 'highlight_adapter.dart';
import 'markdown_image_sources.dart';
import 'markdown_actions.dart';
import 'link_image_handlers.dart';
import 'math_adapter.dart';

// Stable registration identity preserves the parser and completed prefix trees.
final kelivoMarkdownExtensions = MarkstreamExtensions(
  inlineSyntaxes: const [CitationSyntax(), LocalImagePathSyntax()],
  namedInlineBuilders: {'kelivo-citation': buildCitation},
  codeBlockBuilders: {
    'kelivo-ui': _nativeUi,
    'kelivo-web': _nativeUi,
    'math': _math,
    'mermaid': _diagram,
    'svg': _diagram,
    'xml': _diagram,
    'html': _diagram,
    'htm': _diagram,
    'rawhtml': _diagram,
    'raw_html': _diagram,
    'plantuml': _plantUml,
  },
  actionButtonBuilder: markdownActionButton,
  codeExtraActions: markdownCodeActions,
  tableExtraActions: markdownTableActions,
  mobileTableToolbarBuilder: markdownMobileTableToolbar,
);

Widget _nativeUi(
  BuildContext context,
  CodeBlockNode node,
  MarkstreamRenderContext rendering,
) => UiMarkdownBlock(
  node: node,
  rendering: rendering,
  linkHandler: const KelivoLinkHandler(),
  sourceBuilder: (context) => MarkstreamCodeBlock(
    node: node,
    theme: rendering.theme,
    extensions: kelivoMarkdownExtensions,
    options: markdownCodeOptions(context.watch<SettingsProvider>()),
    labels: markdownLabels(context),
    highlighter: KelivoCodeHighlighter.forTheme(rendering.theme),
    streaming: rendering.streaming,
    exporting: ExportCaptureScope.of(context),
  ),
);

Widget _math(
  BuildContext context,
  CodeBlockNode node,
  MarkstreamRenderContext rendering,
) {
  final settings = context.watch<SettingsProvider>();
  final fallback = MarkstreamCodeBlock(
    node: node,
    theme: rendering.theme,
    extensions: kelivoMarkdownExtensions,
    options: markdownCodeOptions(settings),
    labels: markdownLabels(context),
    highlighter: KelivoCodeHighlighter.forTheme(rendering.theme),
    streaming: rendering.streaming,
    exporting: ExportCaptureScope.of(context),
  );
  if (settings.enableMathRendering &&
      node.closed &&
      node.code.trim().isNotEmpty) {
    return KelivoMathBlock(
      node: node,
      theme: rendering.theme,
      fallback: fallback,
    );
  }
  return fallback;
}

Widget _diagram(
  BuildContext context,
  CodeBlockNode node,
  MarkstreamRenderContext rendering,
) {
  final language = node.info.trim().split(RegExp(r'\s+')).first.toLowerCase();
  if (language == 'mermaid' || isSvgCodeBlock(language, node.code)) {
    return KelivoDiagramBlock(
      node: node,
      theme: rendering.theme,
      streaming: rendering.streaming && !node.closed,
      isSvg: language != 'mermaid',
    );
  }
  // HTML snippets and complete HTML documents use the same code chrome and
  // explicit preview action. Calling the built-in widget avoids redispatch.
  return MarkstreamCodeBlock(
    node: node,
    theme: rendering.theme,
    extensions: kelivoMarkdownExtensions,
    options: markdownCodeOptions(context.watch<SettingsProvider>()),
    labels: markdownLabels(context),
    highlighter: KelivoCodeHighlighter.forTheme(rendering.theme),
    streaming: rendering.streaming,
    exporting: ExportCaptureScope.of(context),
  );
}

final _expansionState = CodeExpansionState();
CodeBlockOptions markdownCodeOptions(SettingsProvider settings) =>
    CodeBlockOptions(
      autoCollapse: settings.autoCollapseCodeBlock,
      collapsedLines: settings.autoCollapseCodeBlockLines.clamp(1, 999999),
      mobileWrap: settings.mobileCodeBlockWrap,
      expansionState: _expansionState,
    );

// Keep the localized row-label callback stable for the same localization object.
final _labels = Expando<MarkstreamLabels>();
MarkstreamLabels markdownLabels(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return _labels[l10n] ??= MarkstreamLabels(
    copyCode: l10n.shareProviderSheetCopyButton,
    copyMarkdown: l10n.markdownCopyMarkdownAction,
    copyCsv: l10n.markdownCopyCsvAction,
    expand: l10n.codeBlockExpandButton,
    collapse: l10n.codeBlockCollapseButton,
    unnamedCode: l10n.markdownCodeLabel,
    details: l10n.markdownDetailsLabel,
    note: l10n.markdownNoteLabel,
    tip: l10n.markdownTipLabel,
    important: l10n.markdownImportantLabel,
    warning: l10n.markdownWarningLabel,
    caution: l10n.markdownCautionLabel,
    danger: l10n.markdownDangerLabel,
    moreRows: l10n.markdownMoreRows,
  );
}

Widget _plantUml(
  BuildContext context,
  CodeBlockNode node,
  MarkstreamRenderContext rendering,
) {
  final theme = rendering.theme;
  final streaming = rendering.streaming;
  return PlantUMLBlock(
    theme: theme,
    code: node.code,
    codeBuilder: (_) => MarkstreamCodeContent(
      node: node,
      theme: theme,
      streaming: streaming,
      highlighter: KelivoCodeHighlighter.forTheme(theme),
      wrap: false,
    ),
  );
}

ParserOptions markdownParserOptions(SettingsProvider settings) =>
    switch ((settings.enableMathRendering, settings.enableDollarLatex)) {
      (true, true) => const ParserOptions(),
      (true, false) => const ParserOptions(dollarInlineMath: false),
      (false, _) => const ParserOptions(inlineMath: false, mathBlocks: false),
    };
