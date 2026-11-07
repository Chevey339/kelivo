import 'dart:convert';

import 'package:crypto/crypto.dart';

enum ContextImageSource { user, tool, assistant }

/// An occurrence, not a file: the same asset can be attached more than once.
class ContextImageIdentity {
  const ContextImageIdentity(this.messageId, this.slot, [this.imageIndex = 0]);

  final String messageId;
  final String slot;
  final int imageIndex;

  String get key => '$messageId|$slot|$imageIndex';
  String get handle =>
      'img_${sha256.convert(utf8.encode(key)).toString().substring(0, 20)}';

  static String? remapKey(String key, Map<String, String> messages) {
    final separator = key.indexOf('|');
    if (separator < 1) return null;
    final replacement = messages[key.substring(0, separator)];
    return replacement == null
        ? null
        : '$replacement${key.substring(separator)}';
  }
}

class ImageContextSettings {
  const ImageContextSettings({
    this.automatic = true,
    this.allowRecall = true,
    this.pinned = const {},
  });

  static const entityKind = 'conversationImageContext';
  final bool automatic;
  final bool allowRecall;
  final Set<String> pinned;

  factory ImageContextSettings.fromJson(Map<String, dynamic> json) =>
      ImageContextSettings(
        automatic: json['automatic'] != false,
        allowRecall: json['allowRecall'] != false,
        pinned: Set.unmodifiable(
          (json['pinned'] as List? ?? const []).whereType<String>(),
        ),
      );

  Map<String, dynamic> toJson() => {
    'automatic': automatic,
    'allowRecall': allowRecall,
    'pinned': pinned.toList()..sort(),
  };

  ImageContextSettings remap(Map<String, String> messages) =>
      ImageContextSettings(
        automatic: automatic,
        allowRecall: allowRecall,
        pinned: {
          for (final key in pinned)
            if (ContextImageIdentity.remapKey(key, messages)
                case final String mapped)
              mapped,
        },
      );

  ImageContextSettings pin(String key, bool value) => ImageContextSettings(
    automatic: automatic,
    allowRecall: allowRecall,
    pinned: {...pinned}
      ..removeWhere((item) => item == key)
      ..addAll(value ? [key] : const []),
  );
}

class ImageContextCandidate {
  const ImageContextCandidate({
    required this.key,
    required this.source,
    required this.encodedBytes,
    this.protected = false,
    this.count = 1,
    this.userMessageId,
    this.userTurnId,
  });

  final String key;
  final ContextImageSource source;
  final int encodedBytes;
  final bool protected;
  final int count;
  final String? userMessageId;
  final String? userTurnId;
}

enum ImageContextBudgetKind {
  singleImage,
  totalImages,
  imageCount,
  requestBody,
}

class ImageContextBudgetException implements Exception {
  const ImageContextBudgetException({
    required this.kind,
    required this.actual,
    required this.limit,
    this.imageIndex,
    this.imageKey,
    this.pinned = false,
    this.minimum = false,
  });

  final ImageContextBudgetKind kind;
  final int actual;
  final int limit;
  final int? imageIndex;
  final String? imageKey;
  final bool pinned;
  // A guard may stop loading as soon as the measured prefix exceeds a limit.
  final bool minimum;

  @override
  String toString() =>
      'Kelivo local preflight: ${kind.name}'
      '${imageIndex == null ? '' : ' (image $imageIndex${pinned ? ', pinned' : ''})'}'
      ' exceeds the configured limit: ${minimum ? 'at least ' : ''}$actual > $limit '
      '${kind == ImageContextBudgetKind.imageCount ? 'images' : 'bytes'}. '
      '${kind == ImageContextBudgetKind.requestBody ? 'Shorten the context or adjust the request body budget.' : 'Review Image context, reduce images or unpin old images, or adjust the image budget.'}';
}

/// Deterministic replay. Always give [historyOmissions] the original branch's
/// ordered image occurrences, before applying a message-count window.
abstract final class ImageContextPlanner {
  static int base64Bytes(int rawBytes) => ((rawBytes + 2) ~/ 3) * 4;

  /// Replay every append, rather than choosing a fresh suffix at the end.
  /// Count pruning can free bytes, but cannot bring back a prior byte eviction.
  static Set<String> historyOmissions(
    List<ImageContextCandidate> history, {
    required int maxBytes,
    required int maxSingleBytes,
    int maxImages = 24,
    String? latestUserId,
  }) {
    final retained = <ImageContextCandidate>[];
    final omitted = <String>{};
    final tools = <ImageContextCandidate>[];
    String? currentUser;
    bool protected(ImageContextCandidate item) =>
        item.protected ||
        (item.userMessageId != null && item.userMessageId == currentUser);
    void trim({ImageContextCandidate? newest}) {
      for (final old in List<ImageContextCandidate>.of(retained)) {
        if (old.encodedBytes > maxSingleBytes && !protected(old)) {
          omitted.add(old.key);
          retained.remove(old);
        }
      }
      var bytes = retained.fold<int>(0, (sum, item) => sum + item.encodedBytes);
      for (final user in [false, true]) {
        for (final old in List<ImageContextCandidate>.of(retained)) {
          if (bytes <= maxBytes && retained.length <= maxImages) break;
          if (protected(old) ||
              identical(old, newest) ||
              (old.source == ContextImageSource.user) != user) {
            continue;
          }
          omitted.add(old.key);
          retained.remove(old);
          bytes -= old.encodedBytes;
        }
      }
      if (newest != null &&
          (bytes > maxBytes || retained.length > maxImages) &&
          !protected(newest) &&
          newest.source == ContextImageSource.user) {
        omitted.add(newest.key);
        retained.remove(newest);
      }
    }

    for (final image in history) {
      if (currentUser != image.userTurnId) {
        currentUser = image.userTurnId;
        // Release the previous user's protection without rebuilding retained
        // images. Later batch eviction must not resurrect a prior omission.
        trim();
      }
      retained.add(image);
      if (image.source != ContextImageSource.user) tools.add(image);
      if (tools.length > 12) {
        for (final old in List<ImageContextCandidate>.of(tools)) {
          if (tools.length <= 4) break;
          if (protected(old)) continue;
          omitted.add(old.key);
          tools.remove(old);
          retained.remove(old);
        }
      }
      trim(newest: image);
    }
    if (latestUserId != currentUser) {
      currentUser = latestUserId;
      trim();
    }
    return omitted;
  }

  static void validateBudget(
    List<ImageContextCandidate> images, {
    required int maxBytes,
    int maxImages = 24,
    bool minimum = false,
  }) {
    final bytes = images.fold<int>(0, (sum, image) => sum + image.encodedBytes);
    if (bytes > maxBytes) {
      throw ImageContextBudgetException(
        kind: ImageContextBudgetKind.totalImages,
        actual: bytes,
        limit: maxBytes,
        minimum: minimum,
      );
    }
    final count = images.fold<int>(0, (sum, image) => sum + image.count);
    if (count > maxImages) {
      throw ImageContextBudgetException(
        kind: ImageContextBudgetKind.imageCount,
        actual: count,
        limit: maxImages,
        minimum: minimum,
      );
    }
  }
}
