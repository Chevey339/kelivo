import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;

import '../../../icons/lucide_adapter.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/plain_text_input.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
import '../../../theme/app_semantic_colors.dart';

/// The desktop tab can be mounted directly in the window, outside a Scaffold.
class CreationSurface extends StatelessWidget {
  const CreationSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = theme.textTheme.bodyMedium!.copyWith(
      color: cs.onSurface,
      fontSize: 14,
      height: 1.35,
      letterSpacing: 0,
      decoration: TextDecoration.none,
    );
    return Material(
      type: MaterialType.transparency,
      textStyle: style,
      child: TooltipTheme(
        data: TooltipThemeData(
          waitDuration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: cs.onSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: style.copyWith(color: cs.surface, fontSize: 12),
          constraints: const BoxConstraints(minHeight: 0),
        ),
        child: IconTheme(
          data: IconThemeData(color: cs.onSurface, size: 18),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: theme.brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: ColoredBox(color: cs.surface, child: child),
          ),
        ),
      ),
    );
  }
}

/// The floating composer includes its bottom safe area in this extent.
class CreationDockInset extends InheritedWidget {
  const CreationDockInset({
    super.key,
    required this.height,
    required super.child,
  });
  final double height;

  static double bottomOf(BuildContext context, double minimum) {
    final dock = context
        .dependOnInheritedWidgetOfExactType<CreationDockInset>();
    return dock == null || dock.height + 8 < minimum
        ? minimum
        : dock.height + 8;
  }

  @override
  bool updateShouldNotify(CreationDockInset oldWidget) =>
      height != oldWidget.height;
}

/// Fades controls without changing the measured size of their row or tile.
class CreationHoverActions extends StatelessWidget {
  const CreationHoverActions({
    super.key,
    required this.visible,
    required this.child,
  });
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeFocus(
    excluding: !visible,
    child: ExcludeSemantics(
      excluding: !visible,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: handoffDuration(context, 160),
          curve: Curves.easeInOut,
          child: child,
        ),
      ),
    ),
  );
}

class CreationSearchBox extends StatefulWidget {
  const CreationSearchBox({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.mobile = false,
  });
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus, mobile;
  @override
  State<CreationSearchBox> createState() => _CreationSearchBoxState();
}

class _CreationSearchBoxState extends State<CreationSearchBox> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (value) => setState(() => _focused = value),
      child: SizedBox(
        height: widget.mobile ? 40 : 34,
        child: PlainTextInput(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          placeholder: widget.hint,
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(fontSize: widget.mobile ? 14 : 13),
          decoration: BoxDecoration(
            color: context.appColors.surfaceFill,
            border: Border.all(
              width: 1.5,
              color: _focused && !widget.mobile
                  ? cs.primary
                  : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(widget.mobile ? 20 : 11),
          ),
          padding: const EdgeInsetsDirectional.only(start: 8, end: 10),
          prefix: Padding(
            padding: const EdgeInsetsDirectional.only(start: 10),
            child: Icon(
              Lucide.Search,
              size: 16,
              color: cs.onSurface.withValues(alpha: .48),
            ),
          ),
        ),
      ),
    );
  }
}

class CreationMobileBar extends StatelessWidget {
  const CreationMobileBar({
    super.key,
    required this.leading,
    required this.title,
    this.trailing,
    this.searching = false,
  });
  final Widget leading, title;
  final Widget? trailing;
  final bool searching;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          SizedBox(width: 44, child: leading),
          Expanded(child: searching ? title : Center(child: title)),
          SizedBox(width: searching ? 6 : 44, child: trailing),
        ],
      ),
    ),
  );
}

enum CreationActionTone { ghost, tonal, primary, danger }

class CreationAction extends StatelessWidget {
  const CreationAction({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.tone = CreationActionTone.ghost,
    this.small = false,
    this.pill = false,
    this.foreground,
    this.fill,
    this.minHeight,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final CreationActionTone tone;
  final bool small, pill;
  final Color? foreground, fill;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color =
        foreground ??
        switch (tone) {
          CreationActionTone.primary => cs.onPrimary,
          CreationActionTone.danger => cs.error,
          CreationActionTone.tonal => pill ? cs.onSurface : cs.primary,
          CreationActionTone.ghost => cs.onSurfaceVariant,
        };
    final background =
        fill ??
        switch (tone) {
          CreationActionTone.primary => cs.primary,
          CreationActionTone.tonal =>
            cs.brightness == Brightness.dark && pill
                ? cs.onSurface.withValues(alpha: .08)
                : cs.primary.withValues(alpha: .09),
          _ => Colors.transparent,
        };
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Opacity(
        opacity: onPressed == null ? .45 : 1,
        child: IosCardPress(
          focusable: true,
          onTap: onPressed,
          baseColor: background,
          pressedScale: .98,
          duration: handoffDuration(context, 140),
          borderRadius: BorderRadius.circular(
            pill
                ? 16
                : small
                ? 9
                : 11,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: small ? 10 : 12,
            vertical: pill
                ? 8
                : small
                ? 4
                : 6,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minHeight == null ? 0 : minHeight! - 12,
            ),
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: small ? 12.5 : 13,
                fontWeight: pill ? FontWeight.w500 : FontWeight.w600,
                color: color,
                height: 1.35,
                decoration: TextDecoration.none,
                letterSpacing: 0,
              ),
              child: IconTheme(
                data: IconThemeData(size: small ? 14 : 16, color: color),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[icon!, const SizedBox(width: 6)],
                    Flexible(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CreationSpinner extends StatelessWidget {
  const CreationSpinner({super.key, this.radius = 9, this.color});
  final double radius;
  final Color? color;
  @override
  Widget build(BuildContext context) => CupertinoActivityIndicator(
    radius: radius,
    color: color,
    animating: !MediaQuery.disableAnimationsOf(context),
  );
}
