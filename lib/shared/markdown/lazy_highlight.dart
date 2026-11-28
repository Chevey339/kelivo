import 'package:re_highlight/re_highlight.dart';

import 'highlight_languages.g.dart';

class LazyHighlight {
  Highlight _parser = Highlight();
  final _loaded = <String>{};

  Set<String> get loadedLanguages => Set.unmodifiable(_loaded);

  String? _load(String name) {
    if (_loaded.contains(name)) return name;
    final lower = name.toLowerCase();
    final id = highlightLanguageFactories.containsKey(lower)
        ? lower
        : highlightLanguageAliases[lower];
    if (id == null || !_loaded.add(id)) return id;

    final embedded = highlightEmbeddedLanguages[id];
    if (embedded != null && embedded.isEmpty) {
      // Auto-detection breaks ties in registry order, even after other
      // languages have been requested in a different order.
      _parser = Highlight()
        ..registerLanguages({
          for (final entry in highlightLanguageFactories.entries)
            entry.key: entry.value(),
        });
      _loaded.addAll(highlightLanguageFactories.keys);
    } else {
      _parser.registerLanguage(id, highlightLanguageFactories[id]!());
      if (embedded != null) {
        for (final dependency in embedded) {
          _load(dependency);
        }
      }
    }
    return id;
  }

  Mode? getLanguage(String name) {
    final id = _load(name);
    return id == null ? null : _parser.getLanguage(id);
  }

  HighlightResult? highlight({required String code, required String language}) {
    final id = _load(language);
    return id == null ? null : _parser.highlight(code: code, language: id);
  }
}
