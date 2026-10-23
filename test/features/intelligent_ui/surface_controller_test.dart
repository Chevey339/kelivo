import 'dart:convert';

import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_diagnostic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';

const _owner = UiSurfaceOwner(revisionId: 'revision-a', surfaceKey: '0:0');
const _body =
    r'''root = Column(children=[aInput,bInput,left,right,total,table,chart,ask,reset])
$a: number = 1
$b: number = 10
let leftValue = $a * 2
let rightValue = $b * 3
let totalValue = leftValue + rightValue
aInput = Slider(label="A", bind=$a, min=-100, max=100)
bInput = NumberField(label="B", bind=$b)
left = Metric(label="Left", value=leftValue)
right = Metric(label="Right", value=rightValue)
total = Metric(label="Total", value=totalValue)
table = DataTable(data=[{"id":"one","v":1}], rowKey="id", columns=[{"key":"id","label":"ID"},{"key":"v","label":"Value"}])
chart = Chart(kind="line", data=[{"x":0,"y":1},{"x":1,"y":2}], x="x", y=["y"])
ask = Button(label="Explain", action=Ask(text="Explain the values", context={"a":$a,"total":totalValue}))
reset = Button(label="Reset", action=Reset())''';
String _source([String body = _body]) => '${UiCatalog.header}\n$body';
UiSurfaceController _controller({
  String body = _body,
  bool readOnly = false,
  UiSurfaceOwner owner = _owner,
}) {
  final controller = UiSurfaceController(owner: owner, readOnly: readOnly);
  controller.updateSource(
    _source(body),
    closed: true,
    generation: UiGenerationStatus.complete,
  );
  return controller;
}

UiMutationResult _input(UiSurfaceController c, String name, Object? value) =>
    c.setInputs({name: value}, token: c.token);

