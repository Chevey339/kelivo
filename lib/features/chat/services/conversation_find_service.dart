import 'package:flutter/foundation.dart';
import 'package:markstream/markstream_core.dart';

import '../../../core/models/assistant.dart';
import '../../../core/models/assistant_regex.dart';
import '../../../core/database/generation_run.dart';
import '../../../shared/cache/byte_lru_cache.dart';
import '../../../utils/assistant_regex.dart';
import '../../../utils/protected_text.dart';
import '../../../utils/source_text_map.dart';
import '../../../utils/unicode_case_fold.dart';
import '../../../utils/unicode_sanitizer.dart';
import '../../../utils/utf16_safe_cut.dart';
import '../../../shared/markdown/kelivo_markdown_extensions.dart';
import '../../../shared/markdown/citation_syntax.dart';
import '../../intelligent_ui/host/ui_presented_fences.dart';
import '../../intelligent_ui/catalog/ui_budgets.dart';
import '../../intelligent_ui/host/ui_generation_state.dart';
import '../../intelligent_ui/host/ui_web_document.dart';
import '../../intelligent_ui/host/ui_source_map.dart';
import '../../intelligent_ui/host/ui_user_context_parts.dart';
import '../../intelligent_ui/text/ui_search_text.dart';
import '../models/conversation_find_candidate.dart';
import '../utils/message_reasoning_source.dart';
import '../utils/assistant_paragraph_splitter.dart';
import '../utils/thinking_tag_parser.dart';
import '../widgets/timeline_projection.dart';

enum FindPart { body, reasoning, translation, surface }

typedef ConversationFindHit = ({
  String messageId,
  FindPart part,
  int block,
  int? segment,
  SourceSpan range,
  String? surfaceKey,
});

typedef ConversationFindPreview = ({
  ConversationFindHit hit,
  String role,
  int matchCount,
  String before,
  List<({String text, bool highlighted})> segments,
});

typedef FindOptions = ({bool matchCase, bool wholeWord, bool thinking});
const defaultFindOptions = (
  matchCase: false,
  wholeWord: false,
  thinking: false,
);
const _findCacheBytes = 8 * 1024 * 1024;

/// Keeps text from rendered messages so a later query can skip Markdown
/// parsing for known misses. The source snapshot and presentation must agree.
class ConversationFindCache {
  ConversationFindService? _presentation;
  late ByteLruCache<_FindCacheKey, _CachedFindText> _entries;

  ByteLruCache<_FindCacheKey, _CachedFindText> _forPresentation(
    ConversationFindService service,
  ) {
    final previous = _presentation;
    if (previous == null || !service.usesSamePresentation(previous)) {
      _presentation = service;
      _entries = ByteLruCache(
        maxBytes: _findCacheBytes,
        sizeOf: (_, entry) => entry.projection.bytes,
      );
    }
    return _entries;
  }

  void clear() {
    if (_presentation == null) return;
    _presentation = null;
    _entries.clear();
  }
}

class ConversationFindService {
  const ConversationFindService({
    this.assistant,
    this.userMarkdown = true,
    this.assistantMarkdown = true,
    this.splitAssistantParagraphs = false,
    this.reasoningMarkdown = true,
    this.parserOptions = const ParserOptions(),
    this.translationPlaceholder = '',
  });

  final Assistant? assistant;
  final bool userMarkdown, assistantMarkdown, reasoningMarkdown;
  final bool splitAssistantParagraphs;
  final ParserOptions parserOptions;
  final String translationPlaceholder;

  bool usesSamePresentation(ConversationFindService other) =>
      userMarkdown == other.userMarkdown &&
      assistantMarkdown == other.assistantMarkdown &&
      splitAssistantParagraphs == other.splitAssistantParagraphs &&
      reasoningMarkdown == other.reasoningMarkdown &&
      parserOptions == other.parserOptions &&
      translationPlaceholder == other.translationPlaceholder &&
      listEquals(assistant?.regexRules, other.assistant?.regexRules);

  Future<Map<String, List<ConversationFindHit>>> search(
    Stream<List<ConversationFindCandidate>> candidates,
    String query,
    FindOptions options, {
    ConversationFindCache? cache,
    bool Function()? isCurrent,
    ConversationFindCandidate Function(ConversationFindCandidate)?
    liveCandidate,
  }) async {
    final result = <String, List<ConversationFindHit>>{};
    await for (final hits in _searchBatches(
      candidates,
      query,
      options,
      cache: cache,
      previewsOnly: false,
      isCurrent: isCurrent,
      liveCandidate: liveCandidate,
    )) {
      result.addAll(hits.hits);
    }
    return result;
  }

