import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../../tool/genui_eval/prompt.dart';
import '../../../tool/genui_eval/run_output.dart';
import '../../../tool/genui_eval/scoring.dart';

void main() {
  final config =
      jsonDecode(File('tool/genui_eval/config.json').readAsStringSync())
          as Map<String, dynamic>;
  final tasks = {
    for (final task in (config['tasks'] as List).cast<Map<String, dynamic>>())
      task['id'] as String: GenUiEvalTask.fromJson(task),
  };
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/genui/synthetic/eval_outputs.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final outputs = (fixture['outputs'] as Map<String, dynamic>)
      .cast<String, String>();

  test('only one concurrent run can claim an empty output directory', () async {
    final directory = await Directory.systemTemp.createTemp(
      'genui-eval-claim-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final results = await Future.wait(
      List.generate(8, (_) async {
        try {
          await claimEvaluationOutput(directory);
          return true;
        } on FileSystemException {
          return false;
        }
      }),
    );
    expect(results.where((success) => success), hasLength(1));
    expect(
      await File('${directory.path}/.first-round-claimed').exists(),
      isTrue,
    );
    await expectLater(
      claimEvaluationOutput(directory),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('the configured model, 30 tasks and three early scenes are frozen', () {
    expect(config['model'], 'deepseek-v4.1-flash-1017');
    expect(tasks, hasLength(30));
    for (var scene = 1; scene <= 6; scene++) {
      expect(
        tasks.values.where((task) => task.scene == 'S$scene'),
        hasLength(5),
      );
    }
    expect(
      tasks.values.where((task) => task.early).map((task) => task.id).toSet(),
      {'s1-1', 's2-1', 's5-1'},
    );
    expect(fixture['sourceKind'], 'synthetic');
    expect(genUiEvaluationPrompt(), contains('ui 1 catalog "kelivo.native/1"'));
    expect(
      genUiEvaluationPrompt(),
      contains('Each declaration occupies one physical line'),
    );
  });

  for (final entry in outputs.entries) {
    test(
      '${entry.key}: independently defined numerical and interaction expectations pass',
      () {
        final score = scoreGenUiOutput(tasks[entry.key]!, entry.value);
        expect(score.failures, isEmpty);
        expect(score.deterministicPassed, isTrue);
        expect(score.source, startsWith('ui 1'));
        // A deterministic pass does not imply a separate semantic review.
        expect(score.toJson().containsKey('semanticReview'), isFalse);
      },
    );
  }

  test('wrong formula, units and noninteractive hardcoded results fail', () {
    final good = outputs['s1-1']!;
    for (final invalid in [
      good.replaceFirst(r'$a * $b + $c', r'$a + $b + $c'),
      good.replaceFirst(
        'value=distance, unit="km"',
        'value=distance, unit="m"',
      ),
      good.replaceFirst('value=distance', 'value=65'),
      good.replaceFirst('max=100', 'max=35'),
    ]) {
      expect(
        scoreGenUiOutput(tasks['s1-1']!, invalid).deterministicPassed,
        isFalse,
      );
    }
  });

  test(
    'quoted, open and multiple fences cannot pass as a trusted native task',
    () {
      final good = outputs['s1-1']!;
      for (final invalid in [
        good.split('\n').map((line) => '> $line').join('\n'),
        good.substring(0, good.length - 3),
        '$good\n\n$good',
        '$good\n\n```kelivo-web\nhtml\n```',
      ]) {
        expect(
          scoreGenUiOutput(tasks['s1-1']!, invalid).deterministicPassed,
          isFalse,
        );
      }
    },
  );

  test(
    'syntax and unsupported capabilities are failures with bounded diagnostics',
    () {
      final good = outputs['s1-1']!;
      expect(
        scoreGenUiOutput(
          tasks['s1-1']!,
          good.replaceFirst('Slider(', 'Unknown('),
        ).deterministicPassed,
        isFalse,
      );
      expect(
        scoreGenUiOutput(tasks['s1-1']!, 'a' * (1024 * 1024 + 1)).failures,
        ['response_byte_budget'],
      );
    },
  );

  test('lossy curve gaps, field mappings and divergent table data fail', () {
    final good = outputs['s2-2']!;
    expect(
      scoreGenUiOutput(
        tasks['s2-2']!,
        good.replaceFirst('@sqrt(x - \$a)', '@sqrt(@abs(x - \$a))'),
      ).deterministicPassed,
      isFalse,
    );
    expect(
      scoreGenUiOutput(
        tasks['s2-2']!,
        good.replaceFirst('y=["y"]', 'y=["missing"]'),
      ).deterministicPassed,
      isFalse,
    );
    expect(
      scoreGenUiOutput(
        tasks['s2-2']!,
        good.replaceFirst('DataTable(data=points', 'DataTable(data=[]'),
      ).deterministicPassed,
      isFalse,
    );
  });

  test(
    'a conditional field must follow input while keeping its prior value',
    () {
      final good = outputs['s5-1']!;
      expect(
        scoreGenUiOutput(
          tasks['s5-1']!,
          good.replaceFirst(r'visible=$on', 'visible=true'),
        ).deterministicPassed,
        isFalse,
      );
      expect(
        scoreGenUiOutput(
          tasks['s5-1']!,
          good.replaceFirst(r'"detail":$detail', '"detail":""'),
        ).deterministicPassed,
        isFalse,
      );
    },
  );

  test(
    'extra context, misplaced form fields and disabled or hidden UI fail',
    () {
      final form = outputs['s5-1']!;
      expect(
        scoreGenUiOutput(
          tasks['s5-1']!,
          form.replaceFirst(
            r'"detail":$detail',
            r'"detail":$detail,"unexpected":123',
          ),
        ).deterministicPassed,
        isFalse,
      );
      final outside = form
          .replaceFirst(
            'children=[form,ask]',
            'children=[form,ask,toggle,nameField,detailField]',
          )
          .replaceFirst(
            'Form(children=[toggle,nameField,detailField])',
            'Form(children=[])',
          );
      expect(
        scoreGenUiOutput(tasks['s5-1']!, outside).failures,
        contains(contains('outside_form')),
      );
      final calculator = outputs['s1-1']!;
      expect(
        scoreGenUiOutput(
          tasks['s1-1']!,
          calculator.replaceFirst(
            'aInput = Slider(',
            'aInput = Slider(enabled=false, ',
          ),
        ).failures,
        contains(contains('not_enabled')),
      );
      expect(
        scoreGenUiOutput(
          tasks['s1-1']!,
          calculator.replaceFirst(
            'root = Column(',
            'root = Column(visible=false, ',
          ),
        ).failures,
        contains(contains('root_hidden')),
      );
    },
  );

  test('duplicate table identities and invalid pie values are rejected', () {
    final table = outputs['s4-1']!;
    expect(
      scoreGenUiOutput(
        tasks['s4-1']!,
        table.replaceFirst('"id": "p02"', '"id": "p01"'),
      ).failures,
      contains(contains('row_key')),
    );
    final pie = outputs['s3-5']!;
    expect(
      scoreGenUiOutput(
        tasks['s3-5']!,
        pie.replaceFirst('"share": 30', '"share": -30'),
      ).failures,
      contains(contains('pie_value')),
    );
  });

  test(
    'many aliased invalid tables stop collecting diagnostics at the budget',
    () {
      final ids = List.generate(255, (i) => 't$i');
      final columns = jsonEncode(
        List.generate(8, (i) => {'key': 'c$i', 'label': 'C$i'}),
      );
      final source = StringBuffer(
        '```kelivo-ui\nui 1 catalog "kelivo.native/1"\n',
      );
      source.writeln('root = Column(children=[${ids.join(',')}])');
      source.writeln(
        'let rows = ${jsonEncode(List.filled(1000, <String, Object?>{}))}',
      );
      for (final id in ids) {
        source.writeln(
          '$id = DataTable(data=rows, rowKey="id", columns=$columns)',
        );
      }
      source.write('```');
      final score = scoreGenUiOutput(tasks['s4-1']!, source.toString());
      expect(score.deterministicPassed, isFalse);
      expect(score.failures, hasLength(100));
      expect(score.failures, contains(contains('row_key')));
    },
  );
}
