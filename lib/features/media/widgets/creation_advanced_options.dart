import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/services/media/media_request.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/plain_text_input.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
import '../../../theme/app_semantic_colors.dart';
import 'creation_controls.dart';
import 'creation_slider.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import '../providers/media_creation_controller.dart';

class CreationAdvancedOptions extends StatelessWidget {
  const CreationAdvancedOptions({super.key, this.topicId});

  final String? topicId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MediaCreationController>();
    final model = state.model;
    if (model == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final caps = model.capabilities;
    final options = state.parameters;
    final invalidJson = state.extraParameters == null;

    Widget choices(
      String key,
      String label,
      List<String> values,
      String Function(String) display,
    ) {
      return _Option(
        label: label,
        child: _Choices(
          values: values,
          value: options[key] is String ? options[key] as String : null,
          display: display,
          onChanged: (value) => state.setParameter(key, value),
        ),
      );
    }

    return Column(
      key: ValueKey(model.key),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.creationCommonOptions,
          style: TextStyle(
            fontSize: 12,
            fontWeight: AppFontWeights.semibold,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 7),
        if (caps.sizes.isEmpty &&
            caps.qualities.isEmpty &&
            caps.formats.isEmpty &&
            !caps.supportsTransparent &&
            !caps.supportsNegativePrompt &&
            !caps.supportsSeed)
          Text(
            l10n.creationNoCommonOptions,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        if (caps.sizes.isNotEmpty)
          choices('size', l10n.creationImageSize, caps.sizes, (value) => value),
        if (caps.qualities.isNotEmpty)
          choices(
            'quality',
            l10n.creationQuality,
            caps.qualities,
            (value) => switch (value) {
              'low' => l10n.creationLowQuality,
              'medium' => l10n.creationMediumQuality,
              'high' => l10n.creationHighQuality,
              _ => l10n.creationAuto,
            },
          ),
        if (caps.supportsTransparent)
          choices(
            'background',
            l10n.creationBackground,
            const ['auto', 'opaque', 'transparent'],
            (value) => switch (value) {
              'opaque' => l10n.creationOpaqueBackground,
              'transparent' => l10n.creationTransparentOption,
              _ => l10n.creationAuto,
            },
          ),
        if (caps.formats.isNotEmpty)
          choices(
            'format',
            l10n.creationOutputFormat,
            [
              if (!caps.formats.contains('auto')) 'auto',
              for (final value in caps.formats)
                if (options['background'] != 'transparent' || value != 'jpeg')
                  value,
            ],
            (value) =>
                value == 'auto' ? l10n.creationAuto : value.toUpperCase(),
          ),
        if (caps.supportsNegativePrompt)
          _Option(
            label: l10n.creationNegativePrompt,
            child: _OptionText(
              key: const ValueKey('negativePrompt'),
              value: options['negativePrompt']?.toString() ?? '',
              lines: 2,
              onChanged: (value) => state.setParameter('negativePrompt', value),
            ),
          ),
        if (caps.supportsSeed)
          _Option(
            label: l10n.creationSeed,
            child: Row(
              children: [
                Expanded(
                  child: _OptionText(
                    key: const ValueKey('seed'),
                    value: options['seed']?.toString() ?? '',
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    keyboardType: TextInputType.number,
                    hint: l10n.creationAuto,
                    onChanged: (value) => state.setParameter('seed', value),
                  ),
                ),
                IosIconButton(
                  icon: Lucide.Shuffle,
                  size: 17,
                  minSize: 36,
                  tooltip: l10n.creationSeed,
                  onTap: () => state.setParameter(
                    'seed',
                    Random().nextInt(1 << 31).toString(),
                  ),
                ),
              ],
            ),
          ),
        if (caps.platformOptions.isNotEmpty) ...[
          const Divider(height: 20),
          Text(
            '${model.provider.name} · ${l10n.creationPlatformOptions}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: AppFontWeights.semibold,
              color: colors.onSurfaceVariant,
            ),
          ),
          for (final field in caps.platformOptions)
            _PlatformInput(
              key: ValueKey(field.key),
              field: field,
              topicId: topicId,
            ),
        ],
        const Divider(height: 20),
        _Option(
          label: l10n.creationExtraJson,
          child: _OptionText(
            key: const ValueKey('extra'),
            value: options['extra']?.toString() ?? '',
            hint: '{ }',
            lines: 3,
            mono: true,
            onChanged: (value) => state.setParameter('extra', value),
          ),
        ),
        Text(
          invalidJson
              ? l10n.modelSpecFormInvalidJson
              : l10n.creationExtraJsonHint,
          style: TextStyle(
            fontSize: 11.5,
            color: invalidJson ? colors.error : colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PlatformInput extends StatelessWidget {
  const _PlatformInput({super.key, required this.field, required this.topicId});

  final MediaParameter field;
  final String? topicId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MediaCreationController>();
    final l10n = AppLocalizations.of(context)!;
    final key = field.key;
    final value = state.parameters[key] ?? field.defaultValue;
    void update(Object? value) =>
        state.setParameter(key, value == field.defaultValue ? null : value);
    final input = switch (field.type) {
      MediaParameterType.enumeration => _Choices(
        values: field.choices,
        value: value is String ? value : null,
        display: (value) => value,
        onChanged: update,
      ),
      MediaParameterType.integer || MediaParameterType.number => _NumericOption(
        field: field,
        value: value is num ? value : null,
        onChanged: update,
      ),
      MediaParameterType.boolean => Align(
        alignment: AlignmentDirectional.centerStart,
        child: IosSwitch(
          value: value == true,
          onChanged: update,
          semanticLabel: key,
        ),
      ),
      MediaParameterType.string => _OptionText(
        value: value?.toString() ?? '',
        onChanged: update,
      ),
      MediaParameterType.image => _imageField(state, l10n),
    };
    return _Option(
      label: key.replaceAll('_', ' '),
      trailing: Text(
        field.required ? '$key · ${l10n.creationParameterRequired}' : key,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFamily: 'monospace',
          fontSize: 11,
        ),
      ),
      child: input,
    );
  }

  Widget _imageField(MediaCreationController state, AppLocalizations l10n) {
    final model = state.model!;
    final path = state.platformImage(topicId, field.key);
    return Row(
      children: [
        Flexible(
          child: CreationAction(
            tone: CreationActionTone.tonal,
            icon: const Icon(Lucide.Image, size: 15),
            child: Text(
              path == null
                  ? l10n.creationSelectPlatformImage
                  : p.basename(path),
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () async {
              final files = await FilePicker.platform.pickFiles(
                type: FileType.image,
              );
              if (files?.files.firstOrNull?.path case final chosen?) {
                state.setPlatformImage(topicId, model.key, field.key, chosen);
              }
            },
          ),
        ),
        if (path != null)
          IosIconButton(
            icon: Lucide.X,
            size: 15,
            minSize: 36,
            onTap: () =>
                state.setPlatformImage(topicId, model.key, field.key, null),
          ),
      ],
    );
  }
}

class _NumericOption extends StatelessWidget {
  const _NumericOption({
    required this.field,
    required this.value,
    required this.onChanged,
  });
  final MediaParameter field;
  final num? value;
  final ValueChanged<num> onChanged;

  @override
  Widget build(BuildContext context) {
    final minimum = (field.minimum ?? 0).toDouble();
    final maximum = (field.maximum ?? 100).toDouble();
    final step = (field.step ?? 1).toDouble();
    final integer = field.type == MediaParameterType.integer;
    final current = (value?.toDouble() ?? minimum).clamp(minimum, maximum);
    if (integer) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IosIconButton(
            icon: Lucide.Minus,
            size: 15,
            minSize: 34,
            onTap: current > minimum
                ? () => onChanged(max(minimum, current - step).round())
                : null,
          ),
          Text(value == null ? '—' : '${current.round()}'),
          IosIconButton(
            icon: Lucide.Plus,
            size: 15,
            minSize: 34,
            onTap: current < maximum
                ? () => onChanged(min(maximum, current + step).round())
                : null,
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: CreationSlider(
            label: field.key,
            formatValue: (v) => v.toStringAsFixed(2),
            min: minimum,
            max: maximum,
            divisions: ((maximum - minimum) / step).round().clamp(1, 200),
            value: current,
            onChanged: (position) =>
                onChanged(double.parse(position.toStringAsFixed(2))),
          ),
        ),
        Text(value == null ? '—' : current.toStringAsFixed(1)),
      ],
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.value,
    required this.display,
    required this.onChanged,
  });
  final List<String> values;
  final String? value;
  final String Function(String) display;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = values.indexOf(value ?? 'auto');
    return SlidingSegmentedTabs(
      height: 36,
      expand: values.length <= 4,
      allowReselect: true,
      index: index,
      tabs: [for (final v in values) SegmentedTab(label: display(v))],
      onChanged: (i) =>
          onChanged(i == index || values[i] == 'auto' ? null : values[i]),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.child, this.trailing});
  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: AppFontWeights.medium),
            ),
            if (trailing case final hint?) hint,
          ],
        ),
        const SizedBox(height: 4),
        child,
      ],
    ),
  );
}

class _OptionText extends StatefulWidget {
  const _OptionText({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.lines = 1,
    this.mono = false,
    this.keyboardType,
    this.inputFormatters,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int lines;
  final bool mono;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<_OptionText> createState() => _OptionTextState();
}

class _OptionTextState extends State<_OptionText> {
  late final _text = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _OptionText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _text.text) {
      _text.text = widget.value;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlainTextInput(
    controller: _text,
    placeholder: widget.hint,
    minLines: widget.lines,
    maxLines: widget.lines + (widget.lines > 1 ? 2 : 0),
    keyboardType: widget.keyboardType,
    inputFormatters: widget.inputFormatters,
    onChanged: widget.onChanged,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    style: TextStyle(
      fontSize: 13,
      fontFamily: widget.mono ? 'monospace' : null,
    ),
    decoration: BoxDecoration(
      color: context.appColors.surfaceFill,
      borderRadius: BorderRadius.circular(10),
    ),
  );
}
