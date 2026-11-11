import 'dart:convert';

enum UiTone { info, tip, warning, error, primary }

enum UiBadgeTone { neutral, primary, success, warning, error }

enum UiChartKind { line, area, bar, scatter, pie }

enum UiValueType { number, string, boolean, scalar, array, record, sampleBody }

enum UiSlot { value, binding, children, form, action }

enum UiTextPolicy {
  layout,
  divider,
  text,
  formula,
  metric,
  input,
  form,
  action,
  chart,
  table,
}

final class UiPropertySpec {
  const UiPropertySpec(
    this.type, {
    this.slot = UiSlot.value,
    this.required = false,
    this.nullable = false,
    this.defaultValue,
    this.choices = const [],
    this.min,
    this.max,
    this.integer = false,
  });
  final UiValueType type;
  final UiSlot slot;
  final bool required;
  final bool nullable;
  final Object? defaultValue;
  final List<Object> choices;
  final double? min;
  final double? max;
  final bool integer;

  Map<String, Object?> toJson() => {
    'type': type.name,
    'slot': slot.name,
    if (required) 'required': true,
    if (nullable) 'nullable': true,
    if (defaultValue != null) 'default': defaultValue,
    if (choices.isNotEmpty) 'choices': choices,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    if (integer) 'integer': true,
  };
}

final class UiComponentSpec {
  UiComponentSpec(
    this.name, {
    required Map<String, UiPropertySpec> properties,
    required this.textPolicy,
    required Iterable<String> semanticFields,
    required this.example,
  }) : properties = Map.unmodifiable({
         ...UiCatalog.commonProperties,
         ...properties,
       }),
       semanticFields = List.unmodifiable(semanticFields);
  final String name;
  final Map<String, UiPropertySpec> properties;
  final UiTextPolicy textPolicy;
  final List<String> semanticFields;

  /// A complete, synthetic document, built from a fixed scenario template.
  final String example;

  Map<String, Object?> toJson() => {
    'name': name,
    'properties': {
      for (final key in properties.keys.toList()..sort())
        key: properties[key]!.toJson(),
    },
    'textPolicy': textPolicy.name,
    'semanticFields': semanticFields,
    'example': example,
  };
}

final class UiFunctionSpec {
  const UiFunctionSpec(
    this.name,
    this.parameters,
    this.result, {
    this.optionalParameters = 0,
  });
  final String name;
  final List<UiValueType> parameters;
  final UiValueType result;
  final int optionalParameters;
  int get minimumArguments => parameters.length - optionalParameters;
  int get maximumArguments => parameters.length;
  Map<String, Object?> toJson() => {
    'name': name,
    'parameters': parameters.map((e) => e.name).toList(),
    'result': result.name,
    'optionalParameters': optionalParameters,
  };
}

final class UiActionSpec {
  const UiActionSpec(this.name, this.arguments);
  final String name;
  final Map<String, UiPropertySpec> arguments;
}

/// Single catalog for parsing, validation, projections and generated guidance.
/// Flutter builders are deliberately registered in a separate library.
abstract final class UiCatalog {
  static const version = 'kelivo.native/1';
  static const languageVersion = 1;
  static const header = 'ui 1 catalog "kelivo.native/1"';
  static const commonProperties = {
    'visible': UiPropertySpec(UiValueType.boolean, defaultValue: true),
    'enabled': UiPropertySpec(UiValueType.boolean, defaultValue: true),
  };
  static const _text = UiPropertySpec(UiValueType.string);
  static const _label = UiPropertySpec(UiValueType.string, required: true);
  static const _number = UiPropertySpec(UiValueType.number);
  static const _required = UiPropertySpec(
    UiValueType.boolean,
    defaultValue: false,
  );
  static const _children = UiPropertySpec(
    UiValueType.array,
    slot: UiSlot.children,
    required: true,
  );
  static const _gap = UiPropertySpec(
    UiValueType.string,
    defaultValue: 'medium',
    choices: ['small', 'medium', 'large'],
  );
  static const _tone = UiPropertySpec(
    UiValueType.string,
    defaultValue: 'info',
    choices: ['info', 'tip', 'warning', 'error', 'primary'],
  );
  static const _digits = UiPropertySpec(
    UiValueType.number,
    min: 0,
    max: 10,
    integer: true,
  );
  static const _numericBinding = UiPropertySpec(
    UiValueType.number,
    slot: UiSlot.binding,
    required: true,
  );
  static const _stringBinding = UiPropertySpec(
    UiValueType.string,
    slot: UiSlot.binding,
    required: true,
    nullable: true,
  );
  static const _booleanBinding = UiPropertySpec(
    UiValueType.boolean,
    slot: UiSlot.binding,
    required: true,
  );
  static const _choiceBinding = UiPropertySpec(
    UiValueType.scalar,
    slot: UiSlot.binding,
    required: true,
    nullable: true,
  );
  static const _options = UiPropertySpec(UiValueType.array, required: true);

