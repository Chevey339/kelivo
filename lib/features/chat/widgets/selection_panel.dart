import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';

/// The same compact sheet chrome and surfaces used by the app's form sheets.
Future<void> showSelectionSheet(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showFormSheet<void>(
  context,
  builder: (context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .55,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Flexible(child: builder(context)),
          ],
        ),
      ),
    ),
  ),
);

class SelectionPanel extends StatelessWidget {
  const SelectionPanel({
    super.key,
    required this.title,
    required this.children,
    required this.actions,
    this.headerAction,
    this.onClose,
  });

  final String title;
  final List<Widget> children;
  final Widget actions;
  final Widget? headerAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: AppFontWeights.semibold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    if (headerAction != null) ...[
                      const SizedBox(width: 8),
                      Flexible(child: headerAction!),
                    ],
                  ],
                ),
              ),
              if (onClose != null)
                IosIconButton(
                  icon: LucideIcons.x,
                  size: 16,
                  minSize: 40,
                  visualSize: 28,
                  borderRadius: 14,
                  color: cs.onSurface.withValues(alpha: .62),
                  tooltip: AppLocalizations.of(context)!.commonClose,
                  onTap: onClose,
                ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: actions),
      ],
    );
  }
}
