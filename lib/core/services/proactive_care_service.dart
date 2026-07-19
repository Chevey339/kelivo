import 'dart:convert';

import '../models/assistant_memory.dart';

/// Pure logic for the proactive care ("Ta的来信") decision flow.
///
/// After each completed assistant reply, the full conversation context plus
/// the decision prompt built here is sent silently to the decision model.
/// The model answers with a JSON decision that may update the assistant's
/// next proactive message time.
class ProactiveCareService {
  /// Built-in JSON output rules for the decision request (LLM only).
  ///
  /// Time fields are appended separately via [buildDecisionTimeFooter] after
  /// the chat history.
  static const String builtinDecisionJsonRules = '''
【输出要求】
你必须严格以 JSON 格式输出，不要包含任何额外文字：
{
  "should_update": true或false,
  "next_care_time": "ISO 8601格式的时间字符串，如2026-06-12T10:00:00"
}''';

  /// Prefix before the assistant persona in the decision request (LLM only).
  static const String personaReferencePrefix = '以下是供你参考的助手人设';

  /// Prefix before the memory block in the decision request (LLM only).
  static const String memoriesReferencePrefix = '以下是供你参考的助手记忆';

  /// Prefix inserted as a separate user message before chat history (LLM only).
  static const String chatHistoryPrefix = '以下是用户与助手的聊天记录';

  /// Built-in suffix appended to the user-configured care prompt when the
  /// proactive care time arrives (LLM only, never shown in UI).
  static const String builtinCareTimePrompt = '当前系统时间：{current_system_time}';

  /// Builds the time footer placed after chat history in the decision request.
  static String buildDecisionTimeFooter({
    required DateTime now,
    required DateTime? currentNextCareTime,
  }) {
    return '''
当前已设定的下次主动关怀时间：${currentNextCareTime?.toIso8601String() ?? '未设定'}
当前系统时间：${now.toIso8601String()}'''
        .trim();
  }

  /// Assembles the full silent decision API message list (Pipeline ①):
  ///
  /// 1. `system`: user decision prompt + JSON output rules (no times)
  /// 2. `user` (optional): persona reference prefix + assistant system prompt
  /// 3. `user` (optional): memories reference prefix + memory block
  /// 4. `user`: chat history header (when [history] is non-empty)
  /// 5. ...[history] (user/assistant turns, unchanged)
  /// 6. `user`: next care time + current system time (always last)
  static List<Map<String, dynamic>> buildDecisionApiMessages({
    required String decisionPrompt,
    required DateTime? currentNextCareTime,
    required DateTime now,
    required List<Map<String, dynamic>> history,
    String personaPrompt = '',
    String memoriesBlock = '',
  }) {
    final messages = <Map<String, dynamic>>[];

    final systemParts = <String>[
      if (decisionPrompt.trim().isNotEmpty) decisionPrompt.trim(),
      builtinDecisionJsonRules.trim(),
    ];
    messages.add({'role': 'system', 'content': systemParts.join('\n\n')});

    final persona = personaPrompt.trim();
    if (persona.isNotEmpty) {
      messages.add({
        'role': 'user',
        'content': '$personaReferencePrefix\n\n$persona',
      });
    }

    final memories = memoriesBlock.trim();
    if (memories.isNotEmpty) {
      messages.add({
        'role': 'user',
        'content': '$memoriesReferencePrefix\n\n$memories',
      });
    }

    if (history.isNotEmpty) {
      messages.add({'role': 'user', 'content': chatHistoryPrefix});
      messages.addAll(history);
    }

    messages.add({
      'role': 'user',
      'content': buildDecisionTimeFooter(
        now: now,
        currentNextCareTime: currentNextCareTime,
      ),
    });

    return messages;
  }

  /// Formats assistant memories the same way as the normal send pipeline's
  /// `<memories>` block, but without the memory tool instructions (the
  /// silent requests carry no tools). Returns an empty string when there are
  /// no memories.
  static String buildMemoriesBlock(List<AssistantMemory> mems) {
    if (mems.isEmpty) return '';
    final buf = StringBuffer();
    buf.writeln('## Memories');
    buf.writeln(
      'These are memories that you can reference in the future conversations.',
    );
    buf.writeln('<memories>');
    for (final m in mems) {
      buf.writeln('<record>');
      buf.writeln('<id>${m.id}</id>');
      buf.writeln('<content>${m.content}</content>');
      buf.writeln('</record>');
    }
    buf.writeln('</memories>');
    return buf.toString().trim();
  }

  /// Builds the silent user-role message sent when the proactive care time
  /// arrives: the user-configured care prompt plus the current system time.
  static String buildCareUserMessage({
    required String carePrompt,
    required DateTime now,
  }) {
    final time = builtinCareTimePrompt.replaceAll(
      '{current_system_time}',
      now.toIso8601String(),
    );
    final head = carePrompt.trim();
    if (head.isEmpty) return time;
    return '$head\n\n$time';
  }

  /// Parses the LLM decision reply.
  ///
  /// Returns the new next-care time only when `should_update` is true and
  /// `next_care_time` parses to a time later than [now] (mirroring the date
  /// picker constraint that past times are not allowed). Returns null in all
  /// other cases (invalid JSON, should_update=false, past/invalid time).
  static DateTime? parseDecision(String raw, {required DateTime now}) {
    final jsonText = _extractJsonObject(raw);
    if (jsonText == null) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;

    if (decoded['should_update'] != true) return null;
    final rawTime = decoded['next_care_time'];
    if (rawTime is! String || rawTime.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(rawTime.trim());
    if (parsed == null) return null;

    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    if (!local.isAfter(now)) return null;
    return local;
  }

  /// Extracts the first balanced top-level `{...}` block, tolerating
  /// markdown code fences and surrounding prose.
  static String? _extractJsonObject(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    return raw.substring(start, end + 1);
  }
}
