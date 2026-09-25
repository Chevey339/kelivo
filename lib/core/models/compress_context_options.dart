import '../utils/token_estimator.dart';
import 'chat_message.dart';
import '../../utils/utf16_safe_cut.dart';

enum CompressContextLimitMode { start, recent, unlimited, keepRecent }

class CompressContextOptions {
  const CompressContextOptions({
    required this.mode,
    this.maxChars,
    this.keepUserMessages,
  });

  static const int defaultMaxChars = 6000;
  static const int defaultKeepUserMessages = 3;

  /// Hard cap on a single compress request, in UTF-16 code units.
  ///
  /// Even a 1M-context model stays at or below this to avoid AOT / regex /
  /// JSON-encode blow-ups. The effective budget is
  /// `min(safeRequestChars, compressRequestCharBudget(...))`.
  static const int safeRequestChars = 100000;

  /// Assumed context window when model metadata is missing.
  /// 32k is a conservative floor for current small chat models.
  static const int defaultContextWindowTokens = 32000;

  /// Fraction of the context window reserved for the compress prompt
  /// wrapper and the model's completion.
  static const double contextReserveFraction = 0.30;

  /// Conservative chars/token (CJK-heavy). Matches
  /// [estimateCompressionTokens] (`cjk / 1.6`).
  static const double charsPerToken = 1.6;

  /// Max binary splits when a compress `generateText` hits a context-length
  /// error. Shared across the whole retry tree (halves + merge).
  static const int contextRetryMaxSplits = 5;

  /// Do not split a request whose resulting half would be shorter than this
  /// (UTF-16 code units). Prevents infinite retry on a still-too-dense input.
  static const int contextRetryMinSplitChars = 512;

  final CompressContextLimitMode mode;
  final int? maxChars;
  final int? keepUserMessages;
}

/// Resolve the model that [HomeViewModel.compressContext] will call.
///
/// Chain: compress → summary → title → assistant chat → global default.
/// Provider and model id are resolved independently (same as the existing
/// `??` chain) so a half-set pair can still mix with a later fallback.
({String? providerKey, String? modelId}) resolveCompressContextModel({
  String? compressProvider,
  String? compressModelId,
  String? summaryProvider,
  String? summaryModelId,
  String? titleProvider,
  String? titleModelId,
  String? assistantProvider,
  String? assistantModelId,
  String? currentProvider,
  String? currentModelId,
}) {
  return (
    providerKey:
        compressProvider ??
        summaryProvider ??
        titleProvider ??
        assistantProvider ??
        currentProvider,
    modelId:
        compressModelId ??
        summaryModelId ??
        titleModelId ??
        assistantModelId ??
        currentModelId,
  );
}

/// Per-request UTF-16 budget for one compress `generateText` call.
///
/// Formula:
///   window = contextWindowTokens ?? defaultContextWindowTokens (32k)
///   usableTokens = window * (1 - reserveFraction)   // 30% reserved
///   chars = floor(usableTokens * charsPerToken)     // 1.6, CJK-heavy
///   budget = min(safeRequestChars, max(1, chars))
///
/// A 32k window → 22400 usable tokens → 35840 chars.
/// A 128k+ window is larger but still capped at [safeRequestChars].
int compressRequestCharBudget({
  int? contextWindowTokens,
  int safeRequestChars = CompressContextOptions.safeRequestChars,
  int defaultContextWindowTokens =
      CompressContextOptions.defaultContextWindowTokens,
  double reserveFraction = CompressContextOptions.contextReserveFraction,
  double charsPerToken = CompressContextOptions.charsPerToken,
}) {
  final window = (contextWindowTokens == null || contextWindowTokens <= 0)
      ? defaultContextWindowTokens
      : contextWindowTokens;
  final chars = (window * (1.0 - reserveFraction) * charsPerToken).floor();
  if (chars < 1) return 1;
  return chars < safeRequestChars ? chars : safeRequestChars;
}

String buildCompressContextContent(
  String joined,
  CompressContextOptions options,
) {
  if (options.mode == CompressContextLimitMode.unlimited ||
      options.mode == CompressContextLimitMode.keepRecent) {
    return joined;
  }
  final maxChars = options.maxChars ?? CompressContextOptions.defaultMaxChars;
  if (maxChars <= 0 || joined.length <= maxChars) return joined;
  return switch (options.mode) {
    CompressContextLimitMode.start => truncateHeadUtf16Safe(joined, maxChars),
    CompressContextLimitMode.recent => joined.substring(
      utf16SafeTailStart(joined, joined.length - maxChars),
    ),
    CompressContextLimitMode.unlimited ||
    CompressContextLimitMode.keepRecent => joined,
  };
}

