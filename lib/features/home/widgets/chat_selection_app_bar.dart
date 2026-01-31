import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../icons/lucide_adapter.dart';

class ChatSelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatSelectionAppBar({
    super.key,
    required this.selectedCount,
    required this.allSelected,
    required this.onClose,
    required this.onToggleSelectAll,
    required this.onInvertSelection,
  });

  final int selectedCount;
  final bool allSelected;
  final VoidCallback onClose;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onInvertSelection;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return AppBar(
      centerTitle: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IosIconButton(
        icon: Lucide.X,
        size: 22,
        minSize: 44,
        semanticLabel: l10n.homePageCancel,
        onTap: onClose,
      ),
      title: Text(
        l10n.chatSelectionSelectedCountTitle(selectedCount),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onInvertSelection,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Text(
                    l10n.modelFetchInvertTooltip,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggleSelectAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IgnorePointer(
                        child: IosCheckbox(
                          value: allSelected,
                          size: 18,
                          hitTestSize: 32,
                          onChanged: (_) {},
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        l10n.storageSpaceSelectAll,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
