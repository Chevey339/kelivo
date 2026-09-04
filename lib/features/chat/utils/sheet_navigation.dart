import 'dart:async';

import 'package:flutter/widgets.dart';

/// Closes the sheet [context] sits in via [onClose], then runs [action] once
/// its route is gone.
///
/// Pushing a dialog straight after `maybePop` races the pop: the delayed
/// `pop()` can remove the freshly pushed route instead, leaving its transparent
/// `ModalBarrier` on screen so the page looks fine but ignores taps. Waiting on
/// the popup route's own completion avoids that.
void afterSheetClose(
  BuildContext context, {
  required VoidCallback? onClose,
  required void Function(BuildContext context) action,
}) {
  final navigator = Navigator.of(context);
  final route = ModalRoute.of(context);
  final waitForPopup = route is PopupRoute ? route.completed : null;
  onClose?.call();
  unawaited(() async {
    if (waitForPopup != null) {
      await waitForPopup;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!navigator.mounted) return;
    action(navigator.context);
  }());
}
