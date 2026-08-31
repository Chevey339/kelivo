class AutoRetryOptions {
  factory AutoRetryOptions({
    required bool enabled,
    required int maxRetries,
    required int initialDelayMs,
    required double multiplier,
    required int maxDelayMs,
    required bool jitter,
    required bool retryOnNetworkError,
    required Set<int> retryStatusCodes,
    required List<String> retryKeywords,
    required List<String> stopKeywords,
  }) {
    return AutoRetryOptions._(
      enabled: enabled,
      maxRetries: clampMaxRetries(maxRetries),
      initialDelayMs: clampDelayMs(initialDelayMs),
      multiplier: clampMultiplier(multiplier),
      maxDelayMs: clampDelayMs(maxDelayMs),
      jitter: jitter,
      retryOnNetworkError: retryOnNetworkError,
      retryStatusCodes: retryStatusCodes,
      retryKeywords: retryKeywords,
      stopKeywords: stopKeywords,
    );
  }

  const AutoRetryOptions._({
    required this.enabled,
    required this.maxRetries,
    required this.initialDelayMs,
    required this.multiplier,
    required this.maxDelayMs,
    required this.jitter,
    required this.retryOnNetworkError,
    required this.retryStatusCodes,
    required this.retryKeywords,
    required this.stopKeywords,
  });

  const AutoRetryOptions.defaults()
    : enabled = false,
      maxRetries = 3,
      initialDelayMs = 1000,
      multiplier = 2.0,
      maxDelayMs = 30000,
      jitter = true,
      retryOnNetworkError = true,
      retryStatusCodes = defaultRetryStatusCodes,
      retryKeywords = defaultRetryKeywords,
      stopKeywords = defaultStopKeywords;

  static const int minMaxRetries = 0;
  static const int maxMaxRetries = 10;
  static const double defaultMultiplier = 2.0;
  static const double maxMultiplier = 100;

  static const Set<int> defaultRetryStatusCodes = {
    408,
    425,
    429,
    500,
    502,
    503,
    504,
    529,
  };

  static const List<String> defaultRetryKeywords = [
    '并发',
    '稍后',
    '重试',
    '访问量过大',
    '繁忙',
    '限流',
    'rate limit',
    'too many requests',
    'overloaded',
    'try again',
    'timeout',
    '超时',
  ];

  static const List<String> defaultStopKeywords = [
    '余额',
    '不足',
    '额度',
    '欠费',
    'balance',
    'insufficient',
    'quota',
    'invalid api key',
    'unauthorized',
    'permission',
    '未实名',
  ];

  /// When false, the first attempt is never retried.
  final bool enabled;

  /// Extra attempts after the first request. 3 means 4 tries total.
  final int maxRetries;

  final int initialDelayMs;
  final double multiplier;
  final int maxDelayMs;

  /// When true, each delay is randomized by ±20%.
  final bool jitter;

  /// Retry [SocketException], [TimeoutException], and status-less
  /// [ClientException] transport failures.
  final bool retryOnNetworkError;

  final Set<int> retryStatusCodes;
  final List<String> retryKeywords;
  final List<String> stopKeywords;

  static int clampMaxRetries(int value) =>
      value.clamp(minMaxRetries, maxMaxRetries).toInt();

  static int clampDelayMs(int value) => value < 0 ? 0 : value;

  static double clampMultiplier(double value) {
    if (!value.isFinite || value <= 0) return defaultMultiplier;
    if (value > maxMultiplier) return maxMultiplier;
    return value;
  }

  AutoRetryOptions copyWith({
    bool? enabled,
    int? maxRetries,
    int? initialDelayMs,
    double? multiplier,
    int? maxDelayMs,
    bool? jitter,
    bool? retryOnNetworkError,
    Set<int>? retryStatusCodes,
    List<String>? retryKeywords,
    List<String>? stopKeywords,
  }) {
    return AutoRetryOptions(
      enabled: enabled ?? this.enabled,
      maxRetries: maxRetries ?? this.maxRetries,
      initialDelayMs: initialDelayMs ?? this.initialDelayMs,
      multiplier: multiplier ?? this.multiplier,
      maxDelayMs: maxDelayMs ?? this.maxDelayMs,
      jitter: jitter ?? this.jitter,
      retryOnNetworkError: retryOnNetworkError ?? this.retryOnNetworkError,
      retryStatusCodes: retryStatusCodes ?? this.retryStatusCodes,
      retryKeywords: retryKeywords ?? this.retryKeywords,
      stopKeywords: stopKeywords ?? this.stopKeywords,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'maxRetries': maxRetries,
    'initialDelayMs': initialDelayMs,
    'multiplier': multiplier,
    'maxDelayMs': maxDelayMs,
    'jitter': jitter,
    'retryOnNetworkError': retryOnNetworkError,
    'retryStatusCodes': retryStatusCodes.toList()..sort(),
    'retryKeywords': retryKeywords,
    'stopKeywords': stopKeywords,
  };

  static AutoRetryOptions fromJson(Map<String, dynamic> json) {
    const defaults = AutoRetryOptions.defaults();
    return AutoRetryOptions(
      enabled: _readBool(json['enabled'], defaults.enabled),
      maxRetries: _readInt(json['maxRetries'], defaults.maxRetries),
      initialDelayMs: _readInt(json['initialDelayMs'], defaults.initialDelayMs),
      multiplier: _readDouble(json['multiplier'], defaults.multiplier),
      maxDelayMs: _readInt(json['maxDelayMs'], defaults.maxDelayMs),
      jitter: _readBool(json['jitter'], defaults.jitter),
      retryOnNetworkError: _readBool(
        json['retryOnNetworkError'],
        defaults.retryOnNetworkError,
      ),
      retryStatusCodes: json.containsKey('retryStatusCodes')
          ? _parseIntSet(json['retryStatusCodes'])
          : defaults.retryStatusCodes,
      retryKeywords: json.containsKey('retryKeywords')
          ? _parseStringList(json['retryKeywords'])
          : defaults.retryKeywords,
      stopKeywords: json.containsKey('stopKeywords')
          ? _parseStringList(json['stopKeywords'])
          : defaults.stopKeywords,
    );
  }

  static bool _readBool(Object? raw, bool fallback) {
    if (raw is bool) return raw;
    return fallback;
  }

  static int _readInt(Object? raw, int fallback) {
    if (raw is num && raw.isFinite) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
    return fallback;
  }

  static double _readDouble(Object? raw, double fallback) {
    if (raw is num && raw.isFinite) return raw.toDouble();
    if (raw is String) {
      final parsed = double.tryParse(raw.trim());
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return fallback;
  }

  static Set<int> _parseIntSet(Object? raw) {
    if (raw is! List) return const <int>{};
    final out = <int>{};
    for (final item in raw) {
      if (item is num && item.isFinite) {
        out.add(item.toInt());
      } else if (item is String) {
        final parsed = int.tryParse(item.trim());
        if (parsed != null) out.add(parsed);
      }
    }
    return out;
  }

  static List<String> _parseStringList(Object? raw) {
    if (raw is! List) return const <String>[];
    return [
      for (final item in raw)
        if (item != null) item.toString(),
    ];
  }
}
