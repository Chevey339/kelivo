import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/models/media_creation.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/plain_text_input.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../media/widgets/creation_controls.dart';
import '../../media/widgets/creation_picker.dart';
import 'model_select_sheet.dart';

({IconData icon, String title, String subtitle}) creationDefaultModelLabels(
  AppLocalizations l10n,
  CreationModelSlot slot,
) => switch (slot) {
  CreationModelSlot.image => (
    icon: Lucide.Image,
    title: l10n.creationDefaultImage,
    subtitle: l10n.creationDefaultImageHelp,
  ),
  CreationModelSlot.video => (
    icon: LucideIcons.video,
    title: l10n.creationDefaultVideo,
    subtitle: l10n.creationDefaultVideoHelp,
  ),
  CreationModelSlot.promptEnhance => (
    icon: LucideIcons.wandSparkles,
    title: l10n.creationDefaultEnhance,
    subtitle: l10n.creationDefaultEnhanceHelp,
  ),
};

Future<bool> pickCreationDefaultModel(
  BuildContext context,
  CreationModelSlot slot,
) async {
  final settings = context.read<SettingsProvider>();
  final current = settings.creationModel(slot);
  final selected = await showModelSelector(
    context,
    creationSlot: slot,
    initialProviderKey: current?.providerKey,
    initialModelId: current?.modelId,
  );
  if (selected == null || !context.mounted) return false;
  await settings.setCreationModel(slot, (
    providerKey: selected.providerKey,
    modelId: selected.modelId,
  ));
  return true;
}

Future<void> editCreationEnhancePrompt(
  BuildContext context, {
  required bool desktop,
}) async {
  final settings = context.read<SettingsProvider>();
  final l10n = AppLocalizations.of(context)!;
  Widget editor(BuildContext dialog) => _EnhancePromptEditor(
    initial: settings.promptEnhancePrompt,
    title: desktop ? l10n.creationDefaultEnhance : null,
    onSave: (value) => Navigator.of(dialog).pop(value),
  );
  final value = desktop
      ? await showCreationDialog<String>(
          context,
          maxWidth: 560,
          child: Builder(builder: editor),
        )
      : await showCreationPicker<String>(
          context,
          desktop: false,
          title: l10n.creationDefaultEnhance,
          builder: editor,
        );
  if (value != null && context.mounted) {
    await settings.setPromptEnhancePrompt(value);
  }
}

class _EnhancePromptEditor extends StatefulWidget {
  const _EnhancePromptEditor({
    required this.initial,
    required this.title,
    required this.onSave,
  });

  final String initial;
  final String? title;
  final ValueChanged<String> onSave;

  @override
  State<_EnhancePromptEditor> createState() => _EnhancePromptEditorState();
}

class _EnhancePromptEditorState extends State<_EnhancePromptEditor> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          if (widget.title case final title?)
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(
            l10n.defaultModelPagePromptLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          PlainTextInput(
            controller: _text,
            minLines: 4,
            maxLines: 8,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.appColors.surfaceFill,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Text(
            l10n.creationEnhanceTemplateVariable('{prompt}'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              CreationAction(
                onPressed: () =>
                    _text.text = SettingsProvider.defaultPromptEnhancePrompt,
                child: Text(l10n.defaultModelPageResetDefault),
              ),
              CreationAction(
                tone: CreationActionTone.primary,
                onPressed: () => widget.onSave(_text.text),
                child: Text(l10n.defaultModelPageSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
