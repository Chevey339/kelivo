import 'dart:convert';

import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';

/// Generated Skill assets and manual evaluation share these catalog-derived
/// references. The fixed scenarios are authored examples, not inferred schemas.
abstract final class UiGuidance {
  static const capabilitySummary =
      'Kelivo supports native interactive calculators, forms, charts and tables '
      'in assistant replies. Input changes are local; Ask prepares an editable '
      'draft without sending. Use the visualize skill when interaction helps; '
      'read its protocol and relevant reference first. Keep a useful conclusion '
      'outside the interface. Plain text is enough for simple facts.';

  static const main = '''---
name: visualize
description: Create a native interactive calculator, conditional form, chart or data table when local input changes help answer the user. Also handles repairs to an existing Kelivo interface.
---

# Interactive answers

1. Choose a small native interface when the user benefits from changing inputs,
   comparing values or exploring supplied data. Use prose for a single fact or
   explanation without useful interaction. State a useful conclusion outside
   the interface.
2. Read `references/protocol.md`. Read `references/content.md` for layout and
   text; `references/inputs.md` for controls, validation and actions;
   `references/data.md` for charts/tables; `references/functions.md` when computing.
   Read `references/examples.md` for three complete, validated patterns.
3. Emit one top-level `kelivo-ui` fence using the advertised header, complete
   single-line declarations and an explicit root. Keep all requested controls
   reachable from root and derive results from their bindings. Styling belongs
   to the app's theme; select only catalog semantics.
4. Check unique names, allowed properties, required fields, units, mappings and
   every referenced ID before closing the fence. Test the reasoning for changed
   inputs, not just initial values. Hidden fields retain values but do not block
   form validation. Ask creates an editable draft; it never sends automatically.
   Check every number, sample count and trend in the surrounding prose against
   those same expressions and records. Use the full sample grid, including
   fractional coordinates and missing values. A trend must agree with every
   relevant row; distinguish user-set parameters from calculated results.
   Prefer a short explanation of the controls and data mapping over additional
   numerical interpretations the user did not request.
5. For an answer that displays a dataset or calculated result, include a visible
   provenance sentence in the prose or a Text/Callout. Label supplied synthetic
   rows, invented numbers and mathematical demonstrations as "Synthetic example
   data" in the user's language. Keep this label when copying supplied values
   unchanged. For real user data, identify its supplied source instead. Finish
   only after this qualification appears in the visible answer, outside code.

For repairs, preserve the user's intended behavior and correct the supplied
bounded diagnostics/source. Return a complete corrected interface with a short
explanation. The repair draft is ordinary editable chat text, not a tool call.

Only when supported native components cannot express a self-contained interaction,
read `references/web.md`. Use native charts, calculators, forms and tables whenever
possible. Copy/read-aloud behavior is described in `references/semantics.md`.
''';

  static String get protocol =>
      '''# Kelivo UI protocol

Use an ordinary assistant reply with a useful conclusion and one top-level
fenced block labelled `kelivo-ui`. The first physical source line is exactly:
${UiCatalog.header}

Each declaration occupies one physical line. Escape newlines inside JSON strings.
Declare root early with forward child references, then complete those children.
- State: `\$quantity: number = 3`; scalar types number/string/boolean, optional `?`
  for nullable state. Names are ASCII letters/underscore followed by letters,
  digits/underscore. States, derived values and nodes share ONE unique namespace.
- Derived: `let total = \$quantity * 12`. Read states as `\$name`, derived values
  as bare names. Inputs require `bind=\$state`; derived values are read-only.
- Node: `root = Column(children=[quantityInput,result])`. The root and every child
  form one tree with one parent per node. Button.form is a non-structural Form ID.
- Expressions: literals, arrays/records, parentheses, `! - * / + - < <= > >= == !=
  && || ?:` with ordinary precedence/short circuit; only catalog `@functions`.
  No member/index access, string concatenation, loops, assignments or callbacks.
- Actions: `Ask(text="Explain this example", context={"quantity":\$quantity})`
  or `Reset()`, only in Button.action. Ask freezes one current state into a
  visible removable draft chip; the user reviews and sends it. Reset is local.

Numbers are finite doubles, with no implicit string conversion. Null is accepted
only in nullable slots and displayed as a missing value, never silently zero.
Choose semantic variants/tones and layout groups; the model cannot specify colors,
pixels, CSS or executable code. Markdown/Formula are display-only and do not activate
nested interfaces. Streaming interfaces remain read-only until host completion.

Limits: ${UiBudgets.sourceBytes} UTF-8 bytes/source, ${UiBudgets.declarationBytes}
bytes/line, ${UiBudgets.components} nodes, ${UiBudgets.inputs} inputs,
${UiBudgets.declarations} declarations, tree depth ${UiBudgets.componentDepth},
expression depth ${UiBudgets.expressionDepth}. Prefer a much smaller answer.
At most ${UiBudgets.blocksPerMessage} native blocks per message; extras show source.
''';

