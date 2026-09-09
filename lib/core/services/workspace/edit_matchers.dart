/// How [applyEdit] located [oldText] inside the original file.
enum EditStrategy {
  exact,
  lineTrimmed,
  blockAnchor;

  /// Wire name sent to the model (`exact`, `line_trimmed`, `block_anchor`).
  String get id => switch (this) {
    EditStrategy.exact => 'exact',
    EditStrategy.lineTrimmed => 'line_trimmed',
    EditStrategy.blockAnchor => 'block_anchor',
  };
}

sealed class EditFailure {
  const EditFailure();
}

class EditNotFound extends EditFailure {
  const EditNotFound();
}

class EditAmbiguous extends EditFailure {
  const EditAmbiguous({required this.count, required this.strategy});

  final int count;
  final EditStrategy strategy;
}

sealed class EditOutcome {
  const EditOutcome();

  /// Ready-to-send explanation for the model. Empty on success.
  String get message;
}

class EditApplied extends EditOutcome {
  const EditApplied({
    required this.updated,
    required this.replacements,
    required this.strategy,
  });

  final String updated;
  final int replacements;
  final EditStrategy strategy;

  @override
  String get message => '';
}

class EditFailed extends EditOutcome {
  const EditFailed(this.failure, this.message);

  final EditFailure failure;

  @override
  final String message;
}

const String kEditNotFoundMessage =
    'old_string was not found, even with whitespace-tolerant matching; '
    'read the file again and copy old_string exactly from its current content';

String editAmbiguousMessage(int count, EditStrategy strategy) =>
    'old_string matches $count locations (strategy: ${strategy.id}); '
    'add more surrounding context to make it unique, or set replace_all=true';

/// Port of RikkaHub `TextReplacers.kt`: exact → line-trimmed → block-anchor.
EditOutcome applyEdit({
  required String original,
  required String oldText,
  required String newText,
  bool replaceAll = false,
}) {
  if (oldText.isEmpty) {
    return const EditFailed(EditNotFound(), kEditNotFoundMessage);
  }
  for (final strategy in EditStrategy.values) {
    final matches = _findMatches(original, oldText, newText, strategy);
    if (matches.isEmpty) continue;
    if (!replaceAll && matches.length > 1) {
      return EditFailed(
        EditAmbiguous(count: matches.length, strategy: strategy),
        editAmbiguousMessage(matches.length, strategy),
      );
    }
    final applied = replaceAll
        ? matches
        : <_Match>[matches.reduce((a, b) => a.start <= b.start ? a : b)];
    applied.sort((a, b) => a.start.compareTo(b.start));
    final buffer = StringBuffer();
    var cursor = 0;
    for (final match in applied) {
      buffer.write(original.substring(cursor, match.start));
      buffer.write(match.replacement);
      cursor = match.endExclusive;
    }
    buffer.write(original.substring(cursor));
    return EditApplied(
      updated: buffer.toString(),
      replacements: applied.length,
      strategy: strategy,
    );
  }
  return const EditFailed(EditNotFound(), kEditNotFoundMessage);
}

class _Match {
  const _Match(this.start, this.endExclusive, this.replacement);

  final int start;
  final int endExclusive;
  final String replacement;
}

List<_Match> _findMatches(
  String content,
  String oldText,
  String newText,
  EditStrategy strategy,
) {
  switch (strategy) {
    case EditStrategy.exact:
      return _exactMatches(content, oldText, newText);
    case EditStrategy.lineTrimmed:
      return _lineWindowMatches(
        content,
        oldText,
        newText,
        minLines: 1,
        requireNonBlankOld: true,
        requireNonEmptyAnchors: false,
        windowMatches: (window, oldTrimmed) => _listEquals(window, oldTrimmed),
      );
    case EditStrategy.blockAnchor:
      return _lineWindowMatches(
        content,
        oldText,
        newText,
        minLines: 3,
        requireNonBlankOld: true,
        requireNonEmptyAnchors: true,
        windowMatches: (window, oldTrimmed) =>
            window.first == oldTrimmed.first && window.last == oldTrimmed.last,
      );
  }
}

