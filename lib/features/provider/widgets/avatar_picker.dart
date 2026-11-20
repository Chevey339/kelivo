import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/avatar_config.dart';
import '../../../shared/widgets/emoji_picker_dialog.dart';
import 'avatar_input_dialog.dart';
import 'provider_icon_picker.dart';

Future<void> showAvatarPicker(
  BuildContext context, {
  required bool desktop,
  required GlobalKey anchorKey,
  required AvatarConfig? current,
  required ValueChanged<AvatarConfig?> onSelected,
  bool usePhotoLibrary = false,
  bool Function(Uri?)? validateImageUrl,
  String keyPrefix = 'avatar-input',
}) async {
  final choice = await showProviderAvatarSourceMenu(
    context,
    desktop: desktop,
    allowEmoji: true,
    anchorKey: anchorKey,
  );
  if (choice == null || !context.mounted) return;

  AvatarConfig? avatar;
  switch (choice) {
    case AvatarSource.reset:
      break;
    case AvatarSource.builtin:
      final asset = await showProviderIconPicker(
        context,
        desktop: desktop,
        selectedAsset: current?.type == AvatarType.icon ? current!.value : null,
      );
      if (asset == null) return;
      avatar = AvatarConfig(type: AvatarType.icon, value: asset);
    case AvatarSource.emoji:
      final emoji = await showEmojiPickerDialog(context);
      if (emoji == null) return;
      avatar = AvatarConfig(type: AvatarType.emoji, value: emoji);
    case AvatarSource.image:
      final String? path;
      if (usePhotoLibrary) {
        path = (await ImagePicker().pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
        ))?.path;
      } else {
        path = await pickAvatarImageFile();
      }
      if (path == null || path.isEmpty) return;
      avatar = AvatarConfig(type: AvatarType.file, value: path);
    case AvatarSource.lobehub:
    case AvatarSource.url:
      avatar = await showAvatarInputDialog(
        context,
        type: choice == AvatarSource.lobehub
            ? AvatarType.lobehub
            : AvatarType.url,
        desktop: desktop,
        initial: current,
        validateImageUrl: validateImageUrl,
        keyPrefix: keyPrefix,
      );
      if (avatar == null) return;
  }
  if (context.mounted) onSelected(avatar);
}

Future<String?> pickAvatarImageFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: [
      'png',
      'jpg',
      'jpeg',
      'webp',
      'gif',
      'svg',
      'bmp',
      'ico',
    ],
  );
  return result?.files.single.path;
}
