import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/gestures.dart' show EagerGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../theme/custom_theme.dart';
import '../../../theme/palettes.dart';

bool get _isDesktop =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

// ---------------------------------------------------------------------------
// Presentation shells (match the app's custom sheet/dialog idioms — no
// default Material AlertDialog/FilledButton anywhere in this file).
// ---------------------------------------------------------------------------

/// Centered custom dialog: scrim barrier, fade+scale-in, rounded surface
/// container with a subtle border (same look as the desktop dialogs).
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required Widget child,
  double maxWidth = 420,
  bool dismissible = true,
  EdgeInsets insetPadding = const EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 24,
  ),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.25),
    pageBuilder: (ctx, _, __) {
      final cs = Theme.of(ctx).colorScheme;
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return PopScope(
        canPop: dismissible,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: dismissible ? () => Navigator.of(ctx).maybePop() : null,
          child: Material(
            type: MaterialType.transparency,
            child: Center(
              child: Padding(
                padding: insetPadding,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {},
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth,
                      maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                    ),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: ctx.overlaySurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isDark
                                ? cs.onSurface.withValues(alpha: 0.08)
                                : cs.outlineVariant.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Bottom sheet styled like the app's import/add sheets: drag handle,
/// centered title, close button, keyboard-aware padding.
Future<T?> _showAppSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: () {
            final mq = MediaQuery.of(ctx);
            return EdgeInsets.fromLTRB(
              16,
              10,
              16,
              10 + mq.padding.bottom + mq.viewInsets.bottom,
            );
          }(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: AppFontWeights.semibold,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IosIconButton(
                            icon: Lucide.X,
                            size: 20,
                            color: cs.onSurface.withValues(alpha: 0.62),
                            onTap: () => Navigator.of(ctx).maybePop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  child,
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Dialog header (desktop): title + close button.
class AppDialogHeader extends StatelessWidget {
  const AppDialogHeader({super.key, required this.title, this.actions});
  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: AppFontWeights.emphasis,
                ),
              ),
            ),
            ...?actions,
            IosIconButton(
              icon: Lucide.X,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.62),
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cancel/confirm action row built from [IosTileButton]s.
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.confirmLabel,
    required this.confirmIcon,
    required this.onConfirm,
    this.enabled = true,
    this.danger = false,
  });

  final String confirmLabel;
  final IconData confirmIcon;
  final VoidCallback onConfirm;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: IosTileButton(
            icon: Lucide.X,
            label: l10n.customThemeCancel,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: IosTileButton(
            icon: confirmIcon,
            label: confirmLabel,
            enabled: enabled,
            backgroundColor: danger ? cs.error : cs.primary,
            foregroundColor: danger ? cs.error : cs.primary,
            onTap: onConfirm,
          ),
        ),
      ],
    );
  }
}

/// Filled, rounded, bordered text-field decoration (same style as the
/// provider import sheet fields).
InputDecoration _fieldDecoration(
  BuildContext context, {
  String? hintText,
  String? errorText,
}) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hintText,
    errorText: errorText,
    hintStyle: TextStyle(
      fontSize: 14,
      color: cs.onSurface.withValues(alpha: isDark ? 0.42 : 0.46),
    ),
    isDense: true,
    filled: true,
    fillColor: context.appColors.surfaceCard,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: border(cs.outlineVariant.withValues(alpha: 0.4)),
    enabledBorder: border(cs.outlineVariant.withValues(alpha: 0.4)),
    focusedBorder: border(cs.primary.withValues(alpha: 0.5)),
    errorBorder: border(cs.error.withValues(alpha: 0.6)),
    focusedErrorBorder: border(cs.error),
  );
}

// ---------------------------------------------------------------------------
// Theme dot
// ---------------------------------------------------------------------------

/// Tri-color theme dot (secondary/tertiary container halves with a primary
/// center), like RikkaHub's custom theme list icon.
class CustomThemeDot extends StatelessWidget {
  const CustomThemeDot({
    super.key,
    required this.theme,
    this.size = 24,
    this.selected = false,
  });

  final CustomTheme theme;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = customThemeColorScheme(theme, dark: isDark);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ThemeDotPainter(
          primary: scheme.primary,
          secondary: scheme.secondaryContainer,
          tertiary: scheme.tertiaryContainer,
          selected: selected,
        ),
      ),
    );
  }
}

