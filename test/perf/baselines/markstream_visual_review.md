# Markstream migration visual review

C41, 2026-10-18. Parent revision `1dcb110a`, plus the C41 visual repairs.
All 48 synthetic fixtures were compared at 720/390 px, light/dark, and font
scales 1.0/1.3: 384 before/current pairs. The long paragraph was inspected in
contiguous tiles including its final line. Real conversations and physical
Android validation remain deferred at the user's request.

The local comparison is `test_goldens/out/report/index.html`; its PNGs and
manifest remain ignored. The review used the PNGs directly. The C04 baseline
was preserved. Current captures use the app wrapper, adapters and native
renderer, with export capture enabled and viewport clipping disabled.

## Findings repaired before acceptance

- C40: preserve caller CJK font fallback, including inline and fenced code;
  restore the table's rounded outer border.
- C41: scale inline code, formulas and citation text once. Flutter scales the
  WidgetSpan itself, so its child text must not apply the same scale again.
  A geometry test checks 1.3x global width, and selection regressions still run.
- C41: a whitespace-only escaped `\[ \]` stays visible punctuation instead of
  becoming an empty display formula. Every prefix is checked against full parse
  in both streaming and completed modes.
- The fixture's newly decoded emoji needs an emoji font in the test VM. Current
  captures explicitly load macOS Apple Color Emoji (configurable by
  `MARKSTREAM_EMOJI_FONT`); the baseline displayed the numeric entity as text.
  Latin/CJK/code font files remain the same. No system font is vendored.

## Disposition of the complete matrix

Each row covers both widths, themes and scales. Height changes alone are not
pixel equivalence. The new renderer uses explicit logical theme spacing and
native blocks, rather than nested Text/WidgetSpan blocks which could apply
inherited scaling more than once. Body size/height and heading sizes remain
15.5/1.55 and 24/20/18/16/15/14 respectively. Block spacing remains 15.5 x 1.15
logical pixels; text scales through MediaQuery. Headings now honor the caller's
font family. These explain the denser large-font output without clipping text.

| Fixtures | Reviewed behavior / accepted difference |
| --- | --- |
| 01, 47 | Heading hierarchy, numbered heading text, inherited caller font and one font scaling pass; no accidental ordered-list conversion. |
| 02 | Single line breaks retained; paragraph separation uses explicit block spacing. CJK glyphs restored. |
| 03–05 | Underscore emphasis is now recognized; intraword underscores remain literal; delimiter runs and escapes follow the parser. |
| 06 | Matched backtick-run code spans; Chinese code fallback; code capsules remain selectable. |
| 07–13 | Dollars/HTML/headings stay literal within fences; tilde and open fences work; indentation and blank lines retained; long lines wrap without clipping. Export hides action buttons. |
| 14–17 | Plus bullets and parenthesized ordered markers work; correct nested indentation; tight/loose lists share one font scale without the old compensation. |
| 18–19 | Checkbox/radio geometry, selected strike-through per theme, no duplicate bullet before task marker; labels remain readable. |
| 20–21 | Nested quote bars, heading/list/code in quotes; nested blocks scale once. |
| 22 | Three rules remain visible; native rule padding and block spacing replace inline newline geometry. |
| 23–24 | Table header/body colors, rounded border, left/center/right alignment, CJK and scaled text. Export omits compact toolbar. |
| 25 | Literal unescaped pipe in a code span is still a GFM cell delimiter. The malformed four-cell row is bounded by its three-column header; escaped pipes stay in their cell. No claim of old-parser equivalence. |
| 26 | Tables without outer pipes now render as tables. |
| 27–28 | Provisional headers/unfinished rows render optimistically; missing cells remain empty. |
| 29 | All columns fit exported captures; the interactive wide-table viewport is separately tested for horizontal scrolling and selection. |
| 30–32 | Inline/block fractions, powers, roots and Chinese formulas; centered blocks and single-scale inline atoms, with original LaTeX selection. |
| 33–34 | Display math crosses blank paragraphs and renders incomplete blocks optimistically. |
| 35 | Currency remains literal; escaped dollars and math/code boundaries are preserved. |
| 36 | Explicit, angle-bracket and bare URL/email links; no underline, no double-scaled link text. |
| 37 | Plain `[1]` stays plain text; explicit citation forms retain their app chips and source selection. |
| 38–39 | Closed/open details chrome; collapsed content is unmounted and excluded from selection; summary and visible body retained. |
| 40 | Entity decoding and hard break; whitespace-only escaped brackets remain literal after the repair; emoji font explicitly loaded. |
| 41 | Double-tilde strike-through, single tilde literal, nested strong text. |
| 42–43 | HTML shells retain text, details/basic flow works, complete page remains code. Full subset styling is the next C43 implementation, not an accepted final appearance here. |
| 44 | Parsed alert/directive contents and labels are retained. Default card chrome is C42, not an accepted final appearance here. |
| 45 | Full long paragraphs, CJK and code capsules through the final line; no blank bands or missing tail. |
| 46 | Arabic/Hebrew order, emphasis, inline code and math use the ordinary bidi paragraph path. |
| 48 | Transparent embedded data image keeps its space; surrounding paragraphs remain visible. |

