import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_diagnostic.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_chart_data.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_table_data.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';

Map<String, Object?> _props(List<Object?> rows, {List<Object?>? columns}) => {
  'data': rows,
  'rowKey': 'id',
  'columns':
      columns ??
      [
        {'key': 'id', 'label': 'Name'},
        {'key': 'v', 'label': 'Value'},
      ],
};
String _format(UiTableColumn column, Object? value) => value == null
    ? '—'
    : value is num && column.digits != null
    ? value.toStringAsFixed(column.digits!)
    : value.toString();
UiTablePage _page(
  UiTableData table, {
  String? key,
  bool descending = false,
  String filter = '',
  int page = 0,
  int pageSize = 10,
}) => table.project(
  view: {
    if (key != null)
      'sortKey': table.columns.firstWhere((c) => c.key == key).viewKey,
    'descending': descending,
    'filter': filter,
    'page': page,
    'pageSize': pageSize,
  },
  defaultPageSize: 10,
  format: _format,
);
Matcher _error(UiDiagnosticCode code) =>
    throwsA(isA<UiTableDataException>().having((e) => e.code, 'code', code));
UiSurfaceController _controller(String body) {
  final c = UiSurfaceController(
    owner: const UiSurfaceOwner(revisionId: 'table', surfaceKey: '0:0'),
  );
  c.updateSource(
    '${UiCatalog.header}\n$body\n',
    closed: true,
    generation: UiGenerationStatus.complete,
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('empty tables retain explicit columns and use an empty page', () {
    final t = UiTableData.read(_props([]));
    final page = _page(t, page: 9);
    expect(t.columns.map((c) => c.label), ['Name', 'Value']);
    expect(page.rows, isEmpty);
    expect(
      (page.from, page.to, page.total, page.page, page.pages),
      (0, 0, 0, 0, 1),
    );
  });
  test(
    'scalar row identities stay immutable and independent of sorted ordinals',
    () {
      final raw = [
        {'id': '', 'v': 3},
        {'id': false, 'v': 2},
        {'id': 42, 'v': 1},
      ];
      final t = UiTableData.read(_props(raw));
      raw[0]['v'] = 100;
      final page = _page(t, key: 'v');
      expect(page.rows.map((r) => r.key), [42, false, '']);
      expect(page.rows.map((r) => r.ordinal), [2, 1, 0]);
      expect(page.rows.last.values.last, 3);
      expect(() => t.rows.clear(), throwsUnsupportedError);
      expect(() => t.rows.first.values.clear(), throwsUnsupportedError);
    },
  );
  test('duplicate row keys are rejected including numerically equal keys', () {
    for (final keys in [
      ['a', 'a'],
      [1, 1.0],
      [true, true],
    ]) {
      expect(
        () => UiTableData.read(
          _props([
            for (final key in keys) {'id': key, 'v': 1},
          ]),
        ),
        _error(UiDiagnosticCode.duplicateRowKey),
      );
    }
  });
  test(
    'missing row keys and nested or nonfinite cells are not silently coerced',
    () {
      for (final row in [
        <String, Object?>{'v': 1},
        {'id': null, 'v': 1},
        {
          'id': 'a',
          'v': [1],
        },
        {'id': 'a', 'v': double.infinity},
        {
          'id': 'a',
          'v': 1,
          'hidden': {'nested': true},
        },
      ]) {
        expect(
          () => UiTableData.read(_props([row])),
          _error(UiDiagnosticCode.invalidValue),
        );
      }
      expect(
        () => UiTableData.read(_props([1])),
        _error(UiDiagnosticCode.invalidValue),
      );
    },
  );
  test(
    'columns require distinct known fields and only bounded digits metadata',
    () {
      for (final columns in [
        [],
        [
          {'key': 'id', 'label': ''},
        ],
        [
          {'key': 'missing', 'label': 'Missing'},
        ],
        [
          {'key': 'v', 'label': 'Value', 'digits': 11},
        ],
        [
          {'key': 'v', 'label': 'Value', 'digits': 1.5},
        ],
        [
          {'key': 'v', 'label': 'Value', 'color': 'red'},
        ],
        [
          {'key': 'v', 'label': 'A'},
          {'key': 'v', 'label': 'B'},
        ],
      ]) {
        expect(
          () => UiTableData.read(
            _props([
              {'id': 'a', 'v': 1},
            ], columns: columns),
          ),
          _error(UiDiagnosticCode.invalidValue),
        );
      }
    },
  );
  test('per-row missing cells remain null when the field exists elsewhere', () {
    final t = UiTableData.read(
      _props([
        {'id': 'a', 'v': 1},
        {'id': 'b'},
      ]),
    );
    expect(t.rows[1].values[1], isNull);
    expect(_page(t, filter: '—').rows.single.key, 'b');
  });
  test('DataTable limits are inclusive and do not silently truncate', () {
    final rows = [
      for (var i = 0; i < 1001; i++) {'id': i, 'v': i},
    ];
    expect(
      UiTableData.read(_props(rows.take(1000).toList())).rows,
      hasLength(1000),
    );
    expect(
      () => UiTableData.read(_props(rows)),
      _error(UiDiagnosticCode.dataBudget),
    );
    expect(
      () => UiTableData.read(
        _props(
          [],
          columns: [
            for (var i = 0; i < 9; i++) {'key': 'c$i', 'label': 'C$i'},
          ],
        ),
      ),
      _error(UiDiagnosticCode.dataBudget),
    );
  });
  test(
    'nulls stay last and equal values keep original order in both directions',
    () {
      final t = UiTableData.read(
        _props([
          {'id': 'null1', 'v': null},
          {'id': 'two1', 'v': 2},
          {'id': 'one', 'v': 1},
          {'id': 'two2', 'v': 2},
          {'id': 'null2', 'v': null},
        ]),
      );
      expect(_page(t, key: 'v').rows.map((r) => r.key), [
        'one',
        'two1',
        'two2',
        'null1',
        'null2',
      ]);
      expect(_page(t, key: 'v', descending: true).rows.map((r) => r.key), [
        'two1',
        'two2',
        'one',
        'null1',
        'null2',
      ]);
    },
  );
  test(
    'mixed scalars use a deterministic type order with numeric comparison',
    () {
      final t = UiTableData.read(
        _props([
          {'id': 'n10', 'v': 10},
          {'id': 'n2', 'v': 2},
          {'id': 'sB', 'v': 'b'},
          {'id': 'sA', 'v': 'A'},
          {'id': 'true', 'v': true},
          {'id': 'false', 'v': false},
          {'id': 'null', 'v': null},
        ]),
      );
      expect(_page(t, key: 'v').rows.map((r) => r.key), [
        'n2',
        'n10',
        'sA',
        'sB',
        'false',
        'true',
        'null',
      ]);
      expect(_page(t, key: 'v', descending: true).rows.map((r) => r.key), [
        'true',
        'false',
        'sB',
        'sA',
        'n10',
        'n2',
        'null',
      ]);
    },
  );
  test(
    'filtering uses exactly visible formatted text and literal matching',
    () {
      final t = UiTableData.read(
        _props(
          [
            {'id': '[A].*', 'v': 1.2345, 'hidden': 'secret'},
            {'id': 'other', 'v': 3},
          ],
          columns: [
            {'key': 'id', 'label': 'Name'},
            {'key': 'v', 'label': 'Value', 'digits': 1},
          ],
        ),
      );
      expect(_page(t, filter: '1.2').rows.single.key, '[A].*');
      expect(_page(t, filter: '2345').rows, isEmpty);
      expect(_page(t, filter: 'secret').rows, isEmpty);
      expect(_page(t, filter: '[a].*').rows.single.key, '[A].*');
      final text = 'İa😀A';
      final matches = uiTableFilter('a')!.allMatches(text);
      expect(matches.map((m) => text.substring(m.start, m.end)), ['a', 'A']);
      expect(uiTableFilter('😀')!.firstMatch(text)!.start, 2);
    },
  );
  test(
    'page bounds clamp after filtering and 20-row pages preserve identity',
    () {
      final t = UiTableData.read(
        _props([
          for (var i = 0; i < 25; i++) {'id': 'row-$i', 'v': i},
        ]),
      );
      var page = _page(t, page: 999);
      expect((page.page, page.from, page.to), (2, 21, 25));
      page = _page(t, page: 1, pageSize: 20);
      expect(page.rows.map((r) => r.ordinal), [20, 21, 22, 23, 24]);
      page = _page(t, page: 1, filter: 'row-0');
      expect((page.page, page.total), (0, 1));
    },
  );
  test(
    'long field names and dynamic column order retain a bounded sort identity',
    () {
      final field = List.filled(200, '界').join();
      final raw = [
        {'id': 'a', field: 2},
        {'id': 'b', field: 1},
      ];
      final cols = [
        {'key': field, 'label': 'Value'},
        {'key': 'id', 'label': 'Name'},
      ];
      final a = UiTableData.read(_props(raw, columns: cols));
      final b = UiTableData.read(_props(raw, columns: cols.reversed.toList()));
      final id = a.columns.first.viewKey;
      expect(id.length, 64);
      expect(b.columns.last.viewKey, id);
      expect(
        b
            .project(
              view: {'sortKey': id},
              defaultPageSize: 10,
              format: _format,
            )
            .rows
            .first
            .key,
        'b',
      );
    },
  );
  test(
    'Chart data view keeps all 2000 rows and repeated X source identities',
    () {
      final chart = UiChartData.read({
        'kind': 'line',
        'x': 'x',
        'y': ['y'],
        'data': [
          for (var i = 0; i < 2000; i++) {'x': i % 2, 'y': i},
        ],
      });
      final t = UiTableData.fromChart(chart, {'unit': 'USD'});
      expect(t.rows, hasLength(2000));
      expect(t.columns.last.label, 'y (USD)');
      final page = _page(t, page: 199);
      expect((page.from, page.to), (1991, 2000));
      expect(page.rows.first.key, 1990);
      expect(_page(t, key: 'y', descending: true).rows.first.key, 1999);
    },
  );
  test('lone surrogate field keys keep distinct sort identities', () {
    final t = UiTableData.read(
      _props(
        [
          {'id': 'a', '\ud800': 1, '\ud801': 2},
          {'id': 'b', '\ud800': 2, '\ud801': 1},
        ],
        columns: [
          {'key': '\ud800', 'label': 'First'},
          {'key': '\ud801', 'label': 'Second'},
        ],
      ),
    );
    expect(t.columns.first.viewKey, isNot(t.columns.last.viewKey));
    expect(_page(t, key: '\ud801').rows.first.key, 'b');
  });
  test('shared X/Y column keeps units alongside other Y series', () {
    final chart = UiChartData.read({
      'kind': 'line',
      'x': 'a',
      'y': ['a', 'b'],
      'data': [
        {'a': 1, 'b': 2},
      ],
    });
    final t = UiTableData.fromChart(chart, {'unit': 'USD'});
    expect(t.columns.map((c) => c.label), ['a (USD)', 'b (USD)']);
    expect(t.rows.single.values, [1, 2]);
  });
  test('Chart identical X/Y field has one column without losing its unit', () {
    final chart = UiChartData.read({
      'kind': 'line',
      'x': 'x',
      'y': ['x'],
      'data': [
        {'x': 1},
        {'x': 2},
      ],
    });
    final t = UiTableData.fromChart(chart, {'unit': 'u'});
    expect(t.columns, hasLength(1));
    expect(t.columns.single.label, 'x (u)');
    expect(t.rows.last.values, [2]);
  });
  test(
    'invalid table is a local node error and can recover after input change',
    () {
      final c = _controller(
        r'''$id: string = "a"
root = Column(children=[good,table])
good = Text(text="Still visible")
table = DataTable(data=[{"id":"a","v":1},{"id":$id,"v":2}],rowKey="id",columns=[{"key":"v","label":"Value"}])''',
      );
      expect(
        c.nodes['table']!.diagnostics.single.code,
        UiDiagnosticCode.duplicateRowKey,
      );
      expect(c.nodes['good']!.valid, isTrue);
      expect(
        c.setInputs({'id': 'b'}, token: c.token),
        UiMutationResult.accepted,
      );
      expect(c.nodes['table']!.tableData!.rows, hasLength(2));
    },
  );
  for (final size in [10, 20]) {
    test('literal page size $size normalizes back to source defaults', () {
      final c = _controller(
        'root = DataTable(data=[],rowKey="id",columns=[{"key":"id","label":"ID"}],pageSize=$size)',
      );
      c.setView('root', {'pageSize': size == 10 ? 20 : 10}, token: c.token);
      expect(c.state.isDefault, isFalse);
      c.setView('root', {'pageSize': size}, token: c.token);
      expect(c.state.isDefault, isTrue);
    });
  }
  test(
    'dynamic page-size choice pins until reset and Chart table view round-trips',
    () {
      final c = _controller(r'''$size: number = 10
root = Column(children=[table,chart])
table = DataTable(data=[],rowKey="id",columns=[{"key":"id","label":"ID"}],pageSize=$size)
chart = Chart(kind="line",data=[{"x":0,"y":1}],x="x",y=["y"])''');
      c.setView('table', {'pageSize': 10}, token: c.token);
      expect(c.state.view['table']?['pageSize'], 10);
      c.setInputs({'size': 20}, token: c.token);
      c.setView('chart', {
        'dataView': true,
        'hiddenSeries': [0],
        'pageSize': 20,
        'page': 1,
        'sortKey': c.nodes['chart']!.tableData!.columns.last.viewKey,
        'descending': true,
        'filter': '1',
      }, token: c.token);
      final snapshot = c.captureSnapshot();
      final encoded = UiSurfaceState.decode(
        c.parsed.program,
        snapshot.state.json,
        stateVersion: 1,
      );
      expect(encoded.json, snapshot.state.json);
      c.reset(token: c.token);
      expect(c.state.isDefault, isTrue);
      expect(
        c.setView('chart', {'pageSize': 15}, token: c.token),
        UiMutationResult.invalid,
      );
    },
  );
}
