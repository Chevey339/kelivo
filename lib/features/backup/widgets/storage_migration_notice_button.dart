import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/database/private_data_storage.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';

/// Keeps the storage migration explanation available until acknowledged.
class StorageMigrationNoticeButton extends StatefulWidget {
  const StorageMigrationNoticeButton({super.key, required this.dataDirectory});

  final Directory dataDirectory;

  @override
  State<StorageMigrationNoticeButton> createState() =>
      _StorageMigrationNoticeButtonState();
}

class _StorageMigrationNoticeButtonState
    extends State<StorageMigrationNoticeButton> {
  late final _notice = File(
    '${widget.dataDirectory.path}/${PrivateDataStorage.noticeName}',
  );
  late final _pending = _notice.exists();
  var _acknowledged = false;
  var _showing = false;

  Future<void> _showNotice() async {
    if (_showing) return;
    _showing = true;
    try {
      final l10n = AppLocalizations.of(context)!;
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
      if (acknowledged != true) return;
      await _notice.delete();
      if (mounted) setState(() => _acknowledged = true);
    } catch (_) {
      // Leave the notice pending if acknowledgement could not be saved.
    } finally {
      _showing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_acknowledged) return const SizedBox.shrink();
    return FutureBuilder<bool>(
      future: _pending,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        final title = AppLocalizations.of(context)!.recoveryStorageReadyTitle;
        return IosIconButton(
          icon: Lucide.BadgeInfo,
          color: Theme.of(context).colorScheme.primary,
          minSize: 44,
          tooltip: title,
          semanticLabel: title,
          onTap: _showNotice,
        );
      },
    );
  }
}
