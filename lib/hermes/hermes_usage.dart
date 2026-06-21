/// Token usage and credits information from Hermes backend.
///
/// Parsed from the `session.usage` RPC response payload.
class HermesUsage {
  /// Total input tokens consumed in this session.
  final int inputTokens;

  /// Total output tokens generated in this session.
  final int outputTokens;

  /// Total tokens (input + output).
  final int totalTokens;

  /// Estimated cost in USD (if provided by backend).
  final double? costUsd;

  /// Remaining credits in the user's account (if provided).
  final double? remainingCredits;

  /// Credits consumed in this session.
  final double? creditsUsed;

  /// Number of requests / turns in this session.
  final int turnCount;

  /// Model used for this session (e.g. "gpt-4o", "claude-3.5-sonnet").
  final String? model;

  const HermesUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.totalTokens = 0,
    this.costUsd,
    this.remainingCredits,
    this.creditsUsed,
    this.turnCount = 0,
    this.model,
  });

  factory HermesUsage.fromJson(Map<String, dynamic> json) {
    return HermesUsage(
      inputTokens: (json['input_tokens'] as num?)?.toInt() ?? 0,
      outputTokens: (json['output_tokens'] as num?)?.toInt() ?? 0,
      totalTokens: (json['total_tokens'] as num?)?.toInt() ?? 0,
      costUsd: (json['cost_usd'] as num?)?.toDouble(),
      remainingCredits: (json['remaining_credits'] as num?)?.toDouble(),
      creditsUsed: (json['credits_used'] as num?)?.toDouble(),
      turnCount: (json['turn_count'] as num?)?.toInt() ?? 0,
      model: json['model'] as String?,
    );
  }

  /// Format token count with K/M suffix.
  static String formatTokens(int tokens) {
    if (tokens >= 1_000_000) {
      return '${(tokens / 1_000_000).toStringAsFixed(1)}M';
    }
    if (tokens >= 1_000) {
      return '${(tokens / 1_000).toStringAsFixed(1)}K';
    }
    return tokens.toString();
  }

  /// Format cost string.
  String get formattedCost {
    if (costUsd == null) return '—';
    if (costUsd! < 0.001) return r'<$0.001';
    return '\$${costUsd!.toStringAsFixed(4)}';
  }

  /// Format remaining credits.
  String get formattedCredits {
    if (remainingCredits == null) return '—';
    return remainingCredits!.toStringAsFixed(4);
  }

  /// Format credits used.
  String get formattedCreditsUsed {
    if (creditsUsed == null) return '—';
    return creditsUsed!.toStringAsFixed(4);
  }
}
