/// Local request limits, measured in encoded image bytes and UTF-8 JSON bytes.
/// These are client resource budgets, not advertised provider capabilities.
class RequestBudget {
  const RequestBudget({
    this.singleImageBytes = 5 * mib,
    this.totalImageBytes = 20 * mib,
    this.imageCount = 24,
    this.bodyBytes = 28 * mib,
  }) : assert(singleImageBytes > 0),
       assert(totalImageBytes > 0),
       assert(imageCount > 0),
       assert(bodyBytes > 0);

  static const mib = 1024 * 1024;
  static const google = RequestBudget(
    totalImageBytes: 14 * mib,
    bodyBytes: 20000000,
  );

  final int singleImageBytes;
  final int totalImageBytes;
  final int imageCount;
  final int bodyBytes;

  Map<String, int> toJson() => {
    'singleImageBytes': singleImageBytes,
    'totalImageBytes': totalImageBytes,
    'imageCount': imageCount,
    'bodyBytes': bodyBytes,
  };
}

/// Empty fields inherit the provider default or the provider's override.
class RequestBudgetOverrides {
  const RequestBudgetOverrides({
    this.singleImageBytes,
    this.totalImageBytes,
    this.imageCount,
    this.bodyBytes,
  });

  final int? singleImageBytes;
  final int? totalImageBytes;
  final int? imageCount;
  final int? bodyBytes;

  bool get isEmpty =>
      singleImageBytes == null &&
      totalImageBytes == null &&
      imageCount == null &&
      bodyBytes == null;

  factory RequestBudgetOverrides.fromJson(dynamic json) {
    int? positive(String key) {
      final value = json is Map ? json[key] : null;
      return value is int && value > 0 ? value : null;
    }

    return RequestBudgetOverrides(
      singleImageBytes: positive('singleImageBytes'),
      totalImageBytes: positive('totalImageBytes'),
      imageCount: positive('imageCount'),
      bodyBytes: positive('bodyBytes'),
    );
  }

  Map<String, dynamic> toJson() => {
    if (singleImageBytes != null) 'singleImageBytes': singleImageBytes,
    if (totalImageBytes != null) 'totalImageBytes': totalImageBytes,
    if (imageCount != null) 'imageCount': imageCount,
    if (bodyBytes != null) 'bodyBytes': bodyBytes,
  };

  RequestBudget applyTo(RequestBudget base) => RequestBudget(
    singleImageBytes: singleImageBytes ?? base.singleImageBytes,
    totalImageBytes: totalImageBytes ?? base.totalImageBytes,
    imageCount: imageCount ?? base.imageCount,
    bodyBytes: bodyBytes ?? base.bodyBytes,
  );
}