class _ThemeDotPainter extends CustomPainter {
  _ThemeDotPainter({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.selected,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final r = size.width / 2;
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    // Left half: secondary; right half: tertiary
    canvas.drawRect(
      Rect.fromLTWH(0, 0, r, size.height),
      Paint()..color = secondary,
    );
    canvas.drawRect(
      Rect.fromLTWH(r, 0, r, size.height),
      Paint()..color = tertiary,
    );
    canvas.restore();
    canvas.drawCircle(
      center,
      selected ? r * 0.55 : r * 0.42,
      Paint()..color = primary,
    );
  }

  @override
  bool shouldRepaint(covariant _ThemeDotPainter old) =>
      old.primary != primary ||
      old.secondary != secondary ||
      old.tertiary != tertiary ||
      old.selected != selected;
}

// ---------------------------------------------------------------------------
// HSV color picker
// ---------------------------------------------------------------------------

/// A drag region that claims the gesture arena immediately, so vertical
/// drags move the picker thumb instead of scrolling a surrounding sheet.
class _DragRegion extends StatelessWidget {
  const _DragRegion({required this.onDrag, required this.child});

  final ValueChanged<Offset> onDrag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        EagerGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
              EagerGestureRecognizer.new,
              (_) {},
            ),
      },
      child: Listener(
        onPointerDown: (e) => onDrag(e.localPosition),
        onPointerMove: (e) => onDrag(e.localPosition),
        child: child,
      ),
    );
  }
}

