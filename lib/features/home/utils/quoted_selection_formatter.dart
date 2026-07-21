import 'package:flutter/services.dart';

/// Inserts selected message text into a chat draft as a Markdown blockquote.
TextEditingValue insertQuotedSelectionIntoDraft(
  TextEditingValue current,
  String selectedText,
) {
  var normalizedSelection = selectedText
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  if (normalizedSelection.trim().isEmpty) return current;
  normalizedSelection = normalizedSelection
      .replaceFirst(RegExp(r'^(?:[ \t]*\n)+'), '')
      .replaceFirst(RegExp(r'(?:\n[ \t]*)+$'), '');

  final quote = normalizedSelection
      .split('\n')
      .map((line) => line.isEmpty ? '>' : '> $line')
      .join('\n');
  final selection = current.selection;
  final hasValidSelection =
      selection.isValid &&
      selection.start >= 0 &&
      selection.end >= selection.start &&
      selection.end <= current.text.length;
  final start = hasValidSelection ? selection.start : current.text.length;
  final end = hasValidSelection ? selection.end : current.text.length;
  final prefix = current.text.substring(0, start);
  var suffix = current.text.substring(end);

  final leading = prefix.isEmpty
      ? ''
      : prefix.endsWith('\n\n')
      ? ''
      : prefix.endsWith('\n')
      ? '\n'
      : '\n\n';
  suffix = suffix.replaceFirst(RegExp(r'^\n{1,2}'), '');
  final inserted = '$leading$quote\n\n';
  final nextText = '$prefix$inserted$suffix';
  final caretOffset = prefix.length + inserted.length;

  return TextEditingValue(
    text: nextText,
    selection: TextSelection.collapsed(offset: caretOffset),
    composing: TextRange.empty,
  );
}
