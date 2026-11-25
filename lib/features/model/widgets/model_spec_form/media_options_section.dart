import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/models/media_creation.dart';
import '../../../../core/services/media/media_request.dart';
import '../../../../core/services/media/media_model_overrides.dart';
import '../../../../desktop/widgets/desktop_select_dropdown.dart';
import '../../../../shared/widgets/action_sheet.dart';
import '../../../../core/services/media/adapters/native_image_size.dart'
    show standardImageRatios, imageFormats;
import '../../../media/widgets/creation_ratio_grid.dart';
import '../../../media/widgets/creation_controls.dart';
import '../../../../icons/lucide_adapter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/plain_text_input.dart';
import '../../../../shared/widgets/ios_switch.dart';
import '../../../../shared/widgets/ios_tactile.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../theme/app_font_weights.dart';
import '../../../../theme/app_semantic_colors.dart';
import '../../../../utils/platform_utils.dart';
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
                  CreationAction(
                    small: true,
                    onPressed: controller.resetMedia,
                    child: Text(l10n.modelSpecFormReset),
                  ),
              ],
            ),
          ),
          if (!controller.config.isOAuth)
            _Field(
              title: l10n.creationApiProtocol,
              help: l10n.creationApiProtocolHelp,
              child: _protocolSelector(context, l10n),
            ),
          if (!defaults.fixedAspectRatio)
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
                    onChanged:
                        defaults.requiresFirstFrame ||
                            !defaults.configurableFrameRoles.contains(
                              MediaReferenceRole.firstFrame,
                            )
                        ? null
                        : (value) =>
                              controller.setMediaValue('firstFrame', value),
                  ),
                  _Flag(
                    label: l10n.creationLastFrame,
                    active: last,
                    onChanged:
                        first &&
                            !defaults.requiresLastFrame &&
                            defaults.configurableFrameRoles.contains(
                              MediaReferenceRole.lastFrame,
                            )
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
                maximum: defaults.configurableOutputs,
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
                maximum: defaults.configurableReferences,
                minimum: defaults.referenceLimits(const {}).min,
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
                  onChanged:
                      (defaults.supportsNegativePrompt ||
                          defaults.customImageEndpoint)
                      ? (value) =>
                            controller.setMediaValue('negativePrompt', value)
                      : null,
                ),
                _Flag(
                  label: l10n.creationSeed,
                  help: l10n.creationEnableOptionHelp,
                  active: caps.supportsSeed,
                  onChanged:
                      (defaults.supportsSeed || defaults.customImageEndpoint)
                      ? (value) => controller.setMediaValue('seed', value)
                      : null,
                ),
                if (!video)
                  _Flag(
                    label: l10n.creationTransparentBackground,
                    help: l10n.creationEnableOptionHelp,
                    active: caps.supportsTransparent,
                    onChanged:
                        (defaults.supportsTransparent ||
                            defaults.customImageEndpoint)
                        ? (value) =>
                              controller.setMediaValue('transparent', value)
                        : null,
                  ),
              ],
            ),
          ),
          if (!video)
            if (defaults.configurableFormat)
              _Field(
                title: l10n.creationOutputFormat,
                child: _Choices(
                  values: {
                    ...(defaults.customImageEndpoint
                        ? imageFormats
                        : defaults.formats),
                    ...caps.formats,
                  },
                  active: caps.formats,
                  label: (value) => value.toUpperCase(),
                  onChange: (values) =>
                      controller.setMediaValue('formats', values),
                ),
              ),
          _Field(
            title: l10n.creationExtraJson,
            help: l10n.creationExtraJsonHint,
            child: PlainTextInput(
              controller: controller.mediaExtraController,
              placeholder: '{ }',
              minLines: 3,
              maxLines: 8,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.appColors.surfaceFill,
                borderRadius: BorderRadius.circular(10),
              ),
              onChanged: controller.mediaExtraChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _protocolSelector(BuildContext context, AppLocalizations l10n) {
    final selected = controller.mediaProtocol;
    final protocols = MediaApiProtocol.values.where(
      (protocol) =>
          protocol.mode == null || protocol.mode == controller.mediaMode,
    );
    String label(MediaApiProtocol protocol) =>
        protocol == MediaApiProtocol.auto ? l10n.creationAuto : protocol.label;
    void select(MediaApiProtocol protocol) =>
        controller.setMediaValue('protocol', protocol.name);
    if (PlatformUtils.isDesktopTarget) {
      return SizedBox(
        width: double.infinity,
        child: DesktopSelectDropdown<MediaApiProtocol>(
          value: selected,
          options: [
            for (final protocol in protocols)
              DesktopSelectOption(value: protocol, label: label(protocol)),
          ],
          semanticLabel: l10n.creationApiProtocol,
          triggerFillColor: context.appColors.surfaceFill,
          wrapTriggerLabel: true,
          onSelected: select,
        ),
      );
    }
    return CreationAction(
      icon: const Icon(LucideIcons.chevronDown, size: 14),
      onPressed: () => showMobileActionSheet(
        context,
        title: l10n.creationApiProtocol,
        items: [
          for (final protocol in protocols)
            ActionSheetItem(
              icon: LucideIcons.plug,
              label: label(protocol),
              checked: protocol == selected,
              onTap: () => select(protocol),
            ),
        ],
      ),
      child: Text(label(selected)),
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
          Semantics(
            checked: active.contains(value),
            child: IosCardPress(
              focusable: true,
              baseColor: active.contains(value)
                  ? colors.primary.withValues(alpha: .10)
                  : context.appColors.surfaceFill,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: active.contains(value)
                    ? colors.primary.withValues(alpha: .35)
                    : Colors.transparent,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ratioIcons) ...[
                    CreationRatioGlyph(value.toString(), size: 13),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      label(value),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: active.contains(value)
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () {
                final selected = !active.contains(value);
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
          ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
  });
  final int value, minimum, maximum;
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
          onTap: value < maximum ? () => onChanged(value + 1) : null,
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
