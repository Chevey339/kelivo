class TokenUsage {
  /// Total input, including cache reads and cache writes.
  int get promptTokens => _promptTokens ?? 0;

  /// Total output, including reasoning tokens.
  int get completionTokens => _completionTokens ?? 0;
  int get cachedTokens => _cachedTokens ?? 0;
  int get reasoningTokens => _reasoningTokens ?? 0;
  int get cacheWriteTokens => _cacheWriteTokens ?? 0;
  int get totalTokens => _totalTokens ?? promptTokens + completionTokens;

  // Null means absent from a partial update; zero is a reported value.
  final int? _promptTokens;
  final int? _completionTokens;
  final int? _cachedTokens;
  final int? _reasoningTokens;
  final int? _cacheWriteTokens;
  final int? _totalTokens;

  bool get hasReportedTokens =>
      _promptTokens != null ||
      _completionTokens != null ||
      _cachedTokens != null ||
      _reasoningTokens != null ||
      _cacheWriteTokens != null ||
      _totalTokens != null;

  const TokenUsage({
    this._promptTokens,
    this._completionTokens,
    this._cachedTokens,
    this._reasoningTokens,
    this._cacheWriteTokens,
    this._totalTokens,
  });

  TokenUsage copyWith({
    int? promptTokens,
    int? completionTokens,
    int? cachedTokens,
    int? reasoningTokens,
    int? cacheWriteTokens,
    int? totalTokens,
  }) {
    return merge(
      TokenUsage(
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        cachedTokens: cachedTokens,
        reasoningTokens: reasoningTokens,
        cacheWriteTokens: cacheWriteTokens,
        totalTokens: totalTokens,
      ),
    );
  }

  /// Merges a partial update within one request, including explicitly reported
  /// zeros. A new tool round replaces the old round with [asSnapshot] instead.
  TokenUsage merge(TokenUsage other) {
    final prompt = other._promptTokens ?? _promptTokens;
    final completion = other._completionTokens ?? _completionTokens;
    final splitUpdated =
        other._promptTokens != null || other._completionTokens != null;
    return TokenUsage(
      promptTokens: prompt,
      completionTokens: completion,
      cachedTokens: other._cachedTokens ?? _cachedTokens,
      reasoningTokens: other._reasoningTokens ?? _reasoningTokens,
      cacheWriteTokens: other._cacheWriteTokens ?? _cacheWriteTokens,
      totalTokens: other._totalTokens ?? (splitUpdated ? null : _totalTokens),
    );
  }

  /// Completes this round's snapshot so omitted counters cannot leak in from
  /// an earlier tool round when consumers receive the next Usage chunk.
  TokenUsage asSnapshot() => TokenUsage(
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    cachedTokens: cachedTokens,
    reasoningTokens: reasoningTokens,
    cacheWriteTokens: cacheWriteTokens,
    totalTokens: totalTokens,
  );

  /// Adds separate API requests. Within one request, use [merge] instead.
  TokenUsage operator +(TokenUsage other) => TokenUsage(
    promptTokens: promptTokens + other.promptTokens,
    completionTokens: completionTokens + other.completionTokens,
    cachedTokens: cachedTokens + other.cachedTokens,
    reasoningTokens: reasoningTokens + other.reasoningTokens,
    cacheWriteTokens: cacheWriteTokens + other.cacheWriteTokens,
    totalTokens: totalTokens + other.totalTokens,
  );

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (_promptTokens != null) 'promptTokens': _promptTokens,
      if (_completionTokens != null) 'completionTokens': _completionTokens,
      if (_cachedTokens != null) 'cachedTokens': _cachedTokens,
      if (_reasoningTokens != null) 'reasoningTokens': _reasoningTokens,
      if (_cacheWriteTokens != null) 'cacheWriteTokens': _cacheWriteTokens,
      if (_totalTokens != null) 'totalTokens': _totalTokens,
    };
  }

  factory TokenUsage.fromJson(Map<String, dynamic> json) {
    int? read(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
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