## Interaction evidence and limits

An isolated native macOS profile entry point launched the existing Playground
with an in-memory business database and mock preferences. It did not use the
production application database. Direct mouse dragging selected prose, inline
code, citations, tasks and table cells in one range. The selection pane showed
TSV rows (`Name\tValue`, `Alpha\t42`, `Beta\t3.14`) and structural Markdown.
Right-click displayed Copy and Select All. Menu Select All included the entire
code block with indentation/blank lines, delimited LaTeX, and the collapsed
Details summary without its hidden body.

The native automation's keyboard/paste actions did not visibly update this
window, so this run does **not** establish native Cmd+A/Cmd+C behavior. Keyboard
and mobile handle behavior have widget-test evidence. Physical mobile manual
QA remains open; a narrow desktop window is not mobile-device evidence.

C39 records macOS profile streaming timing and C40 records two viewport
animation pixel checks with zero blank pixels. Export tests verify complete
long code/table capture and bottom pixels. These are distinct automated checks,
not claims of manual mobile QA or physical Android performance.

Final capture report: 384 compared, 376 changed, 8 equal; 332 size changes.

## C42–C43 extension review

C42 changes only fixture 44's eight card captures; all eight were inspected for
light/dark, 390/720 widths and 1.0/1.3 scaling. The directive/alert card title
and body remain separate; locale changes were verified in widget tests.

C43 compared with C42: 372 equal, 12 changed. All 12 changed captures were
inspected. Fixture 42 gains the requested inline styles, keyboard capsule and
raised/lowered scripts; narrow wrapping changes follow those styled widths.
The four desktop fixture 43 differences are the formerly plain `inside` text
now honoring its `<strong>` wrapper. No other fixture changes.

An additional eight captures exercise the complete native HTML subset at the
same width/theme/scale matrix: headings, color spans, mark/kbd/code, sub/sup,
center/quote, nested ordered/unordered lists, aligned table cells, preformatted
code and rules. All were inspected. The first visual pass caught scripts that
had reduced size but an unchanged baseline; a baseline-reporting render proxy
and geometric assertions repaired that before the final captures and gates.
Table copy actions, empty cells/rows, partial list/style selection, image-gallery
ordering and cached HTML links have focused automated regression coverage.

Final C43 gates: root 7,968 passed / one existing skip; package 265 passed;
golden suite 389 passed (384 captures plus harness checks); analyzers clean.
A preceding full run had a two-second attachment-backfill timeout while other
preflight work ran. Its 72-test file and the subsequent serialized full suite
both passed without changes to that unrelated path. Physical-device and native
keyboard limits above remain open; this review does not extend their evidence.
