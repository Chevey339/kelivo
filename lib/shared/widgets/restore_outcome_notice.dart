import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/database/private_data_storage.dart';

import '../../core/services/backup/restore_receipt.dart';
import '../../l10n/app_localizations.dart';

/// Explains rollback and protected storage activation before normal use.
class RestoreOutcomeNotice extends StatefulWidget {
  const RestoreOutcomeNotice({
    super.key,
    required this.outcome,
    required this.child,
    this.dataDirectory,
  });

  final RestoreReceiptState? outcome;
  final Widget child;
  final Directory? dataDirectory;

  @override
  State<RestoreOutcomeNotice> createState() => _RestoreOutcomeNoticeState();
}

class _RestoreOutcomeNoticeState extends State<RestoreOutcomeNotice> {
  var _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled ||
        (widget.outcome != RestoreReceiptState.rolledBack &&
            widget.dataDirectory == null)) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (widget.outcome == RestoreReceiptState.rolledBack) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.backupRestoreRolledBackTitle),
            content: Text(l10n.backupRestoreRolledBackContent),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.backupPageOK),
              ),
            ],
          ),
        );
      }
      final directory = widget.dataDirectory;
      if (directory == null) return;
      final notice = File('${directory.path}/${PrivateDataStorage.noticeName}');
      try {
        if (!await notice.exists() || !mounted) return;
        final acknowledged = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.recoveryStorageReadyTitle),
            content: Text(l10n.recoveryStorageReadyBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.backupPageOK),
              ),
            ],
          ),
        );
        if (acknowledged == true) await notice.delete();
      } catch (_) {
        // Keep the durable notice pending if it could not be acknowledged.
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
