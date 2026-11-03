import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/models/avatar_config.dart';
import '../../../../icons/lucide_adapter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/configurable_avatar.dart';
import '../../../../shared/widgets/emoji_picker_dialog.dart';
import '../../../../shared/widgets/ios_tactile.dart';
import '../../../../shared/widgets/snackbar.dart';
import '../../../../utils/brand_assets.dart';
import '../../../provider/widgets/avatar_input_dialog.dart';
import '../../../provider/widgets/provider_icon_picker.dart';
import 'model_spec_form_controller.dart';

class ModelAvatarField extends StatefulWidget {
  const ModelAvatarField({
    super.key,
    required this.controller,
    required this.desktop,
  });
  final ModelSpecFormController controller;
  final bool desktop;

  @override
  State<ModelAvatarField> createState() => _ModelAvatarFieldState();
}

class _ModelAvatarFieldState extends State<ModelAvatarField> {
  final _anchor = GlobalKey();

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showProviderAvatarSourceMenu(
      context,
      desktop: widget.desktop,
      allowEmoji: true,
      anchorKey: _anchor,
    );
    if (choice == null || !mounted) return;
    try {
      AvatarConfig? avatar;
      switch (choice) {
        case AvatarSource.reset:
          break;
        case AvatarSource.builtin:
          final current = widget.controller.avatar;
          final value = await showProviderIconPicker(
            context,
            desktop: widget.desktop,
            selectedAsset: current?.type == AvatarType.icon
                ? current!.value
                : null,
          );
          if (value == null) return;
          avatar = AvatarConfig(type: AvatarType.icon, value: value);
        case AvatarSource.emoji:
          final value = await showEmojiPickerDialog(context);
          if (value == null) return;
          avatar = AvatarConfig(type: AvatarType.emoji, value: value);
        case AvatarSource.image:
          final String? path;
          if (widget.desktop) {
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
            path = result?.files.single.path;
          } else {
            path = (await ImagePicker().pickImage(
              source: ImageSource.gallery,
              requestFullMetadata: false,
            ))?.path;
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
            desktop: widget.desktop,
            initial: widget.controller.avatar,
            keyPrefix: 'model-avatar-input',
          );
          if (avatar == null) return;
      }
      if (mounted) widget.controller.setAvatar(avatar);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: l10n.modelDetailSheetSaveFailedMessage,
          type: NotificationType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = widget.controller.config;
    final modelAsset = BrandAssets.assetForName(
      widget.controller.spec.upstreamId,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: IosCardPress(
        key: const ValueKey('model-avatar-field'),
        borderRadius: BorderRadius.circular(10),
        onTap: _pick,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            key: _anchor,
            children: [
              ConfigurableAvatar(
                avatar:
                    widget.controller.avatar ??
                    (modelAsset == null ? config.avatar : null),
                name: widget.controller.spec.upstreamId,
                fallbackAsset:
                    modelAsset ??
                    BrandAssets.assetForName(config.name) ??
                    BrandAssets.assetForName(config.id),
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.modelAvatarTitle)),
              Icon(
                Lucide.ChevronRight,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
