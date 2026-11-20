import 'dart:math' as math;

import '../../../utils/utf16_safe_cut.dart';
import '../../models/compress_context_options.dart';
import '../../models/compression_config.dart';
import '../../models/context_compression_task.dart';
import '../../utils/token_estimator.dart';
import 'compression_prompt.dart';

typedef CompressionSegment = ({
  String prompt,
  int nextIndex,
  int nextOffset,
  int startIndex,
  int historyLength,
  int fixedLength,
  int historyBudget,
});

/// Contains only text and configuration, so method tear-offs can be sent to an
/// isolate without retaining the request's callbacks or the chat service.
class CompressionPlanner {
  CompressionPlanner({
    required CompressionRequest request,
    int? summaryTokens,
    required this.materials,
    required this.background,
  }) : template = request.resolvedTemplate,
       focus = request.options.focus,
       locale = request.locale,
       _summaryTokens = summaryTokens ?? request.config.summaryTokens {
    final requestedOutput = request.config.maxOutputTokens ?? _summaryTokens;
    outputTokens = math.min(
      requestedOutput,
      request.maxOutputTokens ?? requestedOutput,
    );
    _window =
        request.contextWindowTokens ??
        CompressContextOptions.defaultContextWindowTokens;
  }

  final List<String> materials;
  final CompressionTemplate template;
  final String focus;
  final String locale;
  final int _summaryTokens;
  late final int _window;
  String background;
  int? _retryPromptLength;
  int _firstWorkingHistoryProbe = 0;
  int _releasedOutputTokens = 0;
  bool _useStoredSummary = true;
  late int outputTokens;
  String previousSummary = '';
  int index = 0;
  int offset = 0;

  int get targetTokens => math.min(_summaryTokens, outputTokens);
  int get inputLimit => _window - outputTokens - (_window * .05).ceil();
  bool get hasReference => background.isNotEmpty;
  static const _probeCharsPerToken = 8;

  String _render(String content, String summary) => renderCompressionPrompt(
    template: template,
    content: content,
    previousSummary: summary,
    background: background,
    focus: focus,
    locale: locale,
    targetTokens: targetTokens,
  );

  CompressionRequestPreview preview() {
    final first = next();
    final budget = first.historyBudget;
    var remainingTokens = 0;
    for (var i = first.nextIndex; i < materials.length; i++) {
      final text = i == first.nextIndex && first.nextOffset > 0
          ? materials[i].substring(first.nextOffset)
          : materials[i];
      final probeTokens =
          (text.length + _probeCharsPerToken - 1) ~/ _probeCharsPerToken;
      remainingTokens += math.max(estimateTokens(text), probeTokens) + 1;
    }
    return (
      prompt: first.prompt,
      estimatedRequests: 1 + (remainingTokens + budget - 1) ~/ budget,
    );
  }

  CompressionSegment next() {
    var startIndex = index;
    var summary = previousSummary;
    var fixed = _render('', summary);
    var available = inputLimit - estimateTokens(fixed);
    if (_useStoredSummary && index == 0 && offset == 0) {
      final initial = _leadingSummaries(available - 128);
      if (initial.isNotEmpty) {
        final combined = initial.join('\n\n');
        final withSummary = _render('', combined);
        final remaining = inputLimit - estimateTokens(withSummary);
        if (remaining >= 128) {
          summary = combined;
          fixed = withSummary;
          available = remaining;
          startIndex = initial.length;
        }
      }
    }

    // The estimate guides packing even when it leaves too little room.
    // After a rejection, reuse the size learned for the complete prompt.
    final budget = math.max(128, available);
    final limit = _retryPromptLength;
    final historyLimit = limit == null
        ? null
        : math.max(_firstWorkingHistoryProbe, limit - fixed.length);
    final startOffset = startIndex == index ? offset : 0;
    CompressionSegment segment(
      String content,
      int nextIndex,
      int nextOffset,
      int historyLength,
    ) => (
      prompt: content.isEmpty ? fixed : _render(content, summary),
      nextIndex: nextIndex,
      nextOffset: nextOffset,
      startIndex: startIndex,
      historyLength: historyLength,
      fixedLength: fixed.length,
      historyBudget: budget,
    );
    final pieces = <String>[];
    var historyLength = 0;
    var remainingTokens = budget;
    for (var i = startIndex; i < materials.length; i++) {
      final text = materials[i];
      final start = i == startIndex ? startOffset : 0;
      final length = text.length - start;
      final remainingLength = historyLimit == null
          ? null
          : historyLimit - historyLength;
      if (length > _candidateLength(length, remainingTokens, remainingLength)) {
        break;
      }
      final whole = _fragment(i, start, text.length);
      final cost = estimateTokens(whole) + 1;
      if (cost > remainingTokens) break;
      pieces.add(whole);
      historyLength += length;
      remainingTokens -= cost;
    }
    if (pieces.isNotEmpty || startIndex == materials.length) {
      return segment(
        pieces.join('\n\n'),
        startIndex + pieces.length,
        0,
        historyLength,
      );
    }

    final text = materials[startIndex];
    final firstEnd = utf16SafeTailStart(text, startOffset + 1);
    final probeEnd = utf16SafeHeadEnd(
      text,
      math.max(
        firstEnd,
        startOffset +
            _candidateLength(text.length - startOffset, budget, historyLimit),
      ),
    );
    final headerTokens = estimateTokens(
      _fragment(startIndex, startOffset, startOffset),
    );
    final fragmentBudget = math.max(1, budget - headerTokens);
    final estimated = estimateTokens(text.substring(startOffset, probeEnd));
    var end = probeEnd;
    if (estimated > fragmentBudget) {
      final length = ((probeEnd - startOffset) * (fragmentBudget / estimated))
          .floor();
      end = utf16SafeHeadEnd(text, math.max(firstEnd, startOffset + length));
    }
    final slice = text.substring(startOffset, end);
    final paragraph = slice.lastIndexOf('\n\n');
    final line = slice.lastIndexOf('\n');
    final halfway = slice.length ~/ 2;
    if (paragraph >= halfway) {
      end = startOffset + paragraph + 2;
    } else if (line >= halfway) {
      end = startOffset + line + 1;
    }
    return segment(
      _fragment(startIndex, startOffset, end),
      end == text.length ? startIndex + 1 : startIndex,
      end == text.length ? 0 : end,
      end - startOffset,
    );
  }

