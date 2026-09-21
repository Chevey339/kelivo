import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../shared/widgets/ios_tactile.dart';
import '../../shared/widgets/section_card.dart';
import '../../theme/app_semantic_colors.dart';

/// The same compact label/control arrangement used in desktop preferences.
class DesktopScheduledTaskRow extends StatelessWidget {
  const DesktopScheduledTaskRow({
    super.key,
    required this.label,
    required this.child,
    this.expandControl = false,
  });

  final String label;
  final Widget child;
  final bool expandControl;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final text = Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .9),
          ),
        );
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              text,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: child),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 2, child: text),
            const SizedBox(width: 20),
            Expanded(
              flex: 3,
              child: expandControl
                  ? child
                  : Align(alignment: Alignment.centerRight, child: child),
            ),
          ],
        );
      },
    ),
  );
}

class DesktopScheduledTaskSection extends StatelessWidget {
  const DesktopScheduledTaskSection({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: Theme.of(
          context,
        ).inputDecorationTheme.copyWith(hoverColor: Colors.transparent),
      ),
      child: SectionCard(
        radius: 12,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: .6,
                  child: ColoredBox(color: context.appColors.hairline),
                ),
              ),
            children[index],
          ],
        ],
      ),
    ),
  );
}

/// Bounded text keeps long assistant/model names from widening the form.
class DesktopScheduledTaskPicker extends StatelessWidget {
  const DesktopScheduledTaskPicker({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? leading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: enabled,
      child: IosCardPress(
        onTap: enabled ? onTap : null,
        baseColor: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 240,
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: .18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: enabled ? .88 : .4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: cs.onSurface.withValues(alpha: .6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