  static const groups = <String, List<String>>{
    'content': [
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
    ],
    'inputs': [
      'TextField',
      'NumberField',
      'Slider',
      'Switch',
      'Checkbox',
      'Select',
      'RadioGroup',
      'Form',
      'Button',
    ],
    'data': ['DataTable', 'Chart'],
  };

  // Usage guidance is authored; signatures/defaults/constraints/semantic fields
  // below come from UiCatalog. Tests require coverage of every catalog entry.
  static const uses = <String, String>{
    'Column': 'Stack a short sequence. Avoid long app-like screens.',
    'Row':
        'Compare compact peers; wraps on narrow/large-text layouts. Avoid fixed-width assumptions.',
    'Section':
        'Group related content with a title. Avoid deeply nested framed sections.',
    'Divider': 'Separate groups. Avoid using it to encode data.',
    'Text': 'Plain readable content. Avoid inventing typography properties.',
    'Markdown':
        'Short formatted explanatory text. Avoid nested UI or interactive HTML.',
    'Formula':
        'Display TeX with an optional spoken label. Computation belongs in expressions.',
    'Metric': 'Show a labelled number and unit. Avoid using it for paragraphs.',
    'Badge': 'Short semantic status. Avoid conveying meaning by color alone.',
    'Callout': 'Explain a caveat or result. Avoid repeated decorative notices.',
    'TextField':
        'Edit a string with validation. Avoid treating a string as numeric input.',
    'NumberField':
        'Edit a finite number, optionally nullable. Avoid precision-critical accounting.',
    'Slider':
        'Explore a bounded numeric range. Avoid unbounded or precise text entry.',
    'Switch':
        'Toggle one boolean immediately. Avoid using it for mutually exclusive choices.',
    'Checkbox':
        'Boolean confirmation; required=true requires checked. Avoid unrelated choice lists.',
    'Select': 'Choose a scalar option. Avoid unlabelled option values.',
    'RadioGroup':
        'Expose a small set of exclusive scalar choices. Avoid oversized lists.',
    'Form': 'Group validation for associated buttons. Avoid nesting forms.',
    'Button':
        'Explicit Ask or Reset only. Avoid implying tool execution or automatic sending.',
    'Chart':
        'Compare supplied data or sampled functions. Avoid fabricated factual series.',
    'DataTable':
        'Inspect supplied records with local sorting/filtering. Avoid database-like editing.',
  };

  static String _type(UiPropertySpec property) {
    final type = switch (property.slot) {
      UiSlot.binding => '\$state<${property.type.name}>',
      UiSlot.children => '[nodeId]',
      UiSlot.form => 'FormId',
      UiSlot.action => 'Ask|Reset',
      UiSlot.value => property.type.name,
    };
    return '$type${property.nullable ? '?' : ''}';
  }

  static String _property(String name, UiPropertySpec property) {
    final modifiers = <String>[
      if (property.defaultValue != null)
        'default=${jsonEncode(property.defaultValue)}',
      if (property.choices.isNotEmpty) 'oneOf=${jsonEncode(property.choices)}',
      if (property.min != null) 'min=${property.min}',
      if (property.max != null) 'max=${property.max}',
      if (property.integer) 'integer',
    ];
    return '$name${property.required ? '*' : ''}:${_type(property)}'
        '${modifiers.isEmpty ? '' : ' (${modifiers.join('; ')})'}';
  }

