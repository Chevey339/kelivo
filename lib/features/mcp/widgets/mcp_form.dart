import 'package:flutter/material.dart';

import '../../../desktop/widgets/desktop_form_dialog.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/form_sheet.dart';

/// Uses the existing mobile form sheet and desktop dialog chrome.
Future<T?> showMcpForm<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool? desktop,
}) {
  if (desktop ?? ResponsiveHelper.isDesktop(context)) {
    return showDialog<T>(context: context, builder: builder);
  }
  return showFormSheet<T>(context, builder: builder);
}

class McpForm extends StatelessWidget {
  const McpForm({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.desktop,
    this.width = 460,
  });

  final String title;
  final List<Widget> children;
  final Widget? actions;
  final bool? desktop;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (!(desktop ?? ResponsiveHelper.isDesktop(context))) {
      return FormSheet(
        title: title,
        actions: actions,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: children,
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DesktopFormDialog(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DesktopFormDialogHeader(
              title: title,
              closeTooltip: MaterialLocalizations.of(
                context,
              ).closeButtonTooltip,
              closeSemanticLabel: MaterialLocalizations.of(
                context,
              ).closeButtonTooltip,
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            if (actions != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: actions,
              ),
          ],
        ),
      ),
    );
  }
}
