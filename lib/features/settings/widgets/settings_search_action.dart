import 'package:flutter/material.dart';

/// Adds keyboard activation to the app's tactile search buttons and rows.
class SettingsSearchAction extends StatefulWidget {
  const SettingsSearchAction({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
  });
  final VoidCallback onTap;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<SettingsSearchAction> createState() => _SettingsSearchActionState();
}

class _SettingsSearchActionState extends State<SettingsSearchAction> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onTap();
          return null;
        },
      ),
    },
    onShowFocusHighlight: (focused) => setState(() => _focused = focused),
    onFocusChange: (focused) {
      if (focused) Scrollable.ensureVisible(context, alignment: 0.5);
    },
    child: Container(
      foregroundDecoration: _focused
          ? BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.primary),
              borderRadius: widget.borderRadius,
            )
          : null,
      child: widget.child,
    ),
  );
}
