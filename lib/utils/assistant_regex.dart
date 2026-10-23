import 'protected_text.dart';
import '../core/models/assistant.dart';
import '../core/models/assistant_regex.dart';

final Map<String, RegExp?> _compiledPatternCache = <String, RegExp?>{};
const int _maxCompiledPatternCacheSize = 256;

enum AssistantRegexTransformTarget {
  /// Persist-time transform. Changes stored content.
  persist,

  /// Visual-only transform. Only affects what is rendered.
  visual,

  /// Send-time transform. Only affects content sent to the model.
  send,
}

String applyAssistantRegexes(
  String input, {
  required Assistant? assistant,
  required AssistantRegexScope scope,
  required AssistantRegexTransformTarget target,
}) {
  if (input.isEmpty) return input;
  if (assistant == null) return input;
  if (assistant.regexRules.isEmpty) return input;

  var out = input;
  for (final (regex, replacement) in _activeRules(assistant, scope, target)) {
    out = out.replaceAllMapped(
      regex,
      (match) => _expandReplacement(replacement, match),
    );
  }
  return out;
}

ProtectedText applyAssistantRegexesProtected(
  ProtectedText input, {
  required Assistant? assistant,
  required AssistantRegexScope scope,
  required AssistantRegexTransformTarget target,
}) {
  if (input.text.isEmpty || assistant == null || assistant.regexRules.isEmpty) {
    return input;
  }
  var out = input;
  for (final (regex, replacement) in _activeRules(assistant, scope, target)) {
    out = out.replaceAllMapped(
      regex,
      (match) => _expandReplacement(replacement, match),
    );
  }
  return out;
}

Iterable<(RegExp, String)> _activeRules(
  Assistant assistant,
  AssistantRegexScope scope,
  AssistantRegexTransformTarget target,
) sync* {
  for (final rule in assistant.regexRules) {
    if (!rule.enabled) continue;
    if (!rule.scopes.contains(scope)) continue;
    if (rule.visualOnly) {
      if (target != AssistantRegexTransformTarget.visual) continue;
    } else if (rule.replaceOnly) {
      if (target != AssistantRegexTransformTarget.send) continue;
    } else {
      if (target != AssistantRegexTransformTarget.persist) continue;
    }
    final pattern = rule.pattern.trim();
    if (pattern.isEmpty) continue;
    if (!_compiledPatternCache.containsKey(pattern) &&
        _compiledPatternCache.length >= _maxCompiledPatternCacheSize) {
      _compiledPatternCache.clear();
    }
    final regex = _compiledPatternCache.putIfAbsent(pattern, () {
      try {
        return RegExp(pattern);
      } catch (_) {
        return null;
      }
    });
    if (regex == null) continue;
    yield (regex, rule.replacement);
  }
}

/// Expands replacement string with capture group references ($0, $1, $2, etc.)
String _expandReplacement(String replacement, Match match) {
  // Pattern to match $0, $1, $2, ... $99
  final refPattern = RegExp(r'\$(\d{1,2})');
  return replacement.replaceAllMapped(refPattern, (m) {
    final groupIndex = int.parse(m.group(1)!);
    if (groupIndex <= match.groupCount) {
      return match.group(groupIndex) ?? '';
    }
    // Return original reference if group doesn't exist
    return m.group(0)!;
  });
}