  /// One snippet per matching message, in timeline order.
  Stream<List<ConversationFindPreview>> searchPreviews(
    Stream<List<ConversationFindCandidate>> candidates,
    String query, {
    ConversationFindCache? cache,
    bool Function()? isCurrent,
    ConversationFindCandidate Function(ConversationFindCandidate)?
    liveCandidate,
  }) => _searchBatches(
    candidates,
    query.trim(),
    defaultFindOptions,
    cache: cache,
    previewsOnly: true,
    isCurrent: isCurrent,
    liveCandidate: liveCandidate,
  ).map((batch) => batch.previews).where((batch) => batch.isNotEmpty);

  /// Release each batch after processing it. Superseded queries stop reading
  /// pages, and preview callers can display results as soon as a page matches.
  Stream<_FindBatch> _searchBatches(
    Stream<List<ConversationFindCandidate>> candidates,
    String query,
    FindOptions options, {
    required ConversationFindCache? cache,
    required bool previewsOnly,
    bool Function()? isCurrent,
    ConversationFindCandidate Function(ConversationFindCandidate)?
    liveCandidate,
  }) async* {
    if (query.trim().isEmpty || isCurrent?.call() == false) return;
    final entries = cache?._forPresentation(this);
    _FindCacheKey key(ConversationFindCandidate row) =>
        (row.id, options.matchCase, options.thinking);
    await for (final batch in candidates) {
      if (isCurrent?.call() == false) return;
      final rows = liveCandidate == null
          ? batch
          : batch.map(liveCandidate).toList();
      final inputs = [
        for (final row in rows)
          (row: row, cached: row.streaming ? null : entries?.get(key(row))),
      ];
      final matches = await compute(_matchBatch, (
        service: this,
        rows: inputs,
        query: query,
        options: options,
        previewsOnly: previewsOnly,
        projectionBudget: entries == null ? 0 : _findCacheBytes - entries.bytes,
      ));
      if (isCurrent?.call() == false) return;
      if (entries != null) {
        for (final row in rows) {
          if (matches.projections[row.id] case final projection?) {
            // A full timeline scan must not evict every reusable entry on
            // each keystroke in a conversation larger than the budget.
            if (entries.bytes + projection.bytes <= _findCacheBytes) {
              entries.put(key(row), _CachedFindText(row, projection));
            }
          }
        }
      }
      yield matches;
    }
  }

