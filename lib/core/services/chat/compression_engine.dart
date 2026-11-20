import 'dart:isolate';

import '../../models/compress_context_options.dart';
import '../../models/context_compression_task.dart';
import '../../models/token_usage.dart';
import '../api/generation/model_request_attempts.dart';
import 'compression_planner.dart';

/// A chronological fold. Only the final, complete summary can be installed.
/// Every API attempt (including overflow retries) is recorded.
class CompressionEngine {
  const CompressionEngine();

  Future<({String summary, bool referenceUsed})> run({
    required ContextCompressionTask task,
    required CompressionRequest request,
    required List<String> materials,
    required String background,
    required void Function() check,
    required Future<void> Function() publish,
    int? summaryTokens,
  }) async {
    final planner = CompressionPlanner(
      request: request,
      summaryTokens: summaryTokens,
      materials: materials,
      background: background,
    );
    check();
    task.phase = CompressionPhase.summarizing;
    await publish();
    var referenceUsed = false;
    while (planner.index < materials.length) {
      check();
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
        planner.accept(segment, summary);
        referenceUsed = referenceUsed || planner.hasReference;
        task.summary = summary;
        task.completedParts++;
      } catch (error) {
        check();
        if (!isCompressionCapacityError(error) || !planner.backOff(segment)) {
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
    return (summary: planner.previousSummary, referenceUsed: referenceUsed);
  }
}
