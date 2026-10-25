import 'dart:convert';
import 'dart:math' as math;
import '../catalog/ui_catalog.dart';
import '../catalog/ui_budgets.dart';
import '../models/ui_context_attachment.dart';
import '../protocol/ui_diagnostic.dart';
import '../protocol/ui_ir.dart';
import '../runtime/ui_form_validation.dart';
import '../runtime/ui_resolved_node.dart';
import '../runtime/ui_surface_controller.dart';
import '../runtime/ui_table_data.dart';
import 'ui_bounded_text.dart';
import 'ui_number.dart';
import 'ui_number_display.dart';
import 'ui_markdown_text.dart';

/// The Flutter host supplies ARB-backed wording. Projection itself has no
/// widget, platform, database or network dependency and reads one frozen batch.
final class UiProjectionLabels {
  const UiProjectionLabels({
    required this.defaultTitle,
    required this.yes,
    required this.no,
    required this.empty,
    required this.omitted,
    required this.waiting,
    required this.diagnostic,
    required this.fieldIssue,
    required this.chartKind,
    required this.chartSummary,
    required this.pieSummary,
    required this.range,
    required this.tablePage,
    required this.filter,
    required this.domainGaps,
    required this.trend,
  });
  final String defaultTitle, yes, no, empty, omitted;
  final String Function(String id) waiting;
  final String Function(UiDiagnostic) diagnostic;
  final String Function(UiFieldIssue) fieldIssue;
  final String Function(UiChartKind kind, bool donut) chartKind;
  final String Function(String kind, int series, int rows, int missing)
  chartSummary;
  final String Function(String kind, int items, String total) pieSummary;
  final String Function(String name, String min, String max) range;
  final String Function(int from, int to, int total) tablePage;
  final String Function(String query) filter;
  final String Function(int count) domainGaps;
  final String Function(String value) trend;
}

/// Human-readable semantic fields in visual order, selected under byte budgets.
/// Context contains accepted values; an interaction owner must first settle or
/// reject transient field drafts. Later edits cannot mutate [UiSurfaceRead].
enum UiTextMode { copy, speech, search, export }

final class UiTextProjection {
  const UiTextProjection(this.labels);
  final UiProjectionLabels labels;

  UiContextText context(UiSurfaceRead read, {Map<String, Object?>? selected}) {
    final title = _title(read);
    final output = UiBoundedText(
      UiContextText.bodyBudget(title),
      omission: labels.omitted,
    );
    if (selected != null) {
      for (final entry in selected.entries) {
        output.add('${jsonEncode(entry.key)}: ${jsonEncode(entry.value)}');
      }
    } else {
      _walk(read, output);
    }
    final body = output.finish();
    return UiContextText(
      title: title,
      body: body.isEmpty ? labels.empty : body,
    );
  }

  String text(UiSurfaceRead read, {UiTextMode mode = UiTextMode.copy}) {
    final output = UiBoundedText(
      mode == UiTextMode.search
          ? UiBudgets.searchTextBytes
          : UiBudgets.copyBytes,
      omission: labels.omitted,
    );
    if (read.phase == SurfacePhase.invalid &&
        read.program.diagnostics.isNotEmpty) {
      output.add(labels.diagnostic(read.program.diagnostics.first));
    } else {
      _walk(read, output);
    }
    final result = output.finish();
    return result.isEmpty ? labels.empty : result;
  }

  String _title(UiSurfaceRead read) {
    final seen = <String>{};
    String? find(String id) {
      if (!seen.add(id)) return null;
      final node = read.nodes[id];
      if (node?.visible != true || node?.valid != true) return null;
      final title = node!.properties['title'];
      if (title is String &&
          title.length <= 256 &&
          title.trim().isNotEmpty &&
          utf8.encode(title).length <= 256) {
        return title;
      }
      final children = node.declaration.arguments['children'];
      if (children is UiChildRefs) {
        for (final child in children.names) {
          final result = find(child);
          if (result != null) return result;
        }
      }
      return null;
    }

    return find('root') ?? labels.defaultTitle;
  }

