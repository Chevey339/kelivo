import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Represents a configurable action for the selection action bar.
/// Each action can run a custom script when triggered.
class SelectionAction {
  final String id;
  final String name;
  final String iconName;
  final String scriptPath;
  final bool enabled;

  const SelectionAction({
    required this.id,
    required this.name,
    required this.iconName,
    required this.scriptPath,
    this.enabled = true,
  });

  /// Create a new action with a generated UUID
  factory SelectionAction.create({
    required String name,
    required String iconName,
    required String scriptPath,
    bool enabled = true,
  }) {
    return SelectionAction(
      id: const Uuid().v4(),
      name: name,
      iconName: iconName,
      scriptPath: scriptPath,
      enabled: enabled,
    );
  }

  SelectionAction copyWith({
    String? name,
    String? iconName,
    String? scriptPath,
    bool? enabled,
  }) {
    return SelectionAction(
      id: id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      scriptPath: scriptPath ?? this.scriptPath,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'scriptPath': scriptPath,
      'enabled': enabled,
    };
  }

  factory SelectionAction.fromJson(Map<String, dynamic> json) {
    return SelectionAction(
      id: json['id'] as String,
      name: json['name'] as String,
      iconName: json['iconName'] as String,
      scriptPath: json['scriptPath'] as String,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  static List<SelectionAction> listFromJson(String jsonString) {
    if (jsonString.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => SelectionAction.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  static String listToJson(List<SelectionAction> actions) {
    return jsonEncode(actions.map((a) => a.toJson()).toList());
  }

  /// Available icons for selection actions
  static const List<String> availableIcons = [
    'volume2',      // TTS/Audio
    'languages',    // Translate
    'search',       // Search
    'sparkles',     // AI/Magic
    'brain',        // AI/Think
    'terminal',     // Command
    'code',         // Code
    'fileText',     // Document
    'link',         // Link
    'share',        // Share
    'bookmark',     // Save
    'zap',          // Quick action
    'wand',         // Magic wand
    'bot',          // Bot/AI
    'messageCircle', // Chat
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectionAction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
