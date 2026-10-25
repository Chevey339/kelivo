part of 're_editor.dart';

class _DefaultCodeCommentFormatter implements DefaultCodeCommentFormatter {

  final String? singleLinePrefix;
  final String? multiLinePrefix;
  final String? multiLineSuffix;

  const _DefaultCodeCommentFormatter({
    this.singleLinePrefix,
    this.multiLinePrefix,
    this.multiLineSuffix
  });

  @override
  CodeLineEditingValue format(CodeLineEditingValue value, String indent, bool single) {
    if (single && (singleLinePrefix == null || singleLinePrefix!.isEmpty)) {
      return value;
    }
    if (!single && (multiLinePrefix == null || multiLinePrefix!.isEmpty) && (multiLineSuffix == null || multiLineSuffix!.isEmpty)) {
      return value;
    }
    final _DefaultCommentFormatter formatter;
    if (single) {
      formatter = _DefaultSingleLineCommentFormatter(singleLinePrefix!);
    } else {
      formatter = _DefaultMultiLineCommentFormatter(multiLinePrefix!,  multiLineSuffix!);
    }
    return formatter.format(value, indent);
  }

}

abstract class _DefaultCommentFormatter {

  final String symbol;

  const _DefaultCommentFormatter(this.symbol);

  CodeLineEditingValue format(CodeLineEditingValue value, String indent);

}

class _DefaultSingleLineCommentFormatter extends _DefaultCommentFormatter {
  const _DefaultSingleLineCommentFormatter(super.symbol);

  @override
  CodeLineEditingValue format(CodeLineEditingValue value, String indent) {
    final CodeLineSelection selection = value.selection;
    if (selection.isSameLine) {
      return _formatSelectedCodeLine(value, indent);
    } else {
      return _formatSelectedCodeLines(value, indent);
    }
  }

  CodeLineEditingValue _formatSelectedCodeLine(CodeLineEditingValue value, String indent) {
    final String trimCode = value.codeLines[value.selection.baseIndex].text.trimLeft();
    if (trimCode.startsWith('$symbol ')) {
      return _uncommentSelectedCodeLine(value, '$symbol ');
    } else if (trimCode.startsWith(symbol)) {
      return _uncommentSelectedCodeLine(value, symbol);
    } else {
      return _commentSelectedCodeLine(value, indent, '$symbol ');
    }
  }

  CodeLineEditingValue _uncommentSelectedCodeLine(CodeLineEditingValue value, String prefix) {
    final CodeLineSelection selection = value.selection;
    final CodeLines codeLines = value.codeLines;
    final int lineIndex = selection.baseIndex;
    final CodeLine codeLine = codeLines[lineIndex];
    final int index = codeLine.text.indexOf(prefix);
    final CodeLines newCodeLines = CodeLines.from(codeLines);
    newCodeLines[lineIndex] = codeLine.copyWith(
      text: codeLine.text.substring(0, index) + codeLine.text.substring(index + prefix.length)
    );
    int relocation(int offset) {
      if (offset <= index) {
        return offset;
      } else {
        return max(index, offset - prefix.length);
      }
    }
    return value.copyWith(
      codeLines: newCodeLines,
      selection: selection.copyWith(
        baseOffset: relocation(selection.baseOffset),
        extentOffset: relocation(selection.extentOffset),
      )
    );
  }

  CodeLineEditingValue _commentSelectedCodeLine(CodeLineEditingValue value, String indent, String prefix) {
    final CodeLineSelection selection = value.selection;
    final CodeLines codeLines = value.codeLines;
    final int lineIndex = selection.baseIndex;
    final CodeLine codeLine = codeLines[lineIndex];
    final int index = codeLine.text.getOffsetWithoutIndent(indent);
    final CodeLines newCodeLines = CodeLines.from(codeLines);
    newCodeLines[lineIndex] = codeLine.copyWith(
      text: codeLine.text.insert(prefix, index)
    );
    final int baseOffset;
    final int extentOffset;
    if (selection.isCollapsed) {
      if (selection.baseOffset < index) {
        baseOffset = extentOffset = selection.baseOffset;
      } else {
        baseOffset = extentOffset = selection.baseOffset + prefix.length;
      }
    } else {
      if (selection.startOffset < index && selection.endOffset > index) {
        if (selection.baseOffset < index) {
          baseOffset = selection.baseOffset;
          extentOffset = selection.extentOffset + prefix.length;
        } else {
          extentOffset = selection.extentOffset;
          baseOffset = selection.baseOffset + prefix.length;
        }
      } else if (selection.startOffset >= index) {
        baseOffset = selection.baseOffset + prefix.length;
        extentOffset = selection.extentOffset + prefix.length;
      } else {
        baseOffset = selection.baseOffset;
        extentOffset = selection.extentOffset;
      }
    }
    return value.copyWith(
      codeLines: newCodeLines,
      selection: selection.copyWith(
        baseOffset: baseOffset,
        extentOffset: extentOffset,
      )
    );
  }

