import 'package:flutter/material.dart';

import '../../../core/models/tool_schema_override.dart';
import '../../../core/services/tools/tool_schema_overrides.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

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
    final initial = _currentOverride();
    return initial.paramDescriptions.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.toolSchemaSettingsToolName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: AppFontWeights.semibold,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(
          _toolName,
          style: TextStyle(
            fontSize: 15,
            fontFamily: 'monospace',
            fontWeight: AppFontWeights.medium,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        IosFormTextField(
          key: const ValueKey('tool-schema-desc'),
          label: l10n.toolSchemaSettingsDescriptionLabel,
          controller: _descController,
          minLines: 4,
          maxLines: 12,
          inlineLabel: false,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
        ),
        if (_params.isNotEmpty) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            initiallyExpanded: false,
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.toolSchemaSettingsParamDescriptions(_params.length),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.medium,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (_hasParamOverrides)
                  _ModifiedBadge(label: l10n.toolSchemaSettingsModified),
              ],
            ),
            children: [for (final p in _params) _paramEditor(context, p)],
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _restoreDefaults,
            child: Text(l10n.toolSchemaSettingsResetDefault),
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
                  fontFamily: 'monospace',
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

class _ModifiedBadge extends StatelessWidget {
  const _ModifiedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: AppFontWeights.medium,
          color: cs.primary,
        ),
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