  List<String> _leadingSummaries(int budget) {
    final summaries = <String>[];
    for (final text in materials) {
      if (budget <= 0 || !text.startsWith(compressionSummarySourcePrefix)) {
        break;
      }
      final headerEnd = text.indexOf('\n');
      if (headerEnd < 0) break;
      final summary = text.substring(headerEnd + 1);
      final cost = estimateTokens(summary) + 1;
      if (cost > budget) break;
      summaries.add(summary);
      budget -= cost;
    }
    return summaries;
  }

  /// Recover only after a real rejection. Halve the source span that was
  /// actually sent and leave the cursor at the start of that span.
  bool backOff(CompressionSegment rejected) {
    _firstWorkingHistoryProbe = 0;
    final start = rejected.startIndex;
    final startOffset = start == index ? offset : 0;
    final firstLength = start == materials.length
        ? 0
        : utf16SafeTailStart(materials[start], startOffset + 1) - startOffset;
    final canSplit = rejected.historyLength > firstLength;
    if (hasReference &&
        (!canSplit || background.length >= rejected.historyLength)) {
      background = '';
      return true;
    }
    if (canSplit) {
      _retryPromptLength =
          rejected.fixedLength +
          math.max(firstLength, rejected.historyLength ~/ 2);
      return true;
    }
    if (start > index) {
      _useStoredSummary = false;
      return true;
    }
    if (outputTokens > 128) {
      final smallerOutput = math.max(128, outputTokens ~/ 2);
      _releasedOutputTokens += outputTokens - smallerOutput;
      outputTokens = smallerOutput;
      return true;
    }
    return false;
  }

  void accept(CompressionSegment segment, String summary) {
    final retryLength = _retryPromptLength;
    if (retryLength != null || _releasedOutputTokens > 0) {
      final acceptedLength =
          segment.fixedLength + segment.historyLength + _releasedOutputTokens;
      _retryPromptLength = math.max(retryLength ?? 0, acceptedLength);
      // The first working summary adds a different prompt section. Probe once
      // with a source span that just worked and adjust to its measured size.
      _firstWorkingHistoryProbe =
          previousSummary.isEmpty && segment.startIndex == index
          ? segment.historyLength + _releasedOutputTokens
          : 0;
      _releasedOutputTokens = 0;
    }
    index = segment.nextIndex;
    offset = segment.nextOffset;
    previousSummary = summary;
  }

  int _candidateLength(int length, int tokens, int? remainingLength) {
    // Scale prefix probing with the available tokens. This avoids walking an
    // enormous unread suffix for every fragment, including low-token whitespace.
    return math.min(
      math.min(length, remainingLength ?? length),
      math.min(length, tokens) * _probeCharsPerToken,
    );
  }

  String _fragment(int index, int start, int end) {
    final text = materials[index];
    if (start == 0 && end == text.length) return text;
    final header = text.startsWith('[source ')
        ? text.substring(0, math.min(text.length, 256))
        : '';
    final headerEnd = header.indexOf('\n');
    final parent = headerEnd >= 0
        ? header.substring(0, headerEnd)
        : 'material:${index + 1}';
    return '[source fragment ${index + 1}; parent=$parent; UTF-16 $start..$end/${text.length}]\n${text.substring(start, end)}';
  }
}
