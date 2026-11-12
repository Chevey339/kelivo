import 'package:markstream/markstream.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'dart:convert';

Future<void> copyRichTextSnapshot(
  String text, {
  String? markdown,
  ClipboardWriter? writer,
  void Function(Iterable<String>)? verifyBudget,
}) async {
  final html = markdown == null
      ? '<p>${const HtmlEscape().convert(text).replaceAll('\n', '<br>')}</p>'
      : toHtml(const MarkdownParser().parse(markdown));
  verifyBudget?.call([text, html]);
  final clipboard = writer ?? SystemClipboard.instance;
  if (clipboard == null) {
    throw UnsupportedError('Rich clipboard is unavailable');
  }
  await clipboard.write([
    DataWriterItem()
      ..add(Formats.htmlText(html))
      ..add(Formats.plainText(text)),
  ]);
}

/// Snapshot before dismissing the native toolbar: dismissal can clear selection.
/// Both representations belong to one item so paste targets choose their format.
Future<void> copyRichMarkdownSelection(
  MarkstreamSelectionController controller, {
  ClipboardWriter? writer,
  int? byteLimit,
}) async {
  final documents = controller.selectedDocuments;
  if (documents.isEmpty) {
    return;
  }
  final plain = controller.selectedPlainText;
  final html = documents.map(toHtml).join('\n');
  controller.verifyCopyBudget([plain, html], byteLimit: byteLimit);
  final clipboard = writer ?? SystemClipboard.instance;
  if (clipboard == null) {
    throw UnsupportedError('Rich clipboard is unavailable');
  }
  final item = DataWriterItem()
    ..add(Formats.htmlText(html))
    ..add(Formats.plainText(plain));
  await clipboard.write([item]);
}
