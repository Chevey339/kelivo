/// Provider family used to tailor JSON Schema sanitization and API payloads.
///
/// Kept in its own dependency-free file so pure, Flutter-independent logic
/// (e.g. tool schema sanitization in `tool_schema_sanitizer.dart`) can depend
/// on it without importing the Flutter-heavy `SettingsProvider`.
///
/// Re-exported from `settings_provider.dart` for backward compatibility with
/// the many existing `import '.../settings_provider.dart'` call sites.
enum ProviderKind { openai, google, claude }
