# Changelog

## [2.0.0] - 2026-07-20

> ℹ️ **This release introduces Ta 的来信** (**proactive care**), which lets AI assistants send care messages to you on a configurable schedule.
>
> **Platform support**: Android only. Users on **other platforms** will see **no visible changes** after upgrading. The feature uses `android_alarm_manager_plus` for alarm scheduling and a headless background isolate for care decision-making and message generation.
>
> **Porting notes**: This feature was ported from another fork of Kelivo and adapted for Cuplivo's Drift/SQLite architecture. Stability is still being evaluated.
>
> **Permissions**: Android will request notification permissions for care message alerts. This is an opt-in custom feature — you can decline the request without affecting Cuplivo's regular chat usage.

### Added

- Proactive care (Ta的来信): AI sends care messages to users on a configurable schedule (#58)

## [1.9.1] - 2026-07-20

### Added
- Configurable focus-input hotkey (#60)

### Fixed
- Ensure assistant loaded before message generation to prevent system prompt race (#63)
- Gate input unfocus on resume to iOS only (#62)
- Markdown image regex stack overflow (definitive fix) (#61)

## [1.9.0] - 2026-07-19

> ⚠️ **Image generation users must update**
>
> Since 1.4.1 switched image responses to base64 (`prefer b64_json`),
> the regex-based image-reference scanner hits catastrophic backtracking
> on large base64 payloads, causing a stack overflow on the second turn
> of any image-generation conversation. 1.9.0 replaces the regex with
> linear indexOf scanning.

### Added
- PDF/Office file attachments: upload PDF, Word, Excel, and PowerPoint documents directly, with document processing configuration (#26)

### Fixed
- Multi-AI retry matrix: context truncation, version selection timing, and guard toasts (#54)
- MCP: skip heartbeat reconnect on rate-limit errors (429 / -32106) (#53)
- Large base64 images no longer cause regex stack overflow — replaced with indexOf scanning (#55)

## [1.8.0] - 2026-07-19

### Added
- Multi-AI synthesize mode: after comparing model responses, fork the conversation and let an AI summarize, fuse, or comment on all outputs — like a more flexible OpenRouter Fusion (#52)

## [1.7.2] - 2026-07-19

> ⚠️ **SVG preview users on 1.7.0–1.7.1 must update**
>
> Previous releases crash when LLM streams SVG code blocks: flutter_svg's
> isolate parser spawns repeated `compute(encodeSvg)` on partial / invalid
> XML chunks during streaming output, causing an isolate storm. 1.7.2 adds
> streaming debounce (360 ms alive / 220 ms settled), auto-switches to Code
> tab during streaming, enforces a 1 MB size limit, and adds an error
> fallback. SVG preview users should upgrade immediately to avoid random
> app kills.

### Added
- Desktop comparison view now shows 2 model columns per page instead of
  single-card swiping (#50)

### Fixed
- SVG preview isolate storm crash during LLM streaming (#46)
- Thread anchor lost on `dropThread` causing auto-adopt failure (#51)

## [1.7.1] - 2026-07-17

> ⚠️ **Mobile users on 1.7.0 must update**
>
> 1.7.0 shipped with a critical multi-select UX regression on mobile:
> the model picker auto-entered multi-select mode on every open, making
> normal model switching nearly impossible. This release restores the
> intended behavior and adds missing multi-select visual feedback.

### Added
- Kimi K3 model support with max reasoning and both naming variants (#43)

### Fixed
- Multi-AI mode: mobile no longer auto-enters multi-select on model open;
  model tiles now show checkboxes and highlight during multi-select;
  active model pre-selected on entering multi-select;
  clicking current conversation no longer exits multi-AI (#41)
- reasoning tags now stripped from auto-generated conversation titles (#42)

## [1.7.0] - 2026-07-17

### Added
- Multi-AI side-by-side comparison mode (#16)

## [1.6.1] - 2026-07-14

### Added
- GPT-5.6 model family support (sol/luna/terra) with low/medium/high/xhigh/max reasoning effort

### Fixed
- Tool schema sanitization now preserves `additionalProperties` for OpenAI and Claude function/tool definitions

## [1.6.0] - 2026-07-13

> 💡 **What's new**
>
> This release introduces the **Memory Mode Switcher** — a per-assistant toggle that
> lets you choose between **Auto Injection** (memories always injected into the system
> prompt) and **On Demand (Tool)** (memories accessed via the `read_memory` tool only
> when needed). Tool mode keeps the system prompt stable, significantly improving API
> cache hit rates and reducing latency.

### Added
- Memory mode switcher — per-assistant toggle between Auto Injection and On Demand (Tool) mode
- `read_memory` tool for on-demand memory retrieval in Tool mode

### Changed
- Memory system now supports on-demand (Tool) mode: instead of always injecting all
  memories into the system prompt, assistants can read memories via tools only when
  needed. This keeps the system prompt stable, dramatically improving API cache hit rates
- Extracted `_cleanupStreamingError` utility; fixed copy-paste log tag error

## [1.5.0] - 2026-07-13

> ⚠️ **Before Upgrading**
>
> This release migrates assistant storage from SharedPreferences to SQLite.
> **Please back up your chat history via Settings before upgrading** to guard
> against any edge-case data anomalies.
>
> It also fixes a critical issue where old conversations could not be resumed
> after restart due to immutable `messageIds` lists. If you encountered this,
> the upgrade will restore normal functionality.

### Added
- Server tool events — OpenAI server-executed tool calls rendered as native tool cards

### Changed
- Assistant storage migrated from SharedPreferences to SQLite, improving reliability and extensibility

### Fixed
- Old conversations could not send messages after restart due to immutable `messageIds` (#22)
- Past OCR results were lost after app restart (now persisted to SQLite via `CacheRows` table)
- `fetch_markdown` tool output did not strip `<script>` and `<style>` tags (#17)

## [1.4.1] - 2026-07-12

### Added
- SVG code block preview — render SVG diagrams inline within svg code fences

### Fixed
- Prefer `b64_json` key for OpenAI image response parsing

### Changed
- Tool descriptions rewritten for conciseness and accuracy (tool prompt optimization)
- Shared PreviewLoadingView and PreviewErrorView components

## [1.4.0] - 2026-07-06

### Added
- Image compression: interactive compression with size overlay and quality dialog
- Memory: record prompt editor in Memory tab

### Changed
- Backup: refactored shared code extraction (formatBytes, RestartRequiredDialog, etc.)

### Fixed
- Backup: import error feedback with try/catch wrapping
- Backup: conservative file inclusion on stat error

## [1.3.0] - 2026-07-05

### 🚀 Features
- Incremental backup with message-level filtering and scope preview
- Incremental attachment export with mtime filtering
- Persist includeSettings and updateBackupTime toggles across sessions

### 🐛 Fixes
- Fix multiple bugs across importers, models, API streaming, and desktop UI
- Chatbox/cherry importer regex and path escaping on Windows
- S3 client error response variable reference
- ChatMessage groupId defaulting to null instead of generated id
- Conversation fromJson crash on missing messageIds key
- Settings avatar path double-backslash check on Windows
- Emoji picker TextEditingController leak
- Assistant settings edit page null guard in desktop dialog
- Claude/OAI unsafe `as` casts causing silent chunk loss in streaming

### ⚡ Performance
- Batch insert restore data in single transaction

## [1.2.0] - 2026-07-02

### 🚀 Features
- Migrate chat history storage from Hive to SQLite
- Add image warning pill when draft images exceed model capability
- Add emoji preset for title prompt with hash fingerprint matching
- Update storage usage tracking to account for SQLite database files
- Improve migration UI with _Saving backup ZIP_ status and schema stage
- Update migration UI and localization text

### 🐛 Fixes
- Read `cachedContentTokenCount` from Gemini `usageMetadata` for Vertex AI
- Broaden Qwen 3.5-3.7 and Doubao seed-2 model capability detection
- Retry triggers title generation after first conversation failure

### ♻️ Refactors
- Unify duplicate tabbed-preview UI into shared components
- Use seconds-based timestamps for SQLite DateTime conversion

### ⚡ Performance
- Optimize Hive to SQLite migration with batch inserts

### 🔧 Chores
- Fork to Cuplivo — rebrand package to `com.cup11.cuplivo`
- Rename package from Kelivo to Cuplivo, bump to 0.1.0
- Remove Hive and migration code
- Bump `reel_text` to 0.4.0
- Remove stale workflows, update build-stable-44 target name
