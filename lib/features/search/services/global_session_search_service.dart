import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/services/chat/chat_service.dart';

class GlobalSessionSearchResult {
  const GlobalSessionSearchResult({
    required this.conversationId,
    required this.conversationTitle,
    required this.updatedAt,
    required this.firstMatchedMessageId,
    required this.snippet,
    required this.score,
    required this.titleMatched,
  });

  final String conversationId;
  final String conversationTitle;
  final DateTime updatedAt;
  final String firstMatchedMessageId;
  final String snippet;
  final int score;
  final bool titleMatched;
}

class GlobalSessionSearchService {
  const GlobalSessionSearchService._();

  // Hidden/internal blocks that should not participate in global search.
  static final RegExp _geminiThoughtSigRe =
      RegExp(r'<!--\s*gemini_thought_signatures:.*?-->', dotAll: true);
  static final RegExp _thinkBlockRe =
      RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false);
  static final RegExp _reasoningBlockRe =
      RegExp(r'<reasoning>[\s\S]*?<\/reasoning>', caseSensitive: false);

  static List<GlobalSessionSearchResult> search({
    required ChatService chatService,
    required String query,
    int limit = 200,
  }) {
    final normalized = query.trim();
    if (normalized.isEmpty) return const <GlobalSessionSearchResult>[];

    final tokens = _tokensOf(normalized);
    if (tokens.isEmpty) return const <GlobalSessionSearchResult>[];

    final out = <GlobalSessionSearchResult>[];
    final conversations = chatService.getAllConversations();

    for (final c in conversations) {
      final match = _matchConversation(
        chatService: chatService,
        conversation: c,
        tokens: tokens,
      );
      if (match != null) out.add(match);
    }

    out.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    if (out.length <= limit) return out;
    return out.sublist(0, limit);
  }

  static GlobalSessionSearchResult? _matchConversation({
    required ChatService chatService,
    required Conversation conversation,
    required List<String> tokens,
  }) {
    final title = conversation.title.trim();
    final lowerTitle = title.toLowerCase();

    final collapsed = _collapseMessages(
      chatService.getMessages(conversation.id),
      conversation.versionSelections,
    );
    if (collapsed.isEmpty && title.isEmpty) return null;

    final contentItems = <_ContentRef>[];
    for (final m in collapsed) {
      // Only search visible conversation body: user + assistant messages.
      // Exclude tool/system-like messages and hidden reasoning/thought blocks.
      if (m.role != 'user' && m.role != 'assistant') continue;
      final body = _searchableBody(m.content);
      if (body.isEmpty) continue;
      contentItems.add(_ContentRef(messageId: m.id, text: body));
    }

    final contentLower = contentItems
        .map((e) => e.text.toLowerCase())
        .join('\n');
    final searchHaystack = '$lowerTitle\n$contentLower';
    for (final t in tokens) {
      if (!searchHaystack.contains(t)) return null;
    }

    final titleMatches = _countMatches(lowerTitle, tokens);
    final firstMatchedIndex = _firstMatchedContentIndex(contentItems, tokens);
    final contentMatches = _countMatches(contentLower, tokens);
    final hasTitleMatch = titleMatches > 0;

    final fallbackMessageId = collapsed.isNotEmpty ? collapsed.first.id : '';
    final matchedMessageId =
        (firstMatchedIndex >= 0 && firstMatchedIndex < contentItems.length)
        ? contentItems[firstMatchedIndex].messageId
        : '';
    final targetMessageId = matchedMessageId.isNotEmpty
        ? matchedMessageId
        : fallbackMessageId;
    // Title-only conversations: targetMessageId is empty but title matched — include with empty messageId

    final displayTitle = title.isEmpty ? '(Untitled)' : title;
    var snippet = firstMatchedIndex >= 0
        ? _contextSnippet(
            items: contentItems,
            centerIndex: firstMatchedIndex,
            tokens: tokens,
          )
        : _snippetFor(title, tokens);

    final titleHasVisibleHit = _containsAnyToken(displayTitle.toLowerCase(), tokens);
    var snippetHasVisibleHit = _containsAnyToken(snippet.toLowerCase(), tokens);

    // Guarantee each visible result has at least one highlightable token in
    // either title or snippet. If the current snippet misses all tokens,
    // fallback to a focused snippet from the first matched message.
    if (!titleHasVisibleHit && !snippetHasVisibleHit) {
      if (firstMatchedIndex >= 0 && firstMatchedIndex < contentItems.length) {
        snippet = _snippetFor(contentItems[firstMatchedIndex].text, tokens);
        snippetHasVisibleHit = _containsAnyToken(snippet.toLowerCase(), tokens);
      }
    }

    if (!titleHasVisibleHit && !snippetHasVisibleHit) {
      return null;
    }

    final score = (titleMatches * 30) + (contentMatches * 10);

    return GlobalSessionSearchResult(
      conversationId: conversation.id,
      conversationTitle: displayTitle,
      updatedAt: conversation.updatedAt,
      firstMatchedMessageId: targetMessageId,
      snippet: snippet,
      score: score,
      titleMatched: hasTitleMatch,
    );
  }

  static List<ChatMessage> _collapseMessages(
    List<ChatMessage> messages,
    Map<String, int> versionSelections,
  ) {
    final byGroup = <String, List<ChatMessage>>{};
    final order = <String>[];
    for (final m in messages) {
      final gid = m.groupId ?? m.id;
      final list = byGroup.putIfAbsent(gid, () {
        order.add(gid);
        return <ChatMessage>[];
      });
      list.add(m);
    }
    for (final list in byGroup.values) {
      list.sort((a, b) => a.version.compareTo(b.version));
    }

    final out = <ChatMessage>[];
    for (final gid in order) {
      final versions = byGroup[gid] ?? const <ChatMessage>[];
      if (versions.isEmpty) continue;
      final sel = versionSelections[gid];
      final idx = (sel != null && sel >= 0 && sel < versions.length)
          ? sel
          : (versions.length - 1);
      out.add(versions[idx]);
    }
    return out;
  }

  static List<String> _tokensOf(String query) {
    return query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static int _countMatches(String text, List<String> tokens) {
    if (text.isEmpty) return 0;
    var score = 0;
    for (final t in tokens) {
      var start = 0;
      while (true) {
        final idx = text.indexOf(t, start);
        if (idx < 0) break;
        score++;
        start = idx + t.length;
      }
    }
    return score;
  }

  static int _firstMatchedContentIndex(
    List<_ContentRef> items,
    List<String> tokens,
  ) {
    for (var i = 0; i < items.length; i++) {
      final lower = items[i].text.toLowerCase();
      for (final t in tokens) {
        if (lower.contains(t)) return i;
      }
    }
    return -1;
  }

  static String _contextSnippet({
    required List<_ContentRef> items,
    required int centerIndex,
    required List<String> tokens,
    int minChars = 110,
    int maxChars = 180,
  }) {
    if (items.isEmpty) return '';

    final center = centerIndex.clamp(0, items.length - 1);
    var left = center;
    var right = center;

    String joinWindow() {
      return [
        for (var i = left; i <= right; i++) _normalize(items[i].text),
      ].where((e) => e.isNotEmpty).join('  ');
    }

    var windowText = joinWindow();
    var step = 1;
    while (windowText.length < minChars &&
        (center - step >= 0 || center + step <= items.length - 1)) {
      if (center - step >= 0) left = center - step;
      if (center + step <= items.length - 1) right = center + step;
      step++;
      windowText = joinWindow();
    }

    if (windowText.isEmpty) return '';

    final lower = windowText.toLowerCase();
    var hit = -1;
    for (final t in tokens) {
      final idx = lower.indexOf(t);
      if (idx >= 0 && (hit < 0 || idx < hit)) hit = idx;
    }

    var start = 0;
    var end = windowText.length;
    if (windowText.length > maxChars) {
      if (hit >= 0) {
        // Keep hit around the middle of the preview so it is likely visible
        // within the 3-line snippet and visually lands near line 2.
        final anchor = (maxChars * 0.45).round();
        start = (hit - anchor).clamp(0, windowText.length - maxChars);
      }
      end = (start + maxChars).clamp(0, windowText.length);
    }

    final hasBefore = left > 0 || start > 0;
    final hasAfter = right < items.length - 1 || end < windowText.length;
    var frag = windowText.substring(start, end).trim();
    if (hasBefore) frag = '... $frag';
    if (hasAfter) frag = '$frag ...';
    return frag;
  }

  static String _normalize(String input) {
    return input
        .replaceAll(RegExp(r'[\t\n\r]+'), ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
  }

  static String _searchableBody(String content) {
    if (content.trim().isEmpty) return '';
    return _normalize(content
        .replaceAll(_geminiThoughtSigRe, ' ')
        .replaceAll(_thinkBlockRe, ' ')
        .replaceAll(_reasoningBlockRe, ' '));
  }

  static String _snippetFor(String source, List<String> tokens) {
    final s = source.trim();
    if (s.isEmpty) return '';
    final lower = s.toLowerCase();
    var hit = -1;
    for (final t in tokens) {
      final idx = lower.indexOf(t);
      if (idx >= 0 && (hit < 0 || idx < hit)) hit = idx;
    }
    if (hit < 0) {
      return s.length <= 140 ? s : '${s.substring(0, 140)}...';
    }
    const maxChars = 180;
    final start = (hit - (maxChars * 0.45).round()).clamp(0, (s.length - maxChars).clamp(0, s.length));
    final end = (start + maxChars).clamp(0, s.length);
    final frag = s.substring(start, end).trim();
    final prefix = start > 0 ? '... ' : '';
    final suffix = end < s.length ? ' ...' : '';
    return '$prefix$frag$suffix';
  }

  static bool _containsAnyToken(String text, List<String> tokens) {
    if (text.isEmpty || tokens.isEmpty) return false;
    for (final t in tokens) {
      if (text.contains(t)) return true;
    }
    return false;
  }
}

class _ContentRef {
  const _ContentRef({required this.messageId, required this.text});

  final String messageId;
  final String text;
}
