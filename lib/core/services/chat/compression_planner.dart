import 'dart:math' as math;

import '../../models/compress_context_options.dart';
import '../../models/compression_config.dart';
import '../../models/context_compression_task.dart';
import '../../utils/token_estimator.dart';
import '../../../utils/utf16_safe_cut.dart';
import 'compression_prompt.dart';

typedef CompressionSegment = ({String prompt, int nextIndex, int nextOffset});

/// Contains only text and configuration, so method tear-offs can be sent to an
/// isolate without retaining a request's callbacks or the chat service.
class CompressionPlanner {
  CompressionPlanner({
    required CompressionRequest request,
    required this.materials,
    required this.previousSummary,
    required this.background,
    this.continuation = '',
  }) : template = request.resolvedTemplate,
       focus = request.options.focus,
       locale = request.locale,
       outputTokens = math.min(
         request.config.summaryTokens,
         request.maxOutputTokens ?? request.config.summaryTokens,
       ),
       maxRequestAttempts = request.config.maxRequestAttempts {
    final window =
        request.contextWindowTokens ??
        CompressContextOptions.defaultContextWindowTokens;
    inputLimit = window - outputTokens - (window * .05).ceil();
  }

  /// Bounds local string/JSON work even when the model has a very large window.
  /// Long inputs are split without dropping any source text.
  static const maxPromptChars = 100000;

  final List<String> materials;
  final CompressionTemplate template;
  final String focus;
  final String locale;
  final int outputTokens;
  final int maxRequestAttempts;
  final String background;
  final String continuation;
  String previousSummary;
  late int inputLimit;
  int index = 0;
  int offset = 0;

  String render(String content) => renderCompressionPrompt(
    template: template,
    content: content,
    previousSummary: previousSummary,
    background: background,
    continuation: continuation,
    focus: focus,
    locale: locale,
    targetTokens: outputTokens,
  );

  bool _fits(String prompt) =>
      prompt.length <= maxPromptChars && estimateTokens(prompt) <= inputLimit;

  int estimateRequests() {
    final initialIndex = index;
    final initialOffset = offset;
    final initialSummary = previousSummary;
    var count = 0;
    try {
      do {
        final segment = next();
        count++;
        index = segment.nextIndex;
        offset = segment.nextOffset;
        if (index == materials.length) return count;
        // Follow the same message boundaries and fragment headers as execution.
        // Reserve a full working summary in both budgets, using eight chars per
        // estimated token. Actual model output is still checked by next().
        if (count == 1) previousSummary = 'summary ' * outputTokens;
      } while (true);
    } finally {
      index = initialIndex;
      offset = initialOffset;
      previousSummary = initialSummary;
    }
  }

  CompressionRequestPreview preview() => (
    prompt: next().prompt,
    estimatedRequests: estimateRequests(),
    maxRequestAttempts: maxRequestAttempts,
  );

  CompressionSegment next() {
    final empty = render('');
    if (!_fits(empty)) throw StateError('compression_reference_too_large');
    if (index == materials.length) {
      return (prompt: empty, nextIndex: index, nextOffset: 0);
    }
    final availableChars = maxPromptChars - empty.length;
    final pieces = <String>[];
    var chars = 0;
    for (var i = index; i < materials.length; i++) {
      final text = materials[i];
      final start = i == index ? offset : 0;
      final separator = pieces.isEmpty ? 0 : 2;
      // Check lengths before copying an oversized message or suffix.
      if (chars + separator + text.length - start > availableChars) break;
      final whole = _fragment(i, start, text.length);
      if (chars + separator + whole.length > availableChars) break;
      pieces.add(whole);
      chars += separator + whole.length;
    }
    if (pieces.isNotEmpty) {
      var count = pieces.length;
      var payload = render(pieces.join('\n\n'));
      if (!_fits(payload)) {
        // Search whole-message boundaries instead of re-counting every growing
        // prefix. Every candidate is already bounded by the local character cap.
        var low = 0;
        var high = count - 1;
        while (low < high) {
          final mid = (low + high + 1) ~/ 2;
          if (_fits(render(pieces.take(mid).join('\n\n')))) {
            low = mid;
          } else {
            high = mid - 1;
          }
        }
        count = low;
        payload = render(pieces.take(count).join('\n\n'));
      }
      if (count > 0) {
        return (prompt: payload, nextIndex: index + count, nextOffset: 0);
      }
    }

    // Only split a message when it cannot fit on its own. Bound the search
    // before taking substrings, and keep absolute, surrogate-safe offsets.
    final text = materials[index];
    var low = 0;
    var high = math.min(text.length - offset, availableChars);
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      final end = utf16SafeHeadEnd(text, offset + mid);
      if (_fits(render(_fragment(index, offset, end)))) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    var end = utf16SafeHeadEnd(text, offset + low);
    if (end - offset < math.min(16, text.length - offset)) {
      throw StateError('compression_reference_too_large');
    }
    final slice = text.substring(offset, end);
    final paragraph = slice.lastIndexOf('\n\n');
    final line = slice.lastIndexOf('\n');
    final halfway = slice.length ~/ 2;
    final boundary = paragraph >= halfway
        ? offset + paragraph + 2
        : line >= halfway
        ? offset + line + 1
        : end;
    if (boundary <= end && _fits(render(_fragment(index, offset, boundary)))) {
      end = boundary;
    }
    final payload = render(_fragment(index, offset, end));
    if (!_fits(payload)) throw StateError('compression_reference_too_large');
    return (
      prompt: payload,
      nextIndex: end == text.length ? index + 1 : index,
      nextOffset: end == text.length ? 0 : end,
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
