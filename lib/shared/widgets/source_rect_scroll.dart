import 'package:flutter/widgets.dart';

/// Center a laid-out source range, remeasuring as lazy blocks settle.
/// An indexed caller can try the mounted range first, then mount its message
/// only if the range has no geometry yet.
Future<bool> scrollToSourceGeometry({
  required Rect? Function() locate,
  required void Function(Rect) scrollToRect,
  required bool Function() isCurrent,
  bool waitForMount = true,
}) async {
  Rect? previous;
  var found = false;
  for (var pass = 0; pass < 8; pass++) {
    await WidgetsBinding.instance.endOfFrame;
    if (!isCurrent()) return false;
    final rect = locate();
    if (rect != null) {
      found = true;
      scrollToRect(rect);
      if (previous != null && (previous.center - rect.center).distance < .5) {
        break;
      }
    } else if (!waitForMount && !found) {
      return false;
    }
    previous = rect;
  }
  return found;
}
