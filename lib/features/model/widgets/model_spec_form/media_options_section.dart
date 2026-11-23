import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/models/media_creation.dart';
import '../../../../core/services/media/adapters/native_image_size.dart';
import '../../../../icons/lucide_adapter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ios_form_text_field.dart';
import '../../../../shared/widgets/ios_switch.dart';
import '../../../../shared/widgets/ios_tactile.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../theme/app_font_weights.dart';
import '../../../../theme/app_semantic_colors.dart';
import 'model_spec_form_controller.dart';

class MediaOptionsSection extends StatelessWidget {
  const MediaOptionsSection({super.key, required this.controller});

  final ModelSpecFormController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final caps = controller.mediaCapabilities;
    final defaults = controller.mediaDefaults;
    final video = controller.mediaMode == MediaMode.video;
    final known = controller.hasMediaModelData;
    final statusColor = known ? colors.primary : context.appColors.warning;
    final first = caps.frameRoles.isNotEmpty;
    final last = caps.frameRoles.length > 1;
    final ratios = {
      ...standardImageRatios,
      ...defaults.aspectRatios,
      ...caps.aspectRatios,
    };
    final durations = {
      ...defaults.durations,
      4,
      5,
      6,
      8,
      10,
      12,
      15,
      ...caps.durations,
    }.toList()..sort();
    final resolutions = {
      ...defaults.resolutions,
      '480p',
      '720p',
      '1080p',
      ...caps.resolutions,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: statusColor.withValues(alpha: known ? .06 : .12),
            ),
            child: Row(
              children: [
                Icon(
                  known ? LucideIcons.circleCheck : LucideIcons.info,
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    known ? l10n.creationModelKnown : l10n.creationModelUnknown,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
                if (known)
                  TextButton(
                    onPressed: controller.resetMedia,
                    child: Text(l10n.modelSpecFormReset),
                  ),
              ],
            ),
          ),
          _Field(
            title: l10n.creationAspectRatio,
            help: l10n.creationRatioHelp,
            child: _Choices(
              values: ratios,
              active: caps.aspectRatios,
              label: (value) => value == 'auto' ? l10n.creationAuto : value,
              onChange: (values) =>
                  controller.setMediaValue('aspectRatios', values),
              allowEmpty: false,
              ratioIcons: true,
            ),
          ),
          if (video) ...[
            _Field(
              title: l10n.creationDuration,
              child: _Choices(
                values: durations,
                active: caps.durations,
                label: l10n.creationDurationSeconds,
                onChange: (values) =>
                    controller.setMediaValue('durations', values),
              ),
            ),
            _Field(
              title: l10n.creationResolution,
              child: _Choices(
                values: resolutions,
                active: caps.resolutions,
                label: (value) => value,
                onChange: (values) =>
                    controller.setMediaValue('resolutions', values),
              ),
            ),
            _Field(
              title: l10n.creationFirstLastFrame,
              child: SectionCard(
                children: [
                  _Flag(
                    label: l10n.creationFirstFrame,
                    active: first,
                    onChanged: defaults.requiresFirstFrame
                        ? null
                        : (value) =>
                              controller.setMediaValue('firstFrame', value),
                  ),
                  _Flag(
                    label: l10n.creationLastFrame,
                    active: last,
                    onChanged: first
                        ? (value) =>
                              controller.setMediaValue('lastFrame', value)
                        : null,
                  ),
                ],
              ),
            ),
          ] else ...[
            if (defaults.sizes.isNotEmpty || caps.sizes.isNotEmpty)
              _Field(
                title: l10n.creationImageSize,
                child: _Choices(
                  values: {...defaults.sizes, ...caps.sizes},
                  active: caps.sizes,
                  label: (value) => value,
                  onChange: (values) =>
                      controller.setMediaValue('sizes', values),
                ),
              ),
            _Field(
              title: l10n.creationMaxPerRequest,
              help: l10n.creationMaxPerRequestHelp,
              child: _Count(
                value: caps.maxPerRequest,
                minimum: 1,
                onChanged: (value) =>
                    controller.setMediaValue('maxPerRequest', value),
              ),
            ),
            _Field(
              title: l10n.creationReferenceLimit,
              help: l10n.creationReferenceLimitHelp,
              child: _Count(
                value: caps.maxReferences,
                minimum: caps.requiresReference ? 1 : 0,
                onChanged: (value) =>
                    controller.setMediaValue('maxReferences', value),
              ),
            ),
          ],
          _Field(
            title: l10n.creationMediaOther,
            child: SectionCard(
              children: [
                _Flag(
                  label: l10n.creationNegativePrompt,
                  help: l10n.creationEnableOptionHelp,
                  active: caps.supportsNegativePrompt,
                  onChanged: (value) =>
                      controller.setMediaValue('negativePrompt', value),
                ),
                _Flag(
                  label: l10n.creationSeed,
                  help: l10n.creationEnableOptionHelp,
                  active: caps.supportsSeed,
                  onChanged: (value) => controller.setMediaValue('seed', value),
                ),
                if (!video)
                  _Flag(
                    label: l10n.creationTransparentBackground,
                    help: l10n.creationEnableOptionHelp,
                    active: caps.supportsTransparent,
                    onChanged: (value) =>
                        controller.setMediaValue('transparent', value),
                  ),
              ],
            ),
          ),
          if (!video)
            _Field(
              title: l10n.creationOutputFormat,
              child: _Choices(
                values: {...imageFormats, ...caps.formats},
                active: caps.formats,
                label: (value) => value.toUpperCase(),
                onChange: (values) =>
                    controller.setMediaValue('formats', values),
              ),
            ),
          _Field(
            title: l10n.creationExtraJson,
            help: l10n.creationExtraJsonHint,
            child: IosFormTextField(
              label: '',
              inlineLabel: false,
              controller: controller.mediaExtraController,
              hintText: '{ }',
              minLines: 3,
              maxLines: 8,
              textStyle: const TextStyle(fontFamily: 'monospace'),
              outerPadding: EdgeInsets.zero,
              onChanged: controller.mediaExtraChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.title, required this.child, this.help});

