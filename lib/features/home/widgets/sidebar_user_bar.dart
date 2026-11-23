import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/sidebar_layout.dart';
import '../../../core/providers/user_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/avatar_image.dart';
import '../../../shared/widgets/emoji_text.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import '../../settings/pages/settings_page.dart';
import 'mobile_sidebar_entries.dart';

class SidebarUserBar extends StatelessWidget {
  const SidebarUserBar({
    super.key,
    required this.name,
    required this.embedded,
    required this.entries,
    required this.onOpen,
    required this.onEditAvatar,
    required this.onEditName,
    this.desktop = false,
  });

  final String name;
  final bool embedded;
  final Map<SidebarEntry, SidebarVisibility> entries;
  final ValueChanged<SidebarEntry> onOpen;
  final VoidCallback onEditAvatar;
  final VoidCallback onEditName;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final icons = sidebarEntriesWithVisibility(
      entries,
      SidebarVisibility.show,
    ).where((entry) => entry != SidebarEntry.history).toList();
    return Container(
      color: embedded ? Colors.transparent : cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const fixedWidth = 91.0; // Avatar, its left inset and Settings.
          const iconSlot = 49.0;
          final slots = ((constraints.maxWidth - fixedWidth) ~/ iconSlot).clamp(
            0,
            3,
          );
          var shownCount = icons.length.clamp(0, slots.clamp(0, 2));
          if (icons.length > shownCount ||
              entries.containsValue(SidebarVisibility.more)) {
            shownCount = shownCount.clamp(0, (slots - 1).clamp(0, 2));
          }
          final more = mobileSidebarOverflow(entries, iconLimit: shownCount);
          final occupied = shownCount + (more.isNotEmpty ? 1 : 0);
          final hideName =
              occupied >= 3 ||
              constraints.maxWidth - fixedWidth - occupied * iconSlot < 50;
          return Row(
            children: [
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEditAvatar,
                child: _UserAvatar(name: name),
              ),
              if (hideName)
                const Spacer()
              else ...[
                const SizedBox(width: 20),
                Expanded(
                  child: IosCardPress(
                    borderRadius: BorderRadius.circular(6),
                    baseColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    onTap: onEditName,
                    child: SizedBox(
                      height: 45,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: desktop ? 14 : 16,
                            fontWeight: AppFontWeights.emphasis,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              for (final entry in icons.take(shownCount)) ...[
                MobileSidebarEntryIcon(
                  entry: entry,
                  onTap: () => onOpen(entry),
                ),
                const SizedBox(width: 4),
              ],
              if (more.isNotEmpty) ...[
                IosIconButton(
                  icon: Lucide.Ellipsis,
                  size: 22,
                  minSize: 45,
                  semanticLabel: l10n.sidebarMore,
                  onTap: () => showMobileSidebarMore(
                    context,
                    onOpen,
                    iconLimit: shownCount,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              IosIconButton(
                icon: Lucide.Settings,
                size: 22,
                minSize: 45,
                padding: const EdgeInsets.all(10),
                semanticLabel: l10n.desktopNavSettingsTooltip,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final cs = Theme.of(context).colorScheme;
    final type = user.avatarType;
    final value = user.avatarValue;
    final hasValue = value != null && value.isNotEmpty;
    const size = 40.0;
    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primary.withValues(alpha: .15),
      ),
      child: type == 'emoji' && hasValue
          ? EmojiText(value, fontSize: size * .5, optimizeEmojiAlign: true)
          : Text(
              (type == 'url' && hasValue) || name.isEmpty
                  ? '?'
                  : name.characters.first,
              style: TextStyle(
                color: cs.primary,
                fontSize: size * .42,
                fontWeight: AppFontWeights.emphasis,
              ),
            ),
    );
    return hasValue && (type == 'url' || (type == 'file' && !kIsWeb))
        ? AvatarImage(
            source: value,
            size: size,
            isNetwork: type == 'url',
            fallback: placeholder,
          )
        : placeholder;
  }
}
