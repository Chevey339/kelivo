import 'package:flutter/material.dart';

import '../../../core/models/tool_schema_override.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../widgets/tool_schema_editor_form.dart';

class ToolSchemaEditorPage extends StatefulWidget {
  const ToolSchemaEditorPage({
    super.key,
    required this.toolName,
    required this.defaultDefinition,
    this.initialOverride,
  });

  final String toolName;
  final Map<String, dynamic> defaultDefinition;
  final ToolSchemaOverride? initialOverride;

  @override
  State<ToolSchemaEditorPage> createState() => _ToolSchemaEditorPageState();
}

class _ToolSchemaEditorPageState extends State<ToolSchemaEditorPage> {
  bool _leaving = false;
  late ToolSchemaOverride _current =
      widget.initialOverride ?? const ToolSchemaOverride();

  void _requestClose() => _popWithResult(null);

  void _save() => _popWithResult(_current);

  void _popWithResult(ToolSchemaOverride? result) {
    if (_leaving) return;
    _leaving = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return PopScope<ToolSchemaOverride?>(
      child: Scaffold(
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
              onTap: _requestClose,
            ),
          ),
          title: Text(l10n.toolSchemaEditorPageTitle),
          actions: [
            Tooltip(
              message: l10n.searchServicesEditDialogSave,
              child: IosIconButton(
                icon: Lucide.Check,
                color: cs.onSurface,
                size: 22,
                minSize: 44,
                semanticLabel: l10n.searchServicesEditDialogSave,
                onTap: _save,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            ToolSchemaEditorForm(
              defaultDefinition: widget.defaultDefinition,
              initialOverride: widget.initialOverride,
              onChanged: (value) => _current = value,
            ),
          ],
        ),
      ),
    );
  }
}