  String scalar(Object? value, {int? digits}) => switch (value) {
    null => '—',
    num n => genUiNumber(n, digits: digits),
    bool b => b ? labels.yes : labels.no,
    String s => s,
    _ => jsonEncode(value),
  };

  String _withUnit(Object? value, Object? unit, {int? digits}) =>
      '${scalar(value, digits: digits)}${unit is String && unit.isNotEmpty ? ' $unit' : ''}';

  void _walk(UiSurfaceRead read, UiBoundedText output) {
    final seen = <String>{};
    final work = _ProjectionWork();
    void visit(String id, {bool enabled = true}) {
      if (!seen.add(id)) return;
      final node = read.nodes[id];
      if (node?.pending == true ||
          (node == null &&
              (read.program.pendingSymbols.contains(id) ||
                  read.phase == SurfacePhase.streaming ||
                  read.phase == SurfacePhase.interrupted))) {
        output.add(labels.waiting(id));
        return;
      }
      if (node?.declaration.component == 'Button' &&
          node?.properties['label'] is String &&
          !node!.visible) {
        return;
      }
      if (node == null || !node.valid) {
        final errors =
            node?.diagnostics ??
            read.program.diagnostics.where((d) => d.symbol == id);
        output.add(
          labels.diagnostic(
            errors.firstOrNull ??
                UiDiagnostic(
                  UiDiagnosticCode.missingReference,
                  line: 1,
                  symbol: id,
                ),
          ),
        );
        return; // An invalid container does not render its children either.
      }
      if (!node.visible) return;
      final props = node.properties;
      final active = enabled && node.enabled;
      void add(Object? value) {
        if (value is String) output.add(value);
      }

      final policy =
          UiCatalog.components[node.declaration.component]!.textPolicy;
      switch (policy) {
        case UiTextPolicy.layout || UiTextPolicy.form:
          add(props['title']);
          add(props['subtitle']);
        case UiTextPolicy.divider:
          add(props['label']);
        case UiTextPolicy.text:
          add(props['title']);
          if (node.declaration.component == 'Markdown') {
            final text = work.markdown(props['text'] as String);
            if (text == null) {
              output.noteOmission();
            } else {
              add(text);
            }
          } else {
            add(props['text']);
          }
        case UiTextPolicy.formula:
          output.add(
            '${props['label'] == null ? '' : '${props['label']}: '}${props['tex']}',
          );
        case UiTextPolicy.metric:
          output.add(
            '${props['label']}: ${_withUnit(props['value'], props['unit'], digits: (props['digits'] as num?)?.toInt())}',
          );
          if (props['trend'] != null) {
            output.add(
              '${props['label']}: ${labels.trend(scalar(props['trend']))}',
            );
          }
        case UiTextPolicy.input:
          var value = scalar(props['bind']);
          if (props['options'] case final List options) {
            for (final option in options.whereType<Map<String, Object?>>()) {
              if (option['value'] == props['bind']) {
                value = '${option['label']} (${jsonEncode(props['bind'])})';
                break;
              }
            }
          }
          output.add(
            '${props['label']}: $value${props['unit'] == null ? '' : ' ${props['unit']}'}',
          );
          final issue = active ? validateUiField(node, read.program) : null;
          if (issue != null) {
            output.add('${props['label']}: ${labels.fieldIssue(issue)}');
          }
        case UiTextPolicy.action:
          break; // Actions and chrome are not current parameter/result values.
        case UiTextPolicy.chart:
          _chart(node, output, work);
          if (read.state.view[id]?['dataView'] == true) {
            _table(node, read, output, work);
          }
        case UiTextPolicy.table:
          _table(node, read, output, work);
      }
      final children = node.declaration.arguments['children'];
      if (children is UiChildRefs) {
        for (final child in children.names) {
          visit(child, enabled: active);
        }
      }
    }

    visit('root');
  }

