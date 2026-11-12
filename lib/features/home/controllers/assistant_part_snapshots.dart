import 'dart:collection';

import '../../../core/models/message_part.dart';
import '../../../core/models/message_part_snapshot.dart';
import '../../../core/services/api/stream/stream_chunk.dart'
    show isBlankImageUri;

/// Transforms only changed source parts, then clips text for the typewriter.
/// Checkpoint and presentation consumers own independent immutable snapshots.
class AssistantPartSnapshots {
  MessagePartSnapshot? _source;
  List<MessagePart> _transformed = [];
  final _textIndices = SplayTreeSet<int>();
  final _checkpoint = MessagePartSnapshotBuilder(arrivalOrdered: true);
  final _presentation = MessagePartSnapshotBuilder(arrivalOrdered: true);
  Set<int> _previousClipped = {};
  bool _presentationAligned = false;
  bool _sourceAligned = true;
  Set<int>? _checkpointDirty;
  Set<int>? _presentationDirty;

  List<MessagePart> update(
    List<MessagePart> source, {
    required String Function(String) transform,
    String? visibleText,
  }) {
    var changed = source is MessagePartSnapshot && _source != null
        ? source.changesSince(_source!)
        : null;
    if (!_sourceAligned) changed = null;
    MessagePart rewrite(MessagePart part) {
      if (part is! TextPart) return part;
      final text = transform(part.text);
      return text == part.text ? part : TextPart(text);
    }

    if (changed == null ||
        changed.any(
          (index) =>
              index < source.length &&
              source[index] is ImagePart &&
              isBlankImageUri((source[index] as ImagePart).uri),
        )) {
      _transformed = [
        for (final part in source)
          if (part is! ImagePart || !isBlankImageUri(part.uri)) rewrite(part),
      ];
      _sourceAligned = _transformed.length == source.length;
      _textIndices
        ..clear()
        ..addAll([
          for (var i = 0; i < _transformed.length; i++)
            if (_transformed[i] is TextPart) i,
        ]);
      changed = null;
    } else {
      for (final index in changed.toList()..sort()) {
        if (index >= source.length) continue;
        final part = rewrite(source[index]);
        if (index < _transformed.length) {
          _transformed[index] = part;
        } else {
          _transformed.add(part);
        }
        if (part is TextPart) {
          _textIndices.add(index);
        } else {
          _textIndices.remove(index);
        }
      }
      if (_transformed.length > source.length) {
        _transformed.length = source.length;
        _textIndices.removeWhere((index) => index >= source.length);
      }
    }
    _source = source is MessagePartSnapshot ? source : null;
    if (changed == null) {
      _checkpointDirty = null;
      _presentationDirty = null;
    } else {
      _checkpointDirty?.addAll(changed);
      _presentationDirty?.addAll(changed);
    }
    if (visibleText == null) {
      final snapshot = _checkpoint.update(
        _transformed,
        changed: _checkpointDirty,
      );
      _checkpointDirty = {};
      return snapshot;
    }
    var remaining = visibleText.length;
    final out = List<MessagePart>.of(_transformed);
    final clipped = <int>{};
    final removed = <int>[];
    for (final index in _textIndices) {
      final part = _transformed[index] as TextPart;
      if (remaining <= 0) {
        removed.add(index);
        clipped.add(index);
      } else if (part.text.length <= remaining) {
        remaining -= part.text.length;
      } else {
        out[index] = TextPart(part.text.substring(0, remaining));
        clipped.add(index);
        remaining = 0;
      }
    }
    for (final index in removed.reversed) {
      out.removeAt(index);
    }
    final dirty =
        _presentationDirty != null && _presentationAligned && removed.isEmpty
        ? <int>{..._presentationDirty!, ..._previousClipped, ...clipped}
        : null;
    _previousClipped = clipped;
    _presentationAligned = removed.isEmpty;
    final snapshot = _presentation.update(out, changed: dirty);
    _presentationDirty = {};
    return snapshot;
  }
}
