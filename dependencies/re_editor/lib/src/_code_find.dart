part of 're_editor.dart';

class _CodeFindControllerImpl extends ValueNotifier<CodeFindValue?> implements CodeFindController {

  late final CodeLineEditingController _controller;
  late final _IsolateTasker<_CodeFindPayload, CodeFindResult?> _tasker;
  late final TextEditingController _findInputController;
  late final FocusNode _findInputFocusNode;
  late final TextEditingController _replaceInputController;
  late final FocusNode _replaceInputFocusNode;
  late bool _shouldNotUpdateResults;
  late bool _replacingMatch;

  _CodeFindControllerImpl(CodeLineEditingController controller, [CodeFindValue? value]) : super(value) {
    _controller = controller is _CodeLineEditingControllerDelegate ? controller.delegate : controller;
    _controller.addListener(_updateResult);
    _tasker = _IsolateTasker<_CodeFindPayload, CodeFindResult?>('CodeFind', _run);
    _findInputController = TextEditingController();
    _findInputController.addListener(_onFindPatternChanged);
    _findInputFocusNode = FocusNode();
    _replaceInputController = TextEditingController();
    _replaceInputFocusNode = FocusNode();
    _shouldNotUpdateResults = false;
    _replacingMatch = false;
    _updateResult();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.removeListener(_updateResult);
    _findInputController.removeListener(_onFindPatternChanged);
    _findInputController.dispose();
    _findInputFocusNode.dispose();
    _replaceInputController.dispose();
    _replaceInputFocusNode.dispose();
    _tasker.close();
  }

  @override
  TextEditingController get findInputController => _findInputController;

  @override
  TextEditingController get replaceInputController => _replaceInputController;

  @override
  FocusNode get findInputFocusNode => _findInputFocusNode;

  @override
  FocusNode get replaceInputFocusNode => _replaceInputFocusNode;

  @override
  List<CodeLineSelection>? get allMatchSelections {
    final List<CodeLineSelection>? matches = value?.result?.matches;
    if (matches == null) {
      return null;
    }
    if (value!.result!.dirty) {
      return null;
    }
    final List<CodeLineSelection> selections = [];
    for (final CodeLineSelection match in matches) {
      final CodeLineSelection? selection = convertMatchToSelection(match);
      if (selection == null) {
        continue;
      }
      selections.add(selection);
    }
    return selections;
  }

  @override
  CodeLineSelection? get currentMatchSelection {
    final CodeLineSelection? currentMatch = value?.result?.currentMatch;
    if (currentMatch == null) {
      return null;
    }
    if (value!.result!.dirty) {
      return null;
    }
    return convertMatchToSelection(currentMatch);
  }

