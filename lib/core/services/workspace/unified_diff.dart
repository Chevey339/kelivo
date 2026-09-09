import 'dart:convert';
import 'dart:math' as math;

import 'package:diffutil_dart/diffutil.dart';

class UnifiedDiff {
  const UnifiedDiff({
    required this.text,
    required this.added,
    required this.removed,
    required this.truncated,
  });

  final String text;
  final int added;
  final int removed;
  final bool truncated;

  /// Line-based unified diff with [context] lines around each change.
  ///
  /// Uses Myers (via `diffutil_dart`) for the edit script. When [text] would
  /// exceed [maxChars], hunks are dropped from the end and a
  /// `... (N more lines)` marker is appended.
  static UnifiedDiff compute(
    String oldText,
    String newText, {
    String path = 'file',
    int context = 3,
    int maxChars = 64 * 1024,
  }) {
    final oldLines = _splitLines(oldText);
    final newLines = _splitLines(newText);
    final ops = _opsFromMyers(oldLines, newLines);
    var added = 0;
    var removed = 0;
    for (final op in ops) {
      if (op.tag == '+') added++;
      if (op.tag == '-') removed++;
    }

    final header = '--- a/$path\n+++ b/$path\n';
    if (added == 0 && removed == 0) {
      return UnifiedDiff(text: header, added: 0, removed: 0, truncated: false);
    }

    final hunks = _buildHunks(ops, context);
    final hunkTexts = [for (final hunk in hunks) _formatHunk(hunk)];
    final buffer = StringBuffer(header);
    var included = 0;
    var truncated = false;
    for (var i = 0; i < hunkTexts.length; i++) {
      final next = '${buffer.toString()}${hunkTexts[i]}';
      if (next.length > maxChars) {
        truncated = true;
        break;
      }
      buffer.write(hunkTexts[i]);
      included++;
    }
    if (truncated) {
      var omitted = 0;
      for (var i = included; i < hunkTexts.length; i++) {
        omitted += _nonEmptyLineCount(hunkTexts[i]);
      }
      buffer.write('... ($omitted more lines)\n');
    }
    return UnifiedDiff(
      text: buffer.toString(),
      added: added,
      removed: removed,
      truncated: truncated,
    );
  }
}

class _Op {
  const _Op(this.tag, this.text, this.oldLine, this.newLine);

  final String tag;
  final String text;
  final int oldLine;
  final int newLine;
}

class _Tagged {
  const _Tagged({
    required this.oldIndex,
    required this.text,
    required this.inserted,
  });

  final int oldIndex;
  final String text;
  final bool inserted;
}

List<String> _splitLines(String text) {
  if (text.isEmpty) return const <String>[];
  return const LineSplitter().convert(text);
}

List<_Op> _opsFromMyers(List<String> oldLines, List<String> newLines) {
  final result = calculateListDiff<String>(
    oldLines,
    newLines,
    detectMoves: false,
  );
  final current = <_Tagged>[
    for (var i = 0; i < oldLines.length; i++)
      _Tagged(oldIndex: i, text: oldLines[i], inserted: false),
  ];
  final deletedOld = <int>{};
  for (final update in result.getUpdatesWithData()) {
    switch (update) {
      case DataRemove(:final position):
        deletedOld.add(current[position].oldIndex);
        current.removeAt(position);
      case DataInsert(:final position, :final data):
        current.insert(
          position,
          _Tagged(oldIndex: -1, text: data, inserted: true),
        );
      case DataChange():
      case DataMove():
        throw StateError('unexpected diff update $update');
    }
  }

  final ops = <_Op>[];
  var oldI = 0;
  var newI = 0;
  var cursor = 0;
  while (oldI < oldLines.length || cursor < current.length) {
    if (oldI < oldLines.length && deletedOld.contains(oldI)) {
      ops.add(_Op('-', oldLines[oldI], oldI + 1, 0));
      oldI++;
      continue;
    }
    if (cursor < current.length && current[cursor].inserted) {
      ops.add(_Op('+', current[cursor].text, 0, newI + 1));
      newI++;
      cursor++;
      continue;
    }
    if (oldI < oldLines.length && cursor < current.length) {
      ops.add(_Op(' ', oldLines[oldI], oldI + 1, newI + 1));
      oldI++;
      newI++;
      cursor++;
      continue;
    }
    break;
  }
  return ops;
}

List<List<_Op>> _buildHunks(List<_Op> ops, int context) {
  final changeIndexes = <int>[
    for (var i = 0; i < ops.length; i++)
      if (ops[i].tag != ' ') i,
  ];
  if (changeIndexes.isEmpty) return const [];

  final hunks = <List<_Op>>[];
  var hunkStart = math.max(0, changeIndexes.first - context);
  var lastChange = changeIndexes.first;
  for (final index in changeIndexes.skip(1)) {
    if (index - lastChange <= context * 2) {
      lastChange = index;
      continue;
    }
    final hunkEnd = math.min(ops.length, lastChange + context + 1);
    hunks.add(ops.sublist(hunkStart, hunkEnd));
    hunkStart = math.max(0, index - context);
    lastChange = index;
  }
  hunks.add(
    ops.sublist(hunkStart, math.min(ops.length, lastChange + context + 1)),
  );
  return hunks;
}

String _formatHunk(List<_Op> hunk) {
  var oldStart = 0;
  var newStart = 0;
  var oldCount = 0;
  var newCount = 0;
  for (final op in hunk) {
    if (op.tag != '+') {
      if (oldStart == 0) oldStart = op.oldLine;
      oldCount++;
    }
    if (op.tag != '-') {
      if (newStart == 0) newStart = op.newLine;
      newCount++;
    }
  }
  final buffer = StringBuffer(
    '@@ -$oldStart,$oldCount +$newStart,$newCount @@\n',
  );
  for (final op in hunk) {
    buffer.write(op.tag);
    buffer.write(op.text);
    buffer.write('\n');
  }
  return buffer.toString();
}

int _nonEmptyLineCount(String text) {
  var count = 0;
  for (final line in const LineSplitter().convert(text)) {
    if (line.isNotEmpty) count++;
  }
  return count;
}
