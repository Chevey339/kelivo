import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/world_book.dart';

/// Timed effects use actual chat messages, excluding synthetic injections and
/// tool calls. A repeated preparation of the same history is idempotent.
class WorldBookActivation {
  static const extrasKey = 'worldBook.activation';

  static ({List<WorldBookEntry> entries, Map<String, dynamic> state}) evaluate({
    required List<WorldBook> books,
    required List<Map<String, dynamic>> scanMessages,
    required List<Map<String, dynamic>> history,
    Map<String, dynamic> previous = const {},
  }) {
    String fingerprint(Object value) =>
        sha256.convert(utf8.encode(jsonEncode(value))).toString();
    final count = history.length;
    final previousCount = previous['messageCount'] as int? ?? 0;
    // Content hashes allow branches with cloned message IDs to inherit effects.
    // Rewinding or changing the evaluated prefix invalidates those effects.
    final continuesHistory =
        previous['historyHash'] != null &&
        previousCount >= 0 &&
        previousCount <= count &&
        previous['historyHash'] ==
            fingerprint(history.take(previousCount).toList());
    final oldEffects = continuesHistory
        ? (previous['effects'] as Map? ?? const {})
        : const {};
    final effects = <String, dynamic>{};
    final triggered = <({WorldBookEntry entry, int seq})>[];
    final contextCache = <int, String>{};
    var seq = 0;

    String contextFor(int depth) => contextCache.putIfAbsent(depth, () {
      final parts = scanMessages.reversed
          .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
          .map((m) => (m['content'] ?? '').toString().trim())
          .where((text) => text.isNotEmpty)
          .take(depth)
          .toList()
          .reversed;
      return parts.join('\n');
    });

    for (final book in books) {
      if (!book.enabled) continue;
      for (final entry in book.entries) {
        final order = seq++;
        if (!entry.enabled || entry.content.trim().isEmpty) continue;
        final key = jsonEncode([book.id, entry.id]);
        final signature = entry.sticky > 0 || entry.cooldown > 0
            ? fingerprint(entry.toJson())
            : '';
        final raw = oldEffects[key];
        final effect = raw is Map && raw['signature'] == signature ? raw : null;
        final activatedAt = effect?['activatedAt'] as int?;
        var active = false;
        if (activatedAt != null && activatedAt <= count) {
          final elapsed = count - activatedAt;
          if (elapsed <= entry.sticky) {
            active = true;
            effects[key] = effect;
          } else if (elapsed <= entry.sticky + entry.cooldown) {
            effects[key] = effect;
            continue;
          }
        }
        if (!active) {
          if (count < entry.delay) continue;
          active = matches(entry, contextFor(entry.scanDepth.clamp(1, 200)));
          if (active && (entry.sticky > 0 || entry.cooldown > 0)) {
            effects[key] = {'signature': signature, 'activatedAt': count};
          }
        }
        if (active) triggered.add((entry: entry, seq: order));
      }
    }
    triggered.sort((a, b) {
      final priority = b.entry.priority.compareTo(a.entry.priority);
      return priority != 0 ? priority : a.seq.compareTo(b.seq);
    });
    return (
      entries: triggered.map((item) => item.entry).toList(),
      state: {
        'messageCount': count,
        'historyHash': effects.isEmpty ? '' : fingerprint(history),
        'effects': effects,
      },
    );
  }

  static bool matches(WorldBookEntry entry, String context) {
    if (!entry.enabled) return false;
    if (entry.constantActive) return true;
    for (final raw in entry.keywords) {
      final keyword = raw.trim();
      if (keyword.isEmpty) continue;
      if (entry.useRegex) {
        try {
          if (RegExp(
            keyword,
            caseSensitive: entry.caseSensitive,
          ).hasMatch(context)) {
            return true;
          }
        } on FormatException {
          // One invalid expression must not suppress the other keywords.
        }
      } else if (entry.caseSensitive
          ? context.contains(keyword)
          : context.toLowerCase().contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}
