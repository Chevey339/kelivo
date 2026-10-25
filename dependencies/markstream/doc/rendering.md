# Retained text rendering

`BlockList` retains an identity forest with fixed-depth branches. Give it
immutable snapshots whose unchanged objects form a prefix and whose changed
objects form a suffix. Change `signature` when rendering inputs change. Items
stay mounted for selection and interactive state; viewport clipping limits
paint and semantics traversal, including when ancestors move behind cached
repaint boundaries. Nested viewports share one observer per applicable scope.

`cullToViewport: false` disables clipping for the entire nested block/text tree,
so image exports can paint offscreen content. The application decides when to
use that option; the package does not depend on an app-specific capture scope.

`StreamingText` retains complete visual-line chunks for long styled text and
rebuilds its active tail. Small paragraphs use Flutter's native paragraph path
at 512 streaming / 2048 completed characters. Embedded widgets, bidirectional
text, special accessibility spacing and other contextual paragraph settings
also keep native paragraph layout. Repaint boundaries retain unchanged glyphs.

The port preserves the existing viewport invalidation and visual-line rules.
Widget tests cover cached paint during ancestor animation, nested scrollports,
semantic clipping, export propagation, branch growth, prefix replacement and
pixel equality with ordinary Text rendering. These primitives alone do not
establish the final complete-renderer performance targets.

## AST view

`MarkstreamView` accepts either cumulative `source` or a `document` snapshot.
Source updates use `IncrementalDocument`; caller-provided snapshots can also
replace arbitrary blocks. Prefix widgets retain their identity through append
and stream completion. Reference definitions have no visible layout slot.

The view owns link recognizer lifetimes and disposes removed links. Extensions
and equivalent theme values retain cached prefixes. Images, links and visual
math use the injected interfaces; formulas and inline code join the surrounding
selection through source adapters. Wide inline math scales its painted baseline
as well as its geometry.

The basic builders render paragraphs, headings, quotes, lists, tasks, radio
items and rules. Unsupported block types remain readable through their plain
text projection. Consumers supply the SelectionArea and menu. The package does
not import app settings or launch URLs itself.

## Rich blocks

Code blocks use the injected highlighter, rejecting changed plain text and
ignoring stale asynchronous results. Stream-time work is capped at 12,000
characters / 300 lines. More than 1,000 lines uses a 420 px viewport of 200-line
chunks. The code selection delegate reports logical source offsets, so select
all and dragging across the complete scrolled block include unmounted lines
and chunk-boundary newlines. Partial selection still follows native geometry.

`CodeBlockOptions` controls wrapping, highlighting and initial folding. Explicit
folding choices survive append and completion. An optional app-owned bounded
`CodeExpansionState` retains them across remounts using the established
language/16-character-prefix key. `MarkstreamCodeContent` is also available for
diagram source panes. The copy button copies complete raw code; selection copies
only the visible collapsed prefix or the selected logical range.

Tables paginate at 40 rows, then 100 more; an active streaming table shows at
most 30 rows. Selection uses TSV, while toolbar actions copy complete Markdown
or CSV. `TableActionContext.capturePng` temporarily renders all rows with opaque
fill and unclipped text, restores pagination on success/failure, and rejects
invalid ratios or images beyond 64 million pixels / 32,767 px per edge. Image
encoding resources are disposed. `exporting` renders every table row and hides
its toolbar/pager; it also disables view-level viewport culling.

Display math scrolls horizontally and exposes LaTeX through its source adapter.
Details retain manual folding and unmount hidden bodies from selection. Full
HTML documents enter the `html` code-builder path, allowing the app to add its
preview action. Native inline HTML remains in the normal text builder.

`MarkstreamLabels`, `actionButtonBuilder`, `codeExtraActions` and
`tableExtraActions` let the app supply localization, icons, save/share dialogs
and platform clipboard actions. Toolbar widgets are excluded from selection.
The package still owns no SelectionArea, platform files, URL launcher or app
settings.

## Document selection and Markdown copy

The caller owns one SelectionArea. `DocumentSelectionDelegate` supplies
clipboard-only paragraph separators and list markers. `BlockList` passes its
`selectionSeparator` through retained forest branches; nested text chunks use
the empty default so visual wrapping never becomes a clipboard newline.

Pass an app-owned `MarkstreamSelectionController` to a view, or put multiple
views under `MarkstreamSelectionScope`. The controller provides `hasSelection`,
`selectedPlainText`, `selectedMarkdown`, `selectedDocuments` and
`copySelectionAsMarkdown()`. `selections` retains each original document, its
selected AST and source ranges; offsets are local to that original document.
Multiple views copy in their current visual order, including after reordering.
Dispose the controller when its owning UI is disposed.

Each mounted leaf uses SelectionListener -> SelectedContentRange -> a TextIndex
built from its actual selectable projection. Clipping those fragments retains
selected emphasis, links, code, list numbering, math and image syntax. Folded
details, collapsed code tails and paginated rows are absent from that projection.
Partial table copies leave unselected cells empty instead of copying their data.
Empty visible cells/rows and rules between selected blocks retain their structure.
Transient native ranges are clamped while a streamed tail is being replaced.
Selection metadata is installed only for views with a controller.

Custom inline builders return `RenderedInline(span: ..., segments: ...)`; each
TextSegment declares selectable text, source span and AST node. An atomic
citation should map its displayed label to the citation node, not WidgetSpan's
object replacement character. Custom block widgets can use
`MarkstreamSelectionFragment` with the same explicit contract, or render built-in
blocks / MarkstreamCodeContent, which already provide their projections. Do not
nest overlapping fragments or add a SelectionArea. Unregistered extension labels
copy their selected text rather than an unselected part of the original spelling.

## Rendering budgets and retained paragraph runs

`PerformanceLimits` centralizes table pagination, streaming highlighting, code
virtualization, native-text thresholds and capture bounds. Streams of at least
8,000 source characters coalesce prefix appends into a 50 ms window, matching
the application's previous policy. Completion, non-prefix edits, parser changes,
caller-supplied ASTs and exports flush immediately. Disposal cancels pending
work. Unchanged parsed snapshots reuse the cached view during scheduling frames.

Consecutive paragraphs share a bounded source projection. Completed paragraph
widgets and spans retain identity. Short text-only paragraphs use native
RenderParagraph children behind one element; embedded widgets keep their normal
Flutter tree. Native children still own layout, hit testing, selection and
semantics. Exact fractional paragraph spacing is retained. Contextual layout
settings such as text scaling, RTL view direction or accessibility overrides
use the individual paragraph path.

Paragraph runs participate in the same before-paint viewport observer as the
block forest, including when an ancestor moves behind a cached layer. Paint and
semantic membership are tracked independently. Capture disables nested culling.
Pixel tests compare English, CJK, RTL text, links and code capsules at both font
scales; selection tests cover source edits during active dragging.

Run `flutter test --no-pub test/perf/streaming_append_bench.dart --reporter expanded`
from this package. It uses the fixed application 30k/100k fixtures and the exact
baseline font, with rich blocks and a selection controller. It reports the
request frame separately from the actual content frame after advancing the fake
clock by 50 ms. That clock advance is not wall-clock sleep. Cold timing includes
parsing, building, layout and paint for the whole initial document. The benchmark
does not claim that the final application adapters or physical Android profile
performance have been measured. Desktop target gaps remain visible in the
application's performance report until final migration acceptance.
