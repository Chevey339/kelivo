import 'package:flutter/material.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_interaction_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';

typedef GenUiAskHandler = Future<void> Function(UiAskIntent intent);

/// Owns only transient editing state unless the host provides an owner shared
/// with an expanded view. Focus registrations always belong to this active tree.
class GenUiInteractionHost extends StatefulWidget {
  const GenUiInteractionHost({
    super.key,
    required this.surface,
    required this.child,
    this.interactions,
    this.onAsk,
    this.exporting = false,
  });
  final UiSurfaceController surface;
  final UiInteractionController? interactions;
  final GenUiAskHandler? onAsk;
  final bool exporting;
  final Widget child;
  @override
  State<GenUiInteractionHost> createState() => _GenUiInteractionHostState();
}

class _GenUiInteractionHostState extends State<GenUiInteractionHost> {
  late UiInteractionController _controller;
  final _focus = <String, _FocusTarget>{};
  final _actions = <String, Future<void> Function()>{};
  void _create() => _controller =
      widget.interactions ?? UiInteractionController(widget.surface);
  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void didUpdateWidget(GenUiInteractionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interactions != widget.interactions ||
        oldWidget.surface != widget.surface) {
      if (oldWidget.interactions == null) _controller.dispose();
      _create();
    }
  }

  @override
  void dispose() {
    if (widget.interactions == null) _controller.dispose();
    _focus.clear();
    _actions.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(identical(_controller.surface, widget.surface));
    return GenUiInteractions._(
      _focus,
      _actions,
      controller: _controller,
      onAsk: widget.onAsk,
      exporting: widget.exporting,
      child: widget.child,
    );
  }
}

final class _FocusTarget {
  const _FocusTarget(this.node, this.context);
  final FocusNode node;
  final BuildContext context;
}

class GenUiInteractions extends InheritedWidget {
  const GenUiInteractions._(
    this._focus,
    this._actions, {
    required this.controller,
    required this.onAsk,
    required this.exporting,
    required super.child,
  });
  final UiInteractionController controller;
  final GenUiAskHandler? onAsk;
  final bool exporting;
  bool get readOnly => exporting || controller.surface.readOnly;
  final Map<String, _FocusTarget> _focus;
  final Map<String, Future<void> Function()> _actions;
  Object get registrationOwner => _focus;
  static GenUiInteractions of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GenUiInteractions>()!;

  VoidCallback registerFocus(String id, FocusNode node, BuildContext context) {
    final target = _FocusTarget(node, context);
    _focus[id] = target;
    return () {
      if (identical(_focus[id], target)) _focus.remove(id);
    };
  }

  Future<UiActionResult> activate(
    BuildContext context,
    String id, {
    required UiRuntimeToken token,
  }) async {
    if (exporting) return const UiActionResult(block: UiActionBlock.readOnly);
    final declaration = controller.surface.nodes[id]?.declaration;
    if (declaration?.arguments['action'] is UiAsk && onAsk == null) {
      return const UiActionResult(block: UiActionBlock.unavailable);
    }
    final result = controller.activate(id, token: token);
    await _focusFailure(context, result, token);
    if (result.intent case final intent?) {
      await onAsk!(intent);
    }
    return result;
  }

  Future<UiActionResult> captureForAttach(
    BuildContext context, {
    required UiRuntimeToken token,
  }) async {
    if (exporting) return const UiActionResult(block: UiActionBlock.readOnly);
    final result = controller.captureForAttach(token: token);
    await _focusFailure(context, result, token);
    return result;
  }

  Future<void> _focusFailure(
    BuildContext context,
    UiActionResult result,
    UiRuntimeToken token,
  ) async {
    final first = result.form?.firstField;
    if (first != null) {
      // Committing a blank number may just have revealed this field. Its
      // focus registration belongs to the next built tree, not the old one.
      await WidgetsBinding.instance.endOfFrame;
      final target = _focus[first];
      if (context.mounted &&
          controller.surface.accepts(token) &&
          target != null &&
          target.context.mounted) {
        target.node.requestFocus();
        await WidgetsBinding.instance.endOfFrame;
        final fieldContext = target.context;
        if (fieldContext.mounted && identical(_focus[first], target)) {
          await Scrollable.ensureVisible(
            fieldContext,
            alignment: .15,
            duration: MediaQuery.disableAnimationsOf(fieldContext)
                ? Duration.zero
                : const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
          );
        }
      }
    }
  }

  VoidCallback registerAction(String id, Future<void> Function() action) {
    _actions[id] = action;
    return () {
      if (identical(_actions[id], action)) _actions.remove(id);
    };
  }

  Future<void> submit(
    BuildContext context,
    String field, {
    required UiRuntimeToken token,
  }) async {
    if (readOnly || !controller.surface.accepts(token)) return;
    final button = controller.submitButtonFor(field);
    if (button != null) await _actions[button]?.call();
  }

  @override
  bool updateShouldNotify(GenUiInteractions oldWidget) =>
      oldWidget.controller != controller ||
      oldWidget.onAsk != onAsk ||
      oldWidget.exporting != exporting;
}
