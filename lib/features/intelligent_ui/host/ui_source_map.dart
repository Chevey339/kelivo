import 'package:Kelivo/utils/protected_text.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:markstream/markstream_core.dart';

/// Original coordinates precede thinking extraction, visual regexes and bubbles.
/// Every non-text part is a hard run boundary, including invisible attachments.
final class UiMessageSource {
  UiMessageSource._(this.runs, this._parts);
  static final _memo = Expando<UiMessageSource>();
  static final empty = UiMessageSource._(const [], const {});
  final List<UiTextRun> runs;
  final Map<int, (UiTextRun, UiRunPart)> _parts;

  static UiMessageSource of(List<MessagePart> parts) =>
      _memo[parts] ??= _hasCandidate(parts) ? _parse(parts) : empty;

  static bool _hasCandidate(List<MessagePart> parts) {
    var tail = '';
    for (final part in parts) {
      if (part is! TextPart) {
        tail = '';
        continue;
      }
      final text = part.text;
      if (text.contains('kelivo-ui') ||
          text.contains('kelivo-web') ||
          const ['kelivo-ui', 'kelivo-web'].any(
            (tag) => (tail + text.substring(0, text.length.clamp(0, 9)))
                .contains(tag),
          )) {
        return true;
      }
      final end = text.length >= 9 ? text : tail + text;
      tail = end.substring((end.length - 9).clamp(0, end.length));
    }
    return false;
  }

  static UiMessageSource _parse(List<MessagePart> parts) {
    final runs = <UiTextRun>[];
    final mapped = <int, (UiTextRun, UiRunPart)>{};
    var joinedOffset = 0;
    var partIndex = 0;
    while (partIndex < parts.length) {
      if (parts[partIndex] is! TextPart) {
        partIndex++;
        continue;
      }
      final first = partIndex;
      final start = joinedOffset;
      final buffer = StringBuffer();
      final runParts = <UiRunPart>[];
      while (partIndex < parts.length && parts[partIndex] is TextPart) {
        final text = (parts[partIndex] as TextPart).text;
        runParts.add(UiRunPart(partIndex, buffer.length, text.length));
        buffer.write(text);
        joinedOffset += text.length;
        partIndex++;
      }
      final run = UiTextRun._(first, start, buffer.toString(), runParts);
      run._parseFences();
      runs.add(run);
      for (final part in runParts) {
        mapped[part.ordinal] = (run, part);
      }
    }
    return UiMessageSource._(List.unmodifiable(runs), Map.unmodifiable(mapped));
  }

  bool get hasFences => runs.any((r) => r.fences.isNotEmpty);
  bool get hasCandidate => runs.isNotEmpty;
  List<SourceSpan> get protectedJoinedRanges => [
    for (final run in runs)
      for (final fence in run.fences)
        SourceSpan(
          run.joinedStart + fence.node.span.start,
          run.joinedStart + fence.node.span.end,
        ),
  ];

  /// Historical split offsets address joined original text, while non-text
  /// parts still delimit separate runs. Never invent a cross-attachment fence.
  Iterable<UiTextSlice> slicesBetween(
    int start,
    int end, {
    List<SourceSpan> excluded = const [],
  }) sync* {
    for (final run in runs) {
      var cursor = start.clamp(
        run.joinedStart,
        run.joinedStart + run.source.length,
      );
      final limit = end.clamp(
        run.joinedStart,
        run.joinedStart + run.source.length,
      );
      if (cursor >= limit) continue;
      for (final hidden in excluded) {
        if (hidden.end <= cursor) continue;
        if (hidden.start >= limit) break;
        if (hidden.start > cursor) {
          yield UiTextSlice.original(
            run,
            cursor - run.joinedStart,
            hidden.start - run.joinedStart,
          );
        }
        cursor = hidden.end.clamp(cursor, limit);
      }
      if (cursor < limit) {
        yield UiTextSlice.original(
          run,
          cursor - run.joinedStart,
          limit - run.joinedStart,
        );
      }
    }
  }

  UiTextSlice? sliceForPart(int ordinal, int start, int end) {
    final source = _parts[ordinal];
    if (source == null) return null;
    final (run, part) = source;
    if (!run.source.contains('kelivo-ui') &&
        !run.source.contains('kelivo-web')) {
      return null;
    }
    if (start < 0 || start > end || end > part.length) {
      throw RangeError('Invalid original TextPart slice');
    }
    return UiTextSlice.original(
      run,
      part.runOffset + start,
      part.runOffset + end,
    );
  }
}

final class UiRunPart {
  const UiRunPart(this.ordinal, this.runOffset, this.length);
  final int ordinal, runOffset, length;
}

final class UiTextRun {
  UiTextRun._(
    this.firstPartOrdinal,
    this.joinedStart,
    this.source,
    List<UiRunPart> parts,
  ) : parts = List.unmodifiable(parts);
  final int firstPartOrdinal, joinedStart;
  final String source;
  final List<UiRunPart> parts;
  late final List<UiSourceFence> fences;

