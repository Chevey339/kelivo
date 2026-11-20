import 'package:flutter/widgets.dart';

/// Keeps the editor route and its draft in place during icon import.
class SearchServiceEditorScope<T> extends StatelessWidget {
  const SearchServiceEditorScope({
    super.key,
    required this.saving,
    required this.child,
  });

  final bool saving;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope<T>(
    canPop: !saving,
    child: ExcludeFocus(
      excluding: saving,
      child: AbsorbPointer(absorbing: saving, child: child),
    ),
  );
}
