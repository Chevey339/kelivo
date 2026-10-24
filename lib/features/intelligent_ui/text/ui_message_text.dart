import 'package:markstream/markstream_core.dart';
import 'package:Kelivo/core/services/tts/tts_text_selection.dart';
import '../catalog/ui_budgets.dart';
import 'ui_bounded_text.dart';

/// A frozen message projection. UI values are literal text, so a value such as
/// `-3`, backticks or a Markdown link is never reinterpreted as syntax.
final class UiMessageText {
  UiMessageText({
    required this.source,
    required Iterable<TtsTextPart> parts,
    required this.omitted,
    required this.hasUi,
  }) : parts = List.unmodifiable(parts);
  final String source, omitted;
  final List<TtsTextPart> parts;
  final bool hasUi;

  late final String copyText = _copyText();

  /// Bound input work as well as output. Huge ordinary prose is omitted as one
  /// source unit before parsing; semantic fields are kept or omitted whole.
  late final List<TtsTextPart> _boundedParts = _bound();
  List<TtsTextPart> _bound() {
    final budget = UiBoundedText(UiBudgets.copyBytes, omission: omitted);
    final result = <TtsTextPart>[];
    for (final part in parts) {
      if (!part.literal) {
        if (budget.add(part.text)) result.add(part);
        continue;
      }
      final kept = [
        for (final line in part.text.split('\n'))
          if (budget.add(line)) line,
      ];
      if (kept.isNotEmpty) {
        result.add(TtsTextPart(kept.join('\n'), literal: true));
      }
    }
    if (budget.omitted) result.add(TtsTextPart(omitted, literal: true));
    return List.unmodifiable(result);
  }

  String _copyText() {
    if (!hasUi) return source;
    final result = UiBoundedText(UiBudgets.copyBytes, omission: omitted);
    for (final part in _boundedParts) {
      final text = part.literal
          ? part.text
          : toPlainText(const MarkdownParser().parse(part.text));
      for (final line in text.split('\n')) {
        result.add(line);
      }
    }
    return result.finish();
  }

  String speech(TtsTextSelectionMode mode) =>
      TtsTextSelection.prepareParts(_boundedParts, mode: mode);
}
