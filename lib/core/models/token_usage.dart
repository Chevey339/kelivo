class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int cachedTokens;
  final int thoughtTokens;
  final int totalTokens;

  const TokenUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.cachedTokens = 0,
    this.thoughtTokens = 0,
    this.totalTokens = 0,
  });

  TokenUsage merge(TokenUsage other) {
    // For streaming responses:
    // - prompt tokens: take max (usually stays constant after initial value)
    // - completion tokens: take max (grows as response streams)
    // - cached tokens: take max (usually set once)
    // - thought tokens: take max (grows as response streams)
    final prompt = other.promptTokens > 0 ? other.promptTokens : promptTokens;
    final completion = other.completionTokens > 0 ? other.completionTokens : completionTokens;
    final cached = other.cachedTokens > 0 ? other.cachedTokens : cachedTokens;
    final thought = other.thoughtTokens > 0 ? other.thoughtTokens : thoughtTokens;
    final total = prompt + completion;
    return TokenUsage(
      promptTokens: prompt,
      completionTokens: completion,
      cachedTokens: cached,
      thoughtTokens: thought,
      totalTokens: total,
    );
  }
}