  static String _example(String declarations) => '$header\n$declarations\n';

  static final Map<String, UiComponentSpec> components = Map.unmodifiable({
    for (final spec in [
      UiComponentSpec(
        'Column',
        properties: {'children': _children, 'gap': _gap},
        textPolicy: UiTextPolicy.layout,
        semanticFields: ['children'],
        example: _example(
          'root = Column(children=[label])\nlabel = Text(text="Example data")',
        ),
      ),
      UiComponentSpec(
        'Row',
        properties: {
          'children': _children,
          'gap': _gap,
          'distribution': const UiPropertySpec(
            UiValueType.string,
            defaultValue: 'equal',
            choices: ['equal', 'fit'],
          ),
        },
        textPolicy: UiTextPolicy.layout,
        semanticFields: ['children'],
        example: _example(
          'root = Row(children=[a,b])\na = Metric(label="Example A", value=2)\nb = Metric(label="Example B", value=3)',
        ),
      ),
      UiComponentSpec(
        'Section',
        properties: {
          'children': _children,
          'title': _label,
          'subtitle': _text,
          'tone': _tone,
        },
        textPolicy: UiTextPolicy.layout,
        semanticFields: ['title', 'subtitle', 'children'],
        example: _example(
          'root = Section(title="Example section", children=[label])\nlabel = Text(text="Example data")',
        ),
      ),
      UiComponentSpec(
        'Divider',
        properties: {'label': _text},
        textPolicy: UiTextPolicy.divider,
        semanticFields: ['label'],
        example: _example('root = Divider(label="Example results")'),
      ),
      UiComponentSpec(
        'Text',
        properties: {
          'text': _label,
          'variant': const UiPropertySpec(
            UiValueType.string,
            defaultValue: 'body',
            choices: ['title', 'body', 'caption', 'mono'],
          ),
        },
        textPolicy: UiTextPolicy.text,
        semanticFields: ['text'],
        example: _example('root = Text(text="Example data", variant="body")'),
      ),
      UiComponentSpec(
        'Markdown',
        properties: {'text': _label},
        textPolicy: UiTextPolicy.text,
        semanticFields: ['text'],
        example: _example(
          'root = Markdown(text="**Example data**: local interaction.")',
        ),
      ),
      UiComponentSpec(
        'Formula',
        properties: {'tex': _label, 'label': _text},
        textPolicy: UiTextPolicy.formula,
        semanticFields: ['label', 'tex'],
        example: _example(
          'root = Formula(tex="y = 2x + 1", label="Example formula")',
        ),
      ),
      UiComponentSpec(
        'Metric',
        properties: {
          'label': _label,
          'value': const UiPropertySpec(
            UiValueType.number,
            required: true,
            nullable: true,
          ),
          'unit': _text,
          'digits': _digits,
          'trend': const UiPropertySpec(UiValueType.number, nullable: true),
        },
        textPolicy: UiTextPolicy.metric,
        semanticFields: ['label', 'value', 'unit', 'trend'],
        example: _example(
          'root = Metric(label="Example distance", value=12.5, unit="km", digits=1)',
        ),
      ),
      UiComponentSpec(
        'Badge',
        properties: {
          'text': _label,
          'tone': const UiPropertySpec(
            UiValueType.string,
            defaultValue: 'neutral',
            choices: ['neutral', 'primary', 'success', 'warning', 'error'],
          ),
        },
        textPolicy: UiTextPolicy.text,
        semanticFields: ['text'],
        example: _example('root = Badge(text="Example data", tone="neutral")'),
      ),
      UiComponentSpec(
        'Callout',
        properties: {'text': _label, 'title': _text, 'tone': _tone},
        textPolicy: UiTextPolicy.text,
        semanticFields: ['title', 'text'],
        example: _example(
          'root = Callout(title="Example", text="Values are synthetic.", tone="info")',
        ),
      ),
      UiComponentSpec(
        'TextField',
        properties: {
          'label': _label,
          'bind': _stringBinding,
          'placeholder': _text,
          'required': _required,
          'multiline': const UiPropertySpec(
            UiValueType.boolean,
            defaultValue: false,
          ),
          'minLength': const UiPropertySpec(
            UiValueType.number,
            min: 0,
            max: 8192,
            integer: true,
          ),
          'maxLength': const UiPropertySpec(
            UiValueType.number,
            min: 1,
            max: 8192,
            integer: true,
            defaultValue: 2000,
          ),
        },
        textPolicy: UiTextPolicy.input,
        semanticFields: ['label', 'bind'],
        example: _example(
          '\$name: string = "Example"\nroot = TextField(label="Example name", bind=\$name, maxLength=80)',
        ),
      ),
      UiComponentSpec(
        'NumberField',
        properties: {
          'label': _label,
          'bind': const UiPropertySpec(
            UiValueType.number,
            slot: UiSlot.binding,
            required: true,
            nullable: true,
          ),
          'unit': _text,
          'min': _number,
          'max': _number,
          'step': const UiPropertySpec(UiValueType.number, defaultValue: 1),
          'required': _required,
        },
        textPolicy: UiTextPolicy.input,
        semanticFields: ['label', 'bind', 'unit'],
        example: _example(
          '\$amount: number = 3\nroot = NumberField(label="Example amount", bind=\$amount, min=0, max=10)',
        ),
      ),
      UiComponentSpec(
        'Slider',
        properties: {
          'label': _label,
          'bind': _numericBinding,
          'min': const UiPropertySpec(UiValueType.number, required: true),
          'max': const UiPropertySpec(UiValueType.number, required: true),
          'step': const UiPropertySpec(UiValueType.number, defaultValue: 1),
          'unit': _text,
          'digits': _digits,
        },
        textPolicy: UiTextPolicy.input,
        semanticFields: ['label', 'bind', 'unit'],
        example: _example(
          '\$slope: number = 2\nroot = Slider(label="Example slope", bind=\$slope, min=-5, max=5, step=0.1)',
        ),
      ),
      UiComponentSpec(
        'Switch',
        properties: {'label': _label, 'bind': _booleanBinding},
        textPolicy: UiTextPolicy.input,
        semanticFields: ['label', 'bind'],
        example: _example(
          '\$on: boolean = true\nroot = Switch(label="Example setting", bind=\$on)',
        ),
      ),
      UiComponentSpec(
        'Checkbox',
        properties: {
          'label': _label,
          'bind': _booleanBinding,
          'required': _required,
        },
        textPolicy: UiTextPolicy.input,
        semanticFields: ['label', 'bind'],
        example: _example(
          '\$accepted: boolean = false\nroot = Checkbox(label="Example confirmation", bind=\$accepted, required=true)',
        ),
      ),
      UiComponentSpec(
        'Select',
        properties: {
          'label': _label,
          'bind': _choiceBinding,
          'options': _options,
          'placeholder': _text,
          'required': _required,
        },
        textPolicy: UiTextPolicy.input,
        semanticFields: ['label', 'bind', 'options'],
        example: _example(
          '\$plan: string = "a"\nroot = Select(label="Example plan", bind=\$plan, options=[{"value":"a","label":"Plan A"},{"value":"b","label":"Plan B"}])',
        ),
      ),
      UiComponentSpec(
        'RadioGroup',
        properties: {
          'label': _label,
          'bind': _choiceBinding,
          'options': _options,
          'required': _required,
        },
        textPolicy: UiTextPolicy.input,
        semanticFields: ['label', 'bind', 'options'],
        example: _example(
          '\$years: number = 20\nroot = RadioGroup(label="Example years", bind=\$years, options=[{"value":10,"label":"10"},{"value":20,"label":"20"}])',
        ),
      ),
      UiComponentSpec(
        'Form',
        properties: {'children': _children, 'title': _text},
        textPolicy: UiTextPolicy.form,
        semanticFields: ['title', 'children'],
        example: _example(
          '\$name: string = "Example"\nroot = Form(children=[nameField,ask])\nnameField = TextField(label="Example name", bind=\$name, required=true)\nask = Button(label="Explain", form=root, action=Ask(text="Explain this example.", context={"name":\$name}))',
        ),
      ),
      UiComponentSpec(
        'Button',
        properties: {
          'label': _label,
          'form': const UiPropertySpec(UiValueType.record, slot: UiSlot.form),
          'action': const UiPropertySpec(
            UiValueType.record,
            slot: UiSlot.action,
            required: true,
          ),
          'variant': const UiPropertySpec(
            UiValueType.string,
            defaultValue: 'tonal',
            choices: ['primary', 'tonal', 'plain'],
          ),
        },
        textPolicy: UiTextPolicy.action,
        semanticFields: ['label'],
        example: _example(
          'root = Button(label="Reset example", action=Reset())',
        ),
      ),
      UiComponentSpec(
        'DataTable',
        properties: {
          'data': const UiPropertySpec(UiValueType.array, required: true),
          'rowKey': _label,
          'columns': const UiPropertySpec(UiValueType.array, required: true),
          'sortable': const UiPropertySpec(
            UiValueType.boolean,
            defaultValue: true,
          ),
          'filterable': const UiPropertySpec(
            UiValueType.boolean,
            defaultValue: true,
          ),
          'pageSize': const UiPropertySpec(
            UiValueType.number,
            integer: true,
            defaultValue: 10,
            choices: [10, 20],
          ),
        },
        textPolicy: UiTextPolicy.table,
        semanticFields: ['columns', 'data'],
        example: _example(
          'root = DataTable(data=[{"id":"a","price":2},{"id":"b","price":3}], rowKey="id", columns=[{"key":"id","label":"Example item"},{"key":"price","label":"Example price"}])',
        ),
      ),
      UiComponentSpec(
        'Chart',
        properties: {
          'kind': const UiPropertySpec(
            UiValueType.string,
            required: true,
            choices: ['line', 'area', 'bar', 'scatter', 'pie'],
          ),
          'data': const UiPropertySpec(UiValueType.array, required: true),
          'x': _label,
          'y': const UiPropertySpec(UiValueType.array, required: true),
          'xLabel': _text,
          'yLabel': _text,
          'title': _text,
          'unit': _text,
          'donut': const UiPropertySpec(
            UiValueType.boolean,
            defaultValue: false,
          ),
        },
        textPolicy: UiTextPolicy.chart,
        semanticFields: [
          'title',
          'kind',
          'xLabel',
          'yLabel',
          'unit',
          'x',
          'y',
          'data',
        ],
        example: _example(
          'root = Chart(kind="line", data=[{"x":0,"y":1},{"x":1,"y":3}], x="x", y=["y"], title="Example data")',
        ),
      ),
    ])
      spec.name: spec,
  });

