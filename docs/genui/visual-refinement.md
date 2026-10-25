# Visual refinement after the hands-on trial

This records C27. The subsequent full-component audit and current presentation
are documented in [C28 component audit](component-audit.md). In particular, C28
removes the inline height cap at the user's request and keeps pagination in one
row instead of wrapping its controls independently.

The trial exposed oversized view selectors, heavy resting input borders,
square table headers, a card header that did not follow the supplied reference,
and a second vertical gesture target inside long messages. This follow-up uses
the supplied HANDOFF, DESIGN.md and reference PNGs 01/02, 10–13 and 60.

## Resulting behavior

- Surface chrome has a separate subdued Markdown-themed header, rounded outline,
  and 14/16-point mobile/desktop content insets. Field labels and table text have
  distinct, quieter typography through GenUiTheme.
- Inputs use filled rounded fields with a focus/error outline only. Buttons have
  a 36-point painted body; Chart/Data uses compact painted segments. Touch
  regions remain at least 44 points on mobile and 32 on desktop. Radio labels
  that need multiple lines use the existing wrapping choice rows.
- Tables clip headers and horizontally scrolling cells to the same rounded
  frame. Search includes a search icon; page size is a compact selector with a
  dialog. Its route closes when the source disappears. Page size and navigation
  wrap independently in narrow layouts.
- A long inline card never owns a user vertical drag. Its bounded preview keeps
  the fade and Expand action; the expanded route owns full-content scrolling.
  Programmatic caret, accessibility and keyboard reveal remain available for
  fields that intersect the clipping edge.
- Decimal slider and NumberField steps no longer persist binary arithmetic
  tails. Donut totals use decimal presentation without changing validated chart
  geometry. Missing pie values remain missing, and ordinary totals such as
  16000 are not unnecessarily converted to scientific notation.

## Verification

Twelve added regressions cover the real MessageListView scroll path, chart and
body drags, full expanded content, caret/showOnScreen reveal, compact touch and
keyboard controls, decimal steps and totals (including maximum finite values),
null pie legends, multiline radio labels, narrow tables and modal source removal.
The 235 GenUI golden cases were refreshed and checked, including the complete
S1/S6/shell matrix, light/dark, wallpaper, RTL, large text and mobile/desktop.
Independent review returned no remaining findings after the boundary repairs.

Native Android evidence uses dedicated device fee8c1be and a separate
com.psyche.kelivo.genui.visual package, with synthetic local data and the production
message host. A swipe beginning on the chart reached the text after the capped
card; Expand reached the final extra node. The native capture sequence is under
build/genui/trial/android-visual-20261025T042946Z. This is native interaction
verification, not a new performance benchmark or provider evaluation.

The normal lib/main.dart application was updated in the existing iPhone 17 /
iOS 26.5 simulator under psyche.kelivo.genuiacceptance, retaining the user's
provider configuration and chats. Its real budget and line-chart messages were
visually inspected. The simulator automation did not produce a reliable drag,
so native swipe evidence is attributed to Android instead.

Full G and the final simulator build are recorded in the implementation log.
The frozen implementation manifest is build/genui/visual-repair/implementation-manifest.json;
G logs are build/genui/logs/c27-visual-*.log. Local build evidence remains ignored.
No model prompt, protocol/evaluation interpretation, scoring, database schema or
provider configuration changed. No paid model run was invoked. Earlier Windows,
Linux, physical-iPhone, macOS Chinese IME and Android performance exceptions
remain as described in delivery.md; this correction does not turn them into passes.
