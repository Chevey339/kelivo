import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/services/chat/chat_service.dart';

typedef TimelinePageLoader =
    Future<LoadedTimelinePage?> Function({
      required String conversationId,
      String? beforeRevisionId,
      String? afterRevisionId,
      required int limit,
    });

/// Owns stable-cursor timeline paging. View widgets receive immutable slots
/// and never calculate database offsets or physical revision coordinates.
class TimelineCoordinator extends ChangeNotifier {
  TimelineCoordinator({required this.loadPage});

  final TimelinePageLoader loadPage;
  String? _conversationId;
  List<LoadedTimelineSlot> _slots = const [];
  bool _hasMoreBefore = false;
  bool _hasMoreAfter = false;

  String? get conversationId => _conversationId;
  UnmodifiableListView<LoadedTimelineSlot> get slots =>
      UnmodifiableListView(_slots);
  bool get hasMoreBefore => _hasMoreBefore;
  bool get hasMoreAfter => _hasMoreAfter;

  Future<void> open(String conversationId, {int limit = 40}) async {
    final page = await loadPage(conversationId: conversationId, limit: limit);
    if (page == null) return;
    _conversationId = conversationId;
    _replace(page);
  }

  Future<bool> loadBefore({int limit = 20}) async {
    final conversationId = _conversationId;
    if (conversationId == null || !_hasMoreBefore || _slots.isEmpty) {
      return false;
    }
    final page = await loadPage(
      conversationId: conversationId,
      beforeRevisionId: _slots.first.identity.revisionId,
      limit: limit,
    );
    if (page == null || page.slots.isEmpty) {
      _hasMoreBefore = false;
      notifyListeners();
      return false;
    }
    _slots = _merge(page.slots, _slots);
    _hasMoreBefore = page.hasMoreBefore;
    notifyListeners();
    return true;
  }

  Future<bool> loadAfter({int limit = 20}) async {
    final conversationId = _conversationId;
    if (conversationId == null || !_hasMoreAfter || _slots.isEmpty) {
      return false;
    }
    final page = await loadPage(
      conversationId: conversationId,
      afterRevisionId: _slots.last.identity.revisionId,
      limit: limit,
    );
    if (page == null || page.slots.isEmpty) {
      _hasMoreAfter = false;
      notifyListeners();
      return false;
    }
    _slots = _merge(_slots, page.slots);
    _hasMoreAfter = page.hasMoreAfter;
    notifyListeners();
    return true;
  }

  void clear() {
    _conversationId = null;
    _slots = const [];
    _hasMoreBefore = false;
    _hasMoreAfter = false;
    notifyListeners();
  }

  void _replace(LoadedTimelinePage page) {
    _slots = _merge(const [], page.slots);
    _hasMoreBefore = page.hasMoreBefore;
    _hasMoreAfter = page.hasMoreAfter;
    notifyListeners();
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
