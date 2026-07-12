import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/services/chat/chat_service.dart';
import '../../../core/models/chat_message.dart';

typedef TimelinePageLoader =
    Future<LoadedTimelinePage?> Function({
      required String conversationId,
      String? beforeRevisionId,
      String? afterRevisionId,
      bool? fromStart,
      required int limit,
    });

typedef TimelineWindowRetainer =
    void Function(String conversationId, Iterable<String> revisionIds);

final class TimelineWindowBudget {
  const TimelineWindowBudget({
    this.maxSlots = 360,
    this.maxDecodedBytes = 4 << 20,
  }) : assert(maxSlots > 0),
       assert(maxDecodedBytes > 0);

  final int maxSlots;
  final int maxDecodedBytes;
}

/// Owns stable-cursor timeline paging, request cancellation, and the bounded
/// decoded window. View widgets never calculate database offsets.
class TimelineCoordinator extends ChangeNotifier {
  TimelineCoordinator({
    required this.loadPage,
    this.retainWindow,
    this.budget = const TimelineWindowBudget(),
  });

  final TimelinePageLoader loadPage;
  final TimelineWindowRetainer? retainWindow;
  final TimelineWindowBudget budget;

  String? _conversationId;
  List<LoadedTimelineSlot> _slots = const [];
  bool _hasMoreBefore = false;
  bool _hasMoreAfter = false;
  bool _loadingBefore = false;
  bool _loadingAfter = false;
  int _requestEpoch = 0;
  int _stateRevision = 0;
  int _totalSlotCount = 0;
  int _decodedBytes = 0;

  String? get conversationId => _conversationId;
  UnmodifiableListView<LoadedTimelineSlot> get slots =>
      UnmodifiableListView(_slots);
  bool get hasMoreBefore => _hasMoreBefore;
  bool get hasMoreAfter => _hasMoreAfter;
  bool get loadingBefore => _loadingBefore;
  bool get loadingAfter => _loadingAfter;
  int get totalSlotCount => _totalSlotCount;
  int get decodedBytes => _decodedBytes;

  Future<void> open(String conversationId, {int limit = 40}) async {
    final epoch = ++_requestEpoch;
    _conversationId = conversationId;
    _slots = const [];
    _hasMoreBefore = false;
    _hasMoreAfter = false;
    _decodedBytes = 0;
    notifyListeners();
    final page = await loadPage(
      conversationId: conversationId,
      fromStart: false,
      limit: limit,
    );
    if (!_accepts(epoch, conversationId) || page == null) return;
    _stateRevision = page.stateRevision;
    _totalSlotCount = page.totalSlotCount;
    _replace(page);
  }

  Future<void> openStart(String conversationId, {int limit = 40}) async {
    final epoch = ++_requestEpoch;
    _conversationId = conversationId;
    final page = await loadPage(
      conversationId: conversationId,
      fromStart: true,
      limit: limit,
    );
    if (!_accepts(epoch, conversationId) || page == null) return;
    _stateRevision = page.stateRevision;
    _totalSlotCount = page.totalSlotCount;
    _replace(page);
  }

  void seed(LoadedTimelinePage page) {
    _requestEpoch++;
    _conversationId = page.conversationId;
    _stateRevision = page.stateRevision;
    _totalSlotCount = page.totalSlotCount;
    _replace(page);
  }

