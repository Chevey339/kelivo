import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/external_backup_auto_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/backup/backup_cancel_token.dart';
import '../../../core/services/backup/backup_encryption.dart';
import '../../../core/services/backup/backup_secure_password_store.dart';
import '../../../desktop/widgets/desktop_select_dropdown.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../settings/widgets/custom_theme_widgets.dart';
import '../backup_restore_error_message.dart';
import '../backup_task_runner.dart';
import 'backup_encryption_tile.dart';

class ExternalBackupControls extends StatefulWidget {
  const ExternalBackupControls({super.key, required this.desktop});
  final bool desktop;
  @override
  State<ExternalBackupControls> createState() => _ExternalBackupControlsState();
}

class _ExternalBackupControlsState extends State<ExternalBackupControls> {
  bool _editing = false;

  Future<void> _edit(Future<void> Function() action) async {
    if (_editing) return;
    setState(() => _editing = true);
    try {
      await action();
    } on BackupCancelledException {
      return;
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final macReason = error is BackupMacKeychainAccessError
            ? error.reason
            : null;
        final canOpenKeychain =
            macReason == MacBackupAuthorization.locked ||
            macReason == MacBackupAuthorization.denied;
        showAppSnackBar(
          context,
          message: error is BackupDecryptionException
              ? l10n.backupAutoFailedPassword
              : backupRestoreErrorMessage(l10n, error),
          type: macReason == MacBackupAuthorization.cancelled
              ? NotificationType.info
              : NotificationType.error,
          duration: Duration(seconds: canOpenKeychain ? 10 : 3),
          actionLabel: canOpenKeychain
              ? l10n.backupMacOpenKeychainAccess
              : null,
          onAction: canOpenKeychain
              ? () async {
                  final opened =
                      await BackupSecurePasswordStore.openMacKeychainAccess();
                  if (!opened && mounted) {
                    showAppSnackBar(
                      context,
                      message: backupRestoreErrorMessage(l10n, error),
                      type: NotificationType.error,
                    );
                  }
                }
              : null,
        );
      }
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  Future<void> _toggle(bool value) async {
    final auto = context.read<ExternalBackupAutoProvider>();
    final settings = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    String? password;
    if (value && settings.backupEncryptionEnabled) {
      password = await backupPasswordForRemembering(context);
      if (!mounted) return;
      if (!settings.backupPasswordRemembered) {
        final remember = await showAppDialog<bool>(
          context,
          maxWidth: 390,
          child: Builder(
            builder: (dialog) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.backupAutoRememberPasswordTitle,
                    style: Theme.of(dialog).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.backupAutoRememberPasswordMessage),
                  const SizedBox(height: 18),
                  FormSheetActions(
                    cancelLabel: l10n.backupAutoRememberPasswordDecline,
                    confirmLabel: l10n.backupAutoRememberPasswordConfirm,
                    onCancel: () => Navigator.pop(dialog, false),
                    onConfirm: () => Navigator.pop(dialog, true),
                  ),
                ],
              ),
            ),
          ),
        );
        if (!mounted) return;
        if (remember != true) {
          showAppSnackBar(
            context,
            message: l10n.backupAutoRememberDeclined,
            type: NotificationType.info,
          );
          return;
        }
      }
    }
    await auto.enable(value, password: password);
  }

  @override
  Widget build(BuildContext context) {
    final auto = context.watch<ExternalBackupAutoProvider>();
    context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final options = auto.available;
    final destination = auto.destination;
    final desktop = widget.desktop && auto.desktop;
    final eligible = options.contains(destination);
    final editable = !_editing && !auto.busy;
    String label(BackupDestination v) => switch (v) {
      BackupDestination.webdav => l10n.backupAutoDestinationWebDav,
      BackupDestination.s3 => l10n.backupAutoDestinationS3,
      BackupDestination.local => l10n.backupAutoDestinationLocal,
    };
    final toggle = editable && (eligible || auto.enabled)
        ? (bool v) => _edit(() => _toggle(v))
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IosNavRow(
          icon: desktop ? null : Lucide.Calendar,
          label: l10n.backupAutoEnableTitle,
          subtitle: l10n.backupAutoEnableHint,
          subtitleMaxLines: null,
          caption: eligible
              ? null
              : desktop
              ? (destination == BackupDestination.local
                    ? l10n.backupAutoNeedFolderHint
                    : l10n.backupAutoNeedDestinationHint)
              : l10n.backupAutoNeedRemoteHint,
          onTap: toggle == null ? null : () => toggle(!auto.enabled),
          trailing: IosSwitch(
            key: const ValueKey('external-backup-auto-switch'),
            value: auto.enabled,
            onChanged: toggle,
            semanticLabel: l10n.backupAutoEnableTitle,
          ),
        ),
        if (options.length > 1 || (options.isNotEmpty && !eligible))
          IosNavRow(
            label: l10n.backupAutoDestinationTitle,
            icon: desktop ? null : Lucide.Upload,
            detailText: desktop
                ? null
                : eligible
                ? label(destination!)
                : null,
            trailing: desktop
                ? DesktopSelectDropdown<BackupDestination?>(
                    value: eligible ? destination : null,
                    options: [
                      for (final v in options)
                        DesktopSelectOption(value: v, label: label(v)),
                    ],
                    enabled: editable,
                    onSelected: (v) async {
                      if (v != null) await _edit(() => auto.select(v));
                    },
                  )
                : null,
            onTap: desktop || !editable
                ? null
                : () => showMobileActionSheet(
                    context,
                    title: l10n.backupAutoDestinationTitle,
                    items: [
                      for (final v in options)
                        ActionSheetItem(
                          icon: Lucide.Upload,
                          label: label(v),
                          checked: v == destination,
                          onTap: () => _edit(() => auto.select(v)),
                        ),
                    ],
                  ),
          ),
        if (desktop) ...[
          IosNavRow(
            label: auto.folder.path.isEmpty
                ? l10n.backupAutoLocalFolderChoose
                : l10n.backupAutoLocalFolderChange,
            subtitle: auto.folder.path.isEmpty ? null : auto.folder.path,
            subtitleMaxLines: 2,
            onTap: editable ? () => _edit(auto.chooseFolder) : null,
          ),
          if (auto.folder.path.isNotEmpty) ...[
            IosNavRow(
              label: l10n.backupAutoLocalRetentionTitle,
              trailing: DesktopSelectDropdown<int>(
                value: auto.retention,
                options: [
                  for (final n in [3, 5, 10, 0])
                    DesktopSelectOption(
                      value: n,
                      label: n == 0
                          ? l10n.backupAutoLocalRetentionUnlimited
                          : l10n.backupAutoLocalRetentionCount(n),
                    ),
                ],
                enabled: editable,
                onSelected: (v) => _edit(() => auto.setRetention(v)),
              ),
            ),
            IosNavRow(
              label: l10n.backupAutoLocalNow,
              onTap: editable
                  ? () => runExternalBackup(context, BackupDestination.local)
                  : null,
            ),
          ],
        ],
      ],
    );
  }
}

class ExternalBackupCancelRow extends StatelessWidget {
  const ExternalBackupCancelRow({super.key});
  @override
  Widget build(BuildContext context) {
    final auto = context.watch<ExternalBackupAutoProvider>();
    if (!auto.busy) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return IosNavRow(
      icon: Lucide.X,
      label: l10n.backupPageCancel,
      subtitle: l10n.backupRunningInBackground,
      onTap: auto.cancellable ? auto.cancel : null,
    );
  }
}
