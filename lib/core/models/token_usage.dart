class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int cachedTokens;
  final int totalTokens;

  const TokenUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.cachedTokens = 0,
    this.totalTokens = 0,
  });

  factory TokenUsage.fromGeminiUsageMetadata(Map<String, dynamic>? um) {
    if (um == null) return const TokenUsage();
    return TokenUsage(
      promptTokens: (um['promptTokenCount'] as int? ?? 0),
      completionTokens: (um['candidatesTokenCount'] as int? ?? 0),
      cachedTokens: (um['cachedContentTokenCount'] as int? ?? 0),
      totalTokens: (um['totalTokenCount'] as int? ?? 0),
    );
  }

  TokenUsage merge(TokenUsage other) {
    // For streaming responses:
    // - prompt tokens: take max (usually stays constant after initial value)
    // - completion tokens: take max (grows as response streams)
    // - cached tokens: take max (usually set once)
    final prompt = other.promptTokens > 0 ? other.promptTokens : promptTokens;
    final completion = other.completionTokens > 0
        ? other.completionTokens
        : completionTokens;
    final cached = other.cachedTokens > 0 ? other.cachedTokens : cachedTokens;
    final splitTotal = prompt + completion;
    final explicitTotal = other.totalTokens > 0
        ? other.totalTokens
        : totalTokens;
    final total = splitTotal > 0 ? splitTotal : explicitTotal;
    return TokenUsage(
      promptTokens: prompt,
      completionTokens: completion,
      cachedTokens: cached,
      totalTokens: total,
    );
  }
}
