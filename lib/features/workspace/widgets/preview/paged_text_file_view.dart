import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'preview_states.dart';
import 'preview_text_document.dart';

class PagedTextFileView extends StatefulWidget {
  const PagedTextFileView({
    super.key,
    required this.document,
    required this.style,
  });

  static const listKey = ValueKey<String>('code-file-preview-plain-text-list');
  final PreviewTextDocument document;
  final TextStyle style;

  @override
  State<PagedTextFileView> createState() => _PagedTextFileViewState();
}

class _PagedTextFileViewState extends State<PagedTextFileView> {
  late final _reader = PreviewTextReader(widget.document);

  @override
  void dispose() {
    unawaited(_reader.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SuperListView.builder(
      key: PagedTextFileView.listKey,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      cacheExtent: 800,
      // Extent estimation permits an EOF jump without laying out every page
      // in between. Keep placeholders and the initial estimate the same size.
      extentEstimation: (_, _) => 240,
      itemCount: widget.document.chunkCount,
      itemBuilder: (context, index) => _TextPage(
        key: ValueKey<String>('preview-text-page-$index'),
        reader: _reader,
        index: index,
        style: widget.style,
      ),
    );
  }
}

class _TextPage extends StatefulWidget {
  const _TextPage({
    super.key,
    required this.reader,
    required this.index,
    required this.style,
  });

  final PreviewTextReader reader;
  final int index;
  final TextStyle style;

  @override
  State<_TextPage> createState() => _TextPageState();
}

class _TextPageState extends State<_TextPage> {
  late Future<String> _text = _read();

  Future<String> _read() =>
      widget.reader.readChunk(widget.index, isCancelled: () => !mounted);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _text,
      initialData: widget.reader.cachedChunk(widget.index),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
            height: 240,
            child: PreviewError(onRetry: () => setState(() => _text = _read())),
          );
        }
        final data = snapshot.data;
        if (data == null) return const SizedBox(height: 240);
        var text = data.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        if (widget.index < widget.reader.document.chunkCount - 1 &&
            text.endsWith('\n')) {
          text = text.substring(0, text.length - 1);
        }
        return SelectableText(
          text,
          key: ValueKey<String>('preview-text-chunk-${widget.index}'),
          style: widget.style,
          textDirection: TextDirection.ltr,
          scrollPhysics: const NeverScrollableScrollPhysics(),
        );
      },
    );
  }
}
