import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_form_validation.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_interaction_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';

const _body = r'''$name: string = "Ready"
$n: number? = 2
$show: boolean = true
root = Form(children=[nameField,amount,ask,reset])
nameField = TextField(label="Name", bind=$name, required=true)
amount = NumberField(label="Amount", bind=$n, min=0, max=10, visible=$show)
ask = Button(label="Explain", form=root, action=Ask(text="Explain", context={"name":$name,"n":$n}))
reset = Button(label="Reset", action=Reset())''';
UiInteractionController _interaction([String body = _body]) {
  final c = UiSurfaceController(
    owner: const UiSurfaceOwner(revisionId: 'interaction', surfaceKey: '0:0'),
  );
  c.updateSource(
    '${UiCatalog.header}\n$body',
    closed: true,
    generation: UiGenerationStatus.complete,
  );
  final interaction = UiInteractionController(c);
  addTearDown(() {
    interaction.dispose();
    c.dispose();
  });
  return interaction;
}

void main() {
  test(
    'Attach rejects incomplete numbers and composition instead of old values',
    () {
      final i = _interaction(), c = i.surface;
      i.editText('amount', const UiFieldDraft('-'), token: c.token);
      final invalid = i.captureForAttach(token: c.token);
      expect(invalid.block, UiActionBlock.form);
      expect(invalid.form!.firstField, 'amount');
      expect(invalid.attachment, isNull);
      expect(c.captureRead().inputs['n'], 2);
      i.setValue('amount', 2, token: c.token);
      i.editText(
        'nameField',
        const UiFieldDraft('中文', composing: true),
        token: c.token,
      );
      final composing = i.captureForAttach(token: c.token);
      expect(composing.form!.issues.single.error, UiFieldError.composing);
      expect(composing.attachment, isNull);
      expect(c.captureRead().inputs['name'], 'Ready');
    },
  );
  test(
    'Attach settles nullable blanks and finished drafts into one frozen read',
    () {
      final i = _interaction(), c = i.surface;
      i.editText('amount', const UiFieldDraft(''), token: c.token);
      i.editText(
        'nameField',
        const UiFieldDraft('中文', composing: true),
        token: c.token,
      );
      i.endComposition('nameField', i.draft('nameField')!, token: c.token);
      final attached = i.captureForAttach(token: c.token).attachment!;
      expect(attached.read.inputs['n'], isNull);
      expect(attached.read.inputs['name'], '中文');
      expect(attached.read.state, same(attached.snapshot.state));
      i.setValue('amount', 7, token: c.token);
      expect(attached.read.inputs['n'], isNull);
      expect(c.captureRead().inputs['n'], 7);
    },
  );
  test(
    'Attach can describe untouched required defaults and ignores hidden drafts',
    () {
      final i = _interaction(_body.replaceFirst('"Ready"', '""')),
          c = i.surface;
      expect(i.captureForAttach(token: c.token).attachment, isNotNull);
      i.editText('amount', const UiFieldDraft('-'), token: c.token);
      c.setInputs({'show': false}, token: c.token);
      expect(i.captureForAttach(token: c.token).attachment, isNotNull);
      c.setInputs({'show': true}, token: c.token);
      expect(i.captureForAttach(token: c.token).form!.firstField, 'amount');
    },
  );
  test(
    'a new alias edit owns the only draft for its binding, regardless of hidden editors',
    () {
      final fields = List.generate(66, (index) => 'f$index');
      final i = _interaction(
        '\$name: string = "old"\n\$stage: number = 0\nroot = Form(children=[${fields.join(',')},ask])\n${fields.indexed.map((entry) => '${entry.$2} = TextField(label="Alias ${entry.$1}",bind=\$name,visible=\$stage == ${entry.$1} || \$stage == 99)').join('\n')}\nask = Button(label="Ask",form=root,action=Ask(text="Explain",context={"name":\$name}))',
      );
      final c = i.surface;
      for (var index = 0; index < fields.length; index++) {
        c.setInputs({'stage': index}, token: c.token);
        i.editText(
          fields[index],
          UiFieldDraft('value$index', composing: true),
          token: c.token,
        );
        final pending = i.draft(fields[index])!;
        c.setInputs({'stage': -1}, token: c.token);
        i.endComposition(fields[index], pending, token: c.token);
        expect(i.drafts.keys, [fields[index]]);
      }
      expect(c.captureRead().inputs['name'], 'old');
      c.setInputs({'stage': 99}, token: c.token);
      var writes = 0;
      c.listenState(() => writes++);
      final result = i.activate('ask', token: c.token);
      expect(result.intent!.context['name'], 'value65');
      expect(writes, 1);
    },
  );
  test(
    'editor disposal only finishes its own draft and never commits an active field',
    () {
      final i = _interaction();
      final token = i.surface.token;
      i.editText(
        'nameField',
        const UiFieldDraft('中', composing: true),
        token: token,
      );
      final previous = i.draft('nameField')!;
      i.endComposition('nameField', previous, token: token);
      expect(i.surface.captureRead().inputs['name'], 'Ready');
      expect(i.draft('nameField')!.composing, isFalse);
      expect(i.activate('ask', token: token).intent!.context['name'], '中');
      i.editText(
        'nameField',
        const UiFieldDraft('新', composing: true),
        token: token,
      );
      i.endComposition('nameField', previous, token: token);
      expect(i.draft('nameField')!.composing, isTrue);
      expect(i.activate('ask', token: token).block, UiActionBlock.form);
    },
  );
  test(
    'disabled IME completion changes only draft metadata until an active submit',
    () {
      final i = _interaction(
        r'''$name: string = "Before"
$active: boolean = true
root = Form(children=[field,ask])
field = TextField(label="Name",bind=$name,enabled=$active)
ask = Button(label="Ask",form=root,action=Ask(text="Explain",context={"name":$name}))''',
      );
      final c = i.surface;
      i.editText(
        'field',
        const UiFieldDraft('中', composing: true),
        token: c.token,
      );
      c.setInputs({'active': false}, token: c.token);
      var writes = 0;
      c.listenState(() => writes++);
      i.editText(
        'field',
        const UiFieldDraft('中'),
        token: c.token,
        finish: true,
      );
      expect(i.draft('field')!.composing, isFalse);
      expect(writes, 0);
      expect(c.captureRead().inputs['name'], 'Before');
      expect(
        i.activate('ask', token: c.token).intent!.context['name'],
        'Before',
      );
      c.setInputs({'active': true}, token: c.token);
      expect(i.activate('ask', token: c.token).intent!.context['name'], '中');
      expect(c.captureRead().inputs['name'], '中');
    },
  );
  test('same-value draft cleanup refreshes the submitted Form summary', () {
    final i = _interaction();
    i.editText('amount', const UiFieldDraft('-'), token: i.surface.token);
    i.activate('ask', token: i.surface.token);
    var formChanges = 0;
    i.listen('root', () => formChanges++);
    i.setValue('amount', 2, token: i.surface.token);
    expect(i.checkForm('root').valid, isTrue);
    expect(formChanges, greaterThan(0));
  });

  test(
    'an explicit same-value edit supersedes another control blank draft',
    () {
      final i = _interaction(
        r'''$n: number? = 2
root = Form(children=[a,b,ask])
a = NumberField(label="A",bind=$n)
b = NumberField(label="B",bind=$n)
ask = Button(label="Ask",form=root,action=Ask(text="Explain",context={"n":$n}))''',
      );
      i.editText('a', const UiFieldDraft(''), token: i.surface.token);
      i.editText('b', const UiFieldDraft('2.00'), token: i.surface.token);
      expect(i.draft('a'), isNull);
      expect(i.draft('b')!.text, '2.00');
      expect(i.activate('ask', token: i.surface.token).intent!.context['n'], 2);
      i.editText('a', const UiFieldDraft(''), token: i.surface.token);
      expect(
        i.activate('ask', token: i.surface.token).intent!.context['n'],
        isNull,
      );
      expect(i.draft('b'), isNull);
      expect(i.draft('a')!.text, '');
    },
  );
  test('same-value stepper commits also supersede stale text drafts', () {
    final i = _interaction();
    i.editText('amount', const UiFieldDraft('-'), token: i.surface.token);
    expect(
      i.setValue('amount', 2, token: i.surface.token),
      UiMutationResult.unchanged,
    );
    expect(i.draft('amount'), isNull);
  });

  test(
    'a Form does not hide a pending draft from an external Ask dependency',
    () {
      final i = _interaction(
        r'''$name: string = "Ready"
$n: number? = 2
root = Column(children=[form,amount,ask])
form = Form(children=[nameField])
nameField = TextField(label="Name",bind=$name,required=true)
amount = NumberField(label="Amount",bind=$n)
ask = Button(label="Ask",form=form,action=Ask(text="Explain",context={"n":$n}))''',
      );
      i.editText('amount', const UiFieldDraft('-'), token: i.surface.token);
      expect(
        i.activate('ask', token: i.surface.token).block,
        UiActionBlock.form,
      );
    },
  );
  test(
    'nullable blank commits reach newly visible drafts before freezing context',
    () {
      final i = _interaction(
        r'''$a: number? = null
$b: number? = 7
root = Form(children=[aInput,bInput,ask])
aInput = NumberField(label="A",bind=$a)
bInput = NumberField(label="B",bind=$b,visible=$a == null)
ask = Button(label="Ask",form=root,action=Ask(text="Explain",context={"a":$a,"b":$b}))''',
      );
      i.editText('bInput', const UiFieldDraft(''), token: i.surface.token);
      i.editText('aInput', const UiFieldDraft('2'), token: i.surface.token);
      i.editText('aInput', const UiFieldDraft(''), token: i.surface.token);
      final intent = i.activate('ask', token: i.surface.token).intent!;
      expect(intent.context, {'a': null, 'b': null});
      expect(intent.read.inputs, {'a': null, 'b': null});
    },
  );
  test(
    'an external Ask cannot submit a Form disabled by committing its draft',
    () {
      final i = _interaction(
        r'''$n: number? = 2
root = Column(children=[form,ask])
form = Form(children=[amount],enabled=$n != null)
amount = NumberField(label="N",bind=$n)
ask = Button(label="Ask",form=form,action=Ask(text="Explain",context={"n":$n}))''',
      );
      i.editText('amount', const UiFieldDraft(''), token: i.surface.token);
      expect(
        i.activate('ask', token: i.surface.token).block,
        UiActionBlock.disabled,
      );
    },
  );
  test(
    'malformed choices become local unavailable content without throwing',
    () {
      for (final options in [
        '[1]',
        '[{"label":"One"}]',
        '[{"value":1,"label":"One"}]',
        '[{"value":"one","label":"One"},{"value":"one","label":"Duplicate"}]',
      ]) {
        final i = _interaction(
          r'''$choice: string = "one"
root = Form(children=[choiceField,ask])
choiceField = Select(label="Choice",bind=$choice,options=''' +
              options +
              r''')
ask = Button(label="Ask",form=root,action=Ask(text="Explain",context={"choice":$choice}))''',
        );
        expect(i.surface.nodes['choiceField']!.valid, isFalse, reason: options);
        expect(
          i.activate('ask', token: i.surface.token).form!.unavailable,
          contains('choiceField'),
        );
      }
    },
  );
  test('discrete value updates cannot bypass the declared numeric range', () {
    final i = _interaction();
    expect(
      i.setValue('amount', 11, token: i.surface.token),
      UiMutationResult.invalid,
    );
    expect(i.surface.captureRead().inputs['n'], 2);
    expect(
      i.setValue('amount', 7, token: i.surface.token),
      UiMutationResult.accepted,
    );
    expect(i.surface.captureRead().inputs['n'], 7);
  });

  test(
    'number draft preserves previous value and blocks stale-context Ask',
    () {
      final i = _interaction();
      final c = i.surface;
      i.editText('amount', const UiFieldDraft('-'), token: c.token);
      expect(c.captureRead().inputs['n'], 2);
      expect(i.draft('amount')!.text, '-');
      final result = i.activate('ask', token: c.token);
      expect(result.block, UiActionBlock.form);
      expect(result.form!.firstField, 'amount');
      expect(i.issue('amount')!.error, UiFieldError.number);
      i.editText('amount', const UiFieldDraft('3.00'), token: c.token);
      final intent = i.activate('ask', token: c.token).intent!;
      expect(intent.context['n'], 3);
      expect(i.draft('amount')!.text, '3.00');
      expect(intent.snapshot.state.inputs['n'], 3);
    },
  );
  test(
    'Ask finishes nullable blank draft before capturing one frozen batch',
    () {
      final i = _interaction();
      final c = i.surface;
      i.editText('amount', const UiFieldDraft(''), token: c.token);
      expect(c.captureRead().inputs['n'], 2);
      final intent = i.activate('ask', token: c.token).intent!;
      expect(intent.context['n'], isNull);
      expect(intent.read.inputs['n'], isNull);
      expect(intent.snapshot.state.inputs['n'], isNull);
      i.editText('amount', const UiFieldDraft('5'), token: c.token);
      expect(intent.context['n'], isNull);
      expect(intent.read.inputs['n'], isNull);
      expect(c.captureRead().inputs['n'], 5);
      expect(() => intent.context['n'] = 9, throwsUnsupportedError);
    },
  );
  test(
    'IME draft does not publish values, validate red, submit or allow late restore',
    () {
      final i = _interaction();
      final c = i.surface;
      final pendingRestore = c.restoreToken;
      final saved = c.captureSnapshot();
      i.editText(
        'nameField',
        const UiFieldDraft('中', composing: true),
        token: c.token,
      );
      expect(c.captureRead().inputs['name'], 'Ready');
      expect(
        i.activate('ask', token: c.token).form!.issues.single.error,
        UiFieldError.composing,
      );
      expect(i.issue('nameField'), isNull);
      expect(c.restore(saved, token: pendingRestore), isFalse);
      i.editText('nameField', const UiFieldDraft('中文'), token: c.token);
      expect(i.activate('ask', token: c.token).intent!.context['name'], '中文');
    },
  );
  test(
    'Reset clears transient invalid input even when committed state is already default',
    () {
      final i = _interaction();
      final c = i.surface;
      var writes = 0;
      c.listenState(() => writes++);
      i.editText('amount', const UiFieldDraft('-'), token: c.token);
      i.activate('ask', token: c.token);
      expect(i.submitted('root'), isTrue);
      expect(c.reset(token: c.token), UiMutationResult.unchanged);
      expect(i.draft('amount'), isNull);
      expect(i.issue('amount'), isNull);
      expect(i.submitted('root'), isFalse);
      expect(writes, 0);
    },
  );
  test('visible form constraints do not discard hidden drafts or values', () {
    final i = _interaction();
    final c = i.surface;
    i.editText('amount', const UiFieldDraft('11'), token: c.token);
    expect(
      i.activate('ask', token: c.token).form!.issues.single.error,
      UiFieldError.range,
    );
    c.setInputs({'show': false}, token: c.token);
    expect(i.activate('ask', token: c.token).intent!.context['n'], 2);
    expect(i.draft('amount')!.text, '11');
    c.setInputs({'show': true}, token: c.token);
    expect(i.activate('ask', token: c.token).block, UiActionBlock.form);
  });
  test(
    'another control of the same state supersedes its old textual draft',
    () {
      final i = _interaction();
      final c = i.surface;
      i.editText('amount', const UiFieldDraft('-'), token: c.token);
      c.setInputs({'n': 7}, token: c.token);
      expect(i.draft('amount'), isNull);
      expect(i.activate('ask', token: c.token).intent!.context['n'], 7);
    },
  );
  test('blank commit revalidates newly visible required fields', () {
    final i = _interaction(
      r'''$n: number? = 2
$name: string = ""
root = Form(children=[amount,nameField,ask])
amount = NumberField(label="Amount", bind=$n)
nameField = TextField(label="Name", bind=$name, required=true, visible=$n == null)
ask = Button(label="Explain", form=root, action=Ask(text="Explain", context={"n":$n,"name":$name}))''',
    );
    i.editText('amount', const UiFieldDraft(''), token: i.surface.token);
    final result = i.activate('ask', token: i.surface.token);
    expect(result.block, UiActionBlock.form);
    expect(result.form!.firstField, 'nameField');
    expect(i.surface.captureRead().inputs['n'], isNull);
  });
  test(
    'Ask without Form still refuses a relevant composing or incomplete draft',
    () {
      final i = _interaction(_body.replaceAll('form=root, ', ''));
      final c = i.surface;
      i.editText('amount', const UiFieldDraft('1.'), token: c.token);
      expect(i.activate('ask', token: c.token).block, UiActionBlock.form);
      i.editText('amount', const UiFieldDraft('4'), token: c.token);
      expect(i.activate('ask', token: c.token).intent!.context['n'], 4);
    },
  );
  test('source epochs clear old drafts and reject captured callbacks', () {
    final i = _interaction();
    final c = i.surface;
    final old = c.token;
    i.editText('amount', const UiFieldDraft('-'), token: old);
    c.updateSource(
      '${UiCatalog.header}\n${_body.replaceFirst('= 2', '= 5')}',
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    expect(i.draft('amount'), isNull);
    expect(
      i.editText('amount', const UiFieldDraft('3'), token: old),
      UiMutationResult.stale,
    );
    expect(i.activate('ask', token: old).block, UiActionBlock.stale);
    expect(c.captureRead().inputs['n'], 5);
  });
  test('streaming controls reject all local mutations and actions', () {
    final i = _interaction();
    final c = i.surface;
    c.updateSource(
      c.parsed.source,
      closed: true,
      generation: UiGenerationStatus.generating,
    );
    expect(
      i.editText('amount', const UiFieldDraft('3'), token: c.token),
      UiMutationResult.readOnly,
    );
    expect(i.activate('ask', token: c.token).block, UiActionBlock.readOnly);
    expect(i.activate('reset', token: c.token).block, UiActionBlock.readOnly);
    expect(i.draft('amount'), isNull);
  });
}
