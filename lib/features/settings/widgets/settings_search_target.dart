import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A search destination is scoped to one page/pane, so labels remain localized
/// and rows opened through normal navigation incur no animation or scroll work.
class SettingsSearchTarget extends InheritedWidget {
  const SettingsSearchTarget({
    super.key,
    required this.label,
    required super.child,
  });

  final String? label;

  static Widget wrap(BuildContext context, String label, Widget child) {
    final target = context
        .dependOnInheritedWidgetOfExactType<SettingsSearchTarget>();
    if (target?.label != label) return child;
    return _SearchHighlight(key: ValueKey(label), child: child);
  }

  @override
  bool updateShouldNotify(SettingsSearchTarget oldWidget) =>
      label != oldWidget.label;
}

class _SearchHighlight extends StatefulWidget {
  const _SearchHighlight({super.key, required this.child});
  final Widget child;

  @override
  State<_SearchHighlight> createState() => _SearchHighlightState();
}

class _SearchHighlightState extends State<_SearchHighlight> {
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // All searchable rows are in an eagerly laid-out settings section. Jump
      // before the route transition finishes, without an extra scrolling tour.
      Scrollable.ensureVisible(context, alignment: 0.25);
      setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        widget.child,
        if (_revealed)
          Positioned.fill(
            child: IgnorePointer(
              child:
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ).animate().fadeOut(
                    delay: Duration(milliseconds: reduceMotion ? 1800 : 1000),
                    duration: Duration(milliseconds: reduceMotion ? 0 : 900),
                  ),
            ),
          ),
      ],
    );
  }
}