String? conversationLineForCompression(ChatMessage message) {
  if (message.content.trim().isEmpty) return null;
  return '${message.role == "assistant" ? "Assistant" : "User"}: ${message.content}';
}

String buildConversationTextForCompression(List<ChatMessage> messages) {
  final lines = <String>[];
  for (final message in messages) {
    final line = conversationLineForCompression(message);
    if (line != null) lines.add(line);
  }
  return lines.join('\n\n');
}

/// Incremental start/recent window. Walks messages and stops at [maxChars]
/// without first joining the full history.
String buildBoundedConversationText(
  List<ChatMessage> messages, {
  required CompressContextLimitMode mode,
  required int maxChars,
}) {
  if (maxChars <= 0) return '';
  if (mode == CompressContextLimitMode.recent) {
    return _buildRecentBoundedConversationText(messages, maxChars);
  }
  return _buildStartBoundedConversationText(messages, maxChars);
}

String _buildStartBoundedConversationText(
  List<ChatMessage> messages,
  int maxChars,
) {
  final buf = StringBuffer();
  for (final message in messages) {
    if (message.content.trim().isEmpty) continue;
    final prefix = message.role == 'assistant' ? 'Assistant: ' : 'User: ';
    final sep = buf.isEmpty ? '' : '\n\n';
    final remaining = maxChars - buf.length;
    if (remaining <= 0) break;
    final head = '$sep$prefix';
    if (head.length >= remaining) {
      buf.write(truncateHeadUtf16Safe(head, remaining));
      break;
    }
    final contentBudget = remaining - head.length;
    final content = message.content.length <= contentBudget
        ? message.content
        : truncateHeadUtf16Safe(message.content, contentBudget);
    buf
      ..write(head)
      ..write(content);
    if (message.content.length > contentBudget) break;
  }
  return buf.toString();
}

String _buildRecentBoundedConversationText(
  List<ChatMessage> messages,
  int maxChars,
) {
  final parts = <String>[];
  var used = 0;
  for (var i = messages.length - 1; i >= 0; i--) {
    final message = messages[i];
    if (message.content.trim().isEmpty) continue;
    final prefix = message.role == 'assistant' ? 'Assistant: ' : 'User: ';
    final sepLen = parts.isEmpty ? 0 : 2;
    final remaining = maxChars - used - sepLen;
    if (remaining <= 0) break;
    final lineLen = prefix.length + message.content.length;
    if (lineLen <= remaining) {
      parts.add('$prefix${message.content}');
      used += lineLen + sepLen;
      continue;
    }
    final tail = _utf16SafeTailOfPrefixed(prefix, message.content, remaining);
    if (tail.isNotEmpty) parts.add(tail);
    break;
  }
  return parts.reversed.join('\n\n');
}

String _utf16SafeTailOfPrefixed(String prefix, String content, int maxChars) {
  final total = prefix.length + content.length;
  if (total <= maxChars) return '$prefix$content';
  if (maxChars <= 0) return '';
  if (maxChars <= content.length) {
    final start = utf16SafeTailStart(content, content.length - maxChars);
    return content.substring(start);
  }
  final prefixKeep = maxChars - content.length;
  final start = utf16SafeTailStart(prefix, prefix.length - prefixKeep);
  return '${prefix.substring(start)}$content';
}

/// Pack formatted messages into chunks of at most [maxChars].
/// Prefers message boundaries; a single over-long line is UTF-16-safe split.
List<String> chunkMessagesForCompression(
  List<ChatMessage> messages, {
  required int maxChars,
}) {
  if (maxChars <= 0) return const <String>[];
  final chunks = <String>[];
  final current = StringBuffer();

  void flush() {
    if (current.isEmpty) return;
    chunks.add(current.toString());
    current.clear();
  }

  for (final message in messages) {
    final line = conversationLineForCompression(message);
    if (line == null) continue;
    if (line.length > maxChars) {
      flush();
      chunks.addAll(splitUtf16SafeChunks(line, maxChars));
      continue;
    }
    final extra = current.isEmpty ? line.length : line.length + 2;
    if (current.isNotEmpty && current.length + extra > maxChars) {
      flush();
    }
    if (current.isNotEmpty) current.write('\n\n');
    current.write(line);
  }
  flush();
  return chunks;
}

