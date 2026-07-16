# Cuplivo Domain Glossary

## Title Preset System
- **Hash Fingerprint matching**: `detect()` uses `trim()` only (conservative), exact character match after stripping leading/trailing whitespace.
- **PromptPreset data class**: `id`, `label`, `prompt` fields only. No `recommendedThinking` — presets are style-only, Thinking is independently controlled.
- **Dirty state**: real-time `detect()` on every text change; dropdown label switches to "自定义" when content no longer matches any preset.

## UI Interaction Model
- **Desktop** uses `DesktopSelectDropdown<String>` with `__custom__` sentinel for unmatched prompts.
- **Mobile** opens a `showModalBottomSheet` with `IosCardPress` options.
- Both are wrapped in `ListenableBuilder(controller)` so the dropdown label updates immediately on preset click or text edit, without auto-saving.
- "重置全部" button: resets both prompt text (`resetTitlePrompt()`) and Thinking switch (`resetTitleGenerationThinkingEnabled()`). No separate [↺] on the Thinking row.

## Prompt Preset Screen Layout

```
┌──────────────────────────────────┐
│ _TitleThinkingSwitchRow          │
│                                  │
│ 提示词              [▼ 标准✓]   │
│                                  │
│ ┌──────────────────────────────┐│
│ │ 可编辑文本框                  ││
│ └──────────────────────────────┘│
│ 可用变量: {content} {locale}    │
│ 更改预设后需点击「保存」方可生效 │
│                                  │
│ [重置全部]              [保存]   │
└──────────────────────────────────┘
```

## Title Generation Prompts

- **emojiTitlePrompt**: A preset variant of the title generation system prompt that allows ONE relevant emoji at the beginning of the title (followed by a space). No other punctuation or special characters are permitted elsewhere. The character limit (≤10) excludes the emoji.

## SVG Rendering in Chat

