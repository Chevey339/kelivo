# Changelog

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
