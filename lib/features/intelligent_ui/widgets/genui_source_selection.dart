import 'package:flutter/widgets.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import '../catalog/ui_budgets.dart';

/// Standalone source previews need selection too. Within a message the existing
/// block projection owns the budget; source dialogs provide an explicit budget.
/// Never nest selection areas inside a Markstream extension.
class GenUiSourceSelection extends StatelessWidget {
  const GenUiSourceSelection({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      SelectionContainer.maybeOf(context) == null
      ? AppSelectionArea(copyByteLimit: UiBudgets.copyBytes, child: child)
      : child;
}
