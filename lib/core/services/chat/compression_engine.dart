import '../api/generation/model_request_attempts.dart';
import 'dart:math' as math;

import '../../models/compress_context_options.dart';
import '../../models/context_compression_task.dart';
import '../../models/token_usage.dart';
import '../../utils/token_estimator.dart';
import '../../../utils/utf16_safe_cut.dart';
import 'compression_prompt.dart';

/// Uses the same fixed prompt and working-summary reserve as execution.
int plannedCompressionRequests({
  required String prompt,
  required String promptWithoutHistory,
  required String history,
  required int inputLimit,
  required int outputLimit,
}) {
  final oneShot = estimateTokens(prompt) <= inputLimit;
  final segmentBudget =
      inputLimit -
      estimateTokens(promptWithoutHistory) -
      (oneShot ? 0 : outputLimit);
  if (segmentBudget <= 32) throw StateError('compression_reference_too_large');
  return oneShot
      ? 1
      : (estimateTokens(history) / (segmentBudget - 32)).ceil().clamp(
          1,
          1 << 30,
        );
}

/// A chronological fold. Only the final, complete summary can be installed.
/// Every API attempt (including overflow retries) belongs to the task budget.
class CompressionEngine {
  const CompressionEngine();

  Future<String> run({
    required ContextCompressionTask task,
    required CompressionRequest request,
    required List<String> materials,
    required String previousSummary,
    required String background,
    String continuation = '',
    required void Function() check,
    required Future<void> Function() publish,
  }) async {
    final window =
        request.contextWindowTokens ??
        CompressContextOptions.defaultContextWindowTokens;
    final output = math.min(
      request.config.summaryTokens,
      request.maxOutputTokens ?? request.config.summaryTokens,
    );
    var inputLimit = window - output - (window * .05).ceil();
    String prompt(String content, String previous) => renderCompressionPrompt(
      template: request.resolvedTemplate,
      content: content,
      previousSummary: previous,
      background: background,
      continuation: continuation,
      focus: request.options.focus,
      locale: request.locale,
      targetTokens: output,
    );
    // Reserve a complete working summary for subsequent segments before
    // spending anything. There is no final, redundant merge request.
    final all = materials.join('\n\n');
    task.totalParts = plannedCompressionRequests(
      prompt: prompt(all, previousSummary),
      promptWithoutHistory: prompt('', previousSummary),
      history: all,
      inputLimit: inputLimit,
      outputLimit: output,
    );
    if (task.totalParts > request.config.maxRequestAttempts) {
      throw StateError('compression_request_budget');
    }
    task.phase = CompressionPhase.summarizing;
    await publish();
    var previous = previousSummary;
    var index = 0;
    var offset = 0;
    // A previous-summary-only rebuild is still one explicit call.
    var pending = materials.isEmpty;
    while (index < materials.length || pending) {
      check();
      if (task.requestAttempts >= request.config.maxRequestAttempts) {
        throw StateError('compression_request_budget');
      }
      final pieces = <String>[];
      var nextIndex = index;
      var nextOffset = offset;
      while (nextIndex < materials.length) {
        final text = materials[nextIndex];
        final remaining = text.substring(nextOffset);
        String fragment(String value, int end) =>
            nextOffset == 0 && end == text.length
            ? value
            : '[source fragment ${nextIndex + 1}; parent=${text.startsWith('[source ') ? text.split('\n').first : 'material:${nextIndex + 1}'}; UTF-16 $nextOffset..$end/${text.length}]\n$value';
        final whole = fragment(remaining, text.length);
        if (estimateTokens(prompt([...pieces, whole].join('\n\n'), previous)) <=
            inputLimit) {
          pieces.add(whole);
          nextIndex++;
          nextOffset = 0;
          continue;
        }
        if (pieces.isNotEmpty) break;
        // Split only an oversized single message. Prefer paragraph / line
        // boundaries and never split a surrogate pair or omit a suffix.
        var low = 0;
        var high = remaining.length;
        while (low < high) {
          final mid = (low + high + 1) ~/ 2;
          final prefix = truncateHeadUtf16Safe(remaining, mid);
          if (estimateTokens(
                prompt(fragment(prefix, nextOffset + prefix.length), previous),
              ) <=
              inputLimit) {
            low = mid;
          } else {
            high = mid - 1;
          }
        }
        var cut = truncateHeadUtf16Safe(remaining, low).length;
        if (cut < 16) throw StateError('compression_reference_too_large');
        final paragraph = remaining.lastIndexOf('\n\n', cut - 1);
        final line = remaining.lastIndexOf('\n', cut - 1);
        if (paragraph >= cut ~/ 2) {
          cut = paragraph + 2;
        } else if (line >= cut ~/ 2) {
          cut = line + 1;
        }
        pieces.add(fragment(remaining.substring(0, cut), nextOffset + cut));
        nextOffset += cut;
        if (nextOffset == text.length) {
          nextIndex++;
          nextOffset = 0;
        }
        break;
      }
      final payload = prompt(pieces.join('\n\n'), previous);
      if (estimateTokens(payload) > inputLimit) {
        throw StateError('compression_reference_too_large');
      }
      task.requestAttempts++;
      TokenUsage? reported;
      try {
        final result = await ModelRequestAttempts.run(
          action: () => request.generate(
            payload,
            task.id,
            output,
            (usage) => reported = (reported ?? const TokenUsage()).merge(usage),
          ),
          onAdditionalAttempt: () async {
            check();
            if (task.requestAttempts >= request.config.maxRequestAttempts) {
              throw StateError('compression_request_budget');
            }
            task.requestAttempts++;
            task.finishReasons.add(null);
            if (!(reported?.hasReportedTokens ?? false)) {
              task.unknownUsageAttempts++;
            }
            await publish();
            check();
          },
        );
        reported = result.totalUsage ?? result.usage ?? reported;
        task.finishReasons.add(result.finishReason);
        check();
        final reason = result.finishReason?.toLowerCase();
        if (const {
          'length',
          'max_tokens',
          'max_output_tokens',
          'max_token',
          'content_filter',
          'refusal',
          'safety',
          'recitation',
          'cancelled',
          'incomplete',
          'blocked',
          'failed',
          'tool_use',
          'tool_calls',
          'function_call',
          'pause_turn',
          'malformed_response',
          'malformed_function_call',
          'unexpected_tool_call',
          'other',
        }.contains(reason)) {
          throw StateError('compression_incomplete:$reason');
        }
        final summary = result.text.trim();
        if (summary.isEmpty) throw StateError('empty_summary');
        previous = summary;
        index = nextIndex;
        offset = nextOffset;
        pending = false;
        task.summary = summary;
        task.completedParts++;
        task.totalParts = math.max(
          task.totalParts,
          task.completedParts + (index < materials.length ? 1 : 0),
        );
      } catch (error) {
        check();
        if (!isContextLengthError(error)) rethrow;
        // Replan only unread material with the same complete working summary.
        inputLimit = (inputLimit * .65).floor();
        if (inputLimit <= estimateTokens(prompt('', previous)) + 32) rethrow;
      } finally {
        if (task.finishReasons.length < task.requestAttempts) {
          task.finishReasons.add(null);
        }
        if (reported?.hasReportedTokens ?? false) {
          task.usage = task.usage == null ? reported : task.usage! + reported!;
        } else {
          task.unknownUsageAttempts++;
        }
        await publish();
      }
    }
    task.totalParts = task.completedParts;
    return previous;
  }
}