/// Full HSV color picker: saturation/value area, hue bar, hex input.
class HsvColorPicker extends StatefulWidget {
  const HsvColorPicker({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final Color initial;
  final ValueChanged<Color> onChanged;

  @override
  State<HsvColorPicker> createState() => _HsvColorPickerState();
}

class _HsvColorPickerState extends State<HsvColorPicker> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  late final TextEditingController _hexController;
  bool _hexEditing = false;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(text: _hexOf(_hsv.toColor()));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  static String _hexOf(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  void _update(HSVColor next, {bool fromHex = false}) {
    setState(() {
      _hsv = next;
      if (!fromHex) _hexController.text = _hexOf(next.toColor());
    });
    widget.onChanged(next.toColor());
  }

  void _submitHex(String value) {
    var s = value.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return;
    _update(HSVColor.fromColor(Color(v)), fromHex: true);
  }

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Saturation / value area
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            const h = 160.0;
            final tx = (_hsv.saturation * w).clamp(0.0, w);
            final ty = ((1 - _hsv.value) * h).clamp(0.0, h);
            void onPan(Offset p) {
              final s = (p.dx / w).clamp(0.0, 1.0);
              final v = (1 - p.dy / h).clamp(0.0, 1.0);
              _update(_hsv.withSaturation(s).withValue(v));
            }

            return _DragRegion(
              onDrag: onPan,
              child: SizedBox(
                height: h,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFFFFFFFF), hueColor],
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0xFF000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: tx - 9,
                        top: ty - 9,
                        child: IgnorePointer(
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _hsv.toColor(),
                              border: Border.all(
                                color: const Color(0xFFFFFFFF),
                                width: 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        // Hue bar
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            const h = 18.0;
            final tx = (_hsv.hue / 360 * w).clamp(0.0, w);
            void onPan(Offset p) {
              final hue = (p.dx / w).clamp(0.0, 1.0) * 360;
              _update(_hsv.withHue(hue >= 360 ? 359.999 : hue));
            }

            return _DragRegion(
              onDrag: onPan,
              child: SizedBox(
                height: h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(h / 2),
                        gradient: LinearGradient(
                          colors: [
                            for (var i = 0; i <= 6; i++)
                              HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor(),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: tx - 9,
                      child: IgnorePointer(
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hueColor,
                            border: Border.all(
                              color: const Color(0xFFFFFFFF),
                              width: 2.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        // Preview + hex input
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hsv.toColor(),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _hexController,
                style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                decoration: _fieldDecoration(context, hintText: '#RRGGBB'),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
                  LengthLimitingTextInputFormatter(7),
                ],
                onChanged: (_) => _hexEditing = true,
                onSubmitted: (v) {
                  _hexEditing = false;
                  _submitHex(v);
                },
                onTapOutside: (_) {
                  if (_hexEditing) {
                    _hexEditing = false;
                    _submitHex(_hexController.text);
                  }
                  FocusScope.of(context).unfocus();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Adaptive color picker (sheet on mobile, dialog on desktop).
Future<Color?> showAppColorPicker(
  BuildContext context, {
  required String title,
  required Color initial,
}) {
  var current = initial;
  final l10n = AppLocalizations.of(context)!;
  Widget content(BuildContext ctx) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HsvColorPicker(initial: initial, onChanged: (c) => current = c),
      const SizedBox(height: 16),
      _ActionButtons(
        confirmLabel: l10n.customThemeSave,
        confirmIcon: Lucide.Check,
        onConfirm: () => Navigator.of(ctx).pop(current),
      ),
    ],
  );

  if (_isDesktop) {
    return showAppDialog<Color>(
      context,
      maxWidth: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppDialogHeader(title: title),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Builder(builder: content),
          ),
        ],
      ),
    );
  }
  return _showAppSheet<Color>(
    context,
    title: title,
    child: Builder(builder: content),
  );
}

// ---------------------------------------------------------------------------
// Theme editor
// ---------------------------------------------------------------------------

/// Editor content (name + 3 color roles + live preview + actions).
class CustomThemeEditor extends StatefulWidget {
  const CustomThemeEditor({super.key, this.initial, required this.onSave});

  final CustomTheme? initial;
  final ValueChanged<CustomTheme> onSave;

  @override
  State<CustomThemeEditor> createState() => _CustomThemeEditorState();
}

class _CustomThemeEditorState extends State<CustomThemeEditor> {
  late final TextEditingController _nameController;
  late int _primaryArgb;
  int? _secondaryArgb;
  int? _tertiaryArgb;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _primaryArgb =
        widget.initial?.primaryArgb ??
        ThemePalettes.defaultPalette.light.primary.toARGB32();
    _secondaryArgb = widget.initial?.secondaryArgb;
    _tertiaryArgb = widget.initial?.tertiaryArgb;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  CustomTheme get _current => CustomTheme(
    id: widget.initial?.id ?? '',
    name: _nameController.text.trim(),
    primaryArgb: _primaryArgb,
    secondaryArgb: _secondaryArgb,
    tertiaryArgb: _tertiaryArgb,
  );

  Future<void> _pickColor({
    required String title,
    required Color initial,
    required ValueChanged<Color> onResult,
  }) async {
    final result = await showAppColorPicker(
      context,
      title: title,
      initial: initial,
    );
    if (!mounted || result == null) return;
    setState(() => onResult(result));
  }

  Widget _colorRow({
    required String label,
    required Color color,
    required bool isAuto,
    required VoidCallback onTap,
    VoidCallback? onReset,
  }) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Haptics.light();
              onTap();
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                  width: 0.6,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Haptics.light();
                onTap();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFontWeights.medium,
                    ),
                  ),
                  if (isAuto)
                    Text(
                      l10n.customThemeColorAuto,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (onReset != null)
            IosIconButton(
              icon: Lucide.RotateCcw,
              size: 16,
              semanticLabel: l10n.themeSettingsPageCustomColorReset,
              color: cs.onSurface.withValues(alpha: 0.7),
              onTap: onReset,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = _current;
    final scheme = customThemeColorScheme(
      theme,
      dark: Theme.of(context).brightness == Brightness.dark,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          decoration: _fieldDecoration(
            context,
            hintText: l10n.customThemeNameLabel,
          ),
          style: const TextStyle(fontSize: 14),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _colorRow(
          label: l10n.customThemePrimaryColor,
          color: Color(_primaryArgb),
          isAuto: false,
          onTap: () => _pickColor(
            title: l10n.customThemePrimaryColor,
            initial: Color(_primaryArgb),
            onResult: (c) => _primaryArgb = c.toARGB32(),
          ),
        ),
        _colorRow(
          label: l10n.customThemeSecondaryColor,
          color: _secondaryArgb != null
              ? Color(_secondaryArgb!)
              : scheme.secondary,
          isAuto: _secondaryArgb == null,
          onTap: () => _pickColor(
            title: l10n.customThemeSecondaryColor,
            initial: _secondaryArgb != null
                ? Color(_secondaryArgb!)
                : scheme.secondary,
            onResult: (c) => _secondaryArgb = c.toARGB32(),
          ),
          onReset: _secondaryArgb != null
              ? () => setState(() => _secondaryArgb = null)
              : null,
        ),
        _colorRow(
          label: l10n.customThemeTertiaryColor,
          color: _tertiaryArgb != null
              ? Color(_tertiaryArgb!)
              : scheme.tertiary,
          isAuto: _tertiaryArgb == null,
          onTap: () => _pickColor(
            title: l10n.customThemeTertiaryColor,
            initial: _tertiaryArgb != null
                ? Color(_tertiaryArgb!)
                : scheme.tertiary,
            onResult: (c) => _tertiaryArgb = c.toARGB32(),
          ),
          onReset: _tertiaryArgb != null
              ? () => setState(() => _tertiaryArgb = null)
              : null,
        ),
        const SizedBox(height: 8),
        _ThemePreview(theme: theme),
        const SizedBox(height: 16),
        _ActionButtons(
          confirmLabel: l10n.customThemeSave,
          confirmIcon: Lucide.Check,
          enabled: _nameController.text.trim().isNotEmpty,
          onConfirm: () {
            Haptics.light();
            Navigator.of(context).pop();
            widget.onSave(_current);
          },
        ),
      ],
    );
  }
}

/// Small mock-UI preview of a custom theme.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.theme});
  final CustomTheme theme;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cs = customThemeColorScheme(theme, dark: dark);
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.6,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Container(
                    width: 40,
                    height: 6,
                    decoration: BoxDecoration(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Show the create/edit UI adaptively (sheet on mobile, dialog on desktop).
/// Saves via [SettingsProvider.saveCustomTheme] and selects the saved theme.
Future<void> showCustomThemeEditor(
  BuildContext context, {
  CustomTheme? initial,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final title = initial == null
      ? l10n.customThemeNewTheme
      : l10n.customThemeEditTheme;
  Future<void> save(CustomTheme t) async {
    final sp = context.read<SettingsProvider>();
    final saved = await sp.saveCustomTheme(t);
    await sp.selectCustomTheme(saved.id);
  }

  if (_isDesktop) {
    await showAppDialog<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppDialogHeader(title: title),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: CustomThemeEditor(initial: initial, onSave: save),
            ),
          ),
        ],
      ),
    );
    return;
  }

  await _showAppSheet<void>(
    context,
    title: title,
    child: CustomThemeEditor(initial: initial, onSave: save),
  );
}

// ---------------------------------------------------------------------------
// Import / export / confirm
// ---------------------------------------------------------------------------

/// Paste-JSON import UI (sheet on mobile, dialog on desktop).
Future<void> showImportCustomThemeDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();

  final imported = await (_isDesktop
      ? showAppDialog<CustomTheme>(
          context,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppDialogHeader(title: l10n.customThemeImportTheme),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: _ImportThemeForm(controller: controller),
              ),
            ],
          ),
        )
      : _showAppSheet<CustomTheme>(
          context,
          title: l10n.customThemeImportTheme,
          child: _ImportThemeForm(controller: controller),
        ));

  if (imported != null && context.mounted) {
    await context.read<SettingsProvider>().importCustomTheme(imported.export());
  }
}

