import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/conversation_find_service.dart';

typedef FindSearch =
    Future<Map<String, List<ConversationFindHit>>> Function(
      String query,
      FindOptions options,
      bool Function() isCurrent,
    );
typedef FindReveal =
    void Function(ConversationFindHit hit, bool Function() isCurrent);

/// One controller belongs to the chat page. Closing keeps only this session's
/// query/options. Asynchronous search and navigation have separate lifetimes.
class ConversationFindController extends ChangeNotifier {
  ConversationFindController({required this.search, required this.onReveal});
  final FindSearch search;
  final FindReveal onReveal;
  static const debounce = Duration(milliseconds: 200);
  String? _conversation;
  String query = '';
  FindOptions options = defaultFindOptions;
  bool opened = false;
  bool searching = false;
  bool _preservePendingPosition = false;
  List<ConversationFindHit> hits = const [];
  int index = -1;
  int _generation = 0, _navigation = 0;
  Timer? _timer, _streamTimer;
  final _pendingRows = <String, Future<List<ConversationFindHit>> Function()>{};
  int? _streamGeneration;
  static const _maximumStreamDelay = Duration(milliseconds: 650);
  final _streamWait = Stopwatch();
  final _byMessage = <String, List<ConversationFindHit>>{};
  ConversationFindHit? get current => index < 0 ? null : hits[index];
  bool get canNavigate => opened && !searching && hits.isNotEmpty;

  void setConversation(String? id) {
    if (_conversation == id) return;
    _conversation = id;
    query = '';
    options = defaultFindOptions;
    close();
  }

  void open({String? selection}) {
    if (selection != null && selection.trim().isNotEmpty) {
      query = selection;
    }
    final wasOpen = opened;
    opened = true;
    if (!wasOpen || selection != null) _schedule(immediate: true);
  }

  void close() {
    opened = false;
    _cancel();
    _clearHits();
    notifyListeners();
  }

  void setQuery(String value) {
    if (value == query) return;
    query = value;
    _schedule();
  }

  void setOptions(FindOptions value) {
    if (value == options) return;
    options = value;
    _schedule(immediate: true);
  }

  void refresh({bool preserve = true}) {
    if (opened && query.trim().isNotEmpty) {
      _schedule(
        immediate: true,
        preserve: preserve && (!searching || _preservePendingPosition),
      );
    }
  }

  void _schedule({bool immediate = false, bool preserve = false}) {
    _cancel();
    if (!opened || query.trim().isEmpty) {
      _clearHits();
      notifyListeners();
      return;
    }
    final generation = _generation;
    searching = true;
    _preservePendingPosition = preserve;
    notifyListeners();
    Future<void> run() async {
      bool valid() => generation == _generation;
      Map<String, List<ConversationFindHit>> rows;
      try {
        rows = await search(query, options, valid);
      } catch (error, stack) {
        if (!valid()) return;
        _clearHits();
        notifyListeners();
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'conversation find',
          ),
        );
        return;
      }
      if (!valid()) return;
      searching = false;
      _byMessage
        ..clear()
        ..addAll(rows);
      _publish(preserve: preserve);
      _armStreamRefresh();
    }

    if (immediate) {
      unawaited(run());
    } else {
      _timer = Timer(debounce, run);
    }
  }

  /// Re-evaluate only the row being written. Sample at most once per window
  /// even if generation emits continuously, always using its newest snapshot.
  void streamChanged(
    String id,
    Future<List<ConversationFindHit>> Function() read,
  ) {
    if (!opened || query.trim().isEmpty) return;
    _pendingRows[id] = read;
    if (searching || _streamGeneration == _generation) return;
    _armStreamRefresh();
  }

  void _armStreamRefresh() {
    if (_pendingRows.isEmpty) return;
    if (!_streamWait.isRunning) _streamWait.start();
    _streamTimer?.cancel();
    final remaining = _maximumStreamDelay - _streamWait.elapsed;
    _streamTimer = Timer(
      remaining < debounce ? remaining : debounce,
      _refreshStreamRows,
    );
  }

  Future<void> _refreshStreamRows() async {
    final generation = _generation;
    _streamGeneration = generation;
    _streamWait
      ..stop()
      ..reset();
    final pending = Map.of(_pendingRows);
    _pendingRows.clear();
    var changed = false;
    try {
      for (final entry in pending.entries) {
        if (!_byMessage.containsKey(entry.key)) continue;
        final rows = await entry.value();
        if (generation != _generation) return;
        if (!listEquals(rows, _byMessage[entry.key])) {
          _byMessage[entry.key] = rows;
          changed = true;
        }
      }
      if (changed) _publish(preserve: true);
    } catch (error, stack) {
      if (generation == _generation) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'conversation find',
          ),
        );
      }
    } finally {
      if (_streamGeneration == generation) {
        _streamGeneration = null;
        _armStreamRefresh();
      }
    }
  }

  void _publish({required bool preserve}) {
    final old = current;
    final previousIndex = index;
    hits = [for (final row in _byMessage.values) ...row];
    index = hits.isEmpty ? -1 : 0;
    if (preserve && old != null && hits.isNotEmpty) {
      final found = hits.indexOf(old);
      index = found >= 0 ? found : previousIndex.clamp(0, hits.length - 1);
      if (found < 0) {
        // Reflow can move an occurrence in the streaming row. Prefer the
        // closest source position in that part before moving to another row.
        int? distance;
        for (var i = 0; i < hits.length; i++) {
          final hit = hits[i];
          if (hit.messageId != old.messageId ||
              hit.part != old.part ||
              hit.block != old.block ||
              hit.surfaceKey != old.surfaceKey) {
            continue;
          }
          final delta = (hit.range.start - old.range.start).abs();
          if (distance == null ||
              delta < distance ||
              (delta == distance && i == previousIndex)) {
            index = i;
            distance = delta;
          }
        }
      }
    }
    if (!preserve || old != current) {
      _reveal();
    } else {
      notifyListeners();
    }
  }

  void move(int delta) {
    if (!canNavigate) return;
    index = (index + delta) % hits.length;
    _reveal();
  }

  void _reveal() {
    final serial = ++_navigation;
    final hit = current;
    notifyListeners();
    if (hit != null) onReveal(hit, () => serial == _navigation && opened);
  }

  List<ConversationFindHit> hitsFor(String id) => _byMessage[id] ?? const [];

  void _clearHits() {
    _byMessage.clear();
    hits = const [];
    index = -1;
    searching = false;
  }

  void _cancel() {
    _generation++;
    _navigation++;
    _timer?.cancel();
    _streamTimer?.cancel();
    _streamGeneration = null;
    _pendingRows.clear();
    _streamWait
      ..stop()
      ..reset();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }
}
