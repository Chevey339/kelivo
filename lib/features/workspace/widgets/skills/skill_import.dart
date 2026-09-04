import 'dart:async';

import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/desktop/menu_anchor.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_labels.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/action_sheet.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum SkillImportKind { paste, file, github }

Future<void> startSkillImport(
  BuildContext context, {
  GlobalKey? anchorKey,
}) async {
  final kind = await showSkillImportMenu(context, anchorKey: anchorKey);
  if (kind == null || !context.mounted) return;
  await runSkillImport(context, kind);
}

Future<void> runSkillImport(BuildContext context, SkillImportKind kind) async {
  switch (kind) {
    case SkillImportKind.paste:
      await showSkillPasteImport(context);
    case SkillImportKind.file:
      await importSkillFromFile(context);
    case SkillImportKind.github:
      await showSkillGitHubImport(context);
  }
}

Offset _menuAnchor(BuildContext context, GlobalKey? anchorKey) {
  final box = anchorKey?.currentContext?.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize) {
    return box.localToGlobal(Offset.zero);
  }
  return DesktopMenuAnchor.positionOrCenter(context);
}

Future<SkillImportKind?> showSkillImportMenu(
  BuildContext context, {
  GlobalKey? anchorKey,
}) async {
  final l10n = AppLocalizations.of(context)!;
  SkillImportKind? selected;
  await showAdaptiveActionMenu(
    context,
    anchor: _menuAnchor(context, anchorKey),
    items: [
      ActionSheetItem(
        icon: Lucide.ClipboardPaste,
        label: l10n.skillsImportPaste,
        onTap: () => selected = SkillImportKind.paste,
      ),
      ActionSheetItem(
        icon: Lucide.FileUp,
        label: l10n.skillsImportFile,
        onTap: () => selected = SkillImportKind.file,
      ),
      ActionSheetItem(
        icon: Lucide.GitFork,
        label: l10n.skillsImportGitHub,
        onTap: () => selected = SkillImportKind.github,
      ),
    ],
  );
  return selected;
}

Future<void> importSkillFromFile(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['md', 'zip'],
  );
  final path = result?.files.single.path;
  if (path == null || !context.mounted) return;
  try {
    await context.read<SkillsService>().importFromFile(path);
  } catch (error) {
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: skillErrorMessage(error),
      type: NotificationType.error,
    );
  }
}

Future<bool> showSkillPasteImport(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showSkillTextImport(
    context: context,
    title: l10n.skillsImportPaste,
    label: l10n.skillsImportPasteLabel,
    hint: l10n.skillsImportPasteHint,
    confirmLabel: l10n.skillsImportConfirm,
    minLines: 8,
    maxLines: 16,
    onSubmit: (markdown) {
      return context.read<SkillsService>().importFromText(markdown);
    },
  );
}

Future<bool> showSkillGitHubImport(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showSkillTextImport(
    context: context,
    title: l10n.skillsImportGitHub,
    label: l10n.skillsImportGitHubRepoLabel,
    hint: l10n.skillsImportGitHubUrlHint,
    confirmLabel: l10n.skillsImportConfirm,
    minLines: 1,
    maxLines: 1,
    keyboardType: TextInputType.url,
    onSubmit: (url) {
      return context.read<SkillsService>().importFromGitHub(url.trim());
    },
  );
}

Future<bool> showSkillTextImport({
  required BuildContext context,
  required String title,
  required String label,
  required String hint,
  required String confirmLabel,
  int maxLines = 8,
  int? minLines,
  String initial = '',
  TextInputType? keyboardType,
  required Future<void> Function(String text) onSubmit,
}) async {
  final form = SkillTextImportForm(
    title: title,
    label: label,
    hint: hint,
    confirmLabel: confirmLabel,
    maxLines: maxLines,
    minLines: minLines,
    initial: initial,
    keyboardType: keyboardType,
    onSubmit: onSubmit,
  );

  if (ResponsiveHelper.isDesktop(context)) {
    final result = await showAppDialog<bool>(
      context,
      maxWidth: 520,
      child: form,
    );
    return result == true;
  }
  final result = await showFormSheet<bool>(context, builder: (_) => form);
  return result == true;
}

class SkillTextImportForm extends StatefulWidget {
  const SkillTextImportForm({
    super.key,
    required this.title,
    required this.label,
    required this.hint,
    required this.confirmLabel,
    required this.onSubmit,
    this.maxLines = 8,
    this.minLines,
    this.initial = '',
    this.keyboardType,
  });

  final String title;
  final String label;
  final String hint;
  final String confirmLabel;
  final int maxLines;
  final int? minLines;
  final String initial;
  final TextInputType? keyboardType;
  final Future<void> Function(String text) onSubmit;

  @override
  State<SkillTextImportForm> createState() => _SkillTextImportFormState();
}

class _SkillTextImportFormState extends State<SkillTextImportForm> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  String? _error;
  bool _busy = false;

  int get _maxLines => widget.maxLines < 1 ? 1 : widget.maxLines;

  int get _minLines {
    final requested = widget.minLines ?? (_maxLines <= 1 ? 1 : 8);
    if (requested < 1) return 1;
    return requested > _maxLines ? _maxLines : requested;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = skillErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final fields = SectionCard(
      children: [
        IosFormTextField(
          label: widget.label,
          controller: _controller,
          hintText: widget.hint,
          inlineLabel: false,
          maxLines: _maxLines,
          minLines: _minLines,
          autofocus: true,
          enabled: !_busy,
          keyboardType: widget.keyboardType,
          textInputAction: _maxLines <= 1
              ? TextInputAction.done
              : TextInputAction.newline,
        ),
        if (_error != null)
          Padding(
            key: SkillsKeys.importError,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Text(
              _error!,
              style: TextStyle(color: cs.error, fontSize: 13, height: 1.35),
            ),
          ),
      ],
    );
    final actions = FormSheetActions(
      key: SkillsKeys.importSubmit,
      cancelLabel: l10n.skillsCancel,
      confirmLabel: widget.confirmLabel,
      onCancel: () => Navigator.of(context).pop(false),
      onConfirm: _busy ? null : _submit,
      busy: _busy,
    );

    if (ResponsiveHelper.isDesktop(context)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogHeader(title: widget.title),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.65,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: fields,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: actions,
          ),
        ],
      );
    }

    return FormSheet(title: widget.title, actions: actions, children: [fields]);
  }
}

/// AppBar / pane ＋ that opens the import menu (anchored on desktop).
class SkillsImportPlusButton extends StatefulWidget {
  const SkillsImportPlusButton({
    super.key,
    this.size = 22,
    this.minSize = 44,
    this.color,
  });

  final double size;
  final double? minSize;
  final Color? color;

  @override
  State<SkillsImportPlusButton> createState() => _SkillsImportPlusButtonState();
}

class _SkillsImportPlusButtonState extends State<SkillsImportPlusButton> {
  final GlobalKey _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: l10n.skillsImportTooltip,
      child: IosIconButton(
        key: _anchorKey,
        icon: Lucide.Plus,
        size: widget.size,
        minSize: widget.minSize,
        color: widget.color,
        semanticLabel: l10n.skillsImportTooltip,
        onTap: () {
          Haptics.light();
          unawaited(startSkillImport(context, anchorKey: _anchorKey));
        },
      ),
    );
  }
}
