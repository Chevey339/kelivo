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
| Model evaluation | User supplied a test endpoint/key and named one model | C06 early/C25 final calls pending; credentials not in Git |

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
- C03–C26: not implemented. No complete-delivery claim.

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
