import 'package:flutter/material.dart';

import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/workspace/desktop_process_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';

class NativeShellDialog extends StatefulWidget {
  const NativeShellDialog({
    super.key,
    required this.environment,
    required this.runtime,
    required this.runtimeProvider,
  });

  final EnvironmentProvider environment;
  final DesktopProcessRuntime runtime;
  final WorkspaceRuntimeProvider runtimeProvider;

  @override
  State<NativeShellDialog> createState() => _NativeShellDialogState();
}

class _NativeShellDialogState extends State<NativeShellDialog> {
  late final _path = TextEditingController(
    text: widget.environment.nativeShellPath,
  );
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final path = _path.text.trim();
      await widget.runtime.shellResolver.resolve(path);
      if (!mounted) return;
      await widget.environment.setNativeShellPath(path);
      widget.runtime.refreshShell();
      await widget.runtimeProvider.refresh();
      if (mounted) Navigator.of(context).pop();
    } on Exception {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_saving,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogHeader(title: l10n.workspaceEnvNativeShellTitle),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionCard(
                    children: [
                      IosFormTextField(
                        key: const ValueKey('native-shell-path'),
                        label: l10n.workspaceEnvShellPath,
                        controller: _path,
                        inlineLabel: false,
                        hintText: l10n.workspaceEnvShellAutomatic,
                        enabled: !_saving,
                        autocorrect: false,
                        enableSuggestions: false,
                        onSubmitted: (_) {
                          if (!_saving) _save();
                        },
                      ),
                    ],
                  ),
                  IosSectionFooter(text: l10n.workspaceEnvNativeShellHint),
                  if (_failed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        l10n.workspaceEnvNativeShellInvalid,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  IosTileButton(
                    key: const ValueKey('native-shell-save'),
                    label: l10n.workspaceEnvNativeShellSave,
                    icon: Lucide.Check,
                    enabled: !_saving,
                    onTap: _save,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