/// Pack already-formatted texts (chunk summaries) into budget-sized groups.
List<String> chunkPlainTexts(List<String> texts, {required int maxChars}) {
  if (maxChars <= 0) return const <String>[];
  final chunks = <String>[];
  final current = StringBuffer();

  void flush() {
    if (current.isEmpty) return;
    chunks.add(current.toString());
    current.clear();
  }

  for (final text in texts) {
    if (text.isEmpty) continue;
    if (text.length > maxChars) {
      flush();
      chunks.addAll(splitUtf16SafeChunks(text, maxChars));
      continue;
    }
    final extra = current.isEmpty ? text.length : text.length + 2;
    if (current.isNotEmpty && current.length + extra > maxChars) {
      flush();
    }
    if (current.isNotEmpty) current.write('\n\n');
    current.write(text);
  }
  flush();
  return chunks;
}

/// Build the per-request compress payloads.
///
/// start/recent: incremental character window (never joins the full history),
/// then split only if the window itself exceeds [safeRequestChars].
/// keepRecent/unlimited: message-boundary chunks at [safeRequestChars] so
/// older content is not dropped and no single request is unbounded.
List<String> buildCompressRequestContents(
  List<ChatMessage> messages,
  CompressContextOptions options, {
  int safeRequestChars = CompressContextOptions.safeRequestChars,
}) {
  if (options.mode == CompressContextLimitMode.start ||
      options.mode == CompressContextLimitMode.recent) {
    final maxChars = options.maxChars ?? CompressContextOptions.defaultMaxChars;
    final bounded = buildBoundedConversationText(
      messages,
      mode: options.mode,
      maxChars: maxChars,
    );
    if (bounded.trim().isEmpty) return const <String>[];
    if (bounded.length <= safeRequestChars) return [bounded];
    return splitUtf16SafeChunks(bounded, safeRequestChars);
  }
  return chunkMessagesForCompression(messages, maxChars: safeRequestChars);
}

/// Select the trailing messages starting at the last [keepUserMessages]
/// user messages (user messages = role 'user' with non-empty content), so
/// the kept region always starts with a user message. When the requested
/// count covers all user messages, returns the full list (nothing left to
/// summarize).
List<ChatMessage> selectKeepRecentMessages(
  List<ChatMessage> messages,
  int keepUserMessages,
) {
  if (keepUserMessages <= 0) return const <ChatMessage>[];
  final userIndices = <int>[];
  for (var i = 0; i < messages.length; i++) {
    final m = messages[i];
    if (m.role == 'user' && m.content.trim().isNotEmpty) {
      userIndices.add(i);
    }
  }
  if (userIndices.isEmpty) return const <ChatMessage>[];
  if (userIndices.length <= keepUserMessages) return List.of(messages);
  return messages.sublist(userIndices[userIndices.length - keepUserMessages]);
}

/// Number of user messages in a collapsed list (role 'user', non-empty
/// content) — the count that [selectKeepRecentMessages] counts against.
int countUserMessages(List<ChatMessage> messages) {
  return messages
      .where((m) => m.role == 'user' && m.content.trim().isNotEmpty)
      .length;
}

/// Default keep count for the keep-recent mode, scaling with conversation
/// size (<5 user messages → 1, <10 → 2, ≥10 → 3) so a small conversation's
/// default never covers all of its user messages.
int defaultKeepUserMessageCountFor(int userMessageCount) {
  if (userMessageCount < 5) return 1;
  if (userMessageCount < 10) return 2;
  return 3;
}

class CompressionTokenEstimate {
  const CompressionTokenEstimate({
    required this.totalTokens,
    required this.keptTokens,
    required this.minResultTokens,
    required this.maxResultTokens,
  });

  final int totalTokens;
  final int keptTokens;
  final int minResultTokens;
  final int maxResultTokens;
}

