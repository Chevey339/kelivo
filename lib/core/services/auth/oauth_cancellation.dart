import 'dart:async';
import '../../models/provider_oauth.dart';

class OAuthCancellation {
  final _cancelled = Completer<void>();
  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;
  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  void check() {
    if (isCancelled) {
      throw const ProviderOAuthException(ProviderOAuthFailure.cancelled);
    }
  }

  Future<void> wait(Duration duration) async {
    check();
    final elapsed = Completer<void>();
    final timer = Timer(duration, elapsed.complete);
    try {
      await Future.any([elapsed.future, whenCancelled]);
    } finally {
      timer.cancel();
    }
    check();
  }
}
