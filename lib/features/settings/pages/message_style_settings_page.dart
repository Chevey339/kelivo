import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../icons/reasoning_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/services/haptics.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../theme/chat_bubble_style.dart';
import '../../../theme/custom_theme.dart';
import '../../../theme/palettes.dart';
import '../../../theme/theme_factory.dart';
import '../../chat/widgets/frosted/chat_frosted_backdrop.dart';
import '../../chat/widgets/frosted/frosted_surface.dart';
import '../../home/pages/home_mobile_layout.dart';
import '../widgets/custom_theme_widgets.dart';

class MessageStyleSettingsPage extends StatelessWidget {
  const MessageStyleSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: IosIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            minSize: 44,
            semanticLabel: l10n.settingsPageBackButton,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.messageStyleSettingsPageTitle),
        actions: [
          Tooltip(
            message: l10n.messageStyleSettingsPageReset,
            child: IosIconButton(
              icon: Lucide.RotateCcw,
              color: cs.onSurface,
              size: 20,
              minSize: 44,
              semanticLabel: l10n.messageStyleSettingsPageReset,
              onTap: () => resetMessageStyleSettings(context),
            ),
          ),
        ],
      ),
      body: const MessageStyleSettingsBody(),
    );
  }
}

Future<void> resetMessageStyleSettings(BuildContext context) async {
  final ok = await _confirmReset(context);
  if (!ok || !context.mounted) return;
  await context.read<SettingsProvider>().setChatBubbleStyleOverrides(
    const ChatBubbleStyleOverrides(),
  );
}

Future<void> showMessageStyleSettingsDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  return showAppDialog<void>(
    context,
    maxWidth: 520,
    child: SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Column(
        children: [
          AppDialogHeader(
            title: l10n.messageStyleSettingsPageTitle,
            actions: [
              IosIconButton(
                icon: Lucide.RotateCcw,
                size: 18,
                color: cs.onSurface.withValues(alpha: 0.62),
                semanticLabel: l10n.messageStyleSettingsPageReset,
                onTap: () => resetMessageStyleSettings(context),
              ),
            ],
          ),
          const Expanded(child: MessageStyleSettingsBody()),
        ],
      ),
    ),
  );
}

class MessageStyleSettingsBody extends StatefulWidget {
  const MessageStyleSettingsBody({super.key});

  @override
  State<MessageStyleSettingsBody> createState() =>
      _MessageStyleSettingsBodyState();
}

class _MessageStyleSettingsBodyState extends State<MessageStyleSettingsBody> {
  bool? _editingDark;
  bool _editingUser = false;
  ThemeData? _cachedLightTheme;
  ThemeData? _cachedDarkTheme;
  String? _previewThemeKey;

  bool get _isEditingDark =>
      _editingDark ?? Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final style = settings.chatMessageBackgroundStyle;
    final overrides = settings.chatBubbleStyleOverridesFor(
      isUser: _editingUser,
    );
    final editingDark = _isEditingDark;
    final isDefault = style == ChatMessageBackgroundStyle.defaultStyle;
    final previewThemes = _previewThemes(context);
    final lightTheme = previewThemes.$1;
    final darkTheme = previewThemes.$2;
    final previewTheme = editingDark ? darkTheme : lightTheme;
    final resolved = resolveBubbleStyle(
      previewTheme.colorScheme,
      previewTheme.brightness,
      style,
      overrides,
    );

