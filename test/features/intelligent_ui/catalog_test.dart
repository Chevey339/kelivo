import 'dart:convert';

import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog is complete and excludes removed capabilities', () {
    expect(UiCatalog.components.keys.toSet(), {
      'Column',
      'Row',
      'Section',
      'Divider',
      'Text',
      'Markdown',
      'Formula',
      'Metric',
      'Badge',
      'Callout',
      'TextField',
      'NumberField',
      'Slider',
      'Switch',
      'Checkbox',
      'Select',
      'RadioGroup',
      'Form',
      'Button',
      'DataTable',
      'Chart',
    });
    expect(UiCatalog.functions.keys.toSet(), {
      'abs',
      'min',
      'max',
      'round',
      'clamp',
      'pow',
      'sqrt',
      'sin',
      'cos',
      'formatNumber',
      'sample',
    });
    expect(UiCatalog.actions.keys.toSet(), {'Ask', 'Reset'});
    for (final spec in UiCatalog.components.values) {
      expect(spec.semanticFields, isNotEmpty, reason: spec.name);
      for (final field in spec.semanticFields) {
        expect(
          spec.properties.containsKey(field),
          isTrue,
          reason: '${spec.name}.$field',
        );
      }
      expect(spec.example, startsWith('${UiCatalog.header}\n'));
      expect(
        spec.example.split('\n').where((line) => line.startsWith('root = ')),
        hasLength(1),
      );
      expect(spec.example, contains(spec.name));
      final declarations = RegExp(
        r'^(?:\$|let )?([A-Za-z_][A-Za-z_0-9]*)(?::[^=]+)?\s*=',
        multiLine: true,
      ).allMatches(spec.example).map((m) => m.group(1)!).toList();
      expect(
        declarations.toSet(),
        hasLength(declarations.length),
        reason: '${spec.name}: symbols share one namespace',
      );
      expect(utf8.encode(spec.example).length, lessThan(UiBudgets.sourceBytes));
      for (final forbidden in [
        'color',
        'width',
        'height',
        'onClick',
        'script',
        'url',
      ]) {
        expect(
          spec.properties.containsKey(forbidden),
          isFalse,
          reason: '${spec.name}.$forbidden',
        );
      }
    }
  });

  test('reference generation is stable, sorted and self-contained', () {
    final encoded = UiCatalog.encodeReference();
    expect(UiCatalog.encodeReference(), encoded);
    final reference = jsonDecode(encoded) as Map<String, dynamic>;
    expect(reference['catalog'], 'kelivo.native/1');
    final components = reference['components'] as List<dynamic>;
    final names = components
        .map((dynamic value) => (value as Map)['name'] as String)
        .toList();
    expect(names, [...names]..sort());
    expect((reference['functions'] as List).length, 11);
    expect((reference['actions'] as Map).keys, ['Ask', 'Reset']);
    for (final component in components.cast<Map<String, dynamic>>()) {
      final keys = (component['properties'] as Map).keys
          .cast<String>()
          .toList();
      expect(keys, [...keys]..sort());
    }
  });

  test('semantic enums and catalog choices cannot drift', () {
    expect(
      UiCatalog.components['Section']!.properties['tone']!.choices,
      UiTone.values.map((e) => e.name),
    );
    expect(
      UiCatalog.components['Callout']!.properties['tone']!.choices,
      UiTone.values.map((e) => e.name),
    );
    expect(
      UiCatalog.components['Badge']!.properties['tone']!.choices,
      UiBadgeTone.values.map((e) => e.name),
    );
    expect(
      UiCatalog.components['Chart']!.properties['kind']!.choices,
      UiChartKind.values.map((e) => e.name),
    );
  });

  test(
    'form association is separate from structural children and bindings',
    () {
      expect(
        UiCatalog.components['Form']!.properties['children']!.slot,
        UiSlot.children,
      );
      expect(
        UiCatalog.components['Button']!.properties['form']!.slot,
        UiSlot.form,
      );
      expect(
        UiCatalog.components['Button']!.properties['action']!.slot,
        UiSlot.action,
      );
      expect(
        UiCatalog.components['Slider']!.properties['bind']!.slot,
        UiSlot.binding,
      );
      expect(
        UiCatalog.components['Slider']!.properties['bind']!.type,
        UiValueType.number,
      );
      expect(const UiInputBinding('amount').path, '/inputs/amount');
      expect(const UiFormRef('root').toJson(), {'form': 'root'});
      expect(UiChildRefs(['field', 'submit']).toJson(), {
        'children': ['field', 'submit'],
      });
    },
  );

  test(
    'IR collections and catalog cannot be mutated through caller aliases',
    () {
      final values = <UiExpression>[const UiLiteral(1)];
      final array = UiArray(values);
      values.add(const UiLiteral(2));
      expect(array.items, hasLength(1));
      expect(() => array.items.add(const UiLiteral(3)), throwsUnsupportedError);
      final fields = <String, UiExpression>{'price': const UiLiteral(2)};
      final object = UiObject(fields);
      fields.clear();
      expect(object.fields, contains('price'));
      final arguments = <String, UiArgument>{
        'children': UiChildRefs(['field', 'submit']),
      };
      final node = UiNodeDeclaration(
        'root',
        const UiSourceLocation(2),
        component: 'Form',
        arguments: arguments,
      );
      arguments.clear();
      expect(node.arguments, contains('children'));
      expect(() => node.arguments.clear(), throwsUnsupportedError);
      expect(() => UiCatalog.components.clear(), throwsUnsupportedError);
      expect(
        () => UiCatalog.components['Chart']!.properties.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test('typed expression and action IR has a JSON-safe representation', () {
    final expression = UiSample(
      'x',
      const UiBinary('*', UiRead('slope', state: true), UiRead('x')),
      const UiLiteral(0),
      const UiLiteral(10),
      const UiLiteral(21),
    );
    final action = UiAsk(
      text: const UiLiteral('Explain this example.'),
      context: UiObject({'points': expression}),
    );
    final node = UiNodeDeclaration(
      'ask',
      const UiSourceLocation(8),
      component: 'Button',
      arguments: {'form': const UiFormRef('controls'), 'action': action},
    );
    final decoded = jsonDecode(jsonEncode(node.toJson())) as Map;
    expect(decoded['line'], 8);
    expect((decoded['arguments'] as Map)['form'], {'form': 'controls'});
    expect(jsonEncode(decoded), contains('sample'));
    expect(const UiReset().toJson(), {'action': 'Reset'});
  });
}
