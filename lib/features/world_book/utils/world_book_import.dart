import 'package:uuid/uuid.dart';

import '../../../core/models/world_book.dart';

class WorldBookImportResult {
  const WorldBookImportResult(this.book, {this.unsupportedEntryCount = 0});

  final WorldBook book;
  final int unsupportedEntryCount;
}

/// Reads Kelivo/RikkaHub exports and SillyTavern's standalone World Info JSON.
/// Unsupported SillyTavern rules must not silently broaden entry activation.
/// Format: https://github.com/SillyTavern/SillyTavern/blob/release/public/scripts/world-info.js
WorldBookImportResult? parseWorldBookImport(
  Object? decoded, {
  required String fileName,
}) {
  try {
    if (decoded is! Map) return null;
    var json = decoded.cast<String, dynamic>();
    if (json['data'] is Map) {
      json = (json['data'] as Map).cast<String, dynamic>();
    }
    final entries = json['entries'];
    if (entries is List) {
      if (entries.any((entry) => entry is! Map)) return null;
      return WorldBookImportResult(WorldBook.fromJson(json));
    }
    if (entries is! Map) return null;

    // ST enumerates integer object keys first, then reverses equal-order entries
    // when assembling the prompt. displayIndex only controls its editor list.
    final sourceKeys = entries.keys.cast<String>().toList();
    final sourceOrder = {
      for (var i = 0; i < sourceKeys.length; i++) sourceKeys[i]: i,
    };
    sourceKeys.sort((a, b) {
      final aIndex = _arrayIndex(a);
      final bIndex = _arrayIndex(b);
      if (aIndex != null && bIndex != null) return aIndex.compareTo(bIndex);
      if (aIndex != null) return -1;
      if (bIndex != null) return 1;
      return sourceOrder[a]!.compareTo(sourceOrder[b]!);
    });
    final imported = <WorldBookEntry>[];
    final depthRoles = <int, Set<int>>{};
    for (final value in entries.values) {
      if (value is! Map) return null;
      if (value['position'] == 4 && value['disable'] != true) {
        final role = value['role'] as int? ?? 0;
        if (role == 1 || role == 2) {
          depthRoles
              .putIfAbsent(value['depth'] as int? ?? 4, () => <int>{})
              .add(role);
        }
      }
    }
    var unsupportedEntryCount = 0;
    for (final key in sourceKeys.reversed) {
      if (entries[key] is! Map) return null;
      final entry = (entries[key] as Map).cast<String, dynamic>();
      if (entry['content'] is! String || entry['key'] is! List) return null;
      final keys = (entry['key'] as List).cast<String>();
      final constant = entry['constant'] as bool? ?? false;
      final position = entry['position'] as int? ?? 0;
      final role = entry['role'] as int? ?? 0;
      final depth = entry['depth'] as int? ?? 4;
      // Global scan settings are not included in standalone exports. Use ST's
      // default when an entry inherits its scan depth/case sensitivity.
      final scanDepth = entry['scanDepth'] as int? ?? 2;
      final unsupported =
          !const [0, 1, 4].contains(position) ||
          // Inline system roles lose their depth in Claude/Gemini/Responses.
          // Keep them disabled rather than silently moving them into the prompt.
          (position == 4 &&
              (!const [1, 2].contains(role) ||
                  depth < 0 ||
                  depth > 200 ||
                  // A trailing assistant message is an unsupported prefill
                  // for some providers, including current Claude models.
                  (role == 2 && depth == 0) ||
                  // ST uses a fixed role order at each depth; Kelivo groups by
                  // priority. Mixed roles require manual review as well.
                  (depthRoles[depth]?.length ?? 0) > 1)) ||
          (!constant &&
              (keys.any(_hasUnsupportedKeyword) ||
                  scanDepth < 1 ||
                  scanDepth > 200)) ||
          _hasUnsupportedRules(entry, constant: constant);
      if (unsupported) unsupportedEntryCount++;
      final comment = entry['comment'] as String? ?? '';
      final converted = WorldBookEntry(
        id: (entry['uid'] ?? key).toString(),
        name: comment.isNotEmpty ? comment : keys.firstOrNull ?? '',
        enabled: !(entry['disable'] as bool? ?? false) && !unsupported,
        // ST inserts larger orders later; Kelivo inserts higher priorities first.
        priority: -(entry['order'] as int? ?? 100),
        position: switch (position) {
          0 => WorldBookInjectionPosition.beforeSystemPrompt,
          4 => WorldBookInjectionPosition.atDepth,
          _ => WorldBookInjectionPosition.afterSystemPrompt,
        },
        content: entry['content'] as String,
        injectDepth: depth.clamp(0, 200),
        role: role == 2
            ? WorldBookInjectionRole.assistant
            : WorldBookInjectionRole.user,
        keywords: keys,
        caseSensitive: entry['caseSensitive'] as bool? ?? false,
        scanDepth: scanDepth.clamp(1, 200),
        constantActive: constant,
        sticky: (entry['sticky'] as int? ?? 0).clamp(0, 10000),
        cooldown: (entry['cooldown'] as int? ?? 0).clamp(0, 10000),
        delay: (entry['delay'] as int? ?? 0).clamp(0, 10000),
      );
      imported.add(converted);
    }
    final name = json['name'] as String? ?? '';
    return WorldBookImportResult(
      WorldBook(
        id: '',
        name: name.trim().isNotEmpty
            ? name
            : fileName
                  .replaceAll('\\', '/')
                  .split('/')
                  .last
                  .replaceFirst(RegExp(r'\.json$', caseSensitive: false), ''),
        description: json['description'] as String? ?? '',
        entries: imported,
      ),
      unsupportedEntryCount: unsupportedEntryCount,
    );
  } on TypeError {
    return null;
  } on FormatException {
    return null;
  }
}

