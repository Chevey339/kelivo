/// Shell-style argument editing without executing expansions or operators.
/// Quoted empty strings and embedded newlines round-trip unchanged.
class StdioArguments {
  static String format(List<String> arguments) =>
      arguments.map(_quote).join(' ');

  static String _quote(String value) {
    if (value.isNotEmpty &&
        RegExp(r'^[a-zA-Z0-9_@%+=:,./-]+$').hasMatch(value)) {
      return value;
    }
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  static List<String> parse(String text) {
    final result = <String>[];
    var token = StringBuffer();
    String? quote;
    var started = false;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (quote == "'") {
        if (char == "'") {
          quote = null;
        } else {
          token.write(char);
        }
      } else if (char == '\\') {
        if (i + 1 == text.length) {
          throw const FormatException('Trailing escape');
        }
        final next = text[i + 1];
        if (quote == '"' && !['"', '\\', r'$', '`', '\n'].contains(next)) {
          token.write(char);
        } else {
          i++;
          if (next != '\n') {
            token.write(next);
            started = true;
          }
        }
      } else if (quote == '"') {
        if (char == '"') {
          quote = null;
        } else {
          token.write(char);
        }
      } else if (char == "'" || char == '"') {
        quote = char;
        started = true;
      } else if (RegExp(r'\s').hasMatch(char)) {
        if (started) {
          result.add(token.toString());
          token = StringBuffer();
          started = false;
        }
      } else {
        token.write(char);
        started = true;
      }
    }
    if (quote != null) throw const FormatException('Unclosed quote');
    if (started) result.add(token.toString());
    return result;
  }
}
