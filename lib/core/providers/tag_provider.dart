import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../database/business_preferences.dart';
import '../models/assistant_tag.dart';

/// Manages assistant group tags, assignments, order and collapse state.
class TagProvider extends ChangeNotifier {
  static const String _tagsKey = 'assistant_tags_v1';
  static const String _assignKey =
      'assistant_tag_map_v1'; // assistantId -> tagId
  static const String _collapsedKey =
      'assistant_tag_collapsed_v1'; // tagId -> bool

  final BusinessPreferences preferences;
  final List<AssistantTag> _tags = <AssistantTag>[];
  final Map<String, String> _assignment = <String, String>{};
  final Map<String, bool> _collapsed = <String, bool>{};

  List<AssistantTag> get tags => List.unmodifiable(_tags);
  Map<String, String> get assignment => Map.unmodifiable(_assignment);
  bool isCollapsed(String tagId) => _collapsed[tagId] ?? false;

  TagProvider({required this.preferences}) {
    _load();
  }

  Future<void> _load() async {
    await preferences.load();
    final rawTags = preferences.getString(_tagsKey);
    if (rawTags != null && rawTags.isNotEmpty) {
      _tags
        ..clear()
        ..addAll(AssistantTag.decodeList(rawTags));
    }
    final rawMap = preferences.getString(_assignKey);
    if (rawMap != null && rawMap.isNotEmpty) {
      try {
        final m = jsonDecode(rawMap) as Map<String, dynamic>;
        _assignment
          ..clear()
          ..addAll(m.map((k, v) => MapEntry(k, v.toString())));
      } catch (_) {}
    }
    final rawCol = preferences.getString(_collapsedKey);
    if (rawCol != null && rawCol.isNotEmpty) {
      try {
        final m = jsonDecode(rawCol) as Map<String, dynamic>;
        _collapsed
          ..clear()
          ..addAll(
            m.map(
              (k, v) => MapEntry(k, (v is bool) ? v : (v.toString() == 'true')),
            ),
          );
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _persistTags() async {
    await preferences.setString(_tagsKey, AssistantTag.encodeList(_tags));
  }

  Future<void> _persistAssignment() async {
    await preferences.setString(_assignKey, jsonEncode(_assignment));
  }

  Future<void> _persistCollapsed() async {
    await preferences.setString(_collapsedKey, jsonEncode(_collapsed));
  }

  String? tagOfAssistant(String assistantId) => _assignment[assistantId];

  Future<String> createTag(String name) async {
    final id = const Uuid().v4();
    _tags.add(AssistantTag(id: id, name: name.trim()));
    await _persistTags();
    notifyListeners();
    return id;
  }

  Future<void> renameTag(String tagId, String name) async {
    final idx = _tags.indexWhere((t) => t.id == tagId);
    if (idx == -1) return;
    _tags[idx] = _tags[idx].copyWith(name: name.trim());
    await _persistTags();
    notifyListeners();
  }

  Future<void> deleteTag(String tagId) async {
    final idx = _tags.indexWhere((t) => t.id == tagId);
    if (idx == -1) return;
    _tags.removeAt(idx);
    _collapsed.remove(tagId);
    // Unassign assistants with this tag
    _assignment.removeWhere((_, v) => v == tagId);
    await _persistTags();
    await _persistAssignment();
    await _persistCollapsed();
    notifyListeners();
  }

  Future<void> reorderTags(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _tags.length) return;
    if (newIndex < 0 || newIndex >= _tags.length) return;
    final t = _tags.removeAt(oldIndex);
    _tags.insert(newIndex, t);
    notifyListeners();
    await _persistTags();
  }

  Future<void> assignAssistantToTag(String assistantId, String? tagId) async {
    if (tagId == null || tagId.isEmpty) {
      _assignment.remove(assistantId);
    } else {
      _assignment[assistantId] = tagId;
    }
    notifyListeners();
    await _persistAssignment();
  }

  Future<void> unassignAssistant(String assistantId) async {
    if (_assignment.containsKey(assistantId)) {
      _assignment.remove(assistantId);
      notifyListeners();
      await _persistAssignment();
    }
  }

  Future<void> setCollapsed(String tagId, bool value) async {
    _collapsed[tagId] = value;
    notifyListeners();
    await _persistCollapsed();
  }

  Future<void> toggleCollapsed(String tagId) =>
      setCollapsed(tagId, !isCollapsed(tagId));
}
