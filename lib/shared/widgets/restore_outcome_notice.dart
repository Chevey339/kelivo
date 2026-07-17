import 'package:flutter/material.dart';

import '../../core/services/backup/restore_receipt.dart';
import '../../l10n/app_localizations.dart';

/// Shows the one startup outcome that requires explicit user acknowledgement.
class RestoreOutcomeNotice extends StatefulWidget {
  const RestoreOutcomeNotice({
    super.key,
    required this.outcome,
    required this.child,
  });

  final RestoreReceiptState? outcome;
  final Widget child;

  @override
  State<RestoreOutcomeNotice> createState() => _RestoreOutcomeNoticeState();
}

class _RestoreOutcomeNoticeState extends State<RestoreOutcomeNotice> {
  var _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled || widget.outcome != RestoreReceiptState.rolledBack) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
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
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
