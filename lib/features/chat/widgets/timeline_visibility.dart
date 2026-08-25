import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../home/services/ask_user_interaction_service.dart';
import '../../home/services/local_tools_service.dart';
import 'screen_time_tool_ui.dart';

/// Built-in search is cited elsewhere and must not create a timeline card.
const String kBuiltinSearchToolName = 'builtin_search';

/// Scoped pending-approval identity. An empty [conversationId] is unscoped
/// and matches any conversation (same fail-safe as [ToolApprovalService]).
class PendingApprovalKey {
  const PendingApprovalKey({
    required this.conversationId,
    required this.toolCallId,
  });

  final String conversationId;
  final String toolCallId;

  bool matches({required String conversationId, required String toolCallId}) {
    if (this.toolCallId != toolCallId) return false;
    if (this.conversationId.isEmpty) return true;
    return this.conversationId == conversationId;
  }

  @override
  bool operator ==(Object other) =>
      other is PendingApprovalKey &&
      other.conversationId == conversationId &&
      other.toolCallId == toolCallId;

  @override
  int get hashCode => Object.hash(conversationId, toolCallId);
}

/// Extract markdown images from a tool result. Matches `![alt](url)` only.
(String, List<String>) parseToolResultImages(String? content) {
  if (content == null || content.isEmpty) return ('', const []);

  final images = <String>[];
  final buffer = StringBuffer();
  var i = 0;
  while (i < content.length) {
    if (content.startsWith('![', i)) {
      final altClose = content.indexOf('](', i + 2);
      if (altClose != -1) {
        final destStart = altClose + 2;
        var depth = 1;
        var j = destStart;
        while (j < content.length && depth > 0) {
          final ch = content.codeUnitAt(j);
          if (ch == 0x28) {
            depth += 1;
          } else if (ch == 0x29) {
            depth -= 1;
            if (depth == 0) break;
          }
          j += 1;
        }
        if (depth == 0 && j < content.length) {
          final path = content.substring(destStart, j).trim();
          if (path.isNotEmpty && path != 'generated') {
            images.add(path);
          }
          i = j + 1;
          continue;
        }
      }
    }
    buffer.writeCharCode(content.codeUnitAt(i));
    i += 1;
  }
  return (buffer.toString().trim(), images);
}

/// Whether [toolName] is allowed to occupy a chain-of-thought step.
bool toolCreatesTimelineCard(String toolName) =>
    toolName != kBuiltinSearchToolName;

/// Visibility used by both the renderer and the list extent estimate.
///
/// - [showToolCards] shows every real tool card
/// - ask-user is always visible so generation is not blocked
/// - a loading tool stays visible when it has a pending approval
bool isTimelineToolVisible({
  required String toolName,
  required bool loading,
  required bool showToolCards,
  required bool pendingApproval,
  bool filterBuiltinSearch = true,
}) {
  if (filterBuiltinSearch && !toolCreatesTimelineCard(toolName)) return false;
  if (showToolCards) return true;
  if (toolName == LocalToolNames.askUser) return true;
  return loading && pendingApproval;
}

/// Collapse a timeline block to the last two steps plus an expand row.
class CollapsedTimelineBlock<T> {
  const CollapsedTimelineBlock({
    required this.visibleSteps,
    required this.hiddenCount,
  });

  final List<T> visibleSteps;
  final int hiddenCount;

  bool get hasExpandRow => hiddenCount > 0;
}

CollapsedTimelineBlock<T> collapseTimelineSteps<T>(
  List<T> steps, {
  required bool collapseThinkingSteps,
}) {
  if (!collapseThinkingSteps || steps.length <= 2) {
    return CollapsedTimelineBlock<T>(
      visibleSteps: List<T>.of(steps),
      hiddenCount: 0,
    );
  }
  final hiddenCount = steps.length - 2;
  return CollapsedTimelineBlock<T>(
    visibleSteps: steps.sublist(hiddenCount),
    hiddenCount: hiddenCount,
  );
}

/// Split tools into per-card blocks using cumulative [toolCounts] from content
/// splits. Each block collapses independently.
List<List<T>> splitToolsIntoTimelineBlocks<T>(
  List<T> tools, {
  List<int>? toolCounts,
}) {
  if (tools.isEmpty) return const [];
  if (toolCounts == null || toolCounts.isEmpty) {
    return <List<T>>[List<T>.of(tools)];
  }

  final blocks = <List<T>>[];
  var start = 0;
  for (final count in toolCounts) {
    final end = count.clamp(0, tools.length);
    if (end > start) {
      blocks.add(tools.sublist(start, end));
      start = end;
    }
  }
  if (start < tools.length) {
    blocks.add(tools.sublist(start));
  }
  return blocks.isEmpty ? <List<T>>[List<T>.of(tools)] : blocks;
}

