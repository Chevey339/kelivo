import 'package:flutter/material.dart';

/// Defers theme updates while a maintained route is completely covered.
///
/// Navigator disables tickers after an opaque route has finished covering us.
/// Translucent routes and in-progress transitions keep following the theme.
/// Visible content inherits the application theme directly, so dialogs opened
/// by descendants do not capture an extra local theme snapshot.
class VisibleRouteTheme extends StatefulWidget {
  const VisibleRouteTheme({super.key, required this.child});

  final Widget child;

  @override
  State<VisibleRouteTheme> createState() => _VisibleRouteThemeState();
}

class _VisibleRouteThemeState extends State<VisibleRouteTheme> {
  final _contentKey = GlobalKey();
  CapturedThemes? _themes;

  @override
  Widget build(BuildContext context) {
    // capture() snapshots without subscribing. These dependencies also cover
    // Cupertino and selection themes, which change alongside Material colors.
    Theme.of(context);
    DefaultSelectionStyle.of(context);
    final visible = TickerMode.valuesOf(context).enabled;
    // Preserve every content State when entering/leaving the captured themes,
    // including controls above any GlobalKeys owned by the page itself.
    final content = KeyedSubtree(key: _contentKey, child: widget.child);
    if (visible) {
      _themes = null;
      return content;
    }
    _themes ??= InheritedTheme.capture(from: context, to: null);
    return _themes!.wrap(content);
  }
}