  CodeLineEditingValue _formatSelectedCodeLines(CodeLineEditingValue value, String indent) {
    final CodeLineSelection selection = value.selection;
    final CodeLines codeLines = value.codeLines;
    final List<String> texts = [];
    for (int i = selection.startIndex; i <= selection.endIndex; i++) {
      texts.add(codeLines[i].text);
    }
    final bool willComment;
    texts.removeWhere((text) => text.isEmpty);
    if (texts.isEmpty) {
      willComment = true;
    } else {
      willComment = texts.any((text) => !text.trimLeft().startsWith(symbol));
    }
    if (willComment) {
      return _commentSelectedCodeLines(value, indent, '$symbol ');
    } else {
      return _uncommentSelectedCodeLines(value, indent, symbol);
    }
  }

  CodeLineEditingValue _commentSelectedCodeLines(CodeLineEditingValue value, String indent, String prefix) {
    final CodeLineSelection selection = value.selection;
    final CodeLines codeLines = value.codeLines;
    int? index;
    for (int i = selection.startIndex; i <= selection.endIndex; i++) {
      final CodeLine codeLine = codeLines[i];
      if (codeLine.text.isEmpty) {
        continue;
      }
      final int offset = codeLine.text.getOffsetWithoutIndent(indent);
      if (index == null) {
        index = offset;
      } else {
        index = min(index, offset);
      }
    }
    if (index == null) {
      return value;
    }
    final CodeLines newCodeLines = CodeLines.from(codeLines);
    for (int i = selection.startIndex; i <= selection.endIndex; i++) {
      final CodeLine codeLine = newCodeLines[i];
      if (codeLine.text.isEmpty) {
        continue;
      }
      final newChunks = _commentChunks(codeLine, prefix, index);
      newCodeLines[i] = codeLine.copyWith(
        text: codeLine.text.insert(prefix, index),
        chunks: newChunks
      );
    }
    final int baseOffset;
    final int extentOffset;
    if (selection.baseIndex < selection.extentIndex) {
      if (selection.baseOffset < index || newCodeLines[selection.baseIndex].text.isEmpty) {
        baseOffset = selection.baseOffset;
      } else {
        baseOffset = selection.baseOffset + prefix.length;
      }
      if (selection.extentOffset <= index) {
        extentOffset = selection.extentOffset;
      } else {
        extentOffset = selection.extentOffset + prefix.length;
      }
    } else {
      if (selection.baseOffset <= index) {
        baseOffset = selection.baseOffset;
      } else {
        baseOffset = selection.baseOffset + prefix.length;
      }
      if (selection.extentOffset < index || newCodeLines[selection.extentIndex].text.isEmpty) {
        extentOffset = selection.extentOffset;
      } else {
        extentOffset = selection.extentOffset + prefix.length;
      }
    }
    return value.copyWith(
      codeLines: newCodeLines,
      selection: selection.copyWith(
        baseOffset: baseOffset,
        extentOffset: extentOffset,
      )
    );
  }

  List<CodeLine> _commentChunks(CodeLine codeLine, String prefix, int index) {
    final List<CodeLine> newCodeChunks = List.from(codeLine.chunks);
    for (int j = 0; j < newCodeChunks.length; j++) {
      final CodeLine codeLineChunk = newCodeChunks[j];
      if (codeLineChunk.text.isEmpty) {
        continue;
      }
      final newCodeLineChunks = _commentChunks(codeLineChunk, prefix, index);
      newCodeChunks[j] = codeLineChunk.copyWith(
          text: codeLineChunk.text.insert(prefix, index),
          chunks: newCodeLineChunks);
    }
    return newCodeChunks;
  }

