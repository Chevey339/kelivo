import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/genui_eval/scoring.dart';

void main() {
  final config =
      jsonDecode(File('tool/genui_eval/config.json').readAsStringSync())
          as Map<String, dynamic>;
  final tasks = {
    for (final raw in (config['tasks'] as List).cast<Map<String, dynamic>>())
      raw['id'] as String: GenUiEvalTask.fromJson(raw),
  };
  const runs = [
    (
      directory: 'final-c25-first',
      report: 'docs/genui/evaluation-final-first.json',
      rejected: {'s4-3', 's4-4', 's4-5'},
    ),
    (
      directory: 'final-c25-second',
      report: 'docs/genui/evaluation-final-second.json',
      rejected: {'s2-2', 's3-1'},
    ),
    (
      directory: 'final-c25',
      report: 'docs/genui/evaluation-final.json',
      rejected: <String>{},
    ),
  ];
  for (final run in runs) {
    final report =
        jsonDecode(File(run.report).readAsStringSync()) as Map<String, dynamic>;
    final fixtures = Directory('test/fixtures/genui/real/${run.directory}')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .map(
          (file) => jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        )
        .toList();
    test('${run.directory} retains all attributed first-round outcomes', () {
      expect(
        report.keys,
        unorderedEquals(['model', 'date', 'testedCommit', 'score']),
      );
      expect(report['model'], 'deepseek-v4.1-flash-1017');
      expect(report['testedCommit'], matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(fixtures, hasLength(30));
      expect(fixtures.map((f) => f['task']), unorderedEquals(tasks.keys));
      var passed = 0;
      for (final fixture in fixtures) {
        for (final key in ['model', 'date', 'testedCommit']) {
          expect(fixture[key], report[key]);
        }
        final review = fixture['semanticReview'] as Map;
        expect(review['reviewer'], isNotEmpty);
        expect(review['notes'], isNotEmpty);
        expect(review['accepted'], !run.rejected.contains(fixture['task']));
        expect(fixture['finishReason'], 'stop');
        if ((fixture['score'] as Map)['deterministicPassed'] == true &&
            review['accepted'] == true) {
          passed++;
        }
      }
      expect(passed, 30 - run.rejected.length);
      expect(
        report['score'],
        '$passed/30 (${(100 * passed / 30).toStringAsFixed(2)}%)',
      );
    });
    for (final fixture in fixtures) {
      final id = fixture['task'] as String;
      test(
        '${run.directory} $id replays its recorded deterministic outcome',
        () {
          expect(
            scoreGenUiOutput(
              tasks[id]!,
              fixture['response'] as String,
            ).toJson(),
            fixture['score'],
          );
        },
      );
    }
  }
}