    final stylePicker = _iosSectionCard(
      children: [
        _StyleRow(
          style: ChatMessageBackgroundStyle.defaultStyle,
          label: l10n.displaySettingsPageChatMessageBackgroundDefault,
          subtitle: l10n.messageStyleSettingsPageStyleDefaultSubtitle,
          selected: isDefault,
          onTap: () => settings.setChatMessageBackgroundStyle(
            ChatMessageBackgroundStyle.defaultStyle,
          ),
        ),
        _iosDivider(context),
        _StyleRow(
          style: ChatMessageBackgroundStyle.frosted,
          label: l10n.displaySettingsPageChatMessageBackgroundFrosted,
          subtitle: l10n.messageStyleSettingsPageStyleFrostedSubtitle,
          selected: style == ChatMessageBackgroundStyle.frosted,
          onTap: () => settings.setChatMessageBackgroundStyle(
            ChatMessageBackgroundStyle.frosted,
          ),
        ),
        _iosDivider(context),
        _StyleRow(
          style: ChatMessageBackgroundStyle.solid,
          label: l10n.displaySettingsPageChatMessageBackgroundSolid,
          subtitle: l10n.messageStyleSettingsPageStyleSolidSubtitle,
          selected: style == ChatMessageBackgroundStyle.solid,
          onTap: () => settings.setChatMessageBackgroundStyle(
            ChatMessageBackgroundStyle.solid,
          ),
        ),
      ],
    );

    final preview = _PreviewPanel(
      theme: previewTheme,
      editingDark: editingDark,
      editingUser: _editingUser,
      style: style,
      userOverrides: settings.userChatBubbleStyleOverrides,
      assistantOverrides: settings.assistantChatBubbleStyleOverrides,
    );

