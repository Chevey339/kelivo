import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' show LucideIcons;

import '../../../core/models/mcp_presentation.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../core/services/mcp/mcp_icon_cache.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/emoji_picker_dialog.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../utils/brand_assets.dart';
import 'mcp_server_avatar.dart';
import 'mcp_text_dialog.dart';

class McpServerIconField extends StatelessWidget {
  const McpServerIconField({super.key, required this.serverId});
  final String serverId;

  @override
  Widget build(BuildContext context) {
    final server = context.watch<McpProvider>().getById(serverId);
    if (server == null) return const SizedBox.shrink();
    return TextButton(
      onPressed: () => showMcpIconPicker(context, serverId),
      child: Row(
        children: [
          McpServerAvatar(server: server, size: 36, radius: 10),
          const SizedBox(width: 12),
          Expanded(child: Text(AppLocalizations.of(context)!.mcpIconTitle)),
          const Icon(Lucide.ChevronRight, size: 16),
        ],
      ),
    );
  }
}

Future<void> showMcpIconPicker(BuildContext context, String serverId) async {
  final l10n = AppLocalizations.of(context)!;
  final mcp = context.read<McpProvider>();
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      backgroundColor: context.overlaySurface,
      title: Text(l10n.mcpIconTitle),
      children: [
        for (final option in [
          ('emoji', LucideIcons.smile, l10n.sideDrawerChooseEmoji),
          ('file', Lucide.Image, l10n.sideDrawerChooseImage),
          ('url', Lucide.Link, l10n.sideDrawerEnterLink),
          ('asset', Lucide.Shapes, l10n.providerAvatarChooseBuiltInIcon),
          ('lobehub', Lucide.Globe, l10n.providerAvatarInputLobehubIcon),
          ('reset', Lucide.RotateCcw, l10n.sideDrawerReset),
        ])
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(option.$1),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Icon(option.$2, size: 20),
                  const SizedBox(width: 12),
                  Text(option.$3),
                ],
              ),
            ),
          ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  try {
    McpServerIcon? icon;
    switch (choice) {
      case 'reset':
        break;
      case 'emoji':
        final value = await showEmojiPickerDialog(context);
        if (value == null) return;
        icon = McpServerIcon(type: McpIconType.emoji, value: value);
      case 'file':
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
      case 'asset':
        final asset = await _pickAsset(context);
        if (asset == null) return;
        icon = McpServerIcon(type: McpIconType.asset, value: asset);
      case 'url':
      case 'lobehub':
        final isUrl = choice == 'url';
        final value = await _input(
          context,
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
    await mcp.setServerIcon(serverId, icon);
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

Future<String?> _pickAsset(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  var query = '';
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final icons = BrandAssets.selectableIcons
            .where(
              (icon) => '${icon.label} ${icon.id}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
        return AlertDialog(
          backgroundColor: context.overlaySurface,
          title: Text(l10n.providerAvatarIconDialogTitle),
          content: SizedBox(
            width: 420,
            height: 380,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: l10n.providerAvatarIconSearchHint,
                    prefixIcon: const Icon(Lucide.Search),
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    itemCount: icons.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemBuilder: (ctx, index) {
                      final icon = icons[index];
                      return Tooltip(
                        message: icon.label,
                        child: InkWell(
                          onTap: () => Navigator.of(ctx).pop(icon.asset),
                          borderRadius: BorderRadius.circular(10),
                          child: Semantics(
                            label: icon.label,
                            button: true,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ctx.appColors.surfaceFill,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: icon.asset.endsWith('.svg')
                                  ? SvgPicture.asset(
                                      icon.asset,
                                      colorFilter:
                                          BrandAssets.assetNeedsDarkInvert(
                                            icon.asset,
                                          )
                                          ? ColorFilter.mode(
                                              Theme.of(
                                                ctx,
                                              ).colorScheme.onSurface,
                                              BlendMode.srcIn,
                                            )
                                          : null,
                                    )
                                  : Image.asset(icon.asset),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.mcpPageCancel),
            ),
          ],
        );
      },
    ),
  );
}
