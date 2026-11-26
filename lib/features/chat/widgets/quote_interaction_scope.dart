import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../core/models/quote_ref.dart';
import '../../../shared/widgets/source_rect_scroll.dart';
import '../services/conversation_find_service.dart';

class QuoteInteractionController extends ChangeNotifier {
  QuoteInteractionController({
    required this.onQuote,
    required this.onJump,
    required this.sourceExists,
  });
  final Future<void> Function(QuoteRef) onQuote;
  final Future<bool> Function(QuoteRef) onJump;
  final Future<bool> Function(String) sourceExists;
  List<QuoteRef> _draft = const [];
  QuoteRef? _revealed;
  Timer? _timer;
  QuoteRef? _navigation;
  int _navigationSerial = 0;
  final _sourceRects = <Object, ({int start, Rect rect})? Function(QuoteRef)>{};
  final _findRects = <Object, Rect? Function(ConversationFindHit)>{};
  void registerFindRect(
    Object owner,
    Rect? Function(ConversationFindHit) locate,
  ) => _findRects[owner] = locate;
  void unregisterFindRect(Object owner) => _findRects.remove(owner);

  Rect? findRect(ConversationFindHit hit) {
    for (final locate in _findRects.values) {
      final rect = locate(hit);
      if (rect != null) return rect;
    }
    return null;
  }

  int sourceRevision = 0;

  QuoteRef? navigationFor(String messageId) =>
      _navigation?.messageId == messageId ? _navigation : null;

  void registerSourceRect(
    Object owner,
    ({int start, Rect rect})? Function(QuoteRef) locate,
  ) => _sourceRects[owner] = locate;

  void unregisterSourceRect(Object owner) => _sourceRects.remove(owner);

  /// Mount the source block first, then correct against its laid-out glyphs.
  /// The short layout handshake is independent of the jump-highlight timer.
  Future<void> scrollToSource(
    QuoteRef quote, {
    required void Function(Rect) scrollToRect,
    required bool Function() isCurrent,
  }) async {
    if (!quote.hasSourceRange) return;
    final serial = ++_navigationSerial;
    _navigation = quote;
    notifyListeners();
    try {
      await scrollToSourceGeometry(
        isCurrent: () => serial == _navigationSerial && isCurrent(),
        scrollToRect: scrollToRect,
        locate: () {
          ({int start, Rect rect})? first;
          for (final locate in _sourceRects.values) {
            final target = locate(quote);
            if (target != null &&
                (first == null || target.start < first.start)) {
              first = target;
            }
          }
          return first?.rect;
        },
      );
    } finally {
      if (serial == _navigationSerial) {
        _navigation = null;
        notifyListeners();
      }
    }
  }

  void refreshSources() {
    sourceRevision++;
    notifyListeners();
  }

  void setDraftQuotes(List<QuoteRef> quotes) {
    if (listEquals(_draft, quotes)) return;
    _draft = List.unmodifiable(quotes);
    notifyListeners();
  }

  Iterable<QuoteRef> highlightsFor(String messageId) => [
    ..._draft,
    if (_revealed != null) _revealed!,
  ].where((q) => q.hasSourceRange && q.messageId == messageId);

  void reveal(QuoteRef quote) {
    if (!quote.hasSourceRange) return;
    _timer?.cancel();
    _revealed = quote;
    notifyListeners();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      _revealed = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _navigationSerial++;
    _sourceRects.clear();
    _findRects.clear();
    _timer?.cancel();
    super.dispose();
  }
}

class QuoteInteractionScope
    extends InheritedNotifier<QuoteInteractionController> {
  const QuoteInteractionScope({
    super.key,
    required QuoteInteractionController controller,
    required super.child,
  }) : super(notifier: controller);
  static QuoteInteractionController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<QuoteInteractionScope>()
      ?.notifier;
}
