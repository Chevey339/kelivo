import 'package:flutter/material.dart';

import '../../../core/services/haptics.dart';
import '../../../shared/widgets/plain_text_input.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
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

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(MobileSidebarSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_refresh);
      widget.focusNode.addListener(_refresh);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.focusNode.removeListener(_refresh);
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _toggleMode() {
    widget.onToggleMode();
    Haptics.light();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final empty = widget.controller.text.trim().isEmpty;
    final centered = empty && !widget.focusNode.hasFocus;
    final glyph = widget.globalSearch ? Lucide.Database : Lucide.Search;
    final modeButton = IosIconButton(
      icon: glyph,
      size: 16,
      minSize: 30,
      tooltip: widget.swipeTip,
      color: cs.onSurface.withValues(alpha: .55),
      onTap: _toggleMode,
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
                    SizedBox(
                      height: 44,
                      child: PlainTextInput(
                        focusNode: widget.focusNode,
                        controller: widget.controller,
                        textInputAction: widget.globalSearch
                            ? TextInputAction.search
                            : TextInputAction.done,
                        onSubmitted: widget.globalSearch
                            ? (_) => widget.onSubmit()
                            : null,
                        decoration: BoxDecoration(
                          color: context.appColors.surfaceFill.withValues(
                            alpha: .8,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                        placeholder: centered ? null : widget.hint,
                        prefix: centered
                            ? null
                            : Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: 6,
                                ),
                                child: modeButton,
                              ),
                        suffix:
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
                        style: TextStyle(color: cs.onSurface, fontSize: 14),
                      ),
                    ),
                    if (centered)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          modeButton,
                          Flexible(
                            child: GestureDetector(
                              onTap: widget.focusNode.requestFocus,
                              child: Text(
                                widget.hint,
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
            duration: handoffDuration(context, 140),
            curve: handoffCurve,
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
