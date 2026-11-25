import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/services/media/media_request.dart';
import '../../../core/services/media/adapters/fal_media.dart';
import '../../../core/services/media/media_models.dart';
import '../../../core/services/media/fal_model_discovery.dart';
import '../../provider/widgets/fal_catalog_notice.dart';
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
    final platformOptions = state.platformOptionsFor(topicId);
    final options = state.parameters;
    final canFetch = state.canFetchFalSettings(model);
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
          automatic: 'auto',
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
                if (FalMediaAdapter.transparentEdit(model.spec.upstreamId, {
                      'background': options['fal:background'],
                    })
                    ? value == 'png' || value == 'auto'
                    : options['background'] != 'transparent' || value != 'jpeg')
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
        if (canFetch || platformOptions.isNotEmpty) ...[
          const SizedBox(height: 14),
          if (canFetch)
            _FalSettingsHeader(
              key: ValueKey((
                model.key,
                model.spec.upstreamId,
                model.provider.baseUrl,
              )),
              model: model,
            )
          else
            Text(
              '${model.provider.name} · ${l10n.creationPlatformOptions}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: AppFontWeights.semibold,
                color: colors.onSurfaceVariant,
              ),
            ),
          for (final field in platformOptions)
            _PlatformInput(
              key: ValueKey(field.key),
              field: field,
              topicId: topicId,
            ),
        ],
        const SizedBox(height: 14),
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

class _FalSettingsHeader extends StatefulWidget {
  const _FalSettingsHeader({super.key, required this.model});
  final MediaModelChoice model;

  @override
  State<_FalSettingsHeader> createState() => _FalSettingsHeaderState();
}

class _FalSettingsHeaderState extends State<_FalSettingsHeader> {
  CancelToken? _pending;
  Object? _error;
  bool _unlisted = false;

  @override
  void initState() {
    super.initState();
    final model = widget.model;
    final override = model.provider.modelOverrides[model.spec.id];
    final endpoint = override is Map ? override['falEndpoint'] : null;
    _unlisted =
        endpoint is Map &&
        endpoint['id'] == model.spec.upstreamId &&
        endpoint['unlisted'] == true;
    if (!_unlisted &&
        !FalModelDiscovery.hasAdditionalSettings(
          model.spec.upstreamId,
          override,
        )) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (_pending != null) return;
    final token = CancelToken();
    setState(() {
      _pending = token;
      _error = null;
    });
    try {
      final found = await context
          .read<MediaCreationController>()
          .refreshFalSettings(widget.model, token);
      if (mounted && !token.isCancelled && found != null) _unlisted = !found;
    } catch (error) {
      if (mounted && !token.isCancelled) _error = error;
    } finally {
      if (mounted && !token.isCancelled) setState(() => _pending = null);
    }
  }

