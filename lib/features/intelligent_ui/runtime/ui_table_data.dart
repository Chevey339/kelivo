import 'dart:math' as math;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_diagnostic.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_chart_data.dart';

final class UiTableDataException implements Exception {
  const UiTableDataException(this.code, this.detail);
  final UiDiagnosticCode code;
  final String detail;
}

final class UiTableColumn {
  UiTableColumn({
    required this.key,
    required this.label,
    this.digits,
    required this.numeric,
  }) : viewKey = sha256.convert(utf8.encode(jsonEncode(key))).toString();
  final String key, label, viewKey;
  final int? digits;
  final bool numeric;
}

final class UiTableRow {
  UiTableRow({
    required this.key,
    required this.ordinal,
    required List<Object?> values,
  }) : values = List.unmodifiable(values);
  final Object key;
  final int ordinal;
  final List<Object?> values;
}

typedef UiTableCellText = String Function(UiTableColumn column, Object? value);

/// A literal text matcher shared by filtering and highlighting. Regex escaping
/// prevents model/user text from becoming an expression. Match offsets refer to
/// the original visible string (unlike indices in a lower-cased Unicode copy).
RegExp? uiTableFilter(String text) => text.isEmpty
    ? null
    : RegExp(RegExp.escape(text), caseSensitive: false, unicode: true);

final class UiTablePage {
  UiTablePage({
    required List<UiTableRow> rows,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.sortKey,
    required this.descending,
    required this.filter,
  }) : rows = List.unmodifiable(rows);
  final List<UiTableRow> rows;
  final int total, page, pageSize;
  final String? sortKey;
  final bool descending;
  final String filter;
  int get pages => math.max(1, (total / pageSize).ceil());
  int get from => total == 0 ? 0 : page * pageSize + 1;
  int get to => math.min(total, (page + 1) * pageSize);
}

/// Validated scalar records. Display/semantic/search callers provide the same
/// host formatter, so filters never search data hidden by numeric formatting.
final class UiTableData {
  UiTableData._(List<UiTableColumn> columns, List<UiTableRow> rows)
    : columns = List.unmodifiable(columns),
      rows = List.unmodifiable(rows);
  final List<UiTableColumn> columns;
  final List<UiTableRow> rows;

  factory UiTableData.read(Map<String, Object?> properties) {
    Never invalid(String detail) =>
        throw UiTableDataException(UiDiagnosticCode.invalidValue, detail);
    final data = properties['data'],
        rawColumns = properties['columns'],
        rowKey = properties['rowKey'];
    if (data is! List || data.any((row) => row is! Map<String, Object?>)) {
      invalid('tableRecords');
    }
    if (data.length > UiBudgets.tableRows) {
      throw const UiTableDataException(
        UiDiagnosticCode.dataBudget,
        'tableRows',
      );
    }
    if (rawColumns is! List || rawColumns.isEmpty) invalid('tableColumns');
    if (rawColumns.length > UiBudgets.tableColumns) {
      throw const UiTableDataException(
        UiDiagnosticCode.dataBudget,
        'tableColumns',
      );
    }
    if (rowKey is! String || rowKey.isEmpty) invalid('tableRowKey');
    final keys = <String>{};
    final columns = <UiTableColumn>[];
    for (final raw in rawColumns) {
      if (raw is! Map<String, Object?> ||
          raw.keys.any((k) => !const {'key', 'label', 'digits'}.contains(k))) {
        invalid('tableColumns');
      }
      final key = raw['key'], label = raw['label'], digits = raw['digits'];
      if (key is! String ||
          key.isEmpty ||
          !keys.add(key) ||
          label is! String ||
          label.trim().isEmpty ||
          (digits != null &&
              (digits is! num ||
                  !digits.isFinite ||
                  digits != digits.truncateToDouble() ||
                  digits < 0 ||
                  digits > 10))) {
        invalid('tableColumns');
      }
      if (data.isNotEmpty &&
          !data.any((row) => (row as Map).containsKey(key))) {
        invalid('tableFields');
      }
      final values = data
          .map((row) => (row as Map)[key])
          .where((v) => v != null);
      columns.add(
        UiTableColumn(
          key: key,
          label: label,
          digits: (digits as num?)?.toInt(),
          numeric:
              digits != null ||
              (values.isNotEmpty && values.every((v) => v is num)),
        ),
      );
    }
    bool scalar(Object? value) =>
        value == null ||
        value is String ||
        value is bool ||
        (value is num && value.isFinite);
    final seen = <Object>{}, rows = <UiTableRow>[];
    for (final raw in data.cast<Map<String, Object?>>()) {
      if (!raw.values.every(scalar)) invalid('tableCells');
      final key = raw[rowKey];
      if (key == null) invalid('tableRowKey');
      if (!seen.add(key)) {
        throw const UiTableDataException(
          UiDiagnosticCode.duplicateRowKey,
          'tableRowKey',
        );
      }
      rows.add(
        UiTableRow(
          key: key,
          ordinal: rows.length,
          values: [for (final column in columns) raw[column.key]],
        ),
      );
    }
    return UiTableData._(columns, rows);
  }

