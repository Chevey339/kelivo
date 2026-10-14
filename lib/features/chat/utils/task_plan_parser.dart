import 'package:uuid/uuid.dart';
import '../../../core/models/task_execution_binding.dart';

/// Parses a Markdown plan specification (typically from `<proposed_plan>`)
/// into a structured [TaskExecutionPlan] with individual [TaskStep]s.
class TaskPlanParser {
  static final RegExp _headingRegex =
      RegExp(r'^\s*#{1,3}\s+(.+)$', multiLine: true);
  static final RegExp _checklistRegex =
      RegExp(r'^\s*(?:[-*]|\d+\.)\s+\[([ xX/])\]\s+(.+)$', multiLine: true);
  static final RegExp _numberedItemRegex =
      RegExp(r'^\s*\d+\.\s+([^\[\n].+)$', multiLine: true);

  /// Target section header keywords that introduce execution steps.
  static final List<String> _implementationKeywords = [
    '落地实施步骤',
    '实施步骤',
    '实现步骤',
    '执行步骤',
    'key changes',
    'implementation changes',
    'implementation steps',
    'tasks',
    'steps',
  ];

  static TaskExecutionPlan parse(String markdown, {String? planId}) {
    final lines = markdown.split('\n');

    // 1. Extract title
    String title = '落地执行计划';
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#')) {
        final headingMatch = _headingRegex.firstMatch(trimmed);
        if (headingMatch != null) {
          final t = headingMatch.group(1)?.trim();
          if (t != null && t.isNotEmpty) {
            title = _cleanMarkdownFormatting(t);
            break;
          }
        }
      }
    }

    final steps = <TaskStep>[];

    // 2. Try extracting checklist items anywhere in the document
    final checklistMatches = _checklistRegex.allMatches(markdown);
    if (checklistMatches.isNotEmpty) {
      int idx = 1;
      for (final match in checklistMatches) {
        final checkChar = match.group(1) ?? ' ';
        final text = match.group(2)?.trim() ?? '';
        if (text.isEmpty) continue;
        final isChecked = checkChar.toLowerCase() == 'x';
        steps.add(
          TaskStep(
            id: 'step_$idx',
            title: _cleanMarkdownFormatting(text),
            status: isChecked ? TaskStepStatus.completed : TaskStepStatus.pending,
          ),
        );
        idx++;
      }
    }

    // 3. If no checklist items found, look within implementation section
    if (steps.isEmpty) {
      final sectionLines = _extractSectionLines(lines, _implementationKeywords);
      final sectionText = sectionLines.join('\n');

      // Look for numbered items in this section
      final numberedMatches = _numberedItemRegex.allMatches(sectionText);
      if (numberedMatches.isNotEmpty) {
        int idx = 1;
        for (final match in numberedMatches) {
          final text = match.group(1)?.trim() ?? '';
          if (text.isEmpty) continue;
          steps.add(
            TaskStep(
              id: 'step_$idx',
              title: _cleanMarkdownFormatting(text),
              status: TaskStepStatus.pending,
            ),
          );
          idx++;
        }
      } else {
        // Look for bullet items
        int idx = 1;
        for (final line in sectionLines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
            final text = trimmed.substring(2).trim();
            if (text.isNotEmpty) {
              steps.add(
                TaskStep(
                  id: 'step_$idx',
                  title: _cleanMarkdownFormatting(text),
                  status: TaskStepStatus.pending,
                ),
              );
              idx++;
            }
          }
        }
      }
    }

    // 4. Fallback: all top-level numbered items in the document
    if (steps.isEmpty) {
      final allNumbered = _numberedItemRegex.allMatches(markdown);
      int idx = 1;
      for (final match in allNumbered) {
        final text = match.group(1)?.trim() ?? '';
        if (text.isEmpty) continue;
        steps.add(
          TaskStep(
            id: 'step_$idx',
            title: _cleanMarkdownFormatting(text),
            status: TaskStepStatus.pending,
          ),
        );
        idx++;
      }
    }

    // 5. Ultimate fallback if nothing parsed
    if (steps.isEmpty) {
      steps.add(
        TaskStep(
          id: 'step_1',
          title: title,
          status: TaskStepStatus.pending,
        ),
      );
    }

    return TaskExecutionPlan(
      id: planId ?? const Uuid().v4(),
      title: title,
      steps: steps,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static List<String> _extractSectionLines(
    List<String> allLines,
    List<String> keywords,
  ) {
    bool inTargetSection = false;
    final result = <String>[];

    for (final line in allLines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('## ') || trimmed.startsWith('### ')) {
        final lower = trimmed.toLowerCase();
        final matchesKeyword = keywords.any((k) => lower.contains(k));
        if (matchesKeyword) {
          inTargetSection = true;
          continue;
        } else if (inTargetSection) {
          // Reached the next section
          break;
        }
      }
      if (inTargetSection) {
        result.add(line);
      }
    }

    return result;
  }

  static String _cleanMarkdownFormatting(String text) {
    var cleaned = text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    return cleaned.trim();
  }
}