/// Extra height under a collapsed tool header. Not gated on the normal
/// four-line summary flag — ask-user, TTS, Screen Time, images, and pending
/// approval each have their own structure.
double estimateToolExtraHeight({
  required String toolName,
  required Map<String, dynamic> arguments,
  required String? content,
  required bool showToolResultSummary,
  required bool hideToolResultImages,
  required bool pendingApproval,
  required double textWidth,
  required double fontScale,
  required double Function(
    String text, {
    required double charsPerLine,
    required double? codeCharsPerLine,
    required double codeLineRatio,
    required int? collapsedCodeLines,
  })
  wrappedLineCount,
}) {
  if (toolName == LocalToolNames.askUser) {
    return _estimateAskUserExtra(
      arguments,
      content: content,
      textWidth: textWidth,
      fontScale: fontScale,
      wrappedLineCount: wrappedLineCount,
    );
  }

  final ttsText = toolName == LocalToolNames.textToSpeech
      ? (arguments['text'] ?? '').toString().trim()
      : '';
  if (ttsText.isNotEmpty) {
    return _estimateTtsReplayRowHeight * fontScale.clamp(0.85, 1.4);
  }

  final (cleanText, imagePaths) = parseToolResultImages(content);
  if (toolName == LocalToolNames.screenTime) {
    final screenTime = ScreenTimeResult.tryParse(cleanText);
    if (screenTime != null &&
        (screenTime.isNoPermission || screenTime.hasApps)) {
      return _estimateScreenTimeExtra(screenTime, fontScale);
    }
  }

  var extra = 0.0;
  final summaryFontSize = 12.0 * fontScale;
  final summaryLineHeight = summaryFontSize * 1.4;
  var hasSummary = false;

  if (pendingApproval) {
    extra += _estimatePendingApprovalExtra(
      arguments,
      showToolResultSummary: showToolResultSummary,
      textWidth: textWidth,
      fontScale: fontScale,
      wrappedLineCount: wrappedLineCount,
    );
    hasSummary = showToolResultSummary;
  } else if (showToolResultSummary) {
    final summary = cleanText.trim();
    if (summary.isNotEmpty) {
      final charWidth = summaryFontSize * 0.55;
      final charsPerLine = (textWidth / charWidth).clamp(8.0, 80.0);
      final lines = wrappedLineCount(
        summary,
        charsPerLine: charsPerLine,
        codeCharsPerLine: null,
        codeLineRatio: 1.0,
        collapsedCodeLines: null,
      ).clamp(0.0, 4.0);
      extra += lines * summaryLineHeight;
      hasSummary = lines > 0;
    }
  }

  if (!hideToolResultImages && imagePaths.isNotEmpty) {
    extra += _estimateToolImageHeight;
    if (hasSummary) extra += _estimateToolImageSummaryGap;
  }

  return extra;
}

const double _estimateTtsReplayRowHeight = 36;
const double _estimateToolImageHeight = 120;
const double _estimateToolImageSummaryGap = 8;
const double _estimateAskUserOptionHeight = 40;
const double _estimateAskUserOptionGap = 7;
const double _estimateAskUserOtherHeight = 40;
const double _estimateAskUserSubmitHeight = 38;
const double _estimateAskUserAnsweredGap = 3;
const double _estimateAskUserAnsweredPad = 4;

/// Matches [_AskUserOptionRow]: 13px / 1.25, max 3 lines, minHeight 40.
double _estimateAskUserOptionRowHeight(
  String label, {
  required double textWidth,
  required double fontScale,
}) {
  final fontSize = 13.0 * fontScale;
  final optionTextWidth = math.max(40.0, textWidth - 28 - 44);
  final textHeight = _askUserLayoutHeight(
    label,
    fontSize: fontSize,
    height: 1.25,
    maxWidth: optionTextWidth,
    maxLines: 3,
    fontWeight: FontWeight.w500,
  );
  return math.max(
    _estimateAskUserOptionHeight * fontScale,
    textHeight + 16 * fontScale,
  );
}

double _askUserLayoutHeight(
  String text, {
  required double fontSize,
  required double height,
  required double maxWidth,
  int? maxLines,
  FontWeight? fontWeight,
}) {
  if (text.trim().isEmpty) return fontSize * height;
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        height: height,
        fontWeight: fontWeight,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : '…',
  )..layout(maxWidth: math.max(1.0, maxWidth));
  try {
    return math.max(fontSize * height, painter.height);
  } finally {
    painter.dispose();
  }
}

