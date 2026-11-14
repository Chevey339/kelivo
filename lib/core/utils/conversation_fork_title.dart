/// Uses the first available positive suffix in the source title's sequence.
String nextConversationForkTitle(
  String sourceTitle,
  Iterable<String> existingTitles,
) {
  final base = sourceTitle.replaceFirst(RegExp(r'( \([1-9][0-9]*\))+$'), '');
  final occupied = existingTitles.toSet();
  var number = 1;
  while (occupied.contains('$base ($number)')) {
    number++;
  }
  return '$base ($number)';
}
