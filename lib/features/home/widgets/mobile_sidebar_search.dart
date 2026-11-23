import 'package:flutter/material.dart';

import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';

class MobileSidebarSearch extends StatefulWidget {
  const MobileSidebarSearch({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.swipeTip,
    required this.globalSearch,
    required this.onToggleMode,
    required this.onSubmit,
    this.historyButton,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final String swipeTip;
  final bool globalSearch;
  final VoidCallback onToggleMode;
  final VoidCallback onSubmit;
  final Widget? historyButton;

  @override
  State<MobileSidebarSearch> createState() => _MobileSidebarSearchState();
}

class _MobileSidebarSearchState extends State<MobileSidebarSearch> {
  double _swipe = 0;
  bool _switched = false;

  void _toggleMode() {
    widget.onToggleMode();
    Haptics.light();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final empty = widget.controller.text.trim().isEmpty;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: empty
                    ? (_) {
                        _swipe = 0;
                        _switched = false;
                      }
                    : null,
                onHorizontalDragUpdate: empty
                    ? (details) {
                        if (_switched) return;
                        _swipe += details.delta.dx;
                        if (_swipe.abs() >= 18) {
                          _switched = true;
                          _toggleMode();
                        }
                      }
                    : null,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TextField(
                      focusNode: widget.focusNode,
                      controller: widget.controller,
                      textInputAction: widget.globalSearch
                          ? TextInputAction.search
                          : TextInputAction.done,
                      onSubmitted: widget.globalSearch
                          ? (_) => widget.onSubmit()
                          : null,
                      decoration: InputDecoration(
                        hintText: empty ? '' : widget.hint,
                        filled: true,
                        fillColor: context.appColors.surfaceFill.withValues(
                          alpha: .8,
                        ),
                        isDense: true,
                        isCollapsed: true,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 6, right: 2),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _toggleMode,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 210),
                                switchInCurve: Curves.easeOutBack,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      ),
                                    ),
                                child: Icon(
                                  widget.globalSearch
                                      ? Lucide.Database
                                      : Lucide.botMessageSquare,
                                  key: ValueKey(widget.globalSearch),
                                  color: cs.onSurface.withValues(alpha: .72),
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(),
                        suffixIcon:
                            widget.globalSearch &&
                                widget.controller.text.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: IosIconButton(
                                  size: 16,
                                  padding: const EdgeInsets.all(4),
                                  color: cs.onSurface.withValues(alpha: .75),
                                  icon: Lucide.Search,
                                  onTap: widget.onSubmit,
                                ),
                              )
                            : null,
                        suffixIconConstraints: const BoxConstraints(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: border,
                        enabledBorder: border,
                        focusedBorder: border,
                      ),
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(color: cs.onSurface, fontSize: 14),
                    ),
                    if (empty)
                      IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            widget.hint,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: .55),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.historyButton != null) ...[
              const SizedBox(width: 4),
              widget.historyButton!,
            ],
          ],
        ),
        const SizedBox(height: 6),
        ListenableBuilder(
          listenable: widget.focusNode,
          builder: (context, _) => AnimatedSize(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: widget.focusNode.hasFocus
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        widget.swipeTip,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: AppFontWeights.medium,
                          color: cs.onSurface.withValues(alpha: .52),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