  static String componentReference(String group) {
    final names = [...groups[group]!]..sort();
    final out = StringBuffer('# $group — ${UiCatalog.version}\n\n')
      ..writeln(
        '`*` means required. Omitted optional values are absent unless a default is shown.',
      )
      ..writeln(
        'All nodes also accept: ${UiCatalog.commonProperties.entries.map((e) => _property(e.key, e.value)).join(', ')}.\n',
      );
    for (final name in names) {
      final spec = UiCatalog.components[name]!;
      out
        ..writeln('## ${spec.name}')
        ..writeln(uses[name])
        ..writeln(
          '`${spec.name}(${(spec.properties.keys.where((k) => !UiCatalog.commonProperties.containsKey(k)).toList()..sort()).map((k) => _property(k, spec.properties[k]!)).join(', ')})`\n',
        );
    }
    if (group == 'inputs') {
      out.writeln(
        '''Options are records {"value":scalar,"label":"Readable label"}; values are unique
and match the bound state type. Form validates only currently visible descendants.
`Button(form=formId, action=Ask(...))` validates that Form before creating a draft;
include the Button in the root tree as well. Every control needs its own label.
Number min must not exceed max; Slider needs min < max. NumberField and Slider
both require step > 0.
TextField minLength must not exceed maxLength. Hidden input values are retained.
''',
      );
    }
    if (group == 'data') {
      out.writeln(
        '''Chart data is a record array; x names a nonempty field, y lists unique nonempty
field names. X values must be consistently strings or finite numbers; Y values
are finite numbers or null. For nonempty data, every y field must exist in at
least one record. Cartesian
charts allow ${UiBudgets.chartSeries} series and ${UiBudgets.chartPoints} total
points; scatter requires numeric x. Pie uses one nonnegative y field, a positive
total and at most ${UiBudgets.pieItems} items. Missing values remain gaps, never
zero; supply labels/units and follow the Skill's visible-provenance check. The app provides legends,
tooltips, data-table alternatives and accessible summaries.
DataTable accepts at most ${UiBudgets.tableRows} records and
1..${UiBudgets.tableColumns} columns, with a unique stable non-null scalar rowKey in each row.
All fields, including undisplayed fields, must be finite numbers, strings, booleans
or null. Remove or flatten nested records/arrays before passing data to the table.
Columns: {"key":"field","label":"Readable label","digits":2}; digits is optional,
integer 0..10. Column keys are unique/nonempty, labels nonblank, and each selected
field exists in at least one record when data is nonempty.
No cell expression or remote query. Sorting always places null values last.
''',
      );
    }
    return out.toString();
  }

  static const functionUses = <String, String>{
    'abs': 'Magnitude of a finite number.',
    'min': 'Smaller of two finite numbers.',
    'max': 'Larger of two finite numbers.',
    'round': 'Decimal rounding; optional digits defaults to 0, integer 0..10.',
    'clamp': 'Bound value between lower and upper; lower <= upper.',
    'pow': 'Finite real-valued power; invalid domains are errors.',
    'sqrt': 'Square root of a nonnegative number.',
    'sin': 'Sine in radians.',
    'cos': 'Cosine in radians.',
    'formatNumber':
        'String display; optional digits defaults to 0, integer 0..10. No numeric coercion.',
    'sample':
        'Evaluate a pure scalar expression over an inclusive finite interval.',
  };

  static String get functions {
    final out = StringBuffer('# Pure functions and actions\n\n');
    for (final name in UiCatalog.functions.keys.toList()..sort()) {
      final spec = UiCatalog.functions[name]!;
      final params = [
        for (var i = 0; i < spec.parameters.length; i++)
          '${spec.parameters[i].name}${i >= spec.minimumArguments ? ' optional' : ''}',
      ];
      out.writeln(
        '- `@${spec.name}(${params.join(', ')}) -> ${spec.result.name}`: ${functionUses[name]}',
      );
    }
    out.writeln('''
`@sample(x => expression, start, end, count)` returns {"x":number,"y":number?}
records. start < end; count is an integer ${UiBudgets.sampleMin}..${UiBudgets.sampleMax}.
Endpoints are included. The body can read x, states and derived scalars; nested
sampling is prohibited. Domain errors produce null gaps, not zeros. This is
finite sampling, not symbolic solving or a general programming runtime.
''');
    for (final name in UiCatalog.actions.keys.toList()..sort()) {
      final spec = UiCatalog.actions[name]!;
      out.writeln(
        '`${spec.name}(${spec.arguments.entries.map((e) => _property(e.key, e.value)).join(', ')})`',
      );
    }
    out.writeln(
      'Ask prepares a frozen editable draft and is never an automatic send. Reset restores source defaults locally.',
    );
    return out.toString();
  }

  /// Every emitted property is checked against the actual catalog signature.
  static String _node(String id, String component, Map<String, String> values) {
    final spec = UiCatalog.components[component]!;
    if (values.keys.any((key) => !spec.properties.containsKey(key)) ||
        spec.properties.entries.any(
          (e) => e.value.required && !values.containsKey(e.key),
        )) {
      throw StateError('Example no longer matches $component');
    }
    return '$id = ${spec.name}(${values.entries.map((e) => '${e.key}=${e.value}').join(', ')})';
  }

