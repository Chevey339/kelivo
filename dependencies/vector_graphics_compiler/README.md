# Local vector_graphics_compiler

Based on the published Flutter `vector_graphics_compiler` 1.3.0 package.
The upstream BSD license and author list are retained.

Local changes: SVG resolution shares a 65,536-unit work budget across resolved
nodes, ordinary and dashed paths, clip references, and text. Path copying and
transformation consume budget before allocating command arrays, including
inherited styles and reused definitions. Each emitted dash command and each
recursive curve-length step consumes the same budget.
Curve subdivision is also limited to 64 levels, preventing stack exhaustion
when floating-point subdivision stops converging. Oversized expansions fail
normally so callers can display the source link.

Before encoding, pattern bitmap allocations are checked using the resolved
dimensions and each actual pattern draw command. Each edge is limited to 4,096
pixels and all pattern tiles together to 4,194,304 pixels. This bounds allocations
that the native decoder performs before the final image size can be constrained.

When updating this dependency, retain the shared `GeometryBudget` in
`SvgParser`, `_Resolver`, and `ResolvingVisitor`, the corresponding `_PathDasher`
and curve checks, and the pattern budget in
`_encodeInstructions`. Regression coverage is in the root
package's `test/utils/svg_image_provider_test.dart`.