  void _parseFences() {
    if (!source.contains('kelivo-ui') && !source.contains('kelivo-web')) {
      fences = const [];
      return;
    }
    final document = const MarkdownParser().parse(source, streaming: true);
    final nodes = <CodeBlockNode>[];
    final pending = <MarkdownNode>[document];
    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      if (node is CodeBlockNode &&
          const {'kelivo-ui', 'kelivo-web'}.contains(node.info.trim())) {
        nodes.add(node);
      }
      pending.addAll(node.children.reversed);
    }
    var nativeOrdinal = 0;
    var webOrdinal = 0;
    fences = List.unmodifiable([
      for (final node in nodes)
        UiSourceFence._(
          this,
          node.info.trim() == 'kelivo-web' ? webOrdinal++ : nativeOrdinal++,
          node,
          document.children.contains(node),
        ),
    ]);
  }
}

final class UiSourceFence {
  const UiSourceFence._(this.run, this.ordinal, this.node, this.topLevel);
  final UiTextRun run;
  final int ordinal;
  final CodeBlockNode node;
  final bool topLevel;
  bool get isWeb => node.info.trim() == 'kelivo-web';
  String get surfaceKey =>
      '${isWeb ? "web:" : ""}${run.firstPartOrdinal}:$ordinal';
  String get source => node.span.slice(run.source);

  /// Markstream adds a display-only LF at an unfinished source line. Never
  /// send that synthetic terminator to the physical-line DSL reducer.
  String get body => [
    for (final child in node.children)
      if (child.span.end > child.span.start) child.text,
  ].join();
}

final class UiMappedFence {
  const UiMappedFence(this.fence, this.span);
  final UiSourceFence fence;
  final SourceSpan span;
}

/// Inline thinking can split one original run into multiple display parts.
/// Transform its visible whole once, then project each original interval back
/// out. In particular, ^/$ cannot restart at a synthetic reasoning boundary.
final class UiTextProjection {
  UiTextProjection(
    Iterable<UiTextSlice> sources,
    ProtectedText Function(ProtectedText) transform,
  ) {
    final grouped = <UiTextRun, List<UiTextSlice>>{};
    for (final source in sources) {
      grouped.putIfAbsent(source.run, () => []).add(source);
    }
    for (final entry in grouped.entries) {
      final pieces = <UiTextSlice>[];
      final anchors = <int>{};
      for (final source in entry.value) {
        anchors.addAll([source.originalStart, source.originalEnd]);
        final merged = pieces.lastOrNull?.append(source);
        if (merged == null) {
          pieces.add(source);
        } else {
          pieces[pieces.length - 1] = merged;
        }
      }
      final ordered = anchors.toList()..sort();
      final mapped = UiTextSlice.visible(
        entry.key,
        pieces: pieces,
        offsets: ordered,
      ).transform(transform);
      _runs[entry.key] = (
        mapped,
        {
          for (var i = 0; i < ordered.length; i++)
            ordered[i]: mapped.trackedOffsets[i],
        },
      );
    }
  }
  final _runs = <UiTextRun, (UiTextSlice, Map<int, int>)>{};
  UiTextSlice project(UiTextSlice source) {
    final (run, offsets) = _runs[source.run]!;
    return run.slice(
      offsets[source.originalStart]!,
      offsets[source.originalEnd]!,
    );
  }
}

final class UiTextSlice {
  UiTextSlice._(
    this.run,
    this.originalStart,
    this.originalEnd,
    this.text,
    this.original,
    Iterable<UiMappedFence> fences, {
    this.firstMessageOrdinal,
    this.firstWebMessageOrdinal,
    this.trackedOffsets = const [],
    this.trackedBeforeInsertion = const [],
  }) : fences = List.unmodifiable(fences);
  factory UiTextSlice.original(UiTextRun run, int start, int end) =>
      UiTextSlice._(run, start, end, run.source.substring(start, end), true, [
        for (final fence in run.fences)
          if (fence.node.span.start >= start && fence.node.span.end <= end)
            UiMappedFence(
              fence,
              SourceSpan(
                fence.node.span.start - start,
                fence.node.span.end - start,
              ),
            ),
      ]);
  final UiTextRun run;
  final int originalStart, originalEnd;
  final String text;
  final bool original;
  final List<UiMappedFence> fences;
  final int? firstMessageOrdinal, firstWebMessageOrdinal;
  final List<int> trackedOffsets;
  final List<bool> trackedBeforeInsertion;

