import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'snackbar.dart';

/// Requests a process restart and keeps the current retry surface visible when
/// the platform cannot schedule it.
Future<bool> requestAppRestart(
  BuildContext context,
  Future<void> Function() restart,
) async {
  try {
    await restart();
    return true;
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Kelivo restart',
        context: ErrorDescription('while requesting a process restart'),
      ),
    );
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.restartAppFailedMessage,
        type: NotificationType.error,
      );
    }
    return false;
  }
}
