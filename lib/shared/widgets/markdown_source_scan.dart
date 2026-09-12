/// Records syntax that can require whole-source preprocessing. Streaming
/// updates validate the prefix once, then inspect only the new code units.
final class MarkdownSourceScan {
  String _source = '';
  bool appended = true;
  bool hasBrackets = false;
  bool hasHtml = false;
  bool hasCarriageReturns = false;
  bool needsPreprocessing = false;
  int scannedCodeUnits = 0;

  void update(String source) {
    if (identical(source, _source)) return;
    appended = source.startsWith(_source);
    final start = appended ? _source.length : 0;
    if (!appended) {
      hasBrackets = hasHtml = hasCarriageReturns = needsPreprocessing = false;
    }
    scannedCodeUnits += source.length - start;
    for (var i = start; i < source.length; i++) {
      switch (source.codeUnitAt(i)) {
        case 0x5b: // [ starts image and citation syntax.
          hasBrackets = needsPreprocessing = true;
        case 0x3c: // < starts HTML, including details blocks.
          hasHtml = needsPreprocessing = true;
        case 0x0d:
          hasCarriageReturns = needsPreprocessing = true;
        case 0x60 || // `
            0x7e || // ~
            0x24 || // $
            0x5c || // \
            0x23 || // #
            0x5d || // ]
            0x2d || // -
            0x7c || // |
            0x3e: // >
          needsPreprocessing = true;
      }
    }
    _source = source;
  }
}
