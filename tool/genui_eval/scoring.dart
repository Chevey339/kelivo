import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:markstream/markstream_core.dart';

final class GenUiEvalTask {
  GenUiEvalTask.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      scene = json['scene'] as String,
      prompt = json['prompt'] as String,
      early = json['early'] == true,
      probes = List.unmodifiable(
        (json['probes'] as List).cast<Map<String, dynamic>>(),
      ),
      manualChecks = List.unmodifiable(
        (json['manualChecks'] as List).cast<String>(),
      ) {
    if (!RegExp(r'^s[1-6]-[1-5]$').hasMatch(id) ||
        scene != id.substring(0, 2).toUpperCase() ||
        prompt.isEmpty ||
        probes.isEmpty ||
        manualChecks.isEmpty) {
      throw const FormatException('Invalid evaluation task');
    }
  }
  final String id;
  final String scene;
  final String prompt;
  final bool early;
  final List<Map<String, dynamic>> probes;
  final List<String> manualChecks;
}

final class GenUiEvalScore {
  GenUiEvalScore(this.source, Iterable<String> failures)
    : failures = List.unmodifiable(failures);
  final String? source;
  final List<String> failures;
  bool get deterministicPassed => failures.isEmpty;
  Map<String, Object?> toJson() => {
    'deterministicPassed': deterministicPassed,
    'failures': failures,
  };
}

final class _Failures extends IterableBase<String> {
  final _items = <String>[];
  bool get full => _items.length >= 100;
  void add(String value) {
    if (!full) _items.add(value);
  }

  void addAll(Iterable<String> values) {
    for (final value in values) {
      if (full) break;
      add(value);
    }
  }

  @override
  Iterator<String> get iterator => _items.iterator;
}

/// Scores the fixed synthetic tasks without network, Flutter or application
/// accounts. Attributed semantic review remains separate and required for a pass.
GenUiEvalScore scoreGenUiOutput(GenUiEvalTask task, String response) {
  final failures = _Failures();
  if (response.length > 1024 * 1024 ||
      utf8.encode(response).length > 1024 * 1024) {
    return GenUiEvalScore(null, ['response_byte_budget']);
  }
  final document = const MarkdownParser().parse(response);
  final blocks = document.children
      .whereType<CodeBlockNode>()
      .where((node) => node.info.trim() == 'kelivo-ui')
      .toList();
  if (blocks.length != 1 || !blocks.single.closed) {
    return GenUiEvalScore(null, ['one_closed_top_level_ui_block_required']);
  }
  if (document.children.whereType<CodeBlockNode>().any(
    (node) => node.info.trim() == 'kelivo-web',
  )) {
    failures.add('native_task_must_not_use_web');
  }
  final block = blocks.single;
  final source = block.children
      .where((node) => node.span.start != node.span.end)
      .map((node) => node.text)
      .join();
  final controller = UiSurfaceController(
    owner: UiSurfaceOwner(revisionId: 'evaluation', surfaceKey: task.id),
  );
  controller.updateSource(
    source,
    closed: true,
    generation: UiGenerationStatus.complete,
  );
  try {
    if (controller.parsed.invalid ||
        controller.parsed.program.diagnostics.isNotEmpty) {
      failures.addAll(
        controller.parsed.program.diagnostics
            .take(20)
            .map((d) => 'line_${d.line}:${d.code.name}'),
      );
      if (failures.isEmpty) failures.add('invalid_surface');
      return GenUiEvalScore(source, failures);
    }
    for (final (index, probe) in task.probes.indexed) {
      if (failures.full) break;
      final inputs = (probe['inputs'] as Map<String, dynamic>?) ?? const {};
      final result = controller.setInputs(inputs, token: controller.token);
      if (result != UiMutationResult.accepted &&
          result != UiMutationResult.unchanged) {
        failures.add('probe_$index:input_${result.name}');
        continue;
      }
      final read = controller.captureRead();
      _checkInteractions(
        probe['expect'] as Map<String, dynamic>,
        controller,
        read,
        failures,
        'probe_$index',
      );
      for (final entry in read.values.entries) {
        if (!entry.value.valid) {
          failures.add(
            'probe_$index:value_${entry.key}:${entry.value.error!.code.name}',
          );
        }
      }
      for (final node in read.nodes.values) {
        if (failures.full) break;
        if (!node.valid) {
          failures.add('probe_$index:node_${node.declaration.name}_invalid');
        }
        _checkData(
          node.declaration.component,
          node.properties,
          failures,
          'probe_$index:${node.declaration.name}',
        );
        _checkInputRange(
          node.declaration.component,
          node.properties,
          failures,
          'probe_$index:${node.declaration.name}',
        );
      }
      final projection = <String, Object?>{
        'inputs': read.inputs,
        'values': read.values.map((key, value) => MapEntry(key, value.value)),
        'nodes': {
          for (final entry in read.nodes.entries)
            entry.key: {
              'component': entry.value.declaration.component,
              'props': entry.value.properties,
              'visible': entry.value.visible,
              'enabled': entry.value.enabled,
              'askText': entry.value.askText,
              'askContext': entry.value.askContext,
              'binding': switch (entry.value.declaration.arguments['bind']) {
                UiInputBinding(:final name) => name,
                _ => null,
              },
              'action': switch (entry.value.declaration.arguments['action']) {
                UiAsk() => 'Ask',
                UiReset() => 'Reset',
                _ => null,
              },
            },
        },
      };
      _compare(probe['expect'], projection, 'probe_$index', failures);
      for (final pair in (probe['same'] as List?) ?? const []) {
        final a = _lookup(projection, (pair[0] as List).cast<String>());
        final b = _lookup(projection, (pair[1] as List).cast<String>());
        if (!a.found || !b.found) {
          failures.add('probe_$index:same_path_missing');
        } else {
          _compare(
            a.value,
            b.value,
            'probe_$index:same',
            failures,
            exactMaps: true,
          );
        }
      }
    }
  } finally {
    controller.dispose();
  }
  return GenUiEvalScore(source, failures);
}

