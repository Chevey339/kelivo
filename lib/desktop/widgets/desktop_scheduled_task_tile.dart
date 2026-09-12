import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/ios_switch.dart';
import '../../shared/widgets/ios_tactile.dart';
import '../../shared/widgets/section_card.dart';

class DesktopScheduledTaskTile extends StatelessWidget {
  const DesktopScheduledTaskTile({
    super.key,
    required this.name,
    required this.time,
    required this.repeat,
    required this.detail,
    required this.enabled,
    required this.running,
    required this.onChanged,
    required this.onEdit,
    required this.onHistory,
    required this.onMenu,
  });

  final String name, time, repeat, detail;
  final bool enabled, running;
  final ValueChanged<bool> onChanged;
  final VoidCallback onEdit, onHistory;
  final ValueChanged<Offset> onMenu;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    return SectionCard(
      child: IosCardPress(
        baseColor: Colors.transparent,
        onTap: running ? onHistory : onEdit,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                running ? LucideIcons.loader : LucideIcons.clock,
                size: 22,
                color: cs.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$time · $repeat',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: .75),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: .55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IosIconButton(
                icon: LucideIcons.history,
                size: 18,
                semanticLabel: l.scheduledTasksHistory,
                tooltip: l.scheduledTasksHistory,
                onTap: onHistory,
              ),
              const SizedBox(width: 8),
              Semantics(
                label: name,
                child: IosSwitch(
                  value: enabled,
                  onChanged: running ? null : onChanged,
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (context) => IosIconButton(
                  icon: LucideIcons.ellipsis,
                  semanticLabel: l.messageMoreSheetTitle,
                  tooltip: l.messageMoreSheetTitle,
                  onTap: () {
                    final box = context.findRenderObject()! as RenderBox;
                    onMenu(box.localToGlobal(Offset(0, box.size.height)));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