    final params = _iosSectionCard(
      children: [
        if (style == ChatMessageBackgroundStyle.frosted) ...[
          _SliderRow(
            label: l10n.messageStyleSettingsPageBlur,
            valueText: resolved.blurSigma.round().toString(),
            child: _ThemedSlider(
              value: resolved.blurSigma,
              min: 0,
              max: 30,
              stepSize: 1,
              onChanged: (v) => settings.setChatBubbleStyleOverridesForRole(
                isUser: _editingUser,
                value: overrides.copyWith(blurSigma: () => v),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(
              l10n.messageStyleSettingsPageBlurHint,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: cs.onSurface.withValues(alpha: 0.58),
              ),
            ),
          ),
          _iosDivider(context, indent: 14),
        ],
        _ColorRow(
          label: l10n.messageStyleSettingsPageBackgroundColor,
          color: resolved.background.withValues(alpha: 1),
          onTap: () => _pickColor(
            context,
            title: l10n.messageStyleSettingsPageBackgroundColor,
            initial: resolved.background.withValues(alpha: 1),
            onPicked: (color) {
              final argb = _opaqueArgb(color);
              settings.setChatBubbleStyleOverridesForRole(
                isUser: _editingUser,
                value: editingDark
                    ? overrides.copyWith(backgroundArgbDark: () => argb)
                    : overrides.copyWith(backgroundArgbLight: () => argb),
              );
            },
          ),
        ),
        _iosDivider(context, indent: 14),
        _SliderRow(
          label: l10n.messageStyleSettingsPageBackgroundOpacity,
          valueText: '${((_styleOpacity(style, overrides) * 100).round())}%',
          child: _ThemedSlider(
            value: _styleOpacity(style, overrides) * 100,
            min: 0,
            max: 100,
            stepSize: 1,
            onChanged: (v) {
              final opacity = (v / 100).clamp(0.0, 1.0);
              settings.setChatBubbleStyleOverridesForRole(
                isUser: _editingUser,
                value: style == ChatMessageBackgroundStyle.frosted
                    ? overrides.copyWith(frostedOpacity: () => opacity)
                    : overrides.copyWith(solidOpacity: () => opacity),
              );
            },
          ),
        ),
        _iosDivider(context, indent: 14),
        _ColorRow(
          label: l10n.messageStyleSettingsPageBorderColor,
          color: resolved.border.withValues(alpha: 1),
          onTap: () => _pickColor(
            context,
            title: l10n.messageStyleSettingsPageBorderColor,
            initial: resolved.border.withValues(alpha: 1),
            onPicked: (color) {
              final argb = _opaqueArgb(color);
              settings.setChatBubbleStyleOverridesForRole(
                isUser: _editingUser,
                value: editingDark
                    ? overrides.copyWith(borderArgbDark: () => argb)
                    : overrides.copyWith(borderArgbLight: () => argb),
              );
            },
          ),
        ),
        _iosDivider(context, indent: 14),
        _SliderRow(
          label: l10n.messageStyleSettingsPageBorderOpacity,
          valueText: '${((resolved.border.a * 100).round())}%',
          child: _ThemedSlider(
            value: resolved.border.a * 100,
            min: 0,
            max: 100,
            stepSize: 1,
            onChanged: (v) => settings.setChatBubbleStyleOverridesForRole(
              isUser: _editingUser,
              value: overrides.copyWith(
                borderOpacity: () => (v / 100).clamp(0.0, 1.0),
              ),
            ),
          ),
        ),
        _iosDivider(context, indent: 14),
        _SliderRow(
          label: l10n.messageStyleSettingsPageBorderWidth,
          valueText: resolved.borderWidth.toStringAsFixed(1),
          child: _ThemedSlider(
            value: resolved.borderWidth,
            min: 0,
            max: 3,
            stepSize: 0.1,
            onChanged: (v) => settings.setChatBubbleStyleOverridesForRole(
              isUser: _editingUser,
              value: overrides.copyWith(borderWidth: () => v),
            ),
          ),
        ),
        _iosDivider(context, indent: 14),
        _ColorRow(
          label: l10n.messageStyleSettingsPageTextColor,
          color: resolved.text.withValues(alpha: 1),
          onTap: () => _pickColor(
            context,
            title: l10n.messageStyleSettingsPageTextColor,
            initial: resolved.text.withValues(alpha: 1),
            onPicked: (color) {
              final argb = _opaqueArgb(color);
              settings.setChatBubbleStyleOverridesForRole(
                isUser: _editingUser,
                value: editingDark
                    ? overrides.copyWith(textArgbDark: () => argb)
                    : overrides.copyWith(textArgbLight: () => argb),
              );
            },
          ),
        ),
        _iosDivider(context, indent: 14),
        _SliderRow(
          label: l10n.messageStyleSettingsPageCornerRadius,
          valueText: resolved.radius.round().toString(),
          child: _ThemedSlider(
            value: resolved.radius,
            min: 0,
            max: 28,
            stepSize: 1,
            onChanged: (v) => settings.setChatBubbleStyleOverridesForRole(
              isUser: _editingUser,
              value: overrides.copyWith(cornerRadius: () => v),
            ),
          ),
        ),
      ],
    );

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
            stylePicker,
            const SizedBox(height: 12),
            _SegmentedToggle(
              leftLabel: l10n.messageStyleSettingsPageLight,
              leftIcon: Lucide.Sun,
              rightLabel: l10n.messageStyleSettingsPageDark,
              rightIcon: Lucide.Moon,
              rightSelected: editingDark,
              onChanged: (value) {
                if (value == editingDark) return;
                Haptics.soft();
                setState(() => _editingDark = value);
              },
            ),
            if (!isDefault) ...[
              const SizedBox(height: 12),
              _SegmentedToggle(
                leftLabel: l10n.messageStyleSettingsPageRoleUser,
                leftIcon: Lucide.User,
                rightLabel: l10n.messageStyleSettingsPageRoleAssistant,
                rightIcon: Lucide.Bot,
                rightSelected: !_editingUser,
                onChanged: (rightSelected) {
                  final editingUser = !rightSelected;
                  if (editingUser == _editingUser) return;
                  Haptics.soft();
                  setState(() => _editingUser = editingUser);
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(
                  l10n.messageStyleSettingsPageRoleAssistantHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: cs.onSurface.withValues(alpha: 0.56),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            preview,
            if (isDefault)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Text(
                  l10n.messageStyleSettingsPageDefaultHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: cs.onSurface.withValues(alpha: 0.56),
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 12),
              params,
            ],
          ],
        ),
      ),
    );
  }

  (ThemeData, ThemeData) _previewThemes(BuildContext context) {
    final current = Theme.of(context);
    final settings = context.read<SettingsProvider>();
    final custom = settings.selectedCustomTheme;
    final key =
        '${current.brightness.name}|${settings.themePaletteId}|${custom?.id}|${settings.usePureBackground}';
    if (_cachedLightTheme != null &&
        _cachedDarkTheme != null &&
        _previewThemeKey == key) {
      return (_cachedLightTheme!, _cachedDarkTheme!);
    }

    final palette =
        settings.themePaletteId == ThemePalettes.customPaletteId &&
            custom != null
        ? buildCustomThemePalette(custom)
        : ThemePalettes.byId(settings.themePaletteId);
    final light = current.brightness == Brightness.light
        ? current
        : buildLightThemeForScheme(
            palette.light,
            pureBackground: settings.usePureBackground,
          );
    final dark = current.brightness == Brightness.dark
        ? current
        : buildDarkThemeForScheme(
            palette.dark,
            pureBackground: settings.usePureBackground,
          );
    _cachedLightTheme = light;
    _cachedDarkTheme = dark;
    _previewThemeKey = key;
    return (light, dark);
  }

  Future<void> _pickColor(
    BuildContext context, {
    required String title,
    required Color initial,
    required ValueChanged<Color> onPicked,
  }) async {
    final result = await showAppColorPicker(
      context,
      title: title,
      initial: initial,
    );
    if (!mounted || result == null) return;
    onPicked(result);
  }
}

