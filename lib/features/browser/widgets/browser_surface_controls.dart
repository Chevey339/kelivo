import '../../../theme/app_semantic_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'browser_text_field.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassAccessibilityData;

import '../../../l10n/app_localizations.dart';
import 'browser_glass.dart';
import 'browser_scroll_configuration.dart';
import '../models/browser_models.dart';
import 'browser_switch_lens.dart';

bool _desktopControls(BuildContext context) =>
    switch (Theme.of(context).platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };

/// Management controls use a stationary fill for feedback. There is no press
/// transform or drag recognizer, so a list remains steady under the pointer.
class BrowserSurfaceButton extends StatefulWidget {
  const BrowserSurfaceButton({
    super.key,
    required this.child,
    this.onPressed,
    this.semanticLabel,
    this.selected = false,
    this.radius = 16,
    this.borderRadius,
    this.onFocusChanged,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final bool selected;
  final double radius;
  final BorderRadius? borderRadius;
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<BrowserSurfaceButton> createState() => _BrowserSurfaceButtonState();
}

class _BrowserSurfaceButtonState extends State<BrowserSurfaceButton> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;
  int? _pointer;
  bool _childOwnsTap = false;
  final Set<int> _childPointers = {};
  _BrowserSurfaceButtonState? _ancestor;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  void _claimChild(int pointer) {
    _childPointers.add(pointer);
    if (_pointer == null || _pointer == pointer) {
      _childOwnsTap = true;
      _setPressed(false);
    }
    _ancestor?._claimChild(pointer);
  }

  void _pointerDown(PointerDownEvent event) {
    _ancestor?._claimChild(event.pointer);
    if (_pointer != null) return;
    _pointer = event.pointer;
    _childOwnsTap = _childPointers.contains(event.pointer);
  }

  void _pointerEnded(PointerEvent event) {
    _childPointers.remove(event.pointer);
    if (_pointer == event.pointer) {
      _pointer = null;
      _setPressed(false);
      // Keep ownership through the recognizer's later tap callback. The next
      // down resets it, including when a disabled child has no tap recognizer.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    _ancestor = _BrowserSurfacePressScope.ownerOf(context);
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      selected: widget.selected,
      label: widget.semanticLabel,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        enabled: widget.onPressed != null,
        mouseCursor: SystemMouseCursors.basic,
        onFocusChange: widget.onFocusChanged,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.onPressed == null
              ? null
              : () {
                  if (!_childOwnsTap) widget.onPressed!();
                },
          onTapDown: widget.onPressed == null
              ? null
              : (_) => _setPressed(!_childOwnsTap),
          onTapCancel: widget.onPressed == null
              ? null
              : () => _setPressed(false),
          onTapUp: widget.onPressed == null ? null : (_) => _setPressed(false),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _pointerDown,
            onPointerUp: _pointerEnded,
            onPointerCancel: _pointerEnded,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(
                  alpha: _pressed ? .09 : (_hovered ? .035 : 0),
                ),
                borderRadius:
                    widget.borderRadius ?? BorderRadius.circular(widget.radius),
                border: _focused
                    ? Border.all(color: colors.primary, width: 1.5)
                    : null,
              ),
              child: _BrowserSurfacePressScope(
                owner: this,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Child controls claim only visual/activation ownership, without intercepting
/// the pointer or entering another gesture arena. Scrolling remains untouched.
class _BrowserSurfacePressScope extends InheritedWidget {
  const _BrowserSurfacePressScope({required this.owner, required super.child});
  final _BrowserSurfaceButtonState owner;
  static _BrowserSurfaceButtonState? ownerOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_BrowserSurfacePressScope>()?.owner;
  @override
  bool updateShouldNotify(_BrowserSurfacePressScope oldWidget) =>
      owner != oldWidget.owner;
}

class _BrowserControlBoundary extends StatelessWidget {
  const _BrowserControlBoundary({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) =>
        _BrowserSurfacePressScope.ownerOf(context)?._claimChild(event.pointer),
    child: child,
  );
}

class BrowserSurfaceIconButton extends StatelessWidget {
  const BrowserSurfaceIconButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.size = 38,
    this.iconSize = 19,
    this.backgroundColor,
    this.foregroundColor,
    this.surface = false,
    this.pressMotion = true,
    this.useParentFeedback = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size, iconSize;
  final Color? backgroundColor, foregroundColor;
  final bool surface, pressMotion;

  /// A grouped icon shares its capsule's press response and material.
  final bool useParentFeedback;

  @override
  Widget build(BuildContext context) {
    final moving = pressMotion && !_desktopControls(context);
    final iconWidget = Icon(
      icon,
      size: iconSize,
      color:
          foregroundColor ??
          Theme.of(context).colorScheme.onSurface.withValues(
            alpha: onPressed == null ? .38 : 1,
          ),
    );
    Widget content = SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: moving && !surface && !useParentFeedback
            ? BrowserControlFeedback(
                radius: 1000,
                child: Center(child: iconWidget),
              )
            : Center(child: iconWidget),
      ),
    );
    if (useParentFeedback) {
      return Tooltip(
        message: label,
        triggerMode: TooltipTriggerMode.manual,
        child: Semantics(
          label: label,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            pressedOpacity: 1,
            borderRadius: BorderRadius.circular(1000),
            onPressed: onPressed,
            child: content,
          ),
        ),
      );
    }
    if (surface) content = BrowserGlass(radius: 1000, child: content);
    return Tooltip(
      message: label,
      triggerMode: moving ? TooltipTriggerMode.manual : null,
      child: moving
          ? _BrowserControlBoundary(
              child: BrowserPress(
                enabled: onPressed != null,
                semanticLabel: label,
                onTap: onPressed,
                draggable: surface || backgroundColor != null,
                child: content,
              ),
            )
          : BrowserSurfaceButton(
              onPressed: onPressed,
              semanticLabel: label,
              radius: size / 2,
              child: content,
            ),
    );
  }
}

/// Adjacent icon targets share one material and one press response, matching
/// the browser navigation capsule. Children use [BrowserSurfaceIconButton]'s
/// [BrowserSurfaceIconButton.useParentFeedback] mode to avoid nested surfaces.
class BrowserSurfaceIconGroup extends StatelessWidget {
  const BrowserSurfaceIconGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => BrowserPress(
    draggable: !_desktopControls(context),
    child: BrowserGlass(
      radius: 1000,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}

/// Controls belonging to the browser's material system. They intentionally do
/// not inherit the app's Material ink or the older iOS press-decoration widgets.
class BrowserTextButton extends StatelessWidget {
  const BrowserTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.destructive = false,
    this.filled = false,
    this.foregroundColor,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.opacity = 1,
  }) : assert(opacity >= 0 && opacity <= 1);

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final bool destructive;
  final bool filled;
  final Color? foregroundColor, backgroundColor;
  final EdgeInsetsGeometry padding;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color =
        foregroundColor ?? (destructive ? colors.error : colors.onSurface);
    final content = Padding(
      padding: padding,
      child: IconTheme(
        data: IconThemeData(color: color, size: 18),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: color.withValues(alpha: onPressed == null ? .38 : 1),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
    final surface = backgroundColor != null
        ? Opacity(
            opacity: opacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(28),
              ),
              child: BrowserControlFeedback(radius: 28, child: content),
            ),
          )
        : filled
        ? BrowserGlass(
            radius: 28,
            elevated: false,
            opacity: opacity,
            child: content,
          )
        : Opacity(opacity: opacity, child: content);
    if (!_desktopControls(context)) {
      return _BrowserControlBoundary(
        child: BrowserPress(
          enabled: onPressed != null,
          onTap: onPressed,
          draggable: filled || backgroundColor != null,
          child: filled || backgroundColor != null
              ? surface
              : BrowserControlFeedback(radius: 28, child: surface),
        ),
      );
    }
    return BrowserSurfaceButton(
      onPressed: onPressed,
      radius: 28,
      child: surface,
    );
  }
}

