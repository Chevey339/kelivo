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
      raw['id']: GenUiEvalTask.fromJson(raw),
  };
  for (final id in ['s1-1', 's2-1', 's5-1']) {
    test(
      'real DeepSeek early response $id retains its first-round outcome',
      () {
        final fixture =
            jsonDecode(
                  File(
                    'test/fixtures/genui/real/early-c06/$id.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(fixture['model'], 'deepseek-v4.1-flash-1017');
        expect(
          fixture['testedCommit'],
          '66148048a16bf3cce98c9a4d66ebe24065296da0',
        );
        expect(fixture['finishReason'], 'stop');
        final score = scoreGenUiOutput(
          tasks[id]!,
          fixture['response'] as String,
        );
        expect(score.toJson(), fixture['score']);
        expect(score.deterministicPassed, id == 's1-1');
        expect((fixture['semanticReview'] as Map)['reviewer'], 'coding-agent');
        if (id != 's1-1') {
          // Preserve bare/unlabeled code as a failure; do not repair it into a
          // trusted UI in replay or accidentally treat it as a model success.
          expect(score.failures, ['one_closed_top_level_ui_block_required']);
        }
      },
    );
  }
}
