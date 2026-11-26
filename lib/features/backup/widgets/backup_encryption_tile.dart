import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/backup/backup_cancel_token.dart';
import '../../../core/services/backup/backup_encryption.dart';
import '../../../core/services/backup/backup_secure_password_store.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../settings/widgets/custom_theme_widgets.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../backup_restore_error_message.dart';

class BackupEncryptionTile extends StatefulWidget {
  const BackupEncryptionTile({super.key, this.busy = false});
  final bool busy;

  @override
  State<BackupEncryptionTile> createState() => _BackupEncryptionTileState();
}

class _BackupEncryptionTileState extends State<BackupEncryptionTile> {
  bool _editing = false;

  Future<void> _edit(Future<void> Function() action) async {
    if (_editing || widget.busy) return;
    setState(() => _editing = true);
    try {
      await action();
    } on BackupCancelledException {
      return;
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: backupRestoreErrorMessage(
            AppLocalizations.of(context)!,
            error,
          ),
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final enabled = settings.backupEncryptionEnabled;
    final remembered = settings.backupPasswordRemembered;
    final editable = !widget.busy && !_editing;
    final l10n = AppLocalizations.of(context)!;
    Future<void> change(bool value) => _edit(() async {
      if (!value) return settings.setBackupEncryptionPassword(null);
      final choice = await _showBackupPasswordDialog(
        context,
        purpose: _PasswordPurpose.create,
        offerRemember: !remembered,
      );
      if (choice == null || !context.mounted) return;
      await settings.setBackupEncryptionPassword(choice.password);
      if (choice.remember) {
        await settings.rememberBackupPassword(choice.password);
      }
    });
    Future<void> remember(bool value) => _edit(() async {
      if (!value) return settings.forgetBackupPassword();
      final password = await backupPasswordForRemembering(context);
      if (password != null) await settings.rememberBackupPassword(password);
    });
    final toggle = IosNavRow(
      icon: Lucide.Lock,
      label: l10n.backupEncryptionTitle,
      subtitle: !enabled
          ? l10n.backupEncryptionOffHint
          : remembered
          ? l10n.backupEncryptionOnHintRemembered
          : l10n.backupEncryptionOnHint,
      subtitleMaxLines: null,
      onTap: editable ? () => change(!enabled) : null,
      trailing: IosSwitch(
        key: const ValueKey('backup-encryption-switch'),
        semanticLabel: l10n.backupEncryptionTitle,
        value: enabled,
        onChanged: editable ? change : null,
      ),
    );
    if (!enabled) return toggle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        toggle,
        IosNavRow(
          icon: Lucide.KeyRound,
          label: l10n.backupRememberPasswordOnDevice,
          subtitle: settings.autoBackupEnabled
              ? l10n.backupForgetDisablesAutomaticHint
              : null,
          subtitleMaxLines: null,
          onTap: editable ? () => remember(!remembered) : null,
          trailing: IosSwitch(
            key: const ValueKey('backup-remember-password-switch'),
            semanticLabel: l10n.backupRememberPasswordOnDevice,
            value: remembered,
            onChanged: editable ? remember : null,
          ),
        ),
        IosNavRow(
          label: l10n.backupEncryptionChangePassword,
          icon: Lucide.Pencil,
          onTap: editable ? () => change(true) : null,
        ),
      ],
    );
  }
}

Future<String?> backupPasswordForExport(BuildContext context) =>
    _resolvePassword(context, offerRemember: true);

Future<String?> backupPasswordForRemembering(BuildContext context) =>
    _resolvePassword(context, offerRemember: false);

Future<String?> _resolvePassword(
  BuildContext context, {
  required bool offerRemember,
}) async {
  final settings = context.read<SettingsProvider>();
  var remember = false;
  final password = await settings.resolveBackupEncryptionPassword(() async {
    if (!context.mounted) return null;
    final choice = await _showBackupPasswordDialog(
      context,
      purpose: settings.hasBackupPasswordVerifier
          ? _PasswordPurpose.manualBackup
          : _PasswordPurpose.create,
      offerRemember: offerRemember,
    );
    remember = choice?.remember == true;
    return choice?.password;
  });
  if (remember && password != null) {
    try {
      await settings.rememberBackupPassword(password);
    } on BackupKeychainUnavailable {
      if (context.mounted) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.backupManualPasswordNotSaved,
          type: NotificationType.warning,
        );
      }
    }
  }
  return password;
}

BackupPasswordPrompt backupPasswordPrompt(BuildContext context) {
  return ({required retry}) async {
    if (!context.mounted) return null;
    return (await _showBackupPasswordDialog(
      context,
      purpose: _PasswordPurpose.restore,
      retry: retry,
    ))?.password;
  };
}

enum _PasswordPurpose { create, manualBackup, restore }

