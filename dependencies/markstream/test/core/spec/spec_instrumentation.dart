import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

List<Map<String, dynamic>> loadSpec(String filename) => (jsonDecode(
  File('test/core/spec/fixtures/$filename').readAsStringSync(),
) as List<dynamic>).cast<Map<String, dynamic>>();

/// Output comparison is a conformance instrument, not a pass-rate gate.
/// Crashes and invalid source ranges remain correctness failures.
void instrumentSpec(
  String name,
  List<Map<String, dynamic>> cases,
  ParserOptions options,
) {
  expect(cases.map((c) => c['example']).toSet(), hasLength(cases.length));
  final parser = MarkdownParser(options: options);
  final failures = <Map<String, Object?>>[];
  final sections = <String, Map<String, int>>{};
  for (final example in cases) {
    final source = example['markdown'] as String;
    final expected = example['html'] as String;
    final section = example['section'] as String;
    final doc = parser.parse(source);
    final pending = <MarkdownNode>[doc];
    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      expect(
        node.span.start,
        greaterThanOrEqualTo(0),
        reason: '$name ${example['example']}',
      );
      expect(
        node.span.end,
        lessThanOrEqualTo(source.length),
        reason: '$name ${example['example']}',
      );
      for (final child in node.children) {
        expect(
          child.span.start,
          greaterThanOrEqualTo(node.span.start),
          reason: '$name ${example['example']}',
        );
        expect(
          child.span.end,
          lessThanOrEqualTo(node.span.end),
          reason: '$name ${example['example']}',
        );
        pending.add(child);
      }
    }
    final actual = toHtml(doc);
    final counts = sections.putIfAbsent(
      section,
      () => {'total': 0, 'matched': 0},
    );
    counts['total'] = counts['total']! + 1;
    if (actual == expected) {
      counts['matched'] = counts['matched']! + 1;
    } else {
      failures.add({
        'example': example['example'],
        'section': section,
        'markdown': source,
        'expected': expected,
        'actual': actual,
      });
    }
  }
  final total = cases.length;
  final matched = total - failures.length;
  final report = File('build/reports/$name.json');
  report.parent.createSync(recursive: true);
  report.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'suite': name,
      'total': total,
      'matched': matched,
      'percent': matched * 100 / total,
      'failedIds': failures.map((f) => f['example']).toList(),
      'sections': sections,
      'differences': failures,
    }),
  );
  // Permanent diagnostic output for CI and local conformance tracking.
  stdout.writeln(
    '$name: $matched/$total (${(matched * 100 / total).toStringAsFixed(1)}%); differences: ${failures.map((f) => f['example']).join(',')}; report: ${report.path}',
  );
}