double _estimateAskUserExtra(
  Map<String, dynamic> arguments, {
  required String? content,
  required double textWidth,
  required double fontScale,
  required double Function(
    String text, {
    required double charsPerLine,
    required double? codeCharsPerLine,
    required double codeLineRatio,
    required int? collapsedCodeLines,
  })
  wrappedLineCount,
}) {
  final questions = AskUserInteractionService.normalizeQuestions(arguments);
  if (questions.isEmpty) return 20 * fontScale;
  final answeredContent = content;
  if (answeredContent != null && answeredContent.trim().isNotEmpty) {
    return _estimateAskUserAnsweredExtra(
      questions,
      answeredContent,
      textWidth: textWidth,
      fontScale: fontScale,
    );
  }
  final fontSize = 13.0 * fontScale;
  // Card padding (16+12) plus the Skip pill on the question row.
  final questionWidth = math.max(80.0, textWidth - 40 - 28 - 56);
  var extra = 0.0;
  for (final question in questions) {
    extra += _askUserLayoutHeight(
      question.question,
      fontSize: fontSize,
      height: 1.35,
      maxWidth: questionWidth,
    );
    extra += 8;
    for (final option in question.options) {
      extra += _estimateAskUserOptionRowHeight(
        option,
        textWidth: textWidth,
        fontScale: fontScale,
      );
      extra += _estimateAskUserOptionGap * fontScale;
    }
    extra += _estimateAskUserOtherHeight * fontScale;
    extra += 12;
  }
  extra += _estimateAskUserSubmitHeight * fontScale;
  return extra;
}

double _estimateAskUserAnsweredExtra(
  List<AskUserQuestion> questions,
  String content, {
  required double textWidth,
  required double fontScale,
}) {
  final questionFontSize = 12.5 * fontScale;
  final answerFontSize = 13.0 * fontScale;
  // Card padding (16+12) plus leftover message inset not in [textWidth].
  final innerWidth = math.max(80.0, textWidth - 40);
  final answers = _askUserAnsweredValues(content);
  var extra = 8.0;
  for (var i = 0; i < questions.length; i++) {
    final question = questions[i];
    extra += _askUserLayoutHeight(
      question.question,
      fontSize: questionFontSize,
      height: 1.35,
      maxWidth: innerWidth,
      fontWeight: FontWeight.w600,
    );
    extra += _estimateAskUserAnsweredGap;
    extra += _askUserLayoutHeight(
      _askUserAnswerSummary(question.id, answers),
      fontSize: answerFontSize,
      height: 1.35,
      maxWidth: innerWidth,
      fontWeight: FontWeight.w600,
    );
    extra += _estimateAskUserAnsweredPad;
    if (i != questions.length - 1) extra += 10;
  }
  return extra;
}

Map<dynamic, dynamic> _askUserAnsweredValues(String content) {
  try {
    final payload = jsonDecode(content);
    if (payload is Map) {
      final answers = payload['answers'];
      if (answers is Map) return answers;
    }
  } catch (_) {}
  return const <dynamic, dynamic>{};
}

String _askUserAnswerSummary(String questionId, Map<dynamic, dynamic> answers) {
  final raw = answers[questionId];
  if (raw is! Map) return ' ';
  if (raw['skipped'] == true) return 'Skipped';
  final value = raw['value'];
  if (value is List) {
    final joined = value.map((item) => item.toString()).join(', ');
    return joined.isEmpty ? ' ' : joined;
  }
  final text = value?.toString() ?? '';
  return text.isEmpty ? ' ' : text;
}

double _estimateScreenTimeExtra(ScreenTimeResult result, double fontScale) {
  final line = 16.0 * fontScale;
  if (result.isNoPermission) return line;
  final apps = result.apps.length.clamp(0, 3);
  return line + apps * (line + 2);
}

double _estimatePendingApprovalExtra(
  Map<String, dynamic> arguments, {
  required bool showToolResultSummary,
  required double textWidth,
  required double fontScale,
  required double Function(
    String text, {
    required double charsPerLine,
    required double? codeCharsPerLine,
    required double codeLineRatio,
    required int? collapsedCodeLines,
  })
  wrappedLineCount,
}) {
  // Approve/deny sit in the header row — they add no extra vertical height.
  if (!showToolResultSummary) return 0;
  final entries = arguments.entries.take(2).map((e) {
    final v = e.value?.toString() ?? '';
    final truncated = v.length > 40 ? '${v.substring(0, 40)}...' : v;
    return '${e.key}: $truncated';
  });
  final summary = entries.join(', ');
  if (summary.isEmpty) return 0;
  final fontSize = 12.0 * fontScale;
  final charWidth = fontSize * 0.55;
  final charsPerLine = (textWidth / charWidth).clamp(8.0, 80.0);
  final lines = wrappedLineCount(
    summary,
    charsPerLine: charsPerLine,
    codeCharsPerLine: null,
    codeLineRatio: 1.0,
    collapsedCodeLines: null,
  ).clamp(0.0, 2.0);
  return lines * (fontSize * 1.4);
}