double _styleOpacity(
  ChatMessageBackgroundStyle style,
  ChatBubbleStyleOverrides overrides,
) {
  return switch (style) {
    ChatMessageBackgroundStyle.frosted => overrides.frostedOpacity ?? 0.66,
    ChatMessageBackgroundStyle.solid => overrides.solidOpacity ?? 1.0,
    ChatMessageBackgroundStyle.defaultStyle => overrides.solidOpacity ?? 1.0,
  };
}

int _opaqueArgb(Color color) => color.withValues(alpha: 1).toARGB32();

Future<bool> _confirmReset(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final ok = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: cs.scrim.withValues(alpha: 0.25),
    pageBuilder: (ctx, _, __) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(ctx).maybePop(false),
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: cs.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isDark
                            ? cs.onSurface.withValues(alpha: 0.08)
                            : cs.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.messageStyleSettingsPageResetConfirm,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: AppFontWeights.medium,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: IosTileButton(
                                icon: Lucide.X,
                                label: l10n.messageStyleSettingsPageCancel,
                                onTap: () => Navigator.of(ctx).maybePop(false),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: IosTileButton(
                                icon: Lucide.RotateCcw,
                                label: l10n.messageStyleSettingsPageReset,
                                backgroundColor: cs.primary,
                                foregroundColor: cs.primary,
                                onTap: () => Navigator.of(ctx).maybePop(true),
                              ),
                            ),
                          ],
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
    },
  );
  return ok ?? false;
}

class _StyleRow extends StatelessWidget {
  const _StyleRow({
    required this.style,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final ChatMessageBackgroundStyle style;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IosCardPress(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      padding: EdgeInsets.zero,
      baseColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _StyleSwatch(style: style),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      color: cs.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: cs.onSurface.withValues(alpha: 0.52),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Lucide.Check, size: 18, color: cs.primary)
            else
              const SizedBox(width: 18, height: 18),
          ],
        ),
      ),
    );
  }
}

class _StyleSwatch extends StatelessWidget {
  const _StyleSwatch({required this.style});

  final ChatMessageBackgroundStyle style;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fill;
    final Color border;
    switch (style) {
      case ChatMessageBackgroundStyle.defaultStyle:
        fill = cs.primary.withValues(alpha: isDark ? 0.22 : 0.14);
        border = cs.primary.withValues(alpha: 0.18);
      case ChatMessageBackgroundStyle.frosted:
        fill = cs.surfaceContainerHigh.withValues(alpha: 0.62);
        border = cs.outlineVariant.withValues(alpha: 0.42);
      case ChatMessageBackgroundStyle.solid:
        fill = cs.surfaceContainerHigh;
        border = cs.outlineVariant.withValues(alpha: 0.55);
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 0.8),
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({
    required this.leftLabel,
    required this.leftIcon,
    required this.rightLabel,
    required this.rightIcon,
    required this.rightSelected,
    required this.onChanged,
  });

