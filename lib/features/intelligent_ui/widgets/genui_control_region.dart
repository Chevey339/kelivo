import 'package:flutter/widgets.dart';

/// The event, not a pointer id, carries the exemption. Mouse ids can be reused
/// and transformed events in the child and parent have different identities.
final class GenUiControlPointer {
  static final _events = Expando<bool>();
  static void mark(PointerDownEvent event) =>
      _events[event.original ?? event] = true;
  static bool contains(PointerDownEvent event) =>
      _events[event.original ?? event] == true;
}

/// Wrap actual control hit areas only, never the whole card or its prose.
class GenUiControlRegion extends StatelessWidget {
  const GenUiControlRegion({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Listener(onPointerDown: GenUiControlPointer.mark, child: child);
}