  Iterable<_FindText> _project(
    ConversationFindCandidate row,
    bool thinking,
  ) sync* {
    final message = row.toMessage();
    List<TimelineToolRef> tools = const [];
    late final citationLookup = citationIndexLookup(
      citationSearchItems(
        tools.reversed.map(
          (tool) => (name: tool.toolName, content: tool.content),
        ),
      ),
    );
    String? Function(UiSourceFence)? surfaceText;
    Iterable<_FindText> project(
      String source,
      FindPart part,
      int block, {
      int? segment,
      UiTextSlice? uiSource,
      SourceTextMap? blockMap,
      bool markdown = false,
    }) sync* {
      final text = UnicodeSanitizer.sanitize(source);
      _FindText fragment(
        String visible, {
        TextIndex? index,
        String? surfaceKey,
      }) => _FindText(
        text: visible,
        part: surfaceKey == null ? part : FindPart.surface,
        block: block,
        segment: segment,
        index: index,
        blockMap: surfaceKey == null ? blockMap : null,
        surfaceKey: surfaceKey,
      );
      if (text.isEmpty) return;
      if (!markdown) {
        yield fragment(text);
        return;
      }
      final doc = MarkdownParser(
        options: parserOptions,
        blockSyntaxes: kelivoMarkdownExtensions.blockSyntaxes,
        inlineSyntaxes: kelivoMarkdownExtensions.inlineSyntaxes,
      ).parse(text, streaming: row.streaming);
      // Keep leaf blocks and table cells separate. Concatenating the text of
      // two list items would invent a searchable word across the row break.
      Iterable<_FindText> projectNode(MarkdownNode node) sync* {
        if (node is TableCellNode ||
            node is BlockNode &&
                !node.children.any(
                  (child) => child is BlockNode || child is TableRowNode,
                )) {
          final leaf = node is TableCellNode
              ? ParagraphNode(span: node.span, children: node.children)
              : node as BlockNode;
          final index = TextIndex.fromDocument(
            DocumentNode(source: text, children: [leaf]),
            inlineText: (node) {
              if (node.name != 'kelivo-citation') return null;
              final resolve =
                  row.role == 'assistant' && part != FindPart.reasoning
                  ? (String id) => resolveCitationIndex(citationLookup, id)
                  : null;
              return parseCitationRefs(
                node.attributes['refs']!,
              ).map((ref) => ref.label(resolve)).join(' ');
            },
          );
          yield fragment(index.text, index: index);
        } else {
          for (final child in node.children) {
            yield* projectNode(child);
          }
        }
      }

      for (final node in doc.children) {
        if (node is CodeBlockNode &&
            uiSource != null &&
            uiSource.fences.isNotEmpty) {
          // Use the same document and source checks as the bubble. A visual
          // rule can turn an originally trusted card into ordinary code.
          final fence = uiSource.resolve(
            doc,
            node,
            allowStreamingTail: row.streaming,
          );
          final ordinal = fence == null
              ? null
              : uiSource.messageOrdinalOf(fence);
          if (fence != null &&
              ordinal != null &&
              ordinal < UiBudgets.blocksPerMessage) {
            final label = surfaceText?.call(fence);
            if (label != null) {
              yield fragment(label, surfaceKey: fence.surfaceKey);
              continue;
            }
          }
        }
        yield* projectNode(node);
      }
    }

    ProtectedText transform(ProtectedText text, AssistantRegexScope scope) =>
        applyAssistantRegexesProtected(
          text,
          assistant: assistant,
          scope: scope,
          target: AssistantRegexTransformTarget.visual,
        );
    if (row.role == 'user') {
      final text = UiUserContextParts.read(message.parts).bodyText;
      yield* project(
        transform(ProtectedText(text, const []), AssistantRegexScope.user).text,
        FindPart.body,
        0,
        markdown: userMarkdown,
      );
      return;
    }
    if (row.role != 'assistant') return;
    final source = UiMessageSource.of(message.parts);
    final parsed = messageHasProviderReasoning(message)
        ? ThinkingTagParseResult(
            visibleContent: message.content,
            thinkingTexts: const [],
          )
        : ThinkingTagParser.parseLegacyInlineBlocks(
            message.content,
            protectedRanges: source.protectedJoinedRanges,
            includeUnclosed: source.hasFences,
          );
    final visual = transform(
      ProtectedText(
        parsed.visibleContent,
        const [],
        sourceMap:
            parsed.sourceMap ?? SourceTextMap.identity(message.content.length),
      ),
      AssistantRegexScope.assistant,
    );
    final timeline = uiMessageTimeline(
      message,
      inlineThinking: parsed.thinkingTexts.join('\n\n'),
    );
    tools = timeline.tools;
    final projection = projectAssistantTimeline(
      parts: message.parts,
      liveTools: timeline.tools,
      reasoningSegments: timeline.segments,
      visualContent: visual.text,
      visualSourceMap: visual.sourceMap,
      contentSplitOffsets: timeline.splits?.offsets,
      reasoningCountAtSplit: timeline.splits?.reasoningCounts,
      toolCountAtSplit: timeline.splits?.toolCounts,
      partsArrivalOrdered: row.streaming,
      parseInlineThinking: parsed.hasThinking,
      transformProtectedText: (text) =>
          transform(text, AssistantRegexScope.assistant),
    );
    late final semantic = uiSearchableText(
      message,
      row.surfaces.isEmpty &&
              !message.isStreaming &&
              message.generationState == GenerationRunState.completed
          ? initialUiSearchText(message)
          : row.surfaces,
    );
    late final surfaces = {
      for (final surface in semantic.surfaces) surface.surfaceKey: surface,
    };
    surfaceText = (fence) {
      if (fence.isWeb) {
        final card = UiWebDocument.parse(
          fence.body,
          closed: fence.node.closed,
          generation: uiGenerationStatus(message),
        );
        return [card.title, card.summary].where((s) => s.isNotEmpty).join('\n');
      }
      final span = surfaces[fence.surfaceKey];
      return span == null
          ? null
          : semantic.text.substring(span.start, span.end);
    };

    var bodyIndex = 0;
    for (final block in projection.blocks) {
      if (block.text case final text?) {
        for (final paragraph in assistantDisplayParagraphs(
          text,
          split: splitAssistantParagraphs,
          uiSource: block.uiSource,
        )) {
          yield* project(
            paragraph.text,
            FindPart.body,
            bodyIndex,
            uiSource: paragraph.uiSource,
            blockMap: paragraph.blockMap,
            markdown: assistantMarkdown,
          );
        }
        bodyIndex++;
      } else if (thinking) {
        for (final step in block.steps) {
          if (step.reasoning case final reasoning?) {
            yield* project(
              reasoningDisplayText(reasoning.text),
              FindPart.reasoning,
              step.sourceOrdinal,
              segment: step.reasoningOverlayIndex,
              markdown: reasoningMarkdown,
            );
          }
        }
      }
    }
    final translation = message.translation;
    if (translation != null && translation != translationPlaceholder) {
      yield* project(
        transform(
          ProtectedText(translation, const []),
          AssistantRegexScope.assistant,
        ).text,
        FindPart.translation,
        0,
        markdown: assistantMarkdown,
      );
    }
  }
}

