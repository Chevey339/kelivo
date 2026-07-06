# Changelog

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
