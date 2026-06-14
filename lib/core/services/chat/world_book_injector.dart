import '../../models/world_book.dart';

/// Applies world book (lorebook) injections to [apiMessages] in place.
///
/// Pure logic shared by the normal chat pipeline (MessageBuilderService) and
/// the proactive care message flow, which runs without a BuildContext.
/// [books] is the full book list; only books that are enabled and whose id is
/// in [activeBookIds] are considered.
void applyWorldBookInjections(
  List<Map<String, dynamic>> apiMessages, {
  required List<WorldBook> books,
  required List<String> activeBookIds,
}) {
  if (books.isEmpty || activeBookIds.isEmpty) return;

  final activeSet = activeBookIds.toSet();
  final activeBooks = books
      .where((b) => b.enabled && activeSet.contains(b.id))
      .toList(growable: false);
  if (activeBooks.isEmpty) return;

  String extractContextForDepth(int scanDepth) {
    final depth = scanDepth <= 0 ? 1 : scanDepth;
    final parts = <String>[];
    for (int i = apiMessages.length - 1; i >= 0 && parts.length < depth; i--) {
      final role = (apiMessages[i]['role'] ?? '').toString();
      if (role != 'user' && role != 'assistant') continue;
      final content = (apiMessages[i]['content'] ?? '').toString().trim();
      if (content.isEmpty) continue;
      parts.add(content);
    }
    return parts.reversed.join('\n');
  }

  bool isTriggered(WorldBookEntry entry, String context) {
    if (!entry.enabled) return false;
    if (entry.constantActive) return true;
    if (entry.keywords.isEmpty) return false;

    for (final raw in entry.keywords) {
      final keyword = raw.trim();
      if (keyword.isEmpty) continue;

      if (entry.useRegex) {
        try {
          final re = RegExp(keyword, caseSensitive: entry.caseSensitive);
          if (re.hasMatch(context)) return true;
        } catch (_) {}
      } else {
        if (entry.caseSensitive) {
          if (context.contains(keyword)) return true;
        } else {
          if (context.toLowerCase().contains(keyword.toLowerCase())) {
            return true;
          }
        }
      }
    }
    return false;
  }

  final contextCache = <int, String>{};
  final triggered = <({WorldBookEntry entry, int seq})>[];
  int seq = 0;

  for (final book in activeBooks) {
    for (final entry in book.entries) {
      final depth = (entry.scanDepth <= 0 ? 1 : entry.scanDepth)
          .clamp(1, 200)
          .toInt();
      final ctx = contextCache.putIfAbsent(
        depth,
        () => extractContextForDepth(depth),
      );
      if (isTriggered(entry, ctx)) {
        triggered.add((entry: entry, seq: seq));
      }
      seq++;
    }
  }

  if (triggered.isEmpty) return;

  triggered.sort((a, b) {
    final pa = a.entry.priority;
    final pb = b.entry.priority;
    if (pb != pa) return pb.compareTo(pa);
    return a.seq.compareTo(b.seq);
  });

  String wrapSystemTag(String content) => '<system>\n$content\n</system>';

  String joinContents(Iterable<WorldBookEntry> items) {
    return items
        .map((e) => e.content.trim())
        .where((c) => c.isNotEmpty)
        .join('\n');
  }

  List<Map<String, dynamic>> createMergedInjectionMessages(
    List<WorldBookEntry> injections,
  ) {
    final byRole = <WorldBookInjectionRole, List<WorldBookEntry>>{};
    for (final e in injections) {
      if (e.content.trim().isEmpty) continue;
      byRole.putIfAbsent(e.role, () => <WorldBookEntry>[]).add(e);
    }

    final result = <Map<String, dynamic>>[];
    for (final role in byRole.keys) {
      final group = byRole[role]!;
      final merged = joinContents(group);
      if (merged.isEmpty) continue;
      if (role == WorldBookInjectionRole.assistant) {
        result.add({'role': 'assistant', 'content': merged});
      } else {
        result.add({'role': 'user', 'content': wrapSystemTag(merged)});
      }
    }
    return result;
  }

  int findSafeInsertIndex(List<Map<String, dynamic>> messages, int target) {
    var index = target.clamp(0, messages.length);
    while (index > 0 && index < messages.length) {
      final role = (messages[index]['role'] ?? '').toString();
      if (role != 'tool') break;
      index--;
    }
    return index;
  }

  final byPosition = <WorldBookInjectionPosition, List<WorldBookEntry>>{};
  for (final t in triggered) {
    byPosition
        .putIfAbsent(t.entry.position, () => <WorldBookEntry>[])
        .add(t.entry);
  }

  // BEFORE/AFTER_SYSTEM_PROMPT: merge into system message.
  final beforeContent = joinContents(
    byPosition[WorldBookInjectionPosition.beforeSystemPrompt] ??
        const <WorldBookEntry>[],
  );
  final afterContent = joinContents(
    byPosition[WorldBookInjectionPosition.afterSystemPrompt] ??
        const <WorldBookEntry>[],
  );

  if (beforeContent.isNotEmpty || afterContent.isNotEmpty) {
    final systemIndex = apiMessages.indexWhere(
      (m) => (m['role'] ?? '').toString() == 'system',
    );
    if (systemIndex >= 0) {
      final original = (apiMessages[systemIndex]['content'] ?? '').toString();
      final sb = StringBuffer();
      if (beforeContent.isNotEmpty) {
        sb.write(beforeContent);
        sb.write('\n');
      }
      sb.write(original);
      if (afterContent.isNotEmpty) {
        sb.write('\n');
        sb.write(afterContent);
      }
      apiMessages[systemIndex]['content'] = sb.toString();
    } else {
      final sb = StringBuffer();
      if (beforeContent.isNotEmpty) sb.write(beforeContent);
      if (afterContent.isNotEmpty) {
        if (sb.isNotEmpty) sb.write('\n');
        sb.write(afterContent);
      }
      if (sb.isNotEmpty) {
        apiMessages.insert(0, {'role': 'system', 'content': sb.toString()});
      }
    }
  }

  // TOP_OF_CHAT: insert before first user message.
  final topInjections = byPosition[WorldBookInjectionPosition.topOfChat];
  if (topInjections != null && topInjections.isNotEmpty) {
    var insertIndex = apiMessages.indexWhere(
      (m) => (m['role'] ?? '').toString() == 'user',
    );
    if (insertIndex < 0) insertIndex = apiMessages.length;
    insertIndex = findSafeInsertIndex(apiMessages, insertIndex);
    apiMessages.insertAll(
      insertIndex,
      createMergedInjectionMessages(topInjections),
    );
  }

  // BOTTOM_OF_CHAT: insert before last message.
  final bottomInjections = byPosition[WorldBookInjectionPosition.bottomOfChat];
  if (bottomInjections != null && bottomInjections.isNotEmpty) {
    var insertIndex = apiMessages.isEmpty ? 0 : (apiMessages.length - 1);
    insertIndex = findSafeInsertIndex(apiMessages, insertIndex);
    apiMessages.insertAll(
      insertIndex,
      createMergedInjectionMessages(bottomInjections),
    );
  }

  // AT_DEPTH: insert at depth from end (depth=1 means before last message).
  final atDepthInjections = byPosition[WorldBookInjectionPosition.atDepth];
  if (atDepthInjections != null && atDepthInjections.isNotEmpty) {
    final byDepth = <int, List<WorldBookEntry>>{};
    for (final e in atDepthInjections) {
      final depth = (e.injectDepth <= 0 ? 1 : e.injectDepth)
          .clamp(1, 200)
          .toInt();
      byDepth.putIfAbsent(depth, () => <WorldBookEntry>[]).add(e);
    }

    final depths = byDepth.keys.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));

    for (final depth in depths) {
      final injections = byDepth[depth] ?? const <WorldBookEntry>[];
      var insertIndex = (apiMessages.length - depth).clamp(
        0,
        apiMessages.length,
      );
      insertIndex = findSafeInsertIndex(apiMessages, insertIndex);
      apiMessages.insertAll(
        insertIndex,
        createMergedInjectionMessages(injections),
      );
    }
  }
}
