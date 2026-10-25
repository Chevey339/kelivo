import 'package:markstream/markstream.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Snapshot before dismissing the native toolbar: dismissal can clear selection.
/// Both representations belong to one item so paste targets choose their format.
Future<void> copyRichMarkdownSelection(
  MarkstreamSelectionController controller, {
  ClipboardWriter? writer,
}) async {
  final documents = controller.selectedDocuments;
  if (documents.isEmpty) {
    return;
  }
  final plain = controller.selectedPlainText;
  final html = documents.map(toHtml).join('\n');
  final clipboard = writer ?? SystemClipboard.instance;
  if (clipboard == null) {
    throw UnsupportedError('Rich clipboard is unavailable');
  }
  final item = DataWriterItem()
    ..add(Formats.htmlText(html))
    ..add(Formats.plainText(plain));
  await clipboard.write([item]);
}
