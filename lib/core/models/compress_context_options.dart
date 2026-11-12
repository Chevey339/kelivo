import '../utils/token_estimator.dart';
import 'chat_message.dart';
import 'context_operation.dart';
import 'message_part.dart';

enum CompressContextLimitMode { start, recent, unlimited, keepRecent }

class CompressContextOptions {
  const CompressContextOptions({
    required this.mode,
    this.maxChars,
    this.keepUserMessages,
    this.historySource = ContextHistorySource.effective,
    this.includeEditedSummaries = true,
    this.includeAttachmentsAndTools = true,
    this.regenerateExisting = false,
    this.newConversation = false,
    this.focus = '',
    this.previewOnly = false,
    this.native = false,
  });

  static const int defaultMaxChars = 6000;
  static const int defaultKeepUserMessages = 6;

  /// Planning window when the summary model has no catalog or explicit limit.
  static const int defaultContextWindowTokens = 1048576;

  final CompressContextLimitMode mode;
  final int? maxChars;
  final int? keepUserMessages;
  final ContextHistorySource historySource;
  final bool includeEditedSummaries;
  final bool includeAttachmentsAndTools;
  final bool regenerateExisting;
  final bool newConversation;
  final String focus;
  final bool previewOnly;
  final bool native;

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'maxChars': maxChars,
    'keep': keepUserMessages,
    'source': historySource.name,
    'includeEdited': includeEditedSummaries,
    'includeAttachmentsAndTools': includeAttachmentsAndTools,
    'regenerateExisting': regenerateExisting,
    'newConversation': newConversation,
    'focus': focus,
    'previewOnly': previewOnly,
    'native': native,
  };

  factory CompressContextOptions.fromJson(Map<String, dynamic> json) =>
      CompressContextOptions(
        mode: CompressContextLimitMode.values.byName(json['mode'] as String),
        maxChars: json['maxChars'] as int?,
        keepUserMessages: json['keep'] as int?,
        historySource: ContextHistorySource.values.byName(
          json['source'] as String,
        ),
        includeEditedSummaries: json['includeEdited'] as bool,
        includeAttachmentsAndTools: json['includeAttachmentsAndTools'] != false,
        regenerateExisting: json['regenerateExisting'] == true,
        newConversation: json['newConversation'] as bool,
        focus: json['focus'] as String? ?? '',
        previewOnly: json['previewOnly'] == true,
        native: json['native'] == true,
      );
}

bool isCompressionUserMessage(ChatMessage message) =>
    message.role == 'user' &&
    !ContextOperation.isSummary(message) &&
    !message.id.startsWith('context-note:') &&
    (message.content.trim().isNotEmpty ||
        message.parts.any((part) => part is ImagePart || part is FilePart));

class CompressionHistory {
  const CompressionHistory({required this.messages, required this.operations});
  factory CompressionHistory.fromMessages(
    List<ChatMessage> messages,
    List<ContextOperation> operations,
  ) => CompressionHistory(
    messages: messages.map(ContextMessageMetadata.fromMessage).toList(),
    operations: operations,
  );
  final List<ContextMessageMetadata> messages;
  final List<ContextOperation> operations;
}

typedef ContextSelection<T> = ({
  List<T> effective,
  List<T> retained,
  List<T> covered,
  List<T> input,
  List<String> dependencies,
  bool needsRegeneration,
  bool missingOriginals,
});
typedef CompressionSelection = ContextSelection<ChatMessage>;
typedef CompressionRangeSelection = ContextSelection<ContextMessageMetadata>;

CompressionSelection selectCompressionHistory(
  List<ChatMessage> messages,
  List<ContextOperation> operations,
  CompressContextOptions options, {
  String? protectedMessageId,
  Set<String>? effectiveMessageIds,
}) {
  final range = selectCompressionRange(
    messages.map(ContextMessageMetadata.fromMessage).toList(),
    operations,
    options,
    protectedMessageId: protectedMessageId,
    effectiveMessageIds: effectiveMessageIds,
  );
  final entries = {
    for (final m in [
      ...range.effective,
      ...range.retained,
      ...range.covered,
      ...range.input,
    ])
      m.id: m,
  };
  final hydrated = {
    for (final m in ContextHistory.materialize(
      messages,
      operations,
      entries.values.toList(),
    ))
      m.id: m,
  };
  List<ChatMessage> materialize(List<ContextMessageMetadata> entries) => [
    for (final entry in entries) hydrated[entry.id]!,
  ];
  return (
    effective: materialize(range.effective),
    retained: materialize(range.retained),
    covered: materialize(range.covered),
    input: materialize(range.input),
    dependencies: range.dependencies,
    needsRegeneration: range.needsRegeneration,
    missingOriginals: range.missingOriginals,
  );
}

List<ContextMessageMetadata> _keepRecentMetadata(
  List<ContextMessageMetadata> messages,
  int keep,
) {
  if (keep <= 0) return const [];
  final indices = [
    for (var i = 0; i < messages.length; i++)
      if (messages[i].isUserMessage) i,
  ];
  if (indices.isEmpty) return const [];
  if (indices.length <= keep) {
    return messages.skipWhile((m) => m.isSummary).toList();
  }
  return messages.sublist(indices[indices.length - keep]);
}

