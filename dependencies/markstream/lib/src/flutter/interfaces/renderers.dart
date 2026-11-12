import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/ast/nodes.dart';
import '../theme/markstream_theme.dart';

/// Supplies styled spans with exactly the same plain text as [source].
abstract interface class CodeHighlighter {
  FutureOr<TextSpan> highlight(
    String source, {
    required String language,
    required TextStyle style,
    required Brightness brightness,
  });
}

/// Builds visual math only; the library owns its selectable LaTeX source.
abstract interface class MathRenderer {
  Widget build(
    BuildContext context,
    String tex, {
    required TextStyle style,
    required bool displayMode,
  });
}

abstract interface class ImageBuilder {
  Widget build(BuildContext context, ImageNode image, MarkstreamTheme theme);
}

abstract interface class LinkHandler {
  FutureOr<void> open(BuildContext context, LinkNode link);
}
