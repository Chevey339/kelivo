import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/world_book.dart';
import '../../../core/providers/world_book_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_form.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snackbar.dart';
import 'world_book_group_actions.dart';

typedef _BookEdit = ({
  String name,
  String description,
  bool enabled,
  String? groupId,
});

Future<void> editWorldBook(
  BuildContext context, {
  required bool desktop,
  WorldBook? book,
  String? groupId,
}) async {
  final provider = context.read<WorldBookProvider>();
  final originalGroupId = book == null
      ? groupId
      : provider.groupIdForBook(book.id);
  final edit = await showAdaptiveForm<_BookEdit>(
    context,
    desktop: desktop,
    builder: (_) =>
        _BookEditor(book: book, groupId: originalGroupId, desktop: desktop),
  );
  if (edit == null || !context.mounted) return;
  try {
    if (book == null) {
      await provider.addBook(
        WorldBook(
          id: const Uuid().v4(),
          name: edit.name,
          description: edit.description,
          enabled: edit.enabled,
        ),
        groupId: edit.groupId,
      );
    } else {
      await provider.updateBook(
        book.id,
        (current) => current.copyWith(
          name: edit.name,
          description: edit.description,
          enabled: edit.enabled,
        ),
        group: edit.groupId == originalGroupId ? null : (groupId: edit.groupId),
      );
    }
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.worldBookGroupSaveFailed,
        type: NotificationType.error,
      );
    }
  }
}

class _BookEditor extends StatefulWidget {
  const _BookEditor({
    required this.book,
    required this.groupId,
    required this.desktop,
  });

  final WorldBook? book;
  final String? groupId;
  final bool desktop;

  @override
  State<_BookEditor> createState() => _BookEditorState();
}

class _BookEditorState extends State<_BookEditor> {
  late final _name = TextEditingController(text: widget.book?.name);
  late final _description = TextEditingController(
    text: widget.book?.description,
  );
  late bool _enabled = widget.book?.enabled ?? true;
  late String? _groupId = widget.groupId;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickGroup() async {
    FocusScope.of(context).unfocus();
    final choice = await chooseWorldBookGroup(
      context,
      desktop: widget.desktop,
      selected: (groupId: _groupId),
    );
    if (mounted && choice != null) setState(() => _groupId = choice.groupId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groups = context.watch<WorldBookProvider>().groups;
    return AdaptiveForm(
      title: widget.book == null ? l10n.worldBookAdd : l10n.worldBookConfig,
      desktop: widget.desktop,
      actions: FormSheetActions(
        cancelLabel: l10n.worldBookCancel,
        confirmLabel: l10n.worldBookSave,
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: () {
          final edit = (
            name: _name.text.trim(),
            description: _description.text.trim(),
            enabled: _enabled,
            groupId: _groupId,
          );
          Navigator.of(context).pop(edit);
        },
      ),
      children: [
        SectionCard(
          children: [
            IosFormTextField(
              label: l10n.worldBookNameLabel,
              controller: _name,
              textInputAction: TextInputAction.next,
              textAlign: TextAlign.start,
              inlineLabel: false,
            ),
            IosFormTextField(
              label: l10n.worldBookDescriptionLabel,
              controller: _description,
              minLines: 2,
              maxLines: 2,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              textAlign: TextAlign.start,
              inlineLabel: false,
            ),
            const IosRowDivider(indent: 12),
            IosNavRow(
              label: l10n.worldBookGroupLabel,
              subtitle: groups[_groupId] ?? l10n.worldBookGroupUngrouped,
              focusable: true,
              onTap: _pickGroup,
            ),
            const IosRowDivider(indent: 12),
            FormSheetSwitchRow(
              label: l10n.worldBookEnabledLabel,
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
          ],
        ),
      ],
    );
  }
}
