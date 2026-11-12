import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Android's stretching overscroll decoration isolates its viewport in an
/// ImageFilterLayer. Glass inside that viewport can no longer sample the page
/// behind it. Disable only that decoration for browser-owned scrollables.
class BrowserScrollConfiguration extends StatelessWidget {
  const BrowserScrollConfiguration({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) return child;
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: child,
    );
  }
}