  CodeLineEditingValue _uncommentSelectedCodeLines(CodeLineEditingValue value, String indent, String prefix) {
    final CodeLineSelection selection = value.selection;
    final CodeLines newCodeLines = CodeLines.from(value.codeLines);
    int? baseOffset;
    int? extentOffset;
    for (int i = selection.startIndex; i <= selection.endIndex; i++) {
      final CodeLine codeLine = newCodeLines[i];
      if (codeLine.text.isEmpty) {
        continue;
      }
      final String trimCode = codeLine.text.trimLeft();
      final String deletion;
      if (trimCode.startsWith('$prefix ')) {
        deletion = '$prefix ';
      } else {
        deletion = prefix;
      }
      final int index = codeLine.text.indexOf(deletion);
      final codeChunks = _uncommentChunks(codeLine, deletion, index);
      newCodeLines[i] = codeLine.copyWith(
        text: codeLine.text.substring(0, index) + codeLine.text.substring(index + deletion.length),
        chunks: codeChunks
      );
      if (i == selection.baseIndex) {
        if (selection.baseOffset > index) {
          baseOffset = max(index, selection.baseOffset - deletion.length);
        }
      }
      if (i == selection.extentIndex) {
        if (selection.extentOffset > index) {
          extentOffset = max(index, selection.extentOffset - deletion.length);
        }
      }
    }
    return value.copyWith(
      codeLines: newCodeLines,
      selection: selection.copyWith(
        baseOffset: baseOffset,
        extentOffset: extentOffset,
      )
    );
  }

  List<CodeLine> _uncommentChunks(
      CodeLine codeLine, String deletion, int index) {
    final List<CodeLine> newCodeChunks = List.from(codeLine.chunks);
    for (int j = 0; j < newCodeChunks.length; j++) {
      final CodeLine codeLineChunk = newCodeChunks[j];
      if (codeLineChunk.text.isEmpty) {
        continue;
      }
      final newCodeLineChunks =
          _uncommentChunks(codeLineChunk, deletion, index);
      newCodeChunks[j] = codeLineChunk.copyWith(
          text: codeLineChunk.text.substring(0, index) +
              codeLineChunk.text.substring(index + deletion.length),
          chunks: newCodeLineChunks);
    }
    return newCodeChunks;
  }
}

class _DefaultMultiLineCommentFormatter extends _DefaultCommentFormatter {

  final String prefix;
  final String suffix;

  _DefaultMultiLineCommentFormatter(this.prefix, this.suffix) : super(prefix + suffix);

  @override
  CodeLineEditingValue format(CodeLineEditingValue value, String indent) {
    final CodeLineSelection selection = value.selection;
    if (selection.isSameLine) {
      return _formatSelectedCodeLine(value, indent);
    } else {
      return _formatSelectedCodeLines(value, indent);
    }
  }

  CodeLineEditingValue _formatSelectedCodeLine(
    CodeLineEditingValue value,
    String indent,
  ) {
    final CodeLineSelection selection = value.selection;
    final String codeLine = value.codeLines[selection.baseIndex].text;

    final int baseOffset = selection.baseOffset;
    final int extentOffset = selection.extentOffset;

    final int base;
    final int extent;

    if (extentOffset >= baseOffset) {
      base = baseOffset;
      extent = extentOffset;
    } else {
      base = extentOffset;
      extent = baseOffset;
    }

    final int prefixIndex;
    final int suffixIndex = codeLine.indexOf(suffix, extent);

    prefixIndex = _getIndexOfPrefix(
      codeLine,
      base,
    );

    if (prefixIndex == -1 || suffixIndex == -1 || base < prefixIndex) {
      return _commentSelectedCodeLine(
        value,
        indent,
        '$prefix ',
        ' $suffix',
      );
    }

    if (codeLine.startsWith('$prefix ', prefixIndex) &&
        codeLine.startsWith(' $suffix', suffixIndex - 1)) {
      return _uncommentSelectedCodeLine(
        value,
        '$prefix ',
        ' $suffix',
        prefixIndex,
        suffixIndex - 1,
      );
    } else if (codeLine.startsWith('$prefix ', prefixIndex) &&
        codeLine.startsWith(suffix, suffixIndex)) {
      return _uncommentSelectedCodeLine(
        value,
        '$prefix ',
        suffix,
        prefixIndex,
        suffixIndex,
      );
    }
    if (codeLine.startsWith(prefix, prefixIndex) &&
        codeLine.startsWith(' $suffix', suffixIndex - 1)) {
      return _uncommentSelectedCodeLine(
        value,
        prefix,
        ' $suffix',
        prefixIndex,
        suffixIndex - 1,
      );
    }
    if (codeLine.startsWith(prefix, prefixIndex) &&
        codeLine.startsWith(suffix, suffixIndex)) {
      return _uncommentSelectedCodeLine(
        value,
        prefix,
        suffix,
        prefixIndex,
        suffixIndex,
      );
    } else {
      return _commentSelectedCodeLine(
        value,
        indent,
        '$prefix ',
        ' $suffix',
      );
    }
  }

