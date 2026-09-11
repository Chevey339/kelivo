import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

String backupReminderFrequencyLabel(AppLocalizations l10n, int days) {
  return switch (days) {
    1 => l10n.backupReminderEveryDay,
    3 => l10n.backupReminderEveryThreeDays,
    7 => l10n.backupReminderEveryWeek,
    14 => l10n.backupReminderEveryFourteenDays,
    30 => l10n.backupReminderEveryMonth,
    _ => l10n.backupReminderCustomDays(days),
  };
}

String backupReminderTimeLabel(BuildContext context, int? minutes) {
  if (minutes == null) {
    return AppLocalizations.of(context)!.backupReminderDisabled;
  }
  final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  return time.format(context);
}

String backupReminderDateTimeLabel(BuildContext context, DateTime? value) {
  final l10n = AppLocalizations.of(context)!;
  if (value == null) return l10n.backupReminderNever;
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(local)} ${TimeOfDay.fromDateTime(local).format(context)}';
}

String backupReminderNextLabel(BuildContext context, DateTime? value) {
  final l10n = AppLocalizations.of(context)!;
  if (value == null) return l10n.backupReminderDisabled;
  if (!DateTime.now().isBefore(value)) return l10n.backupReminderDueNow;
  return backupReminderDateTimeLabel(context, value);
}

Future<int?> showBackupReminderCustomDaysDialog(
  BuildContext context, {
  required int initialDays,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _BackupReminderCustomDaysDialog(initialDays: initialDays),
  );
}

class _BackupReminderCustomDaysDialog extends StatefulWidget {
  const _BackupReminderCustomDaysDialog({required this.initialDays});

  final int initialDays;

  @override
  State<_BackupReminderCustomDaysDialog> createState() =>
      _BackupReminderCustomDaysDialogState();
}

class _BackupReminderCustomDaysDialogState
    extends State<_BackupReminderCustomDaysDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDays.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(int.parse(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(l10n.backupReminderCustomDialogTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.backupReminderCustomDialogDescription),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.backupReminderCustomDaysLabel,
                filled: true,
                fillColor: context.appColors.surfaceFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
              ),
              validator: (value) {
                final days = int.tryParse(value ?? '');
                if (days == null || days < 1 || days > 365) {
                  return l10n.backupReminderCustomDaysInvalid;
                }
                return null;
              },
              onFieldSubmitted: (_) {
                _submit();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.backupPageCancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.backupPageOK)),
      ],
    );
  }
}
