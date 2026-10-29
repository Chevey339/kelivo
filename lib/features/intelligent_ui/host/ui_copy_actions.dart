import 'package:flutter/widgets.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import '../text/ui_message_text.dart';
import '../widgets/genui_clipboard.dart';
import 'ui_message_projection.dart';

Future<UiMessageText?> readUiMessageText(
  BuildContext context,
  ChatMessage message,
) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    return await captureUiMessageText(context, message);
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: l10n.genuiTextFailed,
        type: NotificationType.error,
      );
    }
    return null;
  }
}

Future<void> copyUiMessage(BuildContext context, ChatMessage message) async {
  if (message.quotes.isNotEmpty) {
    await copyGenUiText(
      context,
      message.quotedContent(AppLocalizations.of(context)!.selectionQuoteMarker),
    );
    return;
  }
  final projection = await readUiMessageText(context, message);
  if (projection != null && context.mounted) {
    await copyGenUiText(context, projection.copyText);
  }
}

Future<void> copyUiMessageSource(BuildContext context, ChatMessage message) =>
    copyGenUiText(
      context,
      message.quotedContent(AppLocalizations.of(context)!.selectionQuoteMarker),
    );