  CodeLineEditingValue _uncommentSelectedCodeLine(
    CodeLineEditingValue value,
    String prefix,
    String suffix,
    int prefixIndex,
    int suffixIndex,
  ) {
    final CodeLineSelection selection = value.selection;
    final CodeLines codeLines = value.codeLines;
    final int lineIndex = selection.baseIndex;
    final CodeLine codeLine = codeLines[lineIndex];

    final CodeLines newCodeLines = CodeLines.from(codeLines);

    newCodeLines[lineIndex] = codeLine.copyWith(
      text: codeLine.text.substring(0, prefixIndex) +
          codeLine.text.substring(prefixIndex + prefix.length, suffixIndex) +
          codeLine.text.substring(suffixIndex + suffix.length),
    );

    int relocationPrefix(int offset, int deletion) {
      if (offset <= prefixIndex) {
        return offset;
      } else {
        return max(prefixIndex, offset - deletion);
      }
    }

    int relocationSuffix(int offset, int deletion) {
      return min(offset - deletion, newCodeLines[lineIndex].text.length);
    }

    final int deletion;

    if (prefixIndex + this.prefix.length >= selection.baseOffset) {
      deletion = this.prefix.length;
    } else {
      deletion = prefix.length;
    }

    final int baseOffset;
    final int extentOffset;

    if (selection.extentOffset >= selection.baseOffset) {
      baseOffset = relocationPrefix(selection.baseOffset, deletion);
      extentOffset = relocationSuffix(selection.extentOffset, deletion);
    } else {
      baseOffset = relocationSuffix(selection.baseOffset, deletion);
      extentOffset = relocationPrefix(selection.extentOffset, deletion);
    }

    return value.copyWith(
      codeLines: newCodeLines,
      selection: selection.copyWith(
        baseOffset: baseOffset,
        extentOffset: extentOffset,
      ),
    );
  }

  CodeLineEditingValue _commentSelectedCodeLine(
    CodeLineEditingValue value,
    String indent,
    String prefix,
    String suffix,
  ) {
    final CodeLineSelection selection = value.selection;
    final CodeLines codeLines = value.codeLines;
    final int lineIndex = selection.baseIndex;
    final CodeLine codeLine = codeLines[lineIndex];
    final int index = codeLine.text.getOffsetWithoutIndent(indent);
    final CodeLines newCodeLines = CodeLines.from(codeLines);

    if (selection.extentOffset >= selection.baseOffset) {
      newCodeLines[lineIndex] = codeLine.copyWith(
        text: codeLine.text
            .insert(suffix, selection.extentOffset)
            .insert(prefix, selection.baseOffset),
      );
    } else {
      newCodeLines[lineIndex] = codeLine.copyWith(
        text: codeLine.text
            .insert(suffix, selection.baseOffset)
            .insert(prefix, selection.extentOffset),
      );
    }

    final int baseOffset;
    final int extentOffset;

    if (selection.isCollapsed) {
      if (selection.baseOffset < index) {
        baseOffset = extentOffset = selection.baseOffset;
      } else {
        baseOffset = extentOffset = selection.baseOffset + prefix.length;
      }
    } else {
      if (selection.startOffset < index && selection.endOffset > index) {
        if (selection.baseOffset < index) {
          baseOffset = selection.baseOffset;
          extentOffset = selection.extentOffset + prefix.length;
        } else {
          extentOffset = selection.extentOffset;
          baseOffset = selection.baseOffset + prefix.length;
        }
      } else if (selection.startOffset >= index) {
        baseOffset = selection.baseOffset + prefix.length;
        extentOffset = selection.extentOffset + prefix.length;
      } else {
        baseOffset = selection.baseOffset;
        extentOffset = selection.extentOffset;
      }
    }

    return value.copyWith(
      codeLines: newCodeLines,
      selection: selection.copyWith(
        baseOffset: baseOffset,
        extentOffset: extentOffset,
      ),
    );
  }

