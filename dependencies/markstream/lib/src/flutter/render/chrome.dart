import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/markstream_theme.dart';

enum MarkstreamActionKind {
  copyCode,
  copyMarkdown,
  copyCsv,
  expand,
  collapse,
  showMore,
}

class MarkstreamAction {
  const MarkstreamAction({
    required this.kind,
    required this.chrome,
    required this.label,
    required this.onInvoke,
  });
  final MarkstreamChromeTheme chrome;
  final MarkstreamActionKind kind;
  final String label;
  final FutureOr<void> Function() onInvoke;
}

typedef MarkstreamActionButtonBuilder =
    Widget Function(BuildContext, MarkstreamAction);

class MarkstreamActionButton extends StatelessWidget {
  const MarkstreamActionButton({super.key, required this.action, this.builder});
  final MarkstreamAction action;
  final MarkstreamActionButtonBuilder? builder;
  @override
  Widget build(BuildContext context) => SelectionContainer.disabled(
    child:
        builder?.call(context, action) ??
        TextButton(
          onPressed: () => unawaited(Future<void>.sync(action.onInvoke)),
          style: TextButton.styleFrom(
            minimumSize: Size(0, action.chrome.actionSize),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            foregroundColor: action.chrome.actionColor,
            textStyle: action.chrome.label,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(action.chrome.actionRadius),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(action.label),
        ),
  );
}

class MarkstreamLabels {
  const MarkstreamLabels({
    this.copyCode = 'Copy code',
    this.copyMarkdown = 'Copy Markdown',
    this.copyCsv = 'Copy CSV',
    this.expand = 'Expand',
    this.collapse = 'Collapse',
    this.unnamedCode = 'Code',
    this.details = 'Details',
    this.note = 'Note',
    this.tip = 'Tip',
    this.important = 'Important',
    this.warning = 'Warning',
    this.caution = 'Caution',
    this.danger = 'Danger',
    this.moreRows = _moreRows,
  });
  final String copyCode,
      copyMarkdown,
      copyCsv,
      expand,
      collapse,
      unnamedCode,
      details,
      note,
      tip,
      important,
      warning,
      caution,
      danger;
  final String Function(int) moreRows;
  static String _moreRows(int count) => 'Show $count more rows';
  @override
  bool operator ==(Object other) =>
      other is MarkstreamLabels &&
      other.copyCode == copyCode &&
      other.copyMarkdown == copyMarkdown &&
      other.copyCsv == copyCsv &&
      other.expand == expand &&
      other.collapse == collapse &&
      other.unnamedCode == unnamedCode &&
      other.details == details &&
      other.note == note &&
      other.tip == tip &&
      other.important == important &&
      other.warning == warning &&
      other.caution == caution &&
      other.danger == danger &&
      other.moreRows == moreRows;
  @override
  int get hashCode => Object.hash(
    copyCode,
    copyMarkdown,
    copyCsv,
    expand,
    collapse,
    unnamedCode,
    details,
    note,
    tip,
    important,
    warning,
    caution,
    danger,
    moreRows,
  );
}

class CodeBlockOptions {
  const CodeBlockOptions({
    this.autoCollapse = false,
    this.collapsedLines = 2,
    this.mobileWrap = false,
    this.highlight = true,
    this.expansionState,
  }) : assert(collapsedLines > 0);
  final bool autoCollapse, mobileWrap, highlight;
  final int collapsedLines;
  final CodeExpansionState? expansionState;
  @override
  bool operator ==(Object other) =>
      other is CodeBlockOptions &&
      other.autoCollapse == autoCollapse &&
      other.collapsedLines == collapsedLines &&
      other.mobileWrap == mobileWrap &&
      other.highlight == highlight &&
      identical(other.expansionState, expansionState);
  @override
  int get hashCode => Object.hash(
    autoCollapse,
    collapsedLines,
    mobileWrap,
    highlight,
    expansionState,
  );
}

/// Optional app-owned memory for explicit folding choices across view remounts.
class CodeExpansionState {
  CodeExpansionState({this.capacity = 80}) : assert(capacity > 0);
  final int capacity;
  final _values = <String, bool>{};
  bool? read(String language, String code) => _values[_key(language, code)];
  void remember(String language, String code, bool expanded) {
    final key = _key(language, code);
    _values.remove(key);
    _values[key] = expanded;
    while (_values.length > capacity) {
      _values.remove(_values.keys.first);
    }
  }

  String _key(String language, String code) {
    final prefix = StringBuffer();
    var whitespace = false;
    final source = code.trimLeft();
    for (var i = 0; i < source.length && prefix.length < 16; i++) {
      final unit = source.codeUnitAt(i);
      final blank =
          unit == 32 ||
          unit == 9 ||
          unit == 10 ||
          unit == 13 ||
          unit == 12 ||
          unit == 11;
      if (blank) {
        if (!whitespace) prefix.write(' ');
        whitespace = true;
      } else {
        prefix.writeCharCode(unit);
        whitespace = false;
      }
    }
    return '${language.trim().toLowerCase()}|$prefix';
  }
}