String reasoningDisplayText(String text) => text.replaceAll('\r', '').trim();

typedef _FindWork = ({
  ConversationFindService service,
  List<({ConversationFindCandidate row, _CachedFindText? cached})> rows,
  String query,
  FindOptions options,
  bool previewsOnly,
  int projectionBudget,
});

typedef _FindCacheKey = (String, bool, bool);
typedef _FindProjection = ({String text, int bytes});
typedef _FindBatch = ({
  Map<String, List<ConversationFindHit>> hits,
  List<ConversationFindPreview> previews,
  Map<String, _FindProjection> projections,
});

class _CachedFindText {
  const _CachedFindText(this.source, this.projection);
  final ConversationFindCandidate source;
  final _FindProjection projection;

  String? textFor(ConversationFindCandidate row) =>
      source.conversationId == row.conversationId &&
          source.role == row.role &&
          source.reasoning == row.reasoning &&
          source.segments == row.segments &&
          source.translation == row.translation &&
          source.generation == row.generation &&
          listEquals(source.parts, row.parts) &&
          source.surfaces.length == row.surfaces.length &&
          source.surfaces.entries.every((entry) {
            final current = row.surfaces[entry.key];
            return entry.value.sourceHash == current?.sourceHash &&
                entry.value.text == current?.text;
          })
      ? projection.text
      : null;
}

class _FindText {
  const _FindText({
    required this.text,
    required this.part,
    required this.block,
    this.segment,
    this.index,
    this.blockMap,
    this.surfaceKey,
  });

  final String text;
  final FindPart part;
  final int block;
  final int? segment;
  final TextIndex? index;
  final SourceTextMap? blockMap;
  final String? surfaceKey;

  ConversationFindHit hit(String messageId, SourceSpan span) {
    final local = index?.sourceSpanForRange(span.start, span.end) ?? span;
    return (
      messageId: messageId,
      part: part,
      block: block,
      segment: segment,
      range: blockMap?.sourceRange(local.start, local.end) ?? local,
      surfaceKey: surfaceKey,
    );
  }
}

_FindBatch _matchBatch(_FindWork work) {
  final (:service, :rows, :query, :options, :previewsOnly, :projectionBudget) =
      work;
  final pattern = _FindPattern(query, options);
  final hits = <String, List<ConversationFindHit>>{};
  final previews = <ConversationFindPreview>[];
  final projections = <String, _FindProjection>{};
  var remaining = projectionBudget;
  for (final (:row, :cached) in rows) {
    final rowHits = previewsOnly ? null : <ConversationFindHit>[];
    if (rowHits != null) hits[row.id] = rowHits;
    final cachedText = cached?.textFor(row);
    if (cachedText != null && !cachedText.contains(pattern.needle)) continue;

    final visible = remaining > 256 && !row.streaming && cachedText == null
        ? StringBuffer()
        : null;
    _FindText? previewSource;
    List<SourceSpan>? previewSpans;
    var matchCount = 0;
    for (final fragment in service._project(row, options.thinking)) {
      for (final span in pattern.ranges(fragment.text, visible: visible)) {
        if (rowHits != null) {
          rowHits.add(fragment.hit(row.id, span));
          continue;
        }
        matchCount++;
        if (previewSource == null) {
          previewSource = fragment;
          previewSpans = [span];
        } else if (identical(fragment, previewSource) &&
            span.start < previewSpans!.first.end + _snippetAfter) {
          previewSpans.add(span);
        }
      }
    }
    if (previewSource != null) {
      previews.add(_preview(row, previewSource, previewSpans!, matchCount));
    }
    if (visible != null && 2 * visible.length <= remaining) {
      // Include retained snapshot strings as well as the rendered text.
      final bytes =
          256 +
          2 *
              (visible.length +
                  (row.reasoning?.length ?? 0) +
                  (row.segments?.length ?? 0) +
                  (row.translation?.length ?? 0)) +
          row.parts.fold<int>(
            0,
            (sum, part) => sum + 128 + 2 * part.encodePayload().length,
          ) +
          row.surfaces.entries.fold<int>(
            0,
            (sum, entry) =>
                sum +
                128 +
                2 *
                    (entry.key.length +
                        entry.value.sourceHash.length +
                        entry.value.text.length),
          );
      if (bytes <= remaining) {
        projections[row.id] = (text: visible.toString(), bytes: bytes);
        remaining -= bytes;
      }
    }
  }
  return (hits: hits, previews: previews, projections: projections);
}