  final String leftLabel;
  final IconData leftIcon;
  final String rightLabel;
  final IconData rightIcon;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.08 : 0.06),
          width: 0.6,
        ),
      ),
      child: SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: rightSelected
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isDark
                          ? const []
                          : [
                              BoxShadow(
                                color: cs.shadow.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _SegmentedToggleHit(
                      label: leftLabel,
                      icon: leftIcon,
                      selected: !rightSelected,
                      onTap: () => onChanged(false),
                    ),
                  ),
                  Expanded(
                    child: _SegmentedToggleHit(
                      label: rightLabel,
                      icon: rightIcon,
                      selected: rightSelected,
                      onTap: () => onChanged(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedToggleHit extends StatelessWidget {
  const _SegmentedToggleHit({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                icon,
                size: 16,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.52),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                height: 1.1,
                fontWeight: selected
                    ? AppFontWeights.semibold
                    : AppFontWeights.regular,
                color: selected
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IosCardPress(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      padding: EdgeInsets.zero,
      baseColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                  width: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueText,
    required this.child,
  });

  final String label;
  final String valueText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: cs.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Text(
                valueText,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _ThemedSlider extends StatelessWidget {
  const _ThemedSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.stepSize,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final double stepSize;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return SfSliderTheme(
      data: SfSliderThemeData(
        activeTrackHeight: 8,
        inactiveTrackHeight: 8,
        overlayRadius: 14,
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.onSurface.withValues(
          alpha: isDark ? 0.25 : 0.20,
        ),
        tooltipBackgroundColor: cs.primary,
        tooltipTextStyle: TextStyle(
          color: cs.onPrimary,
          fontWeight: AppFontWeights.semibold,
        ),
        activeTickColor: cs.onSurface.withValues(alpha: isDark ? 0.45 : 0.35),
        inactiveTickColor: cs.onSurface.withValues(alpha: isDark ? 0.30 : 0.25),
        activeMinorTickColor: cs.onSurface.withValues(
          alpha: isDark ? 0.34 : 0.28,
        ),
        inactiveMinorTickColor: cs.onSurface.withValues(
          alpha: isDark ? 0.24 : 0.20,
        ),
      ),
      child: SfSlider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        stepSize: stepSize,
        enableTooltip: true,
        shouldAlwaysShowTooltip: false,
        tooltipShape: const SfPaddleTooltipShape(),
        thumbIcon: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
        ),
        onChanged: (v) => onChanged((v as double).clamp(min, max)),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.theme,
    required this.editingDark,
    required this.editingUser,
    required this.style,
    required this.userOverrides,
    required this.assistantOverrides,
  });

  final ThemeData theme;
  final bool editingDark;
  final bool editingUser;
  final ChatMessageBackgroundStyle style;
  final ChatBubbleStyleOverrides userOverrides;
  final ChatBubbleStyleOverrides assistantOverrides;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.10),
          width: 0.6,
        ),
      ),
      child: SizedBox(
        height: 220,
        child: Theme(
          key: ValueKey<bool>(editingDark),
          data: theme,
          child: _PreviewScene(
            style: style,
            userOverrides: userOverrides,
            assistantOverrides: assistantOverrides,
            editingUser: editingUser,
          ),
        ),
      ),
    );
  }
}

class _PreviewScene extends StatelessWidget {
  const _PreviewScene({
    required this.style,
    required this.userOverrides,
    required this.assistantOverrides,
    required this.editingUser,
  });

  final ChatMessageBackgroundStyle style;
  final ChatBubbleStyleOverrides userOverrides;
  final ChatBubbleStyleOverrides assistantOverrides;
  final bool editingUser;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;
    final userResolved = resolveBubbleStyle(
      cs,
      brightness,
      style,
      userOverrides,
    );
    final assistantResolved = resolveBubbleStyle(
      cs,
      brightness,
      style,
      assistantOverrides,
    );
    final dimInactive = style != ChatMessageBackgroundStyle.defaultStyle;
    Widget maybeDim({required bool active, required Widget child}) {
      if (!dimInactive || active) return child;
      return Opacity(opacity: 0.45, child: child);
    }