  CodeLineEditingValue _formatSelectedCodeLines(
    CodeLineEditingValue value,
    String indent,
  ) {
    final CodeLineSelection selection = value.selection;
    final int baseIndex = selection.baseIndex;
    final int extentIndex = selection.extentIndex;

    String codeFirstLine;
    String codeLastLine;

    final int base;
    final int extent;

    if (extentIndex >= baseIndex) {
      codeFirstLine = value.codeLines[baseIndex].text;
      codeLastLine = value.codeLines[extentIndex].text;

      base = selection.baseOffset;
      extent = selection.extentOffset;
    } else {
      codeFirstLine = value.codeLines[extentIndex].text;
      codeLastLine = value.codeLines[baseIndex].text;

      base = selection.extentOffset;
      extent = selection.baseOffset;
    }

    final int prefixIndex;
    final int suffixIndex = codeLastLine.indexOf(suffix, extent);

    prefixIndex = _getIndexOfPrefix(
      codeFirstLine,
      base,
    );

    if (prefixIndex == -1 || suffixIndex == -1 || base < prefixIndex) {
      return _commentSelectedCodeLines(
        value,
        indent,
        '$prefix ',
        ' $suffix',
      );
    }

    if (codeFirstLine.startsWith('$prefix ', prefixIndex) &&
        codeLastLine.startsWith(' $suffix', suffixIndex - 1)) {
      return _uncommentSelectedCodeLines(
        value,
        '$prefix ',
        ' $suffix',
        prefixIndex,
        suffixIndex - 1,
      );
    } else if (codeFirstLine.startsWith('$prefix ', prefixIndex) &&
        codeLastLine.startsWith(suffix, suffixIndex)) {
      return _uncommentSelectedCodeLines(
        value,
        '$prefix ',
        suffix,
        prefixIndex,
        suffixIndex,
      );
    }
    if (codeFirstLine.startsWith(prefix, prefixIndex) &&
        codeLastLine.startsWith(' $suffix', suffixIndex - 1)) {
      return _uncommentSelectedCodeLines(
        value,
        prefix,
        ' $suffix',
        prefixIndex,
        suffixIndex - 1,
      );
    }
    if (codeFirstLine.startsWith(prefix, prefixIndex) &&
        codeLastLine.startsWith(suffix, suffixIndex)) {
      return _uncommentSelectedCodeLines(
        value,
        prefix,
        suffix,
        prefixIndex,
        suffixIndex,
      );
    } else {
      return _commentSelectedCodeLines(
        value,
        indent,
        '$prefix ',
        ' $suffix',
      );
    }
  }

