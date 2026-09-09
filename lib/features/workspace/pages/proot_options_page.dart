import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';

class ProotOptionsPage extends StatefulWidget {
  const ProotOptionsPage({super.key});
  @override
  State<ProotOptionsPage> createState() => _ProotOptionsPageState();
}

class _ProotOptionsPageState extends State<ProotOptionsPage> {
  late final TextEditingController _shell;
  late final TextEditingController _args;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final env = context.read<EnvironmentProvider>();
    _shell = TextEditingController(text: env.prootShell);
    _args = TextEditingController(text: env.prootArguments.join('\n'));
  }

  @override
  void dispose() {
    _shell.dispose();
    _args.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<EnvironmentProvider>().setProotOptions(
        shell: _shell.text,
        arguments: _args.text,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context)!.workspaceEnvProotInvalid,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workspaceEnvProotOptions),
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            children: [
              IosFormTextField(
                key: const ValueKey('proot-shell'),
                label: l10n.workspaceEnvShellPath,
                controller: _shell,
                inlineLabel: false,
                hintText: l10n.workspaceEnvShellAutomatic,
                autocorrect: false,
                enableSuggestions: false,
              ),
            ],
          ),
          IosSectionFooter(text: l10n.workspaceEnvShellHint),
          SectionCard(
            children: [
              IosFormTextField(
                key: const ValueKey('proot-arguments'),
                label: l10n.workspaceEnvProotArguments,
                controller: _args,
                inlineLabel: false,
                maxLines: 10,
                minLines: 4,
                hintText: '--kernel-release=5.10.0',
                autocorrect: false,
                enableSuggestions: false,
              ),
            ],
          ),
          IosSectionFooter(text: l10n.workspaceEnvProotArgumentsHint),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          IosTileButton(
            key: const ValueKey('proot-options-save'),
            label: l10n.workspaceEnvDownloadSave,
            icon: Lucide.Check,
            enabled: !_saving,
            onTap: _save,
          ),
        ],
      ),
    );
  }
}
