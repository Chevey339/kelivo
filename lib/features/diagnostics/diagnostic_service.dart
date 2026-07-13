import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;

import '../../core/models/assistant.dart';
import '../../core/models/chat_message.dart';
import '../../core/models/conversation.dart';
import '../../core/models/world_book.dart';
import '../../core/providers/assistant_provider.dart';
import '../../core/providers/memory_provider.dart';
import '../../core/providers/world_book_provider.dart';
import '../../core/services/chat/chat_service.dart';
import 'diagnostic_models.dart';

/// Per-conversation cache diagnostic engine.
///
/// Reads token usage from the persisted `ChatMessage` rows of a single
/// conversation, classifies findings, and returns a [DiagnosticReport].
class CacheDiagnosticService {
  CacheDiagnosticService({
    required this.chatService,
    required this.assistantProvider,
    required this.memoryProvider,
    required this.worldBookProvider,
    DateTime Function()? now,
    this.analysisWindow = const Duration(hours: 24),
    this.toolTokenCharPerToken = 2,
  }) : _now = now ?? DateTime.now;

  final ChatService chatService;
  final AssistantProvider assistantProvider;
  final MemoryProvider memoryProvider;
  final WorldBookProvider worldBookProvider;

  final DateTime Function() _now;
  final Duration analysisWindow;
  final int toolTokenCharPerToken;

  static const Color kCached = Color(0xFFA0DCFD); // rgb(160, 220, 253)
  static const Color kUncached = Color(0xFF60B3FE); // rgb(96, 179, 254)

  /// Tokens contributed by the system prompt, the conversation prefix, and
  /// per-user input. We use 2 chars/token as a coarse estimator.
  int estimateTokensFromChars(String text) {
    if (text.isEmpty) return 0;
    return (text.length / toolTokenCharPerToken).ceil();
  }

  /// Check whether a conversation has enough token data to be analyzed.
  ///
  /// Returns true when at most 20% of assistant messages within the window
  /// have no token info AND there is at least one message in the window.
  bool hasSufficientData(Conversation conversation) {
    final messages = _windowedAssistantMessages(conversation);
    if (messages.isEmpty) return false;
    final missing = messages
        .where((m) => m.promptTokens == null && m.cachedTokens == null)
        .length;
    return missing / messages.length <= 0.2;
  }

  /// Build a full diagnostic report for a single conversation.
  Future<DiagnosticReport> analyze(Conversation conversation) async {
    final allMessages = chatService.getMessages(conversation.id);
    final cutoff = _now().subtract(analysisWindow);
    final inWindow = allMessages
        .where((m) => !m.timestamp.isBefore(cutoff))
        .toList(growable: false);

    final assistant = _resolveAssistant(conversation);
    final assistantMsgs = inWindow.where((m) => m.role == 'assistant').toList();
    final userMsgs = inWindow.where((m) => m.role == 'user').toList();

    final aggregate = _aggregate(assistantMsgs, userMsgs);
    final toolBreakdown = _toolBreakdown(assistantMsgs);
    final truncated =
        conversation.truncateIndex >= 0 &&
        conversation.truncateIndex < conversation.messageIds.length;

    final intervalRatio = _longIntervalRatio(userMsgs);

    final findings = <DiagnosticFinding>[];

    // A1 — context overflow
    final a1 = _checkA1(conversation, assistant, aggregate, truncated);
    if (a1 != null) findings.add(a1);

    // A2 — system time variable
    final a2 = _checkA2(assistant, aggregate);
    if (a2 != null) findings.add(a2);

    // A3 — template time variable in front
    final a3 = _checkA3(assistant, aggregate);
    if (a3 != null) findings.add(a3);

    // A4 — memory breaking cache
    final memoryCount = assistant == null
        ? 0
        : memoryProvider.getForAssistant(assistant.id).length;
    final a4 = _checkA4(assistant, memoryCount, aggregate, assistantMsgs);
    if (a4 != null) findings.add(a4);

    // A6 — world book non-bottom + high trigger
    final activeWbCount = _activeWorldBookCount(conversation, assistant);
    final a6 = _checkA6(
      assistant,
      activeWbCount,
      inWindow,
      userMsgs,
      aggregate,
    );
    if (a6 != null) findings.add(a6);

    // T1 — tool token high (隐患 only)
    final t1 = _checkT1(aggregate, toolBreakdown);
    if (t1 != null) findings.add(t1);

    // F1 — fallback
    final f1 = _checkF1(findings, aggregate, intervalRatio);
    if (f1 != null) findings.add(f1);

    DateTime? maxTs;
    DateTime? minTs;
    if (inWindow.isNotEmpty) {
      maxTs = inWindow.first.timestamp;
      minTs = inWindow.first.timestamp;
      for (final m in inWindow) {
        if (m.timestamp.isAfter(maxTs!)) maxTs = m.timestamp;
        if (m.timestamp.isBefore(minTs!)) minTs = m.timestamp;
      }
    }
    return DiagnosticReport(
      conversation: conversation,
      aggregate: aggregate,
      findings: findings,
      toolBreakdown: toolBreakdown,
      assistant: assistant,
      assistantMemoryCount: memoryCount,
      assistantActiveWorldBookCount: activeWbCount,
      truncated: truncated,
      maxTimestamp: maxTs,
      minTimestamp: minTs,
      intervalLongRatio: intervalRatio,
      dataSufficient: hasSufficientData(conversation),
      sampled: assistantMsgs,
    );
  }

