import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';

/// Recreates the P1 integer-budget mapping so request-body expectations stay
/// identical after the thinking-budget path was deleted.
ReasoningRequest legacyBudget(int? budget) {
  if (budget == null || budget == -1) return ReasoningRequest.auto;
  if (budget < 1024) return ReasoningRequest.off;
  final level = budget <= 2000
      ? ReasoningLevel.low
      : budget <= 20000
      ? ReasoningLevel.medium
      : budget <= 32000
      ? ReasoningLevel.high
      : budget <= 64000
      ? ReasoningLevel.xhigh
      : ReasoningLevel.max;
  return ReasoningRequest(level, budgetTokens: budget > 0 ? budget : null);
}