  CodeLineEditingValue _uncommentSelectedCodeLines(
    CodeLineEditingValue value,
    String prefix,
    String suffix,
    int prefixIndex,
    int suffixIndex,
  ) {
    final CodeLineSelection selection = value.selection;
    final CodeLines codeLines = value.codeLines;
    final CodeLines newCodeLines = CodeLines.from(codeLines);

    final int baseIndex = selection.baseIndex;
    final int extentIndex = selection.extentIndex;

    final CodeLine codeFirstLine;
    final CodeLine codeLastLine;

    final int baseOffset;
    final int extentOffset;

    if (extentIndex >= baseIndex) {
      codeFirstLine = codeLines[baseIndex];
      codeLastLine = codeLines[extentIndex];

      newCodeLines[baseIndex] = codeFirstLine.copyWith(
        text: codeFirstLine.text.substring(0, prefixIndex) +
            codeFirstLine.text.substring(prefixIndex + prefix.length),
      );

      newCodeLines[extentIndex] = codeLastLine.copyWith(
        text: codeLastLine.text.substring(0, suffixIndex) +
            codeLastLine.text.substring(suffixIndex + suffix.length),
      );

      final int deletion;

      if (prefixIndex + this.prefix.length >= selection.baseOffset) {
        deletion = this.prefix.length;
      } else {
        deletion = prefix.length;
      }

      baseOffset = selection.baseOffset - deletion;
      extentOffset = min(
        selection.extentOffset,
        newCodeLines[extentIndex].text.length,
      );
    } else {
      codeFirstLine = codeLines[extentIndex];
      codeLastLine = codeLines[baseIndex];

      newCodeLines[extentIndex] = codeFirstLine.copyWith(
        text: codeFirstLine.text.substring(0, prefixIndex) +
            codeFirstLine.text.substring(prefixIndex + prefix.length),
      );

      newCodeLines[baseIndex] = codeLastLine.copyWith(
        text: codeLastLine.text.substring(0, suffixIndex) +
            codeLastLine.text.substring(suffixIndex + suffix.length),
      );

      final int deletion;

      if (prefixIndex + this.prefix.length >= selection.extentOffset) {
        deletion = this.prefix.length;
      } else {
        deletion = prefix.length;
      }

      baseOffset = min(
        selection.baseOffset,
        newCodeLines[baseIndex].text.length,
      );
      extentOffset = selection.extentOffset - deletion;
    }

    return value.copyWith(
      codeLines: newCodeLines,
      selection: selection.copyWith(
        baseOffset: baseOffset,
        extentOffset: extentOffset,
      ),
    );
  }

  CodeLineEditingValue _commentSelectedCodeLines(
    CodeLineEditingValue value,
    String indent,
    String prefix,
    String suffix,
  ) {
    final CodeLineSelection selection = value.selection;
    final CodeLines codeLines = value.codeLines;
    final CodeLines newCodeLines = CodeLines.from(codeLines);

    final int baseIndex = selection.baseIndex;
    final int extentIndex = selection.extentIndex;

    final CodeLine codeFirstLine;
    final CodeLine codeLastLine;

    if (extentIndex >= baseIndex) {
      codeFirstLine = codeLines[baseIndex];
      codeLastLine = codeLines[extentIndex];

      newCodeLines[baseIndex] = codeFirstLine.copyWith(
        text: codeFirstLine.text.insert(prefix, selection.baseOffset),
      );

      newCodeLines[extentIndex] = codeLastLine.copyWith(
        text: codeLastLine.text.insert(suffix, selection.extentOffset),
      );
    } else {
      codeFirstLine = codeLines[extentIndex];
      codeLastLine = codeLines[baseIndex];

      newCodeLines[extentIndex] = codeFirstLine.copyWith(
        text: codeFirstLine.text.insert(prefix, selection.extentOffset),
      );

      newCodeLines[baseIndex] = codeLastLine.copyWith(
        text: codeLastLine.text.insert(suffix, selection.baseOffset),
      );
    }

    final int baseOffset;
    final int extentOffset;

    if (extentIndex >= baseIndex) {
      baseOffset = selection.baseOffset + prefix.length;
      extentOffset = selection.extentOffset;
    } else {
      baseOffset = selection.baseOffset;
      extentOffset = selection.extentOffset + suffix.length;
    }

    return value.copyWith(
      codeLines: newCodeLines,
      selection: selection.copyWith(
        baseOffset: baseOffset,
        extentOffset: extentOffset,
      ),
    );
  }

  int _getIndexOfPrefix(
    String text,
    int baseIndex,
  ) {
    int index = -1;
    int prefixLength = prefix.length - 1;
    int suffixLength = suffix.length - 1;

    if (baseIndex >= text.length - 1) {
      return index;
    }

    for (int i = baseIndex; i > 0; i--) {
      if (text[i] == suffix[suffixLength]) {
        if (text.substring(i - suffixLength, i + 1) == suffix) {
          break;
        }
      }

      if (text[i] == prefix[prefixLength]) {
        if (text.substring(i - prefixLength, i + 1) == prefix) {
          index = i - 1;
          break;
        }
      }
    }

    return index;
  }

}
