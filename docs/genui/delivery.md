# IntelligentUI delivery record

The implementation is in the single managed `intelligent-ui/kelivo` worktree on
`feat/native-genui`. Commits are local; nothing has been pushed or merged. The
original proposal is retained as `technical-proposal.md`. Its scope amendments
below come from the user, not from inferred passes.

## Agreed scope and exceptions

- Final model evaluation uses only `deepseek-v4.1-flash-1017`: the original
  six scenes × five variants remain, with at least 29/30 first-round successes.
- Windows work is paused after the user's blue screen. The C20 plugin source
  and earlier unit evidence are retained; final Windows build/preview work is
  not complete. No cause of that crash has been established.
- Linux acceptance, physical-iPhone acceptance and macOS Chinese IME are
  deferred by the user. Simulator evidence remains explicitly separate.
- Android's measured 120 Hz chart-drag/scroll and maximum-chart response limits
  were accepted on 2026-10-24. The maximum-chart response p95 was 55.298 ms;
  several drag/scroll samples exceeded the 1% target. These remain measured
  exceptions, not passing performance figures.
- The Windows shared-profile autofill/password-setting exception is retained
  for future Windows acceptance. Its synthetic isolation test is still deferred.
- WebRTC remains the proposal's explicitly accepted residual risk. Controlled
  HTTP/TLS probes do not establish absolute network isolation.

## Implementation and review

C01–C24 cover the bounded native language/catalog, parser/evaluator/controller,
21 components, original-source host authority, lifecycle and SQLite persistence,
backup/forward import, charts/tables, frozen Ask drafts, semantic copy/TTS/search,
one expanded control tree, read-only exports, the Windows plugin preparation,
available-platform Web previews and the bundled visualize Skill.

C24 also fixed expanded-Ask focus, exact-zero sampling, measured rendering costs,
and historical split identity across semantic text, search and both PNG hosts.
The last repair retains raw source authority while sharing stored chronology;
hiding reasoning/tool cards cannot change the frozen native cards in an export.
Independent review has no remaining findings at the recorded candidate.

Detailed evidence: [implementation log](implementation.md),
[C24 behavior and visual acceptance](acceptance-c24.md),
[C24 performance samples](performance-c24.json), and
[C21 Web engine observations](web-acceptance-c21.json).

## Visual refinement after the trial

The user's hands-on screenshots identified visual and scrolling issues that the
original golden baselines had not caught. The follow-up aligns compact controls,
input fills, card headers, table framing and pagination with the supplied visual
reference, and removes the competing inline vertical drag. Details and native
verification boundaries are in [the refinement record](visual-refinement.md).
The earlier model, restore, Web and performance records below remain evidence
for their recorded commits; this visual correction adds G and focused native UI
verification rather than relabelling those earlier results.

The [C28 full-component audit](component-audit.md) follows the second hands-on
review: full inline height, an optional title bar, compact fields/buttons/chips,
short-table pagination suppression, clearer charts and streaming placeholders.
Its separate full G passed 10,260 root tests (one existing skip), 298 markstream
tests, both fatal-info analyses, dependency resolution, macOS debug build and
diff checks. Two 28-page native simulator review runs and the six production-host
scenarios passed; their tested source and screenshot limitations are explicit
in the audit. Clean-HEAD trial builds are recorded separately after commit.

## Final model evidence

The accepted [four-field report](evaluation-final.json) records
`deepseek-v4.1-flash-1017`, 2026-10-24, actual tested commit
`39f1c336545c2aecca0093dcbcaa54ca446e557d`, and **30/30 (100.00%)**. Both the
implementation agent and independent review agent checked all full responses
against the frozen tasks. This is agent review, not human acceptance, and applies
to this finite thirty-task set.

Two earlier complete runs remain recorded at 27/30 and 28/30. Shared Skill fixes
addressed missing synthetic-data labels and numerical prose inconsistent with
the displayed records; each repair was followed by a manually invoked full run.
The accepted score uses only the third run. All ninety outputs and attributed
reviews remain in normal offline replay. No paid invocation belongs to G or CI.
The C25 recording and C26 documentation do not change model inputs, interpretation
or scoring; final source-diff review verifies that boundary.

## Available execution environments

