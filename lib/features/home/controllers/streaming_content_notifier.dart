import 'package:flutter/foundation.dart';

/// Lightweight notifier for streaming message content updates.
///
/// This class provides a way to update streaming message content without
/// triggering a full page rebuild. Instead of using ChangeNotifier.notifyListeners()
/// which causes the entire HomePage to rebuild, this uses ValueNotifier
/// so only the specific message widget that's listening will rebuild.
///
/// Usage:
/// 1. StreamController updates content via updateContent()
/// 2. ChatMessageWidget uses ValueListenableBuilder to listen to contentNotifier
/// 3. Only the streaming message widget rebuilds, not the entire page
class StreamingContentNotifier {
  /// Map of message ID to its content notifier.
  /// Each streaming message has its own `ValueNotifier<String>`.
  final Map<String, ValueNotifier<StreamingContentData>> _notifiers =
      <String, ValueNotifier<StreamingContentData>>{};

  final Map<String, StreamingContentData> _pendingFrozenUpdates =
      <String, StreamingContentData>{};
  final Set<String> _deferredRemovals = <String>{};

  bool _updatesFrozen = false;

  /// Whether streaming UI updates are currently being held back.
  bool get updatesFrozen => _updatesFrozen;

  /// Get or create a notifier for a message.
  ValueNotifier<StreamingContentData> getNotifier(String messageId) {
    return _notifiers.putIfAbsent(
      messageId,
      () => ValueNotifier<StreamingContentData>(
        const StreamingContentData(content: '', totalTokens: 0),
      ),
    );
  }

  /// Check if a notifier exists for a message.
  bool hasNotifier(String messageId) => _notifiers.containsKey(messageId);

  /// Check if a frozen update is waiting to be displayed.
  bool hasPendingFrozenUpdate(String messageId) =>
      _pendingFrozenUpdates.containsKey(messageId);

  /// Freeze or resume streaming UI updates.
  ///
  /// While frozen, update calls keep only the latest display snapshot per
  /// message and do not notify listeners. Resuming applies each snapshot once.
  bool setUpdatesFrozen(bool frozen) {
    if (_updatesFrozen == frozen) return false;
    _updatesFrozen = frozen;
    if (frozen) return false;
    return _flushFrozenUpdates();
  }

  /// Update content for a streaming message.
  /// This will only notify the specific widget listening to this message's notifier.
  void updateContent(
    String messageId,
    String content,
    int totalTokens, {
    List<int>? contentSplitOffsets,
    List<int>? reasoningCountAtSplit,
    List<int>? toolCountAtSplit,
    int? promptTokens,
    int? completionTokens,
    int? cachedTokens,
    int? durationMs,
  }) {
    _updateData(
      messageId,
      (current) => current.copyWith(
        content: content,
        totalTokens: totalTokens,
        contentSplitOffsets: contentSplitOffsets,
        reasoningCountAtSplit: reasoningCountAtSplit,
        toolCountAtSplit: toolCountAtSplit,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        cachedTokens: cachedTokens,
        durationMs: durationMs,
      ),
    );
  }

  /// Update reasoning content for a streaming message.
  void updateReasoning(
    String messageId, {
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    List<int>? contentSplitOffsets,
    List<int>? reasoningCountAtSplit,
    List<int>? toolCountAtSplit,
  }) {
    _updateData(
      messageId,
      (current) => current.copyWith(
        reasoningText: reasoningText,
        reasoningStartAt: reasoningStartAt,
        reasoningFinishedAt: reasoningFinishedAt,
        contentSplitOffsets: contentSplitOffsets,
        reasoningCountAtSplit: reasoningCountAtSplit,
        toolCountAtSplit: toolCountAtSplit,
      ),
    );
  }

  /// Notify that tool parts have been updated.
  /// Uses a version counter to trigger rebuild without copying tool data.
  void notifyToolPartsUpdated(
    String messageId, {
    List<int>? contentSplitOffsets,
    List<int>? reasoningCountAtSplit,
    List<int>? toolCountAtSplit,
  }) {
    _updateData(
      messageId,
      (current) => current.copyWith(
        contentSplitOffsets: contentSplitOffsets,
        reasoningCountAtSplit: reasoningCountAtSplit,
        toolCountAtSplit: toolCountAtSplit,
        toolPartsVersion: current.toolPartsVersion + 1,
      ),
    );
  }

  /// Force a rebuild of the streaming message widget.
  /// Used when external state like reasoning expanded changes.
  void forceRebuild(String messageId) {
    _updateData(
      messageId,
      (current) => current.copyWith(uiVersion: current.uiVersion + 1),
    );
  }

  /// Remove notifier when streaming is complete.
  void removeNotifier(String messageId) {
    if (_updatesFrozen && _pendingFrozenUpdates.containsKey(messageId)) {
      _deferredRemovals.add(messageId);
      return;
    }
    _pendingFrozenUpdates.remove(messageId);
    _deferredRemovals.remove(messageId);
    final notifier = _notifiers.remove(messageId);
    notifier?.dispose();
  }

