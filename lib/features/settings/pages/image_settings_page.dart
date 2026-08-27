import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';

class ImageSettingsPage extends StatelessWidget {
  const ImageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final compressionEnabled =
        settings.imageUploadQuality != ImageUploadQuality.original;

    final qualityRows = <Widget>[
      for (final quality in ImageUploadQuality.values)
        _QualityRow(
          title: _qualityTitle(quality, l10n),
          subtitle: _qualitySubtitle(quality, l10n),
          selected: settings.imageUploadQuality == quality,
          onTap: () =>
              context.read<SettingsProvider>().setImageUploadQuality(quality),
        ),
      if (settings.imageUploadQuality == ImageUploadQuality.custom)
        _CustomQualityRow(
          value: settings.imageCompressCustomQuality,
          onChanged: (value) => context
              .read<SettingsProvider>()
              .setImageCompressCustomQuality(value),
        ),
      _ToggleRow(
        title: l10n.imageSettingsPageCompressTransparentTitle,
        subtitle: l10n.imageSettingsPageCompressTransparentSubtitle,
        value: settings.imageCompressTransparentEnabled,
        onChanged: compressionEnabled
            ? (value) => context
                  .read<SettingsProvider>()
                  .setImageCompressTransparentEnabled(value)
            : null,
      ),
    ];

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
        title: Text(l10n.imageSettingsPageTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SettingsSection(
            title: l10n.imageSettingsPageEditSectionTitle,
            children: [
              _ToggleRow(
                title: l10n.displaySettingsPageEnableImageCropperTitle,
                subtitle: l10n.displaySettingsPageEnableImageCropperSubtitle,
                value: settings.imageCropperEnabled,
                onChanged: (value) => context
                    .read<SettingsProvider>()
                    .setImageCropperEnabled(value),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: l10n.imageSettingsPageQualitySectionTitle,
            footer: l10n.imageSettingsPageFooter,
            children: qualityRows,
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const _SettingsDivider(),
              ],
            ],
          ),
        ),
        if (footer != null) ...[
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              footer!,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: cs.onSurface.withValues(alpha: 0.58),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
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
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(
          children: [
            Expanded(
              child: _RowText(title: title, subtitle: subtitle),
            ),
            const SizedBox(width: 12),
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: Icon(Lucide.Check, size: 18, color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomQualityRow extends StatelessWidget {
  const _CustomQualityRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.imageSettingsPageCustomQualityTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.semibold,
                    color: cs.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
          SfSliderTheme(
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
              thumbStrokeColor: Colors.transparent,
              thumbStrokeWidth: 0,
              activeTickColor: cs.onSurface.withValues(
                alpha: isDark ? 0.45 : 0.35,
              ),
              inactiveTickColor: cs.onSurface.withValues(
                alpha: isDark ? 0.30 : 0.25,
              ),
            ),
            child: SfSlider(
              value: value.toDouble(),
              min: 10.0,
              max: 100.0,
              stepSize: 5.0,
              interval: 10.0,
              showTicks: true,
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
              onChanged: (next) => onChanged((next as double).round()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onChanged == null ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: _RowText(title: title, subtitle: subtitle),
            ),
            const SizedBox(width: 12),
            IosSwitch(value: value, semanticLabel: title, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _RowText extends StatelessWidget {
  const _RowText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: AppFontWeights.semibold,
            color: cs.onSurface.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            height: 1.25,
            color: cs.onSurface.withValues(alpha: 0.62),
          ),
        ),
      ],
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      thickness: 0.6,
      indent: 14,
      endIndent: 12,
      color: cs.outlineVariant.withValues(alpha: 0.18),
    );
  }
}

String _qualityTitle(ImageUploadQuality quality, AppLocalizations l10n) {
  return switch (quality) {
    ImageUploadQuality.original => l10n.imageSettingsPageQualityOriginal,
    ImageUploadQuality.high => l10n.imageSettingsPageQualityHigh,
    ImageUploadQuality.balanced => l10n.imageSettingsPageQualityBalanced,
    ImageUploadQuality.saver => l10n.imageSettingsPageQualitySaver,
    ImageUploadQuality.custom => l10n.imageSettingsPageQualityCustom,
  };
}

String _qualitySubtitle(ImageUploadQuality quality, AppLocalizations l10n) {
  return switch (quality) {
    ImageUploadQuality.original =>
      l10n.imageSettingsPageQualityOriginalSubtitle,
    ImageUploadQuality.high => l10n.imageSettingsPageQualityHighSubtitle,
    ImageUploadQuality.balanced =>
      l10n.imageSettingsPageQualityBalancedSubtitle,
    ImageUploadQuality.saver => l10n.imageSettingsPageQualitySaverSubtitle,
    ImageUploadQuality.custom => l10n.imageSettingsPageQualityCustomSubtitle,
  };
}
