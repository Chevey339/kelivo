part of 're_editor.dart';

class CodeChunkController extends ValueNotifier<List<CodeChunk>> {

  late final CodeLineEditingController _controller;
  final CodeChunkAnalyzer _analyzer;

  late final _IsolateTasker<_CodeChunkAnalyzePayload, _CodeChunkAnalyzeResult> _tasker;

  late bool _shouldNotUpdateChunks;

  CodeChunkController(CodeLineEditingController controller, this._analyzer) : super(const []) {
    _controller = controller is _CodeLineEditingControllerDelegate ? controller.delegate : controller;
    _controller.addListener(_onCodeChanged);
    _tasker = _IsolateTasker<_CodeChunkAnalyzePayload, _CodeChunkAnalyzeResult>('CodeChunk', _run);
    _shouldNotUpdateChunks = false;
    _runChunkAnalyzeTask();
  }

  void collapse(int index) {
    final CodeChunk? chunk = findByIndex(index);
    if (chunk == null) {
      // Not support to collapse
      return;
    }
    if (!chunk.canCollapse) {
      // Has collapsed or nothing to collapse
      return;
    }
    final List<CodeChunk> codeChunks = List.of(value);
    // Remove sub chunks
    codeChunks.removeWhere((e) => e.index > chunk.index && e.end < chunk.end);
    // Chunks after the collapsed should adjust the offset
    for (int i = 0; i < codeChunks.length; i++) {
      final CodeChunk e = codeChunks[i];
      if (e.index >= index || e.end >= index) {
        codeChunks[i] = CodeChunk(e.index > index ? e.index - chunk.collapseSize : e.index,
          e.end > index ? e.end - chunk.collapseSize : e.end
        );
      }
    }
    value = codeChunks;
    _shouldNotUpdateChunks = true;
    _controller.collapseChunk(chunk.index, chunk.end);
    _shouldNotUpdateChunks = false;
  }

  void expand(int index) {
    final CodeLine codeLine = _controller.codeLines[index];
    if (!codeLine.chunkParent) {
      // Nothing to expand, this should not happen.
      return;
    }
    final List<CodeChunk> codeChunks = List.of(value);
    bool exists = false;
    for (int i = 0; i < codeChunks.length; i++) {
      final CodeChunk e = codeChunks[i];
      if (e.index >= index || e.end >= index) {
        codeChunks[i] = CodeChunk(e.index > index ? e.index + codeLine.chunks.length : e.index,
          e.end > index ? e.end + codeLine.chunks.length : e.end
        );
      }
      if (e.index == index) {
        exists = true;
      }
    }
    // Add self into the chunks if not exists
    if (!exists) {
      codeChunks.add(CodeChunk(index, index + codeLine.chunks.length + 1));
      // sort by index
      codeChunks.sort((a, b) => a.index - b.index);
    }
    value = codeChunks;
    _controller.expandChunk(index);
  }

  void toggle(int index) {
    if (_controller.codeLines[index].chunkParent) {
      expand(index);
    } else {
      collapse(index);
    }
  }

  CodeChunk? findByIndex(int index) {
    for (final CodeChunk chunk in value) {
      if (chunk.index == index) {
        return chunk;
      } else if (chunk.index > index) {
        break;
      }
    }
    return null;
  }

  bool canCollapse(int index) {
    return findByIndex(index)?.canCollapse ?? false;
  }

  @override
  void dispose() {
    _controller.removeListener(_onCodeChanged);
    _tasker.close();
    super.dispose();
  }

  void _onCodeChanged() {
    if (_shouldNotUpdateChunks) {
      return;
    }
    if (_plainDocument) return;
    if (_controller.codeLines.length < 3 && value.isEmpty) {
      value = [];
      return;
    }
    if (_controller.codeLines.equals(_controller.preValue?.codeLines)) {
      return;
    }
    _runChunkAnalyzeTask();
  }

  void _runChunkAnalyzeTask() {
    if (_plainDocument) return;
    final CodeLines codeLines = _controller.codeLines;
    _tasker.run(_CodeChunkAnalyzePayload(_analyzer, codeLines), (result) {
      if (_controller.codeLines.equals(codeLines)) {
        value = result.chunks;
        _expandInvalidCollapsedChunks(result.invalidCollapsedChunkIndexes);
      }
    });
  }

  // Plain messages have no foldable chunks. Avoid serializing the entire
  // document to an isolate after every keystroke for an always-empty result.
  bool get _plainDocument => _analyzer is NonCodeChunkAnalyzer &&
    _controller.codeLines.lineCount == _controller.codeLines.length;

  void _expandInvalidCollapsedChunks(List<int> indexes) {
    // Expand invalid chunks from bottom to top
    for (int i = indexes.length - 1; i >=0; i--) {
      expand(indexes[i]);
    }
  }

  @pragma('vm:entry-point')
  static _CodeChunkAnalyzeResult _run(_CodeChunkAnalyzePayload payload) {
    final List<CodeChunk> chunks = payload.analyzer.run(payload.codeLines);
    final List<int> invalidCollapsedChunkIndexes = [];
    for (int i = 0; i < payload.codeLines.length; i++) {
      if (!payload.codeLines[i].chunkParent) {
        continue;
      }
      final int index = chunks.indexWhere((e) => e.index == i);
      if (index < 0 || chunks[index].canCollapse) {
        invalidCollapsedChunkIndexes.add(i);
      }
    }
    return _CodeChunkAnalyzeResult(chunks, invalidCollapsedChunkIndexes);
  }

}

