# IntelligentUI implementation record

The authoritative scope is [the technical proposal](technical-proposal.md),
followed by the user's 2026-10-23 visual HANDOFF, then
[DESIGN.md](visual-design-reference.md), then the HTML prototype.
This record distinguishes implemented capability from acceptance evidence.

User amendments in this implementation chat (2026-10-23): Linux acceptance is
deferred; model evaluation uses only `deepseek-v4.1-flash-1017` (the 30 tasks and
29/30 threshold are unchanged). Windows is the LAN machine from the chat
“查看 Issue #1276”, `01a15c4d-b2c1-7f31-afd3-74e084567f32`; its existing SSH
identity and verified host key can be reused. Credentials provided for model
evaluation must remain outside source control and are not copied here.

## C01 baseline

- Date: 2026-10-23, America/Los_Angeles. Implementer/build operator: this Codex
  chat on the user's local Mac; no external operator has been assigned.
- Base: `e15df5485da56383dfe769a62f86ca66ecdea21a`, matching fetched
  `origin/master`. Worktree: `/Users/psyche/.codex/worktrees/intelligent-ui/kelivo`.
  Branch: `feat/native-genui`. Main checkout remains untouched.
- Proposal baseline: `e06ba9dec55958404ba37951cd63396559a9f7e8`.
  Frozen legacy reader: `58d9badfb0912bb01739a71d2dc26ed7deded90b`.
- Flutter: `/Users/psyche/development/flutter/bin/flutter`, 3.47.6,
  framework `5fc346839b5d0eef006ed8404392afb4dfae428d`, Dart 3.13.5.
  Host: macOS 26.5.2 (25F84), arm64; Xcode 26.6 (17F113).
- Root dependency resolution copied from the clean main checkout, then checked
  with `flutter pub get --offline --enforce-lockfile`. Ignored lockfile SHA-256:
  `ca2ee77520e837b94e454cc091a7b57365a9b339cd76a7d4830a3b55b2324d14`.
  No global dependencies installed.
- Root/markstream checks and a macOS debug build are required for every commit.
  Logs live under `build/genui/logs/`, outside version control. Check results
  below before treating this step as accepted.

### Changes since the proposal baseline

The browser feature was merged into master. Its new in-app WebView packages,
vendored platform implementations, glass dependency and shader remain intact.
GenUI retains the proposal's explicit restricted-preview contract; an existing
general browser is not evidence of sandbox compliance. The assistant timeline
now has browser-tool grouping and expanded message UI. C09 must preserve that
projection behavior. Backup packing progress now excludes the generated
manifest from measured source bytes; cancellation still runs for metadata.

Database remains schema 3, published `{1,2,3}`, minimum readable 2. Archive
format/minimum readable remain 3. The schema, composer draft contract and
Markdown integration have no intervening changes in this range.

### Scope and initial contracts

21 native components, 11 pure functions (including sample), Ask/Reset only.
DSL header: `ui 1 catalog "kelivo.native/1"`. Physical-line declarations,
JSON strings, globally unique symbols, explicit root, typed bindings and refs.
No arbitrary colors/layout/script, network, tools or automatic sends.
Implement in order: catalog → parser → evaluator → memory controller → storage.
Persisted state version 1 contains normalized `inputs` and `view` overrides;
database schema will move atomically from 3 to 5 in C10.

Budgets: source 256 KiB; declaration 128 KiB; 3 UI blocks and separately 3 Web
blocks per message; 256 components, 64 inputs, 512 declarations; component depth
16, expression depth 32; 50,000 operations per state batch; sample 2–501 points;
Cartesian charts 4 series/2,000 points, pie 12 items; tables 1,000 rows/8 columns,
10 or 20 rows/page; state 32 KiB, model projection 4 KiB, search 16 KiB,
copy 64 KiB; image export 16 MP; one application-wide Web preview.

### Visual source and decisions

Reference directory: `/Users/psyche/Downloads/kelivo-genui`; `index.html`,
`DESIGN.md`, `png/00`–`png/71`. The prototype is a visual reference, not code
to transplant. All visual tokens have one owner, `widgets/genui_theme.dart`.

