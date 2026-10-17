import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Code text chunks have the same offsets as their source. Copying the selected
/// source range preserves indentation and line breaks across visual line chunks.
class CodeSelectionDelegate extends StaticSelectionContainerDelegate {
  CodeSelectionDelegate(this.source) {
    addListener(WidgetsBinding.instance.ensureVisualUpdate);
  }
  String source;

  @override
  SelectedContent? getSelectedContent() {
    final range = getSelection();
    if (range == null || range.startOffset == range.endOffset) return null;
    final start = math
        .min(range.startOffset, range.endOffset)
        .clamp(0, source.length);
    final end = math
        .max(range.startOffset, range.endOffset)
        .clamp(start, source.length);
    return SelectedContent(plainText: source.substring(start, end));
  }
}
