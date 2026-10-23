import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';

/// Shared catalog-driven guidance for manual evaluation. Registration as an
/// application Skill is a later, separately verified implementation step.
String genUiEvaluationPrompt() =>
    '''You are generating a native interactive UI in a Kelivo assistant reply.
Write a short useful explanation and exactly one top-level fenced kelivo-ui block.
Do not use HTML, JavaScript, kelivo-web, a tool call, or executable code.
The first physical source line must be exactly:
${UiCatalog.header}
Each declaration occupies one physical line. JSON strings escape embedded newlines.
Write root first with forward child references, then states, derived values and nodes.
Writable scalar state: \$name: number|string|boolean (optional ?) = JSON scalar.
Read-only derived value: let name = expression. Node: id = Component(named=value, ...).
All states, derived values and node IDs share ONE namespace; never reuse a state name for its input node.
Use bind=\$name only for inputs; values read \$name or a derived name. root is an explicit node.
children=[nodeA,nodeB] builds a single tree. Each node has one parent. Button.form is a non-structural reference.
Supported expression operators: ! - * / + - < <= > >= == != && || ?: with ordinary precedence and short circuit.
No string concatenation or interpolation, member access, indexing, loops, assignments, callbacks or arbitrary calls.
Only the @functions listed in the catalog are executable. Ask(text=..., context={...}) and Reset() are typed Button action descriptions.
Use @sample(x => expression, start, end, count) for finite curves; count is an integer 2..501, endpoints included, start < end. No nested sampling.
Numeric values are finite doubles. Domain errors in samples remain null gaps, never zeros. Use null only in nullable slots; no implicit numeric string conversion.
Charts consume record arrays; name the x field and the list of y fields. Cartesian charts have <=4 series and <=2000 total points. scatter uses numeric x. pie has one nonnegative y field, <=12 items and a positive total.
Tables use <=1000 records, <=8 columns and a unique stable rowKey field. Columns are {"key":"field","label":"Label","digits":2}; no arbitrary cell expressions.
Choice options are {"value":scalar,"label":"Label"}. Component styling is semantic, never colors, pixels, CSS or arbitrary layout props.
Hidden fields retain their input values but do not take part in current Form required validation.
Provide the requested controls and exact IDs in the task, clear units, synthetic-data labels and Reset/Ask only when requested.
Ask prepares an editable draft; it never sends a message automatically. All ordinary interactions are local.
Catalog signatures, defaults, choices and complete small examples follow. A property is allowed only when listed here:
${UiCatalog.encodeReference()}
''';
