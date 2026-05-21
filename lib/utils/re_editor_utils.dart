import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:re_editor/re_editor.dart';

extension CodeLineEditingControllerX on CodeLineEditingController {
  /// Safely set editor text without losing content or breaking IME composition.
  ///
  /// - Skips updates while composing (IME) by default to avoid disrupting input.
  /// - Uses [CodeLineEditingValue] so selection/composing are consistent.
  /// - Places the cursor at the end of the content by default.
  /// - Falls back to setting [text] directly if parsing fails.
  void setTextSafely(
    String nextText, {
    bool skipIfComposing = true,
    bool moveCursorToEnd = true,
  }) {
    if (skipIfComposing && isComposing) return;
    if (text == nextText) return;

    if (nextText.isEmpty) {
      value = const CodeLineEditingValue.empty();
      return;
    }

    try {
      final lines = nextText.codeLines;
      if (lines.isEmpty) {
        // Defensive fallback; should be rare for non-empty strings.
        text = nextText;
        return;
      }

      CodeLineSelection selection;
      if (moveCursorToEnd) {
        final lastIndex = lines.length - 1;
        final lastOffset = lines.last.length;
        selection =
            CodeLineSelection.collapsed(index: lastIndex, offset: lastOffset);
      } else {
        selection = const CodeLineSelection.collapsed(index: 0, offset: 0);
      }

      value = CodeLineEditingValue(
        codeLines: lines,
        selection: selection,
        composing: TextRange.empty,
      );
    } catch (e, s) {
      debugPrint('Failed to set CodeLineEditingController text: $e');
      debugPrintStack(stackTrace: s);
      try {
        text = nextText;
      } catch (_) {}
    }
  }
}

