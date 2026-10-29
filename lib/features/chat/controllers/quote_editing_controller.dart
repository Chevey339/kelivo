import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/models/quote_ref.dart';
import '../../../shared/text_input/message_editing_controller.dart';
import '../widgets/quote_chip.dart';

/// Carries references through Flutter's undo history, including composing
/// range normalization. A restored edit restores its references atomically.
class QuoteEditingValue extends TextEditingValue {
  const QuoteEditingValue({
    super.text,
    super.selection,
    super.composing,
    this.quotes = const [],
  });
  final List<QuoteRef> quotes;

  @override
  QuoteEditingValue copyWith({
    String? text,
    TextSelection? selection,
    TextRange? composing,
  }) {
    final next = TextEditingValue(
      text: text ?? this.text,
      selection: selection ?? this.selection,
      composing: composing ?? this.composing,
    );
    return reconcileQuoteEdit(this, next);
  }

  @override
  bool operator ==(Object other) =>
      super == other &&
      (other is QuoteEditingValue
          ? listEquals(quotes, other.quotes)
          : quotes.isEmpty);
  @override
  int get hashCode => quotes.isEmpty
      ? super.hashCode
      : Object.hash(super.hashCode, Object.hashAll(quotes));
}

QuoteEditingValue reconcileQuoteEdit(
  QuoteEditingValue before,
  TextEditingValue after,
) {
  if (before.text == after.text) {
    return QuoteEditingValue(
      text: after.text,
      selection: after.selection,
      composing: after.composing,
      quotes: before.quotes,
    );
  }
  var prefix = 0;
  var bound = before.text.length < after.text.length
      ? before.text.length
      : after.text.length;
  // Identical adjacent placeholders must follow the actual edit position.
  // A backspace after the first token must not delete the second token's ref.
  if (before.selection.isValid && after.selection.isValid) {
    bound = bound.clamp(0, before.selection.start);
    bound = bound.clamp(0, after.selection.start);
  }
  while (prefix < bound &&
      before.text.codeUnitAt(prefix) == after.text.codeUnitAt(prefix)) {
    prefix++;
  }
  var oldEnd = before.text.length, newEnd = after.text.length;
  while (oldEnd > prefix &&
      newEnd > prefix &&
      before.text.codeUnitAt(oldEnd - 1) == after.text.codeUnitAt(newEnd - 1)) {
    oldEnd--;
    newEnd--;
  }
  final refs = <QuoteRef>[];
  var index = 0;
  for (var offset = 0; offset < before.text.length; offset++) {
    if (before.text.codeUnitAt(offset) != 0xfffc) continue;
    if ((offset < prefix || offset >= oldEnd) && index < before.quotes.length) {
      refs.add(before.quotes[index]);
    }
    index++;
  }
  // An external paste can never mint a reference by inserting U+FFFC.
  final inserted = after.text.substring(prefix, newEnd);
  final clean = inserted.replaceAll(quotePlaceholder, '');
  int offset(int value) {
    if (value < 0 || value <= prefix) return value;
    final end = value.clamp(prefix, newEnd);
    return value -
        RegExp(
          quotePlaceholder,
        ).allMatches(after.text.substring(prefix, end)).length;
  }

  final nextText = after.text.replaceRange(prefix, newEnd, clean);
  return QuoteEditingValue(
    text: nextText,
    selection: TextSelection(
      baseOffset: offset(after.selection.baseOffset),
      extentOffset: offset(after.selection.extentOffset),
      affinity: after.selection.affinity,
      isDirectional: after.selection.isDirectional,
    ),
    composing: after.composing.isValid
        ? TextRange(
            start: offset(after.composing.start),
            end: offset(after.composing.end),
          )
        : TextRange.empty,
    quotes: List.unmodifiable(refs),
  );
}

enum QuoteInsertion { inserted, duplicate, limit }

class QuoteEditingController extends MessageEditingController {
  QuoteEditingController({
    super.text,
    super.nativeInputEnabled,
    super.inputChannel,
  });
  String? flashingQuoteId;
  int flashRevision = 0;

  @override
  QuoteEditingValue get value {
    final current = super.value;
    return current is QuoteEditingValue
        ? current
        : QuoteEditingValue(
            text: current.text,
            selection: current.selection,
            composing: current.composing,
          );
  }

  @override
  set value(TextEditingValue next) {
    super.value = next is QuoteEditingValue
        ? next
        : reconcileQuoteEdit(value, next);
  }

