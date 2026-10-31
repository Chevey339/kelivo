import 'dart:collection';

/// A tool-event list published by the stream owner. Records are replaced when
/// tool state changes; body tokens can reuse the same checkpoint overlay.
class ToolEventSnapshot extends UnmodifiableListView<Map<String, dynamic>> {
  ToolEventSnapshot(Iterable<Map<String, dynamic>> events)
    : super(List.unmodifiable(events.map(Map<String, dynamic>.unmodifiable)));
}