  /// Clear all notifiers (e.g., when switching conversations).
  void clear() {
    for (final notifier in _notifiers.values) {
      notifier.dispose();
    }
    _notifiers.clear();
    _pendingFrozenUpdates.clear();
    _deferredRemovals.clear();
    _updatesFrozen = false;
  }

  /// Dispose all resources.
  void dispose() {
    clear();
  }

  void _updateData(
    String messageId,
    StreamingContentData Function(StreamingContentData current) update,
  ) {
    final notifier = _notifiers[messageId];
    if (notifier == null) return;
    final current = _pendingFrozenUpdates[messageId] ?? notifier.value;
    final next = update(current);
    if (_updatesFrozen) {
      _pendingFrozenUpdates[messageId] = next;
      return;
    }
    notifier.value = next;
  }

  bool _flushFrozenUpdates() {
    if (_pendingFrozenUpdates.isEmpty) return false;
    final pending = Map<String, StreamingContentData>.of(_pendingFrozenUpdates);
    _pendingFrozenUpdates.clear();
    var flushed = false;
    for (final entry in pending.entries) {
      final notifier = _notifiers[entry.key];
      if (notifier == null) continue;
      notifier.value = entry.value;
      flushed = true;
    }
    for (final messageId in pending.keys) {
      if (_deferredRemovals.remove(messageId)) {
        final notifier = _notifiers.remove(messageId);
        notifier?.dispose();
      }
    }
    return flushed;
  }
}

/// Data class for streaming content.
@immutable
class StreamingContentData {
  const StreamingContentData({
    required this.content,
    required this.totalTokens,
    this.reasoningText,
    this.reasoningStartAt,
    this.reasoningFinishedAt,
    this.contentSplitOffsets,
    this.reasoningCountAtSplit,
    this.toolCountAtSplit,
    this.toolPartsVersion = 0,
    this.uiVersion = 0,
    this.promptTokens,
    this.completionTokens,
    this.cachedTokens,
    this.durationMs,
  });

  final String content;
  final int totalTokens;
  final String? reasoningText;
  final DateTime? reasoningStartAt;
  final DateTime? reasoningFinishedAt;
  final List<int>? contentSplitOffsets;
  final List<int>? reasoningCountAtSplit;
  final List<int>? toolCountAtSplit;

  /// Version counter for tool parts updates. Incrementing this triggers rebuild.
  final int toolPartsVersion;

  /// Version counter for UI state changes (e.g., reasoning expanded toggle).
  final int uiVersion;

  /// Detailed token usage fields.
  final int? promptTokens;
  final int? completionTokens;
  final int? cachedTokens;
  final int? durationMs;

  StreamingContentData copyWith({
    String? content,
    int? totalTokens,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    List<int>? contentSplitOffsets,
    List<int>? reasoningCountAtSplit,
    List<int>? toolCountAtSplit,
    int? toolPartsVersion,
    int? uiVersion,
    int? promptTokens,
    int? completionTokens,
    int? cachedTokens,
    int? durationMs,
  }) {
    return StreamingContentData(
      content: content ?? this.content,
      totalTokens: totalTokens ?? this.totalTokens,
      reasoningText: reasoningText ?? this.reasoningText,
      reasoningStartAt: reasoningStartAt ?? this.reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt ?? this.reasoningFinishedAt,
      contentSplitOffsets: contentSplitOffsets ?? this.contentSplitOffsets,
      reasoningCountAtSplit:
          reasoningCountAtSplit ?? this.reasoningCountAtSplit,
      toolCountAtSplit: toolCountAtSplit ?? this.toolCountAtSplit,
      toolPartsVersion: toolPartsVersion ?? this.toolPartsVersion,
      uiVersion: uiVersion ?? this.uiVersion,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      cachedTokens: cachedTokens ?? this.cachedTokens,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamingContentData &&
          runtimeType == other.runtimeType &&
          content == other.content &&
          totalTokens == other.totalTokens &&
          reasoningText == other.reasoningText &&
          reasoningStartAt == other.reasoningStartAt &&
          reasoningFinishedAt == other.reasoningFinishedAt &&
          listEquals(contentSplitOffsets, other.contentSplitOffsets) &&
          listEquals(reasoningCountAtSplit, other.reasoningCountAtSplit) &&
          listEquals(toolCountAtSplit, other.toolCountAtSplit) &&
          toolPartsVersion == other.toolPartsVersion &&
          uiVersion == other.uiVersion &&
          promptTokens == other.promptTokens &&
          completionTokens == other.completionTokens &&
          cachedTokens == other.cachedTokens &&
          durationMs == other.durationMs;

  @override
  int get hashCode =>
      content.hashCode ^
      totalTokens.hashCode ^
      reasoningText.hashCode ^
      reasoningStartAt.hashCode ^
      reasoningFinishedAt.hashCode ^
      Object.hashAll(contentSplitOffsets ?? const <int>[]) ^
      Object.hashAll(reasoningCountAtSplit ?? const <int>[]) ^
      Object.hashAll(toolCountAtSplit ?? const <int>[]) ^
      toolPartsVersion.hashCode ^
      uiVersion.hashCode ^
      promptTokens.hashCode ^
      completionTokens.hashCode ^
      cachedTokens.hashCode ^
      durationMs.hashCode;
}
