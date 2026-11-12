import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' show LucideIcons;

import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/widgets/desktop_form_dialog.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../utils/brand_assets.dart';
import '../../../theme/app_semantic_colors.dart';

enum AvatarSource { builtin, lobehub, image, url, emoji, reset }

/// The provider avatar menu, also used by MCP's draft icon field.
Future<AvatarSource?> showProviderAvatarSourceMenu(
  BuildContext context, {
  required bool desktop,
  bool allowEmoji = false,
  GlobalKey? anchorKey,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final options = [
    (AvatarSource.builtin, Lucide.Shapes, l10n.providerAvatarChooseBuiltInIcon),
    (AvatarSource.lobehub, Lucide.Globe, l10n.providerAvatarInputLobehubIcon),
    (AvatarSource.image, Lucide.Image, l10n.sideDrawerChooseImage),
    (AvatarSource.url, Lucide.Link, l10n.sideDrawerEnterLink),
    if (allowEmoji)
      (AvatarSource.emoji, LucideIcons.smile, l10n.sideDrawerChooseEmoji),
    (AvatarSource.reset, Lucide.RotateCcw, l10n.sideDrawerReset),
  ];
  AvatarSource? result;
  if (desktop) {
    final items = [
      for (final option in options)
        DesktopContextMenuItem(
          icon: option.$2,
          label: option.$3,
          onTap: () => result = option.$1,
        ),
    ];
    if (anchorKey != null) {
      await showDesktopAnchoredMenu(
        context,
        anchorKey: anchorKey,
        items: items,
      );
    } else {
      final box = context.findRenderObject() as RenderBox;
      await showDesktopContextMenuAt(
        context,
        globalPosition: box.localToGlobal(
          Offset(box.size.width - 220, box.size.height),
        ),
        backgroundColor: context.appColors.surfaceCard.withValues(alpha: .96),
        items: items,
      );
    }
  } else {
    await showMobileActionSheet(
      context,
      items: [
        for (final option in options)
          ActionSheetItem(
            icon: option.$2,
            label: option.$3,
            onTap: () => result = option.$1,
          ),
      ],
    );
  }
  return result;
}

Future<String?> showProviderIconPicker(
  BuildContext context, {
  String? selectedAsset,
  bool desktop = false,
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      ProviderIconPicker(selectedAsset: selectedAsset, desktop: desktop),
);

/// Extracted from the provider editor: the same searchable brand grid,
/// circular icon wells, selected ring, and dark monochrome treatment.
class ProviderIconPicker extends StatefulWidget {
  const ProviderIconPicker({
    super.key,
    this.selectedAsset,
    this.desktop = false,
  });
  final String? selectedAsset;
  final bool desktop;
  @override
  State<ProviderIconPicker> createState() => _ProviderIconPickerState();
}

class _ProviderIconPickerState extends State<ProviderIconPicker> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final query = _search.text.trim().toLowerCase();
    final icons = BrandAssets.selectableIcons
        .where(
          (icon) => '${icon.label} ${icon.id}'.toLowerCase().contains(query),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DesktopFormDialog(
        constraints: BoxConstraints(
          maxWidth: widget.desktop ? 440 : 400,
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: CustomScrollView(
          shrinkWrap: true,
          slivers: [
            SliverToBoxAdapter(
              child: DesktopFormDialogHeader(
                title: l10n.providerAvatarIconDialogTitle,
                closeTooltip: l10n.sideDrawerCancel,
                closeSemanticLabel: l10n.sideDrawerCancel,
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: IosFormTextField(
                  label: '',
                  controller: _search,
                  hintText: l10n.providerAvatarIconSearchHint,
                  inlineLabel: false,
                  outerPadding: EdgeInsets.zero,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            if (icons.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.providerAvatarIconNoResults,
                    style: TextStyle(color: cs.onSurface.withValues(alpha: .6)),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                sliver: SliverGrid.builder(
                  itemCount: icons.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: widget.desktop ? 5 : 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (ctx, index) {
                    final icon = icons[index];
                    final selected = widget.selectedAsset == icon.asset;
                    final mono =
                        isDark && BrandAssets.assetNeedsDarkInvert(icon.asset);
                    return Semantics(
                      label: icon.label,
                      button: true,
                      selected: selected,
                      child: Tooltip(
                        message: icon.label,
                        excludeFromSemantics: true,
                        child: IosCardPress(
                          focusable: true,
                          haptics: false,
                          baseColor: cs.surface,
                          pressedBlendStrength: .04,
                          borderRadius: BorderRadius.circular(12),
                          padding: const EdgeInsets.all(8),
                          onTap: () => Navigator.of(context).pop(icon.asset),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primary.withValues(
                                alpha: isDark ? .18 : .10,
                              ),
                              border: selected
                                  ? Border.all(color: cs.primary, width: 2)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: FractionallySizedBox(
                              widthFactor: .65,
                              heightFactor: .65,
                              child: icon.asset.endsWith('.svg')
                                  ? SvgPicture.asset(
                                      icon.asset,
                                      fit: BoxFit.contain,
                                      colorFilter: mono
                                          ? ColorFilter.mode(
                                              cs.onSurface,
                                              BlendMode.srcIn,
                                            )
                                          : null,
                                    )
                                  : Image.asset(
                                      icon.asset,
                                      fit: BoxFit.contain,
                                      color: mono ? cs.onSurface : null,
                                      colorBlendMode: mono
                                          ? BlendMode.srcIn
                                          : null,
                                    ),
                            ),
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
    );
  }
}
