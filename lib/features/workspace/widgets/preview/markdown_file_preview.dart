import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:Kelivo/shared/widgets/segmented_tabs.dart';

import 'code_file_preview.dart';
import 'preview_states.dart';

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
  String? _source;
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

  @visibleForTesting
  Future<void> load() async {
    try {
      final source = widget.file.readAsStringSync();
      if (!mounted) return;
      setState(() {
        _source = source;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_error != null) {
      return PreviewError(onRetry: () => unawaited(load()));
    }
    final source = _source;
    if (source == null) {
      return const PreviewLoading();
    }
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
                  autoLoad: widget.autoLoad,
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
    final desktop = ResponsiveHelper.isDesktop(context);
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
