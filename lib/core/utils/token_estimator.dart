/// Heuristic token estimator ported from tokenx
/// (https://github.com/johannschopplich/tokenx, MIT).
///
/// LobeHub calls the same algorithm as `estimateTokenCount`. Segmentation,
/// short-lowercase-word handling, digit grouping, CJK/kana/hangul weights,
/// other-language ratios, and structural whitespace match that source. Pure
/// Dart so [estimateTokens] can run inside `Isolate.run`.
library;

import 'dart:convert';
import 'dart:math' as math;

import '../providers/settings_provider.dart' show ProviderKind;

/// Extra tokens charged per tool beyond [jsonEncode] of the tools list.
/// Covers provider envelope fields (`type` / `function` wrappers) that the
/// serialized maps often omit or under-count.
const int kToolDefinitionOverheadTokens = 8;

const int _unknownImageTokens = 1000;

/// JS `\s` (no `/u` flag): ASCII whitespace plus the Unicode separators
/// ECMA-262 includes in `\s`.
const String _jsWhitespaceClass =
    r'[ \f\n\r\t\v\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF]';

const String _punctuationClass = r'[.,!?;(){}[\]<>:/\\|@#$%^&*+=`~_"-]';

final RegExp _tokenSplitPattern = RegExp(
  '($_jsWhitespaceClass+|$_punctuationClass+)',
);
final RegExp _whitespaceOnly = RegExp('^$_jsWhitespaceClass+\$');
final RegExp _structuredWhitespace = RegExp('\\n$_jsWhitespaceClass');
final RegExp _punctuationChar = RegExp(_punctuationClass);
final RegExp _nonAscii = RegExp(r'[\u0080-\uFFFF]');
final RegExp _cjk = RegExp(
  r'[\u4E00-\u9FFF\u3400-\u4DBF\u3000-\u30FF\uFF00-\uFFEF'
  r'\u2E80-\u2EFF\u31C0-\u31EF\u3200-\u32FF\u3300-\u33FF'
  r'\uAC00-\uD7AF\u1100-\u11FF\u3130-\u318F\uA960-\uA97F\uD7B0-\uD7FF]',
);
final RegExp _numeric = RegExp(r'^\d+$');
final RegExp _lowercaseWord = RegExp(r'^[a-z]+$');

const int _defaultCharsPerToken = 7;
const int _shortTokenThreshold = 3;
const int _lowercaseWordSingleTokenLength = 8;
const int _punctuationCharsPerToken = 6;
const double _kanaCharsPerToken = 1.4;
const double _hangulCharsPerToken = 1.65;
const double _hanziCharsPerToken = 1.15;

class _LanguageConfig {
  const _LanguageConfig(this.pattern, this.averageCharsPerToken);

  final RegExp pattern;
  final double averageCharsPerToken;
}

final List<_LanguageConfig> _languageConfigs = [
  _LanguageConfig(RegExp(r'[äöüßẞ]', caseSensitive: false), 3),
  _LanguageConfig(
    RegExp(r'[éèêëàâîïôûùüÿçœæáíóúñ]', caseSensitive: false),
    4.5,
  ),
  _LanguageConfig(RegExp(r'[ąćęłńóśźżěščřžýůúďťň]', caseSensitive: false), 2.5),
  _LanguageConfig(RegExp(r'[\u0430-\u044F\u0451]', caseSensitive: false), 6),
  _LanguageConfig(RegExp(r'[\u03AC-\u03CE]', caseSensitive: false), 3),
  _LanguageConfig(
    RegExp(
      r'^\p{Extended_Pictographic}[\p{Extended_Pictographic}\p{Emoji_Component}]*$',
      unicode: true,
    ),
    0.9,
  ),
];

int estimateTokens(String text) {
  if (text.isEmpty) return 0;

  var tokenCount = 0;
  var previousSegment = '';
  for (final segment in _splitKeepingDelimiters(text)) {
    tokenCount += _estimateSegmentTokens(segment, previousSegment);
    previousSegment = segment;
  }
  return tokenCount;
}

/// JS `String.split` with a capturing regex keeps the separators. Dart's
/// `split` drops them, so we replay `allMatches` and emit both sides.
Iterable<String> _splitKeepingDelimiters(String text) sync* {
  var start = 0;
  for (final match in _tokenSplitPattern.allMatches(text)) {
    if (match.start > start) {
      yield text.substring(start, match.start);
    }
    if (match.end > match.start) {
      yield match.group(0)!;
    }
    start = match.end;
  }
  if (start < text.length) {
    yield text.substring(start);
  }
}