  void _chart(UiResolvedNode node, UiBoundedText output, _ProjectionWork work) {
    final data = node.chartData!, props = node.properties;
    if (props['title'] case final String title) output.add(title);
    final kind = labels.chartKind(data.kind, props['donut'] == true);
    if (data.kind == UiChartKind.pie) {
      output.add(
        labels.pieSummary(
          kind,
          data.rows.length,
          _withUnit(data.total, props['unit']),
        ),
      );
      for (final row in data.rows) {
        output.add('${row.x}: ${_withUnit(row.y.single, props['unit'])}');
      }
      return;
    }
    output.add(
      labels.chartSummary(
        kind,
        data.yKeys.length,
        data.rows.length,
        data.missingCount,
      ),
    );
    if (props['yLabel'] case final String label when data.yKeys.length > 1) {
      output.add(label);
    }
    if (!work.consumeData(data.rows.length * (data.yKeys.length + 1))) {
      output.noteOmission();
      return;
    }
    if (data.rows.isNotEmpty) {
      final x = data.rows.map((r) => r.x);
      final low = data.numericX ? x.cast<num>().reduce(math.min) : x.first;
      final high = data.numericX ? x.cast<num>().reduce(math.max) : x.last;
      output.add(
        labels.range(
          props['xLabel'] as String? ?? data.xKey,
          scalar(low),
          scalar(high),
        ),
      );
    }
    for (var s = 0; s < data.yKeys.length; s++) {
      final values = data.rows.map((row) => row.y[s]).nonNulls.toList();
      final name = data.yKeys.length == 1
          ? props['yLabel'] as String? ?? data.yKeys[s]
          : data.yKeys[s];
      output.add(
        labels.range(
          name,
          _withUnit(
            values.isEmpty ? null : values.reduce(math.min),
            props['unit'],
          ),
          _withUnit(
            values.isEmpty ? null : values.reduce(math.max),
            props['unit'],
          ),
        ),
      );
    }
    if (data.domainRows.isNotEmpty) {
      output.add(labels.domainGaps(data.domainRows.length));
    }
  }

  void _table(
    UiResolvedNode node,
    UiSurfaceRead read,
    UiBoundedText output,
    _ProjectionWork work,
  ) {
    final table = node.tableData!;
    output.add(table.columns.map((c) => c.label).join(' | '));
    for (final row in table.rows) {
      for (final value in row.values) {
        if (!work.consumeData(value is String ? value.length + 1 : 1)) {
          output.noteOmission();
          return;
        }
      }
    }
    String format(UiTableColumn column, Object? value) =>
        scalar(value, digits: column.digits);
    // Match the visible table's row set without rounding the values copied
    // below into text or the frozen context.
    String display(UiTableColumn column, Object? value) => value is num
        ? genUiDisplayNumber(value, digits: column.digits)
        : format(column, value);
    final page = table.project(
      view: read.state.view[node.declaration.name] ?? const {},
      defaultPageSize: (node.properties['pageSize'] as num?)?.toInt() ?? 10,
      format: display,
      sortable: node.properties['sortable'] != false,
      filterable: node.properties['filterable'] != false,
    );
    output.add(labels.tablePage(page.from, page.to, page.total));
    if (page.filter.isNotEmpty) output.add(labels.filter(page.filter));
    for (final row in page.rows) {
      output.add(
        [
          for (var i = 0; i < table.columns.length; i++)
            '${table.columns[i].label}: ${format(table.columns[i], row.values[i])}',
        ].join(' | '),
      );
    }
    if (page.rows.length < page.total) output.noteOmission();
  }
}

/// Output size alone does not bound expensive conversion of rejected fields.
/// This per-projection owner also limits input work, sharing repeated Markdown.
final class _ProjectionWork {
  int _markdownRemaining = 16 * 1024;
  int _dataRemaining = UiBudgets.operationsPerBatch;
  final _markdown = <String, String?>{};
  String? markdown(String source) {
    if (_markdown.containsKey(source)) return _markdown[source];
    if (source.length > _markdownRemaining) return _markdown[source] = null;
    final bytes = utf8.encode(source).length;
    if (bytes > _markdownRemaining) return _markdown[source] = null;
    _markdownRemaining -= bytes;
    return _markdown[source] = uiMarkdownText(source);
  }

  bool consumeData(int count) {
    if (count > _dataRemaining) return false;
    _dataRemaining -= count;
    return true;
  }
}