  List<QuoteRef> get quotes => value.quotes;

  void restore(TextEditingValue next, List<QuoteRef> refs) {
    assert(
      RegExp(quotePlaceholder).allMatches(next.text).length == refs.length,
    );
    value = QuoteEditingValue(
      text: next.text,
      selection: next.selection,
      composing: next.composing,
      quotes: List.unmodifiable(refs),
    );
  }

  QuoteInsertion insertQuote(QuoteRef quote) {
    final duplicate = quotes
        .where((item) => item.sameSource(quote))
        .firstOrNull;
    if (duplicate != null) {
      flashingQuoteId = duplicate.id;
      flashRevision++;
      notifyListeners();
      return QuoteInsertion.duplicate;
    }
    final range = selection.isValid
        ? selection
        : TextSelection.collapsed(offset: text.length);
    final leftCount = RegExp(
      quotePlaceholder,
    ).allMatches(text.substring(0, range.start)).length;
    final rightCount = RegExp(
      quotePlaceholder,
    ).allMatches(text.substring(0, range.end)).length;
    final refs = [...quotes.take(leftCount), quote, ...quotes.skip(rightCount)];
    if (refs.length > maxMessageQuotes) return QuoteInsertion.limit;
    restore(
      TextEditingValue(
        text: text.replaceRange(range.start, range.end, quotePlaceholder),
        selection: TextSelection.collapsed(offset: range.start + 1),
      ),
      refs,
    );
    return QuoteInsertion.inserted;
  }

  void removeQuote(String id) {
    final index = quotes.indexWhere((quote) => quote.id == id);
    if (index < 0) return;
    final offset = RegExp(
      quotePlaceholder,
    ).allMatches(text).elementAt(index).start;
    final refs = [...quotes]..removeAt(index);
    int move(int n) => n > offset ? n - 1 : n;
    restore(
      TextEditingValue(
        text: text.replaceRange(offset, offset + 1, ''),
        selection: selection.isValid
            ? TextSelection(
                baseOffset: move(selection.baseOffset),
                extentOffset: move(selection.extentOffset),
              )
            : TextSelection.collapsed(offset: offset),
      ),
      refs,
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (quotes.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return buildQuoteTextSpan(
      text: text,
      quotes: quotes,
      style: style,
      token: (quote, offset) => QuoteChip(
        quote: quote,
        style: style,
        selected:
            selection.isValid &&
            selection.start <= offset &&
            selection.end > offset,
        flashRevision: quote.id == flashingQuoteId ? flashRevision : 0,
        onRemove: () => removeQuote(quote.id),
      ),
      composing: withComposing ? value.composing : TextRange.empty,
    );
  }
}

TextSpan buildQuoteTextSpan({
  required String text,
  required List<QuoteRef> quotes,
  required Widget Function(QuoteRef quote, int offset) token,
  TextStyle? style,
  TextRange composing = TextRange.empty,
  List<TextRange> highlights = const [],
  Color? highlightColor,
  QuoteRef? Function(int offset)? quoteAtOffset,
}) {
  final spans = <InlineSpan>[];
  void plain(int start, int end) {
    if (start >= end) return;
    final points = <int>{start, end};
    for (final range in [composing, ...highlights]) {
      if (range.isValid && range.start < end && range.end > start) {
        points.add(range.start.clamp(start, end));
        points.add(range.end.clamp(start, end));
      }
    }
    final sorted = points.toList()..sort();
    for (var i = 0; i < sorted.length - 1; i++) {
      final from = sorted[i], to = sorted[i + 1];
      spans.add(
        TextSpan(
          text: text.substring(from, to),
          style: TextStyle(
            decoration:
                composing.isValid &&
                    composing.start <= from &&
                    composing.end >= to
                ? TextDecoration.underline
                : null,
            backgroundColor:
                highlights.any(
                  (range) => range.start <= from && range.end >= to,
                )
                ? highlightColor
                : null,
          ),
        ),
      );
    }
  }

  var cursor = 0, index = 0;
  for (final match in RegExp(quotePlaceholder).allMatches(text)) {
    plain(cursor, match.start);
    final quote = quoteAtOffset != null
        ? quoteAtOffset(match.start)
        : index < quotes.length
        ? quotes[index]
        : null;
    if (quote != null) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: token(quote, match.start),
        ),
      );
    }
    index++;
    cursor = match.end;
  }
  plain(cursor, text.length);
  return TextSpan(style: style, children: spans);
}
