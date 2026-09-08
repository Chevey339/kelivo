import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/environment_variable.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

Future<void> openEnvironmentVariablesPage(BuildContext context) {
  final provider = context.read<EnvironmentProvider>();
  final page = ChangeNotifierProvider.value(
    value: provider,
    child: const EnvironmentVariablesPage(),
  );
  if (useDesktopWorkspaceLayout(context)) {
    return showAppDialog<void>(
      context,
      maxWidth: 640,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: page,
      ),
    );
  }
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
}

/// A shared settings list with platform-appropriate navigation chrome.
class EnvironmentVariablesPage extends StatefulWidget {
  const EnvironmentVariablesPage({super.key});

  @override
  State<EnvironmentVariablesPage> createState() =>
      _EnvironmentVariablesPageState();
}

class _EnvironmentVariablesPageState extends State<EnvironmentVariablesPage> {
  final _visible = <String>{};

  Future<void> _edit([EnvironmentVariable? variable]) async {
    final editor = _VariableEditor(
      provider: context.read<EnvironmentProvider>(),
      variable: variable,
      desktop: useDesktopWorkspaceLayout(context),
    );
    if (useDesktopWorkspaceLayout(context)) {
      await showAppDialog<void>(context, maxWidth: 520, child: editor);
    } else {
      await showFormSheet<void>(context, builder: (_) => editor);
    }
    if (mounted) setState(_visible.clear);
  }

  Future<void> _setPrivacy(bool enabled) async {
    try {
      await context.read<EnvironmentProvider>().setPrivacyMode(enabled);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(
            context,
          )!.workspaceEnvVariablesSaveFailed,
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      showAppSnackBar(
        context,
        message: AppLocalizations.of(
          context,
        )!.chatMessageWidgetCopiedToClipboard,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final env = context.watch<EnvironmentProvider>();
    final desktop = useDesktopWorkspaceLayout(context);
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SectionCard(
          children: [
            IosSwitchRow(
              key: const ValueKey('environment-privacy-mode'),
              icon: Lucide.Shield,
              label: l10n.workspaceEnvPrivacyMode,
              value: env.privacyMode,
              onChanged: _setPrivacy,
            ),
          ],
        ),
        IosSectionFooter(text: l10n.workspaceEnvPrivacyDetail),
        IosSectionHeader(text: l10n.workspaceEnvVariablesTitle),
        if (env.variables.isNotEmpty)
          SectionCard(
            children: [
              for (var i = 0; i < env.variables.length; i++) ...[
                if (i > 0) const IosRowDivider(),
                _variableRow(env.variables[i], l10n),
              ],
            ],
          )
        else
          IosSectionFooter(text: l10n.workspaceEnvVariablesEmpty),
        const SizedBox(height: 12),
        IosTileButton(
          key: const ValueKey('environment-variable-add'),
          label: l10n.workspaceEnvVariableAdd,
          icon: Lucide.Plus,
          onTap: () => _edit(),
        ),
        IosSectionFooter(text: l10n.workspaceEnvVariablesScope),
      ],
    );
    if (desktop) {
      return Column(
        children: [
          AppDialogHeader(title: l10n.workspaceEnvVariablesTitle),
          Expanded(child: body),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workspaceEnvVariablesTitle),
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          minSize: 44,
          size: 22,
          tooltip: l10n.settingsPageBackButton,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: body,
    );
  }

  Widget _variableRow(EnvironmentVariable variable, AppLocalizations l10n) {
    final visible = _visible.contains(variable.name);
    return IosNavRow(
      key: ValueKey('environment-variable-${variable.name}'),
      icon: Lucide.KeyRound,
      label: variable.name,
      subtitle: visible ? variable.value : '••••••••',
      caption: variable.note.isEmpty ? null : variable.note,
      onTap: () => _edit(variable),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IosIconButton(
            icon: visible ? Lucide.EyeOff : Lucide.Eye,
            minSize: 36,
            tooltip: visible
                ? l10n.providerDetailPageHideTooltip
                : l10n.providerDetailPageShowTooltip,
            onTap: () => setState(() {
              if (visible) {
                _visible.remove(variable.name);
              } else {
                _visible.add(variable.name);
              }
            }),
          ),
          IosIconButton(
            icon: Lucide.Copy,
            minSize: 36,
            tooltip: l10n.assistantSettingsCopyButton,
            onTap: () => _copy(variable.value),
          ),
        ],
      ),
    );
  }
}

class _VariableEditor extends StatefulWidget {
  const _VariableEditor({
    required this.provider,
    required this.desktop,
    this.variable,
  });
  final EnvironmentProvider provider;
  final EnvironmentVariable? variable;
  final bool desktop;

  @override
  State<_VariableEditor> createState() => _VariableEditorState();
}

class _VariableEditorState extends State<_VariableEditor> {
  late final _name = TextEditingController(text: widget.variable?.name);
  late final _value = TextEditingController(text: widget.variable?.value);
  late final _note = TextEditingController(text: widget.variable?.note);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save({bool delete = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context)!;
    try {
      if (delete) {
        await widget.provider.deleteVariable(widget.variable!.name);
      } else {
        await widget.provider.saveVariable(
          EnvironmentVariable(
            name: _name.text,
            value: _value.text,
            note: _note.text,
          ),
          previousName: widget.variable?.name,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = switch (error) {
            EnvironmentVariableError.invalidName =>
              l10n.workspaceEnvVariableInvalidName,
            EnvironmentVariableError.invalidValue =>
              l10n.workspaceEnvVariableInvalidValue,
            EnvironmentVariableError.duplicateName =>
              l10n.workspaceEnvVariableDuplicate,
            _ => l10n.workspaceEnvVariablesSaveFailed,
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.variable == null
        ? l10n.workspaceEnvVariableAdd
        : l10n.workspaceEnvVariableEdit;
    final children = <Widget>[
      SectionCard(
        children: [
          IosFormTextField(
            key: const ValueKey('environment-variable-name'),
            label: l10n.workspaceEnvVariableName,
            controller: _name,
            hintText: 'API_KEY',
            inlineLabel: false,
            autofocus: widget.variable == null,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_busy,
          ),
          IosFormTextField(
            key: const ValueKey('environment-variable-value'),
            label: l10n.workspaceEnvVariableValue,
            controller: _value,
            inlineLabel: false,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_busy,
          ),
          IosFormTextField(
            label: l10n.workspaceEnvVariableNote,
            controller: _note,
            inlineLabel: false,
            enabled: !_busy,
          ),
        ],
      ),
      IosSectionFooter(text: l10n.workspaceEnvVariableNameHint),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (widget.variable != null) ...[
        IosNavRow(
          key: const ValueKey('environment-variable-delete'),
          label: l10n.workspaceFilesDelete,
          icon: Lucide.Trash2,
          destructive: true,
          trailing: const SizedBox.shrink(),
          onTap: _busy ? null : () => _save(delete: true),
        ),
        const SizedBox(height: 8),
      ],
    ];
    final actions = FormSheetActions(
      cancelLabel: l10n.workspaceFilesCancel,
      confirmLabel: l10n.workspaceFilesSave,
      onCancel: () {
        if (!_busy) Navigator.of(context).pop();
      },
      onConfirm: _busy ? null : _save,
      busy: _busy,
    );
    return PopScope(
      canPop: !_busy,
      child: widget.desktop
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppDialogHeader(title: title),
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(children: children),
                    ),
                  ),
                ),
                Padding(padding: const EdgeInsets.all(16), child: actions),
              ],
            )
          : FormSheet(title: title, actions: actions, children: children),
    );
  }
}
