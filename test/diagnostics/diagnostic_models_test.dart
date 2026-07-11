import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/diagnostics/diagnostic_models.dart';

void main() {
  group('TokenAggregate.hitRate', () {
    test('returns 0 when no input tokens', () {
      const agg = TokenAggregate(
        inputTokens: 0,
        cachedTokens: 0,
        uncachedTokens: 0,
        completionTokens: 0,
        toolTokens: 0,
        sampledMessageCount: 0,
        assistantMessageCount: 0,
        userMessageCount: 0,
      );
      expect(agg.hitRate, 0);
    });

    test('caches normalised against input', () {
      const agg = TokenAggregate(
        inputTokens: 200,
        cachedTokens: 50,
        uncachedTokens: 150,
        completionTokens: 0,
        toolTokens: 0,
        sampledMessageCount: 1,
        assistantMessageCount: 1,
        userMessageCount: 1,
      );
      expect(agg.hitRate, closeTo(0.25, 1e-9));
    });

    test('uncached is the complement', () {
      const agg = TokenAggregate(
        inputTokens: 100,
        cachedTokens: 30,
        uncachedTokens: 70,
        completionTokens: 0,
        toolTokens: 0,
        sampledMessageCount: 1,
        assistantMessageCount: 1,
        userMessageCount: 1,
      );
      expect(agg.uncachedTokens + agg.cachedTokens, 100);
    });
  });

  group('TokenAggregate.toolRatio', () {
    test('zero when no input', () {
      const agg = TokenAggregate(
        inputTokens: 0,
        cachedTokens: 0,
        uncachedTokens: 0,
        completionTokens: 0,
        toolTokens: 500,
        sampledMessageCount: 1,
        assistantMessageCount: 1,
        userMessageCount: 1,
      );
      expect(agg.toolRatio, 0);
    });

    test('tool / input ratio is correct', () {
      const agg = TokenAggregate(
        inputTokens: 100,
        cachedTokens: 0,
        uncachedTokens: 100,
        completionTokens: 0,
        toolTokens: 70,
        sampledMessageCount: 1,
        assistantMessageCount: 1,
        userMessageCount: 1,
      );
      expect(agg.toolRatio, closeTo(0.7, 1e-9));
    });
  });

  group('DiagnosticFinding', () {
    test('titleSuffix defaults to null', () {
      const f = DiagnosticFinding(
        kind: DiagnosticKind.toolTokenHigh,
        severity: DiagnosticSeverity.risk,
        title: 'k',
        subtitle: [],
        solution: 's',
      );
      expect(f.titleSuffix, isNull);
    });

    test('titleSuffix carries the dynamic payload', () {
      const f = DiagnosticFinding(
        kind: DiagnosticKind.toolTokenHigh,
        severity: DiagnosticSeverity.risk,
        title: 'k',
        subtitle: [],
        solution: 's',
        titleSuffix: ' · foo, bar · 70%',
      );
      expect(f.titleSuffix, ' · foo, bar · 70%');
    });
  });

  group('SubtitleLine', () {
    test('suffix defaults to empty', () {
      const s = SubtitleLine('k');
      expect(s.suffix, isEmpty);
    });

    test('carries both key and suffix', () {
      const s = SubtitleLine('k', suffix: ' (60%)');
      expect(s.key, 'k');
      expect(s.suffix, ' (60%)');
    });
  });
}
