# Kelivo UI protocol

Use an ordinary assistant reply with a useful conclusion and one top-level
fenced block labelled `kelivo-ui`. The first physical source line is exactly:
ui 1 catalog "kelivo.native/1"

Each declaration occupies one physical line. Escape newlines inside JSON strings.
Declare root early with forward child references, then complete those children.
- State: `$quantity: number = 3`; scalar types number/string/boolean, optional `?`
  for nullable state. Names are ASCII letters/underscore followed by letters,
  digits/underscore. States, derived values and nodes share ONE unique namespace.
- Derived: `let total = $quantity * 12`. Read states as `$name`, derived values
  as bare names. Inputs require `bind=$state`; derived values are read-only.
- Node: `root = Column(children=[quantityInput,result])`. The root and every child
  form one tree with one parent per node. Button.form is a non-structural Form ID.
- Expressions: literals, arrays/records, parentheses, `! - * / + - < <= > >= == !=
  && || ?:` with ordinary precedence/short circuit; only catalog `@functions`.
  No member/index access, string concatenation, loops, assignments or callbacks.
- Actions: `Ask(text="Explain this example", context={"quantity":$quantity})`
  or `Reset()`, only in Button.action. Ask freezes one current state into a
  visible removable draft chip; the user reviews and sends it. Reset is local.

Numbers are finite doubles, with no implicit string conversion. Null is accepted
only in nullable slots and displayed as a missing value, never silently zero.
Choose semantic variants/tones and layout groups; the model cannot specify colors,
pixels, CSS or executable code. Markdown/Formula are display-only and do not activate
nested interfaces. Streaming interfaces remain read-only until host completion.

Limits: 262144 UTF-8 bytes/source, 131072
bytes/line, 256 nodes, 64 inputs,
512 declarations, tree depth 16,
expression depth 32. Prefer a much smaller answer.
At most 3 native blocks per message; extras show source.
