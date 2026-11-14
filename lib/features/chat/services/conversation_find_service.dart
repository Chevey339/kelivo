import 'package:flutter/foundation.dart';
import 'package:markstream/markstream_core.dart';

import '../../../core/models/assistant.dart';
import '../../../core/models/assistant_regex.dart';
import '../../../core/database/generation_run.dart';
import '../../../utils/assistant_regex.dart';
import '../../../utils/protected_text.dart';
import '../../../utils/source_text_map.dart';
import '../../../utils/unicode_case_fold.dart';
import '../../../utils/unicode_sanitizer.dart';
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

typedef FindOptions = ({bool matchCase, bool wholeWord, bool thinking});
const defaultFindOptions = (
  matchCase: false,
  wholeWord: false,
  thinking: false,
);

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

  /// Keep full message snapshots out of the widget tree and release each batch
  /// as soon as it has been projected. A superseded query stops reading pages.
  Future<Map<String, List<ConversationFindHit>>> search(
    Stream<List<ConversationFindCandidate>> candidates,
    String query,
    FindOptions options, {
    bool Function()? isCurrent,
    ConversationFindCandidate Function(ConversationFindCandidate)?
    liveCandidate,
  }) async {
    final result = <String, List<ConversationFindHit>>{};
    if (query.trim().isEmpty) return result;
    await for (final batch in candidates) {
      if (isCurrent?.call() == false) break;
      final rows = liveCandidate == null
          ? batch
          : batch.map(liveCandidate).toList();
      final hits = await compute(_matchBatch, (this, rows, query, options));
      if (isCurrent?.call() == false) break;
      result.addAll(hits);
    }
    return result;
  }

  List<ConversationFindHit> _match(
    ConversationFindCandidate row,
    _FindPattern pattern,
    bool thinking,
  ) {
    final message = row.toMessage();
    final hits = <ConversationFindHit>[];
    List<TimelineToolRef> tools = const [];
    late final citationLookup = citationIndexLookup(
      citationSearchItems(
        tools.reversed.map(
          (tool) => (name: tool.toolName, content: tool.content),
        ),
      ),
    );
    String? Function(UiSourceFence)? surfaceText;
    void add(
      String source,
      FindPart part,
      int block, {
      int? segment,
      UiTextSlice? uiSource,
      SourceTextMap? blockMap,
      bool markdown = false,
    }) {
      final text = UnicodeSanitizer.sanitize(source);
      void match(String visible, {TextIndex? index, String? surfaceKey}) {
        for (final span in pattern.ranges(visible)) {
          final local = index?.sourceSpanForRange(span.start, span.end) ?? span;
          hits.add((
            messageId: row.id,
            part: surfaceKey == null ? part : FindPart.surface,
            block: block,
            segment: segment,
            range: surfaceKey == null && blockMap != null
                ? blockMap.sourceRange(local.start, local.end)
                : local,
            surfaceKey: surfaceKey,
          ));
        }
      }

      if (text.isEmpty) return;
      if (!markdown) {
        match(text);
        return;
      }
      final doc = MarkdownParser(
        options: parserOptions,
        blockSyntaxes: kelivoMarkdownExtensions.blockSyntaxes,
        inlineSyntaxes: kelivoMarkdownExtensions.inlineSyntaxes,
      ).parse(text, streaming: row.streaming);
      // Keep leaf blocks and table cells separate. Concatenating the text of
      // two list items would invent a searchable word across the row break.
      void matchNode(MarkdownNode node) {
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
          match(index.text, index: index);
        } else {
          for (final child in node.children) {
            matchNode(child);
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
              match(label, surfaceKey: fence.surfaceKey);
              continue;
            }
          }
        }
        matchNode(node);
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
      add(
        transform(ProtectedText(text, const []), AssistantRegexScope.user).text,
        FindPart.body,
        0,
        markdown: userMarkdown,
      );
      return hits;
    }
    if (row.role != 'assistant') return hits;
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
          add(
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
            add(
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
      add(
        transform(
          ProtectedText(translation, const []),
          AssistantRegexScope.assistant,
        ).text,
        FindPart.translation,
        0,
        markdown: assistantMarkdown,
      );
    }
    return hits;
  }
}

String reasoningDisplayText(String text) => text.replaceAll('\r', '').trim();

Map<String, List<ConversationFindHit>> _matchBatch(
  (
    ConversationFindService,
    List<ConversationFindCandidate>,
    String,
    FindOptions,
  )
  work,
) {
  final (service, rows, query, options) = work;
  final pattern = _FindPattern(query, options);
  return {
    for (final row in rows)
      row.id: service._match(row, pattern, options.thinking),
  };
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

  Iterable<SourceSpan> ranges(String source) sync* {
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