/// The options preview and the actual task use the same range selection.
CompressionRangeSelection selectCompressionRange(
  List<ContextMessageMetadata> messages,
  List<ContextOperation> operations,
  CompressContextOptions options, {
  String? protectedMessageId,
  Set<String>? effectiveMessageIds,
}) {
  final effective = ContextHistory.project(messages, operations)
      .where(
        (message) =>
            effectiveMessageIds == null ||
            effectiveMessageIds.contains(message.id),
      )
      .toList();
  final keep = options.mode == CompressContextLimitMode.keepRecent
      ? options.keepUserMessages ??
            CompressContextOptions.defaultKeepUserMessages
      : 0;
  final retained = keep == 0
      ? <ContextMessageMetadata>[]
      : _keepRecentMetadata(effective, keep);
  var prefix = effective.take(effective.length - retained.length).toList();
  if (options.mode == CompressContextLimitMode.start ||
      options.mode == CompressContextLimitMode.recent) {
    // The old character setting now chooses whole messages. Coverage and
    // serialization always receive exactly the same selection.
    final selected = <ContextMessageMetadata>[];
    var length = 0;
    final candidates = options.mode == CompressContextLimitMode.recent
        ? prefix.reversed
        : prefix;
    for (final message in candidates) {
      if (length >=
          (options.maxChars ?? CompressContextOptions.defaultMaxChars)) {
        break;
      }
      selected.add(message);
      length += message.contentLength;
    }
    prefix = options.mode == CompressContextLimitMode.recent
        ? selected.reversed.toList()
        : selected;
  }
  if (protectedMessageId != null) {
    final protected = effective.indexWhere((m) => m.id == protectedMessageId);
    if (protected < 0) throw StateError('context_changed');
    final allowed = effective.take(protected).map((m) => m.id).toSet();
    prefix = prefix.where((m) => allowed.contains(m.id)).toList();
  }
  final dependencies = prefix
      .where((m) => m.isSummary)
      .map((m) => m.id.substring(ContextOperation.summaryPrefix.length))
      .toList();
  final byId = {for (final op in operations) op.id: op};
  final byMessage = {
    for (final op in operations) op.summaryMessageId: op,
    for (final op in operations) 'context-note:${op.id}': op,
  };
  final groups = <String>{
    for (final message in prefix)
      if (!message.isSummary) message.groupId,
    for (final id in dependencies) ...?byId[id]?.sourceGroups,
  };
  final expanded = ContextHistory.compressionProjection(
    messages,
    operations,
    source: options.historySource,
    includeEditedSummaries: options.includeEditedSummaries,
    includeNative: options.native,
  );
  final input = expanded.where((message) {
    if (groups.contains(message.groupId)) return true;
    final operation = byMessage[message.id];
    return operation != null && operation.sourceGroups.every(groups.contains);
  }).toList();
  final prefixIds = prefix.map((m) => m.id).toSet();
  return (
    effective: effective,
    retained: effective.where((m) => !prefixIds.contains(m.id)).toList(),
    covered: messages.where((m) => groups.contains(m.groupId)).toList(),
    dependencies: dependencies,
    needsRegeneration:
        !options.native &&
        prefix.isNotEmpty &&
        prefix.every((m) => m.isSummary) &&
        options.historySource == ContextHistorySource.effective &&
        !options.regenerateExisting,
    input: input,
    missingOriginals: !options.native && input.any((message) => message.native),
  );
}

/// Resolve an explicit compression model as a pair, otherwise use the
/// conversation's current chat model. Never silently change providers.
({String? providerKey, String? modelId}) resolveCompressContextModel({
  String? compressProvider,
  String? compressModelId,
  String? assistantProvider,
  String? assistantModelId,
  String? currentProvider,
  String? currentModelId,
}) => compressProvider != null && compressModelId != null
    ? (providerKey: compressProvider, modelId: compressModelId)
    : assistantProvider != null && assistantModelId != null
    ? (providerKey: assistantProvider, modelId: assistantModelId)
    : (providerKey: currentProvider, modelId: currentModelId);

String? conversationLineForCompression(
  ChatMessage message, {
  required String Function(int) quoteMarker,
}) {
  final content = message.quotedContent(quoteMarker);
  if (content.trim().isEmpty) return null;
  return '[source message:${message.id}; role=${message.role}]\n${message.role == 'assistant' ? 'Assistant' : 'User'}: $content';
}

String buildConversationTextForCompression(
  List<ChatMessage> messages, {
  required String Function(int) quoteMarker,
}) => buildCompressRequestContents(
  messages,
  const CompressContextOptions(mode: CompressContextLimitMode.unlimited),
  quoteMarker: quoteMarker,
).join('\n\n');

/// Whole selected messages for local preview and the token-budgeted engine.
List<String> buildCompressRequestContents(
  List<ChatMessage> messages,
  CompressContextOptions options, {
  required String Function(int) quoteMarker,
}) => [
  for (final message in messages)
    if (conversationLineForCompression(message, quoteMarker: quoteMarker)
        case final String text)
      text,
];

/// Select the trailing messages starting at the last [keepUserMessages]
/// user messages, including attachment-only inputs. Leading summaries stay
/// outside the retained region so an explicit original-history reread can
/// regenerate them even when all raw user messages are retained.
List<ChatMessage> selectKeepRecentMessages(
  List<ChatMessage> messages,
  int keepUserMessages,
) {
  if (keepUserMessages <= 0) return const <ChatMessage>[];
  final userIndices = <int>[];
  for (var i = 0; i < messages.length; i++) {
    final m = messages[i];
    if (isCompressionUserMessage(m)) {
      userIndices.add(i);
    }
  }
  if (userIndices.isEmpty) return const <ChatMessage>[];
  if (userIndices.length <= keepUserMessages) {
    return messages.skipWhile(ContextOperation.isSummary).toList();
  }
  return messages.sublist(userIndices[userIndices.length - keepUserMessages]);
}

/// Number of user messages in a collapsed list (role 'user', non-empty
/// content) — the count that [selectKeepRecentMessages] counts against.
int countUserMessages(List<ChatMessage> messages) {
  return messages.where(isCompressionUserMessage).length;
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
  return false;
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
