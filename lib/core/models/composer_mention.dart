import 'package:flutter/services.dart';

/// An explicitly selected recipient, anchored to a token in the composer.
/// Text that merely resembles a mention never creates this association.
class ComposerMention {
  const ComposerMention({
    required this.assistantId,
    required this.label,
    required this.start,
  });
  final String assistantId;
  final String label;
  final int start;
  String get token => '@$label';
  int get end => start + token.length;

  bool matches(String text) =>
      start >= 0 && end <= text.length && text.substring(start, end) == token;

  /// Text changes may validate a replacement at the previous selection.
  /// Selection/composing changes alone are not evidence of an edit: a plain
  /// editing value cannot distinguish same-text paste from moving the caret.
  ComposerMention? afterEditingValue(
    TextEditingValue before,
    TextEditingValue after,
  ) {
    if (before.text == after.text) return matches(after.text) ? this : null;
    final selection = before.selection;
    if (selection.isValid && selection.end <= before.text.length) {
      var from = selection.start;
      var to = selection.end;
      if (selection.isCollapsed &&
          after.selection.isCollapsed &&
          after.selection.isValid) {
        from = after.selection.start < from ? after.selection.start : from;
        final removed = before.text.length - after.text.length;
        if (removed > 0) to = from + removed;
      }
      final inserted = after.text.length - before.text.length + to - from;
      if (inserted >= 0 &&
          to <= before.text.length &&
          from + inserted <= after.text.length &&
          before.text.substring(0, from) == after.text.substring(0, from) &&
          before.text.substring(to) == after.text.substring(from + inserted) &&
          (!selection.isCollapsed || before.text != after.text)) {
        return _afterReplacement(from, to, inserted);
      }
    }
    return afterEdit(before.text, after.text);
  }

  ComposerMention? _afterReplacement(int from, int to, int inserted) {
    if (to <= start) {
      return ComposerMention(
        assistantId: assistantId,
        label: label,
        start: start + inserted - (to - from),
      );
    }
    if (from >= end) return this;
    return null;
  }

  ComposerMention? afterEdit(String before, String after) {
    if (before == after) return this;
    var prefix = 0;
    while (prefix < before.length &&
        prefix < after.length &&
        before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
      prefix++;
    }
    var oldEnd = before.length;
    var newEnd = after.length;
    while (oldEnd > prefix &&
        newEnd > prefix &&
        before.codeUnitAt(oldEnd - 1) == after.codeUnitAt(newEnd - 1)) {
      oldEnd--;
      newEnd--;
    }
    final candidate = _afterReplacement(prefix, oldEnd, newEnd - prefix);
    if (candidate == null) return null;
    // Repeated text can admit several equally small edits. Keep an anchor only
    // if every possible placement preserves the same token, never by name.
    for (var shift = 1; shift <= prefix; shift++) {
      if (before.codeUnitAt(oldEnd - shift) !=
          after.codeUnitAt(newEnd - shift)) {
        break;
      }
      final alternative = _afterReplacement(
        prefix - shift,
        oldEnd - shift,
        newEnd - prefix,
      );
      if (alternative == null || alternative.start != candidate.start) {
        return null;
      }
    }
    return candidate;
  }

  @override
  bool operator ==(Object other) =>
      other is ComposerMention &&
      assistantId == other.assistantId &&
      label == other.label &&
      start == other.start;

  @override
  int get hashCode => Object.hash(assistantId, label, start);

  Map<String, dynamic> toJson() => {
    'assistantId': assistantId,
    'label': label,
    'start': start,
  };
  factory ComposerMention.fromJson(Map<String, dynamic> json) =>
      ComposerMention(
        assistantId: json['assistantId'] as String,
        label: json['label'] as String,
        start: json['start'] as int,
      );
}
