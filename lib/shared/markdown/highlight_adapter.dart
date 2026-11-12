import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/atom-one-dark-reasonable.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:markstream/markstream.dart';
import 'package:Kelivo/shared/cache/byte_lru_cache.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

// Cache syntax trees, not styled spans, so changing the theme does not reparse.
final _nodes = ByteLruCache<String, DataNode>(
  maxBytes: 8 << 20,
  sizeOf: (key, nodes) {
    var bytes = key.length * 2;
    final pending = <dynamic>[nodes];
    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      if (node is String) {
        bytes += 32 + node.length * 2;
      } else if (node is DataNode) {
        bytes += 64 + (node.scope?.length ?? 0) * 2;
        pending.addAll(node.children);
      }
    }
    return bytes;
  },
);
final _pending = <String, Future<DataNode>>{};
final _parser = Highlight()..registerLanguages(builtinAllLanguages);
@visibleForTesting
int debugHighlightParseCount = 0;
@visibleForTesting
void debugResetHighlightNodeCache() {
  _nodes.clear();
  debugHighlightParseCount = 0;
}

class KelivoCodeHighlighter implements CodeHighlighter {
  const KelivoCodeHighlighter({this.wallpaper = false});
  final bool wallpaper;

  factory KelivoCodeHighlighter.forTheme(MarkstreamTheme theme) =>
      theme.backdrop == MarkstreamBackdrop.wallpaper ||
          theme.backdrop == MarkstreamBackdrop.frostedBubble
      ? const KelivoCodeHighlighter(wallpaper: true)
      : const KelivoCodeHighlighter();
  @override
  FutureOr<TextSpan> highlight(
    String source, {
    required String language,
    required TextStyle style,
    required Brightness brightness,
  }) {
    final languageId = normalizeCodeLanguage(language) ?? 'plaintext';
    final key = '$languageId\u0000$source';
    final theme = brightness == Brightness.dark
        ? atomOneDarkReasonableTheme
        : githubTheme;
    final mutedStyles = brightness == Brightness.dark
        ? (wallpaper ? _wallpaperDarkMuted : _plainDarkMuted)
        : (wallpaper ? _wallpaperLightMuted : _plainLightMuted);
    TextStyle? syntaxStyle(String? name) {
      // Modern grammars use scopes such as title.function and variable.language.
      final scope = theme.containsKey(name) ? name : name?.split('.').first;
      final raw = theme[scope]?.merge(mutedStyles[scope]) ?? mutedStyles[scope];
      final weight = raw?.fontWeight;
      if (weight == null) return raw;
      final normalized = AppFontWeights.normalize(weight);
      return normalized == weight ? raw : raw!.copyWith(fontWeight: normalized);
    }

    List<TextSpan> convert(DataNode node) => [
      for (final child in node.children)
        if (child is String)
          TextSpan(text: child)
        else if (child is DataNode)
          TextSpan(style: syntaxStyle(child.scope), children: convert(child)),
    ];
    TextSpan styled(DataNode nodes) {
      final span = TextSpan(
        style: style.copyWith(backgroundColor: const Color(0x00000000)),
        children: convert(nodes),
      );
      return span.toPlainText() == source
          ? span
          : TextSpan(text: source, style: style);
    }

    try {
      final nodes = _parseCached(source, languageId, key);
      return nodes is DataNode
          ? styled(nodes)
          : nodes.then(
              styled,
              onError: (Object error, StackTrace stack) =>
                  TextSpan(text: source, style: style),
            );
    } catch (_) {
      return TextSpan(text: source, style: style);
    }
  }
}

