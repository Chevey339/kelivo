import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/section_card.dart';

class ScheduledTaskTile extends StatelessWidget {
  const ScheduledTaskTile({
    super.key,
    required this.name,
    required this.time,
    required this.repeat,
    required this.detail,
    required this.enabled,
    required this.onChanged,
    required this.onTap,
    this.running = false,
  });
  final String name, time, repeat, detail;
  final bool enabled, running;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IosCardPress(
            baseColor: Colors.transparent,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          children: [
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 32,
                                height: 1.15,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              repeat,
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface.withValues(alpha: .55),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    label: name,
                    child: IgnorePointer(
                      ignoring: running,
                      child: IosSwitch(value: enabled, onChanged: onChanged),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const IosRowDivider(indent: 16),
          IosNavRow(
            label: detail,
            icon: running ? LucideIcons.loader : LucideIcons.clock,
            onTap: onTap,
            labelWeight: FontWeight.w400,
          ),
        ],
      ),
    );
  }
}

@Preview(
  name: 'Scheduled task · Light',
  brightness: Brightness.light,
  size: Size(390, 200),
)
@Preview(
  name: 'Scheduled task · Dark',
  brightness: Brightness.dark,
  size: Size(390, 200),
)
Widget scheduledTaskPreview() => Padding(
  padding: const EdgeInsets.all(16),
  child: ScheduledTaskTile(
    name: '晨间简报',
    time: '08:00',
    repeat: '每天',
    detail: '下次：明天 08:00',
    enabled: true,
    onChanged: (_) {},
    onTap: () {},
  ),
);
