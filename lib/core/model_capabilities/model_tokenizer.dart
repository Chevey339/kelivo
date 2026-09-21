import 'package:flutter/foundation.dart';

/// A calendar date recovered from the trailing snapshot segment of a model id.
///
/// Compact four-digit snapshots (`gpt-4-0613`) carry no year, so [year] is
/// nullable and comparisons against them are treated as non-matching.
@immutable
class ModelDate implements Comparable<ModelDate> {
  const ModelDate({required this.month, required this.day, this.year});

  final int? year;
  final int month;
  final int day;

  bool get hasYear => year != null;

  /// Whether this date is known to fall on or after [threshold].
  ///
  /// Returns `false` whenever either side lacks a year, because a yearless
  /// snapshot cannot be ordered against a full date.
  bool isOnOrAfter(ModelDate threshold) {
    final ownYear = year;
    final thresholdYear = threshold.year;
    if (ownYear == null || thresholdYear == null) return false;
    if (ownYear != thresholdYear) return ownYear > thresholdYear;
    if (month != threshold.month) return month > threshold.month;
    return day >= threshold.day;
  }

  @override
  int compareTo(ModelDate other) {
    final ownYear = year ?? 0;
    final otherYear = other.year ?? 0;
    if (ownYear != otherYear) return ownYear.compareTo(otherYear);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is ModelDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => year == null
      ? '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}'
      : '${year!.toString().padLeft(4, '0')}-'
            '${month.toString().padLeft(2, '0')}-'
            '${day.toString().padLeft(2, '0')}';
}

/// The canonical decomposition of a model id.
///
/// Tokenization is deliberately finest-grained: every separator (`-`, `.`,
/// `_`, `/`, `:`, `@`, `+`, whitespace) and every letter/digit boundary is a
/// token boundary. That makes `qwen3.7-plus`, `qwen-3.7-plus` and
/// `qwen3-7-plus` collapse to the same token stream, so rules never have to
/// spell out separator variants.
@immutable
class TokenizedModelId {
  const TokenizedModelId({
    required this.raw,
    required this.vendor,
    required this.name,
    required this.core,
    required this.tokens,
    this.colonBoundaries = const <int>{},
    this.date,
  });

  /// The original, unmodified input.
  final String raw;

  /// Everything before the last `/`, or `''` when unqualified.
  final String vendor;

  /// The unqualified id (everything after the last `/`).
  final String name;

  /// [name] with any trailing snapshot date removed.
  final String core;

  /// Finest-grained tokens of [core].
  final List<String> tokens;

  /// Token indices that immediately follow a `:` in [core].
  ///
  /// Mirrors the legacy `(?:$|[:])` suffix rule: a rule may treat a
  /// colon-qualified variant (`moonshotai/kimi-for-coding:fast`) as a clean
  /// match while still rejecting dash continuations (`kimi-for-coding-other`).
  final Set<int> colonBoundaries;

  /// The trailing snapshot date, when one was recognized.
  final ModelDate? date;

  bool get hasVendor => vendor.isNotEmpty;

  @override
  String toString() =>
      'TokenizedModelId($tokens${date == null ? '' : ', date: $date'})';
}

/// A raw tokenization fragment: tokens plus colon-boundary indices.
@immutable
class TokenizedFragment {
  const TokenizedFragment({
    required this.tokens,
    required this.colonBoundaries,
  });

  final List<String> tokens;
  final Set<int> colonBoundaries;

  @override
  String toString() => 'TokenizedFragment($tokens)';
}

/// Splits model ids into normalized tokens.
class ModelTokenizer {
  const ModelTokenizer._();

  /// Parses [id] into a [TokenizedModelId].
  static TokenizedModelId tokenizeModelId(String id) {
    final trimmed = id.trim().toLowerCase();
    var vendor = '';
    var name = trimmed;
    final slash = trimmed.lastIndexOf('/');
    if (slash >= 0) {
      vendor = trimmed.substring(0, slash);
      name = trimmed.substring(slash + 1);
    }
    final dateMatch = _parseTrailingDate(name);
    final core = dateMatch == null ? name : name.substring(0, dateMatch.start);
    final fragment = splitFragment(core);
    return TokenizedModelId(
      raw: id,
      vendor: vendor,
      name: name,
      core: core,
      tokens: fragment.tokens,
      colonBoundaries: fragment.colonBoundaries,
      date: dateMatch?.date,
    );
  }