int estimateImageTokens(ProviderKind kind, {int? width, int? height}) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return _unknownImageTokens;
  }
  return switch (kind) {
    // OpenAI high-detail: fit 2048×2048, shortest side → 768, 170/512px tile + 85.
    // https://platform.openai.com/docs/guides/images-vision
    ProviderKind.openai => _openaiHighDetailImageTokens(width, height),
    // Claude: (w×h)/750 after long-edge ≤ 1568, cap ~1600 visual tokens.
    // https://docs.anthropic.com/en/docs/build-with-claude/vision
    ProviderKind.claude => _claudeImageTokens(width, height),
    // Gemini: 258 if both sides ≤ 384px; else 258 per 768×768 tile after crop.
    // https://ai.google.dev/gemini-api/docs/image-understanding
    ProviderKind.google => _geminiImageTokens(width, height),
  };
}

int estimateToolsTokens(List<Map<String, dynamic>> tools) {
  if (tools.isEmpty) return 0;
  return estimateTokens(jsonEncode(tools)) +
      tools.length * kToolDefinitionOverheadTokens;
}

int _estimateSegmentTokens(String segment, String previousSegment) {
  if (_whitespaceOnly.hasMatch(segment)) {
    if (_structuredWhitespace.hasMatch(segment)) return 1;
    final last = previousSegment.isEmpty
        ? ''
        : previousSegment[previousSegment.length - 1];
    return segment.contains('\n') && !_punctuationChar.hasMatch(last) ? 1 : 0;
  }

  final languageCharsPerToken = _languageCharsPerToken(segment);
  if (languageCharsPerToken != null) {
    return (segment.runes.length / languageCharsPerToken).ceil();
  }

  if (_cjk.hasMatch(segment)) {
    return _estimateCjkTokens(segment);
  }

  if (_numeric.hasMatch(segment)) {
    return (segment.length / 3).ceil();
  }

  if (segment.length <= _shortTokenThreshold) {
    return 1;
  }

  if (segment.length <= _lowercaseWordSingleTokenLength &&
      _lowercaseWord.hasMatch(segment)) {
    return 1;
  }

  if (_punctuationChar.hasMatch(segment)) {
    return (segment.length / _punctuationCharsPerToken).ceil();
  }

  return (segment.length / _defaultCharsPerToken).ceil();
}

double? _languageCharsPerToken(String segment) {
  // JS `[\u0080-\uFFFF]` matches BMP non-ASCII *and* surrogate code units, so
  // supplementary-plane emoji still enter this loop. Dart `runes` above 0xFFFF
  // must be treated the same; the BMP regex alone would skip them.
  if (!_nonAscii.hasMatch(segment) && !segment.runes.any((r) => r > 0xFFFF)) {
    return null;
  }
  for (final config in _languageConfigs) {
    if (config.pattern.hasMatch(segment)) {
      return config.averageCharsPerToken;
    }
  }
  return null;
}

int _estimateCjkTokens(String segment) {
  var kanaCount = 0;
  var hangulCount = 0;
  var hanziCount = 0;
  for (final codePoint in segment.runes) {
    if (codePoint >= 0x3040 && codePoint <= 0x30FF) {
      kanaCount++;
    } else if (_isHangulCodePoint(codePoint)) {
      hangulCount++;
    } else {
      hanziCount++;
    }
  }
  return (hanziCount / _hanziCharsPerToken +
          kanaCount / _kanaCharsPerToken +
          hangulCount / _hangulCharsPerToken)
      .ceil();
}

bool _isHangulCodePoint(int codePoint) {
  return (codePoint >= 0xAC00 && codePoint <= 0xD7AF) ||
      (codePoint >= 0x1100 && codePoint <= 0x11FF) ||
      (codePoint >= 0x3130 && codePoint <= 0x318F) ||
      (codePoint >= 0xA960 && codePoint <= 0xA97F) ||
      (codePoint >= 0xD7B0 && codePoint <= 0xD7FF);
}

int _openaiHighDetailImageTokens(int width, int height) {
  var w = width;
  var h = height;
  final longSide = math.max(w, h);
  if (longSide > 2048) {
    final scale = 2048 / longSide;
    w = (w * scale).round();
    h = (h * scale).round();
  }
  final shortSide = math.min(w, h);
  if (shortSide > 768) {
    final scale = 768 / shortSide;
    w = (w * scale).round();
    h = (h * scale).round();
  }
  final tiles = (w / 512).ceil() * (h / 512).ceil();
  return 170 * tiles + 85;
}

int _claudeImageTokens(int width, int height) {
  var w = width;
  var h = height;
  final longSide = math.max(w, h);
  if (longSide > 1568) {
    final scale = 1568 / longSide;
    w = (w * scale).round();
    h = (h * scale).round();
  }
  final tokens = ((w * h) / 750).round();
  return tokens > 1600 ? 1600 : tokens;
}

int _geminiImageTokens(int width, int height) {
  if (width <= 384 && height <= 384) return 258;
  var crop = (math.min(width, height) / 1.5).floor();
  if (crop < 256) crop = 256;
  if (crop > 768) crop = 768;
  final tiles = (width / crop).ceil() * (height / crop).ceil();
  return tiles * 258;
}
