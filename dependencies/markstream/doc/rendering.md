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
