import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import '../../support/genui_projection_fixture.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_interaction_controller.dart';

UiSurfaceController _controller(String body, {bool header = true}) {
  final c = UiSurfaceController(
    owner: const UiSurfaceOwner(revisionId: 'projection', surfaceKey: '0:0'),
  );
  c.updateSource(
    '${header ? '${UiCatalog.header}\n' : ''}$body\n',
    closed: true,
    generation: UiGenerationStatus.complete,
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test(
    'completed missing references and hidden runtime errors remain errors',
    () {
      final c = _controller('''root = Column(children=[missing,bad,good])
bad = Metric(label="Hidden bad",value=1/0,visible=false)
good = Text(text="Good")''');
      expect(c.phase, SurfacePhase.completeWithErrors);
      final body = testUiProjection.context(c.captureRead()).body;
      expect(body, contains('Error: missingReference'));
      expect(body, contains('Error: divisionByZero'));
      expect(body, isNot(contains('Waiting')));
    },
  );
  test('axis names and Metric changes preserve their meanings', () {
    final c = _controller(
      '''root = Column(children=[metric,chart])
metric = Metric(label="Revenue",value=100,trend=-5,unit="USD")
chart = Chart(kind="line",x="t",y=["a","b"],xLabel="Time",yLabel="Revenue axis",unit="USD",data=[{"t":1,"a":2,"b":3}])''',
    );
    final body = testUiProjection.context(c.captureRead()).body;
    expect(body, contains('Revenue: 100 USD\nRevenue: Change -5'));
    expect(body, contains('Revenue axis'));
    expect(body, contains('Time: 1–1'));
  });
  test(
    'conversion work is bounded even for 255 references to huge Markdown',
    () {
      final c = _controller(genUiRepeatedMarkdownFixture(255), header: false);
      expect(c.phase, SurfacePhase.complete);
      expect(
        testUiProjection.context(c.captureRead()).body,
        '[Some fields omitted]',
      );
    },
  );
  test(
    'Ask captures oversized context for whole-field projection without retry',
    () {
      final context = jsonEncode({'huge': '界' * 2000, 'tiny': 1});
      final c = _controller(
        'root = Button(label="Ask",action=Ask(text="Explain",context=$context))',
      );
      final i = UiInteractionController(c);
      addTearDown(i.dispose);
      final intent = i.activate('root', token: c.token).intent!;
      expect(
        testUiProjection.context(intent.read, selected: intent.context).body,
        '"tiny": 1.0\n[Some fields omitted]',
      );
    },
  );
  for (final spec in UiCatalog.components.values) {
    test('${spec.name} has a bounded semantic projection', () {
      final c = _controller(spec.example, header: false);
      expect(c.phase, SurfacePhase.complete);
      final result = testUiProjection.context(c.captureRead());
      expect(result.body, isNotEmpty);
      expect(utf8.encode(result.exactText).length, lessThanOrEqualTo(4096));
      expect(result.body, isNot(contains(UiCatalog.header)));
    });
  }
  test('input and results stay in the same immutable batch after edits', () {
    final c = _controller(r'''$a: number = 2
root = Column(children=[input,result])
input = Slider(label="Slope",bind=$a,min=0,max=10)
result = Metric(label="Double",value=$a*2,unit="km")''');
    final read = c.captureRead();
    c.setInputs({'a': 3.5}, token: c.token);
    expect(testUiProjection.context(read).body, 'Slope: 2\nDouble: 4 km');
    expect(
      testUiProjection.context(c.captureRead()).body,
      'Slope: 3.5\nDouble: 7 km',
    );
  });
  test(
    'oversized selected fields are omitted whole and later fields survive',
    () {
      final c = _controller('root = Text(text="Visible")');
      final selected = {
        'huge': '界' * 3000,
        'small': {'value': 3.1, 'label': '示例'},
      };
      final text = testUiProjection
          .context(c.captureRead(), selected: selected)
          .body;
      expect(
        text,
        '"small": {"value":3.1,"label":"示例"}\n[Some fields omitted]',
      );
      expect(
        testUiProjection.context(c.captureRead(), selected: {}).body,
        'No fields.',
      );
    },
  );
  test('unrendered descendants never supply a title or values', () {
    final c = _controller('''root = Column(children=[bad,hidden,good])
bad = Section(title="Bad",unknown="x",children=[secret])
secret = Section(title="Secret title",children=[value])
value = Metric(label="Unrendered",value=99)
hidden = Metric(label="Hidden",value=7,visible=false)
good = Metric(label="Visible",value=3)''');
    final context = testUiProjection.context(c.captureRead());
    expect(context.title, 'Interface');
    expect(context.body, contains('Error: unknownProperty'));
    expect(context.body, contains('Visible: 3'));
    expect(context.body, isNot(contains('Unrendered')));
    expect(context.body, isNot(contains('Hidden')));
  });
  test(
    'option labels, required fields and disabled fields match visible semantics',
    () {
      final c = _controller(
        r'''$choice: string = "a"
$name: string = ""
root = Form(title="Selection",children=[choiceField,nameField,disabled])
choiceField = Select(label="Plan",bind=$choice,options=[{"value":"a","label":"Plan A"}])
nameField = TextField(label="Name",bind=$name,required=true)
disabled = TextField(label="Disabled",bind=$name,required=true,enabled=false)''',
      );
      final body = testUiProjection.context(c.captureRead()).body;
      expect(c.phase, SurfacePhase.complete);
      expect(body, contains('Plan: Plan A ("a")'));
      expect(body, contains('Name: Field: required'));
      expect(body, isNot(contains('Disabled: Field: required')));
    },
  );
  test('Chart data view shares table formatting and page semantics', () {
    final c = _controller(
      'root = Chart(kind="line",x="x",y=["y"],unit="km",data=[{"x":1,"y":2},{"x":2,"y":null}])',
    );
    c.setView('root', {'dataView': true}, token: c.token);
    final body = testUiProjection.context(c.captureRead()).body;
    expect(body, contains('line, 1 series, 2 rows, 1 missing'));
    expect(body, contains('Rows 1–2 of 2'));
    expect(body, contains('x: 2 | y (km): —'));
  });
  test(
    'Markdown projection uses the same noninteractive subset as rendering',
    () {
      final c = _controller(
        'root = Markdown(text=${jsonEncode('**Bold** [label](https://example.com)')})',
      );
      final body = testUiProjection.context(c.captureRead()).body;
      expect(body, contains('Bold'));
      expect(body, contains('label'));
      expect(body, isNot(contains('**')));
      expect(body, isNot(contains('root =')));
    },
  );
}