  @override
  void findMode() {
    _findInputFocusNode.requestFocus();
    final String? autoFilled = _autoFilledPattern();
    _findInputController.removeListener(_onFindPatternChanged);
    if (autoFilled != null) {
      _findInputController.value = TextEditingValue(
        text: autoFilled,
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: autoFilled.length
        )
      );
    } else {
      _findInputController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _findInputController.text.length
      );
    }
    _findInputController.addListener(_onFindPatternChanged);
    final CodeFindValue preValue = value ?? const CodeFindValue.empty();
    value = preValue.copyWith(
      option: preValue.option.copyWith(
        pattern: _findInputController.text
      ),
      result: null,
      searching: true
    );
    _updateResult();
  }

  @override
  void replaceMode() {
    _replaceInputFocusNode.requestFocus();
    final String? autoFilled = _autoFilledPattern();
    _findInputController.removeListener(_onFindPatternChanged);
    if (autoFilled != null) {
      _findInputController.value = TextEditingValue(
        text: autoFilled,
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: autoFilled.length
        )
      );
    } else {
      _findInputController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _findInputController.text.length
      );
    }
    _findInputController.addListener(_onFindPatternChanged);
    final CodeFindValue preValue = value ?? const CodeFindValue.empty();
    value = preValue.copyWith(
      option: preValue.option.copyWith(
        pattern: _findInputController.text,
      ),
      replaceMode: true,
      result: null,
      searching: true
    );
    _updateResult();
  }

  @override
  void focusOnFindInput() {
    _findInputFocusNode.requestFocus();
    _findInputController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _findInputController.text.length
    );
  }

  @override
  void focusOnReplaceInput() {
    _replaceInputFocusNode.requestFocus();
    _replaceInputController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _replaceInputController.text.length
    );
  }

  @override
  void toggleMode() {
    final CodeFindValue? preValue = value;
    if (preValue == null) {
      return;
    }
    value = preValue.copyWith(
      replaceMode: !preValue.replaceMode,
      result: preValue.result
    );
  }

  @override
  void close() {
    value = null;
  }

  @override
  void toggleRegex() {
    final CodeFindOption? option = value?.option;
    if (option == null) {
      return;
    }
    value = value?.copyWith(
      option: option.copyWith(
        regex: !option.regex,
      ),
      result: null,
      searching: true
    );
    _updateResult();
  }

  @override
  void toggleCaseSensitive() {
    final CodeFindOption? option = value?.option;
    if (option == null) {
      return;
    }
    value = value?.copyWith(
      option: option.copyWith(
        caseSensitive: !option.caseSensitive,
      ),
      result: null,
      searching: true
    );
    _updateResult();
  }

  @override
  void previousMatch() {
    final CodeFindResult? result = value?.result;
    if (result == null || result.dirty) {
      return;
    }
    final CodeFindValue newValue = value!.copyWith(
      result: result.previous
    );
    _expandChunkIfNeeded(newValue);
    value = newValue;
    if (result.matches.length == 1) {
      final CodeLineSelection? selection = currentMatchSelection;
      if (selection != null) {
        _controller.makePositionCenterIfInvisible(selection.start);
      }
    }
  }

  @override
  void nextMatch() {
    final CodeFindResult? result = value?.result;
    if (result == null || result.dirty) {
      return;
    }
    final CodeFindValue newValue = value!.copyWith(
      result: result.next
    );
    _expandChunkIfNeeded(newValue);
    value = newValue;
    if (result.matches.length == 1) {
      final CodeLineSelection? selection = currentMatchSelection;
      if (selection != null) {
        _controller.makePositionCenterIfInvisible(selection.start);
      }
    }
  }

  @override
  void replaceMatch() {
    final CodeFindResult? result = value?.result;
    if (result == null || result.dirty) {
      return;
    }
    if (currentMatchSelection == null) {
      _expandChunkIfNeeded(value!);
    }
    final CodeLineSelection? selection = currentMatchSelection;
    if (selection == null) {
      return;
    }
    _replacingMatch = true;
    final CodeLines preCodeLines = _controller.codeLines;
    _controller.replaceSelection(_replaceInputController.text, selection);
    final CodeFindValue newValue = value!.copyWith(
      result: result.next.copyWith(
        dirty: !preCodeLines.equals(_controller.codeLines)
      )
    );
    _expandChunkIfNeeded(newValue);
    value = newValue;
    _replacingMatch = false;
  }

  @override
  void replaceAllMatches() {
    final CodeFindResult? result = value?.result;
    if (result == null || result.matches.isEmpty || result.dirty) {
      return;
    }
    final CodeFindOption? option = value?.option;
    if (option == null) {
      return;
    }
    final RegExp? regExp = option.regExp;
    if (regExp == null) {
      return;
    }
    _replacingMatch = true;
    final CodeLines preCodeLine = _controller.codeLines;
    _controller.replaceAll(regExp, _replaceInputController.text);
    value = value?.copyWith(
      result: result.copyWith(
        dirty: !preCodeLine.equals(_controller.codeLines)
      )
    );
    _replacingMatch = false;
  }

  @override
  CodeLineSelection? convertMatchToSelection(CodeLineSelection match) {
    final CodeLineIndex baseIndex = _controller.lineIndex2Index(match.baseIndex);
    if (baseIndex.chunkIndex >= 0) {
      // This match is in a collapsed chunk, invisble
      return null;
    }
    final CodeLineIndex extentIndex;
    if (match.isSameLine) {
      extentIndex = baseIndex;
    } else {
      extentIndex = _controller.lineIndex2Index(match.extentIndex);
    }
    if (extentIndex.chunkIndex >= 0) {
      // This match is in a collapsed chunk, invisble
      return null;
    }
    return match.copyWith(
      baseIndex: baseIndex.index,
      extentIndex: extentIndex.index
    );
  }

  void _onFindPatternChanged() {
    final CodeFindOption? option = value?.option;
    if (option == null) {
      return;
    }
    if (_findInputController.text == option.pattern) {
      return;
    }
    value = value?.copyWith(
      option: option.copyWith(
        pattern: _findInputController.text,
      ),
      result: null,
      searching: true
    );
    _updateResult();
  }

  String? _autoFilledPattern() {
    final CodeLineSelection selection = _controller.selection;
    if (selection.isCollapsed || !selection.isSameLine) {
      return null;
    }
    return _controller.selectedText;
  }

  void _updateResult() {
    if (_shouldNotUpdateResults) {
      return;
    }
    final CodeFindOption? option = value?.option;
    if (option == null || option.pattern.isEmpty) {
      value = value?.copyWith(
        result: null,
        searching: false
      );
      return;
    }
    final bool optionChanged = value?.result?.option != option;
    if (!optionChanged && _controller.codeLines.equals(value?.result?.codeLines)) {
      value = value?.copyWith(
        result: value?.result,
        searching: false
      );
      return;
    }
    final _CodeFindPayload payload = _CodeFindPayload(
      codeLines: _controller.codeLines,
      selection: _controller.unfoldLineSelection,
      option: option,
      forwardMatch: !_replacingMatch
    );
    _tasker.run(payload, (result) {
      if (option == value?.option) {
        final CodeFindValue newValue = value!.copyWith(
          result: result,
          searching: false
        );
        if (optionChanged) {
          _expandChunkIfNeeded(newValue);
        }
        value = newValue;
      } else {
        value = value?.copyWith(
          result: null,
          searching: false
        );
      }
    });
  }

  void _expandChunkIfNeeded(CodeFindValue value) {
    _shouldNotUpdateResults = true;
    final CodeLineSelection? match = value.result?.currentMatch;
    if (match != null) {
      _expandChunkIfSelectionInvisible(match);
    }
    _shouldNotUpdateResults = false;
  }

  void _expandChunkIfSelectionInvisible(CodeLineSelection match) {
    if (match.isSameLine) {
      final CodeLineIndex start = _controller.lineIndex2Index(match.startIndex);
      if (start.chunkIndex < 0) {
        return;
      }
      _controller.expandChunk(start.index);
    } else {
      final CodeLineIndex start = _controller.lineIndex2Index(match.startIndex);
      final CodeLineIndex end = _controller.lineIndex2Index(match.endIndex);
      if (start.chunkIndex >= 0) {
        _controller.expandChunk(start.index);
      } else if (end.chunkIndex >= 0) {
        _controller.expandChunk(end.index);
      } else {
        return;
      }
    }
    // If the selection is in a nested chunk, we should expand the chunk from outside one by one
    _expandChunkIfSelectionInvisible(match);
  }

  @pragma('vm:entry-point')
  static CodeFindResult? _run(_CodeFindPayload payload) {
    final RegExp? regExp = payload.option.regExp;
    if (regExp == null) {
      return null;
    }
    final List<String> rawCodeLines = payload.codeLines.toList().fold([], (previousValue, element) {
      previousValue.addAll(element.flat());
      return previousValue;
    });
    final Iterable<Match> matches = regExp.allMatches(rawCodeLines.join(TextLineBreak.lf.value));
    if (matches.isEmpty) {
      return null;
    }
    final List<CodeLineSelection> selections = [];
    for (final Match match in matches) {
      final CodeLinePosition start = _findPosition(rawCodeLines, match.start);
      final CodeLinePosition end = _findPosition(rawCodeLines, match.end);
      selections.add(CodeLineSelection(
        baseIndex: start.index,
        baseOffset: start.offset,
        extentIndex: end.index,
        extentOffset: end.offset
      ));
    }
    int index;
    if (payload.forwardMatch) {
      index = selections.length - 1;
      for (; index > 0; index--) {
        if (selections[index].contains(payload.selection)) {
          break;
        }
        if (selections[index].endIndex < payload.selection.startIndex) {
          break;
        }
        if (selections[index].endIndex == payload.selection.startIndex &&
          selections[index].endOffset <= payload.selection.startOffset) {
          break;
        }
      }
    } else {
      index = 0;
      for (; index < selections.length; index++) {
        if (selections[index].contains(payload.selection)) {
          break;
        }
        if (selections[index].startIndex > payload.selection.endIndex) {
          break;
        }
        if (selections[index].startIndex == payload.selection.endIndex &&
          selections[index].startOffset >= payload.selection.endOffset) {
          break;
        }
      }
    }
    return CodeFindResult(
      index: max(min(index, selections.length - 1), 0),
      matches: selections,
      option: payload.option,
      codeLines: payload.codeLines,
      dirty: false
    );
  }

  static CodeLinePosition _findPosition(List<String> codeLines, int index) {
    int start = 0;
    int line = 0;
    int offset = -1;
    for (; line < codeLines.length; line++) {
      if (index <= start + codeLines[line].length) {
        offset = index - start;
        break;
      }
      start += codeLines[line].length + 1;
    }
    return CodeLinePosition(
      index: line,
      offset: offset
    );
  }

}

class _CodeFindPayload {

  final CodeLines codeLines;
  final CodeLineSelection selection;
  final CodeFindOption option;
  final bool forwardMatch;

  const _CodeFindPayload({
    required this.codeLines,
    required this.selection,
    required this.option,
    required this.forwardMatch,
  });

}