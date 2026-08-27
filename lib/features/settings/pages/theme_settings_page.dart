import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../theme/palettes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../core/services/haptics.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import '../../../theme/custom_theme.dart';
import '../widgets/custom_theme_widgets.dart';
import '../../../shared/widgets/section_card.dart';
import 'theme_advanced_settings_page.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: AppFontWeights.semibold,
          color: cs.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );

    // Section header with trailing action icons (e.g. new/import theme).
    Widget headerWithActions(String text, {required List<Widget> actions}) =>
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFontWeights.semibold,
                    color: cs.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
              ...actions,
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: _TactileIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.displaySettingsPageThemeSettingsTitle),
        actions: [
          Tooltip(
            message: l10n.themeAdvancedSettingsPageTitle,
            child: _TactileIconButton(
              icon: Lucide.Settings2,
              color: cs.onSurface,
              size: 22,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ThemeAdvancedSettingsPage(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          if (!kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android &&
              settings.dynamicColorSupported) ...[
            header(l10n.themeSettingsPageDynamicColorSection),
            SectionCard(
              children: [
                _iosSwitchRow(
                  context,
                  icon: Lucide.Palette,
                  label: l10n.themeSettingsPageUseDynamicColorTitle,
                  subtitle: l10n.themeSettingsPageUseDynamicColorSubtitle,
                  value: settings.useDynamicColor,
                  onChanged: (v) =>
                      context.read<SettingsProvider>().setUseDynamicColor(v),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SectionCard(
            children: [
              _iosSwitchRow(
                context,
                icon: Lucide.Square,
                label: l10n.themeSettingsPageUsePureBackgroundTitle,
                subtitle: l10n.themeSettingsPageUsePureBackgroundSubtitle,
                value: settings.usePureBackground,
                onChanged: (v) =>
                    context.read<SettingsProvider>().setUsePureBackground(v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // header(l10n.themeSettingsPageColorPalettesSection),
          SectionCard(
            children: [
              for (int i = 0; i < ThemePalettes.all.length; i++) ...[
                _paletteRow(
                  context,
                  palette: ThemePalettes.all[i],
                  selected: settings.themePaletteId == ThemePalettes.all[i].id,
                  onTap: () => context.read<SettingsProvider>().setThemePalette(
                    ThemePalettes.all[i].id,
                  ),
                ),
                if (i != ThemePalettes.all.length - 1) _iosDivider(context),
              ],
            ],
          ),
          headerWithActions(
            l10n.themeSettingsPageCustomThemesSection,
            actions: [
              Tooltip(
                message: l10n.customThemeNewTheme,
                child: _TactileIconButton(
                  icon: Lucide.Plus,
                  color: cs.onSurface.withValues(alpha: 0.7),
                  size: 18,
                  onTap: () => showCustomThemeEditor(context),
                ),
              ),
              Tooltip(
                message: l10n.customThemeImportTheme,
                child: _TactileIconButton(
                  icon: Lucide.Download,
                  color: cs.onSurface.withValues(alpha: 0.7),
                  size: 18,
                  onTap: () => showImportCustomThemeDialog(context),
                ),
              ),
            ],
          ),
          _customThemesSection(context),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Saved custom themes list (create/import live in the section header).
Widget _customThemesSection(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final settings = context.watch<SettingsProvider>();
  final themes = settings.customThemes;
  final isCustomActive =
      settings.themePaletteId == ThemePalettes.customPaletteId;

  Future<void> confirmDelete(CustomTheme t) async {
    final ok = await showCustomThemeConfirmDialog(
      context,
      message: l10n.customThemeDeleteConfirm,
    );
    if (ok && context.mounted) {
      await context.read<SettingsProvider>().deleteCustomTheme(t.id);
    }
  }

  if (themes.isEmpty) return const SizedBox.shrink();

  return SectionCard(
    children: [
      for (int i = 0; i < themes.length; i++) ...[
        _customThemeRow(
          context,
          theme: themes[i],
          selected:
              isCustomActive && settings.selectedCustomThemeId == themes[i].id,
          onTap: () =>
              context.read<SettingsProvider>().selectCustomTheme(themes[i].id),
          onCopy: () => exportCustomThemeToClipboard(context, themes[i]),
          onEdit: () => showCustomThemeEditor(context, initial: themes[i]),
          onDelete: () => confirmDelete(themes[i]),
        ),
        if (i != themes.length - 1) _iosDivider(context),
      ],
    ],
  );
}

Widget _customThemeRow(
  BuildContext context, {
  required CustomTheme theme,
  required bool selected,
  required VoidCallback onTap,
  required VoidCallback onCopy,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  return _TactileRow(
    onTap: onTap,
    builder: (pressed) {
      final baseColor = cs.onSurface.withValues(alpha: 0.9);
      return _AnimatedPressColor(
        pressed: pressed,
        base: baseColor,
        builder: (c) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              CustomThemeDot(theme: theme, size: 28, selected: selected),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  theme.name.isEmpty
                      ? l10n.themeSettingsPageCustomPaletteName
                      : theme.name,
                  style: TextStyle(fontSize: 15, color: c),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected) Icon(Lucide.Check, size: 18, color: cs.primary),
              _rowAction(context, icon: Lucide.Copy, onTap: onCopy),
              _rowAction(context, icon: Lucide.Pencil, onTap: onEdit),
              _rowAction(
                context,
                icon: Lucide.Trash2,
                onTap: onDelete,
                color: cs.error,
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _rowAction(
  BuildContext context, {
  required IconData icon,
  required VoidCallback onTap,
  Color? color,
}) {
  final cs = Theme.of(context).colorScheme;
  return _TactileIconButton(
    icon: icon,
    color: color ?? cs.onSurface.withValues(alpha: 0.7),
    size: 16,
    onTap: onTap,
  );
}

// --- iOS-style helpers ---

Widget _iosDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(
    height: 6,
    thickness: 0.6,
    indent: 12,
    endIndent: 12,
    color: cs.outlineVariant.withValues(alpha: 0.18),
  );
}

class _AnimatedPressColor extends StatelessWidget {
  const _AnimatedPressColor({
    required this.pressed,
    required this.base,
    required this.builder,
  });
  final bool pressed;
  final Color base;
  final Widget Function(Color color) builder;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final target = pressed
        ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base)
        : base;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, color, _) => builder(color ?? base),
    );
  }
}

class _TactileRow extends StatefulWidget {
  const _TactileRow({required this.builder, this.onTap});
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  @override
  State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false;
  void _setPressed(bool v) {
    if (_pressed != v) {
      setState(() => _pressed = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (context.read<SettingsProvider>().hapticsOnListItemTap) {
                Haptics.soft();
              }
              widget.onTap!.call();
            },
      child: widget.builder(_pressed),
    );
  }
}

class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 22,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  @override
  State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    final pressColor = base.withValues(alpha: 0.7);
    final icon = Icon(
      widget.icon,
      size: widget.size,
      color: _pressed ? pressColor : base,
    );
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          widget.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: icon,
        ),
      ),
    );
  }
}

Widget _iosSwitchRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  String? subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final cs = Theme.of(context).colorScheme;
  return _TactileRow(
    onTap: () => onChanged(!value),
    builder: (pressed) {
      final baseColor = cs.onSurface.withValues(alpha: 0.9);
      return _AnimatedPressColor(
        pressed: pressed,
        base: baseColor,
        builder: (c) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 15, color: c)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IosSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      );
    },
  );
}

Widget _paletteRow(
  BuildContext context, {
  required ThemePalette palette,
  required bool selected,
  required VoidCallback onTap,
}) {
  final cs = Theme.of(context).colorScheme;
  final title = Localizations.localeOf(context).languageCode == 'zh'
      ? palette.displayNameZh
      : palette.displayNameEn;
  final color = palette.light.primary;
  return _TactileRow(
    onTap: onTap,
    builder: (pressed) {
      final baseColor = cs.onSurface.withValues(alpha: 0.9);
      return _AnimatedPressColor(
        pressed: pressed,
        base: baseColor,
        builder: (c) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              // color dot (slightly smaller)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: Theme.of(context).brightness == Brightness.dark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 15, color: c)),
              ),
              if (selected)
                Icon(Lucide.Check, size: 18, color: cs.primary)
              else
                const SizedBox(width: 18, height: 18),
            ],
          ),
        ),
      );
    },
  );
}
