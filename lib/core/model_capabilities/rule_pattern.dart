import 'package:flutter/foundation.dart';

import 'model_tokenizer.dart';

/// The result of matching one pattern alternative against a token stream.
@immutable
class PatternMatch implements Comparable<PatternMatch> {
  const PatternMatch({
    required this.anchored,
    required this.endAnchored,
    required this.consumedTokens,
    required this.literalTokens,
  });

  /// Whether the match started at the first token.
  final bool anchored;

  /// Whether the match had to end at the close of the id (or at a `:` boundary).
  final bool endAnchored;

  /// How many id tokens the alternative consumed.
  final int consumedTokens;

  /// How many of those tokens were pinned to a plain literal. Token sets and
  /// version bounds do not count, so `'^gpt 5.2'` outranks `'^gpt 5 {v>=2}'`.
  final int literalTokens;

  /// Orders matches by specificity: start anchor, end anchor, then breadth,
  /// then literals.
  @override
  int compareTo(PatternMatch other) {
    if (anchored != other.anchored) return anchored ? 1 : -1;
    if (endAnchored != other.endAnchored) return endAnchored ? 1 : -1;
    if (consumedTokens != other.consumedTokens) {
      return consumedTokens.compareTo(other.consumedTokens);
    }
    return literalTokens.compareTo(other.literalTokens);
  }
}

/// A single parsed pattern alternative.
@immutable
class PatternAlternative {
  const PatternAlternative({
    required this.anchored,
    required this.endAnchored,
    required this.items,
    this.minDate,
    this.requireDate = false,
  });

  final bool anchored;
  final bool endAnchored;
  final List<PatternItem> items;
  final ModelDate? minDate;

  /// When true, [minDate] only matches ids that actually carry a snapshot;
  /// bare aliases are rejected.
  final bool requireDate;

  /// Matches this alternative anywhere in [tokens] (or at the start when
  /// [anchored]).
  ///
  /// A `@>=` bound admits bare aliases (no snapshot) and dated snapshots at or
  /// after the bound; `@snap>=` additionally requires a snapshot, and a
  /// yearless snapshot cannot be ordered and so is rejected either way.
  /// A trailing `$` accepts the end of the id as well as the start of a
  /// colon-qualified variant (see [TokenizedModelId.colonBoundaries]).
  PatternMatch? match(
    List<String> tokens, {
    ModelDate? date,
    Set<int> colonBoundaries = const <int>{},
  }) {
    final threshold = minDate;
    if (threshold != null) {
      if (date == null) {
        if (requireDate) return null;
      } else if (!date.isOnOrAfter(threshold)) {
        return null;
      }
    }
    final starts = anchored
        ? const <int>[0]
        : <int>[for (var i = 0; i < tokens.length; i++) i];
    for (final start in starts) {
      final consumed = _matchFrom(tokens, start, colonBoundaries);
      if (consumed != null) {
        return PatternMatch(
          anchored: anchored,
          endAnchored: endAnchored,
          consumedTokens: consumed.consumed,
          literalTokens: consumed.literals,
        );
      }
    }
    return null;
  }

  ({int consumed, int literals})? _matchFrom(
    List<String> tokens,
    int start,
    Set<int> colonBoundaries,
  ) {
    var cursor = start;
    var literals = 0;
    for (final item in items) {
      switch (item) {
        case _LiteralTokens(tokens: final expected):
          for (final expectedToken in expected) {
            if (cursor >= tokens.length || tokens[cursor] != expectedToken) {
              return null;
            }
            cursor++;
            literals++;
          }
        case _TokenSet(values: final values):
          if (cursor >= tokens.length || !values.contains(tokens[cursor])) {
            return null;
          }
          cursor++;
        case _VersionAtLeast(
          major: final thresholdMajor,
          minor: final thresholdMinor,
        ):
          if (cursor >= tokens.length || !_isNumeric(tokens[cursor])) {
            return null;
          }
          final first = int.parse(tokens[cursor]);
          final hasPair =
              cursor + 1 < tokens.length && _isNumeric(tokens[cursor + 1]);
          final parsedMajor = first;
          final parsedMinor = hasPair ? int.parse(tokens[cursor + 1]) : 0;
          if (!_versionAtLeast(
            parsedMajor,
            parsedMinor,
            thresholdMajor,
            thresholdMinor,
          )) {
            return null;
          }
          cursor += hasPair ? 2 : 1;
      }
    }
    if (endAnchored &&
        cursor != tokens.length &&
        !colonBoundaries.contains(cursor)) {
      return null;
    }
    return (consumed: cursor - start, literals: literals);
  }
}

/// A matchable unit inside a pattern alternative.
sealed class PatternItem {
  const PatternItem();
}

class _LiteralTokens extends PatternItem {
  const _LiteralTokens(this.tokens);

  final List<String> tokens;
}

class _TokenSet extends PatternItem {
  const _TokenSet(this.values);

  final Set<String> values;
}

class _VersionAtLeast extends PatternItem {
  const _VersionAtLeast(this.major, this.minor);

  final int major;
  final int minor;
}

/// Parses and caches the rule pattern DSL.
///
/// Grammar:
/// ```
/// pattern     := alternative ('|' alternative)*
/// alternative := ['^'] item+ ['@>=' YYYY-MM-DD]
/// item        := literal | '{' value ('|' value)* '}' | '{v>=' major ['.' minor] '}'
/// ```
/// Whitespace separates items. Literal chunks are tokenized with the same
/// tokenizer as model ids, so `'gpt 5.2'` and `'gpt-5-2'` are equivalent.
class RulePattern {
  RulePattern._(this.source, this.alternatives);