void main() {
  test(
    'defaults initialize once and repeated reads retain a coherent batch',
    () {
      final c = _controller();
      expect(c.phase, SurfacePhase.complete);
      expect(c.readOnly, isFalse);
      expect(c.captureRead().inputs, {'a': 1.0, 'b': 10.0});
      expect(c.nodes['total']!.properties['value'], 32);
      expect(c.state.json, '{"inputs":{},"view":{}}');
      expect(c.sequence, 0);
      final node = c.nodes['total'];
      for (var i = 0; i < 100; i++) {
        expect(c.captureRead().nodes['total'], same(node));
      }
    },
  );

  test(
    'both real fence closure and successful host completion unlock input',
    () {
      final c = UiSurfaceController(owner: _owner);
      c.updateSource(
        _source(),
        closed: false,
        generation: UiGenerationStatus.generating,
      );
      expect(c.phase, SurfacePhase.streaming);
      expect(_input(c, 'a', 2), UiMutationResult.readOnly);
      c.updateSource(
        _source(),
        closed: true,
        generation: UiGenerationStatus.generating,
      );
      expect(c.phase, SurfacePhase.streaming);
      expect(c.canSnapshot, isFalse);
      var controlsChanged = 0;
      c.listenNode('aInput', () => controlsChanged++);
      c.updateSource(
        _source(),
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      expect(c.phase, SurfacePhase.complete);
      expect(controlsChanged, 1);
      expect(_input(c, 'a', 2), UiMutationResult.accepted);
    },
  );

  test('interruption is read-only even with a closed fence', () {
    final c = UiSurfaceController(owner: _owner);
    c.updateSource(
      _source(),
      closed: false,
      generation: UiGenerationStatus.complete,
    );
    expect(c.phase, SurfacePhase.interrupted);
    expect(c.canSnapshot, isFalse);
    c.updateSource(
      _source(),
      closed: true,
      generation: UiGenerationStatus.interrupted,
    );
    expect(c.phase, SurfacePhase.interrupted);
    expect(_input(c, 'a', 2), UiMutationResult.readOnly);
    expect(c.captureSnapshot, throwsStateError);
  });

  test('whole-surface failure differs from an isolated broken node', () {
    final invalid = _controller(body: 'root = Gauge(value=1)');
    expect(invalid.phase, SurfacePhase.invalid);
    expect(invalid.readOnly, isTrue);
    final partial = _controller(body: 'broken');
    expect(partial.phase, SurfacePhase.invalid);
    partial.updateSource(
      _source('''root = Column(children=[bad,good])
bad = Gauge(value=1)
good = Text(text="Healthy")'''),
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    expect(partial.phase, SurfacePhase.completeWithErrors);
    expect(partial.readOnly, isFalse);
    expect(partial.nodes['bad']!.valid, isFalse);
    expect(partial.nodes['good']!.valid, isTrue);
  });

  test('unresolved derived dependencies remain pending while streaming', () {
    final c = UiSurfaceController(owner: _owner);
    final prefix = _source('''root = Metric(label="Result", value=result)
let result = missing * 2
''');
    c.updateSource(
      prefix,
      closed: false,
      generation: UiGenerationStatus.generating,
    );
    expect(c.nodes['root']!.pending, isTrue);
    expect(c.nodes['root']!.diagnostics, isEmpty);
    c.updateSource(
      '${prefix}let missing = 3',
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    expect(c.phase, SurfacePhase.complete);
    expect(c.nodes['root']!.properties['value'], 6);
  });

  test('only dependent nodes receive input notifications, not the shell', () {
    final c = _controller();
    final notifications = <String>[];
    for (final id in c.nodes.keys) {
      c.listenNode(id, () => notifications.add(id));
    }
    var status = 0;
    var changes = 0;
    c.listenStatus(() => status++);
    c.listenState(() {
      changes++;
      final read = c.captureRead();
      expect(read.inputs['a'], 2);
      expect(read.values['totalValue']!.value, 34);
      expect(read.nodes['ask']!.askContext, {'a': 2.0, 'total': 34.0});
    });
    final right = c.nodes['right'];
    expect(_input(c, 'a', 2), UiMutationResult.accepted);
    expect(notifications.toSet(), {'aInput', 'left', 'total', 'ask'});
    expect(c.nodes['right'], same(right));
    expect(status, 0);
    expect(changes, 1);
    expect(_input(c, 'a', 2.0), UiMutationResult.unchanged);
    expect(changes, 1);
  });

  test('retained reads and state collections are deeply immutable', () {
    final c = _controller();
    final before = c.captureRead();
    _input(c, 'a', 3);
    expect(before.inputs['a'], 1);
    expect(before.nodes['total']!.properties['value'], 32);
    expect(() => before.inputs.clear(), throwsUnsupportedError);
    expect(
      () => before.nodes['ask']!.askContext!.clear(),
      throwsUnsupportedError,
    );
    c.setView('chart', {
      'hiddenSeries': [2, 0, 2],
      'dataView': true,
    }, token: c.token);
    expect(c.state.view['chart']!['hiddenSeries'], [0, 2]);
    expect(
      () => (c.state.view['chart']!['hiddenSeries'] as List).clear(),
      throwsUnsupportedError,
    );
    expect(() => c.state.view['chart']!.clear(), throwsUnsupportedError);
  });

  test('manual return to defaults and Reset normalize to the same state', () {
    final c = _controller();
    c.setInputs({'b': 5, 'a': 3}, token: c.token);
    expect(c.state.json, '{"inputs":{"a":3.0,"b":5.0},"view":{}}');
    c.setView('table', {
      'sortKey': 'v',
      'descending': true,
      'page': 1,
    }, token: c.token);
    expect(c.state.isDefault, isFalse);
    c.setInputs({'a': 1, 'b': 10}, token: c.token);
    c.setView('table', {
      'sortKey': null,
      'descending': true,
      'page': 0,
      'filter': '',
    }, token: c.token);
    final manual = c.state.json;
    c.setView('chart', {'dataView': true}, token: c.token);
    expect(c.reset(token: c.token), UiMutationResult.accepted);
    expect(c.state.json, manual);
    expect(c.state.isDefault, isTrue);
  });

  test(
    'same source, line-ending normalization and appearance do not reset input',
    () {
      final c = _controller();
      _input(c, 'a', 8);
      final sourceHash = c.sourceHash;
      final before = c.nodes['left'];
      c.updateSource(
        _source(),
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      expect(c.nodes['left'], same(before));
      final token = c.token;
      c.updateSource(
        _source().replaceAll('\n', '\r\n'),
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      expect(c.sourceHash, sourceHash);
      expect(c.accepts(token), isFalse);
      c.setReadOnly(true);
      expect(_input(c, 'a', 9), UiMutationResult.readOnly);
      c.setReadOnly(false);
      expect(c.captureRead().inputs['a'], 8);
    },
  );

  test(
    'source replacement invalidates callbacks, overrides and source hash',
    () {
      final c = _controller();
      _input(c, 'a', 8);
      final token = c.token;
      final oldHash = c.sourceHash;
      c.updateSource(
        _source().replaceFirst(r'$a: number = 1', r'$a: number = 2'),
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      expect(c.sourceHash, isNot(oldHash));
      expect(c.state.isDefault, isTrue);
      expect(c.captureRead().inputs['a'], 2);
      expect(c.setInputs({'a': 9}, token: token), UiMutationResult.stale);
    },
  );

  test('owner and controller instance keep independent states and tokens', () {
    final a = _controller();
    final b = _controller(
      owner: const UiSurfaceOwner(revisionId: 'revision-b', surfaceKey: '0:0'),
    );
    final recreated = _controller();
    _input(a, 'a', 8);
    expect(a.sourceHash, b.sourceHash);
    expect(b.restore(a.captureSnapshot(), token: b.restoreToken), isFalse);
    expect(
      recreated.setInputs({'a': 9}, token: a.token),
      UiMutationResult.stale,
    );
    expect(b.captureRead().inputs['a'], 1);
  });

  test(
    'restore validates source and cannot overwrite input accepted during load',
    () {
      final source = _controller();
      _input(source, 'a', 4);
      final saved = source.captureSnapshot();
      final c = _controller();
      var saves = 0;
      c.listenState(() => saves++);
      expect(c.restore(saved, token: c.restoreToken), isTrue);
      expect(c.captureRead().values['totalValue']!.value, 38);
      expect(saves, 0);
      final pendingRestore = c.restoreToken;
      _input(c, 'a', 5);
      expect(c.restore(saved, token: pendingRestore), isFalse);
      expect(c.captureRead().inputs['a'], 5);
      final different = _controller(
        body: _body.replaceFirst('Total', 'Changed'),
      );
      expect(different.restore(saved, token: different.restoreToken), isFalse);
    },
  );

  test('read-only exports can restore snapshots without enabling mutation', () {
    final source = _controller();
    _input(source, 'a', 4);
    final target = _controller(readOnly: true);
    expect(
      target.restore(source.captureSnapshot(), token: target.restoreToken),
      isTrue,
    );
    expect(target.nodes['total']!.properties['value'], 38);
    expect(target.reset(token: target.token), UiMutationResult.readOnly);
  });

  test(
    'even no-op user choices and composing drafts invalidate pending restore',
    () {
      final source = _controller();
      _input(source, 'a', 7);
      final saved = source.captureSnapshot();
      for (final interact in <void Function(UiSurfaceController)>[
        (c) => c.reset(token: c.token),
        (c) => c.setInputs({'a': 1}, token: c.token),
        (c) => c.setView('table', const {}, token: c.token),
        (c) => c.noteInteraction(token: c.token),
      ]) {
        final c = _controller();
        final pending = c.restoreToken;
        var writes = 0;
        c.listenState(() => writes++);
        interact(c);
        expect(c.sequence, 0);
        expect(writes, 0);
        expect(c.restore(saved, token: pending), isFalse);
        expect(c.captureRead().inputs['a'], 1);
      }
    },
  );

  test('the diagnostic cap never turns failed nodes into valid controls', () {
    final source = StringBuffer(
      'root = Column(children=[${List.generate(255, (i) => 'n$i').join(',')}])\n',
    );
    for (var i = 0; i < 255; i++) {
      source.writeln('n$i = Text(a=1, b=2, c=3)');
    }
    final c = _controller(body: source.toString());
    expect(c.parsed.program.diagnostics, hasLength(512));
    expect(c.phase, SurfacePhase.completeWithErrors);
    for (var i = 0; i < 255; i++) {
      expect(c.nodes['n$i']!.valid, isFalse);
      expect(c.nodes['n$i']!.enabled, isFalse);
      expect(c.nodes['n$i']!.diagnostics, isNotEmpty);
    }
  });

  test(
    'FormRef propagates runtime errors even when the button arrives first',
    () {
      final c = _controller(
        body: r'''root = Column(children=[form,input])
$d: number = 0
ask = Button(label="Explain", form=form, action=Ask(text="Explain", context={"d":$d}))
form = Form(visible=1 / $d > 0, children=[label,ask])
input = NumberField(label="Divisor", bind=$d)
label = Text(text="Form")''',
      );
      expect(c.nodes['form']!.valid, isFalse);
      expect(c.nodes['ask']!.enabled, isFalse);
      expect(
        c.nodes['ask']!.diagnostics.single.code,
        UiDiagnosticCode.dependency,
      );
      var notified = 0;
      c.listenNode('ask', () => notified++);
      _input(c, 'd', 1);
      expect(c.nodes['form']!.valid, isTrue);
      expect(c.nodes['ask']!.enabled, isTrue);
      expect(notified, 1);
    },
  );

  test('invalid multi-input updates reject the whole batch', () {
    final c = _controller();
    final before = c.captureRead();
    expect(
      c.setInputs({'a': 3, 'b': '4'}, token: c.token),
      UiMutationResult.invalid,
    );
    expect(c.sequence, before.sequence);
    expect(c.nodes['total'], same(before.nodes['total']));
    for (final invalid in [
      double.infinity,
      double.nan,
      true,
      null,
      <Object>[],
    ]) {
      expect(_input(c, 'a', invalid), UiMutationResult.invalid);
    }
    expect(_input(c, 'missing', 1), UiMutationResult.invalid);
  });

  test('nullable inputs preserve null and reject lossy coercion', () {
    final c = _controller(
      body: r'''$a: number? = 3
root = NumberField(label="Optional", bind=$a)''',
    );
    expect(_input(c, 'a', null), UiMutationResult.accepted);
    expect(c.state.inputs.containsKey('a'), isTrue);
    expect(c.nodes['root']!.properties['bind'], isNull);
    expect(_input(c, 'a', '4'), UiMutationResult.invalid);
    expect(_input(c, 'a', 3), UiMutationResult.accepted);
    expect(c.state.isDefault, isTrue);
  });

  test(
    'UTF-8 state size is bounded without truncation or partial input changes',
    () {
      final c = _controller(
        body: r'''$text: string = ""
root = TextField(label="Text", bind=$text, maxLength=8192)''',
      );
      expect(_input(c, 'text', '界' * 11000), UiMutationResult.invalid);
      expect(c.state.isDefault, isTrue);
      expect(_input(c, 'text', '界' * 8000), UiMutationResult.accepted);
      expect(utf8.encode(c.state.json).length, lessThan(32 * 1024));
    },
  );

  test(
    'state decoding rejects foreign versions, keys, types and view settings',
    () {
      final c = _controller();
      for (final raw in [
        'null',
        '{"inputs":{},"view":{},"extra":0}',
        '{"inputs":{"unknown":1},"view":{}}',
        '{"inputs":{"a":"1"},"view":{}}',
        '{"inputs":{},"view":{"left":{"dataView":true}}}',
        '{"inputs":{},"view":{"table":{"page":-1}}}',
        '{"inputs":{},"view":{"chart":{"hiddenSeries":[12]}}}',
        '{"inputs":{},"view":{"table":{"script":"bad"}}}',
      ]) {
        expect(
          () => UiSurfaceState.decode(c.parsed.program, raw, stateVersion: 1),
          throwsFormatException,
          reason: raw,
        );
      }
      expect(
        () => UiSurfaceState.decode(
          c.parsed.program,
          c.state.json,
          stateVersion: 2,
        ),
        throwsFormatException,
      );
      final a = UiSurfaceState.decode(
        c.parsed.program,
        '{"view":{},"inputs":{"b":9,"a":2}}',
        stateVersion: 1,
      );
      final b = UiSurfaceState.decode(
        c.parsed.program,
        '{"inputs":{"a":2.0,"b":9.0},"view":{}}',
        stateVersion: 1,
      );
      expect(a.json, b.json);
    },
  );

  test('view changes notify only that view and remain absent from inputs', () {
    final c = _controller();
    final changed = <String>[];
    for (final id in c.nodes.keys) {
      c.listenNode(id, () => changed.add(id));
    }
    expect(
      c.setView('table', {'sortKey': 'v', 'descending': true}, token: c.token),
      UiMutationResult.accepted,
    );
    expect(changed, ['table']);
    expect(c.state.inputs, isEmpty);
    expect(
      c.setView('left', {'dataView': true}, token: c.token),
      UiMutationResult.invalid,
    );
  });

  test('runtime errors stay local and recover when their input changes', () {
    final c = _controller(
      body: r'''root = Column(children=[input,result,good])
$a: number = -1
let value = @sqrt($a)
input = NumberField(label="Input", bind=$a)
result = Metric(label="Root", value=value)
good = Text(text="Unaffected")''',
    );
    expect(c.phase, SurfacePhase.completeWithErrors);
    expect(
      c.nodes['result']!.diagnostics.single.code,
      UiDiagnosticCode.dependency,
    );
    final good = c.nodes['good'];
    expect(_input(c, 'a', 4), UiMutationResult.accepted);
    expect(c.phase, SurfacePhase.complete);
    expect(c.nodes['result']!.properties['value'], 2);
    expect(c.nodes['good'], same(good));
  });

  test(
    'dynamic catalog constraints are checked after expression evaluation',
    () {
      final c = _controller(
        body: r'''root = Column(children=[input,label])
$a: boolean = true
input = Switch(label="Toggle", bind=$a)
label = Text(text="Example", variant=$a ? "unknown" : "body")''',
      );
      expect(c.phase, SurfacePhase.completeWithErrors);
      expect(
        c.nodes['label']!.diagnostics.single.code,
        UiDiagnosticCode.invalidValue,
      );
      _input(c, 'a', false);
      expect(c.phase, SurfacePhase.complete);
    },
  );

  test('stale save completions cannot clear the latest failure badge', () {
    final c = _controller();
    _input(c, 'a', 3);
    final earlier = c.sequence;
    expect(c.setSaveFailed(true, token: c.token, sequence: earlier), isTrue);
    _input(c, 'a', 4);
    expect(c.saveFailed, isTrue);
    expect(c.setSaveFailed(false, token: c.token, sequence: earlier), isFalse);
    expect(c.saveFailed, isTrue);
    expect(
      c.setSaveFailed(false, token: c.token, sequence: c.sequence),
      isTrue,
    );
    expect(c.saveFailed, isFalse);
  });

  test(
    'unsubscribe and disposal invalidate callbacks without state writes',
    () {
      final c = _controller();
      var calls = 0;
      final stop = c.listenNode('left', () => calls++);
      stop();
      _input(c, 'a', 2);
      expect(calls, 0);
      final token = c.token;
      c.dispose();
      c.dispose();
      expect(c.setInputs({'a': 4}, token: token), UiMutationResult.stale);
      expect(() => c.listenNode('left', () {}), throwsStateError);
      expect(c.captureRead, throwsStateError);
    },
  );
}
