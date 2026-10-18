import 'package:flutter/widgets.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/atom-one-dark-reasonable.dart';
import 'package:highlight/highlight.dart' show Node, highlight;
import 'package:markstream/markstream.dart';
import 'package:Kelivo/shared/cache/byte_lru_cache.dart';

// Cache syntax trees, not styled spans, so changing the theme does not reparse.
final _nodes = ByteLruCache<String, List<Node>>(
  maxBytes: 8 << 20,
  sizeOf: (key, nodes) {
    var bytes = key.length * 2;
    final pending = [...nodes];
    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      bytes +=
          64 +
          (node.value?.length ?? 0) * 2 +
          (node.className?.length ?? 0) * 2;
      pending.addAll(node.children ?? const []);
    }
    return bytes;
  },
);
@visibleForTesting
int debugHighlightParseCount = 0;
@visibleForTesting
void debugResetHighlightNodeCache() {
  _nodes.clear();
  debugHighlightParseCount = 0;
}

class KelivoCodeHighlighter implements CodeHighlighter {
  const KelivoCodeHighlighter();
  @override
  TextSpan highlight(
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
    try {
      var nodes = _nodes.get(key);
      if (nodes == null) {
        debugHighlightParseCount++;
        nodes = _parse(source, languageId);
        _nodes.put(key, nodes);
      }
      List<TextSpan> convert(List<Node> nodes) => [
        for (final node in nodes)
          TextSpan(
            text: node.value,
            children: node.value == null && node.children != null
                ? convert(node.children!)
                : null,
            style: theme[node.className],
          ),
      ];
      final span = TextSpan(
        style: style.copyWith(backgroundColor: const Color(0x00000000)),
        children: convert(nodes),
      );
      return span.toPlainText() == source
          ? span
          : TextSpan(text: source, style: style);
    } catch (_) {
      return TextSpan(text: source, style: style);
    }
  }
}

// Keep this separate from the interface method of the same name.
List<Node> _parse(String source, String language) =>
    highlight.parse(source, language: language).nodes ?? const [];

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
