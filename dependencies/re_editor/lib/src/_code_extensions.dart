part of 're_editor.dart';

extension _InlineSpanExtension on InlineSpan {

  int get length => _computeLength();

  int _computeLength() {
    int len = 0;
    if (this is TextSpan) {
      len += (this as TextSpan).length;
    } else {
      len += toPlainText(includePlaceholders: false).length;
    }
    return len;
  }

}

extension _TextSpanExtension on TextSpan {

  int get length => _computeLength();

  int _computeLength() {
    int len = 0;
    if (text != null) {
      len += text!.length;
    }
    if (children != null) {
      for (final InlineSpan span in children!) {
        len += span.length;
      }
    }
    return len;
  }

}

extension _OffsetExtension on Offset {

  bool isSamePosition(Offset offset) {
    return (this - offset).distance < 10;
  }

}