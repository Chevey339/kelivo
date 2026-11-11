import 'package:flutter/foundation.dart';

enum AvatarType { emoji, url, file, icon, lobehub }

/// Display-only avatar settings, independent of model API capabilities.
@immutable
class AvatarConfig {
  const AvatarConfig({
    required this.type,
    required this.value,
    this.monochrome = false,
  });

  final AvatarType type;
  final String value;
  final bool monochrome;

  static AvatarConfig? fromJson(Object? json) {
    if (json is! Map) return null;
    final type = AvatarType.values
        .where((t) => t.name == json['type'])
        .firstOrNull;
    final value = json['value'];
    if (type == null || value is! String || value.trim().isEmpty) return null;
    return AvatarConfig(
      type: type,
      value: value.trim(),
      monochrome: json['monochrome'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'value': value,
    if (monochrome) 'monochrome': true,
  };

  @override
  bool operator ==(Object other) =>
      other is AvatarConfig &&
      type == other.type &&
      value == other.value &&
      monochrome == other.monochrome;

  @override
  int get hashCode => Object.hash(type, value, monochrome);
}