Verified existing symbols:

| Symbols | Current source |
| --- | --- |
| SurfaceLadder | `lib/theme/surface_ladder.dart` |
| AppSemanticColors | `lib/theme/app_semantic_colors.dart` |
| AppSpacing, AppRadii, AppShadows, AppOverlayColors | `lib/theme/design_tokens.dart` |
| MarkstreamTheme, CodeBlockTheme, QuoteTheme, MarkdownTableTheme | `dependencies/markstream/lib/src/flutter/theme/markstream_theme.dart` |
| MarkdownSurfaceScope | `lib/shared/markdown/markdown_surface_scope.dart` |
| ChatSurfaceTheme, ChatSurfaceForegroundPalette | `lib/features/chat/widgets/chat_surface.dart` |
| FrostedSurface, ChatFrostedBackdropScope | `lib/features/chat/widgets/frosted/` |

`SurfaceLadder.surfaceFill` is the input fill (DESIGN's `fill` is shorthand).
`AppRadii` currently defines only `capsule=28`; other control radii come from
existing widgets, with centralized GenUiTheme mappings. No missing required
class. No additional blur, opacity layer or boundary in the message path.

Approved decisions A1–A12: streaming is read-only; Web has its own block limit;
chip freezes at click; a stale chip does not block sending and is omitted;
no resume-generation action; save failure is a retryable header badge only;
expansion shares state with an in-message stub and one active control tree;
RTL mirrors legends/columns but not numeric/time axes; nulls sort last in both
directions; unknown components are node errors; Row wraps at text scale ≥1.3;
desktop expansion is at most 960×85vh and closes with Esc.

The proposal takes precedence over visual references: WebRTC remains an
accepted residual risk. The Web preview must not claim absolute offline or
zero network capability even though the prototype uses “无网络”.

### Markstream spike and host integration decision

`test/features/intelligent_ui/markstream_contract_test.dart` exercises real
Markstream ASTs: every UTF-16 prefix, every UTF-8 split after decoding, CRLF,
Unicode, fence/quote/list indentation, closure, interruption, source rewriting,
truncation, regeneration and repeated declarations at distinct positions.

Important: `CodeBlockNode.code` includes a synthetic final LF even when the
source has none. Its final TextNode has an empty source span. C09 must exclude
that display-only LF before feeding the line reducer. Real CRLF is represented
by `text="\n"` with a two-code-unit source span; contextual indentation is
removed while each text fragment retains its original coordinates. No generic
Markstream event API is needed. Compare normalized consumed prefixes, append
only their suffix, and advance runtime epoch on replacement/truncation. Do not
reduce in widget build. Real fence closure and successful host completion are
separate conditions for unlocking controls.

Current `TimelineProjectedBlock.text` does not retain original part ordinals;
inline thinking can synthesize display parts. C09 will carry original part/run
mapping through the projection, grouping adjacent TextParts only and never
crossing image/file/tool boundaries. The surface key uses original run-first
part ordinal and UI-fence ordinal, not display index or database part_id.
Builder registration belongs in `kelivo_markdown_extensions.dart`; trusted
scope only wraps assistant main reply text. Quote/nested/user/tool/preview
paths remain code. Focus exemption belongs to control hit regions, because
`MessageListView` currently requests timeline focus on desktop pointerDown.

The C09 development entry will mount production ChatMessageWidget and
MessageListView with a synthetic assistant message from
`test/fixtures/genui/manual/c01-assistant.md`; pair it with user/tool cases.
An isolated gallery cannot establish host focus/trust correctness. No runtime
feature flag or conversion of user messages into trusted assistants.

### Environment and outstanding acceptance

| Environment | Discovery | Acceptance status |
| --- | --- | --- |
| macOS | Local GUI host, Xcode and Flutter available | C01 debug build passed; GenUI GUI flows later |
| iOS simulator | Booted iPhone 17, iOS 26.5 | Available; not physical-device evidence |
| iOS physical | Flutter discovers device named HUAWEI, iOS 18.2.1 | Signing/install/behavior not yet verified |
| Android | Local Android SDK/adb, no connected device | Build possible; physical runtime BLOCKED |
| Windows | SSH verified; Windows 11 build 26100, x64, active console; isolated Flutter 3.47.6/Dart 3.13.5 and Visual Studio 2022 17.12.4 with C++ tools | Candidate builds available; actual GenUI build/plugin tests and C21 GUI pending |
| Linux | No machine; user explicitly deferred acceptance | DEFERRED by user; not a delivery gate for this run |
| Model evaluation | User supplied a test endpoint/key and named one model | C06 early run 1/3 preserved; C25 final 30 pending; credentials not in Git |

No external CI run or upload is claimed. Missing environments do not block
independent local implementation, but corresponding platform commits require
the proposal's build evidence. Model credentials must be supplied through
environment variables, never read from the app's accounts or logged.

### Progress

- C01: final-tree analyze passed; root suite 9,079 passed/2 skipped; all 12
  newly added Markstream contract tests passed separately (added after suite
  discovery). Markstream analyze and all 296 tests passed. Independent
  `code-review` agent found no actionable defects in the five C01 files.
  `flutter build macos --debug --no-pub` passed with existing native dependency
  warnings. Formatting and diff checks passed. Baseline accepted; no GenUI
  renderer or model capability is registered in this step.
- C02: catalog/typed contracts accepted. Independent review found no actionable
  defects; fatal-info analysis passed; root 9,097 passed/2 skipped; markstream
  analysis and 296 tests passed; macOS debug build and diff check passed.
- C03: parser/validation accepted. Final independent review has no actionable
  findings; 61 focused tests passed; root fatal-info analysis and 9,140 tests
  passed/2 skipped; markstream analysis and 296 tests passed; macOS debug build,
  formatting and diff checks passed.
- C04: bounded evaluator accepted; 77 focused tests passed, root fatal-info
  analysis and 9,156 tests passed/2 skipped; markstream analysis and 296 tests
  passed; macOS debug build and diff check passed. Independent review has no
  remaining findings after sampling and signed-zero cache fixes.
- C05: in-memory controller and normalized state accepted; 102 focused tests,
  root fatal-info analysis and 9,181 tests passed/2 skipped; markstream analysis
  and 296 tests passed; macOS debug build and diff check passed. Final independent
  review has no remaining findings.
- C06: manual evaluator, frozen 30-task configuration and offline scorer
  implemented; 120 focused tests and fatal-info tool analysis passed. Final
  independent review has no findings; root fatal-info analysis and 9,199 tests
  passed/2 skipped; markstream analysis and 296 tests passed; macOS debug build,
  formatting and diff checks passed. Early real calls follow this commit.
- C07: native content and shell accepted by independent review; 151 focused
  tests including 14 pixel goldens passed. Root fatal-info analysis and 9,230
  tests passed/2 skipped; markstream analysis and 296 tests passed. macOS debug
  build, formatting and diff checks passed. The native gallery built and launched;
  interactive inspection is pending because the Mac is locked.
- C08: seven native inputs, Form validation and local actions implemented;
  220 focused checks (including 26 goldens and two shared-control tests) passed.
  Final independent review has no findings. Root fatal-info analysis and 9,297
  tests passed/2 skipped; markstream analysis and all 296 tests passed. macOS
  main-app and native input-gallery debug builds passed, as did formatting and
  diff checks. The first full run exposed a file-browser test waiting only 50 ms
  for real I/O; its reviewed fix awaits the rendered item without forcing a
  competing refresh. All filesystem and widget-action assertions remain.
- C09: trusted Markdown/message host accepted by independent review; 301 focused
  checks including 28 goldens and a further 20 bootstrap/host checks passed. Root
  fatal-info analysis and 9,339 tests passed/2 skipped; markstream analysis and
  296 tests passed. macOS main-app and isolated gallery debug builds, formatting
  and diff checks passed. Native GUI inspection remains pending while locked.
- C10–C26: not implemented. No complete-delivery claim.

## C02 contracts

`catalog/ui_catalog.dart` owns all 21 component descriptors, semantic fields,
tone/chart enums, named slots, function/action signatures and synthetic example
documents. `UiCatalog.encodeReference()` produces deterministic sorted JSON;
no generated Skill is registered yet. `ui_budgets.dart` owns the proposal's
shared limits. `protocol/ui_ir.dart` distinguishes input bindings, structural
children, non-structural FormRef, expressions and action descriptions.

Contract choices that the proposal leaves to the catalog: gaps are the semantic
values small/medium/large; Row distribution is equal/fit; display precision is
0–10 digits; TextField defaults to a 2,000-character limit (explicit bounds up
to 8,192); number/slider step defaults to 1; min/max are binary pure functions;
round/formatNumber accept an optional precision argument. These are fixed
language contracts, not model-controlled pixels or colors. Dropdown/radio
options use `{value: scalar, label: string}` records; table columns use
`{key: string, label: string, digits?: number}` records. Detailed graph/type
validation and executable parsing of all examples follow in C03.

Plain Dart smoke import of both the catalog and IR succeeded without Flutter,
Drift or platform libraries. Contract tests cover deterministic reference
generation, semantic coverage, unique example symbols, distinct reference
types, immutable collection ownership and JSON-safe IR serialization.

## C03 parser and validation

Reuses PetitParser 6.1.0 from the existing dependency graph. Full physical
records are reduced once; CRLF and pending CR are handled explicitly, and
unterminated final records commit only on fence closure. A changed consumed
prefix or reopening a closed document advances the runtime epoch. Identical
updates reuse the snapshot; duplicate declarations remain errors even when
their text is identical. Header/catalog/root failures are whole-surface
failures; unknown components/properties and bad dependencies stay local.

Typed binding/children/FormRef/action slots, declaration/UTF-8/depth budgets,
forward references, static expression types and graph invariants are checked.
Error codes map to fixed localization keys without importing Flutter.
Derived types use iterative dependency postorder; AST recursion is bounded
before records leave the parser. Rejected deep ASTs and nonfinite literals do
not enter the serializable IR. Runtime arithmetic/domain checks are C04.

Independent early review confirmed and then rechecked the fixes for a valid
500-declaration chain overflowing recursive type inference, and invalid ASTs
overflowing/failing diagnostic serialization. The reviewer also checked 2,205
incremental rewrites against fresh parsing. Current review has no actionable
findings. Regression tests include these cases and all catalog examples.

## C04 bounded evaluation

`runtime/ui_evaluator.dart` executes only catalog expressions and functions,
with strict scalar types, finite doubles, short-circuit branches, immutable
collections and one shared operation budget. Derived declarations resolve in
iterative dependency order. Accepted input batches reuse valid unaffected
results; failed calculations retry with the next batch's fresh budget.

Samples include both endpoints, preserve null domain gaps and reject partial
results on budget failure. Interpolation stays inside the requested interval
and is nondecreasing even when adjacent requested points round to the same
representable double. Zero has one representation so cached formatting agrees
with fresh evaluation. No expression performs IO or invokes actions.

Result shape checks reuse immutable value identities to bound alias expansion:
logical UTF-8 JSON size is at most the source budget, logical values at most
the batch operation budget, and result depth at most the expression depth.
This prevents tiny repeated-array programs from producing enormous serialized
results, without expanding the shared object graph during validation. These
checks supplement the catalog's later chart/table-specific data limits.

## C05 in-memory controller and state version 1

The host owns `UiSurfaceController` outside widget lifetimes. A synchronous
batch resolves inputs, derived values, node properties and Ask descriptions
before notifying subscribers. Nodes subscribe independently; unchanged sibling
results retain identity and ordinary input changes do not notify the shell.
Real fence closure and successful host completion are both required to unlock
interaction. Interrupted/invalid and explicit export modes stay read-only.

`UiSurfaceState` serializes only scalar overrides and bounded view settings.
It removes values equal to source defaults, sorts keys and rejects unknown
fields, invalid types, unsupported versions and UTF-8 states over 32 KiB.
Table settings are sortKey/descending/filter/page (filter up to 256 code units,
sort key up to 128, page within the row budget); Chart settings are dataView
and sorted unique hidden-series indices within the pie-series limit. Missing
settings mean host defaults. No derived values, owner IDs or runtime epochs
enter state_json. Saved snapshots pair it with revision/surface identity and
the SHA-256 of normalized source plus catalog version.

Runtime callbacks use controller identity and source epoch. Pending restores
also capture a separate user-interaction epoch: even a no-op Reset or an IME
draft invalidates an older restore without causing a redundant state write.
Save completions are checked against the actual state sequence. Source changes
reset overrides, while equivalent LF/CRLF sources preserve values.

Review regressions cover the no-op Reset/restore race, failed nodes whose
diagnostics exceeded the bounded list, and runtime errors propagating through
FormRef to its button. Required/hidden-field validation and draft controls
remain C08; repository/flush behavior remains C11. No database or widget
dependency is introduced here.

## C06 manual model evaluation and offline scoring

`tool/genui_eval.dart` reads the test key and full completion endpoint only from
environment variables. Its serial bounded HTTP client refuses redirects, does
not log exception bodies or credentials, and never retries paid calls. An
exclusive retained marker claims each fresh output directory before requests.
The repository entrypoint and tracked, clean configuration are required so the
recorded tested commit describes the actual input and interpretation code.
Guards include the vendored Markstream parser and dependency manifests. Since
the app lockfile is intentionally ignored, the tracked evaluator configuration
also fixes the Dart SDK and the six hosted packages used by the pure runtime;
both the active package resolution and lockfile must match before a run/summary.

The user-selected single model has six scenes × five fixed variants. The early
subset covers calculator, parameter curve and conditional form. Deterministic
checks exercise actual controller updates, units/numbers, exact Ask contexts,
Form membership, visibility/enabling, data mappings/keys and preserved null
gaps. Semantic inspection is separate and attributed (including agent review
when applicable); a parser-only or deterministic-only pass is insufficient.
Final acceptance remains at least 29/30. The formal report contains only model,
date, testedCommit and score. No model API enters ordinary tests or G.

Eight clearly labeled synthetic outputs cover all six scenes plus domain gaps.
Regression mutations cover wrong arithmetic/units, hardcoded results, hidden or
disabled UI, fields escaping Form, extra Ask context, duplicated table keys and
bad chart mapping. Failed checks stop at a bounded collector even for hundreds
of aliased invalid tables. Actual early calls occur only after C06 is committed;
they and the later C25 full run require separate recorded evidence.

### Early live result (after C06)

The manual three-task run completed on `66148048a16bf3cce98c9a4d66ebe24065296da0`.
The four-field record is `evaluation-early.json`: **1/3**. The calculator passed
deterministic probes and coding-agent semantic inspection. The function curve
omitted its fence, and the conditional form used an unlabeled fence and renamed
the requested `form` node to `root`. Original outputs, diagnostics and attributed
review notes are retained under `test/fixtures/genui/real/early-c06/`.

No output was repaired for scoring and no paid retry was made. The failures
motivate a complete fenced few-shot and explicit task-ID preservation in the
final generated guidance (C22); they do not justify activating bare DSL or
unlabeled code. This early result is diagnostic, not the final 30-task acceptance.
The no-credentials CLI check also exited explicitly without a model request.

## C07 native layout and content

`GenUiTheme.of(context)` maps the existing surface ladder, semantic containers,
spacing/radii/shadows and Markdown fonts at one boundary. Cards remain opaque
on wallpaper. The ten content/layout components use resolved values from the
in-memory controller; they never parse source during build or own state lifetime.
Narrow equal rows and large text stack; fit rows wrap without shrinking text.
Nested Markdown has no feature extensions or image loader. Formula reuses the
existing math engine, exposes its label and selectable TeX, and falls back to
source for parse failures or presentation-changing commands.

The Surface shell shows generation, interruption, node failures, invalid source,
read-only snapshots and a retryable unsaved badge. Source and More dialogs reuse
the app dialog and iOS controls; Escape restores the trigger focus. Reset is a
local controller mutation. Expand/repair/save callbacks are supplied by the host
when their later commits land. A 44-pixel minimum on IosIconButton now encloses
the actual pointer target; icon/text buttons and app dialogs honor reduced
motion. Restoring inputs that change the number of failed nodes also notifies
shell observers, without producing a persistence write.

Development entry: `flutter run -d macos --no-pub -t
lib/features/intelligent_ui/widgets/gallery/main.dart`. `gallery/previews.dart`
contains the isolated content previews; the native shell is intentionally kept
out of the web preview import graph. Nothing registers a production builder or
model skill yet. The 14 initial pixel baselines cover content and shell states
in light/dark, mobile/desktop, wallpaper, RTL and 1.3x text. They use the existing
wallpaper host and deterministic bundled test font. These are C07 baselines,
not the full S1/S6/state matrix or device/performance acceptance required in C24.

The macOS gallery debug build and VM launch succeeded. Computer use returned
“Mac is locked”; foreground inspection and native clicks were not performed.
The unlock request is pending while implementation and automated checks continue.
Widget/golden evidence is not counted as native GUI acceptance.

## C08 inputs and local actions

`UiInteractionController` keeps text/composition drafts, validation visibility
and submitted Forms separate from persisted input state. Incomplete numbers
never substitute the last committed value during Ask. Hidden fields retain
their values and drafts without validation; disabled inputs do not write state.
Ending IME composition while a field is disabled or unmounted preserves the
finished draft, which a later active edit or explicit submit can commit. Submit
validates visible active fields, settles pending drafts to a bounded fixed point,
then captures one immutable intent. Newly revealed errors are focused after
their controls mount. Reset clears transient editing even when persisted state
was already at its defaults.
Controls bound to the same logical input share one current draft: starting a
new edit supersedes older alias drafts, including hidden ones. This keeps the
submit bound tied to input count and prevents old aliases overwriting newer
edits. Row keeps keyed child Elements when width or text scale changes, so the
focused editor, selection and active composition survive reflow.

The seven controls reuse iOS fields, switches, checkboxes and segmented tabs.
Slider uses a native canvas with bounded ticks, finite-range interpolation,
RTL pointer/key direction and accessible value/increase/decrease actions.
Select uses the existing mobile FormSheet and desktop dropdown; keyboard
navigation, visible focus, Escape, focus return, large menus and open-menu
theme changes are supported. RadioGroup uses segments only when short labels
fit; large text and long labels use vertical rows. Source epochs reject old
editor/gesture callbacks, including a node changing component type.

Buttons remain keyboard focusable when disabled and explain the reason. Ask
requires a connected observer and only emits a frozen `UiAskIntent`: no request,
composer mutation or sent-state claim. The native gallery now has all inputs,
conditional fields, local Reset and an observable frozen Ask context. Twelve
additional input goldens cover light/dark, RTL, 1.3x text, validation, disabled
and read-only states. They extend C07's fourteen baselines; C24's full matrix,
production-host focus chain and native-device acceptance are still separate.


## C09 trusted message host

The stable Markdown registry now dispatches `kelivo-ui` through a feature-owned
adapter. Only assistant main-text Markdown constructs `UiHostBinding`; user,
tool, system/unknown roles, quoted/list-nested blocks, internal Markdown, an
identical nested renderer and an unscoped renderer keep ordinary code. The scope
requires the exact nearest MarkstreamView instance plus original top-level fence
coordinates. Completed Markdown prefixes cache widgets, so the native block's
own element subscribes to host changes; it does not rely on another builder call
or tail-block `rendering.streaming` to receive a terminal state.

`UiMessageSource` caches by original parts identity. It groups only adjacent
TextParts and carries original part ordinal, run fence ordinal and exact source
spans through thinking extraction, historical contentSplits, visual regexes and
paragraph bubbles. Every non-text part is a hard run boundary. The DSL adapter
omits Markstream's synthetic trailing LF; source reduction stays in lifecycle
hooks. `ProtectedText` matches regexes in complete run coordinates, retaining
fences, adjacent line breaks and mapped historical split anchors. A visual
replacement cannot create an authorized fence. Hidden native-looking code does
not consume the visible three-block budget. The fourth visible block receives
an explanation and ordinary source.

The message list owns the in-memory registry and transient draft controller,
so paragraph regrouping, scrolling out/in and theme rebuilds retain input state.
Actual control hit areas mark the original pointer event; the list skips only
its keyboard-focus request for these events and retains scroll/defer bookkeeping.
Card prose still follows the existing selection path. A rewrite advances the
controller epoch and rejects callbacks from the previous source.

The existing generation-run state is hydrated alongside parts in a batched read
transaction, without schema changes. Finalization publishes the terminal state
on the caller's message, including temporary/no-run branches. Unknown historical
outcome is interrupted, never inferred successful from `!isStreaming`. C12 must
preserve completed provenance for copy/fork paths together with state ownership.

A complete header starts the shell; forward references show dashed placeholders.
One shared surface clock drives dots and skeleton paint and stops on completion,
interruption, export or reduced motion. Node arrival fades for 160 ms; the
FadeTransition is removed when the animation ends. A retained content subtree preserves focus and composing
through removal, with no permanent per-node repaint boundary. Invalid
source has a bounded line viewport with diagnostic bars/backgrounds and explicit
copy. Repair is visibly unavailable until the C16 draft action is connected.

Development target: `tool/genui_message_gallery.dart`. It uses
the actual MessageListView and ChatMessageWidget, isolated in-memory preferences
and DB, paired assistant/user/tool/quote fixtures, nine generation phases and an
observable frozen Ask sink. It makes no model requests and is not imported by
the production entry. The fixture is asserted complete and its actual button
is exercised by a widget test. UI expansion remains C19; production Ask remains
unavailable until C16, with no fake-success callback.

Final verification: 301 focused language/runtime/widget/projection checks
including all 28 light/dark pixel goldens passed. After moving the isolated
bootstrap to tool/, the existing preference-access gate and actual host group
passed all 20 checks; tool entry analysis also passed. Root fatal-info analysis
and all 9,339 tests passed (2 existing skips). Markstream pub get, fatal-info
analysis and all 296 tests passed. The main macOS app and separate message-gallery
debug target both built. All 41 changed Dart files are formatted; diff checks
passed. The final independent review has no findings.

The four shell goldens changed for diagnostic source/disabled repair appearance;
two new stream goldens cover forward references, closed-but-generating, complete
and interrupted. Light streaming and dark wallpaper/RTL/1.3x shell images were
inspected. The Mac is still locked, so native GUI operation remains unverified.
The development entry uses isolated memory storage and makes no model requests.

Review verified role gating, historical split order, whole-run regex anchors,
source-revocation and current streaming notifier authority. Disappearance,
changing fence info to ordinary code, or moving a block into thinking revokes the
owner; viewport unmount does not. Reappearing source cannot reuse an old token.
Raw source reconciliation does not impose a second three-block budget. A further
516 pure Dart split/anchor probes were reported by the independent reviewer;
these are separate from Flutter and native evidence.

Two partial root runs were stopped for review/SDK corrections and are not
counted as passing. The first completed root run caught the frozen preferences
access gate: memory-only setup was moved from lib/ into the separate tool entry,
with the production allowlist unchanged. The final complete run above is after
all fixes, including the transient FadeTransition/editor identity regression.

The before/after timeline_scroll_bench.dart runs use the same 40-round fixture.
Render-object counts are unchanged (1,388 / 1,074 / 1,038 for 0 / 4 / 12 tools),
and each case has one extra inherited element. Average widget-test scroll times
were 10.56 / 13.94 / 17.51 ms before and 10.78 / 14.40 / 16.72 ms after. These
stopwatch samples are diagnostic only; they do not establish device build/raster
±3% or the C24 performance acceptance. Logs remain in ignored build/genui/logs/.