class CodeChunk {

  final int index;
  final int end;

  const CodeChunk(this.index, this.end);

  bool get canCollapse => collapseSize > 0;

  int get collapseSize => end - index - 1;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeChunk
        && other.index == index
        && other.end == end;
  }

  @override
  int get hashCode => Object.hash(index, end);

  @override
  String toString() {
    return '[$index, $end]';
  }

}

abstract class CodeChunkAnalyzer {

  List<CodeChunk> run(CodeLines codeLines);

}

class NonCodeChunkAnalyzer implements CodeChunkAnalyzer {

  const NonCodeChunkAnalyzer();

  @override
  List<CodeChunk> run(CodeLines codeLines) => const [];

}

class DefaultCodeChunkAnalyzer implements CodeChunkAnalyzer {

  static const Map<String, String> _chunkSymbols = {
    '(': ')',
    '[': ']',
    '{': '}'
  };
  static final List<int> _tokens = '"\'()[]{}'.codeUnits;

  const DefaultCodeChunkAnalyzer();

  @override
  List<CodeChunk> run(CodeLines codeLines) {
    final List<CodeChunk> chunks = [];
    final List<CodeChunkSymbol> stack = [];
    final List<CodeChunkSymbol> chunkSymbols = parse(codeLines);
    for (final CodeChunkSymbol symbol in chunkSymbols) {
      if (_chunkSymbols.keys.contains(symbol.value)) {
        stack.add(symbol);
        continue;
      }
      while(stack.isNotEmpty) {
        final CodeChunkSymbol pop = stack.removeLast();
        if (_chunkSymbols[pop.value] == symbol.value) {
          if (symbol.index - pop.index >= 1 && chunks.where((e) => e.index == pop.index).isEmpty) {
            chunks.add(CodeChunk(pop.index, symbol.index));
          }
          break;
        }
      }
    }
    // sort by index
    chunks.sort((a, b) => a.index - b.index);
    return chunks;
  }

  @visibleForTesting
  List<CodeChunkSymbol> parse(CodeLines codeLines) {
    final List<CodeChunkSymbol> symbols = [];
    for (int i = 0; i < codeLines.length; i++) {
      final String text = codeLines[i].text.trim();
      if (text.isEmpty) {
        continue;
      }
      symbols.addAll(_parseLine(text, i));
    }
    return symbols;
  }

  List<CodeChunkSymbol> _parseLine(String text, int index) {
    final List<CodeChunkSymbol> symbols = [];
    const int normal = 0;
    const int inQuote = 1;
    const int inDoubleQuote = 2;
    bool inEscapeQuote = false;
    bool inEscapeDoubleQuote = false;
    int state = normal;
    final List<int> codeUnits = text.codeUnits;
    for (int i = 0; i < codeUnits.length; i++) {
      if (!_tokens.contains(codeUnits[i])) {
        continue;
      }
      final String character = String.fromCharCode(codeUnits[i]);
      if (state == inQuote) {
        if (character == '\'' && !isPreEscapeChar(codeUnits, i)) {
          state = normal;
        }
      } else if (state == inDoubleQuote) {
        if (character == '"' && !isPreEscapeChar(codeUnits, i)) {
          state = normal;
        }
      } else {
        if (character == '\'') {
          if (inEscapeQuote) {
            if (isPreEscapeChar(codeUnits, i)) {
              inEscapeQuote = false;
            } else {
              // Unbalanced escape quotes
              break;
            }
          } else {
            if (isPreEscapeChar(codeUnits, i)) {
              inEscapeQuote = true;
            } else {
              state = inQuote;
            }
          }
        } else if (character == '"') {
          if (inEscapeDoubleQuote) {
            if (isPreEscapeChar(codeUnits, i)) {
              inEscapeDoubleQuote = false;
            } else {
              // Unbalanced escape double quotes
              break;
            }
          } else {
            if (isPreEscapeChar(codeUnits, i)) {
              inEscapeDoubleQuote = true;
            } else {
              state = inDoubleQuote;
            }
          }
        } else {
          if (!inEscapeQuote && !inEscapeDoubleQuote) {
            symbols.add(CodeChunkSymbol(character, index));
          }
        }
      }
    }
    return symbols;
  }

  bool isPreEscapeChar(List<int> codeUnits, int index) {
    return index > 0 && codeUnits[index - 1] == '\\'.codeUnits.first;
  }

}

class CodeChunkSymbol {

  final String value;
  final int index;

  const CodeChunkSymbol(this.value, this.index);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeChunkSymbol
        && other.value == value
        && other.index == index;
  }

  @override
  int get hashCode => Object.hash(value, index);

  @override
  String toString() {
    return '$value@$index';
  }

}

class _CodeChunkAnalyzePayload {

  final CodeChunkAnalyzer analyzer;
  final CodeLines codeLines;

  const _CodeChunkAnalyzePayload(this.analyzer, this.codeLines);

}

class _CodeChunkAnalyzeResult {

  final List<CodeChunk> chunks;
  final List<int> invalidCollapsedChunkIndexes;

  const _CodeChunkAnalyzeResult(this.chunks, this.invalidCollapsedChunkIndexes);

}
