import 'package:flutter/material.dart';

import '../../../core/models/tool_schema_override.dart';
import '../../../core/services/tools/tool_schema_overrides.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'tool_schema_ui.dart';

class ToolSchemaEditorForm extends StatefulWidget {
  const ToolSchemaEditorForm({
    super.key,
    required this.defaultDefinition,
    this.initialOverride,
    required this.onChanged,
  });

  final Map<String, dynamic> defaultDefinition;
  final ToolSchemaOverride? initialOverride;
  final ValueChanged<ToolSchemaOverride> onChanged;

  @override
  State<ToolSchemaEditorForm> createState() => _ToolSchemaEditorFormState();
}

class _ToolSchemaEditorFormState extends State<ToolSchemaEditorForm> {
  late final TextEditingController _descController;
  late final List<ToolParamDescriptor> _params;
  late final Map<String, TextEditingController> _paramControllers;
  late final String _toolName;
  late final String _defaultDescription;
  bool _paramsExpanded = false;

  @override
  void initState() {
    super.initState();
    _toolName = _nameOf(widget.defaultDefinition) ?? '';
    _defaultDescription = _descriptionOf(widget.defaultDefinition) ?? '';
    _params = ToolSchemaOverrides.describeParams(widget.defaultDefinition);
    final initial = widget.initialOverride;
    _descController = TextEditingController(
      text: _effective(initial?.description, _defaultDescription),
    );
    _paramControllers = {
      for (final p in _params)
        p.path: TextEditingController(
          text: _effective(
            initial?.paramDescriptions[p.path],
            p.defaultDescription ?? '',
          ),
        ),
    };
    _descController.addListener(_emit);
    for (final c in _paramControllers.values) {
      c.addListener(_emit);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    for (final c in _paramControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(_currentOverride());
    if (mounted) setState(() {});
  }

  ToolSchemaOverride _currentOverride() {
    final desc = _overrideOrNull(_descController.text, _defaultDescription);
    final params = <String, String>{};
    for (final p in _params) {
      final value = _overrideOrNull(
        _paramControllers[p.path]!.text,
        p.defaultDescription ?? '',
      );
      if (value != null) params[p.path] = value;
    }
    return ToolSchemaOverride(description: desc, paramDescriptions: params);
  }

  void _restoreDefaults() {
    _descController.text = _defaultDescription;
    for (final p in _params) {
      _paramControllers[p.path]!.text = p.defaultDescription ?? '';
    }
    widget.onChanged(const ToolSchemaOverride());
    setState(() {});
  }

  bool get _hasParamOverrides {
    return _currentOverride().paramDescriptions.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Text(
            l10n.toolSchemaSettingsToolName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Icon(
                    toolSchemaIconFor(_toolName),
                    size: 20,
                    color: cs.onSurface.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    _toolName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.medium,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        IosFormTextField(
          key: const ValueKey('tool-schema-desc'),
          label: l10n.toolSchemaSettingsDescriptionLabel,
          controller: _descController,
          minLines: 4,
          maxLines: 12,
          inlineLabel: false,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          outerPadding: EdgeInsets.zero,
        ),
        if (_params.isNotEmpty) ...[
          const SizedBox(height: 18),
          IosCardPress(
            haptics: false,
            baseColor: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            padding: EdgeInsets.zero,
            onTap: () => setState(() => _paramsExpanded = !_paramsExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.toolSchemaSettingsParamDescriptions(_params.length),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: AppFontWeights.medium,
                        color: cs.onSurface.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  if (_hasParamOverrides)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ToolSchemaModifiedBadge(
                        label: l10n.toolSchemaSettingsModified,
                      ),
                    ),
                  Icon(
                    _paramsExpanded ? Lucide.ChevronDown : Lucide.ChevronRight,
                    size: 16,
                    color: cs.onSurface.withValues(alpha: 0.35),
                  ),
                ],
              ),
            ),
          ),
          if (_paramsExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [for (final p in _params) _paramEditor(context, p)],
              ),
            ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: IosTileButton(
            icon: Lucide.RotateCcw,
            label: l10n.toolSchemaSettingsResetDefault,
            onTap: _restoreDefaults,
          ),
        ),
      ],
    );
  }

  Widget _paramEditor(BuildContext context, ToolParamDescriptor param) {
    final cs = Theme.of(context).colorScheme;
    final tags = <String>[
      if (param.type != null) param.type!,
      if (param.enumValues != null && param.enumValues!.isNotEmpty)
        param.enumValues!.join(' | '),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SelectableText(
                param.path,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: AppFontWeights.medium,
                  color: cs.onSurface,
                ),
              ),
              for (final tag in tags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceCardFill,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ),
            ],
          ),
          IosFormTextField(
            key: ValueKey('tool-schema-param-${param.path}'),
            label: '',
            controller: _paramControllers[param.path]!,
            minLines: 2,
            maxLines: 8,
            inlineLabel: false,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            outerPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          ),
        ],
      ),
    );
  }
}

String _effective(String? override, String fallback) {
  if (override != null && override.trim().isNotEmpty) return override;
  return fallback;
}

String? _overrideOrNull(String text, String defaultText) {
  if (text.trim().isEmpty) return null;
  if (text == defaultText) return null;
  return text;
}

String? _nameOf(Map<String, dynamic> def) {
  final function = def['function'];
  if (function is! Map) return null;
  final name = function['name'];
  return name is String ? name : null;
}

String? _descriptionOf(Map<String, dynamic> def) {
  final function = def['function'];
  if (function is! Map) return null;
  final desc = function['description'];
  return desc is String ? desc : null;
}