  final String title;
  final Widget child;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 13, fontWeight: AppFontWeights.semibold),
          ),
          if (help case final value?)
            Text(
              value,
              style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant),
            ),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }
}

class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.active,
    required this.label,
    required this.onChange,
    this.allowEmpty = true,
    this.ratioIcons = false,
  });

  final Iterable<T> values, active;
  final String Function(T) label;
  final ValueChanged<List<T>> onChange;
  final bool allowEmpty, ratioIcons;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 5,
      children: [
        for (final value in values)
          FilterChip(
            selected: active.contains(value),
            showCheckmark: false,
            avatar: ratioIcons ? _RatioIcon(value: value.toString()) : null,
            label: Text(label(value)),
            labelStyle: TextStyle(
              fontSize: 12.5,
              color: active.contains(value)
                  ? colors.primary
                  : colors.onSurfaceVariant,
            ),
            backgroundColor: colors.surfaceContainerHigh,
            selectedColor: colors.primary.withValues(alpha: .1),
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            side: BorderSide(
              color: active.contains(value)
                  ? colors.primary.withValues(alpha: .35)
                  : Colors.transparent,
            ),
            onSelected: (selected) {
              if (!selected && !allowEmpty && active.length == 1) return;
              onChange(
                values
                    .where(
                      (item) =>
                          item == value ? selected : active.contains(item),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }
}

class _RatioIcon extends StatelessWidget {
  const _RatioIcon({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value == 'auto') return const Icon(LucideIcons.proportions, size: 13);
    final dimensions = imageDimensions(value, 1024);
    final ratio = dimensions.width / dimensions.height;
    return Center(
      child: Container(
        width: ratio >= 1 ? 14 : 14 * ratio,
        height: ratio <= 1 ? 14 : 14 / ratio,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.value,
    required this.minimum,
    required this.onChanged,
  });
  final int value, minimum;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IosIconButton(
          icon: Lucide.Minus,
          size: 15,
          minSize: 34,
          onTap: value > minimum ? () => onChanged(value - 1) : null,
        ),
        Text(l10n.creationImagesCount(value)),
        IosIconButton(
          icon: Lucide.Plus,
          size: 15,
          minSize: 34,
          onTap: value < 16 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({
    required this.label,
    required this.active,
    required this.onChanged,
    this.help,
  });
  final String label;
  final bool active;
  final ValueChanged<bool>? onChanged;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                if (help case final value?)
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IosSwitch(value: active, onChanged: onChanged, semanticLabel: label),
        ],
      ),
    );
  }
}