  final String source;
  final List<PatternAlternative> alternatives;

  static final Map<String, RulePattern> _cache = <String, RulePattern>{};

  static RulePattern parse(String source) {
    final key = source.trim();
    return _cache.putIfAbsent(key, () => _parse(key));
  }

  /// Returns the most specific matching alternative, or `null`.
  PatternMatch? bestMatch(
    List<String> tokens, {
    ModelDate? date,
    Set<int> colonBoundaries = const <int>{},
  }) {
    PatternMatch? best;
    for (final alternative in alternatives) {
      final match = alternative.match(
        tokens,
        date: date,
        colonBoundaries: colonBoundaries,
      );
      if (match == null) continue;
      if (best == null || match.compareTo(best) > 0) best = match;
    }
    return best;
  }

  bool matches(
    List<String> tokens, {
    ModelDate? date,
    Set<int> colonBoundaries = const <int>{},
  }) => bestMatch(tokens, date: date, colonBoundaries: colonBoundaries) != null;

  static RulePattern _parse(String source) {
    if (source.isEmpty) {
      throw const FormatException('Rule pattern must not be empty');
    }
    var depth = 0;
    for (final unit in source.codeUnits) {
      if (unit == 0x7b) depth++;
      if (unit == 0x7d) depth--;
      if (depth < 0) {
        throw FormatException('Unbalanced "}" in pattern "$source"');
      }
    }
    if (depth != 0) {
      throw FormatException('Unbalanced "{" in pattern "$source"');
    }
    final alternatives = <PatternAlternative>[
      for (final part in _splitTopLevel(source))
        _parseAlternative(part, source),
    ];
    return RulePattern._(source, List.unmodifiable(alternatives));
  }

  static PatternAlternative _parseAlternative(String raw, String source) {
    var text = raw.trim();
    if (text.isEmpty) {
      throw FormatException('Empty alternative in pattern "$source"');
    }
    var anchored = false;
    if (text.startsWith('^')) {
      anchored = true;
      text = text.substring(1).trim();
    }

    var endAnchored = false;
    void stripEndAnchor() {
      final trimmed = text.trimRight();
      if (trimmed.endsWith(r'$')) {
        endAnchored = true;
        text = trimmed.substring(0, trimmed.length - 1).trim();
      }
    }

    stripEndAnchor();

    ModelDate? minDate;
    var requireDate = false;
    final dateFilter = RegExp(
      r'@(snap)?>=(\d{4})-(\d{2})-(\d{2})\s*$',
    ).firstMatch(text);
    if (dateFilter != null) {
      final month = int.parse(dateFilter[3]!);
      final day = int.parse(dateFilter[4]!);
      if (month < 1 || month > 12 || day < 1 || day > 31) {
        throw FormatException('Invalid date bound in pattern "$source"');
      }
      requireDate = dateFilter[1] != null;
      minDate = ModelDate(
        year: int.parse(dateFilter[2]!),
        month: month,
        day: day,
      );
      text = text.substring(0, dateFilter.start).trim();
    }

    stripEndAnchor();

    if (text.isEmpty) {
      throw FormatException('Alternative has no items in pattern "$source"');
    }

    final items = <PatternItem>[
      for (final rawItem in text.split(RegExp(r'\s+')))
        _parseItem(rawItem, source),
    ];
    return PatternAlternative(
      anchored: anchored,
      endAnchored: endAnchored,
      items: List.unmodifiable(items),
      minDate: minDate,
      requireDate: requireDate,
    );
  }

  static PatternItem _parseItem(String rawItem, String source) {
    if (rawItem.startsWith('{') && rawItem.endsWith('}')) {
      final inner = rawItem.substring(1, rawItem.length - 1).trim();
      if (inner.startsWith('v>=')) {
        final version = RegExp(r'^v>=(\d+)(?:\.(\d+))?$').firstMatch(inner);
        if (version == null) {
          throw FormatException('Invalid version item "$rawItem" in "$source"');
        }
        return _VersionAtLeast(
          int.parse(version[1]!),
          version[2] == null ? 0 : int.parse(version[2]!),
        );
      }
      final values = <String>{
        for (final value in inner.split('|'))
          if (value.trim().isNotEmpty) _singleToken(value.trim(), source),
      };
      if (values.isEmpty) {
        throw FormatException('Empty token set "$rawItem" in "$source"');
      }
      return _TokenSet(Set.unmodifiable(values));
    }

    final tokens = ModelTokenizer.splitTokens(rawItem);
    if (tokens.isEmpty) {
      throw FormatException('Invalid literal "$rawItem" in "$source"');
    }
    return _LiteralTokens(tokens);
  }

  static String _singleToken(String value, String source) {
    final tokens = ModelTokenizer.splitTokens(value);
    if (tokens.length != 1) {
      throw FormatException(
        'Token set value "$value" must be a single token in "$source"',
      );
    }
    return tokens.single;
  }

  static List<String> _splitTopLevel(String source) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var depth = 0;
    for (final rune in source.runes) {
      final char = String.fromCharCode(rune);
      if (char == '{') depth++;
      if (char == '}') depth--;
      if (char == '|' && depth == 0) {
        parts.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    parts.add(buffer.toString());
    return parts;
  }
}

bool _isNumeric(String token) {
  if (token.isEmpty) return false;
  for (final unit in token.codeUnits) {
    if (unit < 0x30 || unit > 0x39) return false;
  }
  return true;
}

bool _versionAtLeast(
  int major,
  int minor,
  int thresholdMajor,
  int thresholdMinor,
) {
  if (major != thresholdMajor) return major > thresholdMajor;
  return minor >= thresholdMinor;
}