| Environment | Scope |
| --- | --- |
| Local Mac, macOS 26.5.2 (25F84), M4 Pro / 24 GiB | macOS native build, six scenes and Web engine checks |
| Xcode 26.6 (17F113) | iOS unsigned release build and iPhone 17 / iOS 26.5 simulator |
| Dedicated Android 2112123AC, Android 11 / API 30, adb fee8c1be | Native build, six scenes, Sogou IME and Web engine checks |
| Flutter 3.47.6, revision 5fc346839b5d0eef006ed8404392afb4dfae428d, Dart 3.13.5 | Pinned toolchain for all local Flutter checks |

The implementation agent executes commands and reviews results. Native Web
activation uses CUA clicks on Mac/simulator and Flutter pointer injection on
Android; each probe requires trusted activation. IME checks use the real
Android keyboard. Flutter-injected Ctrl/Cmd+A and widget Semantics assertions
are recorded separately from OS keyboard/screen-reader acceptance.

## Pre-commit validation

C25 passed root fatal-info analysis and 10,240 tests (one existing skip),
markstream dependency resolution/analysis and 298 tests, a macOS debug build,
diff whitespace checks and independent review. C26 changes documentation only;
its separate required G passed the same 10,240 root tests (one existing skip),
298 markstream tests, both fatal-info analyses, dependency resolution, macOS
debug build and diff whitespace check. Independent review returned no findings.
Logs are retained under build/genui/logs/c26-*. No Dart files changed in C26.

### iOS scenario-driver correction

The first C26 simulator attempt found that the test driver used Ctrl+A on iOS.
The pinned SDK uses Cmd+A for Select All there, and Ctrl+A moves to the line
start. An added iOS widget variant reproduced the same selection failure; using
Meta on both Apple platforms makes Android/iOS/macOS composed variants pass.
This is a test-fixture correction with no application, prompt or scoring change.
Its separate full G passed root analysis and 10,241 tests (one existing skip),
markstream resolution/analysis and 298 tests, macOS debug build and diff checks.
Independent review returned no findings. Both changed Dart files were formatted;
logs remain under build/genui/logs/c26-ios-*. Earlier final-HEAD records remain
retained as history; the final repetitions use the corrected committed fixture.

## Final-HEAD procedure

C26 is committed only after the root and markstream G checks, independent
review and a macOS candidate build pass. After that commit, record the exact
same final HEAD in `build/genui/c26/delivery-final.json` and its linked logs:

1. Build macOS release, iOS release without signing, and Android release APK.
2. Run six native scenarios on Mac, physical Android and the iOS simulator.
   Each must report zero native GenUI WebViews.
3. Repeat the available-platform Web engine probes, including real trusted
   gestures, positive controls, local HTTP/TLS observations and teardown.
4. Repeat the Android native IME flow with the final fixture.
5. Run `tool/legacy_restore/run.sh` manually. Generate a new v5 archive through
   the real export chain and restore it using frozen v3 business source
   `58d9badfb0912bb01739a71d2dc26ed7deded90b` with newly resolved dependencies.
6. Confirm paid model inputs, interpretation and scoring have not changed since
   the report's actual tested commit. Report/fixture-only changes do not require
   additional paid requests.

The isolated simulator harness temporarily changes five identity/entitlement
files, records them, and restores every original file. The release iOS build
uses normal identity with no signing. Neither constitutes physical-iPhone proof.
Each attempt has an exclusive directory and preserves earlier logs. The runner
archives any pre-existing integration-driver result before execution, then saves
only the newly produced reportData with the current command and commit. This
avoids treating truncated Android/iOS console JSON as complete Web evidence.
Final evidence stays outside Git to avoid a self-referential commit/amend loop.
Unexecuted final checks must stay pending; earlier C21/C24 runs do not substitute
for the final-HEAD repetitions.

## Evidence limits

The later [C28 component audit](component-audit.md) records the user's requested
full-height presentation, immersive header setting, compact controls and renewed
native simulator interaction/visual checks. It supersedes the C27 bounded-card
presentation without converting any deferred device or performance item into a
pass. The isolated 28-case review and production-host six-scene flow are separate
from the normal `lib/main.dart` trial installed for the user.

Goldens establish deterministic pixels; widget tests establish their tested
behavior/Semantics. Native automated scenes, actual keyboard input, provider
calls and profile observations are distinct evidence. Repository close/reopen
is not process-kill recovery, RSS includes engine/font/GPU caches, and an old
business-source restore is not execution of a historical release binary. The
ordinary-message profile comparison measured build +2.292% and raster -3.444%,
not statistical equivalence or an exact symmetric ±3% result.

No recurring provider evaluation, CI network call or old-reader gate is added.
The deferred environments remain open and are not described as fully accepted.
