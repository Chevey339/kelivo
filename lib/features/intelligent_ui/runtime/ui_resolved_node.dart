import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'ui_chart_data.dart';
import 'ui_table_data.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_diagnostic.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_evaluator.dart';

/// Presentation-independent values from one completed evaluation batch.
final class UiResolvedNode {
  UiResolvedNode({
    required this.declaration,
    required Map<String, Object?> properties,
    required Iterable<UiDiagnostic> diagnostics,
    required Iterable<UiSampleGap> gaps,
    this.pending = false,
    this.askText,
    this.askContext,
    this.chartData,
    this.tableData,
  }) : properties = Map.unmodifiable(properties),
       diagnostics = List.unmodifiable(diagnostics),
       gaps = List.unmodifiable(gaps);
  final UiNodeDeclaration declaration;
  final Map<String, Object?> properties;
  final UiChartData? chartData;
  final UiTableData? tableData;
  final List<UiDiagnostic> diagnostics;
  final List<UiSampleGap> gaps;
  final bool pending;
  final String? askText;
  final Map<String, Object?>? askContext;
  bool get valid => diagnostics.isEmpty && !pending;
  bool get visible => properties['visible'] != false;
  bool get enabled => valid && properties['enabled'] != false;
}

UiResolvedNode uiResolveNode(
  UiNodeDeclaration node,
  UiEvaluationBatch batch,
  Map<String, UiResolvedNode> resolved,
) {
  final program = batch.program;
  final diagnostics = <UiDiagnostic>[
    ...program.diagnostics.where(
      (diagnostic) => diagnostic.symbol == node.name,
    ),
  ];
  if (program.failedSymbols.contains(node.name) && diagnostics.isEmpty) {
    diagnostics.add(
      UiDiagnostic(
        UiDiagnosticCode.invalidValue,
        line: node.location.line,
        symbol: node.name,
      ),
    );
  }
  final properties = <String, Object?>{};
  final gaps = <UiSampleGap>{};
  final spec = UiCatalog.components[node.component];
  var pending = false;
  final visited = <String>{};
  final dependencies = [node.name];
  while (dependencies.isNotEmpty) {
    final name = dependencies.removeLast();
    if (!visited.add(name)) continue;
    if (program.pendingSymbols.contains(name)) pending = true;
    dependencies.addAll(program.dependencies[name] ?? const {});
  }
  String? askText;
  Map<String, Object?>? askContext;
  var sampledData = false;

  Object? evaluate(
    String key,
    UiExpression expression,
    UiPropertySpec property,
  ) {
    final computed = batch.readExpression(node.name, expression);
    if (key == 'data') sampledData = computed.sampled;
    if (computed.error case final error?) {
      if (error.code == UiDiagnosticCode.missingReference &&
          program.pendingSymbols.contains(error.detail)) {
        pending = true;
      } else {
        diagnostics.add(error);
      }
      return null;
    }
    gaps.addAll(computed.gaps);
    final value = computed.value;
    final valid = value == null
        ? property.nullable
        : switch (property.type) {
            UiValueType.number => value is num && value.isFinite,
            UiValueType.string => value is String,
            UiValueType.boolean => value is bool,
            UiValueType.scalar =>
              value is num || value is bool || value is String,
            UiValueType.array => value is List,
            UiValueType.record => value is Map<String, Object?>,
            UiValueType.sampleBody => false,
          };
    final inBounds =
        (property.choices.isEmpty || property.choices.contains(value)) &&
        (value is! num ||
            ((property.min == null || value >= property.min!) &&
                (property.max == null || value <= property.max!) &&
                (!property.integer || value == value.truncateToDouble())));
    if (!valid || !inBounds) {
      diagnostics.add(
        UiDiagnostic(
          valid ? UiDiagnosticCode.invalidValue : UiDiagnosticCode.typeMismatch,
          line: node.location.line,
          symbol: node.name,
          detail: key,
        ),
      );
      return null;
    }
    return value;
  }

  if (spec != null && !program.failedSymbols.contains(node.name) && !pending) {
    for (final entry in node.arguments.entries) {
      final property = spec.properties[entry.key];
      if (property == null) continue;
      switch (entry.value) {
        case UiExpression value:
          properties[entry.key] = evaluate(entry.key, value, property);
        case UiInputBinding(:final name):
          properties[entry.key] = evaluate(
            entry.key,
            UiRead(name, state: true),
            property,
          );
        case UiChildRefs(:final names):
          properties[entry.key] = names;
        case UiFormRef(:final name):
          properties[entry.key] = name;
          final form = resolved[name];
          if (form?.pending == true) {
            pending = true;
          } else if (form?.valid != true) {
            diagnostics.add(
              UiDiagnostic(
                UiDiagnosticCode.dependency,
                line: node.location.line,
                symbol: node.name,
                detail: name,
              ),
            );
          }
        case UiAsk(:final text, :final context):
          askText =
              evaluate(
                    'text',
                    text,
                    UiCatalog.actions['Ask']!.arguments['text']!,
                  )
                  as String?;
          askContext =
              evaluate(
                    'context',
                    context,
                    UiCatalog.actions['Ask']!.arguments['context']!,
                  )
                  as Map<String, Object?>?;
        case UiReset():
          break;
      }
    }
  }
  if (!pending &&
      (node.component == 'Select' || node.component == 'RadioGroup')) {
    final binding = node.arguments['bind'];
    final state = binding is UiInputBinding
        ? program.declarations[binding.name]
        : null;
    final options = properties['options'];
    final seen = <Object?>{};
    bool validOption(Object? option) {
      if (option is! Map<String, Object?> ||
          option.length != 2 ||
          !option.containsKey('value') ||
          option['label'] is! String ||
          (option['label'] as String).trim().isEmpty ||
          state is! UiStateDeclaration) {
        return false;
      }
      final value = option['value'];
      final typeMatches = value == null
          ? state.nullable
          : switch (state.type) {
              UiScalarType.number => value is num && value.isFinite,
              UiScalarType.string => value is String,
              UiScalarType.boolean => value is bool,
            };
      return typeMatches && seen.add(value);
    }

    if (options is! List || !options.every(validOption)) {
      diagnostics.add(
        UiDiagnostic(
          UiDiagnosticCode.invalidValue,
          line: node.location.line,
          symbol: node.name,
          detail: 'options',
        ),
      );
    }
  }
  if (!pending) {
    final min = properties['min'];
    final max = properties['max'];
    final step = properties['step'];
    final minLength = properties['minLength'];
    final maxLength = properties['maxLength'];
    if ((min is num && max is num && min > max) ||
        (step is num && step <= 0) ||
        (minLength is num && maxLength is num && minLength > maxLength)) {
      diagnostics.add(
        UiDiagnostic(
          UiDiagnosticCode.invalidValue,
          line: node.location.line,
          symbol: node.name,
          detail: 'range',
        ),
      );
    }
  }
  UiChartData? chartData;
  UiTableData? tableData;
  if (!pending && diagnostics.isEmpty && node.component == 'Chart') {
    try {
      chartData = UiChartData.read(
        properties,
        sampleGaps: gaps,
        sampled: sampledData,
      );
      tableData = UiTableData.fromChart(chartData, properties);
    } on UiChartDataException catch (error) {
      diagnostics.add(
        UiDiagnostic(
          error.code,
          line: node.location.line,
          symbol: node.name,
          detail: error.detail,
        ),
      );
    }
  }
  if (!pending && diagnostics.isEmpty && node.component == 'DataTable') {
    try {
      tableData = UiTableData.read(properties);
    } on UiTableDataException catch (error) {
      diagnostics.add(
        UiDiagnostic(
          error.code,
          line: node.location.line,
          symbol: node.name,
          detail: error.detail,
        ),
      );
    }
  }
  return UiResolvedNode(
    declaration: node,
    properties: properties,
    diagnostics: diagnostics,
    gaps: gaps,
    pending: pending,
    askText: askText,
    askContext: askContext,
    chartData: chartData,
    tableData: tableData,
  );
}
