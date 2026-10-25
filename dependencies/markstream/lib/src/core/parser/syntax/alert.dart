final _alert = RegExp(
  r'^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\](?:[ \t]+(.*?))?[ \t]*$',
  caseSensitive: false,
);
({String name, String? title})? readAlert(String text) {
  final match = _alert.firstMatch(text);
  if (match == null) return null;
  final title = match[2]?.trim();
  return (
    name: match[1]!.toLowerCase(),
    title: title == null || title.isEmpty ? null : title,
  );
}
