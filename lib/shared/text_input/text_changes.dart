import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/services.dart';
import 'compact_edit.dart';

/// Plain UTF-16 operations. Quill supplies composition and concurrent transforms;
/// the transport remains the editor's compact replacement format.
abstract final class TextChanges {
  static Delta diff(TextEditingValue before, TextEditingValue after) {
    if (before.text == after.text) return Delta();
    final selection = before.selection;
    if (selection.isValid && selection.end <= before.text.length) {
      final inserted =
          after.text.length -
          before.text.length +
          selection.end -
          selection.start;
      if (inserted >= 0 &&
          after.selection.isCollapsed &&
          after.selection.extentOffset == selection.start + inserted &&
          _equalRange(before.text, 0, after.text, 0, selection.start) &&
          _equalRange(
            before.text,
            selection.end,
            after.text,
            selection.start + inserted,
            before.text.length - selection.end,
          )) {
        return replacement(
          selection.start,
          selection.end,
          after.text.substring(selection.start, selection.start + inserted),
        );
      }
    }
    return (Delta()..insert(before.text)).diff(
      Delta()..insert(after.text),
      cleanupSemantic: false,
    );
  }

  static bool _equalRange(
    String a,
    int startA,
    String b,
    int startB,
    int length,
  ) {
    if (startB < 0 || startB + length > b.length) return false;
    for (var i = 0; i < length; i++) {
      if (a.codeUnitAt(startA + i) != b.codeUnitAt(startB + i)) return false;
    }
    return true;
  }

  static Delta replacement(int start, int end, String inserted) => Delta()
    ..retain(start)
    ..delete(end - start)
    ..insert(inserted);

  static Delta fromPatches(List<Object?> patches) {
    var result = Delta();
    for (final raw in patches) {
      final p = raw as List;
      result = result.compose(
        replacement(p[0] as int, p[1] as int, p[2] as String),
      );
    }
    return result;
  }

  static List<List<Object>> patches(Delta change) {
    var position = 0;
    final result = <List<Object>>[];
    for (final operation in change.toList()) {
      final length = operation.length!;
      if (operation.isRetain) {
        position += length;
      } else if (operation.isDelete) {
        result.add([position, position + length, '']);
      } else {
        final inserted = operation.data as String;
        result.add([position, position, inserted]);
        position += inserted.length;
      }
    }
    return result;
  }

  static String apply(String text, Delta change) {
    final edit = CompactEdit.coalesce(text, patches(change));
    return edit == null
        ? text
        : text.replaceRange(edit.start, edit.end, edit.text);
  }

  static TextSelection mapSelection(TextSelection selection, Delta change) =>
      TextSelection(
        baseOffset: change.transformPosition(
          selection.baseOffset,
          force:
              selection.isCollapsed ||
              selection.baseOffset > selection.extentOffset,
        ),
        extentOffset: change.transformPosition(
          selection.extentOffset,
          force:
              selection.isCollapsed ||
              selection.extentOffset > selection.baseOffset,
        ),
        affinity: selection.affinity,
        isDirectional: selection.isDirectional,
      );

  static TextRange mapComposing(TextRange range, Delta change) => !range.isValid
      ? TextRange.empty
      : TextRange(
          start: change.transformPosition(range.start, force: false),
          end: change.transformPosition(range.end),
        );
}