  // --- helpers ---

  Assistant? _resolveAssistant(Conversation conversation) {
    final id = conversation.assistantId;
    if (id == null) return null;
    return assistantProvider.getById(id);
  }

  List<ChatMessage> _windowedAssistantMessages(Conversation conversation) {
    final all = chatService.getMessages(conversation.id);
    final cutoff = _now().subtract(analysisWindow);
    return all
        .where((m) => m.role == 'assistant' && !m.timestamp.isBefore(cutoff))
        .toList(growable: false);
  }

  TokenAggregate _aggregate(
    List<ChatMessage> assistantMsgs,
    List<ChatMessage> userMsgs,
  ) {
    int input = 0;
    int cached = 0;
    int completion = 0;
    int toolTokens = 0;
    int sampled = 0;
    int toolEstimatedChars = 0;
    for (final m in assistantMsgs) {
      final p = m.promptTokens;
      if (p != null) {
        input += p;
        sampled++;
      }
      cached += m.cachedTokens ?? 0;
      completion += m.completionTokens ?? 0;
      // Tool events may not have a stored token count, so estimate by char.
      final events = chatService.getToolEvents(m.id);
      for (final e in events) {
        final c = e['content'];
        if (c is String) toolEstimatedChars += c.length;
      }
    }
    toolTokens = (toolEstimatedChars / toolTokenCharPerToken).ceil();
    return TokenAggregate(
      inputTokens: input,
      cachedTokens: math.min(cached, input),
      uncachedTokens: math.max(0, input - math.min(cached, input)),
      completionTokens: completion,
      toolTokens: toolTokens,
      sampledMessageCount: sampled,
      assistantMessageCount: assistantMsgs.length,
      userMessageCount: userMsgs.length,
    );
  }

  List<ToolTokenEntry> _toolBreakdown(List<ChatMessage> assistantMsgs) {
    final byName = <String, int>{};
    for (final m in assistantMsgs) {
      final events = chatService.getToolEvents(m.id);
      for (final e in events) {
        final name = (e['name'] ?? '').toString();
        if (name.isEmpty) continue;
        final c = e['content'];
        final chars = c is String ? c.length : 0;
        byName[name] = (byName[name] ?? 0) + chars;
      }
    }
    final entries =
        byName.entries
            .map(
              (e) => ToolTokenEntry(
                name: e.key,
                tokens: (e.value / toolTokenCharPerToken).ceil(),
              ),
            )
            .where((e) => e.tokens > 0)
            .toList()
          ..sort((a, b) => b.tokens.compareTo(a.tokens));
    return entries;
  }