final _snippetWhitespace = RegExp(r'\s+');
const _snippetAfter = 84;

ConversationFindPreview _preview(
  ConversationFindCandidate row,
  _FindText fragment,
  List<SourceSpan> spans,
  int matchCount,
) {
  String oneLine(String text) => text.replaceAll(_snippetWhitespace, ' ');
  final source = fragment.text;
  final first = spans.first;
  final start = utf16SafeTailStart(
    source,
    (first.start - 16).clamp(0, source.length),
  );
  final end = utf16SafeHeadEnd(
    source,
    (first.end + _snippetAfter).clamp(0, source.length),
  );
  final segments = <({String text, bool highlighted})>[];
  var from = first.start;
  for (final span in spans) {
    if (span.start >= end) break;
    if (from < span.start) {
      segments.add((
        text: oneLine(source.substring(from, span.start)),
        highlighted: false,
      ));
    }
    from = span.end.clamp(0, end);
    segments.add((
      text: oneLine(source.substring(span.start, from)),
      highlighted: true,
    ));
  }
  final tail =
      '${oneLine(source.substring(from, end))}${end < source.length ? '…' : ''}';
  if (tail.isNotEmpty) segments.add((text: tail, highlighted: false));
  return (
    hit: fragment.hit(row.id, first),
    role: row.role,
    matchCount: matchCount,
    before:
        '${start > 0 ? '…' : ''}${oneLine(source.substring(start, first.start))}',
    segments: segments,
  );
}

class _FindPattern {
  _FindPattern(String query, FindOptions options)
    : fold = !options.matchCase,
      needle = options.matchCase
          ? query
          : query.runes.map(foldUnicodeScalar).join(),
      boundary = options.wholeWord && !_cjk.hasMatch(query);

  static final _cjk = RegExp(
    r'[\p{Script_Extensions=Han}\p{Script_Extensions=Hiragana}\p{Script_Extensions=Katakana}\p{Script_Extensions=Hangul}]',
    unicode: true,
  );
  static final _word = RegExp(r'[\p{L}\p{M}\p{N}\p{Pc}]', unicode: true);
  final String needle;
  final bool fold, boundary;

  bool _wordBefore(String source, int offset) {
    final rune = RuneIterator.at(source, offset)..movePrevious();
    return _word.hasMatch(rune.currentAsString);
  }

  Iterable<SourceSpan> ranges(String source, {StringBuffer? visible}) sync* {
    var haystack = source;
    // Only expanding folds need an offset table. Its interior boundaries are
    // invalid: searching for a single 's' must not match half of a sharp S.
    Int32List? offsets;
    if (fold) {
      final out = StringBuffer();
      final expansions = <(int, int, int)>[];
      var original = 0;
      for (final rune in source.runes) {
        final size = rune > 0xffff ? 2 : 1;
        final folded = foldUnicodeScalar(rune);
        if (size != folded.length) {
          expansions.add((out.length, folded.length, size));
        }
        out.write(folded);
        original += size;
      }
      haystack = out.toString();
      if (expansions.isNotEmpty) {
        offsets = Int32List(haystack.length + 1);
        var a = 0, b = 0;
        for (final (start, len, size) in expansions) {
          while (a < start) {
            offsets[a++] = b++;
          }
          offsets[a++] = b;
          for (var i = 1; i < len; i++) {
            offsets[a++] = -1;
          }
          b += size;
        }
        while (a <= haystack.length) {
          offsets[a++] = b++;
        }
        assert(offsets.last == original);
      }
    }
    visible?.writeln(haystack);
    var from = 0;
    while (from < haystack.length) {
      final i = haystack.indexOf(needle, from);
      if (i < 0) break;
      final end = i + needle.length;
      final a = offsets?[i] ?? i, b = offsets?[end] ?? end;
      if (a < 0 ||
          b < 0 ||
          (boundary &&
              ((a > 0 && _wordBefore(source, a)) ||
                  (b < source.length &&
                      _word.matchAsPrefix(source, b) != null)))) {
        from = i + 1;
        continue;
      }
      yield SourceSpan(a, b);
      from = end;
    }
  }
}