class BrowserSurfaceField extends StatelessWidget {
  const BrowserSurfaceField({
    super.key,
    required this.controller,
    this.focusNode,
    this.label,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType = TextInputType.text,
    this.autofocus = false,
    this.autocorrect = false,
    this.maxLines = 1,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType keyboardType;
  final bool autofocus;
  final bool autocorrect;
  final int maxLines;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final desktop = _desktopControls(context);
    final appTextStyle = Theme.of(context).textTheme.bodyMedium!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              label!,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.onSurface.withValues(alpha: .055),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.onSurface.withValues(alpha: .07),
              width: .5,
            ),
          ),
          child: BrowserTextField(
            controller: controller,
            focusNode: focusNode,
            placeholder: hintText,
            autofocus: autofocus,
            autocorrect: autocorrect,
            enableSuggestions: keyboardType != TextInputType.url,
            keyboardType: keyboardType,
            textInputAction: onSubmitted == null
                ? TextInputAction.done
                : TextInputAction.go,
            maxLines: maxLines,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: desktop ? 8 : 14,
            ),
            style: TextStyle(
              fontFamily: appTextStyle.fontFamily,
              fontFamilyFallback: appTextStyle.fontFamilyFallback,
              color: colors.onSurface,
              fontSize: desktop ? 13 : 16,
            ),
            placeholderStyle: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: desktop ? 13 : 16,
            ),
            cursorColor: colors.primary,
            prefix: prefixIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Icon(
                      prefixIcon,
                      size: desktop ? 16 : 19,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class BrowserSurfaceGroup extends StatelessWidget {
  const BrowserSurfaceGroup({
    super.key,
    required this.children,
    this.filled = true,
  });

  final List<Widget> children;

  /// Rows inside an existing glass dialog inherit that one material surface.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final desktop = _desktopControls(context);
    final contrast = MediaQuery.highContrastOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: !filled
              ? Colors.transparent
              : desktop
              ? colors.onSurface.withValues(alpha: .035)
              : context.appColors.surfaceCard,
          borderRadius: BorderRadius.circular(26),
          border: filled && (desktop || contrast)
              ? Border.all(
                  color: colors.onSurface.withValues(
                    alpha: contrast ? .6 : .055,
                  ),
                  width: contrast ? 1 : .5,
                )
              : null,
        ),
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Divider(
                    height: .5,
                    thickness: .5,
                    color: colors.onSurface.withValues(alpha: .08),
                  ),
                ),
              _BrowserRowShape(
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(26) : Radius.zero,
                  bottom: index == children.length - 1
                      ? const Radius.circular(26)
                      : Radius.zero,
                ),
                child: children[index],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BrowserRowShape extends InheritedWidget {
  const _BrowserRowShape({required this.borderRadius, required super.child});
  final BorderRadius borderRadius;
  static BorderRadius? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_BrowserRowShape>()
      ?.borderRadius;
  @override
  bool updateShouldNotify(_BrowserRowShape oldWidget) =>
      borderRadius != oldWidget.borderRadius;
}