  Future<bool> loadBefore({int limit = 20}) async {
    final conversationId = _conversationId;
    if (conversationId == null ||
        !_hasMoreBefore ||
        _slots.isEmpty ||
        _loadingBefore) {
      return false;
    }
    final epoch = _requestEpoch;
    _loadingBefore = true;
    notifyListeners();
    try {
      final page = await loadPage(
        conversationId: conversationId,
        beforeRevisionId: _slots.first.identity.revisionId,
        fromStart: false,
        limit: limit,
      );
      if (!_accepts(epoch, conversationId) || page == null) return false;
      if (page.stateRevision != _stateRevision) return false;
      if (page.slots.isEmpty) {
        _hasMoreBefore = false;
        return false;
      }
      _slots = _merge(page.slots, _slots);
      _hasMoreBefore = page.hasMoreBefore;
      _totalSlotCount = page.totalSlotCount;
      _enforceBudget(trimFromStart: false);
      _publishRetainedWindow();
      return true;
    } finally {
      if (_accepts(epoch, conversationId)) {
        _loadingBefore = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadAfter({int limit = 20}) async {
    final conversationId = _conversationId;
    if (conversationId == null ||
        !_hasMoreAfter ||
        _slots.isEmpty ||
        _loadingAfter) {
      return false;
    }
    final epoch = _requestEpoch;
    _loadingAfter = true;
    notifyListeners();
    try {
      final page = await loadPage(
        conversationId: conversationId,
        afterRevisionId: _slots.last.identity.revisionId,
        fromStart: false,
        limit: limit,
      );
      if (!_accepts(epoch, conversationId) || page == null) return false;
      if (page.stateRevision != _stateRevision) return false;
      if (page.slots.isEmpty) {
        _hasMoreAfter = false;
        return false;
      }
      _slots = _merge(_slots, page.slots);
      _hasMoreAfter = page.hasMoreAfter;
      _totalSlotCount = page.totalSlotCount;
      _enforceBudget(trimFromStart: true);
      _publishRetainedWindow();
      return true;
    } finally {
      if (_accepts(epoch, conversationId)) {
        _loadingAfter = false;
        notifyListeners();
      }
    }
  }

  void clear() {
    _requestEpoch++;
    _conversationId = null;
    _slots = const [];
    _hasMoreBefore = false;
    _hasMoreAfter = false;
    _loadingBefore = false;
    _loadingAfter = false;
    _totalSlotCount = 0;
    _decodedBytes = 0;
    notifyListeners();
  }

  void replaceMessage(ChatMessage message) {
    final index = _slots.indexWhere(
      (slot) => slot.identity.revisionId == message.id,
    );
    if (index < 0) return;
    final updated = _slots.toList(growable: false);
    updated[index] = LoadedTimelineSlot(
      identity: updated[index].identity,
      message: message,
    );
    _slots = List.unmodifiable(updated);
    _decodedBytes = _slots.fold<int>(0, (sum, slot) => sum + _slotBytes(slot));
    notifyListeners();
  }

  bool _accepts(int epoch, String conversationId) =>
      epoch == _requestEpoch && _conversationId == conversationId;

  void _replace(LoadedTimelinePage page) {
    _slots = _merge(const [], page.slots);
    _hasMoreBefore = page.hasMoreBefore;
    _hasMoreAfter = page.hasMoreAfter;
    _enforceBudget(trimFromStart: true);
    _publishRetainedWindow();
    notifyListeners();
  }

  void _enforceBudget({required bool trimFromStart}) {
    var bytes = _slots.fold<int>(0, (sum, slot) => sum + _slotBytes(slot));
    final mutable = _slots.toList(growable: true);
    while (mutable.length > 1 &&
        (mutable.length > budget.maxSlots || bytes > budget.maxDecodedBytes)) {
      final removed = trimFromStart
          ? mutable.removeAt(0)
          : mutable.removeLast();
      bytes -= _slotBytes(removed);
      if (trimFromStart) {
        _hasMoreBefore = true;
      } else {
        _hasMoreAfter = true;
      }
    }
    _slots = List.unmodifiable(mutable);
    _decodedBytes = bytes;
  }

  int _slotBytes(LoadedTimelineSlot slot) {
    final message = slot.message;
    return 128 +
        (message.content.length * 2) +
        ((message.reasoningText?.length ?? 0) * 2) +
        ((message.translation?.length ?? 0) * 2) +
        ((message.reasoningSegmentsJson?.length ?? 0) * 2);
  }

  void _publishRetainedWindow() {
    final conversationId = _conversationId;
    if (conversationId == null) return;
    retainWindow?.call(
      conversationId,
      _slots.map((slot) => slot.identity.revisionId),
    );
  }

  List<LoadedTimelineSlot> _merge(
    Iterable<LoadedTimelineSlot> first,
    Iterable<LoadedTimelineSlot> second,
  ) {
    final bySlot = <String, LoadedTimelineSlot>{};
    for (final slot in [...first, ...second]) {
      if (bySlot.containsKey(slot.identity.slotId)) {
        throw StateError('timeline_duplicate_slot');
      }
      bySlot[slot.identity.slotId] = slot;
    }
    return List.unmodifiable(bySlot.values);
  }
}
