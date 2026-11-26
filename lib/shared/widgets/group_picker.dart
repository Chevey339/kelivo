import 'package:flutter/material.dart';

import '../../icons/lucide_adapter.dart';
import 'adaptive_form.dart';
import 'ios_tactile.dart';
import 'ios_text_button.dart';
import 'section_card.dart';
import 'snackbar.dart';

/// A null result dismisses the picker. A null group ID chooses Ungrouped.
typedef GroupChoice = ({String? groupId});

Future<GroupChoice?> showGroupPicker(
  BuildContext context, {
  required String title,
  required String ungroupedLabel,
  required String createLabel,
  required Map<String, String> Function(BuildContext) groups,
  required Future<String?> Function(BuildContext) createGroup,
  GroupChoice? selected,
  String Function(Object)? errorMessage,
  bool? desktop,
}) => showAdaptiveForm<GroupChoice>(
  context,
  desktop: desktop,
  builder: (context) => _GroupPicker(
    title: title,
    groups: groups(context),
    ungroupedLabel: ungroupedLabel,
    createLabel: createLabel,
    selected: selected,
    createGroup: createGroup,
    errorMessage: errorMessage,
    desktop: desktop,
  ),
);

class _GroupPicker extends StatefulWidget {
  const _GroupPicker({
    required this.title,
    required this.groups,
    required this.ungroupedLabel,
    required this.createLabel,
    required this.selected,
    required this.createGroup,
    required this.errorMessage,
    required this.desktop,
  });

  final String title;
  final Map<String, String> groups;
  final String ungroupedLabel;
  final String createLabel;
  final GroupChoice? selected;
  final Future<String?> Function(BuildContext) createGroup;
  final String Function(Object)? errorMessage;
  final bool? desktop;

  @override
  State<_GroupPicker> createState() => _GroupPickerState();
}

class _GroupPickerState extends State<_GroupPicker> {
  bool _creating = false;

  Future<void> _create() async {
    if (_creating) return;
    final route = ModalRoute.of(context);
    setState(() => _creating = true);
    try {
      final id = await widget.createGroup(context);
      // The route stays mounted while closing. Only pop this picker.
      if (id != null && mounted && route?.isCurrent == true) {
        Navigator.of(context).pop((groupId: id));
      }
    } catch (error) {
      if (mounted && route?.isCurrent == true) {
        showAppSnackBar(
          context,
          message: widget.errorMessage?.call(error) ?? error.toString(),
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AdaptiveForm(
      title: widget.title,
      desktop: widget.desktop,
      children: [
        for (final group in <String?, String>{
          null: widget.ungroupedLabel,
          ...widget.groups,
        }.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: IosCardPress(
              focusable: true,
              key: ValueKey('group-option-${group.key ?? 'ungrouped'}'),
              baseColor: sheetTileColor(context),
              onTap: _creating
                  ? null
                  : () => Navigator.of(context).pop((groupId: group.key)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Lucide.Folder,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: .5),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      group.value,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  if (widget.selected == (groupId: group.key))
                    Icon(Lucide.Check, size: 18, color: cs.primary),
                ],
              ),
            ),
          ),
        IosTextButton(
          icon: Lucide.Plus,
          label: widget.createLabel,
          onPressed: _creating ? null : _create,
        ),
      ],
    );
  }
}
