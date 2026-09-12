/// Returns the most useful short preview for a collapsed reasoning card.
///
/// Providers often stream one cumulative summary string. Keeping the whole
/// string in a collapsed card makes it look like the expanded card, so prefer
/// the newest-looking fragment and let the widget animate between updates.
String latestReasoningPreview(String raw, {int maxCharacters = 96}) {
  var value = raw.replaceAll('\r', '').trim();
  if (value.isEmpty) return '';

  final lines = value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isNotEmpty) value = lines.last;

  // Summary text is commonly wrapped in Markdown emphasis. Splitting on the
  // marker keeps the trailing/current fragment when a proxy concatenates
  // several summary updates without inserting whitespace.
  final emphasizedFragments = value
      .split('**')
      .map((fragment) => fragment.trim())
      .where((fragment) => fragment.isNotEmpty)
      .toList();
  if (emphasizedFragments.length > 1) {
    value = emphasizedFragments.last;
  }

  // If the provider did include sentence boundaries, the last sentence is a
  // better current-step preview than the entire accumulated summary.
  final sentences = value
      .split(RegExp(r'[.!?。！？；;]+'))
      .map((sentence) => sentence.trim())
      .where((sentence) => sentence.isNotEmpty)
      .toList();
  if (sentences.length > 1) value = sentences.last;

  value = value
      .replaceFirst(RegExp(r'^[\s>*_`~\-]+'), '')
      .replaceFirst(RegExp(r'[\s>*_`~]+$'), '')
      .trim();
  if (value.isEmpty) return '';
  if (value.length <= maxCharacters) return value;

  var tail = value.substring(value.length - maxCharacters);
  final firstWhitespace = RegExp(r'\s').firstMatch(tail);
  if (firstWhitespace != null && firstWhitespace.end < tail.length - 12) {
    tail = tail.substring(firstWhitespace.end);
  }
  return '…${tail.trim()}';
}
