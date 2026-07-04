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

- **Data scope**: Chat data only (conversations + messages + toolEvents + geminiThoughtSigs). Attachments are never included in incremental mode.
- **Filtering unit**: Conversation-level (`createdAt >= since`). Entire conversations that started before `since` are skipped, even if they have recent messages. This is a deliberate trade-off — see `docs/adr/0001-conversation-level-incremental-filtering.md`.
- **File naming**: `cuplivo_backup_<export_timestamp>_incr.zip`. The `_incr` suffix is the single identification mechanism for the restore path.
- **Restore behavior**: `_incr` suffix detected → skip the "Overwrite/Merge" dialog entirely → force `RestoreMode.merge` at both UI and DataSync layers.
- **Date source**: `BackupReminderProvider.lastBackupTime` for the [↻] shortcut. If null, fallback to 30 days ago. User can always override via `showDatePicker()`.
- **`includeSettings`**: Default `true`. Not yet persisted (planned for a future PR).
- **Architecture**: Incremental backup is NOT a mode toggle on full backup — it's a separate independent action. `BackupProvider.incrementalBackup(since, includeSettings)` and `S3BackupProvider.incrementalBackup(since, includeSettings)` are new methods that don't modify existing `backup()`.
- **UI placement**: Desktop only. Each target (WebDAV, S3, Local) gets its own incremental section within its existing card, with date picker + [↻] shortcut + settings toggle + separate action button.
- **User-visible behaviors**:
  - Export filename always bears `_incr` suffix
  - Export includes settings if `includeSettings=true` (never attachments)
  - Import automatically skips mode selection for `_incr` files
  - Empty export (0 conversations matched) shows a confirmation warning before producing the file

## Planned but Deferred In-Box

Features agreed to be valuable but intentionally deferred:

- **Message-level filtering** — instead of skipping entire conversations, filter individual messages by `timestamp >= since`
- **Incremental with attachments** — scan exported messages' `[image:...]` / `[file:...]` tags to pack only referenced files
- **Mobile incremental UI** — `backup_page.dart` incremental section (core logic already shared)
- **`includeSettings` persistence** — remember the last toggle value across sessions via SharedPreferences
- **Conversation title reference in date picker** — show recent conversation titles as date reference points during `since` selection

