import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/segmented_tabs.dart';

import 'code_file_preview.dart';
import 'preview_states.dart';

class HtmlFilePreview extends StatefulWidget {
  const HtmlFilePreview({super.key, required this.file, this.autoLoad = true});

  final File file;
  final bool autoLoad;

  @override
  State<HtmlFilePreview> createState() => _HtmlFilePreviewState();
}

class _HtmlFilePreviewState extends State<HtmlFilePreview> {
  WebViewController? _controller;
  Object? _error;
  bool _showSource = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      unawaited(_init());
    } else {
      _loading = false;
    }
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.loadFile(widget.file.absolute.path);
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_showSource) {
      return CodeFilePreview(
        file: widget.file,
        autoLoad: widget.autoLoad,
        language: 'xml',
      );
    }
    if (_error != null) {
      return PreviewError(onRetry: () => unawaited(_init()));
    }
    if (_loading || _controller == null) {
      return const PreviewLoading();
    }
    return WebViewWidget(controller: _controller!);
  }
}
