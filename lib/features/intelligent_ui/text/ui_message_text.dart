import 'package:markstream/markstream_core.dart';
import 'package:Kelivo/core/services/tts/tts_text_selection.dart';
import '../catalog/ui_budgets.dart';
import '../runtime/ui_surface_controller.dart';
import '../runtime/ui_surface_state.dart';
import 'ui_bounded_text.dart';

/// A frozen message projection. UI values are literal text, so a value such as
/// `-3`, backticks or a Markdown link is never reinterpreted as syntax.
final class UiMessageText {
  UiMessageText({
    required this.source,
    required Iterable<TtsTextPart> parts,
    required this.omitted,
    required this.hasUi,
    Iterable<UiMessageReplacement> replacements = const [],
    Iterable<UiCapturedSurface> surfaces = const [],
  }) : parts = List.unmodifiable(parts),
       replacements = List.unmodifiable(replacements),
       surfaces = List.unmodifiable(surfaces);
  final String source, omitted;
  final List<TtsTextPart> parts;
  final bool hasUi;
  final List<UiMessageReplacement> replacements;
  final List<UiCapturedSurface> surfaces;

  /// Original joined TextPart coordinates. A fence spanning adjacent parts is
  /// emitted exactly once; image/file/tool positions remain the caller's own.
  String exportSlice(
    int start,
    int end, {
    required bool markdown,
    required String Function(int start, int end) ordinary,
  }) {
    final output = StringBuffer();
    var cursor = start;
    for (final replacement in replacements) {
      if (replacement.end <= cursor) continue;
      if (replacement.start >= end) break;
      if (replacement.start > cursor) {
        output.write(ordinary(cursor, replacement.start));
      }
      if (replacement.start >= start) {
        output.write(
          '\n${markdown ? replacement.markdown : replacement.text}\n',
        );
      }
      cursor = replacement.end.clamp(cursor, end);
    }
    if (cursor < end) output.write(ordinary(cursor, end));
    return output.toString();
  }

  late final String copyText = _copyText();

  /// Bound input work as well as output. Huge ordinary prose is omitted as one
  /// source unit before parsing; semantic fields are kept or omitted whole.
  late final List<TtsTextPart> _boundedParts = _bound();
  List<TtsTextPart> _bound() {
    final budget = UiBoundedText(UiBudgets.copyBytes, omission: omitted);
    final result = <TtsTextPart>[];
    for (final part in parts) {
      if (!part.literal) {
        if (budget.add(part.text)) result.add(part);
        continue;
      }
      final kept = [
        for (final line in part.text.split('\n'))
          if (budget.add(line)) line,
      ];
      if (kept.isNotEmpty) {
        result.add(TtsTextPart(kept.join('\n'), literal: true));
      }
    }
    if (budget.omitted) result.add(TtsTextPart(omitted, literal: true));
    return List.unmodifiable(result);
  }

  String _copyText() {
    if (!hasUi) return source;
    final result = UiBoundedText(UiBudgets.copyBytes, omission: omitted);
    for (final part in _boundedParts) {
      final text = part.literal
          ? part.text
          : toPlainText(const MarkdownParser().parse(part.text));
      for (final line in text.split('\n')) {
        result.add(line);
      }
    }
    return result.finish();
  }

  String speech(TtsTextSelectionMode mode) =>
      TtsTextSelection.prepareParts(_boundedParts, mode: mode);
}

/// The fenced form prevents model-authored semantic values from becoming
/// Markdown links, HTML or another executable UI block in an exported file.
String uiExportMarkdown(String text, String source) {
  var width = 3;
  for (final match in RegExp(r'`+').allMatches(text)) {
    if (match.group(0)!.length >= width) width = match.group(0)!.length + 1;
  }
  final fence = '`' * width;
  return '$fence'
      'text\n$text\n$fence\n\n$source';
}

final class UiMessageReplacement {
  const UiMessageReplacement(this.start, this.end, this.text, this.source);
  final int start, end;
  final String text, source;
  String get markdown => uiExportMarkdown(text, source);
}

/// Immutable capture material; reconstructing it never touches a live owner.
final class UiCapturedSurface {
  const UiCapturedSurface({
    required this.owner,
    required this.source,
    required this.closed,
    required this.generation,
    this.snapshot,
  });
  final UiSurfaceOwner owner;
  final String source;
  final bool closed;
  final UiGenerationStatus generation;
  final UiSurfaceSnapshot? snapshot;

  UiSurfaceController createController() {
    final controller = UiSurfaceController(owner: owner, readOnly: true)
      ..updateSource(source, closed: closed, generation: generation);
    if (snapshot case final state?) {
      if (!controller.restore(state, token: controller.restoreToken)) {
        controller.dispose();
        throw StateError('genui_export_snapshot_invalid');
      }
    }
    return controller;
  }
}
