import 'dart:async';
import 'package:flutter/widgets.dart';
import '../runtime/ui_surface_state.dart';

final class UiSearchTarget {
  UiSearchTarget(this.conversationId, this.owner);
  final String conversationId;
  final UiSurfaceOwner owner;
}

/// The message-list jump mounts the revision first; this subsequent request
/// reveals the actual block. No semantic character offset enters Markdown.
final class UiSearchNavigation extends ValueNotifier<UiSearchTarget?> {
  UiSearchNavigation() : super(null);
  void reveal(String conversationId, String revisionId, String surfaceKey) {
    value = UiSearchTarget(
      conversationId,
      UiSurfaceOwner(revisionId: revisionId, surfaceKey: surfaceKey),
    );
  }

  void clear() => value = null;
}

class UiSearchNavigationScope extends InheritedWidget {
  const UiSearchNavigationScope({
    super.key,
    required this.navigation,
    required super.child,
  });
  final UiSearchNavigation navigation;
  static UiSearchNavigation? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<UiSearchNavigationScope>()
      ?.navigation;
  @override
  bool updateShouldNotify(UiSearchNavigationScope oldWidget) =>
      navigation != oldWidget.navigation;
}

class UiSearchReveal extends StatefulWidget {
  const UiSearchReveal({
    super.key,
    required this.conversationId,
    required this.owner,
    required this.child,
    this.enabled = true,
  });
  final String conversationId;
  final UiSurfaceOwner owner;
  final Widget child;
  final bool enabled;
  @override
  State<UiSearchReveal> createState() => _UiSearchRevealState();
}

class _UiSearchRevealState extends State<UiSearchReveal> {
  UiSearchNavigation? _navigation;
  UiSearchTarget? _scheduled;
  void _changed() {
    final target = _navigation?.value;
    if (!widget.enabled ||
        target == null ||
        target == _scheduled ||
        target.conversationId != widget.conversationId ||
        target.owner != widget.owner) {
      return;
    }
    _scheduled = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(_scheduled, target)) _scheduled = null;
      if (!mounted ||
          !widget.enabled ||
          _navigation?.value != target ||
          target.owner != widget.owner ||
          target.conversationId != widget.conversationId) {
        return;
      }
      _navigation!.clear();
      unawaited(
        Scrollable.ensureVisible(
          context,
          alignment: 0.15,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
        ),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = UiSearchNavigationScope.maybeOf(context);
    if (next != _navigation) {
      _navigation?.removeListener(_changed);
      _navigation = next;
      next?.addListener(_changed);
    }
    _changed();
  }

  @override
  void didUpdateWidget(UiSearchReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _changed();
  }

  @override
  void dispose() {
    _navigation?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
