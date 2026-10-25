import '../../ast/source_span.dart';

final class DirectiveStart {
  DirectiveStart(
    this.start,
    this.end,
    this.colons,
    this.name,
    this.label,
    Map<String, String> attributes,
  ) : attributes = Map.unmodifiable(attributes);
  final int start;
  final int end;
  final int colons;
  final String name;
  final SourceSpan? label;
  final Map<String, String> attributes;
}

final _name = RegExp(r'[A-Za-z][A-Za-z0-9_-]*');
final _attributeName = RegExp(r'[A-Za-z_:][A-Za-z0-9_.:-]*');
bool _space(int c) => c == 32 || c == 9;

/// Parses all three directive forms, leaving block/inline placement to callers.
DirectiveStart? readDirective(String source, int start, int end) {
  var i = start;
  while (i < end && source.codeUnitAt(i) == 58) i++;
  final count = i - start;
  if (count == 0) return null;
  final name = _name.matchAsPrefix(source, i);
  if (name == null ||
      name.end > end ||
      name[0]!.endsWith('-') ||
      name[0]!.endsWith('_'))
    return null;
  i = name.end;
  SourceSpan? label;
  if (i < end && source.codeUnitAt(i) == 91) {
    final labelStart = ++i;
    var depth = 1;
    for (; i < end; i++) {
      final c = source.codeUnitAt(i);
      if (c == 92) {
        i++;
        continue;
      }
      if (c == 96) {
        var run = i + 1;
        while (run < end && source.codeUnitAt(run) == 96) run++;
        final marker = source.substring(i, run);
        var close = source.indexOf(marker, run);
        while (close >= 0 && close + marker.length <= end) {
          var after = close + marker.length;
          while (after < end && source.codeUnitAt(after) == 96) after++;
          if (after - close == marker.length) {
            i = after - 1;
            break;
          }
          close = source.indexOf(marker, after);
        }
        if (close >= 0 && close + marker.length <= end) continue;
        i = run - 1;
        continue;
      }
      if (c == 91) depth++;
      if (c == 93) {
        depth--;
        if (depth == 0) break;
      }
    }
    if (i >= end) return null;
    label = SourceSpan(labelStart, i++);
  }
  final attributes = <String, String>{};
  if (i < end && source.codeUnitAt(i) == 123) {
    i++;
    while (i < end) {
      while (i < end && _space(source.codeUnitAt(i))) i++;
      if (i < end && source.codeUnitAt(i) == 125) {
        i++;
        break;
      }
      if (i >= end) return null;
      final shortcut = source.codeUnitAt(i) == 35 || source.codeUnitAt(i) == 46;
      String key;
      String value;
      if (shortcut) {
        key = source.codeUnitAt(i++) == 35 ? 'id' : 'class';
        final beginning = i;
        while (i < end &&
            !_space(source.codeUnitAt(i)) &&
            source.codeUnitAt(i) != 125)
          i++;
        if (i == beginning) return null;
        value = source.substring(beginning, i);
      } else {
        final attr = _attributeName.matchAsPrefix(source, i);
        if (attr == null || attr.end > end) return null;
        key = attr[0]!;
        i = attr.end;
        final afterName = i;
        while (i < end && _space(source.codeUnitAt(i))) i++;
        value = '';
        if (i < end && source.codeUnitAt(i) == 61) {
          i++;
          while (i < end && _space(source.codeUnitAt(i))) i++;
          if (i >= end) return null;
          final quote = source.codeUnitAt(i);
          if (quote == 34 || quote == 39) {
            final beginning = ++i;
            while (i < end && source.codeUnitAt(i) != quote) {
              if (source.codeUnitAt(i) == 92) i++;
              i++;
            }
            if (i >= end) return null;
            value = source.substring(beginning, i++);
          } else {
            final beginning = i;
            while (i < end &&
                !_space(source.codeUnitAt(i)) &&
                source.codeUnitAt(i) != 125) {
              if ('"\'<=`{'.contains(source[i])) return null;
              i++;
            }
            if (i == beginning) return null;
            value = source.substring(beginning, i);
          }
        } else {
          i = afterName;
        }
      }
      attributes[key] = key == 'class' && attributes.containsKey(key)
          ? '${attributes[key]} $value'
          : value;
      if (i < end &&
          !_space(source.codeUnitAt(i)) &&
          source.codeUnitAt(i) != 125)
        return null;
    }
    if (i == 0 || source.codeUnitAt(i - 1) != 125) return null;
  } else if (label == null &&
      count == 1 &&
      i < end &&
      source.codeUnitAt(i) == 58) {
    return null;
  }
  return DirectiveStart(start, i, count, name[0]!, label, attributes);
}

DirectiveStart? readBlockDirective(String source, int start, int end) {
  final result = readDirective(source, start, end);
  if (result == null ||
      result.colons < 2 ||
      source.substring(result.end, end).trim().isNotEmpty)
    return null;
  return result;
}
