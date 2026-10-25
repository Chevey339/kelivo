import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_diagnostic.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_chart_data.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_evaluator.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';

Map<String, Object?> _props({
  String kind = 'line',
  List<Object?>? rows,
  List<String> y = const ['y'],
}) => {
  'kind': kind,
  'x': 'x',
  'y': y,
  'data':
      rows ??
      [
        {'x': 0, 'y': 2},
        {'x': 1, 'y': 3},
      ],
};
Matcher _error(UiDiagnosticCode code, [String? detail]) => throwsA(
  isA<UiChartDataException>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.detail, 'detail', detail ?? isNotEmpty),
);
double _nextUp(double value) {
  final b = ByteData(8)..setFloat64(0, value);
  b.setUint64(0, b.getUint64(0) + 1);
  return b.getFloat64(0);
}

void main() {
  test('readable Y bounds put the lowest tick on the painted border', () {
    for (final values in [
      [50.0, 40.0, 35.0, 30.0],
      [-50.0, 40.0],
      [0.0, 0.0],
    ]) {
      final axis = UiChartAxis(values, includeZero: true, niceTicks: true);
      final step = axis.tickInterval!;
      final firstTick = (axis.minimum / step).ceil() * step;
      expect(
        (firstTick - axis.minimum) / (axis.maximum - axis.minimum) * 260,
        lessThan(1e-6),
      );
      expect(
        axis.coordinate(values.reduce((a, b) => a < b ? a : b)),
        greaterThan(axis.minimum),
      );
    }
  });
  test(
    'tick labels suppress cancellation residue without erasing tiny data',
    () {
      final axis = UiChartAxis([-1.997, 1.994], niceTicks: true);
      final zero = axis.coordinate(0) - 1e-16;
      expect(axis.value(zero), isNot(0));
      expect(axis.tickValue(zero), 0);
      final tiny = UiChartAxis([-2e-20, 2e-20], niceTicks: true);
      expect(tiny.tickValue(tiny.coordinate(1e-20)), closeTo(1e-20, 1e-35));
      expect(tiny.tickValue(tiny.coordinate(-1e-20)), closeTo(-1e-20, 1e-35));
    },
  );

  test(
    'sample provenance follows value aliases without classifying ordinary numbers as a function',
    () {
      final c = UiSurfaceController(
        owner: const UiSurfaceOwner(revisionId: 'samples', surfaceKey: '0:0'),
      );
      addTearDown(c.dispose);
      c.updateSource(
        r'''ui 1 catalog "kelivo.native/1"
$sample: boolean = false
$title: string = "Curve"
let sampled = @sample(x => x * x, -2, 2, 21)
let points = $sample ? sampled : [{"x":0,"y":3},{"x":1,"y":7}]
let alias = points
root = Column(children=[curve,observations])
curve = Chart(kind="line",title=$title,data=alias,x="x",y=["y"])
observations = Chart(kind="line",data=[{"x":0,"y":1},{"x":1,"y":2}],x="x",y=["y"])
''',
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      expect(c.phase, SurfacePhase.complete);
      expect(c.nodes['curve']!.chartData!.sampled, isFalse);
      c.setInputs({'sample': true}, token: c.token);
      expect(c.nodes['curve']!.chartData!.sampled, isTrue);
      c.setInputs({'title': 'Cached values'}, token: c.token);
      expect(c.nodes['curve']!.chartData!.sampled, isTrue);
      c.setInputs({'sample': false}, token: c.token);
      expect(c.nodes['curve']!.chartData!.sampled, isFalse);
      expect(c.nodes['observations']!.chartData!.sampled, isFalse);
    },
  );
  for (final kind in UiChartKind.values) {
    test('${kind.name} retains raw finite values and accepts empty data', () {
      final d = UiChartData.read(_props(kind: kind.name));
      expect(d.kind, kind);
      expect(d.rows.map((r) => r.y.single), [2, 3]);
      expect(d.missingCount, 0);
      expect(
        UiChartData.read(_props(kind: kind.name, rows: [])).isEmpty,
        isTrue,
      );
    });
  }
  test(
    'numeric positions preserve distances and strings retain source order',
    () {
      final d = UiChartData.read(
        _props(
          rows: [
            {'x': 0, 'y': 1},
            {'x': 2, 'y': 2},
            {'x': 10, 'y': 3},
          ],
        ),
      );
      expect(d.numericX, isTrue);
      expect(d.x(d.rows[1]), .2);
      final category = UiChartData.read(
        _props(
          rows: [
            {'x': 'March', 'y': 1},
            {'x': 'January', 'y': 2},
            {'x': 'March', 'y': 3},
          ],
        ),
      );
      expect(category.numericX, isFalse);
      expect(category.rows.map((r) => r.x), ['March', 'January', 'March']);
      expect(category.rows.map(category.x), [0, .5, 1]);
      expect(category.rows.map((r) => r.index), [0, 1, 2]);
    },
  );
  test('narrow neighboring large numbers remain equally spaced', () {
    for (final a in [1e100, 1e300]) {
      final b = _nextUp(a), c = _nextUp(_nextUp(a));
      final axis = UiChartAxis([a, b, c]);
      expect(axis.coordinate(a), 0);
      expect(axis.coordinate(b), .5);
      expect(axis.coordinate(c), 1);
      expect(axis.value(.5), b);
    }
  });
  test(
    'finite extreme and subnormal ranges never create nonfinite plot bounds',
    () {
      for (final values in [
        [-double.maxFinite, double.maxFinite],
        [double.maxFinite],
        [double.minPositive, double.minPositive * 2],
        [0.0],
      ]) {
        final axis = UiChartAxis(values);
        expect(axis.minimum.isFinite && axis.maximum.isFinite, isTrue);
        expect(axis.maximum, greaterThan(axis.minimum));
        for (final value in values) {
          expect(axis.coordinate(value).isFinite, isTrue);
        }
      }
      final axis = UiChartAxis([-double.maxFinite, double.maxFinite]);
      expect(axis.value(axis.maximum), isNull);
      expect(axis.value(axis.minimum), isNull);
      expect(axis.value(0), 0);
    },
  );
  test('missing values retain null slots and never become zero', () {
    final d = UiChartData.read(
      _props(
        rows: [
          {'x': 0, 'y': 2},
          {'x': 1, 'y': null},
          {'x': 2},
          {'x': 3, 'y': 5},
        ],
      ),
    );
    expect(d.rows.map((r) => r.y.single), [2, null, null, 5]);
    expect(d.missingCount, 2);
    expect(d.gaps, isEmpty);
    final empty = UiChartData.read(
      _props(
        rows: [
          {'x': 0, 'y': null},
        ],
      ),
    );
    expect(empty.isEmpty, isTrue);
    expect(empty.missingCount, 1);
  });
  test('only real matching sampled domain gaps receive shading ranges', () {
    final d = UiChartData.read(
      _props(
        rows: [
          {'x': -2, 'y': 2},
          {'x': -1, 'y': null},
          {'x': 0, 'y': null},
          {'x': 1, 'y': null},
          {'x': 2, 'y': 2},
        ],
      ),
      sampleGaps: const [
        UiSampleGap(x: -1, index: 1, code: UiDiagnosticCode.domain),
        UiSampleGap(x: 0, index: 2, code: UiDiagnosticCode.domain),
        UiSampleGap(x: 99, index: 3, code: UiDiagnosticCode.domain),
      ],
    );
    expect(d.domainRows, {1, 2});
    expect(d.gaps, hasLength(1));
    expect(d.gaps.single.start, d.xAxis.coordinate(-1.5));
    expect(d.gaps.single.end, d.xAxis.coordinate(.5));
  });
  test('Cartesian budgets include missing slots across every series', () {
    List<Object?> rows(int n) => [
      for (var i = 0; i < n; i++) {'x': i, 'a': 1, 'b': null, 'c': 2, 'd': 3},
    ];
    expect(
      UiChartData.read(_props(rows: rows(500), y: ['a', 'b', 'c', 'd'])).rows,
      hasLength(500),
    );
    expect(
      () => UiChartData.read(_props(rows: rows(501), y: ['a', 'b', 'c', 'd'])),
      _error(UiDiagnosticCode.dataBudget, 'chartPoints'),
    );
    expect(
      () => UiChartData.read(_props(y: ['a', 'b', 'c', 'd', 'e'])),
      _error(UiDiagnosticCode.dataBudget, 'chartSeries'),
    );
  });
  test('pie is bounded, nonnegative and has a finite positive total', () {
    final good = UiChartData.read(
      _props(
        kind: 'pie',
        rows: [
          {'x': 'A', 'y': 3},
          {'x': 'B', 'y': null},
          {'x': 'C', 'y': 0},
        ],
      ),
    );
    expect(good.total, 3);
    expect(good.missingCount, 1);
    for (final values in [
      [-1, 3],
      [0, 0],
      [null, null],
      [double.maxFinite, double.maxFinite],
    ]) {
      expect(
        () => UiChartData.read(
          _props(
            kind: 'pie',
            rows: [
              for (var i = 0; i < values.length; i++)
                {'x': '$i', 'y': values[i]},
            ],
          ),
        ),
        _error(UiDiagnosticCode.invalidValue, 'chartPieValues'),
      );
    }
    expect(
      UiChartData.read(
        _props(
          kind: 'pie',
          rows: [
            for (var i = 0; i < 12; i++) {'x': '$i', 'y': 1},
          ],
        ),
      ).rows,
      hasLength(12),
    );
    expect(
      () => UiChartData.read(
        _props(
          kind: 'pie',
          rows: [
            for (var i = 0; i < 13; i++) {'x': '$i', 'y': 1},
          ],
        ),
      ),
      _error(UiDiagnosticCode.dataBudget, 'chartPoints'),
    );
    expect(
      () => UiChartData.read(_props(kind: 'pie', y: ['a', 'b'])),
      _error(UiDiagnosticCode.dataBudget, 'chartSeries'),
    );
  });
  test('unknown/mixed/nonfinite fields produce bounded node diagnostics', () {
    for (final rows in [
      [
        {'x': 0, 'y': 1},
        {'x': 'A', 'y': 2},
      ],
      [
        {'y': 1},
      ],
      [
        {'x': true, 'y': 1},
      ],
    ]) {
      expect(
        () => UiChartData.read(_props(rows: rows)),
        _error(UiDiagnosticCode.invalidValue, 'chartX'),
      );
    }
    expect(
      () => UiChartData.read(
        _props(
          kind: 'scatter',
          rows: [
            {'x': 'A', 'y': 1},
          ],
        ),
      ),
      _error(UiDiagnosticCode.invalidValue, 'chartX'),
    );
    for (final rows in [
      [
        {'x': 0, 'z': 1},
      ],
      [
        {'x': 0, 'y': '1'},
      ],
      [
        {
          'x': 0,
          'y': {'nested': 1},
        },
      ],
    ]) {
      expect(
        () => UiChartData.read(_props(rows: rows)),
        _error(UiDiagnosticCode.invalidValue, 'chartY'),
      );
    }
    expect(
      () => UiChartData.read(_props(rows: [1])),
      _error(UiDiagnosticCode.invalidValue, 'chartRecords'),
    );
    expect(
      () => UiChartData.read(_props(y: ['y', 'y'])),
      _error(UiDiagnosticCode.invalidValue, 'chartFields'),
    );
    expect(
      () => UiChartData.read(
        _props(
          rows: [
            {'x': double.infinity, 'y': 1},
          ],
        ),
      ),
      _error(UiDiagnosticCode.nonFinite),
    );
    expect(
      () => UiChartData.read(
        _props(
          rows: [
            {'x': 0, 'y': double.nan},
          ],
        ),
      ),
      _error(UiDiagnosticCode.nonFinite),
    );
  });
  test('the same numeric column can legitimately supply both axes', () {
    final data = UiChartData.read(_props(y: ['x']));
    expect(data.rows.map((r) => r.y.single), [0, 1]);
  });
  test(
    'dynamic bad chart data is a local node error and recovers in one batch',
    () {
      final c = UiSurfaceController(
        owner: const UiSurfaceOwner(revisionId: 'chart', surfaceKey: '0:0'),
      );
      addTearDown(c.dispose);
      c.updateSource(
        '${UiCatalog.header}\n'
        r'''$value: number = -1
root = Column(children=[good,chart])
good = Text(text="Sibling survives")
chart = Chart(kind="pie",data=[{"x":"A","y":$value}],x="x",y=["y"])
''',
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      expect(c.phase, SurfacePhase.completeWithErrors);
      expect(c.nodes['chart']!.diagnostics.single.detail, 'chartPieValues');
      expect(c.nodes['good']!.valid, isTrue);
      c.setInputs({'value': 2}, token: c.token);
      expect(c.phase, SurfacePhase.complete);
      expect(c.nodes['chart']!.chartData!.total, 2);
      final model = c.nodes['chart']!.chartData;
      c.setView('chart', {
        'hiddenSeries': [0],
      }, token: c.token);
      expect(c.nodes['chart']!.chartData, same(model));
    },
  );
}