  /// Remove hidden reasoning before matching whole-run visual expressions and
  /// retain split anchors in the same coordinate system as the protected code.
  factory UiTextSlice.visible(
    UiTextRun run, {
    required List<UiTextSlice> pieces,
    required List<int> offsets,
  }) {
    final buffer = StringBuffer();
    final fences = <UiMappedFence>[];
    for (final piece in pieces) {
      final base = buffer.length;
      buffer.write(piece.text);
      fences.addAll([
        for (final f in piece.fences)
          UiMappedFence(
            f.fence,
            SourceSpan(f.span.start + base, f.span.end + base),
          ),
      ]);
    }
    return UiTextSlice._(
      run,
      0,
      run.source.length,
      buffer.toString(),
      false,
      fences,
      trackedBeforeInsertion: [
        for (final offset in offsets)
          offset <= (pieces.firstOrNull?.originalStart ?? 0),
      ],
      trackedOffsets: [
        for (final offset in offsets)
          pieces.fold<int>(
            0,
            (sum, piece) =>
                sum +
                (offset - piece.originalStart).clamp(
                  0,
                  piece.originalEnd - piece.originalStart,
                ),
          ),
      ],
    );
  }
  int get topLevelFenceCount =>
      fences.where((item) => item.fence.topLevel && !item.fence.isWeb).length;
  int get topLevelWebFenceCount =>
      fences.where((item) => item.fence.topLevel && item.fence.isWeb).length;

  UiTextSlice withFirstMessageOrdinal(int ordinal, {int webOrdinal = 0}) =>
      UiTextSlice._(
        run,
        originalStart,
        originalEnd,
        text,
        original,
        fences,
        firstMessageOrdinal: ordinal,
        firstWebMessageOrdinal: webOrdinal,
      );

  int? messageOrdinalOf(UiSourceFence fence) {
    final first = fence.isWeb ? firstWebMessageOrdinal : firstMessageOrdinal;
    if (first == null) return null;
    var ordinal = first;
    for (final item in fences) {
      if (!item.fence.topLevel || item.fence.isWeb != fence.isWeb) continue;
      if (identical(item.fence, fence)) return ordinal;
      ordinal++;
    }
    return null;
  }

  UiTextSlice? append(UiTextSlice next) {
    if (!original ||
        !next.original ||
        !identical(run, next.run) ||
        originalEnd != next.originalStart) {
      return null;
    }
    return UiTextSlice.original(run, originalStart, next.originalEnd);
  }

  /// Only ordinary prose goes through display regexes. Protected code retains
  /// exact source bytes and its identity even when surrounding text changes.
  UiTextSlice transform(ProtectedText Function(ProtectedText) transformText) {
    final transformed = transformText(
      ProtectedText(
        text,
        [for (final f in fences) f.span],
        offsets: trackedOffsets,
        beforeInsertion: trackedBeforeInsertion,
      ),
    );
    if (transformed.ranges.length != fences.length) {
      throw StateError('Protected text lost original source intervals');
    }
    return UiTextSlice._(
      run,
      originalStart,
      originalEnd,
      transformed.text,
      false,
      [
        for (var i = 0; i < fences.length; i++)
          UiMappedFence(fences[i].fence, transformed.ranges[i]),
      ],
      firstMessageOrdinal: firstMessageOrdinal,
      firstWebMessageOrdinal: firstWebMessageOrdinal,
      trackedOffsets: transformed.offsets,
      trackedBeforeInsertion: transformed.beforeInsertion,
    );
  }

  /// Paragraphs carry exact source intervals, never a search for matching text.
  UiTextSlice slice(int start, int end) => UiTextSlice._(
    run,
    originalStart,
    originalEnd,
    text.substring(start, end),
    false,
    [
      for (final item in fences)
        if (item.span.start >= start && item.span.end <= end)
          UiMappedFence(
            item.fence,
            SourceSpan(item.span.start - start, item.span.end - start),
          ),
    ],
    firstMessageOrdinal: firstMessageOrdinal == null
        ? null
        : firstMessageOrdinal! +
              fences
                  .where(
                    (item) =>
                        item.fence.topLevel &&
                        !item.fence.isWeb &&
                        item.span.start < start,
                  )
                  .length,
    firstWebMessageOrdinal: firstWebMessageOrdinal == null
        ? null
        : firstWebMessageOrdinal! +
              fences
                  .where(
                    (item) =>
                        item.fence.topLevel &&
                        item.fence.isWeb &&
                        item.span.start < start,
                  )
                  .length,
  );

  UiSourceFence? resolve(DocumentNode document, CodeBlockNode node) {
    if (!document.children.contains(node)) {
      return null;
    }
    for (final item in fences) {
      if (item.fence.topLevel &&
          node.span.start == item.span.start &&
          node.span.end == item.span.end &&
          // A completed prefix can retain its prior document while later text
          // streams. Both source intervals must still equal the original fence.
          node.span.slice(document.source) == item.fence.source &&
          node.span.slice(text) == item.fence.source) {
        return item.fence;
      }
    }
    return null;
  }
}
