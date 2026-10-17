# markstream

Internal Markdown syntax package for Kelivo. `lib/src/core` contains the
immutable AST and source-coordinate types. Core code uses Dart libraries only;
Flutter functionality belongs outside that directory.

Use `package:markstream/markstream_core.dart` from code that must stay independent
of Flutter. Every source interval refers to UTF-16 offsets in the original,
unmodified input. AST child lists are immutable snapshots.

Run `flutter pub get`, `dart analyze --fatal-infos`, and `flutter test` from this
directory. The import guard checks every core source and the core barrel;
root-package tests do not discover this package's tests.

## Parsing profiles

```dart
const parser = MarkdownParser(options: ParserOptions.llm());
final document = parser.parse('Hello **world**');
final options = const ParserOptions.gfm().copyWith(autolinks: false);
```

The default LLM profile displays single newlines, enables standalone task
and radio items, and disables setext headings and indented code. Underscore
emphasis, plus list markers, ordered parenthesis markers, bare URLs and HTML
entities are enabled. Bracketed numbers such as `[1]` remain ordinary text;
applications register their own citation syntax with `InlineSyntax`.

`commonMark()` and `gfm()` select stricter syntax defaults. The native HTML
subset is sanitized in all profiles, and strikethrough uses double tildes.
Profiles select behavior; they do not assert full specification compliance.

Each syntax family can be configured independently through `copyWith`.
`tablePipesOptional: false` requires outer pipes on the header, delimiter and
body rows. `maxInlineMathLength` defaults to 512 UTF-16 code units and applies
to text and table cells. Disabling checkboxes does not disable radio items.

`StreamingOptions` describes the closure policy for incomplete input: blocks
are optimistic by default, while unfinished inline syntax remains literal.

## Streaming documents

```dart
final stream = IncrementalDocument();
stream.update('First paragraph.\n\n**in progress', streaming: true);
final document = stream.update('First paragraph.\n\n**complete**');
```

Updates accept the cumulative source. Completed leading blocks retain their
identity; changes to an open container reparse that container. Changing a
reference definition invalidates earlier links. Replacing or truncating the
source reparses it, and an identical update returns the existing document.

The default policy projects an unfinished pipe-table header without inventing
source characters. Optional optimistic inline closure covers emphasis, strike,
code spans and mathematical expressions; links still need a destination. Only
the active inline tail receives this closure. `closed` and `provisional` flags
distinguish projected nodes, and every source span remains inside the input.

`optimisticBlocks: false` displays the source of unfinished fenced code, math,
details, directives and HTML blocks until they finish. Ending the stream uses
ordinary Markdown parsing. Document reference metadata is immutable and uses
the same original-source coordinates as the visible syntax tree.