int? _arrayIndex(String key) {
  final value = int.tryParse(key);
  return value != null &&
          value >= 0 &&
          value < 0xffffffff &&
          value.toString() == key
      ? value
      : null;
}

bool _hasMacro(String text) => RegExp(
  r'\{\{[\s\S]*?\}\}|<(?:user|bot|char|charifnotgroup|group)>',
  caseSensitive: false,
).hasMatch(text);

bool _hasUnsupportedRules(
  Map<String, dynamic> entry, {
  required bool constant,
}) {
  final content = entry['content'] as String;
  if (content.startsWith('@@') || _hasMacro(content)) {
    return true;
  }
  // ST expires timed effects at a different boundary and starts cooldown when
  // sticky expiration is observed. Copying the numbers would change activation.
  if ((entry['sticky'] as int? ?? 0) != 0 ||
      (entry['cooldown'] as int? ?? 0) != 0 ||
      (entry['delay'] as int? ?? 0) > 10000) {
    return true;
  }
  if (!constant &&
      (entry['selective'] as bool? ?? true) &&
      ((entry['keysecondary'] as List?)?.isNotEmpty ?? false)) {
    return true;
  }
  if ((entry['useProbability'] as bool? ?? true) &&
      (entry['probability'] as num? ?? 100) != 100) {
    return true;
  }
  if ((entry['group'] as String? ?? '').trim().isNotEmpty ||
      (entry['automationId'] as String? ?? '').trim().isNotEmpty ||
      ((entry['triggers'] as List?)?.isNotEmpty ?? false)) {
    return true;
  }
  final recursionDelay = entry['delayUntilRecursion'];
  if (recursionDelay == true || (recursionDelay is num && recursionDelay > 0)) {
    return true;
  }
  final filter = entry['characterFilter'];
  if (filter is Map &&
      [
        filter['names'],
        filter['tags'],
      ].any((value) => value is List && value.isNotEmpty)) {
    return true;
  }
  return !constant &&
      const [
        'vectorized',
        'matchWholeWords',
        'matchPersonaDescription',
        'matchCharacterDescription',
        'matchCharacterPersonality',
        'matchCharacterDepthPrompt',
        'matchScenario',
        'matchCreatorNotes',
      ].any((field) => entry[field] == true);
}

bool _hasUnsupportedKeyword(String raw) {
  if (_hasMacro(raw) || RegExp(r'[\r\n\x01]').hasMatch(raw)) return true;
  final match = RegExp(r'^/([\s\S]+?)/([gimsuy]*)$').firstMatch(raw.trim());
  if (match == null) return false;
  final pattern = match.group(1)!;
  final flags = match.group(2)!;
  if (RegExp(r'(^|[^\\])/').hasMatch(pattern) ||
      flags.split('').toSet().length != flags.length) {
    return false;
  }
  try {
    RegExp(
      pattern,
      multiLine: flags.contains('m'),
      dotAll: flags.contains('s'),
      unicode: flags.contains('u'),
    );
    // ST scans newest-first with message separators. Even regexes supported by
    // Dart can match differently; retain the original key for manual review.
    return true;
  } on FormatException {
    // Like ST, invalid slash expressions remain literal keywords.
    return false;
  }
}

WorldBook normalizeImportedWorldBook(
  WorldBook book, {
  required Set<String> existingBookIds,
}) {
  var bookId = book.id.trim();
  if (bookId.isEmpty || existingBookIds.contains(bookId)) {
    bookId = const Uuid().v4();
  }
  final seenEntryIds = <String>{};
  final entries = <WorldBookEntry>[];
  for (final entry in book.entries) {
    var id = entry.id.trim();
    if (id.isEmpty || seenEntryIds.contains(id)) id = const Uuid().v4();
    seenEntryIds.add(id);
    entries.add(entry.copyWith(id: id));
  }
  return book.copyWith(id: bookId, entries: entries);
}