  /// Splits an arbitrary fragment into finest-grained lowercase tokens.
  ///
  /// Non-alphanumeric characters are separators; adjacent letters and digits
  /// are also split. Non-ASCII letters are kept as part of a token so brand
  /// names such as `智谱` survive.
  static List<String> splitTokens(String input) => splitFragment(input).tokens;

  /// Like [splitTokens], but also reports which tokens follow a `:`.
  static TokenizedFragment splitFragment(String input) {
    final lower = input.toLowerCase();
    final out = <String>[];
    final boundaries = <int>{};
    final buffer = StringBuffer();
    bool? bufferIsDigit;
    var colonPending = false;

    void flush() {
      if (buffer.isNotEmpty) {
        if (colonPending) boundaries.add(out.length);
        out.add(buffer.toString());
      }
      buffer.clear();
      bufferIsDigit = null;
      colonPending = false;
    }

    for (final rune in lower.runes) {
      if (!_isAlphanumeric(rune)) {
        final wasColon = rune == 0x3a;
        flush();
        if (wasColon) colonPending = true;
        continue;
      }
      final isDigit = rune >= 0x30 && rune <= 0x39;
      if (bufferIsDigit != null && bufferIsDigit != isDigit) flush();
      buffer.writeCharCode(rune);
      bufferIsDigit = isDigit;
    }
    flush();
    return TokenizedFragment(
      tokens: List<String>.unmodifiable(out),
      colonBoundaries: Set<int>.unmodifiable(boundaries),
    );
  }

  static bool _isAlphanumeric(int rune) {
    if (rune >= 0x30 && rune <= 0x39) return true;
    if (rune >= 0x61 && rune <= 0x7a) return true;
    return rune > 0x7f;
  }

  static _DateMatch? _parseTrailingDate(String name) {
    final dashed = RegExp(
      r'[\-._@:](\d{4})[\-._@:](\d{2})[\-._@:](\d{2})$',
    ).firstMatch(name);
    if (dashed != null) {
      final year = int.parse(dashed[1]!);
      final month = int.parse(dashed[2]!);
      final day = int.parse(dashed[3]!);
      if (_isValidMonthDay(month, day)) {
        return _DateMatch(
          dashed.start,
          ModelDate(year: year, month: month, day: day),
        );
      }
    }

    final compact8 = RegExp(r'[\-._@:](\d{8})$').firstMatch(name);
    if (compact8 != null) {
      final raw = compact8[1]!;
      final year = int.parse(raw.substring(0, 4));
      final month = int.parse(raw.substring(4, 6));
      final day = int.parse(raw.substring(6, 8));
      if (_isValidMonthDay(month, day)) {
        return _DateMatch(
          compact8.start,
          ModelDate(year: year, month: month, day: day),
        );
      }
    }

    final compact6 = RegExp(r'[\-._@:](\d{6})$').firstMatch(name);
    if (compact6 != null) {
      final raw = compact6[1]!;
      final year = 2000 + int.parse(raw.substring(0, 2));
      final month = int.parse(raw.substring(2, 4));
      final day = int.parse(raw.substring(4, 6));
      if (_isValidMonthDay(month, day)) {
        return _DateMatch(
          compact6.start,
          ModelDate(year: year, month: month, day: day),
        );
      }
    }

    final compact4 = RegExp(r'[\-._@:](\d{4})$').firstMatch(name);
    if (compact4 != null) {
      final raw = compact4[1]!;
      final month = int.parse(raw.substring(0, 2));
      final day = int.parse(raw.substring(2, 4));
      if (_isValidMonthDay(month, day)) {
        return _DateMatch(compact4.start, ModelDate(month: month, day: day));
      }
    }

    return null;
  }

  static bool _isValidMonthDay(int month, int day) =>
      month >= 1 && month <= 12 && day >= 1 && day <= 31;
}

@immutable
class _DateMatch {
  const _DateMatch(this.start, this.date);

  final int start;
  final ModelDate date;
}
