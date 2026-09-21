import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_semantic_colors.dart';

/// Read the live origin again on dismissal, including after rotation.
typedef SettingsSearchOrigin = Rect? Function();

const settingsSearchFieldRadius = BorderRadius.all(Radius.circular(18));

double settingsSearchFieldHeight(BuildContext context) =>
    math.max(40, MediaQuery.textScalerOf(context).scale(15) * 1.25 + 16);

/// Shared geometry for the resting entry and the moving, editable search field.
class SettingsSearchField extends StatelessWidget {
  const SettingsSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.reveal = 1,
    this.editing = const AlwaysStoppedAnimation(1),
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final double reveal;
  final Animation<double> editing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final height = settingsSearchFieldHeight(context);
    final muted = cs.onSurface.withValues(alpha: 0.45);
    final style = TextStyle(fontSize: 15, height: 1.25, color: cs.onSurface);
    final hintStyle = style.copyWith(color: muted);
    final contentOpacity = const Interval(
      0.55,
      1,
      curve: Curves.easeOut,
    ).transform(reveal);
    final placeholder = Text(
      l10n.settingsSearchHint,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: hintStyle,
    );
    final hasText = controller?.text.isNotEmpty ?? false;
    // A query and the resting hint must not overlap while the field returns.
    // An empty input can crossfade directly because both hints are identical.
    final inputOpacity = hasText
        ? editing.drive(CurveTween(curve: const Interval(0.5, 1)))
        : editing;
    final placeholderOpacity = hasText
        ? ReverseAnimation(
            editing,
          ).drive(CurveTween(curve: const Interval(0.5, 1)))
        : ReverseAnimation(editing);

    return ClipRRect(
      borderRadius: settingsSearchFieldRadius,
      child: SizedBox(
        key: const ValueKey('settings-search-field-surface'),
        height: height * reveal,
        child: ColoredBox(
          color: context.appColors.surfaceCardFill,
          child: OverflowBox(
            minHeight: height,
            maxHeight: height,
            child: Opacity(
              key: const ValueKey('settings-search-field-content'),
              opacity: contentOpacity,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 13, right: 8),
                    child: Icon(LucideIcons.search, size: 18, color: muted),
                  ),
                  Expanded(
                    child: controller == null
                        ? placeholder
                        : Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              FadeTransition(
                                opacity: inputOpacity,
                                child: TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  textInputAction: TextInputAction.search,
                                  autocorrect: false,
                                  onChanged: onChanged,
                                  onSubmitted: onSubmitted,
                                  style: style,
                                  textAlignVertical: TextAlignVertical.center,
                                  decoration: InputDecoration(
                                    // The surrounding field owns its height;
                                    // desktop compact density shifts the baseline.
                                    visualDensity: VisualDensity.standard,
                                    hintText: l10n.settingsSearchHint,
                                    hintStyle: hintStyle,
                                    isDense: true,
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              IgnorePointer(
                                child: FadeTransition(
                                  opacity: placeholderOpacity,
                                  child: placeholder,
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (hasText)
                    FadeTransition(
                      opacity: inputOpacity,
                      child: IosIconButton(
                        icon: LucideIcons.circleX,
                        size: 16,
                        minSize: 40,
                        tooltip: l10n.settingsSearchClear,
                        semanticLabel: l10n.settingsSearchClear,
                        color: muted,
                        onTap: onClear,
                      ),
                    )
                  else
                    const SizedBox(width: 13),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