List<_Match> _exactMatches(String content, String oldText, String newText) {
  final matches = <_Match>[];
  var index = content.indexOf(oldText);
  while (index >= 0) {
    matches.add(_Match(index, index + oldText.length, newText));
    index = content.indexOf(oldText, index + oldText.length);
  }
  return matches;
}

List<_Match> _lineWindowMatches(
  String content,
  String oldText,
  String newText, {
  required int minLines,
  required bool requireNonBlankOld,
  required bool requireNonEmptyAnchors,
  required bool Function(List<String> windowTrimmed, List<String> oldTrimmed)
  windowMatches,
}) {
  final rawOldLines = oldText.split('\n');
  final dropTrailingEmpty = rawOldLines.length > 1 && rawOldLines.last.isEmpty;
  final oldLines = dropTrailingEmpty
      ? rawOldLines.sublist(0, rawOldLines.length - 1)
      : rawOldLines;
  final oldTrimmed = [for (final line in oldLines) line.trim()];
  if (oldLines.length < minLines) return const [];
  if (requireNonBlankOld && oldTrimmed.every((line) => line.isEmpty)) {
    return const [];
  }
  if (requireNonEmptyAnchors &&
      (oldTrimmed.first.isEmpty || oldTrimmed.last.isEmpty)) {
    return const [];
  }
  final adjustedNewText = dropTrailingEmpty
      ? _removeOneTrailingNewline(newText)
      : newText;

  final contentLines = _splitLinesWithOffsets(content);
  final matches = <_Match>[];
  var index = 0;
  while (index + oldLines.length <= contentLines.length) {
    final window = contentLines.sublist(index, index + oldLines.length);
    final windowTrimmed = [for (final line in window) line.text.trim()];
    if (windowMatches(windowTrimmed, oldTrimmed)) {
      final replacement = _reindent(
        text: adjustedNewText,
        oldIndent: _indentOf(oldLines.first),
        newIndent: _indentOf(window.first.text),
      );
      matches.add(
        _Match(window.first.start, window.last.endExclusive, replacement),
      );
      index += oldLines.length;
    } else {
      index++;
    }
  }
  return matches;
}

class _LineWithOffset {
  const _LineWithOffset(this.start, this.endExclusive, this.text);

  final int start;
  final int endExclusive;
  final String text;
}

/// Split on `\n`, treating a preceding `\r` as part of the line ending so
/// offsets stay on the logical line text (RikkaHub `splitLinesWithOffsets`).
List<_LineWithOffset> _splitLinesWithOffsets(String content) {
  final lines = <_LineWithOffset>[];
  var start = 0;
  for (var index = 0; index < content.length; index++) {
    if (content.codeUnitAt(index) != 0x0A) continue;
    final end = index > start && content.codeUnitAt(index - 1) == 0x0D
        ? index - 1
        : index;
    lines.add(_LineWithOffset(start, end, content.substring(start, end)));
    start = index + 1;
  }
  lines.add(_LineWithOffset(start, content.length, content.substring(start)));
  return lines;
}

String _indentOf(String line) {
  var i = 0;
  while (i < line.length) {
    final unit = line.codeUnitAt(i);
    if (unit != 0x20 && unit != 0x09) break;
    i++;
  }
  return line.substring(0, i);
}

String _reindent({
  required String text,
  required String oldIndent,
  required String newIndent,
}) {
  if (oldIndent == newIndent) return text;
  return text
      .split('\n')
      .map((line) {
        if (line.trim().isEmpty) return line;
        if (line.startsWith(oldIndent)) {
          return '$newIndent${line.substring(oldIndent.length)}';
        }
        return line;
      })
      .join('\n');
}

String _removeOneTrailingNewline(String text) {
  if (text.endsWith('\r\n')) return text.substring(0, text.length - 2);
  if (text.endsWith('\n')) return text.substring(0, text.length - 1);
  return text;
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