({bool found, Object? value}) _lookup(Object? value, List<String> path) {
  for (final part in path) {
    if (value is! Map || !value.containsKey(part)) {
      return (found: false, value: null);
    }
    value = value[part];
  }
  return (found: true, value: value);
}

void _compare(
  Object? expected,
  Object? actual,
  String path,
  _Failures failures, {
  bool exactMaps = false,
}) {
  if (failures.full) return;
  if (expected is Map) {
    if (actual is! Map || (exactMaps && actual.length != expected.length)) {
      failures.add('$path:object_mismatch');
      return;
    }
    for (final key in expected.keys) {
      if (!actual.containsKey(key)) {
        failures.add('$path.$key:missing');
      } else {
        _compare(
          expected[key],
          actual[key],
          '$path.$key',
          failures,
          exactMaps: exactMaps || key == 'askContext',
        );
      }
    }
  } else if (expected is List) {
    if (actual is! List || actual.length != expected.length) {
      failures.add('$path:array_length');
      return;
    }
    for (var i = 0; i < expected.length; i++) {
      _compare(expected[i], actual[i], '$path[$i]', failures, exactMaps: true);
    }
  } else if (expected is num && actual is num) {
    final tolerance = 1e-9 * math.max(1, expected.abs());
    if (!actual.isFinite || (expected - actual).abs() > tolerance) {
      failures.add('$path:number');
    }
  } else if (expected != actual) {
    failures.add('$path:value');
  }
}

void _checkInteractions(
  Map<String, dynamic> expected,
  UiSurfaceController controller,
  UiSurfaceRead read,
  _Failures failures,
  String path,
) {
  final requested = (expected['nodes'] as Map<String, dynamic>?) ?? const {};
  final parents = <String, String>{
    for (final entry in controller.parsed.program.children.entries)
      for (final child in entry.value) child: entry.key,
  };
  bool effective(String name, String property) {
    String? current = name;
    while (current != null) {
      final node = read.nodes[current];
      if (node == null || node.properties[property] == false) return false;
      current = parents[current];
    }
    return true;
  }

  if (!effective('root', 'visible')) failures.add('$path:root_hidden');
  final formInputs = <String>{};
  for (final entry in requested.entries) {
    final spec = entry.value as Map<String, dynamic>;
    final id = entry.key;
    final input =
        UiCatalog.components[spec['component']]?.textPolicy ==
        UiTextPolicy.input;
    if (input) formInputs.add(id);
    if (spec['visible'] == false) continue;
    if (!effective(id, 'visible')) failures.add('$path:$id:not_visible');
    final node = read.nodes[id];
    final actionMustWork =
        spec['action'] == 'Reset' ||
        (spec['action'] == 'Ask' &&
            node?.declaration.arguments['form'] == null);
    if ((input || actionMustWork) && !effective(id, 'enabled')) {
      failures.add('$path:$id:not_enabled');
    }
  }
  if (requested['form'] is Map && requested['form']['component'] == 'Form') {
    final members = <String>{};
    final pending = ['form'];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (!members.add(id)) continue;
      pending.addAll(controller.parsed.program.children[id] ?? const []);
    }
    for (final input in formInputs) {
      if (!members.contains(input)) failures.add('$path:$input:outside_form');
    }
  }
}