- **SVG code block** (` ```svg `): rendered via `SvgCodeBlock` widget (tab UI: "SVG" image tab + "Code" tab, reuses `mermaidImageTab`/`mermaidCodeTab` ARB keys). Uses `SvgPicture.string()` to render inline SVG XML. No streaming support (streaming SVG fragments are almost always invalid XML).
- **Markdown image SVG**: `imageBuilder` detects `.svg` extension in URL and `data:image/svg+xml;base64,...` pattern, routes to `SvgPicture.network()` or `SvgPicture.string()` respectively.
- **Known limitation**: URLs without `.svg` extension (e.g. shields.io badges like `https://img.shields.io/badge/release-1.0.0-blue`) are not detected as SVG. The user must ensure LLM output includes `.svg` suffix, or append it manually. Deliberate trade-off: avoids an extra failing HTTP request for every extensionless URL.

## Input Draft Persistence

- **InputDraftPersistence**: `lib/features/home/services/input_draft_persistence.dart`. Owns debounced (800ms) writes + lifecycle immediate save of chat input draft via `SharedPreferences`.
- **Scope**: Single global draft (`chat_draft_v1` key). Not per-conversation — the input is shared across conversations.
- **Persistence**: JSON blob with `{text, images[], documents[{path,fileName,mime}]}`.
- **Restore**: On cold start only, in `_ChatInputBarState._restoreDraft()`. Sets `TextEditingController.text` + media lists.
- **Clear**: On send success or when input is fully empty. Debounce skips empty content.

## Incremental Backup (Experimental)

- **Data scope**: Chat data (conversations + messages + toolEvents + geminiThoughtSigs). Optionally includes files (upload/, images/, avatars/, fonts/) when `includeFiles=true`, filtered by mtime >= since.
- **Filtering unit**: Message-level (`message.timestamp >= since`). Conversations created before `since` are still included if they have recent messages; only those messages are exported. Uses `updatedAt` as a fast pre-filter to skip inactive conversations. See `docs/adr/0002-conversation-level-incremental-filtering.md`.
- **File naming**: `cuplivo_incr_<export_ts_YYYYMMDD-HHmmss-ffffff>_<since_ts_YYYYMMDD-HHmmss>.zip`. The `cuplivo_incr_` prefix is the single identification mechanism for the restore path.
- **Restore behavior**: `cuplivo_incr_` prefix detected → skip the "Overwrite/Merge" dialog entirely → force `RestoreMode.merge` at both UI and DataSync layers.
- **Date source**: `BackupReminderProvider.lastBackupTime` for the [↻] shortcut. If null, fallback to 30 days ago. User can always override via `showDatePicker()`.
- **`includeSettings`**: Default `true`. Not yet persisted (planned for a future PR).
- **`includeFiles`**: Default follows the config's `includeFiles` toggle. Files are filtered by `lastModifiedSync() >= since`. Not persisted.
- **Architecture**: Incremental backup is NOT a mode toggle on full backup — it's a separate independent action. `BackupProvider.incrementalBackup(IncrementalBackupConfig)` and `S3BackupProvider.incrementalBackup(IncrementalBackupConfig)` are new methods that don't modify existing `backup()`.
- **UI placement**: Desktop & Mobile. Each target (WebDAV, S3, Local) gets its own incremental section within its existing card, with date picker + [↻] shortcut + settings toggle + includeFiles toggle + separate action button.
- **User-visible behaviors**:
  - Export filename always starts with `cuplivo_incr_`
  - Export includes settings if `includeSettings=true`, includes files if `includeFiles=true` (filtered by mtime)
  - Import automatically skips mode selection for `cuplivo_incr_` files
  - Empty export (0 conversations matched) shows a confirmation warning before producing the file

## Multi-AI Comparison Mode (Side-by-side)

- **Trigger**: 
  - **User messages**: No entry point.
  - **Assistant messages**: MessageMoreSheet "Multi AI" action → "让其他 AI 也回答". Uses pre-selected models from model selector; if none pre-selected, opens multi-model selector via `showMultiModelSelector()`. Comparison starts **immediately** via `startRoundFromHistory()`.
  - **Model selector**: Dual-mode (single/multi) in `_ModelSelectSheet`. Select ≥2 models → 确定 → enters multi-AI mode via `multiAIEngine.enter()`.
- **Data model**: `ChatMessage.subgroupId` (nullable TEXT). Within the same `groupId`, multiple `subgroupId`s represent different model responses as **cards**. `subgroupId = null` messages follow existing collapse/version behavior.
- **Card rendering**: When a `groupId` has any message with `subgroupId != null`, render cards (PageView) instead of a single collapsed message. Each card shows one subgroup's selected version using full `ChatMessageWidget`.
- **Resolve (adopt)**: ALL threads across ALL rounds get `subgroupId = NULL`, reassigned continuous versions, adopt version stored in `versionSelections[groupId]`. Exits card mode. Exits multi-AI engine mode.
- **Drop**: A single thread's messages get `subgroupId = NULL` (keeping version), exits that card but stays in version pool. Model pool shrinks by 1 via `removeThread()`. Physical DB rows unchanged.
- **Streaming**: N concurrent streams, each writing to their own messageId. Existing `StreamingContentNotifier` per-message architecture handles this.
- **Engine state** (MultiAIEngine, in-memory only): `_models`, `_threadIds`, `_isActive`. NOT persisted — recovery happens from `ChatMessage.subgroupId` + `providerId`/`modelId` in conversation history.
- **Persistence recovery**: On conversation switch via `switchConversationAnimated`, scan `_messages` for `subgroupActiveGroupIds`, extract `{providerId, modelId}` from latest round's subgroup messages, restore model selector badge via `multiAIEngine.recoverFromMessages()`.
- **Mode lifecycle**:
  - Enter: Select ≥2 models → 确定. Or: assistant message "更多" + trigger.
  - Lock: Once active, model selector button is locked → shows pill badge with ✕ and model count. Click shows snackbar "多 AI 模式已激活".
  - Exit: Click ✕ on badge, resolve (adopt), deselect to 1 model, switch conversation.
  - Drop: Reduces model pool synchronously via `removeThread()`.
- **Model selector interaction**:
  - Normal: single-select (existing behavior).
  - Multi-select mode: checkboxes in `_ModelSelectSheet` + 确定 button. Long-press still opens ProvidersPage.
  - When N≥2 selected → enter multi-AI mode.
  - When locked: click → snackbar toast.
- **Send behavior**: When multi-AI mode active, typing send triggers `startRound` for ALL models (N parallel threads).
- **startRoundFromHistory**: Called when user clicks "让其他 AI 也回答". Finds preceding user message, assigns it `roundGroupId` (persisted via `chatService.updateMessage` with `groupId`), creates N assistant placeholders with `subgroupId`s, starts N streams using conversation history as API context. No new user message created.
- **UI**: `MultiAICardGroup` with PageView (horizontal swipe). Card has Resolve ✓ / Drop ✕ per card. `ChatInputBar` retained with badge `{count} 个模型` and ✕ button.

## Image Attachment Compression

- **Trigger**: Per-image via clicking file size label below thumbnail; batch via dialog's "全部压缩" button. All ingress paths (gallery, camera, file picker, drag-and-drop, clipboard paste) treated identically.
- **Dialog**: `ImageCompressionDialog` in `lib/shared/dialogs/image_compression_dialog.dart`. Follows incremental backup pattern: `show()` for desktop (centered Dialog), `showSheet()` for mobile (bottom sheet). Same content, different shell.
- **Dialog controls**: Quality slider (30-100), max-dimension slider (320 to original long-edge, step 64px, shortcuts: 原始 / 1/2 / 1/4), format option (仅在有 alpha 通道的 PNG 时显示: "保留透明度 PNG" / "转为 JPEG 白色背景").
- **Format detection**: Done in `_openCompressionDialog` via `img.decodeImage()` (pure Dart, no GPU). Detects real pixel transparency (`decoded.hasAlpha && any(px.a < maxChannelValue)`). Result passed to dialog as `hasRealAlpha`. Eliminates separate file header parsing.
- **Compression core**: `ImageCompressor.compressIfNeeded()` in `lib/utils/image_compressor.dart` (credit: Ankairis, PR #705). Decode/encode in background isolate via `compute()`. Parameters: `quality` (1-100), `maxDimension` (resize longest edge, maintain aspect ratio), `keepPng` (override format detection). Defensive: on exception or result≥original, return original path unchanged.
- **File strategy**: Compressed result written to same dir, same basename, new extension (e.g. `photo.png` → `photo.jpg`). Original file deleted. `_images` path updated accordingly.
- **UI**: File size shown as gradient overlay at bottom of each 64×64 thumbnail, with `Lucide.ImageDown` icon. Tappable → opens dialog. `_imageSizes` cache maintained alongside `_images` to avoid repeated disk reads.
- **Compression progress**: Dialog buttons show loading spinner while compressing. Single "压缩" or "全部压缩" (后者仅在 totalImageCount > 1 时可用).
