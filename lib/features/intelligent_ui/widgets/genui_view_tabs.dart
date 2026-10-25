import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_control_region.dart';
import 'genui_segments.dart';

/// Existing app segments with one keyboard focus stop and directional selection.
class GenUiViewTabs extends StatefulWidget {
  const GenUiViewTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.enabled,
    required this.onChanged,
  });
  final List<String> labels;
  final int index;
  final bool enabled;
  final ValueChanged<int> onChanged;
  @override
  State<GenUiViewTabs> createState() => _GenUiViewTabsState();
}

class _GenUiViewTabsState extends State<GenUiViewTabs> {
  final _focus = FocusNode(debugLabel: 'GenUI view tabs');
  bool _showFocus = false;
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (!widget.enabled || event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final int? next = switch (key) {
      LogicalKeyboardKey.arrowLeft => widget.index + (rtl ? 1 : -1),
      LogicalKeyboardKey.arrowRight => widget.index + (rtl ? -1 : 1),
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => widget.labels.length - 1,
      _ => null,
    };
    if (next == null) return KeyEventResult.ignored;
    widget.onChanged(next.clamp(0, widget.labels.length - 1));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return GenUiControlRegion(
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: _key,
        child: FocusableActionDetector(
          focusNode: _focus,
          enabled: widget.enabled,
          onShowFocusHighlight: (value) => setState(() => _showFocus = value),
          child: GenUiSegments(
            labels: widget.labels,
            index: widget.index,
            enabled: widget.enabled,
            focused: _showFocus,
            onChanged: (index) {
              _focus.requestFocus();
              widget.onChanged(index);
            },
          ),
        ),
      ),
    );
  }
}