typedef _PasswordChoice = ({String password, bool remember});

Future<_PasswordChoice?> _showBackupPasswordDialog(
  BuildContext context, {
  required _PasswordPurpose purpose,
  bool offerRemember = false,
  bool retry = false,
}) {
  final platform = Theme.of(context).platform;
  final desktop =
      ResponsiveHelper.isDesktop(context) ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;
  final editor = _BackupPasswordEditor(
    purpose: purpose,
    offerRemember: offerRemember,
    retry: retry,
    desktop: desktop,
  );
  if (desktop) {
    return showAppDialog<_PasswordChoice>(
      context,
      maxWidth: 400,
      child: editor,
    );
  }
  return showFormSheet<_PasswordChoice>(context, builder: (_) => editor);
}

class _BackupPasswordEditor extends StatefulWidget {
  const _BackupPasswordEditor({
    required this.purpose,
    required this.offerRemember,
    required this.retry,
    required this.desktop,
  });

  final _PasswordPurpose purpose;
  bool get creating => purpose == _PasswordPurpose.create;
  final bool offerRemember;
  final bool retry;
  final bool desktop;

  @override
  State<_BackupPasswordEditor> createState() => _BackupPasswordEditorState();
}

class _BackupPasswordEditorState extends State<_BackupPasswordEditor> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _visible = false;
  bool _remember = false;

  bool get _valid =>
      _password.text.isNotEmpty &&
      (!widget.creating || _password.text == _confirmation.text);

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (_valid) {
      Navigator.of(
        context,
      ).pop((password: _password.text, remember: _remember));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final title = widget.purpose == _PasswordPurpose.restore
        ? l10n.backupEncryptionUnlockTitle
        : l10n.backupEncryptionTitle;
    final visibilityLabel = _visible
        ? l10n.backupEncryptionHidePassword
        : l10n.backupEncryptionShowPassword;
    final children = <Widget>[
      IosFormTextField(
        key: const ValueKey('backup-password'),
        label: l10n.backupEncryptionPassword,
        controller: _password,
        inlineLabel: false,
        outerPadding: EdgeInsets.zero,
        obscureText: !_visible,
        autocorrect: false,
        enableSuggestions: false,
        autofocus: true,
        textInputAction: widget.creating
            ? TextInputAction.next
            : TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          if (!widget.creating) _submit();
        },
        suffix: IosIconButton(
          key: const ValueKey('backup-password-visibility'),
          icon: _visible ? Lucide.EyeOff : Lucide.Eye,
          size: 18,
          minSize: 36,
          color: cs.onSurfaceVariant,
          tooltip: visibilityLabel,
          semanticLabel: visibilityLabel,
          onTap: () => setState(() => _visible = !_visible),
        ),
      ),
      if (widget.creating) ...[
        const SizedBox(height: 12),
        IosFormTextField(
          key: const ValueKey('backup-password-confirmation'),
          label: l10n.backupEncryptionConfirmPassword,
          controller: _confirmation,
          inlineLabel: false,
          outerPadding: EdgeInsets.zero,
          obscureText: !_visible,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
      ],
      if (widget.retry ||
          (widget.creating && _confirmation.text.isNotEmpty && !_valid)) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            widget.retry
                ? l10n.backupEncryptionFailed
                : l10n.backupEncryptionMismatch,
            style: TextStyle(fontSize: 13, color: cs.error),
          ),
        ),
      ],
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          switch (widget.purpose) {
            _PasswordPurpose.create => l10n.backupEncryptionPasswordHint,
            _PasswordPurpose.manualBackup => l10n.backupManualPasswordHint,
            _PasswordPurpose.restore => l10n.backupEncryptionUnlockHint,
          },
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
      if (widget.offerRemember)
        IosNavRow(
          label: l10n.backupRememberPasswordOnDevice,
          leading: IosCheckbox(
            key: const ValueKey('backup-password-remember'),
            semanticLabel: l10n.backupRememberPasswordOnDevice,
            value: _remember,
            onChanged: (value) => setState(() => _remember = value),
          ),
          onTap: () => setState(() => _remember = !_remember),
        ),
    ];
    final actions = FormSheetActions(
      key: const ValueKey('backup-password-actions'),
      cancelLabel: l10n.backupPageCancel,
      confirmLabel: switch (widget.purpose) {
        _PasswordPurpose.create => l10n.backupPageSave,
        _PasswordPurpose.manualBackup => l10n.backupPageOK,
        _PasswordPurpose.restore => l10n.backupEncryptionUnlock,
      },
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: _valid ? _submit : null,
    );
    if (!widget.desktop) {
      return FormSheet(
        title: title,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        actions: actions,
        children: children,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDialogHeader(title: title),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
        Padding(padding: const EdgeInsets.all(16), child: actions),
      ],
    );
  }
}
