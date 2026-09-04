/// YAML frontmatter for a `SKILL.md` body.
class SkillFrontmatter {
  const SkillFrontmatter({
    required this.name,
    required this.description,
    required this.body,
    this.extras = const <String, dynamic>{},
  });

  final String name;
  final String description;
  final String body;
  final Map<String, dynamic> extras;

  /// Parse markdown that may start with `---` YAML frontmatter.
  ///
  /// Tolerates a leading BOM and CRLF. When frontmatter is missing, [name]
  /// is taken from the first `# Heading` or left empty (see [validate]).
  factory SkillFrontmatter.parse(String markdown) {
    var text = markdown;
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    String? yamlBlock;
    var body = text;
    final lines = text.split('\n');
    if (lines.isNotEmpty && _isFence(lines.first)) {
      for (var i = 1; i < lines.length; i++) {
        if (_isFence(lines[i])) {
          yamlBlock = lines.sublist(1, i).join('\n');
          body = lines.sublist(i + 1).join('\n');
          break;
        }
      }
    }

    var name = '';
    var description = '';
    var extras = <String, dynamic>{};
    if (yamlBlock != null) {
      try {
        final map = _parseYamlMap(yamlBlock);
        name = _scalarString(map['name']);
        description = _scalarString(map['description']);
        extras = Map<String, dynamic>.from(map)
          ..remove('name')
          ..remove('description');
      } catch (_) {
        extras = const <String, dynamic>{};
      }
    }

    if (name.trim().isEmpty) {
      name = _firstHeading(body) ?? '';
    }

    return SkillFrontmatter(
      name: name.trim(),
      description: description,
      body: body,
      extras: extras,
    );
  }

  /// Human-readable problems. Empty means the skill can be imported.
  List<String> validate() {
    final errors = <String>[];
    if (name.trim().isEmpty) errors.add('missing name');
    if (description.trim().isEmpty) errors.add('missing description');
    return errors;
  }
}

/// Lowercase `[a-z0-9-]` slug, at most 64 characters.
String slugify(String name) {
  var slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  slug = slug.replaceAll(RegExp(r'-{2,}'), '-');
  slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.length > 64) {
    slug = slug.substring(0, 64).replaceAll(RegExp(r'-+$'), '');
  }
  return slug.isEmpty ? 'skill' : slug;
}

bool _isFence(String line) => RegExp(r'^---\s*$').hasMatch(line);

String? _firstHeading(String text) {
  for (final line in text.split('\n')) {
    final match = RegExp(r'^#{1,6}\s+(.+?)\s*$').firstMatch(line);
    if (match != null) return match.group(1);
  }
  return null;
}

String _scalarString(Object? value) {
  if (value == null) return '';
  return value.toString();
}

Map<String, dynamic> _parseYamlMap(String yaml) {
  final lines = yaml.split('\n');
  return _parseIndentedMap(lines, 0, 0).map;
}

({Map<String, dynamic> map, int next}) _parseIndentedMap(
  List<String> lines,
  int start,
  int minIndent,
) {
  final map = <String, dynamic>{};
  var i = start;
  while (i < lines.length) {
    final raw = lines[i];
    if (raw.trim().isEmpty || raw.trimLeft().startsWith('#')) {
      i++;
      continue;
    }
    final indent = _indentOf(raw);
    if (indent < minIndent) break;
    if (indent > minIndent && minIndent == 0 && map.isEmpty) {
      i++;
      continue;
    }
    if (indent != minIndent && map.isNotEmpty) break;

    final content = raw.substring(indent);
    final parsed = _splitKeyValue(content);
    if (parsed == null) {
      i++;
      continue;
    }
    final key = parsed.key;
    final rest = parsed.rest;
    if (rest == '|' ||
        rest == '|-' ||
        rest == '|+' ||
        rest == '>' ||
        rest == '>-' ||
        rest == '>+') {
      final block = _readBlockScalar(
        lines,
        i + 1,
        indent,
        fold: rest.startsWith('>'),
        stripFinal: rest.endsWith('-'),
      );
      map[key] = block.value;
      i = block.next;
      continue;
    }
    if (rest.isEmpty) {
      final peek = _nextSignificant(lines, i + 1);
      if (peek != null && peek.indent > indent) {
        final peekContent = lines[peek.index].substring(peek.indent).trimLeft();
        if (peekContent.startsWith('- ')) {
          final list = _parseList(lines, i + 1, peek.indent);
          map[key] = list.list;
          i = list.next;
        } else {
          final nested = _parseIndentedMap(lines, i + 1, peek.indent);
          map[key] = nested.map;
          i = nested.next;
        }
        continue;
      }
      map[key] = '';
      i++;
      continue;
    }
    map[key] = _parseScalar(rest);
    i++;
  }
  return (map: map, next: i);
}