  static const functions = <String, UiFunctionSpec>{
    'abs': UiFunctionSpec('abs', [UiValueType.number], UiValueType.number),
    'min': UiFunctionSpec('min', [
      UiValueType.number,
      UiValueType.number,
    ], UiValueType.number),
    'max': UiFunctionSpec('max', [
      UiValueType.number,
      UiValueType.number,
    ], UiValueType.number),
    'round': UiFunctionSpec(
      'round',
      [UiValueType.number, UiValueType.number],
      UiValueType.number,
      optionalParameters: 1,
    ),
    'clamp': UiFunctionSpec('clamp', [
      UiValueType.number,
      UiValueType.number,
      UiValueType.number,
    ], UiValueType.number),
    'pow': UiFunctionSpec('pow', [
      UiValueType.number,
      UiValueType.number,
    ], UiValueType.number),
    'sqrt': UiFunctionSpec('sqrt', [UiValueType.number], UiValueType.number),
    'sin': UiFunctionSpec('sin', [UiValueType.number], UiValueType.number),
    'cos': UiFunctionSpec('cos', [UiValueType.number], UiValueType.number),
    'formatNumber': UiFunctionSpec(
      'formatNumber',
      [UiValueType.number, UiValueType.number],
      UiValueType.string,
      optionalParameters: 1,
    ),
    'sample': UiFunctionSpec('sample', [
      UiValueType.sampleBody,
      UiValueType.number,
      UiValueType.number,
      UiValueType.number,
    ], UiValueType.array),
  };

  static const actions = <String, UiActionSpec>{
    'Ask': UiActionSpec('Ask', {
      'text': UiPropertySpec(UiValueType.string, required: true),
      'context': UiPropertySpec(UiValueType.record, required: true),
    }),
    'Reset': UiActionSpec('Reset', {}),
  };

  static String encodeReference() =>
      const JsonEncoder.withIndent('  ').convert({
        'languageVersion': languageVersion,
        'catalog': version,
        'components': [
          for (final name in components.keys.toList()..sort())
            components[name]!.toJson(),
        ],
        'functions': [
          for (final name in functions.keys.toList()..sort())
            functions[name]!.toJson(),
        ],
        'actions': {
          for (final name in actions.keys.toList()..sort())
            name: {
              for (final entry in actions[name]!.arguments.entries)
                entry.key: entry.value.toJson(),
            },
        },
      });
}
