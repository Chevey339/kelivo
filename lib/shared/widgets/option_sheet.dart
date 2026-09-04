import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

/// One choice in [showOptionSheet].
class OptionSheetItem<T> {
  const OptionSheetItem({
    required this.value,
    this.icon,
    required this.label,
    this.subtitle,
    this.key,
  });

  final T value;
  final IconData? icon;
  final String label;
  final String? subtitle;
  final Key? key;
}

bool _isDesktopPlatform() {
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// Single-select list. Mobile uses the World Book form-sheet shell;
/// desktop uses [showAppDialog] + [AppDialogHeader] (`maxWidth: 420`).
///
/// Returns the tapped [OptionSheetItem.value], or `null` if dismissed.
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<OptionSheetItem<T>> items,
  T? selected,
  Widget? footer,
}) {
  if (_isDesktopPlatform()) {
    return showAppDialog<T>(
      context,
      maxWidth: 420,
      child: _OptionSheetDialog(
        title: title,
        items: items,
        selected: selected,
        footer: footer,
      ),
    );
  }
  return showFormSheet<T>(
    context,
    builder: (ctx) => FormSheet(
      title: title,
      children: [
        _OptionList<T>(items: items, selected: selected),
        if (footer != null) footer,
      ],
    ),
  );
}

class _OptionSheetDialog<T> extends StatelessWidget {
  const _OptionSheetDialog({
    required this.title,
    required this.items,
    required this.selected,
    this.footer,
  });

  final String title;
  final List<OptionSheetItem<T>> items;
  final T? selected;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDialogHeader(title: title),
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _OptionList<T>(items: items, selected: selected),
                  if (footer != null) footer!,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionList<T> extends StatelessWidget {
  const _OptionList({required this.items, required this.selected});

  final List<OptionSheetItem<T>> items;
  final T? selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SectionCard(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const IosRowDivider(),
          IosNavRow(
            key: items[i].key,
            icon: items[i].icon,
            label: items[i].label,
            subtitle: items[i].subtitle,
            labelWeight: AppFontWeights.medium,
            trailing: selected == items[i].value
                ? Icon(Lucide.Check, size: 18, color: cs.primary)
                : const SizedBox.shrink(),
            onTap: () => Navigator.of(context).pop(items[i].value),
          ),
        ],
      ],
    );
  }
}
