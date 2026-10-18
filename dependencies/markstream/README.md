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

## Non-rendering structure scans

`MarkdownStructure(source)` uses the same block grammar as rendering, including
unfinished streaming fences, math and containers. `codeBlocks` exposes code in
source order; `protects(offset)` identifies blank lines inside protected blocks.
`lines` retains each original line and its UTF-16 offsets, and identifies code
opening, content and closing lines for attachment extraction.

`removeCode(source)` removes fenced and closed inline code for speech while
preserving surrounding source and line endings. Its inline-code scan is
line-local: unmatched backticks cannot pair across separate speech lines.
Unfinished fenced code suppresses its remaining body.

The LLM profile recognizes Unicode LS/PS line separators through
`unicodeLineBreaks`; CommonMark and GFM leave that option off. The parser,
incremental document and structure scans share this policy.

## Serialization and selection offsets

`toPlainText(document)` produces structured clipboard text, including TSV for
tables and markers for lists and tasks. `toMarkdown(document)` writes canonical
Markdown; `toHtml(document)` emits portable HTML with active tags, unsafe URL
schemes and unsupported style properties removed. Complete HTML documents are
exported as escaped code. `tableToCsv(table)` uses CRLF rows and CSV quoting.

`TextIndex.fromDocument(document)` indexes canonical selectable content. Its
offsets deliberately exclude generated TSV separators, list markers and block
spacing. Code display omits one structural final newline. Original entities,
pipe escapes and normalized line endings keep their source ranges.

Use `TextIndex.fromSegments(...)` for a rendered projection: hidden details
content, resolved citation labels and inserted soft-wrap characters can differ
from the complete AST. Generated glyphs have empty source spans. Segment order
must follow document selection order. Clipboard string lengths are not valid
selection offsets.


## Specification instrument

`flutter test test/core/spec` compares the pinned CommonMark 0.31.2 examples
and the four GFM 0.29 extension sections against `toHtml`. Exact output
percentages, failing IDs, and complete differences are saved under
`build/reports/`. The tests fail on crashes and invalid source spans, not on
conformance percentages. `test/core/spec/known_deviations.txt` distinguishes
native HTML policy from remaining parser and serializer gaps. Fixture sources,
hashes and licenses are recorded in `THIRD_PARTY_NOTICES.md`.


## Inline widget selection

Use `buildSelectableText(Text.rich(...))` for paragraphs containing inline
widgets. `InlineCodeCapsule` renders a baseline-aligned `WidgetSpan` child and
copies its code text as an atomic selection unit. `SelectableSpanAdapter`
provides the same source-text bridge for formulas or application citation chips.
Wrap changing groups in `StableSelectionContainer` and supply one outer
`SelectionArea` in the application. The package does not create a selection
menu or selection owner. See `doc/selection_spike.md` for validation boundaries.

## Theme tokens

`MarkstreamTheme.fromColorScheme` supplies the body, headings, links, code,
quotes, list markers, tasks, tables, rules, images, math and details tokens.
Applications can provide a base font style, monospace family, CJK letter spacing
and platform-adjusted weights. Link overrides inherit the enclosing font size.
Text scaling remains in Flutter's inherited `TextScaler`.

Nested token groups support `copyWith`. Themes compare by value, including
heading styles, so reconstructing equivalent settings does not invalidate
cached document prefixes. Heading lists are immutable snapshots. Fill alpha
constants and the monochrome code-border adjustment follow the existing app
palette; applications can override individual surfaces in the token groups.

## Extension and renderer contracts

`MarkstreamExtensions` takes immutable snapshots of syntax lists and builder
maps. Code builders dispatch by the first, case-insensitive fence language;
directive and named-inline builders dispatch by name. These specific builders
take precedence over `NodeBuilderRegistry` entries keyed by node runtime type.
An unregistered node remains available to the built-in renderer.

`BlockSyntax` classifies an already-scanned leaf block after inline parsing.
It must preserve that block's source boundary and keep child spans inside it.
Structural multiline containers use the built-in directive or fence grammar.
Syntax implementations should remain stable for a document session.
`InlineSyntax` retains its mapped-text offsets and non-consuming-match guard.

`CodeHighlighter` returns a synchronous or asynchronous `TextSpan` whose plain
text exactly matches its input. `MathRenderer` builds the visual formula while
the library owns LaTeX selection. `ImageBuilder` and `LinkHandler` leave source
resolution, navigation and image viewing to the application. Table/code extra
actions similarly leave saving and sharing to the application; a table action
receives a PNG-capture callback. Extensions share the consumer's selection area.


### Directives and alerts

`:::note`, `:::tip`, `:::warning`, `:::danger` containers and leaf directives
render as cards. GitHub `NOTE`, `TIP`, `IMPORTANT`, `WARNING` and `CAUTION`
alerts use the same renderer. `MarkstreamLabels` localizes default titles;
`title="..."` overrides the chrome title. An explicit `[label]` stays selectable.
Unknown directive names retain their children without a card.

Register a named builder to override a default or add an app-specific card:

```dart
final extensions = MarkstreamExtensions(directiveBuilders: {
  'answer': (context, node, rendering) => MarkstreamDirectiveCard(
    kind: 'note',
    title: 'Answer',
    theme: rendering.theme,
    child: Column(children: [
      for (final child in node.children)
        rendering.buildBlock(child as BlockNode),
    ]),
  ),
});
```

Keep this registration object stable across streaming updates. Reuse
`rendering.buildBlock` so source selection and app adapters remain connected.

### Native HTML subset

HTML fragments use native text and the existing link, image, code, table and
details adapters. Supported inline styling includes `b`/`strong`, `i`/`em`, `u`,
`s`/`del`, `mark`, `font[color]`, `code`, `kbd`, `sub`, `sup`, `a`, `img` and `br`.
`span[style]` accepts bounded color/background-color, font-weight, font-style,
font-size (px/em/percent), and text-decoration declarations. Other CSS is ignored.
Colors accept named colors, hex, and numeric rgb/rgba. Image dimensions accept
positive finite values up to 4096; source resolution belongs to `ImageBuilder`.

Block fragments support paragraphs, headings, quotes, lists (including ordered
start numbers), rules, alignment, details, preformatted code and rectangular
tables. Rowspan/colspan layout and arbitrary browser CSS are not implemented.
Tables reuse pagination, CSV/Markdown actions and TSV selection. Source-aware
selection retains the original HTML structure, including empty table cells,
partial inline styles and adjusted ordered-list starts. Unknown wrappers retain
their text; active elements are discarded and active URL schemes are rejected.
Full HTML documents continue through the application's HTML preview extension.

### Source range highlights

`MarkstreamView.highlightRanges` and Kelivo's wrapper accept half-open UTF-16
`SourceSpan` intervals in the original Markdown. `highlightColor` overrides the
default translucent theme-primary paint. Pass a new list for a changed search or
TTS range. Overlapping/adjacent intervals merge; empty and out-of-document ranges
have no visible effect. Source changes keep the supplied absolute offsets, so
callers must update them when their search/TTS result changes.

Text is split only for paint. Entity/escape fragments retain their original
source mapping, surrogate pairs stay intact, and formulas, images and inline
code are marked as whole atoms. Fenced/indented code ranges map through original
text fragments and retain syntax colors and virtualized chunk offsets. The
same atomic rule applies to a custom inline node containing embedded widgets,
whose selectable text can be longer than its rendered placeholder. The
range-only path reuses the parsed document; cached prefix paint is invalidated.
Selections, plain/Markdown/HTML serialization and link gestures stay unchanged.
