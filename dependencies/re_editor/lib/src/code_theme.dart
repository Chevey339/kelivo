part of 're_editor.dart';

/// The code syntax highlighting theme. We use Re-Highlight as the syntax highlighting rule.
/// Re-Highlight provides some built-in syntax highlighting rules for dozens of programming languages,
/// and many theme styles.
///
/// Please see [Re-Highlight](https://reqable/re-highlight).
class CodeHighlightTheme {

  const CodeHighlightTheme({
    required this.languages,
    required this.theme,
    this.plugins = const [],
  });

  /// Supported syntax highlighting language rules.
  final Map<String, CodeHighlightThemeMode> languages;

  /// The syntax highlighting style theme.
  final Map<String, TextStyle> theme;

  /// The plugins for syntax highlighting.
  final List<HLPlugin> plugins;

  @override
  int get hashCode => Object.hash(languages, theme, plugins);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeHighlightTheme
        && mapEquals(other.languages, languages)
        && mapEquals(other.theme, theme)
        && listEquals(other.plugins, plugins);
  }

}

/// Define language rules and restrictions for highlighting.
///
/// Since the dart stack capacity is relatively small, stack overflow may occur
/// when executing syntax highlighting, so we added some restrictions to disable
/// syntax highlighting.
///
/// The issue see https://github.com/dart-lang/sdk/issues/48425
class CodeHighlightThemeMode {

  const CodeHighlightThemeMode({
    required this.mode,
    this.maxSize = 4 * 1024 * 1024,
    this.maxLineLength = 1 * 1024 * 1024,
  });

  /// Syntax highlighting language rule.
  final Mode mode;

  /// If the total text length is higher than this value, syntax highlighting
  /// will not be performed.
  ///
  /// The default value is 4MB.
  final int maxSize;

  /// If the text length of a line is higher than this value, syntax highlighting
  /// will not be performed.
  ///
  /// The default value is 1MB.
  final int maxLineLength;

  @override
  int get hashCode => Object.hash(mode, maxSize, maxLineLength);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeHighlightThemeMode
        && mode == other.mode && maxSize == other.maxSize
        && maxLineLength == other.maxLineLength;
  }

}

extension CodeHighlightThemeModeExtension on Mode {

  CodeHighlightThemeMode get themeMode => CodeHighlightThemeMode(mode: this);

}