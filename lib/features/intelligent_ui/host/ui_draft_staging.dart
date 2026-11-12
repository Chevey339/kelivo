import 'package:flutter/widgets.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import '../widgets/genui_draft_dialog.dart';
import 'ui_draft_request.dart';

Future<void> stageUiComposerDraft(
  BuildContext context, {
  required UiDraftRequest request,
  required ChatInputBarController target,
  required bool Function() isCurrent,
}) async {
  if (!context.mounted || !isCurrent() || !target.isValid) return;
  final l10n = AppLocalizations.of(context)!;
  final before = await target.prepareExternalDraft();
  if (!context.mounted || !isCurrent() || !target.isValid) return;
  if (before == null) {
    showAppSnackBar(
      context,
      message: target.isComposing
          ? l10n.genuiFinishComposing
          : l10n.genuiDraftChanged,
      type: NotificationType.warning,
    );
    return;
  }
  final incoming = request.attachment;
  if (before.uiContext != null && incoming != null) {
    if (!await confirmGenUiReplacement(
      context,
      current: before.uiContext!,
      replacement: incoming,
    )) {
      return;
    }
    if (!context.mounted || !isCurrent() || !target.isValid) return;
  }
  final text = request.text.isEmpty
      ? before.text
      : before.text.isEmpty
      ? request.text
      : '${before.text}\n\n${request.text}';
  final next = before.copyWith(
    text: text,
    uiContext: incoming,
    selectionBase: text.length,
    selectionExtent: text.length,
  );
  if (before.text.isNotEmpty) {
    if (!await confirmGenUiMerge(context, next)) return;
    if (!context.mounted || !isCurrent() || !target.isValid) return;
  }
  // A native edit may have been accepted behind the preview while its Flutter
  // mirror is still stale. Drain that work again before the final comparison.
  final settled = await target.prepareExternalDraft();
  if (!context.mounted || !isCurrent() || !target.isValid) return;
  if (settled == null ||
      !before.sameValue(settled) ||
      !target.applyExternalDraft(before, next)) {
    showAppSnackBar(
      context,
      message: l10n.genuiDraftChanged,
      type: NotificationType.warning,
    );
  }
}