/// Conservative detector for provider context-window / prompt-too-long errors.
///
/// Providers surface overflow as an HTTP / provider exception whose
/// `toString()` includes the API body. Only phrases that strongly indicate
/// an input-token overflow match; generic `max_tokens` config errors do not.
bool isContextLengthError(Object error) {
  final lower = error.toString().toLowerCase();
  const phrases = <String>[
    'context_length',
    'context length',
    'context window',
    'maximum context',
    'max context',
    'too many tokens',
    'prompt is too long',
    'prompt too long',
    'input is too long',
    'input too long',
    'reduce the length of the messages',
    'reduce the length of the prompt',
    'exceeds the maximum number of tokens',
  ];
  if (phrases.any(lower.contains)) return true;
  if (lower.contains('max_tokens') &&
      (lower.contains('exceed') ||
          lower.contains('too long') ||
          lower.contains('too many') ||
          lower.contains('over'))) {
    return true;
  }
  return false;
}

class _ContextSplitBudget {
  _ContextSplitBudget(this.remaining);

  int remaining;

  bool get canSplit => remaining > 0;

  void consume() {
    remaining--;
  }
}

/// Summarize [text], UTF-16-safely splitting and retrying on context-length
/// errors. [summarize] is the injected generate call (chunk or merge).
///
/// On overflow: split in half, summarize each half, then summarize the
/// joined pair (same merge path as multi-chunk). Stops when [maxSplits]
/// is exhausted or a half would be below [minSplitChars]. Other errors
/// are rethrown immediately.
Future<String> summarizeWithContextRetry(
  String text, {
  required Future<String> Function(String text) summarize,
  int maxSplits = CompressContextOptions.contextRetryMaxSplits,
  int minSplitChars = CompressContextOptions.contextRetryMinSplitChars,
  void Function(Object error, StackTrace stackTrace, String text)? onSplitRetry,
}) {
  return _summarizeWithContextRetry(
    text,
    summarize: summarize,
    budget: _ContextSplitBudget(maxSplits),
    minSplitChars: minSplitChars,
    onSplitRetry: onSplitRetry,
  );
}

Future<String> _summarizeWithContextRetry(
  String text, {
  required Future<String> Function(String text) summarize,
  required _ContextSplitBudget budget,
  required int minSplitChars,
  required void Function(Object error, StackTrace stackTrace, String text)?
  onSplitRetry,
}) async {
  try {
    return await summarize(text);
  } catch (e, st) {
    if (!isContextLengthError(e) || !budget.canSplit) {
      rethrow;
    }
    final halves = splitUtf16SafeHalves(text);
    if (halves == null ||
        halves.left.length < minSplitChars ||
        halves.right.length < minSplitChars) {
      rethrow;
    }
    budget.consume();
    onSplitRetry?.call(e, st, text);
    final left = await _summarizeWithContextRetry(
      halves.left,
      summarize: summarize,
      budget: budget,
      minSplitChars: minSplitChars,
      onSplitRetry: onSplitRetry,
    );
    final right = await _summarizeWithContextRetry(
      halves.right,
      summarize: summarize,
      budget: budget,
      minSplitChars: minSplitChars,
      onSplitRetry: onSplitRetry,
    );
    return _summarizeWithContextRetry(
      '$left\n\n$right',
      summarize: summarize,
      budget: budget,
      minSplitChars: minSplitChars,
      onSplitRetry: onSplitRetry,
    );
  }
}

/// Estimate the token budget of a keep-recent compression result.
///
/// Assumptions (documented in CONTEXT.md): kept tokens = totalTokens ×
/// (kept chars / total chars) — length ratio equals token ratio; the
/// summarized-away part is estimated at 10%–30% of its own tokens, exposed
/// as a [minResultTokens]–[maxResultTokens] band.
CompressionTokenEstimate estimateCompressionTokens({
  required String totalText,
  required String keptText,
}) {
  final totalTokens = estimateTokens(totalText);
  final totalChars = totalText.length;
  if (totalChars == 0) {
    return const CompressionTokenEstimate(
      totalTokens: 0,
      keptTokens: 0,
      minResultTokens: 0,
      maxResultTokens: 0,
    );
  }
  final keptTokens = (totalTokens * keptText.length / totalChars).round();
  final oldTokens = totalTokens - keptTokens;
  return CompressionTokenEstimate(
    totalTokens: totalTokens,
    keptTokens: keptTokens,
    minResultTokens: keptTokens + (oldTokens * 0.10).round(),
    maxResultTokens: keptTokens + (oldTokens * 0.30).round(),
  );
}