  @override
  void dispose() {
    _pending?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.falAdditionalSettings,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            if (_pending != null)
              Semantics(
                label: l10n.falCheckingModel,
                child: const SizedBox.square(
                  dimension: 30,
                  child: Center(child: CupertinoActivityIndicator(radius: 7)),
                ),
              )
            else
              IosIconButton(
                icon: Lucide.RefreshCw,
                minSize: 30,
                size: 15,
                tooltip: l10n.falRefreshAdditionalSettings,
                onTap: _load,
              ),
          ],
        ),
        if (_error case final error?)
          Text(
            falCatalogErrorMessage(l10n, error),
            style: TextStyle(fontSize: 12, color: cs.error),
          )
        else if (_pending == null &&
            (_unlisted || widget.model.capabilities.platformOptions.isEmpty))
          Text(
            _unlisted
                ? l10n.falNoPublishedSettings
                : l10n.falNoAdditionalSettings,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
    final raw = state.parameters[field.storageKey];
    final value = raw ?? field.defaultValue;
    final title = switch (key) {
      'watermark' when field.title != null => l10n.falWatermark,
      'sync_mode' when field.title != null => l10n.falSyncMode,
      'enable_safety_checker' when field.title != null => l10n.falSafetyChecker,
      'background' when field.title != null => l10n.creationBackground,
      _ => field.title ?? key.replaceAll('_', ' '),
    };
    void update(Object? value) => state.setParameter(
      field.storageKey,
      value == field.defaultValue ? null : value,
    );
    final structured = const {
      MediaParameterType.array,
      MediaParameterType.object,
      MediaParameterType.json,
    }.contains(field.type);
    final invalid = !field.acceptsDraft(raw);
    final hint = field.defaultValue == null
        ? l10n.creationAuto
        : structured
        ? jsonEncode(field.defaultValue)
        : field.defaultValue.toString();
    final input = switch (field.type) {
      MediaParameterType.boolean => Align(
        alignment: AlignmentDirectional.centerStart,
        child: IosSwitch(
          value: value == true,
          onChanged: field.readOnly || field.constant ? null : update,
          semanticLabel: title,
        ),
      ),
      _ when field.readOnly || field.constant => Text(
        value?.toString() ?? l10n.creationAuto,
      ),
      MediaParameterType.enumeration => _Choices<Object>(
        values: field.choices,
        value: value,
        display: (v) => v.toString(),
        onChanged: update,
      ),
      MediaParameterType.integer || MediaParameterType.number
          when field.title != null &&
              (field.storageKey != field.key ||
                  field.minimum == null ||
                  field.maximum == null ||
                  field.exclusiveMinimum != null ||
                  field.exclusiveMaximum != null ||
                  field.multipleOf != null) =>
        _OptionText(
          value: raw?.toString() ?? '',
          hint: hint,
          keyboardType: TextInputType.numberWithOptions(
            signed: true,
            decimal: field.type == MediaParameterType.number,
          ),
          onChanged: update,
        ),
      MediaParameterType.integer || MediaParameterType.number => _NumericOption(
        field: field,
        value: value is num ? value : null,
        onChanged: update,
      ),
      MediaParameterType.string => _OptionText(
        value: raw?.toString() ?? '',
        hint: hint,
        onChanged: update,
      ),
      MediaParameterType.array ||
      MediaParameterType.object ||
      MediaParameterType.json => _OptionText(
        value: raw == null
            ? ''
            : raw is String
            ? raw
            : jsonEncode(raw),
        hint: field.defaultValue == null
            ? switch (field.type) {
                MediaParameterType.array => '[ ]',
                MediaParameterType.object => '{ }',
                _ => 'JSON',
              }
            : hint,
        lines: 2,
        mono: true,
        onChanged: update,
      ),
      MediaParameterType.image => _imageField(state, l10n),
    };
    return _Option(
      label: title,
      trailing: Text(
        field.required ? '$key · ${l10n.creationParameterRequired}' : key,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFamily: 'monospace',
          fontSize: 11,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (structured && field.choices.isNotEmpty)
            _Choices<Object>(
              values: field.choices,
              value: raw == null
                  ? field.defaultValue
                  : !invalid
                  ? field.parseDraft(raw)
                  : null,
              display: (v) => v.toString(),
              onChanged: (v) => update(v == null ? null : jsonEncode(v)),
            ),
          input,
          if (invalid)
            Text(
              structured
                  ? l10n.modelSpecFormInvalidJson
                  : l10n.modelSpecFormInvalidNumber,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          if (field.description case final description?
              when description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
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

class _Choices<T extends Object> extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.value,
    required this.display,
    this.automatic,
    required this.onChanged,
  });
  final List<T> values;
  final T? value, automatic;
  final String Function(T) display;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value ?? automatic;
    final index = selected == null ? -1 : values.indexOf(selected);
    return SlidingSegmentedTabs(
      height: 36,
      fitLabels: true,
      allowReselect: true,
      index: index,
      tabs: [for (final v in values) SegmentedTab(label: display(v))],
      onChanged: (i) =>
          onChanged(i == index || values[i] == automatic ? null : values[i]),
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
    padding: const EdgeInsets.only(bottom: 12),
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
