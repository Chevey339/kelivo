final _alert = RegExp(
  r'^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\][ \t]*$',
  caseSensitive: false,
);
String? alertName(String text) => _alert.firstMatch(text)?[1]?.toLowerCase();
