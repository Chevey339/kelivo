import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:markstream/markstream_core.dart';
import 'package:Kelivo/shared/markdown/kelivo_markdown_extensions.dart';

/// Drives the developer preview without modifying the editor's complete source.
class MarkdownPlaygroundModel extends ChangeNotifier {
  MarkdownPlaygroundModel(String source) {
    setSource(source);
  }
  ParserOptions _options = const ParserOptions();
  IncrementalDocument _parser = _newParser(const ParserOptions());
  static IncrementalDocument _newParser(ParserOptions options) =>
      IncrementalDocument(
        parser: MarkdownParser(
          options: options,
          inlineSyntaxes: kelivoMarkdownExtensions.inlineSyntaxes,
        ),
      );
  void setParserOptions(ParserOptions options) {
    if (identical(options, _options)) return;
    _options = options;
    _parser = _newParser(options);
    _publish();
  }

  Timer? _timer;
  String _source = '', _displayed = '';
  int _cursor = 0, _shown = 0, _total = 0;
  bool _session = false;
  late DocumentNode _document;
  String get source => _source;
  String get displayed => _displayed;
  DocumentNode get document => _document;
  int get shown => _shown;
  int get total => _total;
  bool get playing => _timer != null;
  bool get streaming => _session && _cursor < _source.length;
  void setSource(String source) {
    _timer?.cancel();
    _timer = null;
    _source = source;
    _session = false;
    _cursor = source.length;
    _total = source.runes.length;
    _shown = _total;
    _publish();
  }

  void play() {
    if (_source.isEmpty || playing) return;
    if (!streaming) {
      _cursor = 0;
      _shown = 0;
      _session = true;
      _publish();
    }
    _timer = Timer.periodic(
      const Duration(milliseconds: 30),
      (_) => _advance(),
    );
    notifyListeners();
  }

  void _advance() {
    if (_cursor >= _source.length) {
      showAll();
      return;
    }
    final unit = _source.codeUnitAt(_cursor++);
    if (unit >= 0xd800 && unit <= 0xdbff && _cursor < _source.length) {
      final next = _source.codeUnitAt(_cursor);
      if (next >= 0xdc00 && next <= 0xdfff) _cursor++;
    }
    _shown++;
    if (_cursor == _source.length) {
      _timer?.cancel();
      _timer = null;
      _session = false;
    }
    _publish();
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void showAll() {
    _timer?.cancel();
    _timer = null;
    _session = false;
    _cursor = _source.length;
    _shown = _total;
    _publish();
  }

  void _publish() {
    _displayed = _source.substring(0, _cursor);
    _document = _parser.update(_displayed, streaming: streaming);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
