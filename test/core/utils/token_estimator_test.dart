import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart' show ProviderKind;
import 'package:Kelivo/core/utils/token_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estimateTokens', () {
    test('empty string is 0 tokens', () {
      expect(estimateTokens(''), 0);
    });

    test('table-driven tokenx samples', () {
      const cases = <(String, int)>[
        ('123', 1),
        ('1234567890', 4),
        ('hello', 1),
        ('Hello', 1),
        ('Hello world', 2),
        ('The quick brown fox jumps over the lazy dog.', 10),
        ('Hello\n  world', 3),
        ('Hello\n\nworld', 3),
        ('Hello\nworld', 3),
        ('Hello,\nworld', 3),
        ('こんにちはみなさん', 7),
        ('人工智能技术发展迅速', 9),
        ('안녕하세요반갑습니다', 7),
        ('你好', 2),
        ('你好hello', 7),
        ('你好世界', 4),
        ('function add(a, b) {\n  return a + b;\n}', 15),
        ('{"name":"kelivo","count":12}', 9),
        ('Café über uns', 4),
        ('Привет мир', 2),
        ('🏀🔥', 3),
        ('Gutenberg™', 2),
        ('https://example.com/path/to/resource', 11),
        ('User: hello\n\nAssistant: hi', 8),
      ];
      for (final (text, tokens) in cases) {
        expect(estimateTokens(text), tokens, reason: text);
      }
    });

    test('digit grouping and long ASCII runs', () {
      expect(estimateTokens('a' * 1000), 143);
      expect(estimateTokens('中' * 400), 348);
      expect(estimateTokens('${'中' * 200}${'a' * 400}'), 522);
    });
  });

  group('estimateImageTokens', () {
    test('unknown or non-positive dimensions are 1000', () {
      for (final kind in ProviderKind.values) {
        expect(estimateImageTokens(kind), 1000);
        expect(estimateImageTokens(kind, width: 1024), 1000);
        expect(estimateImageTokens(kind, height: 1024), 1000);
        expect(estimateImageTokens(kind, width: 0, height: 1024), 1000);
        expect(estimateImageTokens(kind, width: 1024, height: -1), 1000);
      }
    });

    test('OpenAI high-detail tiles', () {
      expect(
        estimateImageTokens(ProviderKind.openai, width: 1024, height: 1024),
        765,
      );
      expect(
        estimateImageTokens(ProviderKind.openai, width: 2048, height: 4096),
        1105,
      );
      expect(
        estimateImageTokens(ProviderKind.openai, width: 512, height: 512),
        255,
      );
    });

    test('Claude area / 750 with 1568 long-edge and 1600 cap', () {
      expect(
        estimateImageTokens(ProviderKind.claude, width: 1000, height: 1000),
        1333,
      );
      expect(
        estimateImageTokens(ProviderKind.claude, width: 2000, height: 2000),
        1600,
      );
    });

    test('Gemini 258-token tiles', () {
      expect(
        estimateImageTokens(ProviderKind.google, width: 300, height: 300),
        258,
      );
      expect(
        estimateImageTokens(ProviderKind.google, width: 384, height: 384),
        258,
      );
      expect(
        estimateImageTokens(ProviderKind.google, width: 960, height: 540),
        1548,
      );
    });
  });

  group('estimateToolsTokens', () {
    const tool = <String, dynamic>{
      'type': 'function',
      'function': {
        'name': 'search',
        'description': 'Search the web',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'},
          },
        },
      },
    };

    test('empty list is 0', () {
      expect(estimateToolsTokens(const []), 0);
    });

    test('grows with tool count and adds per-tool overhead', () {
      final one = estimateToolsTokens([tool]);
      final two = estimateToolsTokens([
        tool,
        {...tool},
      ]);
      expect(one, greaterThan(0));
      expect(two, greaterThan(one));
      expect(
        one,
        estimateTokens(jsonEncode([tool])) + kToolDefinitionOverheadTokens,
      );
      expect(
        two,
        estimateTokens(
              jsonEncode([
                tool,
                {...tool},
              ]),
            ) +
            2 * kToolDefinitionOverheadTokens,
      );
    });
  });

  test('cross-checks samples against the tokenx JS reference', () async {
    final samples = <String>[
      'The quick brown fox jumps over the lazy dog.',
      'function add(a, b) {\n  return a + b;\n}',
      '{"name":"kelivo","count":12}',
      '人工智能技术发展迅速',
      'こんにちはみなさん',
    ];

    late ProcessResult probe;
    try {
      probe = await Process.run('node', ['-e', 'process.stdout.write("ok")']);
    } on ProcessException {
      markTestSkipped('node is not available');
      return;
    }
    if (probe.exitCode != 0 || probe.stdout != 'ok') {
      markTestSkipped('node is not available');
      return;
    }

    final script = File(
      '${Directory.systemTemp.path}/kelivo_tokenx_crosscheck.js',
    );
    await script.writeAsString(_tokenxJsReference);
    final result = await Process.run('node', [
      script.path,
      jsonEncode(samples),
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    final jsCounts = (jsonDecode(result.stdout as String) as List<dynamic>)
        .cast<int>();
    expect(jsCounts, hasLength(samples.length));
    for (var i = 0; i < samples.length; i++) {
      expect(
        estimateTokens(samples[i]),
        jsCounts[i],
        reason: 'JS mismatch for ${jsonEncode(samples[i])}',
      );
    }
  });
}

/// Compact copy of johannschopplich/tokenx `estimateTokenCount` (MIT).
const String _tokenxJsReference = r'''
const PATTERNS = {
  whitespace: /^\s+$/,
  structuredWhitespace: /\n\s/,
  nonAscii: /[\u0080-\uFFFF]/,
  cjk: /[\u4E00-\u9FFF\u3400-\u4DBF\u3000-\u30FF\uFF00-\uFFEF\u2E80-\u2EFF\u31C0-\u31EF\u3200-\u32FF\u3300-\u33FF\uAC00-\uD7AF\u1100-\u11FF\u3130-\u318F\uA960-\uA97F\uD7B0-\uD7FF]/,
  numeric: /^\d+$/,
  punctuation: /[.,!?;(){}[\]<>:/\\|@#$%^&*+=`~_"-]/,
  lowercaseWord: /^[a-z]+$/,
}
const TOKEN_SPLIT_PATTERN = new RegExp(`(\\s+|${PATTERNS.punctuation.source}+)`)
const DEFAULT_LANGUAGE_CONFIGS = [
  { pattern: /[äöüßẞ]/i, averageCharsPerToken: 3 },
  { pattern: /[éèêëàâîïôûùüÿçœæáíóúñ]/i, averageCharsPerToken: 4.5 },
  { pattern: /[ąćęłńóśźżěščřžýůúďťň]/i, averageCharsPerToken: 2.5 },
  { pattern: /[\u0430-\u044F\u0451]/i, averageCharsPerToken: 6 },
  { pattern: /[\u03AC-\u03CE]/i, averageCharsPerToken: 3 },
  { pattern: /^\p{Extended_Pictographic}[\p{Extended_Pictographic}\p{Emoji_Component}]*$/u, averageCharsPerToken: 0.9 },
]
function estimateTokenCount(text) {
  if (!text) return 0
  let tokenCount = 0
  let previousSegment = ""
  for (const segment of text.split(TOKEN_SPLIT_PATTERN)) {
    if (segment) {
      tokenCount += estimateSegmentTokens(segment, previousSegment)
      previousSegment = segment
    }
  }
  return tokenCount
}
function estimateSegmentTokens(segment, previousSegment) {
  if (PATTERNS.whitespace.test(segment)) {
    if (PATTERNS.structuredWhitespace.test(segment)) return 1
    return segment.includes("\n") && !PATTERNS.punctuation.test(previousSegment.slice(-1)) ? 1 : 0
  }
  if (!PATTERNS.nonAscii.test(segment)) {
    return finishAscii(segment)
  }
  for (const config of DEFAULT_LANGUAGE_CONFIGS) {
    if (segment.search(config.pattern) !== -1) {
      return Math.ceil(Array.from(segment).length / config.averageCharsPerToken)
    }
  }
  if (PATTERNS.cjk.test(segment)) return estimateCjkTokens(segment)
  return finishAscii(segment)
}
function finishAscii(segment) {
  if (PATTERNS.numeric.test(segment)) return Math.ceil(segment.length / 3)
  if (segment.length <= 3) return 1
  if (segment.length <= 8 && PATTERNS.lowercaseWord.test(segment)) return 1
  if (PATTERNS.punctuation.test(segment)) return Math.ceil(segment.length / 6)
  return Math.ceil(segment.length / 7)
}
function estimateCjkTokens(segment) {
  let kanaCount = 0, hangulCount = 0, hanziCount = 0
  for (const character of segment) {
    const codePoint = character.codePointAt(0)
    if (codePoint >= 0x3040 && codePoint <= 0x30FF) kanaCount++
    else if ((codePoint >= 0xAC00 && codePoint <= 0xD7AF) || (codePoint >= 0x1100 && codePoint <= 0x11FF) || (codePoint >= 0x3130 && codePoint <= 0x318F) || (codePoint >= 0xA960 && codePoint <= 0xA97F) || (codePoint >= 0xD7B0 && codePoint <= 0xD7FF)) hangulCount++
    else hanziCount++
  }
  return Math.ceil(hanziCount / 1.15 + kanaCount / 1.4 + hangulCount / 1.65)
}
const samples = JSON.parse(process.argv[2])
process.stdout.write(JSON.stringify(samples.map(estimateTokenCount)))
''';