void _checkData(
  String component,
  Map<String, Object?> props,
  _Failures failures,
  String path,
) {
  if (failures.full) return;
  if (component != 'Chart' && component != 'DataTable') return;
  final data = props['data'];
  if (data is! List || data.any((row) => row is! Map<String, Object?>)) {
    failures.add('$path:record_array');
    return;
  }
  final rows = data.cast<Map<String, Object?>>();
  if (component == 'DataTable') {
    final keys = <Object?>{};
    final columns = props['columns'];
    if (rows.length > UiBudgets.tableRows ||
        columns is! List ||
        columns.length > UiBudgets.tableColumns ||
        columns.isEmpty) {
      failures.add('$path:table_budget_or_columns');
      return;
    }
    final columnKeys = <String>{};
    for (final column in columns) {
      if (column is! Map ||
          column['key'] is! String ||
          column['label'] is! String ||
          !columnKeys.add(column['key'] as String) ||
          column.keys.any(
            (key) => !const {'key', 'label', 'digits'}.contains(key),
          )) {
        failures.add('$path:column_definition');
        continue;
      }
      final digits = column['digits'];
      if (digits != null &&
          (digits is! num ||
              digits < 0 ||
              digits > 10 ||
              digits != digits.truncateToDouble())) {
        failures.add('$path:column_digits');
      }
    }
    for (final row in rows) {
      if (failures.full) return;
      final key = row[props['rowKey']];
      if (key == null || key is List || key is Map || !keys.add(key)) {
        failures.add('$path:row_key');
      }
      if (row.values.any((value) => value is List || value is Map)) {
        failures.add('$path:non_scalar_cell');
      }
      for (final column in columns) {
        if (column is! Map ||
            column['key'] is! String ||
            column['label'] is! String ||
            !row.containsKey(column['key'])) {
          failures.add('$path:column_mapping');
        }
      }
    }
  } else {
    final series = props['y'];
    if (series is! List ||
        series.isEmpty ||
        series.any((y) => y is! String) ||
        series.toSet().length != series.length ||
        series.length > UiBudgets.chartSeries ||
        rows.length * series.length > UiBudgets.chartPoints) {
      failures.add('$path:chart_budget_or_series');
      return;
    }
    final pie = props['kind'] == 'pie';
    if (pie && (series.length != 1 || rows.length > UiBudgets.pieItems)) {
      failures.add('$path:pie_budget');
    }
    var total = 0.0;
    for (final row in rows) {
      if (failures.full) return;
      final x = row[props['x']];
      if (x is! num && x is! String ||
          props['kind'] == 'scatter' && x is! num) {
        failures.add('$path:x_mapping');
      }
      for (final y in series) {
        final value = row[y];
        if (!row.containsKey(y) || (value != null && value is! num)) {
          failures.add('$path:y_mapping');
        }
        if (pie && (value is! num || value < 0)) {
          failures.add('$path:pie_value');
        }
        if (value is num) total += value;
      }
    }
    if (pie && rows.isNotEmpty && (total <= 0 || !total.isFinite)) {
      failures.add('$path:pie_total');
    }
  }
}

void _checkInputRange(
  String component,
  Map<String, Object?> props,
  _Failures failures,
  String path,
) {
  if (component != 'Slider' && component != 'NumberField') return;
  final value = props['bind'];
  final min = props['min'];
  final max = props['max'];
  final step = props['step'];
  if (step is! num ||
      step <= 0 ||
      (min is num && max is num && min >= max) ||
      (value is num &&
          ((min is num && value < min) || (max is num && value > max)))) {
    failures.add('$path:input_range');
  }
}
