import 'package:Kelivo/features/intelligent_ui/host/ui_host_scope.dart';
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
import '../../utils/unicode_sanitizer.dart';

/// App fonts, settings and platform actions around the native Markdown renderer.
class MarkdownWithCodeHighlight extends StatefulWidget {
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
    this.uiHost,
  });
  final String text;
  final UiHostBinding? uiHost;
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
  State<MarkdownWithCodeHighlight> createState() =>
      _MarkdownWithCodeHighlightState();
}

class _MarkdownWithCodeHighlightState extends State<MarkdownWithCodeHighlight> {
  late String _source;

  @override
  void initState() {
    super.initState();
    _source = UnicodeSanitizer.sanitize(widget.text);
  }

  @override
  void didUpdateWidget(MarkdownWithCodeHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _source = UnicodeSanitizer.sanitize(widget.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final exporting = ExportCaptureScope.of(context);
    final theme = mapMarkdownTheme(context, settings, widget.baseStyle);
    final view = MarkstreamView(
      source: _source,
      highlightRanges: widget.highlightRanges,
      highlightColor: widget.highlightColor,
      streaming: widget.streaming,
      options: markdownParserOptions(settings),
      theme: theme,
      extensions: markdownExtensionsFor(context),
      codeHighlighter: KelivoCodeHighlighter.forTheme(theme),
      mathRenderer: const KelivoMathRenderer(),
      imageBuilder: const KelivoImageBuilder(),
      linkHandler: const KelivoLinkHandler(),
      codeOptions: markdownCodeOptions(settings),
      labels: markdownLabels(context),
      exporting: exporting,
      cullToViewport: !exporting,
    );
    return MarkdownLinkScope(
      source: _source,
      conversationId: widget.conversationId,
      child: CitationScope(
        onTap: widget.onCitationTap,
        resolve: widget.citationIndexResolver,
        child: widget.uiHost == null
            ? view
            : UiHostScope(
                binding: widget.uiHost!,
                renderOwner: view,
                exporting: exporting,
                child: view,
              ),
      ),
    );
  }
}