  double _longIntervalRatio(List<ChatMessage> userMsgs) {
    if (userMsgs.length < 2) return 0;
    final sorted = [...userMsgs]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    int longCount = 0;
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i].timestamp.difference(sorted[i - 1].timestamp);
      if (gap.inMinutes > 5) longCount++;
    }
    return longCount / (sorted.length - 1);
  }

  int _activeWorldBookCount(Conversation conversation, Assistant? assistant) {
    if (assistant == null) return 0;
    final ids = worldBookProvider.activeBookIdsFor(assistant.id).toSet();
    final books = worldBookProvider.books
        .where((b) => ids.contains(b.id) && b.enabled)
        .toList();
    return books.fold<int>(0, (sum, b) => sum + b.entries.length);
  }

  // --- A1: context overflow ---
  DiagnosticFinding? _checkA1(
    Conversation conversation,
    Assistant? assistant,
    TokenAggregate agg,
    bool truncated,
  ) {
    if (assistant == null) return null;
    if (!assistant.limitContextMessages) return null;
    final limit = assistant.contextMessageSize;
    final allMessages = chatService.getMessages(conversation.id);
    final userCount = allMessages.where((m) => m.role == 'user').length;
    final oversize = userCount > limit;
    if (!oversize && !truncated) return null;
    return const DiagnosticFinding(
      kind: DiagnosticKind.contextOverflow,
      severity: DiagnosticSeverity.urgent,
      title: 'diagA1Title',
      subtitle: [SubtitleLine('diagA1Subtitle')],
      solution: 'diagA1Solution',
    );
  }

  // --- A2: system prompt has time variable ---
  DiagnosticFinding? _checkA2(Assistant? assistant, TokenAggregate agg) {
    if (assistant == null) return null;
    final p = assistant.systemPrompt;
    final hasTime =
        p.contains('{cur_time}') ||
        p.contains('{cur_datetime}') ||
        p.contains('{cur_date}');
    if (!hasTime) return null;
    final sev = _classify(agg, urgentAt: 0.40, riskAt: 0.70);
    if (sev == null) return null;
    return DiagnosticFinding(
      kind: DiagnosticKind.systemTimeVariable,
      severity: sev,
      title: 'diagA2Title',
      subtitle: const [SubtitleLine('diagA2Subtitle')],
      solution: 'diagA2Solution',
    );
  }

  // --- A3: message template has time variable BEFORE {{ message }} ---
  DiagnosticFinding? _checkA3(Assistant? assistant, TokenAggregate agg) {
    if (assistant == null) return null;
    final tmpl = assistant.messageTemplate;
    if (!_hasTimeBeforeMessage(tmpl)) return null;
    final sev = _classify(agg, urgentAt: 0.40, riskAt: 0.70);
    if (sev == null) return null;
    return DiagnosticFinding(
      kind: DiagnosticKind.templateTimeBefore,
      severity: sev,
      title: 'diagA3Title',
      subtitle: const [SubtitleLine('diagA3Subtitle')],
      solution: 'diagA3Solution',
    );
  }

  bool _hasTimeBeforeMessage(String tmpl) {
    if (tmpl.isEmpty) return false;
    final hasTime = tmpl.contains('{{ time }}') || tmpl.contains('{{ date }}');
    if (!hasTime) return false;
    final msgMatch = RegExp(r'{{\s*message\s*}}').firstMatch(tmpl);
    if (msgMatch == null) {
      return true; // no {{ message }} → variable appears before by definition
    }
    final timeIdx = tmpl.indexOf('{{ time }}');
    final timeIdx2 = tmpl.indexOf('{{ date }}');
    final earliestTime = [
      timeIdx,
      timeIdx2,
    ].where((i) => i >= 0).fold<int>(tmpl.length, math.min);
    return earliestTime < msgMatch.start;
  }

  // --- A4: memory breaking cache ---
  DiagnosticFinding? _checkA4(
    Assistant? assistant,
    int memoryCount,
    TokenAggregate agg,
    List<ChatMessage> assistantMsgs,
  ) {
    if (assistant == null || !assistant.enableMemory) return null;
    final mems = memoryProvider.getForAssistant(assistant.id);
    if (mems.isEmpty) return null; // No memories → no A4 fire.

    final memChanged = _memoryContentChangedInWindow(assistant.id);
    final hourChanged = _hourChangedInWindow(assistantMsgs);
    if (!memChanged && !hourChanged) return null;

    final sev = _classify(agg, urgentAt: 0.30, riskAt: 0.60);
    if (sev == null) return null;

    final subtitles = <SubtitleLine>[];
    if (memChanged) subtitles.add(const SubtitleLine('diagA4SubContent'));
    if (hourChanged) subtitles.add(const SubtitleLine('diagA4SubHour'));

    return DiagnosticFinding(
      kind: DiagnosticKind.memory,
      severity: sev,
      title: 'diagA4Title',
      subtitle: subtitles,
      solution: 'diagA4Solution',
    );
  }

  bool _memoryContentChangedInWindow(String assistantId) {
    // We don't have per-edit timestamps for memories, so we conservatively
    // assume "true" when there is at least one memory row for this assistant.
    // This is a deliberate trade-off: the feature is opt-in, and the
    // diagnostic should err on the side of warning rather than missing.
    return memoryProvider.getForAssistant(assistantId).isNotEmpty;
  }

  bool _hourChangedInWindow(List<ChatMessage> assistantMsgs) {
    if (assistantMsgs.length < 2) return false;
    final sorted = [...assistantMsgs]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    String? prevHour;
    for (final m in sorted) {
      final h = _hourKey(m.timestamp);
      if (prevHour != null && h != prevHour) return true;
      prevHour ??= h;
    }
    return false;
  }

  String _hourKey(DateTime t) => '${t.year}-${t.month}-${t.day}-${t.hour}';

  // --- A6: world book non-bottom + high trigger ---
  DiagnosticFinding? _checkA6(
    Assistant? assistant,
    int activeWbCount,
    List<ChatMessage> allMsgs,
    List<ChatMessage> userMsgs,
    TokenAggregate agg,
  ) {
    if (assistant == null) return null;
    final activeIds = worldBookProvider.activeBookIdsFor(assistant.id).toSet();
    final books = worldBookProvider.books
        .where((b) => activeIds.contains(b.id) && b.enabled)
        .toList();
    if (books.isEmpty) return null;

    final nonBottom = <WorldBookEntry>[];
    for (final b in books) {
      for (final e in b.entries) {
        if (!e.enabled) continue;
        if (e.constantActive) continue;
        if (e.position == WorldBookInjectionPosition.bottomOfChat) continue;
        nonBottom.add(e);
      }
    }
    if (nonBottom.isEmpty) return null;

    if (userMsgs.isEmpty) return null;
    final triggers = _countTriggers(userMsgs, nonBottom);
    final triggerRate = triggers / userMsgs.length;
    if (triggerRate < 0.60) return null;

    final sev = _classify(agg, urgentAt: 0.50, riskAt: 0.70);
    if (sev == null) return null;

    return DiagnosticFinding(
      kind: DiagnosticKind.worldBookNonBottom,
      severity: sev,
      title: 'diagA6Title',
      subtitle: [
        SubtitleLine(
          'diagA6Subtitle',
          suffix: ' (${(triggerRate * 100).round()}%)',
        ),
      ],
      solution: 'diagA6Solution',
    );
  }

  int _countTriggers(List<ChatMessage> userMsgs, List<WorldBookEntry> entries) {
    int hits = 0;
    for (final m in userMsgs) {
      final ctx = m.content;
      for (final e in entries) {
        if (e.keywords.isEmpty) continue;
        for (final raw in e.keywords) {
          final k = raw.trim();
          if (k.isEmpty) continue;
          bool matched;
          if (e.useRegex) {
            try {
              matched = RegExp(k, caseSensitive: e.caseSensitive).hasMatch(ctx);
            } catch (_) {
              matched = false;
            }
          } else {
            matched = e.caseSensitive
                ? ctx.contains(k)
                : ctx.toLowerCase().contains(k.toLowerCase());
          }
          if (matched) {
            hits++;
            break;
          }
        }
      }
    }
    return hits;
  }

  // --- T1: tool token high (隐患 only) ---
  DiagnosticFinding? _checkT1(
    TokenAggregate agg,
    List<ToolTokenEntry> breakdown,
  ) {
    if (agg.toolRatio <= 0.60) return null;
    if (breakdown.isEmpty) return null;

    // Take the top tool; if the second is within 5% of the first, include it.
    final top = breakdown.take(2).toList();
    String names;
    if (top.length == 2) {
      final first = top[0].tokens;
      final second = top[1].tokens;
      if (first == 0 || (first - second) / first <= 0.05) {
        names = '${top[0].name}, ${top[1].name}';
      } else {
        names = top[0].name;
      }
    } else {
      names = top.first.name;
    }
    final pct = (agg.toolRatio * 100).round();
    return DiagnosticFinding(
      kind: DiagnosticKind.toolTokenHigh,
      severity: DiagnosticSeverity.risk,
      title: 'diagT1Title',
      titleSuffix: ' · $names · $pct%',
      subtitle: const [SubtitleLine('diagT1Subtitle')],
      solution: 'diagT1Solution',
    );
  }

  // --- F1: fallback (隐患 only) ---
  DiagnosticFinding? _checkF1(
    List<DiagnosticFinding> findings,
    TokenAggregate agg,
    double intervalRatio,
  ) {
    final hasUrgent = findings.any(
      (f) => f.severity == DiagnosticSeverity.urgent,
    );
    if (hasUrgent) return null;
    final hasRisk = findings.any((f) => f.severity == DiagnosticSeverity.risk);
    if (hasRisk) return null;
    if (agg.hitRate >= 0.30) return null;
    if (agg.inputTokens <= 0) return null;
    if (intervalRatio >= 0.50) {
      return const DiagnosticFinding(
        kind: DiagnosticKind.fallbackInterval,
        severity: DiagnosticSeverity.risk,
        title: 'diagF1aTitle',
        subtitle: [SubtitleLine('diagF1aSubtitle')],
        solution: 'diagF1aSolution',
      );
    }
    return const DiagnosticFinding(
      kind: DiagnosticKind.fallbackUpstream,
      severity: DiagnosticSeverity.risk,
      title: 'diagF1bTitle',
      subtitle: [SubtitleLine('diagF1bSubtitle')],
      solution: 'diagF1bSolution',
    );
  }

  /// Centralised urgent/risk classifier.
  ///
  /// Returns null when hit rate is healthy for the rule.
  DiagnosticSeverity? _classify(
    TokenAggregate agg, {
    required double urgentAt,
    required double riskAt,
  }) {
    if (agg.inputTokens <= 0) return null;
    if (agg.userMessageCount < 5) return DiagnosticSeverity.risk;
    if (agg.hitRate < urgentAt) return DiagnosticSeverity.urgent;
    if (agg.hitRate < riskAt) return DiagnosticSeverity.risk;
    return null;
  }
}
