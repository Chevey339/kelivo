import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../search/settings_search_index.dart';
import 'settings_search_action.dart';
import 'settings_search_field.dart';

/// The input stays mounted while its bounds move from the entry to the top.
/// The presentation layers animate while the lazy result list stays mounted.
class SettingsSearchView extends StatefulWidget {
  const SettingsSearchView({
    super.key,
    required this.index,
    required this.onSelected,
    required this.onClose,
    this.autofocus = true,
    this.transition = const AlwaysStoppedAnimation(1),
    this.origin,
    this.safeAreaInsets = EdgeInsets.zero,
    this.backgroundColor,
  });

  final SettingsSearchIndex index;
  final ValueChanged<SettingsSearchItem> onSelected;
  final VoidCallback onClose;
  final bool autofocus;
  final Animation<double> transition;
  final SettingsSearchOrigin? origin;
  final EdgeInsets safeAreaInsets;
  final Color? backgroundColor;

  @override
  State<SettingsSearchView> createState() => _SettingsSearchViewState();
}

class _SettingsSearchViewState extends State<SettingsSearchView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  late CurvedAnimation _motion;
  List<SettingsSearchItem> _results = const [];
  bool _focusRequested = false;
  bool _closing = false;

  bool get _hasQuery => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _motion = CurvedAnimation(
      parent: widget.transition,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    widget.transition.addListener(_onTransition);
    _focusNode.onKeyEvent = (_, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowDown &&
          _controller.value.composing.isCollapsed) {
        FocusScope.of(context).nextFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    _onTransition();
  }

  void _onTransition() {
    if (widget.transition.status == AnimationStatus.reverse) {
      _closing = true;
      _focusNode.unfocus();
      return;
    }
    if (widget.autofocus &&
        !_focusRequested &&
        widget.transition.value >= 0.45) {
      _focusRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_closing) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(SettingsSearchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _results = widget.index.search(_controller.text);
    }
    if (widget.transition != oldWidget.transition) {
      oldWidget.transition.removeListener(_onTransition);
      _motion.dispose();
      _motion = CurvedAnimation(
        parent: widget.transition,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      widget.transition.addListener(_onTransition);
      _onTransition();
    }
  }

  @override
  void dispose() {
    widget.transition.removeListener(_onTransition);
    _motion.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _search(String query) {
    setState(() => _results = widget.index.search(query));
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _submit(String query) {
    final results = widget.index.search(query);
    if (results.isNotEmpty) _open(results.first);
  }

  void _open(SettingsSearchItem item) {
    _focusNode.unfocus();
    widget.onSelected(item);
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _focusNode.unfocus();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final items = _hasQuery ? _results : widget.index.suggestions;
    final cancelStyle = DefaultTextStyle.of(
      context,
    ).style.merge(TextStyle(fontSize: 15, height: 1.25, color: cs.primary));
    final cancelText = TextPainter(
      text: TextSpan(text: l10n.settingsSearchCancel, style: cancelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final cancelWidth = math.max(44.0, cancelText.width + 16);
    cancelText.dispose();
    final fieldHeight = settingsSearchFieldHeight(context);
    final insets = widget.safeAreaInsets;
    final top = insets.top + 8;

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: LayoutBuilder(
        builder: (context, constraints) {
          final target = Rect.fromLTWH(
            insets.left + 16,
            top,
            math.max(
              0,
              constraints.maxWidth - insets.horizontal - 32 - cancelWidth - 8,
            ),
            fieldHeight,
          );
          return AnimatedBuilder(
            animation: _motion,
            child: _buildResults(context, items),
            builder: (context, results) {
              final progress = _motion.value;
              final origin = widget.origin?.call();
              final rect = Rect.lerp(origin ?? target, target, progress)!;
              final backgroundOpacity = const Interval(
                0,
                0.65,
                curve: Curves.easeOut,
              ).transform(progress);
              final contentOpacity = const Interval(
                0.45,
                1,
                curve: Curves.easeOut,
              ).transform(progress);
              return Stack(
                children: [
                  if (widget.backgroundColor != null)
                    Positioned.fill(
                      child: Opacity(
                        opacity: backgroundOpacity,
                        child: ColoredBox(color: widget.backgroundColor!),
                      ),
                    ),
                  // Cover the resting field locally while the editable one moves.
                  // Keeping the source laid out and painted avoids a blank frame
                  // when the modal overlay is finally removed on dismissal.
                  if (origin != null && widget.backgroundColor != null)
                    Positioned.fromRect(
                      rect: origin.inflate(0.5),
                      child: ColoredBox(color: widget.backgroundColor!),
                    ),
                  Positioned(
                    top: math.min(
                      top + fieldHeight + 14,
                      constraints.maxHeight,
                    ),
                    left: insets.left,
                    right: insets.right,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: progress < 1,
                      child: Opacity(
                        key: const ValueKey('settings-search-results'),
                        opacity: contentOpacity,
                        child: Transform.translate(
                          offset: Offset(0, 12 * (1 - progress)),
                          child: results,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: rect,
                    child: SettingsSearchField(
                      controller: _controller,
                      focusNode: _focusNode,
                      editing: progress,
                      onChanged: _search,
                      onSubmitted: _submit,
                      onClear: () {
                        _controller.clear();
                        _search('');
                        _focusNode.requestFocus();
                      },
                    ),
                  ),
                  Positioned(
                    top: top,
                    right: insets.right + 12,
                    width: cancelWidth + 4,
                    height: fieldHeight,
                    child: IgnorePointer(
                      ignoring: progress < 0.15,
                      child: Opacity(
                        opacity: progress,
                        child: IosIconButton(
                          builder: (color) => Text(
                            l10n.settingsSearchCancel,
                            style: cancelStyle.copyWith(color: color),
                          ),
                          color: cs.primary,
                          minSize: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onTap: _close,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildResults(BuildContext context, List<SettingsSearchItem> items) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.searchX,
                    size: 30,
                    color: cs.onSurface.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.settingsSearchNoResults,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: AppFontWeights.medium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.settingsSearchNoResultsHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        24 + widget.safeAreaInsets.bottom,
      ),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
            child: Text(
              _hasQuery
                  ? l10n.settingsSearchResultCount(items.length)
                  : l10n.settingsSearchSuggestions,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          );
        }
        final item = items[index - 1];
        final radius = BorderRadius.vertical(
          top: index == 1 ? const Radius.circular(18) : Radius.zero,
          bottom: index == items.length
              ? const Radius.circular(18)
              : Radius.zero,
        );
        return ClipRRect(
          key: ValueKey(item.id),
          borderRadius: radius,
          child: ColoredBox(
            color: context.appColors.surfaceCard,
            child: Column(
              children: [
                Semantics(
                  button: true,
                  child: SettingsSearchAction(
                    onTap: () => _open(item),
                    borderRadius: radius,
                    child: IosNavRow(
                      icon: item.icon,
                      label: item.title,
                      labelWeight: AppFontWeights.medium,
                      subtitle: item.path.join(' › '),
                      subtitleMaxLines: null,
                      onTap: () => _open(item),
                    ),
                  ),
                ),
                if (index < items.length) const IosRowDivider(),
              ],
            ),
          ),
        );
      },
    );
  }
}