class BrowserSurfaceRow extends StatelessWidget {
  const BrowserSurfaceRow({
    super.key,
    required this.label,
    this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = destructive ? colors.error : colors.onSurface;
    final desktop = _desktopControls(context);
    final row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 17,
        vertical: desktop ? 10 : 16,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: desktop ? 18 : 22, color: foreground),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: desktop ? 13 : 15,
                    color: foreground,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 14), trailing!],
        ],
      ),
    );
    return onTap == null
        ? row
        : BrowserSurfaceButton(
            onPressed: onTap,
            semanticLabel: label,
            borderRadius: _BrowserRowShape.of(context),
            child: row,
          );
  }
}

class BrowserSwitch extends StatefulWidget {
  const BrowserSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  State<BrowserSwitch> createState() => _BrowserSwitchState();
}

class _BrowserSwitchState extends State<BrowserSwitch>
    with TickerProviderStateMixin {
  AnimationController? _positionController;
  AnimationController get _position =>
      _positionController ??= AnimationController(
        vsync: this,
        value: widget.value ? 1 : 0,
        duration: const Duration(milliseconds: 220),
      );
  AnimationController? _pressController;
  AnimationController get _press => _pressController ??= AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );
  bool _dragging = false;
  bool _pointerCancelled = false;
  bool _focused = false;
  bool _active = true;
  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  @override
  void deactivate() {
    _active = false;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
  }

  @override
  void didUpdateWidget(BrowserSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging &&
        oldWidget.value != widget.value &&
        _positionController != null) {
      _settle(widget.value);
    }
    if (widget.onChanged == null && _dragging) _cancel();
  }

  void _settle(bool value) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = value ? 1 : 0;
    } else {
      _position.animateTo(value ? 1 : 0, curve: Curves.easeOutCubic);
    }
  }

  void _commit(bool value) {
    if (!_active || !mounted) return;
    _dragging = false;
    _press.reverse();
    _settle(value);
    if (value != widget.value) widget.onChanged?.call(value);
  }

  void _cancel() {
    if (!_active || !mounted) return;
    _dragging = false;
    _press.reverse();
    _settle(widget.value);
  }

  void _releasePress() {
    if (_active && mounted) _pressController?.reverse();
  }

  @override
  void dispose() {
    _positionController?.dispose();
    _pressController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final desktop = _desktopControls(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);
    if (!desktop) return _mobile(context);
    return Semantics(
      label: widget.semanticLabel,
      toggled: widget.value,
      enabled: widget.onChanged != null,
      child: BrowserSurfaceButton(
        onPressed: widget.onChanged == null
            ? null
            : () => widget.onChanged!(!widget.value),
        child: SizedBox(
          width: desktop ? 40 : 56,
          height: desktop ? 32 : 44,
          child: Center(
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              width: desktop ? 36 : 54,
              height: desktop ? 22 : 32,
              padding: EdgeInsets.all(desktop ? 2 : 3),
              decoration: BoxDecoration(
                color: widget.value
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedAlign(
                duration: duration,
                curve: Curves.easeOutCubic,
                alignment: widget.value
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: desktop ? 18 : 27,
                  height: desktop ? 18 : 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xffeeeeee)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x25000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobile(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = widget.onChanged != null;
    final reduced = MediaQuery.disableAnimationsOf(context);
    void activate() => _commit(!widget.value);
    return _BrowserControlBoundary(
      child: Semantics(
        label: widget.semanticLabel,
        toggled: widget.value,
        enabled: enabled,
        onTap: enabled ? activate : null,
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor: SystemMouseCursors.basic,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                activate();
                return null;
              },
            ),
          },
          child: Listener(
            onPointerDown: enabled
                ? (_) {
                    _pointerCancelled = false;
                    _press.forward();
                  }
                : null,
            onPointerCancel: enabled
                ? (_) {
                    // An accepted Flutter drag can end through onDragEnd on cancel.
                    // Preserve the external value rather than committing that position.
                    _pointerCancelled = true;
                    _cancel();
                  }
                : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              dragStartBehavior: DragStartBehavior.down,
              onTap: enabled ? activate : null,
              onTapCancel: enabled && !_dragging ? _releasePress : null,
              onHorizontalDragStart: enabled
                  ? (_) {
                      _dragging = true;
                      _position.stop();
                      _press.forward();
                    }
                  : null,
              onHorizontalDragUpdate: enabled
                  ? (details) {
                      _position.value =
                          (_position.value +
                                  details.delta.dx / 18 * (_rtl ? -1 : 1))
                              .clamp(0, 1);
                    }
                  : null,
              onHorizontalDragEnd: enabled
                  ? (details) {
                      if (_pointerCancelled) return;
                      final velocity =
                          (details.primaryVelocity ?? 0) * (_rtl ? -1 : 1);
                      _commit(
                        velocity.abs() > 180
                            ? velocity > 0
                            : _position.value >= .5,
                      );
                    }
                  : null,
              onHorizontalDragCancel: enabled ? _cancel : null,
              child: SizedBox(
                width: 64,
                height: 44,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_position, _press]),
                  builder: (context, _) {
                    final position = _rtl
                        ? 1 - _position.value
                        : _position.value;
                    final pressed = reduced ? 0.0 : _press.value;
                    // Glass-HQ: 54×24 static track, 32×20 idle face. The clear
                    // lens grows by 9 / 5.5 points on each side while pressed.
                    final thumbWidth = 32 + 18 * pressed;
                    final thumbHeight = 20 + 11 * pressed;
                    final opaque =
                        MediaQuery.highContrastOf(context) ||
                        GlassAccessibilityData.of(context).reduceTransparency ||
                        BrowserGlassScope.of(context) ==
                            BrowserSurfaceStyle.solid;
                    return Opacity(
                      opacity: enabled ? 1 : .4,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            key: const ValueKey('browserSwitchTrack'),
                            width: 54,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                colors.onSurface.withValues(alpha: .22),
                                colors.primary,
                                _position.value,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: _focused
                                  ? Border.all(color: colors.primary, width: 2)
                                  : null,
                            ),
                          ),
                          Positioned(
                            left: 23 + 18 * position - thumbWidth / 2,
                            top: 22 - thumbHeight / 2,
                            width: thumbWidth,
                            height: thumbHeight,
                            child: DecoratedBox(
                              key: const ValueKey('browserSwitchThumb'),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .14),
                                    blurRadius: 3 + 5 * pressed,
                                    blurStyle: BlurStyle.outer,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: BrowserSwitchLens(
                                progress: pressed,
                                opaque: opaque,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BrowserDialogHeader extends StatelessWidget {
  const BrowserDialogHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      22,
      _desktopControls(context) ? 8 : 14,
      12,
      _desktopControls(context) ? 6 : 12,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: _desktopControls(context) ? 17 : 21,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        BrowserSurfaceIconButton(
          label: AppLocalizations.of(context)!.browserClose,
          icon: LucideIcons.x,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

Future<T?> showBrowserDialog<T>(
  BuildContext context, {
  required Widget child,
  double maxWidth = 460,
}) {
  final style = BrowserGlassScope.of(context);
  final themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context, rootNavigator: true).context,
  );
  final reducedMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: AppLocalizations.of(context)!.browserClose,
    barrierColor: Colors.black.withValues(alpha: .16),
    transitionDuration: Duration(milliseconds: reducedMotion ? 0 : 260),
    pageBuilder: (context, _, __) => themes.wrap(
      BrowserScrollConfiguration(
        child: BrowserGlassScope(
          style: style,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: BrowserGlass(
                    radius: 34,
                    child: DefaultTextStyle(
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      child: SingleChildScrollView(child: child),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    // Native glass must sample the live backdrop without an intermediate
    // opacity layer. Only its position is animated.
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, .035),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}