// Color overrides inherit upstream emphasis, normalized for the app platform.
// Changing the backdrop or platform reuses the cached syntax tree.
const _plainLightMuted = <String, TextStyle>{
  'comment': TextStyle(color: Color(0xff57606a), fontStyle: FontStyle.italic),
  'quote': TextStyle(color: Color(0xff57606a), fontStyle: FontStyle.italic),
  'meta': TextStyle(color: Color(0xff57606a)),
};
const _plainDarkMuted = <String, TextStyle>{
  'comment': TextStyle(color: Color(0xff9da5b0), fontStyle: FontStyle.italic),
  'quote': TextStyle(color: Color(0xff9da5b0), fontStyle: FontStyle.italic),
  'meta': TextStyle(color: Color(0xff9da5b0)),
};
const _wallpaperLightMuted = <String, TextStyle>{
  'comment': TextStyle(color: Color(0xff4a525c), fontStyle: FontStyle.italic),
  'quote': TextStyle(color: Color(0xff4a525c), fontStyle: FontStyle.italic),
  'meta': TextStyle(color: Color(0xff4a525c)),
};
const _wallpaperDarkMuted = <String, TextStyle>{
  'comment': TextStyle(color: Color(0xffbdc5d0), fontStyle: FontStyle.italic),
  'quote': TextStyle(color: Color(0xffbdc5d0), fontStyle: FontStyle.italic),
  'meta': TextStyle(color: Color(0xffbdc5d0)),
};

FutureOr<DataNode> _parseCached(String source, String language, String key) {
  final cached = _nodes.get(key);
  if (cached != null) return cached;
  final pending = _pending[key];
  if (pending != null) return pending;
  debugHighlightParseCount++;
  if (source.length <= PerformanceLimits.highlightCharacters &&
      '\n'.allMatches(source).length < PerformanceLimits.highlightLines) {
    final result = _parseCode((source, language));
    _nodes.put(key, result);
    return result;
  }
  // Parse the complete block off the UI isolate so embedded languages and
  // multiline tokens retain their context without blocking scrolling.
  return _pending[key] = compute(_parseCode, (source, language))
      .then((result) {
        _nodes.put(key, result);
        return result;
      })
      .whenComplete(() {
        _pending.remove(key);
      });
}

DataNode _parseCode((String, String) input) {
  final (source, language) = input;
  if (_parser.getLanguage(language) == null) {
    return DataNode(children: [source]);
  }
  final tree = _SyntaxTree();
  _parser.highlight(code: source, language: language).render(tree);
  return tree.root!;
}

// Retain only the token tree, not HighlightResult's compiled grammar/state.
// This tree is also safe to transfer from the parsing isolate.
class _SyntaxTree implements HighlightRenderer {
  DataNode? root;
  @override
  void openNode(DataNode node) => root ??= node;
  @override
  void addText(String text) {}
  @override
  void closeNode(DataNode node) {}
}

String? normalizeCodeLanguage(String? lang) {
  if (lang == null || lang.trim().isEmpty) return null;
  final l = lang.trim().toLowerCase();
  switch (l) {
    case 'js':
    case 'javascript':
      return 'javascript';
    case 'ts':
    case 'typescript':
      return 'typescript';
    case 'sh':
    case 'zsh':
    case 'bash':
    case 'shell':
      return 'bash';
    case 'yml':
      return 'yaml';
    case 'py':
    case 'python':
      return 'python';
    case 'rb':
    case 'ruby':
      return 'ruby';
    case 'kt':
    case 'kotlin':
      return 'kotlin';
    case 'java':
      return 'java';
    case 'c#':
    case 'cs':
    case 'csharp':
      return 'csharp';
    case 'objc':
    case 'objectivec':
      return 'objectivec';
    case 'swift':
      return 'swift';
    case 'go':
    case 'golang':
      return 'go';
    case 'php':
      return 'php';
    case 'dart':
      return 'dart';
    case 'json':
      return 'json';
    case 'html':
    case 'svg':
      return 'xml';
    case 'text':
    case 'txt':
    case 'mermaid':
    case 'plantuml':
      return 'plaintext';
    case 'md':
    case 'markdown':
      return 'markdown';
    case 'sql':
      return 'sql';
    default:
      return l; // try as-is
  }
}
