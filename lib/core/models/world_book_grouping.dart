import 'dart:convert';

final class WorldBookGrouping {
  const WorldBookGrouping({this.names = const {}, this.memberships = const {}});

  static const preferenceKey = 'world_books_grouping_v1';

  final Map<String, String> names;
  final Map<String, String> memberships;

  factory WorldBookGrouping.decode(Object? raw) {
    if (raw is! String) return const WorldBookGrouping();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const WorldBookGrouping();
      final names = _stringMap(decoded['names']);
      final memberships = _stringMap(decoded['memberships'])
        ..removeWhere((_, groupId) => !names.containsKey(groupId));
      return WorldBookGrouping(names: names, memberships: memberships);
    } on FormatException {
      return const WorldBookGrouping();
    }
  }

  static Map<String, String> _stringMap(Object? value) => {
    if (value is Map)
      for (final entry in value.entries)
        if (entry.key is String &&
            (entry.key as String).isNotEmpty &&
            entry.value is String &&
            (entry.value as String).trim().isNotEmpty)
          entry.key as String: entry.value as String,
  };

  String encode() => jsonEncode({'names': names, 'memberships': memberships});
}