    return ChatFrostedBackdrop(
      backdrop: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: cs.surface),
          const MobileBackgroundLayer(),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: maybeDim(
                      active: editingUser,
                      child: _PreviewSurface(
                        style: style,
                        resolved: userResolved,
                        defaultColor: brightness == Brightness.dark
                            ? cs.primary.withValues(alpha: 0.15)
                            : cs.primary.withValues(alpha: 0.08),
                        padding: const EdgeInsets.all(11),
                        child: Text(
                          l10n.messageStyleSettingsPagePreviewUser,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color:
                                style == ChatMessageBackgroundStyle.defaultStyle
                                ? cs.onSurface
                                : userResolved.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                maybeDim(
                  active: !editingUser,
                  child: _PreviewSurface(
                    style: style,
                    resolved: assistantResolved,
                    defaultColor: cs.primaryContainer.withValues(
                      alpha: brightness == Brightness.dark ? 0.25 : 0.30,
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                    child: Row(
                      children: [
                        ReasoningIcons.thinkingCardIcon(
                          size: 16,
                          color: _previewStrong(context, assistantResolved),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.messageStyleSettingsPagePreviewThinking,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: AppFontWeights.emphasis,
                              color: _previewStrong(context, assistantResolved),
                            ),
                          ),
                        ),
                        Icon(
                          Lucide.ChevronRight,
                          size: 16,
                          color: _previewStrong(context, assistantResolved),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: maybeDim(
                      active: !editingUser,
                      child: _PreviewSurface(
                        style: style,
                        resolved: assistantResolved,
                        bareOnDefault: true,
                        padding: const EdgeInsets.all(11),
                        child: Text(
                          l10n.messageStyleSettingsPagePreviewAssistant,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color:
                                style == ChatMessageBackgroundStyle.defaultStyle
                                ? cs.onSurface
                                : assistantResolved.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _previewStrong(BuildContext context, ResolvedBubbleStyle resolved) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final style = context.read<SettingsProvider>().chatMessageBackgroundStyle;
  if (style == ChatMessageBackgroundStyle.defaultStyle) {
    return cs.secondary;
  }
  final isDark = theme.brightness == Brightness.dark;
  return resolved.text.withValues(alpha: isDark ? 0.88 : 0.78);
}

class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({
    required this.style,
    required this.resolved,
    required this.padding,
    required this.child,
    this.defaultColor,
    this.bareOnDefault = false,
  });

  final ChatMessageBackgroundStyle style;
  final ResolvedBubbleStyle resolved;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final Color? defaultColor;
  final bool bareOnDefault;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(padding: padding, child: child);
    switch (style) {
      case ChatMessageBackgroundStyle.frosted:
        return FrostedSurface(
          style: resolved,
          borderRadius: BorderRadius.circular(resolved.radius),
          child: padded,
        );
      case ChatMessageBackgroundStyle.solid:
        final radius = BorderRadius.circular(resolved.radius);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: resolved.background,
            borderRadius: radius,
            border: Border.all(
              color: resolved.border,
              width: resolved.borderWidth,
            ),
          ),
          child: padded,
        );
      case ChatMessageBackgroundStyle.defaultStyle:
        if (bareOnDefault) return child;
        if (defaultColor == null) return padded;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: defaultColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: padded,
        );
    }
  }
}

Widget _iosSectionCard({required List<Widget> children}) {
  return Builder(
    builder: (context) {
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      final isDark = theme.brightness == Brightness.dark;
      return Container(
        decoration: BoxDecoration(
          color: context.appColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.08 : 0.06),
            width: 0.6,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: children),
        ),
      );
    },
  );
}

Widget _iosDivider(BuildContext context, {double indent = 14}) {
  final cs = Theme.of(context).colorScheme;
  return Divider(
    height: 6,
    thickness: 0.6,
    indent: indent,
    endIndent: 12,
    color: cs.outlineVariant.withValues(alpha: 0.18),
  );
}