  /// The Chart has already passed its own 2,000-slot budget. It may legitimately
  /// contain more than the 1,000-row DSL DataTable limit. Preserve every row,
  /// including duplicate X values; source ordinals are its stable identities.
  factory UiTableData.fromChart(
    UiChartData chart,
    Map<String, Object?> properties,
  ) {
    final series = [
      for (var s = 0; s < chart.yKeys.length; s++)
        if (chart.yKeys[s] != chart.xKey) s,
    ];
    final unit = properties['unit'] as String?;
    return UiTableData._(
      [
        UiTableColumn(
          key: chart.xKey,
          label:
              '${properties['xLabel'] as String? ?? chart.xKey}${chart.yKeys.contains(chart.xKey) && unit != null && unit.isNotEmpty ? ' ($unit)' : ''}',
          numeric: chart.numericX,
        ),
        for (final s in series)
          UiTableColumn(
            key: chart.yKeys[s],
            label:
                '${chart.yKeys.length == 1 ? properties['yLabel'] as String? ?? chart.yKeys[s] : chart.yKeys[s]}${unit == null || unit.isEmpty ? '' : ' ($unit)'}',
            numeric: true,
          ),
      ],
      [
        for (final row in chart.rows)
          UiTableRow(
            key: row.index,
            ordinal: row.index,
            values: [row.x, for (final s in series) row.y[s]],
          ),
      ],
    );
  }

  UiTablePage project({
    required Map<String, Object?> view,
    required int defaultPageSize,
    required UiTableCellText format,
    bool sortable = true,
    bool filterable = true,
  }) {
    final filter = filterable ? view['filter'] as String? ?? '' : '';
    final matcher = uiTableFilter(filter);
    final selected = rows
        .where(
          (row) =>
              matcher == null ||
              [
                for (var c = 0; c < columns.length; c++)
                  format(columns[c], row.values[c]),
              ].any(matcher.hasMatch),
        )
        .toList();
    final sort = sortable
        ? columns.indexWhere((c) => c.viewKey == view['sortKey'])
        : -1;
    final descending = sort >= 0 && view['descending'] == true;
    if (sort >= 0) {
      selected.sort((a, b) {
        final av = a.values[sort], bv = b.values[sort];
        // Missing values always follow nonmissing values in both directions.
        if (av == null || bv == null) {
          return av == bv
              ? a.ordinal.compareTo(b.ordinal)
              : av == null
              ? 1
              : -1;
        }
        int rank(Object v) => v is num
            ? 0
            : v is String
            ? 1
            : 2;
        var comparison = rank(av).compareTo(rank(bv));
        if (comparison == 0) {
          comparison = av is num && bv is num
              ? av.compareTo(bv)
              : av is bool && bv is bool
              ? (av ? 1 : 0).compareTo(bv ? 1 : 0)
              : av.toString().toLowerCase().compareTo(
                  bv.toString().toLowerCase(),
                );
        }
        return comparison == 0
            ? a.ordinal.compareTo(b.ordinal)
            : descending
            ? -comparison
            : comparison;
      });
    }
    final pageSize = view['pageSize'] as int? ?? defaultPageSize;
    final page = (view['page'] as int? ?? 0)
        .clamp(0, math.max(0, (selected.length / pageSize).ceil() - 1))
        .toInt();
    return UiTablePage(
      rows: selected.skip(page * pageSize).take(pageSize).toList(),
      total: selected.length,
      page: page,
      pageSize: pageSize,
      sortKey: sort < 0 ? null : columns[sort].viewKey,
      descending: descending,
      filter: filter,
    );
  }
}
