import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import '../catalog/ui_budgets.dart';

Future<void> copyGenUiText(
  BuildContext context,
  String text, {
  String? successMessage,
}) async {
  final l10n = AppLocalizations.of(context)!;
  if (text.length > UiBudgets.copyBytes ||
      utf8.encode(text).length > UiBudgets.copyBytes) {
    showAppSnackBar(
      context,
      message: l10n.genuiCopyLimit,
      type: NotificationType.warning,
    );
    return;
  }
  try {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: successMessage ?? l10n.chatMessageWidgetCopiedToClipboard,
      type: NotificationType.success,
    );
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: l10n.markdownCopySelectionFailed,
        type: NotificationType.error,
      );
    }
  }
}
