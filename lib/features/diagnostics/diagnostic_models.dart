import '../../core/models/chat_message.dart';
import '../../core/models/conversation.dart';

/// Severity of a diagnostic finding.
enum DiagnosticSeverity {
  /// Must fix now, hit rate is critically low.
  urgent,

  /// Potential issue, recommend fixing.
  risk,
}

/// Diagnostic rule identifier (A1..A6, T1, F1).
enum DiagnosticKind {
  contextOverflow, // A1
  systemTimeVariable, // A2
  templateTimeBefore, // A3
  memory, // A4
  worldBookNonBottom, // A6
  toolTokenHigh, // T1
  fallbackUpstream, // F1b
  fallbackInterval, // F1a
}

/// One diagnostic finding to display in the result page.
class DiagnosticFinding {
  const DiagnosticFinding({
    required this.kind,
    required this.severity,
    required this.title,
    required this.subtitle,
    required this.solution,
    this.titleSuffix,
  });

  final DiagnosticKind kind;
  final DiagnosticSeverity severity;
  final String title;

  /// Optional secondary lines (e.g. A4 has two sub-reasons).
  final List<SubtitleLine> subtitle;

  /// Solution copy shown below the description.
  final String solution;

  /// Optional suffix appended after the resolved title (used by T1 to
  /// surface the dominant tool name and percentage).
  final String? titleSuffix;
}

/// Convenience class carrying a per-line subtitle (key + dynamic suffix).
class SubtitleLine {
  const SubtitleLine(this.key, {this.suffix = ''});
  final String key;
  final String suffix;
}

/// Aggregated token usage for the analyzed window.
class TokenAggregate {
  const TokenAggregate({
    required this.inputTokens,
    required this.cachedTokens,
    required this.uncachedTokens,
    required this.completionTokens,
    required this.toolTokens,
    required this.sampledMessageCount,
    required this.assistantMessageCount,
    required this.userMessageCount,
  });

  /// Sum of prompt_tokens across assistant messages in the window.
  final int inputTokens;

  /// Sum of cached_tokens across assistant messages in the window.
  final int cachedTokens;

  /// promptTokens - cachedTokens.
  final int uncachedTokens;

  /// Sum of completion_tokens across assistant messages.
  final int completionTokens;

  /// Estimated tokens consumed by tool call results (per-tool sum).
  final int toolTokens;

  /// Number of assistant messages that contributed to the stats.
  final int sampledMessageCount;

  /// Number of assistant messages in the window (including unsampled).
  final int assistantMessageCount;

  /// Number of user messages in the window.
  final int userMessageCount;

  double get hitRate {
    if (inputTokens <= 0) return 0;
    return cachedTokens / inputTokens;
  }

  /// Ratio of tool tokens against total input tokens (not including output).
  double get toolRatio {
    if (inputTokens <= 0) return 0;
    return toolTokens / inputTokens;
  }

  static const empty = TokenAggregate(
    inputTokens: 0,
    cachedTokens: 0,
    uncachedTokens: 0,
    completionTokens: 0,
    toolTokens: 0,
    sampledMessageCount: 0,
    assistantMessageCount: 0,
    userMessageCount: 0,
  );
}

/// Per-tool token breakdown for the T1 finding.
class ToolTokenEntry {
  const ToolTokenEntry({required this.name, required this.tokens});

  final String name;
  final int tokens;
}

/// Full diagnostic result for one conversation.
class DiagnosticReport {
  const DiagnosticReport({
    required this.conversation,
    required this.aggregate,
    required this.findings,
    required this.toolBreakdown,
    required this.assistant,
    required this.assistantMemoryCount,
    required this.assistantActiveWorldBookCount,
    required this.truncated,
    required this.maxTimestamp,
    required this.minTimestamp,
    required this.intervalLongRatio,
    required this.dataSufficient,
    this.sampled = const [],
  });

  final Conversation conversation;
  final TokenAggregate aggregate;
  final List<DiagnosticFinding> findings;

  /// Per-tool token breakdown (only for tools with non-zero tokens).
  final List<ToolTokenEntry> toolBreakdown;

  /// The assistant linked to this conversation (may be null for default).
  final dynamic assistant; // Assistant?, kept dynamic to avoid hard import.

  final int assistantMemoryCount;
  final int assistantActiveWorldBookCount;

  /// Whether the conversation is currently being context-truncated.
  final bool truncated;

  final DateTime? maxTimestamp;
  final DateTime? minTimestamp;

  /// Ratio of user-message pairs with interval > 5 min in the window.
  final double intervalLongRatio;

  /// True if the conversation has enough token data; false → show "数据不足".
  final bool dataSufficient;

  /// Used messages (assistant only) for downstream inspection.
  final List<ChatMessage> sampled;

  /// Backwards-compatible getter.
  List<ChatMessage> get sampledAssistantMessages => sampled;
}
