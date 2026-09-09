import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart';

class _CachedParagraph {
  _CachedParagraph(this.paragraph, this.styleKey, this.codePoints);

  final Paragraph paragraph;

  /// Colors and attribute flags - everything but the text.
  final int styleKey;

  /// The text laid out, kept so a lookup can rule out a hash collision.
  final Uint32List codePoints;

  bool matches(int styleKey, Uint32List cps, int length) {
    if (this.styleKey != styleKey) return false;
    if (codePoints.length != length) return false;
    for (var i = 0; i < length; i++) {
      if (codePoints[i] != cps[i]) return false;
    }
    return true;
  }
}

/// A cache of laid out [Paragraph]s. This is used to avoid laying out the same
/// text multiple times, which is expensive.
///
/// Lookups are by hash, then verified against the entry's text and style - a
/// collision would put the wrong glyphs on screen, and the check is cheap next
/// to a re-layout.
///
/// Eviction is generational rather than LRU: when the hot generation fills, the
/// cold one is dropped whole and hot becomes cold. A hit never has to reorder
/// anything, which matters at one lookup per visible run per frame.
///
/// Evicted paragraphs are disposed. [Canvas.drawParagraph] paints immediately
/// rather than retaining the paragraph, so disposing one already drawn this
/// frame is safe.
class ParagraphCache {
  ParagraphCache(this.maximumSize);

  /// Entries the hot generation holds before rotating. Up to twice this many
  /// paragraphs can be alive at once, counting the cold generation.
  final int maximumSize;

  var _hot = <int, _CachedParagraph>{};

  var _cold = <int, _CachedParagraph>{};

  /// Returns the [Paragraph] cached under [key], or null if there is none that
  /// was laid out from exactly [codePoints] (up to [length]) in [styleKey].
  Paragraph? getLayoutFromCache(
    int key,
    int styleKey,
    Uint32List codePoints,
    int length,
  ) {
    final hit = _hot[key];
    if (hit != null) {
      return hit.matches(styleKey, codePoints, length) ? hit.paragraph : null;
    }

    final promoted = _cold.remove(key);
    if (promoted != null) {
      if (!promoted.matches(styleKey, codePoints, length)) {
        promoted.paragraph.dispose();
        return null;
      }
      _hot[key] = promoted;
      return promoted.paragraph;
    }

    return null;
  }

  /// Applies [style] and [textScaler] to [codePoints] and lays it out to create
  /// a [Paragraph]. The [Paragraph] is cached and can be retrieved with the
  /// same [key], [styleKey] and text by calling [getLayoutFromCache].
  Paragraph performAndCacheLayout(
    Uint32List codePoints,
    int length,
    TextStyle style,
    StrutStyle strutStyle,
    TextScaler textScaler,
    int key,
    int styleKey,
  ) {
    final builder = ParagraphBuilder(
      // The scaler has to reach the strut too: it pins the line height, so
      // left unscaled it would hold the line at its unscaled size and clip
      // text the user asked to be bigger.
      style.getParagraphStyle(strutStyle: strutStyle, textScaler: textScaler),
    );
    builder.pushStyle(style.getTextStyle(textScaler: textScaler));
    builder.addText(String.fromCharCodes(codePoints, 0, length));

    final paragraph = builder.build();
    paragraph.layout(const ParagraphConstraints(width: double.infinity));

    if (_hot.length >= maximumSize) _rotate();

    // The caller reuses its scratch buffer for the next run, so keep a copy.
    _hot[key] = _CachedParagraph(
      paragraph,
      styleKey,
      codePoints.sublist(0, length),
    );

    return paragraph;
  }

  /// Retires the cold generation and makes the current hot generation cold.
  void _rotate() {
    for (final entry in _cold.values) {
      entry.paragraph.dispose();
    }
    _cold = _hot;
    _hot = <int, _CachedParagraph>{};
  }

  /// Clears the cache. This should be called when the same text and style
  /// pair no longer produces the same layout. For example, when a font is
  /// loaded.
  void clear() {
    for (final entry in _cold.values) {
      entry.paragraph.dispose();
    }
    for (final entry in _hot.values) {
      entry.paragraph.dispose();
    }
    _cold = <int, _CachedParagraph>{};
    _hot = <int, _CachedParagraph>{};
  }

  int get length {
    return _hot.length + _cold.length;
  }
}
