// Run from dependencies/markstream with: dart run test/perf/parse_bench.dart
// Diagnostic timings only. Correctness belongs in the core test suite.
import 'dart:convert';
import 'dart:io';

import 'package:markstream/markstream_core.dart';

import '../../../../test/fixtures/markdown/markstream_documents.dart';

Map<String, Object> distribution(List<int> samples) {
  final sorted = [...samples]..sort();
  return {
    'samples': samples.length,
    'medianUs': sorted[sorted.length ~/ 2],
    'p95Us': sorted[(sorted.length * .95).ceil() - 1],
    'rawUs': samples,
  };
}

void report(Map<String, Object> values) {
  // ignore: avoid_print
  print('MARKSTREAM_PARSE ${jsonEncode(values)}');
}

void main() {
  report({
    'measurement': 'metadata',
    'scope': 'core only; excludes Flutter build/layout/paint/raster',
    'dart': Platform.version,
    'os': Platform.operatingSystem,
    'osVersion': Platform.operatingSystemVersion,
    'processors': Platform.numberOfProcessors,
    'rounds': 5,
    'fullParseWarmups': 12,
    'fullParseSamples': 31,
    'appendWarmups': 30,
    'appendSamples': 120,
    'appendToken': ' token',
    'fixtureRevision': 'markstream-C03',
  });
  const parser = MarkdownParser();
  for (var round = 1; round <= 5; round++) {
    for (final source in [markstreamAppendFixture, markstreamColdFixture]) {
      for (var i = 0; i < 12; i++) {
        parser.parse(source);
      }
      final samples = <int>[];
      var blocks = 0;
      for (var i = 0; i < 31; i++) {
        final watch = Stopwatch()..start();
        final document = parser.parse(source);
        watch.stop();
        samples.add(watch.elapsedMicroseconds);
        blocks = document.children.length;
      }
      report({
        'measurement': 'full_parse',
        'round': round,
        'characters': source.length,
        'rootBlocks': blocks,
        ...distribution(samples),
      });
    }
    final stream = IncrementalDocument();
    var source = markstreamAppendFixture;
    stream.update(source, streaming: true);
    final samples = <int>[];
    for (var i = 0; i < 150; i++) {
      source += ' token';
      final watch = Stopwatch()..start();
      stream.update(source, streaming: true);
      watch.stop();
      if (i >= 30) samples.add(watch.elapsedMicroseconds);
    }
    report({
      'measurement': 'incremental_append',
      'round': round,
      'initialCharacters': markstreamAppendFixture.length,
      'finalCharacters': source.length,
      ...distribution(samples),
    });
  }
}
