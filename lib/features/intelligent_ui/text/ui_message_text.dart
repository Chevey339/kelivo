import 'package:markstream/markstream_core.dart';
import 'package:Kelivo/core/services/tts/tts_text_selection.dart';
import 'package:Kelivo/utils/source_text_map.dart';
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
    Iterable<SourceTextMap>? partSourceMaps,
  }) : parts = List.unmodifiable(parts),
       replacements = List.unmodifiable(replacements),
       surfaces = List.unmodifiable(surfaces),
       _partSourceMaps = partSourceMaps == null
           ? null
           : List.unmodifiable(partSourceMaps);
  final String source, omitted;
  final List<TtsTextPart> parts;
  final bool hasUi;
  final List<UiMessageReplacement> replacements;
  final List<UiCapturedSurface> surfaces;
  final List<SourceTextMap>? _partSourceMaps;

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

  late final (String, SourceTextMap?) _copyProjection = _copyText();
  String get copyText => _copyProjection.$1;
  SourceTextMap? get copySourceMap => _copyProjection.$2;

  /// Bound input work as well as output. Huge ordinary prose is omitted as one
  /// source unit before parsing; semantic fields are kept or omitted whole.
  late final List<_MappedPart> _boundedParts = _bound();
  SourceTextMap get _omissionMap => SourceTextMap.replacement(
    omitted.length,
    SourceSpan(source.length, source.length),
  );
  List<_MappedPart> _bound() {
    final budget = UiBoundedText(UiBudgets.copyBytes, omission: omitted);
    final result = <_MappedPart>[];
    for (final (index, part) in parts.indexed) {
      final map = _partSourceMaps?[index];
      if (!part.literal) {
        if (budget.add(part.text)) result.add(_MappedPart(part, map));
        continue;
      }
      final kept = <String>[];
      final maps = <SourceTextMap?>[];
      var offset = 0;
      for (final line in part.text.split('\n')) {
        if (budget.add(line)) {
          kept.add(line);
          maps.add(map?.slice(offset, offset + line.length));
        }
        offset += line.length + 1;
      }
      if (kept.isNotEmpty) {
        result.add(
          _MappedPart(
            TtsTextPart(kept.join('\n'), literal: true),
            _joinMaps(maps),
          ),
        );
      }
    }
    if (budget.omitted) {
      result.add(
        _MappedPart(TtsTextPart(omitted, literal: true), _omissionMap),
      );
    }
    return List.unmodifiable(result);
  }

  (String, SourceTextMap?) _copyText() {
    if (!hasUi) return (source, SourceTextMap.identity(source.length));
    final result = UiBoundedText(UiBudgets.copyBytes, omission: omitted);
    final maps = <SourceTextMap?>[];
    for (final mapped in _boundedParts) {
      final part = mapped.part;
      final index = part.literal
          ? null
          : plainTextIndex(const MarkdownParser().parse(part.text));
      final text = index?.text ?? part.text;
      final map = index == null
          ? mapped.sourceMap
          : mapped.sourceMap == null
          ? null
          : SourceTextMap.fromSegments(
              index.entries.map((entry) => entry.segment),
            ).through(mapped.sourceMap!);
      var offset = 0;
      for (final line in text.split('\n')) {
        if (result.add(line) && line.isNotEmpty) {
          maps.add(map?.slice(offset, offset + line.length));
        }
        offset += line.length + 1;
      }
    }
    if (result.omitted) maps.add(_omissionMap);
    return (result.finish(), _joinMaps(maps));
  }

  String speech(TtsTextSelectionMode mode) => TtsTextSelection.prepareParts(
    _boundedParts.map((mapped) => mapped.part),
    mode: mode,
  );
}

class _MappedPart {
  const _MappedPart(this.part, this.sourceMap);
  final TtsTextPart part;
  final SourceTextMap? sourceMap;
}

SourceTextMap? _joinMaps(List<SourceTextMap?> maps) {
  if (maps.any((map) => map == null)) return null;
  return SourceTextMap.join([
    for (var i = 0; i < maps.length; i++) ...[
      if (i > 0) SourceTextMap.replacement(1, maps[i]!.sourceRange(0, 0)),
      maps[i]!,
    ],
  ]);
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
