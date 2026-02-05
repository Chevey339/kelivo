import 'dart:convert';

class ProviderGroup {
  final String id;
  final String name;
  final int createdAt;

  const ProviderGroup({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  ProviderGroup copyWith({String? id, String? name, int? createdAt}) => ProviderGroup(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt,
      };

  static ProviderGroup fromJson(Map<String, dynamic> json) => ProviderGroup(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        createdAt: (json['createdAt'] is num)
            ? (json['createdAt'] as num).toInt()
            : int.tryParse((json['createdAt'] ?? '0').toString()) ?? 0,
      );

  static String encodeList(List<ProviderGroup> list) => jsonEncode(list.map((e) => e.toJson()).toList());
  static List<ProviderGroup> decodeList(String raw) {
    try {
      final arr = jsonDecode(raw) as List<dynamic>;
      return [for (final e in arr) ProviderGroup.fromJson(e as Map<String, dynamic>)];
    } catch (_) {
      return const <ProviderGroup>[];
    }
  }
}

