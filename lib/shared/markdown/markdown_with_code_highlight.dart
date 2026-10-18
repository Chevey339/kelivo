import 'package:flutter/material.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';

import 'citation_syntax.dart';
import 'highlight_adapter.dart';
import 'kelivo_markdown_extensions.dart';
import 'link_image_handlers.dart';
import 'markdown_theme_mapper.dart';
import 'math_adapter.dart';

/// App fonts, settings and platform actions around the native Markdown renderer.
class MarkdownWithCodeHighlight extends StatelessWidget {
  const MarkdownWithCodeHighlight({
    super.key,
    required this.text,
    this.onCitationTap,
    this.citationIndexResolver,
    this.baseStyle,
    this.streaming = false,
    this.useBlockRendering = false,
    this.conversationId,
    this.highlightRanges = const [],
    this.highlightColor,
  });
  final String text;
  final void Function(String id)? onCitationTap;
  final String? Function(String id)? citationIndexResolver;
  final TextStyle? baseStyle;
  final bool streaming;

  /// Retained as the app's static-document intent. Markstream always renders
  /// source blocks and keeps their identity through streaming completion.
  final bool useBlockRendering;
  final String? conversationId;
  final List<SourceSpan> highlightRanges;
  final Color? highlightColor;
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final exporting = ExportCaptureScope.of(context);
    return MarkdownLinkScope(
      source: text,
      conversationId: conversationId,
      child: CitationScope(
        onTap: onCitationTap,
        resolve: citationIndexResolver,
        child: MarkstreamView(
          source: text,
          highlightRanges: highlightRanges,
          highlightColor: highlightColor,
          streaming: streaming,
          options: markdownParserOptions(settings),
          theme: mapMarkdownTheme(context, settings, baseStyle),
          extensions: kelivoMarkdownExtensions,
          codeHighlighter: const KelivoCodeHighlighter(),
          mathRenderer: const KelivoMathRenderer(),
          imageBuilder: const KelivoImageBuilder(),
          linkHandler: const KelivoLinkHandler(),
          codeOptions: markdownCodeOptions(settings),
          labels: markdownLabels(context),
          exporting: exporting,
          cullToViewport: !exporting,
        ),
      ),
    );
  }
}
