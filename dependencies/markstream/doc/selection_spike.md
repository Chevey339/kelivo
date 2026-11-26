# Inline selection decision

Inline code uses a baseline-aligned WidgetSpan capsule. The capsule's
Text.rich joins the consumer's SelectionArea through buildSelectableText, so
selection can start and end at character boundaries inside the code. Plain-text
copy returns the selected characters without Markdown backticks.

The enclosing paragraph must use buildSelectableText. Its source-ordered
selection delegate keeps the ordinary text fragments and inline widgets in one
logical order, including wrapped paragraphs and RTL text. A bare Text.rich can
order multiline widget fragments by geometry instead of source order.
StableSelectionContainer avoids replaying selection edges against a partially
merged child list when streaming widgets register or unregister.

The package tests cover:

- Forward and reverse mouse dragging across text, code and formula atoms on
  Linux, macOS and Windows platform variants.
- Android long press and end-handle dragging across inline widgets and
  within an inline code capsule.
- Desktop substring dragging and Shift+Arrow extension inside a capsule, with
  exact source offsets and Markdown copy.
- Cmd/Ctrl+C through Flutter shortcuts, with the platform clipboard mocked.
- Narrow 180-pixel layouts at text scales 1.0 and 1.3, with long code wrapping
  inside its available width and remaining fully copyable.
- Source offsets, RTL order, paragraph selection, accessibility spacing,
  inline registration changes during an active drag and selected-widget removal.

Run `flutter test test/flutter/inline_code_capsule_test.dart test/flutter/selectable_rich_text_test.dart`.
These are Flutter 3.47.6 widget tests with synthesized pointer input. Physical
Android handle behavior and native clipboard integration remain manual QA.
The library creates no SelectionArea; the application owns the selection menu.

`mixed_selection_test.dart` also exercises one document containing a paragraph,
inline code, a formula, a table with empty edge cells and split code chunks.
Desktop dragging in both directions and Android end-handle expansion retain
TSV cell separators, code indentation and line breaks. The application imports
these same code/table/paragraph delegates from the package.
