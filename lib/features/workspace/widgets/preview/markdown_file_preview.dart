import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:Kelivo/shared/widgets/segmented_tabs.dart';

import 'code_file_preview.dart';
import 'preview_states.dart';
import 'preview_text_document.dart';

class MarkdownFilePreview extends StatefulWidget {
  const MarkdownFilePreview({
    super.key,
    required this.file,
    this.autoLoad = true,
  });

  final File file;
  final bool autoLoad;

  @override
  MarkdownFilePreviewState createState() => MarkdownFilePreviewState();
}

class MarkdownFilePreviewState extends State<MarkdownFilePreview> {
  bool _showSource = false;
  PreviewTextDocument? _document;
  int _loadGeneration = 0;
  Object? _error;

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
  void didUpdateWidget(covariant MarkdownFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _loadGeneration++;
      _document = null;
      _error = null;
      _showSource = false;
      if (widget.autoLoad) unawaited(load());
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
        _error = null;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_error != null) {
      return PreviewError(onRetry: () => unawaited(load()));
    }
    final document = _document;
    if (document == null) {
      return const PreviewLoading();
    }
    if (document.usesPlainText) {
      return CodeFilePreview(
        file: widget.file,
        document: document,
        language: 'text',
      );
    }
    final source = document.source!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedTabs(
            tabs: [
              SegmentedTab(
                label: l10n.workspacePreviewRendered,
                icon: Lucide.Eye,
              ),
              SegmentedTab(
                label: l10n.workspacePreviewSource,
                icon: Lucide.FileCode,
              ),
            ],
            index: _showSource ? 1 : 0,
            onChanged: (next) => setState(() => _showSource = next == 1),
          ),
        ),
        Expanded(
          child: _showSource
              ? CodeFilePreview(
                  file: widget.file,
                  document: document,
                  language: 'markdown',
                )
              : source.trim().isEmpty
              ? PreviewEmptyHint(
                  title: l10n.workspacePreviewEmptyFile,
                  hint: l10n.workspacePreviewEmptyHint,
                  icon: Lucide.FileText,
                )
              : _MarkdownRenderedView(source: source),
        ),
      ],
    );
  }
}

class _MarkdownRenderedView extends StatelessWidget {
  const _MarkdownRenderedView({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final desktop = useDesktopWorkspaceLayout(context);
    final bool isDesktopPlatform =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    final double baseSize = isDesktopPlatform ? 14.0 : 15.7;
    final baseStyle = TextStyle(fontSize: baseSize, height: 1.5);

    final markdown = SelectionArea(
      child: DefaultTextStyle.merge(
        style: baseStyle,
        child: MarkdownWithCodeHighlight(text: source, baseStyle: baseStyle),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: desktop
          ? Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: markdown,
              ),
            )
          : markdown,
    );
  }
}
