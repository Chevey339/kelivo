import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Makes Android back leave an in-page selection before popping its route.
///
/// iOS keeps the route's native edge swipe. Blocking that route with PopScope
/// (or adding local history) would disable the Cupertino back gesture entirely.
class SelectionBackScope extends StatelessWidget {
  const SelectionBackScope({
    super.key,
    required this.selecting,
    required this.onCancel,
    required this.child,
  });

  final bool selecting;
  final VoidCallback onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) return child;

    return PopScope<Object?>(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selecting && ModalRoute.isCurrentOf(context) == true) {
          onCancel();
        }
      },
      child: child,
    );
  }
}
