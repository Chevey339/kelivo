import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/models/mcp_presentation.dart';
import '../../../core/services/mcp/mcp_icon_cache.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/emoji_picker_dialog.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../provider/widgets/provider_icon_picker.dart';
import 'mcp_text_dialog.dart';

Future<void> showMcpIconPicker(
  BuildContext context, {
  required FutureOr<void> Function(McpServerIcon?) onSelected,
  bool? desktop,
  McpServerIcon? currentIcon,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final choice = await showProviderAvatarSourceMenu(
    context,
    desktop: desktop ?? ResponsiveHelper.isDesktop(context),
    allowEmoji: true,
  );
  if (choice == null || !context.mounted) return;
  try {
    McpServerIcon? icon;
    switch (choice) {
      case AvatarSource.reset:
        break;
      case AvatarSource.emoji:
        final value = await showEmojiPickerDialog(context);
        if (value == null) return;
        icon = McpServerIcon(type: McpIconType.emoji, value: value);
      case AvatarSource.image:
        final files = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'png',
            'jpg',
            'jpeg',
            'webp',
            'gif',
            'svg',
            'ico',
            'bmp',
          ],
        );
        final path = files?.files.single.path;
        if (path == null) return;
        icon = McpServerIcon(
          type: McpIconType.file,
          value: await McpIconCache.importFile(path),
        );
      case AvatarSource.builtin:
        final asset = await showProviderIconPicker(
          context,
          desktop: desktop ?? ResponsiveHelper.isDesktop(context),
          selectedAsset: currentIcon?.type == McpIconType.asset
              ? currentIcon!.value
              : null,
        );
        if (asset == null) return;
        icon = McpServerIcon(type: McpIconType.asset, value: asset);
      case AvatarSource.url:
      case AvatarSource.lobehub:
        final isUrl = choice == AvatarSource.url;
        final value = await _input(
          context,
          desktop: desktop,
          title: isUrl
              ? l10n.sideDrawerImageUrlDialogTitle
              : l10n.providerAvatarLobehubDialogTitle,
          hint: isUrl
              ? l10n.sideDrawerImageUrlDialogHint
              : l10n.providerAvatarLobehubDialogHint,
          valid: (value) => isUrl
              ? McpIconCache.isWebUri(Uri.tryParse(value))
              : RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9-]*$').hasMatch(value),
        );
        if (value == null) return;
        icon = McpServerIcon(
          type: isUrl ? McpIconType.url : McpIconType.lobehub,
          value: value,
        );
    }
    if (context.mounted) await onSelected(icon);
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: l10n.mcpIconInvalid,
        type: NotificationType.error,
      );
    }
  }
}

Future<String?> _input(
  BuildContext context, {
  bool? desktop,
  required String title,
  required String hint,
  required bool Function(String) valid,
}) async {
  return showDialog<String>(
    context: context,
    builder: (_) => McpTextDialog(
      title: title,
      hint: hint,
      valid: valid,
      submitLabel: AppLocalizations.of(context)!.sideDrawerSave,
    ),
  );
}
