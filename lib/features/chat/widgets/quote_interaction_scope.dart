import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../core/models/quote_ref.dart';

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
  int sourceRevision = 0;

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
  ].where((q) => q.messageId == messageId);

  void reveal(QuoteRef quote) {
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