class _ImportThemeForm extends StatefulWidget {
  const _ImportThemeForm({required this.controller});
  final TextEditingController controller;

  @override
  State<_ImportThemeForm> createState() => _ImportThemeFormState();
}

class _ImportThemeFormState extends State<_ImportThemeForm> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          minLines: 4,
          maxLines: 8,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          decoration: _fieldDecoration(
            context,
            hintText: l10n.customThemeImportHint,
            errorText: _error,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 16),
        _ActionButtons(
          confirmLabel: l10n.customThemeImportTheme,
          confirmIcon: Lucide.Import,
          onConfirm: () {
            try {
              final t = CustomTheme.parse(widget.controller.text);
              Haptics.light();
              Navigator.of(context).pop(t);
            } catch (_) {
              setState(() => _error = l10n.customThemeImportInvalid);
            }
          },
        ),
      ],
    );
  }
}

/// Delete-confirmation dialog in the app's custom dialog style.
Future<bool> showCustomThemeConfirmDialog(
  BuildContext context, {
  required String message,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await showAppDialog<bool>(
    context,
    maxWidth: 360,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: TextStyle(fontSize: 15, fontWeight: AppFontWeights.medium),
          ),
          const SizedBox(height: 20),
          _ActionButtons(
            confirmLabel: l10n.customThemeDelete,
            confirmIcon: Lucide.Trash2,
            danger: true,
            onConfirm: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ),
  );
  return ok ?? false;
}

/// Export a theme to the clipboard and show a confirmation.
Future<void> exportCustomThemeToClipboard(
  BuildContext context,
  CustomTheme theme,
) async {
  await Clipboard.setData(ClipboardData(text: theme.export()));
  if (!context.mounted) return;
  showAppSnackBar(
    context,
    message: AppLocalizations.of(context)!.customThemeCopied,
    type: NotificationType.success,
  );
}
