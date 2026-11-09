import '../api/generation/model_request_attempts.dart';
import 'dart:isolate';
import 'dart:math' as math;

import '../../models/compress_context_options.dart';
import '../../models/context_compression_task.dart';
import '../../models/token_usage.dart';
import '../../utils/token_estimator.dart';
import 'compression_planner.dart';

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
    final planner = CompressionPlanner(
      request: request,
      materials: materials,
      previousSummary: previousSummary,
      background: background,
      continuation: continuation,
    );
    task.totalParts = await Isolate.run(planner.estimateRequests);
    check();
    if (task.totalParts > request.config.maxRequestAttempts) {
      throw StateError('compression_request_budget');
    }
    task.phase = CompressionPhase.summarizing;
    await publish();
    // A previous-summary-only rebuild is still one explicit call.
    var pending = materials.isEmpty;
    while (planner.index < materials.length || pending) {
      check();
      if (task.requestAttempts >= request.config.maxRequestAttempts) {
        throw StateError('compression_request_budget');
      }
      final segment = await Isolate.run(planner.next);
      check();
      task.requestAttempts++;
      TokenUsage? reported;
      try {
        final result = await ModelRequestAttempts.run(
          action: () => request.generate!(
            segment.prompt,
            task.id,
            planner.outputTokens,
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
        planner.previousSummary = summary;
        planner.index = segment.nextIndex;
        planner.offset = segment.nextOffset;
        pending = false;
        task.summary = summary;
        task.completedParts++;
        task.totalParts = math.max(
          task.totalParts,
          task.completedParts + (planner.index < materials.length ? 1 : 0),
        );
      } catch (error) {
        check();
        if (!isContextLengthError(error)) rethrow;
        // Replan only unread material with the same complete working summary.
        planner.inputLimit = (planner.inputLimit * .65).floor();
        if (planner.inputLimit <= estimateTokens(planner.render('')) + 32) {
          rethrow;
        }
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
    return planner.previousSummary;
  }
}
