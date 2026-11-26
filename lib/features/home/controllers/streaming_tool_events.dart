import '../../../core/models/tool_event_snapshot.dart';
import '../../chat/utils/tool_event_deduplication.dart';

/// Owns the event overlay for one generation. Checkpoints freeze it on demand.
class StreamingToolEvents {
  StreamingToolEvents([List<Map<String, dynamic>> seed = const []])
    : _events = [for (final event in seed) Map<String, dynamic>.of(event)],
      _needsDedup = seed.isNotEmpty {
    _indexIds();
  }

  List<Map<String, dynamic>> _events;
  final _indices = <String, int>{};
  bool _needsDedup;
  ToolEventSnapshot? _snapshot;
  ToolEventSnapshot get snapshot => _snapshot ??= ToolEventSnapshot(_events);

  void _indexIds() {
    _indices.clear();
    for (var index = 0; index < _events.length; index++) {
      final id = (_events[index]['id']?.toString() ?? '').trim();
      if (id.isNotEmpty) _indices.putIfAbsent(id, () => index);
    }
  }

  void start(Map<String, dynamic> event) {
    final id = (event['id']?.toString() ?? '').trim();
    if (id.isEmpty || _needsDedup) {
      // Anonymous calls use argument/content identity. Normalize restored
      // overlays on the first start, just as for a newly received sequence.
      _events = dedupeToolEvents([..._events, event]);
      _indexIds();
      _needsDedup = false;
    } else {
      final index = _indices[id];
      if (index == null) {
        _indices[id] = _events.length;
        _events.add(event);
      } else {
        if (hasCompletedToolContent(_events[index]['content']?.toString())) {
          return;
        }
        _events[index] = event;
      }
    }
    _snapshot = null;
  }

  void complete(Map<String, dynamic> incoming) {
    final id = incoming['id']! as String;
    var index = _indices[id.trim()] ?? -1;
    if (index < 0 || _events[index]['id']?.toString() != id) {
      // A result without a matching raw ID can introduce an anonymous or
      // whitespace-equivalent duplicate. Normalize on the next start.
      _needsDedup = true;
      index = id.isEmpty
          ? -1
          : _events.indexWhere((event) => event['id']?.toString() == id);
    }
    if (index < 0) {
      index = _events.indexWhere(
        (event) =>
            (event['name']?.toString() ?? '') == incoming['name'] &&
            (event['content']?.toString() ?? '').isEmpty,
      );
    }
    if (index < 0) {
      if (id.trim().isNotEmpty) _indices[id.trim()] = _events.length;
      _events.add(incoming);
    } else {
      final previous = _events[index];
      _events[index] = _mergeRecord(previous, incoming);
      if (previous['id'] != _events[index]['id']) {
        _needsDedup = true;
        _indexIds();
      }
    }
    _snapshot = null;
  }

  static Map<String, dynamic> _mergeRecord(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) {
    final merged = Map<String, dynamic>.from(existing);
    for (final entry in incoming.entries) {
      if (entry.key == 'metadata') continue;
      if (_isEmptyToolOverlay(entry.value) &&
          !_isEmptyToolOverlay(merged[entry.key])) {
        continue;
      }
      merged[entry.key] = entry.value;
    }
    if (existing['server'] == true && incoming['server'] != false) {
      merged['server'] = true;
    }
    final incomingMetadata = incoming['metadata'];
    if (incomingMetadata is Map && incomingMetadata.isNotEmpty) {
      final existingMetadata = merged['metadata'];
      merged['metadata'] = <String, dynamic>{
        if (existingMetadata is Map)
          ...Map<String, dynamic>.from(existingMetadata),
        ...Map<String, dynamic>.from(incomingMetadata),
      };
    } else if (!merged.containsKey('metadata')) {
      final existingMetadata = existing['metadata'];
      if (existingMetadata is Map) {
        merged['metadata'] = Map<String, dynamic>.from(existingMetadata);
      }
    }
    return merged;
  }

  static bool _isEmptyToolOverlay(Object? value) {
    if (value == null) return true;
    if (value is String) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    if (value is List) return value.isEmpty;
    return false;
  }
}