  static Map<String, String> get examples => {
    'calculator': [
      UiCatalog.header,
      _node('root', 'Column', {'children': '[quantityInput,result,reset]'}),
      r'$quantity: number = 3',
      _node('quantityInput', 'Slider', {
        'label': '"Example quantity"',
        'bind': r'$quantity',
        'min': '0',
        'max': '10',
      }),
      _node('result', 'Metric', {
        'label': '"Example total"',
        'value': r'$quantity * 12',
        'unit': '"USD"',
      }),
      _node('reset', 'Button', {
        'label': '"Reset locally"',
        'action': 'Reset()',
      }),
    ].join('\n'),
    'curve': [
      UiCatalog.header,
      _node('root', 'Column', {'children': '[slopeInput,chart,table]'}),
      r'$slope: number = 2',
      r'let points = @sample(x => $slope * x + 1, -2, 2, 21)',
      _node('slopeInput', 'Slider', {
        'label': '"Example slope"',
        'bind': r'$slope',
        'min': '-5',
        'max': '5',
        'step': '0.1',
      }),
      _node('chart', 'Chart', {
        'kind': '"line"',
        'data': 'points',
        'x': '"x"',
        'y': '["y"]',
        'title': '"Synthetic function"',
      }),
      _node('table', 'DataTable', {
        'data': 'points',
        'rowKey': '"x"',
        'columns': '[{"key":"x","label":"x"},{"key":"y","label":"y"}]',
      }),
    ].join('\n'),
    'conditional-form': [
      UiCatalog.header,
      _node('root', 'Column', {'children': '[form,result,ask]'}),
      r'$useOffset: boolean = true',
      r'$offset: number = 1',
      r'let total = 10 + ($useOffset ? $offset : 0)',
      _node('form', 'Form', {
        'children': '[toggle,offsetInput]',
        'title': '"Example parameters"',
      }),
      _node('toggle', 'Switch', {
        'label': '"Use offset"',
        'bind': r'$useOffset',
      }),
      _node('offsetInput', 'NumberField', {
        'label': '"Offset"',
        'bind': r'$offset',
        'visible': r'$useOffset',
        'required': 'true',
      }),
      _node('result', 'Metric', {
        'label': '"Example result"',
        'value': 'total',
        'unit': '"u"',
      }),
      _node('ask', 'Button', {
        'label': '"Prepare explanation draft"',
        'form': 'form',
        'action':
            r'Ask(text="Explain these example parameters.", context={"useOffset":$useOffset,"offset":$offset,"result":total})',
      }),
    ].join('\n'),
  };

  static String get fewShots =>
      '# Complete examples\n\nAll values below are synthetic example data. Each reply includes prose outside its fence.\n\n${examples.entries.map((e) => '## ${e.key}\n\nChange the controls to explore this local example.\n\n```kelivo-ui\n${e.value}\n```\n').join('\n')}';

  static String get semantics {
    final out = StringBuffer('''# Semantic text coverage

Copy, read-aloud and export use readable values from the current accepted state,
not DSL source. Search uses source defaults; later input changes do not update
the search index or make changed results searchable. Hidden nodes are omitted; unavailable nodes contribute a
bounded explanation. Text/code/formula display does not execute nested UI.
Inputs expose labels/values/units; Metric includes its value/unit/trend; action labels and interface chrome are omitted from parameter/result text. Charts describe series, ranges and
gaps with a data alternative. Tables describe their columns and visible page.
Large results are bounded with an omission marker. An explicitly attached chip
freezes at click time and is not updated by later input changes.

''');
    for (final name in UiCatalog.components.keys.toList()..sort()) {
      final spec = UiCatalog.components[name]!;
      out.writeln(
        '- ${spec.name}: policy=${spec.textPolicy.name}; fields=${spec.semanticFields.join(', ')}.',
      );
    }
    return out.toString();
  }

  static String get web =>
      '''# Self-contained Web preview

Use native components for supported charts, forms, tables and calculators. Only
choose Web for a useful interaction the native catalog cannot express.
A separate top-level `kelivo-web` fence starts with exactly these JSON fields:
{"version":1,"title":"Example animation","summary":"A self-contained synthetic demonstration."}
The next line begins the complete HTML document. Scripts/styles are inline;
images/fonts use data URLs. No CDN, network, file access, host bridge or tools.
The app creates the WebView only after generation completes and the user clicks
Open. At most ${UiBudgets.webBlocksPerMessage} Web blocks per message, independently
of native blocks. Closing discards changes; reopening starts over. Web state is
not attached to chat, sent to a model or persisted by this feature.

Previews currently run on Android, iOS and macOS. Windows activation is deferred;
Windows and Linux provide source/copy/HTML export. The parent CSP and opaque-origin
sandbox restrict ordinary network/navigation/storage/capabilities. They do not
provide OS-level offline isolation; WebRTC is an explicitly accepted residual
risk. Never claim the preview is absolutely offline or request credentials.
''';

  static Map<String, String> generateAssets() => {
    'SKILL.md': main,
    'references/protocol.md': protocol,
    for (final group in groups.keys)
      'references/$group.md': componentReference(group),
    'references/functions.md': functions,
    'references/examples.md': fewShots,
    'references/semantics.md': semantics,
    'references/web.md': web,
  };

  static String get nativeEvaluationPrompt =>
      '''$main
$protocol
${groups.keys.map(componentReference).join('\n')}
$functions
$fewShots
For this native evaluation task, use exactly one kelivo-ui fence and the exact
requested state/node IDs. Preserve requested units, field mapping and behavior.
''';
}
