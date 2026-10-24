import 'dart:convert';

/// Deduplicate raw persisted tool events.
List<Map<String, dynamic>> dedupeToolEvents(List<Map<String, dynamic>> events) {
  final completedIds = <String>{
    for (final e in events)
      if ((e['id']?.toString() ?? '').trim().isNotEmpty &&
          hasCompletedToolContent(e['content']?.toString()))
        (e['id']?.toString() ?? '').trim(),
  };
  final completedNoIdBases = <String>{
    for (final e in events)
      if ((e['id']?.toString() ?? '').trim().isEmpty &&
          hasCompletedToolContent(e['content']?.toString()))
        toolEventBaseKey(
          e['name']?.toString() ?? '',
          (e['arguments'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
  };
  final indexByKey = <String, int>{};
  final out = <Map<String, dynamic>>[];
  for (final e in events) {
    final id = (e['id']?.toString() ?? '').trim();
    final name = (e['name']?.toString() ?? '');
    final args =
        ((e['arguments'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{});
    if (!hasCompletedToolContent(e['content']?.toString()) &&
        ((id.isNotEmpty && completedIds.contains(id)) ||
            (id.isEmpty &&
                completedNoIdBases.contains(toolEventBaseKey(name, args))))) {
      continue;
    }
    final key = toolEventIdentityKey(
      id: id,
      name: name,
      arguments: args,
      content: e['content']?.toString(),
    );
    final normalizedEvent = e.map((k, v) => MapEntry(k.toString(), v));
    final existingIndex = indexByKey[key];
    if (existingIndex != null) {
      if (id.isNotEmpty) out[existingIndex] = normalizedEvent;
      continue;
    }
    indexByKey[key] = out.length;
    out.add(normalizedEvent);
  }
  return out;
}

String toolEventBaseKey(String name, Map<String, dynamic> arguments) {
  return 'name:$name|args:${jsonEncode(arguments)}';
}

bool hasCompletedToolContent(String? content) =>
    content?.trim().isNotEmpty == true;

String toolEventIdentityKey({
  required String id,
  required String name,
  required Map<String, dynamic> arguments,
  String? content,
}) {
  final trimmedId = id.trim();
  if (trimmedId.isNotEmpty) return 'id:$trimmedId';

  final base = toolEventBaseKey(name, arguments);
  final trimmedContent = content?.trim();
  if (trimmedContent == null || trimmedContent.isEmpty) return base;
  return '$base|content:$trimmedContent';
}
