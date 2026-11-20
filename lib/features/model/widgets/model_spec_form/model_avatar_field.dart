import 'package:flutter/material.dart';

import '../../../../icons/lucide_adapter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/configurable_avatar.dart';
import '../../../../shared/widgets/ios_tactile.dart';
import '../../../../shared/widgets/snackbar.dart';
import '../../../../utils/brand_assets.dart';
import '../../../provider/widgets/avatar_picker.dart';
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
    try {
      await showAvatarPicker(
        context,
        desktop: widget.desktop,
        anchorKey: _anchor,
        current: widget.controller.avatar,
        onSelected: (avatar) => widget.controller.setAvatar(avatar),
        usePhotoLibrary: !widget.desktop,
        keyPrefix: 'model-avatar-input',
      );
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
