import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_form_validation.dart';

UiSurfaceController _surface(String source) {
  final c = UiSurfaceController(
    owner: const UiSurfaceOwner(revisionId: 'form-test', surfaceKey: '0:0'),
  );
  c.updateSource(
    '${UiCatalog.header}\n$source',
    closed: true,
    generation: UiGenerationStatus.complete,
  );
  addTearDown(c.dispose);
  return c;
}

UiFormCheck _check(
  UiSurfaceController c, {
  Map<String, UiFieldDraft> drafts = const {},
}) => validateUiForm(
  'root',
  c.parsed.program,
  UiControlTree(c.nodes),
  drafts: drafts,
);

void main() {
  test(
    'contradictory field bounds and non-positive steps are node-local errors',
    () {
      for (final props in ['min=10,max=2', 'step=0', 'step=-1']) {
        final c = _surface(
          '\$n: number = 2\nroot = Form(children=[field])\nfield = NumberField(label="Number",bind=\$n,$props)',
        );
        expect(c.nodes['field']!.valid, isFalse, reason: props);
        expect(c.nodes['root']!.valid, isTrue);
        expect(_check(c).unavailable, ['field']);
      }
      final text = _surface(r'''$name: string = ""
root = TextField(label="Name",bind=$name,minLength=10,maxLength=2)''');
      expect(text.nodes['root']!.valid, isFalse);
    },
  );
  test('form follows visible child order, including ancestor visibility', () {
    final c = _surface(r'''$show: boolean = false
$name: string = ""
$n: number? = null
root = Form(children=[nameField,section])
amount = NumberField(label="Amount", bind=$n, required=true, min=0, max=10)
section = Section(title="Optional group", visible=$show, children=[amount])
nameField = TextField(label="Name", bind=$name, required=true)''');
    expect(_check(c).issues.map((e) => e.node), ['nameField']);
    c.setInputs({'show': true}, token: c.token);
    expect(_check(c).issues.map((e) => e.node), ['nameField', 'amount']);
    c.setInputs({'name': 'Ready', 'n': 6}, token: c.token);
    expect(_check(c).valid, isTrue);
    c.setInputs({'show': false}, token: c.token);
    expect(c.captureRead().inputs['n'], 6);
    expect(
      _check(c, drafts: {'amount': const UiFieldDraft('-')}).valid,
      isTrue,
    );
  });
  test('a visible failed child blocks the referenced Form', () {
    final c = _surface('root = Form(children=[bad])\nbad = Gauge(value=4)');
    final check = _check(c);
    expect(check.valid, isFalse);
    expect(check.unavailable, contains('bad'));
  });
  test('complete finite numbers only; incomplete input stays a draft', () {
    for (final text in ['2', '-2', '+2', '.5', '-.25', '1e-2', ' 3 ']) {
      expect(parseUiNumber(text), isNotNull, reason: text);
    }
    for (final text in [
      '',
      '-',
      '+',
      '.',
      '1.',
      '1e',
      '1e-',
      '--1',
      'NaN',
      'Infinity',
      '1e309',
    ]) {
      expect(parseUiNumber(text), isNull, reason: text);
    }
  });
  test('number drafts never fall through to the previous committed value', () {
    final c = _surface(r'''$n: number? = 6
root = Form(children=[amount])
amount = NumberField(label="Amount", bind=$n, required=true, min=0, max=10)''');
    expect(_check(c).valid, isTrue);
    for (final text in ['-', '1.', '1e', 'hello']) {
      expect(
        _check(c, drafts: {'amount': UiFieldDraft(text)}).issues.single.error,
        UiFieldError.number,
      );
      expect(c.captureRead().inputs['n'], 6);
    }
    expect(
      _check(c, drafts: {'amount': const UiFieldDraft('')}).issues.single.error,
      UiFieldError.required,
    );
    expect(
      _check(
        c,
        drafts: {'amount': const UiFieldDraft('11')},
      ).issues.single.error,
      UiFieldError.range,
    );
    expect(
      _check(
        c,
        drafts: {'amount': const UiFieldDraft('7', composing: true)},
      ).issues.single.error,
      UiFieldError.composing,
    );
  });
  test(
    'optional null number and current choices are validated without coercion',
    () {
      final c = _surface(
        r'''$n: number? = null
$choice: string = "invalid"
root = Form(children=[amount,choiceField])
amount = NumberField(label="Amount", bind=$n)
choiceField = Select(label="Choice", bind=$choice, options=[{"value":"one","label":"One"}])''',
      );
      expect(_check(c).issues.map((e) => e.error), [UiFieldError.option]);
      c.setInputs({'choice': 'one'}, token: c.token);
      expect(
        _check(c, drafts: {'amount': const UiFieldDraft('')}).valid,
        isTrue,
      );
    },
  );
  test('required checkbox and Unicode scalar text limits are independent', () {
    final c = _surface(r'''$text: string = "😀"
$ok: boolean = false
root = Form(children=[textField,okField])
textField = TextField(label="Text", bind=$text, minLength=2, maxLength=3)
okField = Checkbox(label="Agree", bind=$ok, required=true)''');
    expect(_check(c).issues.map((e) => e.error), [
      UiFieldError.tooShort,
      UiFieldError.required,
    ]);
    c.setInputs({'text': '😀中文', 'ok': true}, token: c.token);
    expect(_check(c).valid, isTrue);
    expect(
      _check(
        c,
        drafts: {'textField': const UiFieldDraft('😀中文四')},
      ).issues.single.error,
      UiFieldError.tooLong,
    );
  });
}