({List<dynamic> list, int next}) _parseList(
  List<String> lines,
  int start,
  int itemIndent,
) {
  final list = <dynamic>[];
  var i = start;
  while (i < lines.length) {
    final raw = lines[i];
    if (raw.trim().isEmpty) {
      i++;
      continue;
    }
    final indent = _indentOf(raw);
    if (indent < itemIndent) break;
    final content = raw.substring(indent);
    if (!content.startsWith('- ')) {
      if (indent > itemIndent) {
        i++;
        continue;
      }
      break;
    }
    list.add(_parseScalar(content.substring(2)));
    i++;
  }
  return (list: list, next: i);
}

({String key, String rest})? _splitKeyValue(String content) {
  final match = RegExp(r'^([A-Za-z0-9_-]+)\s*:\s*(.*)$').firstMatch(content);
  if (match == null) return null;
  return (key: match.group(1)!, rest: match.group(2) ?? '');
}

({int index, int indent})? _nextSignificant(List<String> lines, int from) {
  for (var i = from; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.trim().isEmpty || raw.trimLeft().startsWith('#')) continue;
    return (index: i, indent: _indentOf(raw));
  }
  return null;
}

({String value, int next}) _readBlockScalar(
  List<String> lines,
  int start,
  int parentIndent, {
  required bool fold,
  required bool stripFinal,
}) {
  final collected = <String>[];
  var i = start;
  var contentIndent = -1;
  while (i < lines.length) {
    final raw = lines[i];
    if (raw.trim().isEmpty) {
      collected.add('');
      i++;
      continue;
    }
    final indent = _indentOf(raw);
    if (indent <= parentIndent) break;
    if (contentIndent < 0) contentIndent = indent;
    collected.add(
      indent >= contentIndent ? raw.substring(contentIndent) : raw.trimLeft(),
    );
    i++;
  }
  while (collected.isNotEmpty && collected.last.isEmpty) {
    collected.removeLast();
  }
  String value;
  if (fold) {
    final buf = StringBuffer();
    var pendingSpace = false;
    for (final line in collected) {
      if (line.isEmpty) {
        buf.writeln();
        pendingSpace = false;
        continue;
      }
      if (pendingSpace) buf.write(' ');
      buf.write(line);
      pendingSpace = true;
    }
    value = buf.toString();
  } else {
    value = collected.join('\n');
  }
  if (!stripFinal && value.isNotEmpty) value = '$value\n';
  return (value: value, next: i);
}

int _indentOf(String line) {
  var n = 0;
  while (n < line.length && (line[n] == ' ' || line[n] == '\t')) {
    n++;
  }
  return n;
}

dynamic _parseScalar(String raw) {
  var text = raw.trim();
  final comment = text.indexOf(' #');
  if (comment >= 0 && !text.startsWith('"') && !text.startsWith("'")) {
    text = text.substring(0, comment).trimRight();
  }
  if (text.isEmpty) return '';
  if (text == 'true') return true;
  if (text == 'false') return false;
  if (text == 'null' || text == '~') return null;
  if (text.startsWith('[') && text.endsWith(']')) {
    return _parseFlowList(text);
  }
  if ((text.startsWith('"') && text.endsWith('"') && text.length >= 2) ||
      (text.startsWith("'") && text.endsWith("'") && text.length >= 2)) {
    return _unquote(text);
  }
  final number = num.tryParse(text);
  if (number != null) return number;
  return text;
}

List<dynamic> _parseFlowList(String text) {
  final inner = text.substring(1, text.length - 1).trim();
  if (inner.isEmpty) return <dynamic>[];
  return [for (final part in _splitFlow(inner)) _parseScalar(part)];
}

List<String> _splitFlow(String inner) {
  final parts = <String>[];
  final buf = StringBuffer();
  var quote = '';
  for (var i = 0; i < inner.length; i++) {
    final ch = inner[i];
    if (quote.isEmpty && (ch == '"' || ch == "'")) {
      quote = ch;
      buf.write(ch);
      continue;
    }
    if (quote.isNotEmpty) {
      buf.write(ch);
      if (ch == quote) quote = '';
      continue;
    }
    if (ch == ',') {
      parts.add(buf.toString());
      buf.clear();
      continue;
    }
    buf.write(ch);
  }
  if (buf.isNotEmpty) parts.add(buf.toString());
  return parts;
}

String _unquote(String text) {
  if (text.length < 2) return text;
  final quote = text[0];
  if (quote != '"' && quote != "'") return text;
  if (text[text.length - 1] != quote) return text;
  final inner = text.substring(1, text.length - 1);
  if (quote == "'") return inner.replaceAll("''", "'");
  final buf = StringBuffer();
  for (var i = 0; i < inner.length; i++) {
    final ch = inner[i];
    if (ch != '\\' || i == inner.length - 1) {
      buf.write(ch);
      continue;
    }
    final next = inner[++i];
    switch (next) {
      case 'n':
        buf.write('\n');
      case 't':
        buf.write('\t');
      case 'r':
        buf.write('\r');
      case '\\':
        buf.write('\\');
      case '"':
        buf.write('"');
      default:
        buf.write(next);
    }
  }
  return buf.toString();
}
