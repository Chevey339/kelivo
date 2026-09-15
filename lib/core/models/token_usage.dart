class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int cachedTokens;
  final int reasoningTokens;
  final int cacheWriteTokens;
  final int totalTokens;

  const TokenUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.cachedTokens = 0,
    this.reasoningTokens = 0,
    this.cacheWriteTokens = 0,
    this.totalTokens = 0,
  });

  TokenUsage copyWith({
    int? promptTokens,
    int? completionTokens,
    int? cachedTokens,
    int? reasoningTokens,
    int? cacheWriteTokens,
    int? totalTokens,
  }) {
    return TokenUsage(
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      cachedTokens: cachedTokens ?? this.cachedTokens,
      reasoningTokens: reasoningTokens ?? this.reasoningTokens,
      cacheWriteTokens: cacheWriteTokens ?? this.cacheWriteTokens,
      totalTokens: totalTokens ?? this.totalTokens,
    );
  }

  /// Folds a usage snapshot into the running one: the newest non-zero field
  /// wins, so a later round's numbers replace the previous round's rather than
  /// adding to them (providers already report the full context each round).
  TokenUsage merge(TokenUsage other) {
    final prompt = other.promptTokens > 0 ? other.promptTokens : promptTokens;
    final completion = other.completionTokens > 0
        ? other.completionTokens
        : completionTokens;
    final cached = other.cachedTokens > 0 ? other.cachedTokens : cachedTokens;
    final reasoning = other.reasoningTokens > 0
        ? other.reasoningTokens
        : reasoningTokens;
    final cacheWrite = other.cacheWriteTokens > 0
        ? other.cacheWriteTokens
        : cacheWriteTokens;
    final splitTotal = prompt + completion;
    final explicitTotal = other.totalTokens > 0
        ? other.totalTokens
        : totalTokens;
    final total = splitTotal > 0 ? splitTotal : explicitTotal;
    return TokenUsage(
      promptTokens: prompt,
      completionTokens: completion,
      cachedTokens: cached,
      reasoningTokens: reasoning,
      cacheWriteTokens: cacheWrite,
      totalTokens: total,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'promptTokens': promptTokens,
      'completionTokens': completionTokens,
      'cachedTokens': cachedTokens,
      'reasoningTokens': reasoningTokens,
      'cacheWriteTokens': cacheWriteTokens,
      'totalTokens': totalTokens,
    };
  }

  factory TokenUsage.fromJson(Map<String, dynamic> json) {
    int read(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return TokenUsage(
      promptTokens: read('promptTokens'),
      completionTokens: read('completionTokens'),
      cachedTokens: read('cachedTokens'),
      reasoningTokens: read('reasoningTokens'),
      cacheWriteTokens: read('cacheWriteTokens'),
      totalTokens: read('totalTokens'),
    );
  }
}
